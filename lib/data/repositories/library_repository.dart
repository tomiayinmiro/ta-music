import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

import '../database/daos/excluded_folder_dao.dart';
import '../database/daos/scan_root_dao.dart';
import '../database/daos/song_dao.dart';
import '../database/database_change_notifier.dart';
import '../models/excluded_folder.dart';
import '../models/scan_root.dart';
import '../services/library_scanner.dart';
import 'reactive_query.dart';

final _logger = Logger();

/// Result of a storage/audio permission check or request.
enum StoragePermissionStatus {
  granted,
  denied,

  /// Android's "don't ask again" state — calling `.request()` again would
  /// silently no-op instead of showing the OS dialog. Callers should send
  /// the user to app settings instead of re-prompting.
  permanentlyDenied,
}

/// Orchestrates library scanning: manages scan-root/excluded-folder config
/// and runs [LibraryScanner], notifying the main isolate's
/// [DatabaseChangeNotifier] when a scan completes (the scanner runs in its
/// own isolate, whose change notifications don't cross isolate boundaries).
class LibraryRepository {
  LibraryRepository({
    required this._scanRootDao,
    required this._excludedFolderDao,
    required this._songDao,
  });

  final ScanRootDao _scanRootDao;
  final ExcludedFolderDao _excludedFolderDao;
  final SongDao _songDao;
  final _scanner = LibraryScanner();

  /// Cached for the process lifetime — the running OS version can't change
  /// underneath the app, so there's no reason to re-query the platform
  /// channel on every permission check/request.
  int? _cachedAndroidSdkInt;

  Future<int> _androidSdkInt() async {
    final cached = _cachedAndroidSdkInt;
    if (cached != null) return cached;
    final info = await DeviceInfoPlugin().androidInfo;
    _cachedAndroidSdkInt = info.version.sdkInt;
    return info.version.sdkInt;
  }

  Stream<List<ScanRoot>> watchScanRoots() => watchQuery({'scan_roots'}, _scanRootDao.getAll);

  Stream<List<ExcludedFolder>> watchExcludedFolders() =>
      watchQuery({'excluded_folders'}, _excludedFolderDao.getAll);

  Future<void> addScanRoot(String path) => _scanRootDao.add(path);

  Future<void> removeScanRoot(int id) => _scanRootDao.remove(id);

  /// Adds the folder to the excluded list AND instantly hides any songs
  /// already in the library that fall under it, rather than waiting for the
  /// next scan (approved 2026-08-18 — "next scan" is fine for songs
  /// *reappearing* after un-excluding, but disappearing should be instant).
  Future<void> addExcludedFolder(String path) async {
    await _excludedFolderDao.add(path);
    await _songDao.markMissingUnderPath(path);
  }

  Future<void> removeExcludedFolder(int id) => _excludedFolderDao.remove(id);

  Future<void> removeExcludedFolderByPath(String path) => _excludedFolderDao.removeByPath(path);

  /// Immediate child directories of [path] (one level, no recursion) — used
  /// by the "Exclude a subfolder?" prompt shown right after adding a scan
  /// root, so it doesn't accidentally become a full recursive tree browser.
  Future<List<Directory>> listSubfolders(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return [];
    final entries = await dir.list(followLinks: false).toList();
    return entries.whereType<Directory>().toList()
      ..sort((a, b) => p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase()));
  }

  /// Seeds a default scan root on first run. Windows defaults to the user's
  /// Music folder; Android has no single conventional folder across devices
  /// and scoped storage requires a granted permission first anyway, so it's
  /// left for the user to pick via the empty-state CTA.
  Future<void> ensureDefaultScanRoot() async {
    if (!Platform.isWindows) return;
    final existing = await _scanRootDao.getAll();
    if (existing.isNotEmpty) return;
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile == null) return;
    final musicDir = Directory(p.join(userProfile, 'Music'));
    if (await musicDir.exists()) {
      await _scanRootDao.add(musicDir.path);
    }
  }

  /// Current permission status without prompting — used by the first-launch
  /// flow to decide whether to show the rationale dialog. Always
  /// [StoragePermissionStatus.granted] off Android, which has no such
  /// permission model.
  Future<StoragePermissionStatus> checkStoragePermissionStatus() async {
    if (!Platform.isAndroid) return StoragePermissionStatus.granted;
    final sdkInt = await _androidSdkInt();
    final primary = _primaryPermission(sdkInt);
    final primaryStatus = await primary.status;
    // TODO(permission-diagnostics): remove before release — added to
    // diagnose the Tecno BF6/Android 12 degraded-scan regression, where the
    // app was silently treating Permission.audio's no-op "granted" as real
    // on pre-13 devices and skipping the actual READ_EXTERNAL_STORAGE check.
    _logger.i('[permission] check sdk=$sdkInt primary=$primary status=$primaryStatus');
    if (primaryStatus.isGranted) return StoragePermissionStatus.granted;

    // Only Android 13+ has a real fallback worth checking — Permission.audio
    // is a genuine permission there, and Permission.storage (capped at
    // maxSdkVersion=32 in the manifest) is declared but effectively inert;
    // still checked per spec since the OS *could* still report it granted on
    // some OEM skins. Below 13, Permission.storage IS the real permission —
    // there's nothing to fall back to.
    if (sdkInt >= 33) {
      final fallbackStatus = await Permission.storage.status;
      _logger.i('[permission] fallback check sdk=$sdkInt permission=storage status=$fallbackStatus');
      if (fallbackStatus.isGranted) return StoragePermissionStatus.granted;
      if (primaryStatus.isPermanentlyDenied || fallbackStatus.isPermanentlyDenied) {
        return StoragePermissionStatus.permanentlyDenied;
      }
      return StoragePermissionStatus.denied;
    }

    if (primaryStatus.isPermanentlyDenied) return StoragePermissionStatus.permanentlyDenied;
    return StoragePermissionStatus.denied;
  }

  /// Requests the storage/audio permission — shared by [scan] and the
  /// first-launch rationale-dialog flow so there's exactly one place that
  /// knows how to ask.
  ///
  /// permission_handler's Permission.audio is a hard no-op below Android 13
  /// (its own source explicitly skips pre-TIRAMISU: "we should not handle
  /// permissions on pre Android TIRAMISU devices") — confirmed 2026-08-17
  /// testing on a real Android 12 device, where it granted trivially
  /// without ever prompting. The previous version of this method requested
  /// both Permission.audio and Permission.storage and accepted either being
  /// granted, which meant Permission.audio's fake "granted" on <=12 could
  /// mask a real READ_EXTERNAL_STORAGE denial — the app would proceed to
  /// scan believing it had permission when MediaStore actually had none,
  /// producing a silently degraded (near-empty) scan. Root-caused
  /// 2026-09-09 against a real Tecno BF6/Android 12 device. Now branches on
  /// the real API level via [_androidSdkInt] (device_info_plus) instead of
  /// asking both and hoping: Android 13+ asks Permission.audio (falling
  /// back to Permission.storage if that's denied, per spec, though it's
  /// realistically inert there — capped at maxSdkVersion=32 in the
  /// manifest); Android 12 and below asks Permission.storage only, since
  /// that's the only one that's ever real pre-13.
  Future<StoragePermissionStatus> requestStoragePermission() async {
    if (!Platform.isAndroid) return StoragePermissionStatus.granted;
    final sdkInt = await _androidSdkInt();
    final primary = _primaryPermission(sdkInt);
    final status = await primary.request();
    // TODO(permission-diagnostics): remove before release — see the check
    // method's matching TODO above.
    _logger.i('[permission] requested sdk=$sdkInt permission=$primary result=$status');
    if (status.isGranted) return StoragePermissionStatus.granted;

    if (sdkInt >= 33) {
      final fallback = await Permission.storage.request();
      _logger.i('[permission] fallback requested sdk=$sdkInt permission=storage result=$fallback');
      if (fallback.isGranted) return StoragePermissionStatus.granted;
      if (status.isPermanentlyDenied || fallback.isPermanentlyDenied) {
        return StoragePermissionStatus.permanentlyDenied;
      }
      return StoragePermissionStatus.denied;
    }

    if (status.isPermanentlyDenied) return StoragePermissionStatus.permanentlyDenied;
    return StoragePermissionStatus.denied;
  }

  /// Android 13+ (API 33) gets the real, OS-tracked `READ_MEDIA_AUDIO`
  /// permission; everything below that gets `READ_EXTERNAL_STORAGE`, the
  /// only one of the two that actually means anything pre-13.
  Permission _primaryPermission(int sdkInt) => sdkInt >= 33 ? Permission.audio : Permission.storage;

  Stream<ScanProgress> scan() async* {
    // Requested here, right before a scan, rather than unconditionally at
    // app launch, so the ask has context instead of firing at a blank
    // screen — the first-launch flow (HomeScreen) already requests it
    // proactively with a rationale dialog before this ever runs, so this
    // is normally an instant no-op by the time a scan actually starts.
    if (Platform.isAndroid) {
      final status = await requestStoragePermission();
      if (status != StoragePermissionStatus.granted) {
        yield const ScanProgress(
          scanned: 0,
          total: 0,
          isDone: true,
          error: 'Storage permission was not granted, so your music folders can\'t be read.',
        );
        return;
      }
    }

    final roots = (await _scanRootDao.getAll()).map((r) => r.path).toList();
    final excluded = (await _excludedFolderDao.getAll()).map((e) => e.path).toList();
    await for (final progress in _scanner.scan(rootPaths: roots, excludedPaths: excluded)) {
      yield progress;
      if (progress.isDone && progress.error == null) {
        DatabaseChangeNotifier.instance.notify({'songs', 'albums', 'artists'});
      }
    }
  }
}
