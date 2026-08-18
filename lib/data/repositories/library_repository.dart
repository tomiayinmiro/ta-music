import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

import '../database/daos/excluded_folder_dao.dart';
import '../database/daos/scan_root_dao.dart';
import '../database/database_change_notifier.dart';
import '../models/excluded_folder.dart';
import '../models/scan_root.dart';
import '../services/library_scanner.dart';
import 'reactive_query.dart';

/// Orchestrates library scanning: manages scan-root/excluded-folder config
/// and runs [LibraryScanner], notifying the main isolate's
/// [DatabaseChangeNotifier] when a scan completes (the scanner runs in its
/// own isolate, whose change notifications don't cross isolate boundaries).
class LibraryRepository {
  LibraryRepository({
    required this._scanRootDao,
    required this._excludedFolderDao,
  });

  final ScanRootDao _scanRootDao;
  final ExcludedFolderDao _excludedFolderDao;
  final _scanner = LibraryScanner();

  Stream<List<ScanRoot>> watchScanRoots() => watchQuery({'scan_roots'}, _scanRootDao.getAll);

  Stream<List<ExcludedFolder>> watchExcludedFolders() =>
      watchQuery({'excluded_folders'}, _excludedFolderDao.getAll);

  Future<void> addScanRoot(String path) => _scanRootDao.add(path);

  Future<void> removeScanRoot(int id) => _scanRootDao.remove(id);

  Future<void> addExcludedFolder(String path) => _excludedFolderDao.add(path);

  Future<void> removeExcludedFolder(int id) => _excludedFolderDao.remove(id);

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

  Stream<ScanProgress> scan() async* {
    if (Platform.isAndroid) {
      // permission_handler's Permission.audio is a hard no-op below Android
      // 13 (its own source explicitly skips pre-TIRAMISU: "we should not
      // handle permissions on pre Android TIRAMISU devices") — confirmed
      // 2026-08-17 testing on a real Android 12 device, where it granted
      // trivially without ever prompting. Permission.storage is the
      // READ_EXTERNAL_STORAGE-backed counterpart for <=12; it's a no-op the
      // other way on 13+. Requesting both and accepting either covers both
      // OS versions without needing a device_info plugin to branch on SDK
      // int. Requested here, right before a scan, rather than at app
      // launch, so the ask has context instead of firing at a blank screen.
      final statuses = await [Permission.audio, Permission.storage].request();
      final granted = statuses.values.any((status) => status.isGranted);
      if (!granted) {
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
