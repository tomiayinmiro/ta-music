import 'dart:io';

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
    final audioStatus = await Permission.audio.status;
    final storageStatus = await Permission.storage.status;
    if (audioStatus.isGranted || storageStatus.isGranted) return StoragePermissionStatus.granted;
    if (audioStatus.isPermanentlyDenied || storageStatus.isPermanentlyDenied) {
      return StoragePermissionStatus.permanentlyDenied;
    }
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
  /// without ever prompting. Permission.storage is the
  /// READ_EXTERNAL_STORAGE-backed counterpart for <=12; it's a no-op the
  /// other way on 13+. Requesting both and accepting either covers both OS
  /// versions without needing a device_info plugin to branch on SDK int.
  Future<StoragePermissionStatus> requestStoragePermission() async {
    if (!Platform.isAndroid) return StoragePermissionStatus.granted;
    final statuses = await [Permission.audio, Permission.storage].request();
    if (statuses.values.any((status) => status.isGranted)) return StoragePermissionStatus.granted;
    if (statuses.values.any((status) => status.isPermanentlyDenied)) {
      return StoragePermissionStatus.permanentlyDenied;
    }
    return StoragePermissionStatus.denied;
  }

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
