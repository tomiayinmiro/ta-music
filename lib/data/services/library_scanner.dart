import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:audiotags/audiotags.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show sqfliteFfiInit, databaseFactory, databaseFactoryFfi;

import '../../core/utils/path_matching.dart';
import '../database/daos/album_dao.dart';
import '../database/daos/artist_dao.dart';
import '../database/daos/song_dao.dart';
import '../database/database.dart';
import '../models/album.dart';
import '../models/song.dart';
import 'cover_art_resizer.dart';
import 'media_store_scanner.dart';

final _logger = Logger();

// TODO(cover-art-resize-audit): temporary instrumentation added 2026-09-01
// to verify the new cover-art resize step from adb logcat — logs original
// vs. resized dimensions/file size for the first few covers processed per
// scan, then goes quiet. Remove once confirmed on-device. See CLAUDE.md.
int _coverArtResizeLogCount = 0;
const _kCoverArtResizeLogLimit = 5;

/// Audio file extensions the scanner considers, matched case-insensitively.
const kSupportedAudioExtensions = {
  '.mp3',
  '.flac',
  '.m4a',
  '.aac',
  '.ogg',
  '.wav',
  '.opus',
};

/// Folder names that mark a directory (and everything under it) as
/// voice-recording territory, per CLAUDE.md rule (a). Compared
/// case-insensitively against each path segment; `_containsRecording`
/// catches variants these exact names miss (e.g. "Screen Recordings").
const _kVoiceMemoFolderNames = {'recordings', 'voice recorder', 'call recordings'};

/// Matches Android voice-recorder auto-generated filenames — the whole
/// basename (no extension), nothing else — e.g. "2023-05-01_07.10.01" or
/// "20230501_071001". Bug 8b (device testing pass): folder-name exclusion
/// alone didn't catch every OEM voice recorder, so this catches the
/// pattern regardless of which folder the file landed in.
final _kVoiceMemoFilenamePattern = RegExp(
  r'^\d{4}-\d{2}-\d{2}_\d{2}\.\d{2}\.\d{2}$|^\d{8}_\d{6}$',
);

/// Progress/result snapshot emitted while a scan runs.
class ScanProgress {
  const ScanProgress({
    required this.scanned,
    required this.total,
    this.currentPath,
    this.isDone = false,
    this.error,
    this.inserted = 0,
    this.updated = 0,
    this.missing = 0,
  });

  final int scanned;
  final int total;
  final String? currentPath;
  final bool isDone;
  final String? error;
  final int inserted;
  final int updated;
  final int missing;

  double get fraction => total <= 0 ? 0 : (scanned / total).clamp(0, 1);
}

/// Scans the configured library folders for audio files, extracts metadata
/// and cover art, and reconciles the result against the `songs` table.
///
/// Runs the entire walk + tag-read + DB-write pass on a background isolate
/// (via [Isolate.spawn]) so it never blocks the UI thread, per the Phase 2
/// brief. Progress streams back over a [ReceivePort].
class LibraryScanner {
  Stream<ScanProgress> scan({
    required List<String> rootPaths,
    required List<String> excludedPaths,
  }) {
    final controller = StreamController<ScanProgress>();
    final receivePort = ReceivePort();
    Isolate? isolate;

    receivePort.listen((message) {
      if (message is ScanProgress) {
        controller.add(message);
        if (message.isDone || message.error != null) {
          controller.close();
          receivePort.close();
          isolate?.kill();
        }
      }
    });

    () async {
      try {
        final rootToken = RootIsolateToken.instance;
        if (rootToken == null) {
          throw StateError('LibraryScanner.scan must be called after Flutter binding init.');
        }
        isolate = await Isolate.spawn(
          _scanEntryPoint,
          _ScanRequest(
            sendPort: receivePort.sendPort,
            rootIsolateToken: rootToken,
            rootPaths: rootPaths,
            excludedPaths: excludedPaths,
          ),
        );
      } catch (e) {
        controller.add(ScanProgress(scanned: 0, total: 0, error: e.toString(), isDone: true));
        controller.close();
        receivePort.close();
      }
    }();

    return controller.stream;
  }
}

class _ScanRequest {
  const _ScanRequest({
    required this.sendPort,
    required this.rootIsolateToken,
    required this.rootPaths,
    required this.excludedPaths,
  });

  final SendPort sendPort;
  final RootIsolateToken rootIsolateToken;
  final List<String> rootPaths;
  final List<String> excludedPaths;
}

void _scanEntryPoint(_ScanRequest request) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(request.rootIsolateToken);
  if (Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final sendPort = request.sendPort;
  try {
    final db = await AppDatabase.instance;
    final songDao = SongDao(db);
    final albumDao = AlbumDao(db);
    final artistDao = ArtistDao(db);

    final coversDir = Directory(p.join((await getApplicationSupportDirectory()).path, 'covers'));
    if (!await coversDir.exists()) await coversDir.create(recursive: true);

    // Phase 1: collect candidate file paths (cheap — no tag reads), plus
    // any dates the platform can give us up front. On Android, discovery
    // goes through MediaStore instead of walking folders — the folder
    // picker (Storage Access Framework) can't reach many real-world
    // locations (WhatsApp Audio, Downloads, other apps' music folders)
    // that MediaStore + READ_MEDIA_AUDIO can. Windows keeps the direct
    // filesystem walk. Either way, scan_roots (if any) and excluded_folders
    // apply as filters afterward, and voice-memo heuristics apply to both.
    final candidates = <String>[];
    final mediaStoreDateAdded = <String, DateTime>{};
    final mediaStoreDurationMs = <String, int>{};

    if (Platform.isAndroid) {
      final mediaStoreFiles = await MediaStoreScanner.queryAudioFiles();
      for (final file in mediaStoreFiles) {
        final path = file.path;
        if (!kSupportedAudioExtensions.contains(p.extension(path).toLowerCase())) continue;
        // Empty scan_roots means "no restriction" on Android — MediaStore
        // already covers everything, matching how other music apps behave.
        if (request.rootPaths.isNotEmpty && !isPathUnderAnyRoot(path, request.rootPaths)) continue;
        if (isPathUnderAnyRoot(path, request.excludedPaths)) continue;
        if (_isInVoiceMemoFolder(path)) continue;
        // MediaStore's index can lag behind actual deletions.
        if (!await File(path).exists()) continue;
        candidates.add(path);
        mediaStoreDateAdded[path] = file.dateAdded;
        if (file.durationMs != null) mediaStoreDurationMs[path] = file.durationMs!;
      }
    } else {
      for (final root in request.rootPaths) {
        final dir = Directory(root);
        if (!await dir.exists()) continue;
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is! File) continue;
          final path = entity.path;
          if (!kSupportedAudioExtensions.contains(p.extension(path).toLowerCase())) continue;
          if (isPathUnderAnyRoot(path, request.excludedPaths)) continue;
          if (_isInVoiceMemoFolder(path)) continue;
          candidates.add(path);
        }
      }
    }

    final total = candidates.length;
    var scanned = 0;
    var inserted = 0;
    var updated = 0;

    final existingByPath = {for (final s in await songDao.getAllRaw()) s.path: s};
    final seenPaths = <String>{};

    for (final path in candidates) {
      scanned++;
      sendPort.send(ScanProgress(scanned: scanned, total: total, currentPath: path));

      final file = File(path);
      final stat = await file.stat();
      final lastModified = stat.modified;
      final existing = existingByPath[path];
      seenPaths.add(path);

      final looksLikeVoiceMemoName =
          _kVoiceMemoFilenamePattern.hasMatch(p.basenameWithoutExtension(path));

      // Skip re-reading tags for files that haven't changed since last
      // scan — except when the existing row still has an unknown duration
      // or a voice-recorder-style filename, so a rescan actually fixes
      // already-scanned bug 8a/8b cases instead of leaving them stuck
      // until the file itself is touched.
      if (existing != null &&
          !existing.isMissing &&
          existing.lastModified != null &&
          !lastModified.isAfter(existing.lastModified!) &&
          (existing.durationMs ?? 0) > 0 &&
          !looksLikeVoiceMemoName) {
        continue;
      }

      Tag? tag;
      try {
        tag = await AudioTags.read(path);
      } catch (_) {
        tag = null;
      }

      // Bug 8a: audiotags returns 0/null duration for some files —
      // MediaStore's own indexer usually already has an accurate one.
      final tagDurationMs = tag?.duration != null && tag!.duration! > 0 ? tag.duration! * 1000 : null;
      final durationMs = tagDurationMs ?? mediaStoreDurationMs[path];

      // Voice-memo heuristic (b): short-or-unknown-duration untagged
      // clips, or a voice-recorder-style timestamp filename with no
      // artist tag. A missing duration is treated the same as "short" —
      // failing to read a duration at all is far more common for voice
      // memos (minimal/no container metadata) than for real music.
      final hasArtist = (tag?.trackArtist ?? '').trim().isNotEmpty;
      final hasAlbum = (tag?.album ?? '').trim().isNotEmpty;
      final shortOrUnknownDuration = durationMs == null || durationMs < 60000;
      if (!hasArtist && !hasAlbum && shortOrUnknownDuration) {
        continue;
      }
      if (!hasArtist && looksLikeVoiceMemoName) {
        continue;
      }

      final artistName = tag?.trackArtist?.trim().isEmpty ?? true ? null : tag!.trackArtist!.trim();
      final albumName = tag?.album?.trim().isEmpty ?? true ? null : tag!.album!.trim();

      final artistId = await artistDao.upsert(artistName);
      int? albumId;
      String? coverArtPath;
      if (albumName != null) {
        albumId = await albumDao.upsert(Album(name: albumName, artist: artistName, year: tag?.year));
        // Windows regression investigation (2026-09-04): a single album's
        // cover write failing (observed: PathAccessException/"Access is
        // denied" writing covers/{id}.jpg — the running app's own CoverArt
        // widget can hold a transient read handle on that exact file while
        // this isolate tries to overwrite it) used to propagate all the way
        // out to the scan's top-level catch, aborting the ENTIRE scan and
        // leaving every other album's cover unresolved too. Cover art is
        // best-effort per song now: a failure here just leaves this song's
        // album without art for this pass (retried automatically next scan,
        // same as "no art found") instead of failing the whole library scan.
        try {
          coverArtPath = await _ensureCoverArt(
            albumId: albumId,
            albumDao: albumDao,
            coversDir: coversDir,
            sourceFilePath: path,
            embeddedPictureBytes:
                tag != null && tag.pictures.isNotEmpty ? tag.pictures.first.bytes : null,
          );
        } catch (e) {
          _logger.w('[cover_art] failed for album=$albumId path=$path: $e');
          coverArtPath = null;
        }
      }

      final song = Song(
        id: existing?.id,
        path: path,
        title: tag?.title,
        artist: artistName,
        album: albumName,
        albumArtist: tag?.albumArtist,
        genre: tag?.genre,
        year: tag?.year,
        trackNumber: tag?.trackNumber,
        discNumber: tag?.discNumber,
        durationMs: durationMs,
        fileSize: stat.size,
        format: p.extension(path).replaceFirst('.', '').toUpperCase(),
        // MediaStore knows when a file actually landed on the device —
        // more accurate than "now" for songs discovered for the first time
        // that already existed on the phone before this app did.
        dateAdded: existing?.dateAdded ?? mediaStoreDateAdded[path] ?? DateTime.now(),
        lastModified: lastModified,
        playCount: existing?.playCount ?? 0,
        lastPlayedAt: existing?.lastPlayedAt,
        isExcluded: existing?.isExcluded ?? false,
        albumId: albumId,
        artistId: artistId,
        isMissing: false,
      );

      if (existing == null) {
        await songDao.insert(song);
        inserted++;
      } else {
        await songDao.update(song);
        updated++;
      }

      unawaited(_maybeUpdateAlbumCover(albumId, coverArtPath, albumDao));
    }

    // Reconcile: anything in the DB but not seen this pass is soft-deleted.
    var missing = 0;
    for (final entry in existingByPath.entries) {
      if (!seenPaths.contains(entry.key) && !entry.value.isMissing && entry.value.id != null) {
        await songDao.markMissing(entry.value.id!);
        missing++;
      }
    }

    sendPort.send(ScanProgress(
      scanned: total,
      total: total,
      isDone: true,
      inserted: inserted,
      updated: updated,
      missing: missing,
    ));
  } catch (e) {
    sendPort.send(ScanProgress(scanned: 0, total: 0, error: e.toString(), isDone: true));
  }
}

Future<void> _maybeUpdateAlbumCover(int? albumId, String? coverArtPath, AlbumDao albumDao) async {
  if (albumId == null || coverArtPath == null) return;
  final album = await albumDao.getById(albumId);
  if (album != null && album.coverArtPath == null) {
    await albumDao.setCoverArtPath(albumId, coverArtPath);
  }
}

/// Resolves cover art for an album the first time it's seen: embedded
/// picture bytes first, else a `cover.jpg`/`folder.jpg` sitting next to the
/// audio file. Writes to `covers/{album_id}.jpg` in app documents.
Future<String?> _ensureCoverArt({
  required int albumId,
  required AlbumDao albumDao,
  required Directory coversDir,
  required String sourceFilePath,
  required List<int>? embeddedPictureBytes,
}) async {
  final existing = await albumDao.getById(albumId);
  if (existing?.coverArtPath != null) return existing!.coverArtPath;

  final destPath = p.join(coversDir.path, '$albumId.jpg');

  if (embeddedPictureBytes != null && embeddedPictureBytes.isNotEmpty) {
    final resized = _resizeAndLog(embeddedPictureBytes, albumId: albumId, sourceLabel: 'embedded');
    await _writeCoverArtWithRetry(destPath, resized);
    return destPath;
  }

  final sourceDir = p.dirname(sourceFilePath);
  for (final name in const ['cover.jpg', 'Cover.jpg', 'folder.jpg', 'Folder.jpg']) {
    final candidate = File(p.join(sourceDir, name));
    if (await candidate.exists()) {
      final resized = _resizeAndLog(
        await candidate.readAsBytes(),
        albumId: albumId,
        sourceLabel: name,
      );
      await _writeCoverArtWithRetry(destPath, resized);
      return destPath;
    }
  }

  return null;
}

/// Writes [bytes] to [destPath], retrying a couple of times on a transient
/// Windows file-access error before giving up — Windows regression
/// investigation (2026-09-04): a `covers/{id}.jpg` write can momentarily
/// collide with the running app's own `CoverArt` widget holding a read
/// handle on that exact file (Windows' file locking is stricter about
/// concurrent access than the platforms this codebase mostly runs on), which
/// surfaces as `PathAccessException`/"Access is denied" — usually gone a few
/// hundred milliseconds later once that read completes. The caller still
/// treats a persistent failure as non-fatal to the rest of the scan (see the
/// call site's `try`/`catch`); this just avoids needing an entire second
/// manual rescan for what's typically a one-frame timing collision.
Future<void> _writeCoverArtWithRetry(String destPath, Uint8List bytes) async {
  const maxAttempts = 3;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      await File(destPath).writeAsBytes(bytes, flush: true);
      return;
    } catch (e) {
      if (attempt == maxAttempts) rethrow;
      _logger.w('[cover_art] write attempt $attempt failed for $destPath, retrying: $e');
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }
}

// TODO(cover-art-resize-audit): remove alongside the log-count fields above
// once the resize is confirmed working on-device.
Uint8List _resizeAndLog(List<int> sourceBytes, {required int albumId, required String sourceLabel}) {
  final resized = resizeCoverArt(sourceBytes);
  if (_coverArtResizeLogCount < _kCoverArtResizeLogLimit) {
    _coverArtResizeLogCount++;
    final before = img.decodeImage(Uint8List.fromList(sourceBytes));
    final after = img.decodeImage(resized);
    _logger.i(
      '[cover_art] album=$albumId source=$sourceLabel '
      'originalDimensions=${before?.width}x${before?.height} originalBytes=${sourceBytes.length} '
      'resizedDimensions=${after?.width}x${after?.height} resizedBytes=${resized.length}',
    );
  }
  return resized;
}

bool _isInVoiceMemoFolder(String path) {
  final segments = p.split(p.dirname(path)).map((s) => s.toLowerCase());
  for (final segment in segments) {
    if (_kVoiceMemoFolderNames.contains(segment)) return true;
    if (segment.contains('recording')) return true;
  }
  return false;
}
