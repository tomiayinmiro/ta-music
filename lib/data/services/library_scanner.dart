import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:audiotags/audiotags.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show sqfliteFfiInit, databaseFactory, databaseFactoryFfi;

import '../database/daos/album_dao.dart';
import '../database/daos/artist_dao.dart';
import '../database/daos/song_dao.dart';
import '../database/database.dart';
import '../models/album.dart';
import '../models/song.dart';

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

    final excludedNormalized = request.excludedPaths.map(_normalize).toList();

    // Phase 1: walk and collect candidate file paths (cheap — no tag reads).
    final candidates = <String>[];
    for (final root in request.rootPaths) {
      final dir = Directory(root);
      if (!await dir.exists()) continue;
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final path = entity.path;
        if (!kSupportedAudioExtensions.contains(p.extension(path).toLowerCase())) continue;
        if (_isUnderAny(path, excludedNormalized)) continue;
        if (_isInVoiceMemoFolder(path)) continue;
        candidates.add(path);
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

      // Skip re-reading tags for files that haven't changed since last scan.
      if (existing != null &&
          !existing.isMissing &&
          existing.lastModified != null &&
          !lastModified.isAfter(existing.lastModified!)) {
        continue;
      }

      Tag? tag;
      try {
        tag = await AudioTags.read(path);
      } catch (_) {
        tag = null;
      }

      // Voice-memo heuristic (b): short, untagged clips.
      final durationMs = tag?.duration != null ? tag!.duration! * 1000 : null;
      final hasArtist = (tag?.trackArtist ?? '').trim().isNotEmpty;
      final hasAlbum = (tag?.album ?? '').trim().isNotEmpty;
      if (durationMs != null && durationMs < 60000 && !hasArtist && !hasAlbum) {
        continue;
      }

      final artistName = tag?.trackArtist?.trim().isEmpty ?? true ? null : tag!.trackArtist!.trim();
      final albumName = tag?.album?.trim().isEmpty ?? true ? null : tag!.album!.trim();

      final artistId = await artistDao.upsert(artistName);
      int? albumId;
      String? coverArtPath;
      if (albumName != null) {
        albumId = await albumDao.upsert(Album(name: albumName, artist: artistName, year: tag?.year));
        coverArtPath = await _ensureCoverArt(
          albumId: albumId,
          albumDao: albumDao,
          coversDir: coversDir,
          sourceFilePath: path,
          embeddedPictureBytes: tag != null && tag.pictures.isNotEmpty ? tag.pictures.first.bytes : null,
        );
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
        dateAdded: existing?.dateAdded ?? DateTime.now(),
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
    await File(destPath).writeAsBytes(embeddedPictureBytes, flush: true);
    return destPath;
  }

  final sourceDir = p.dirname(sourceFilePath);
  for (final name in const ['cover.jpg', 'Cover.jpg', 'folder.jpg', 'Folder.jpg']) {
    final candidate = File(p.join(sourceDir, name));
    if (await candidate.exists()) {
      await candidate.copy(destPath);
      return destPath;
    }
  }

  return null;
}

bool _isInVoiceMemoFolder(String path) {
  final segments = p.split(p.dirname(path)).map((s) => s.toLowerCase());
  for (final segment in segments) {
    if (_kVoiceMemoFolderNames.contains(segment)) return true;
    if (segment.contains('recording')) return true;
  }
  return false;
}

String _normalize(String path) => p.normalize(path).toLowerCase();

bool _isUnderAny(String path, List<String> normalizedRoots) {
  final normalizedPath = _normalize(path);
  for (final root in normalizedRoots) {
    if (normalizedPath == root || normalizedPath.startsWith('$root${Platform.pathSeparator}')) {
      return true;
    }
  }
  return false;
}
