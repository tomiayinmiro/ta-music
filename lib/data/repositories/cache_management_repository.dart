import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/daos/album_dao.dart';
import '../database/daos/lyrics_cache_dao.dart';
import '../database/daos/recommendation_seed_cache_dao.dart';
import '../database/daos/translations_cache_dao.dart';

/// Sizes (bytes) for the Settings "Storage & Cache" screen's per-type rows
/// and total-usage summary. Cover art is a real on-disk measurement; the
/// other three have no backing file, so their sizes are estimated from the
/// cached text columns' stored length — see each DAO's `cacheSizeBytes*`.
class CacheSizes {
  const CacheSizes({
    required this.coverArtBytes,
    required this.lyricsBytes,
    required this.translationsBytes,
    required this.recommendationsBytes,
  });

  final int coverArtBytes;
  final int lyricsBytes;
  final int translationsBytes;
  final int recommendationsBytes;

  int get totalBytes => coverArtBytes + lyricsBytes + translationsBytes + recommendationsBytes;
}

/// Computes and clears the app's four re-generatable caches — everything
/// the Storage & Cache screen shows. Deliberately separate from
/// `BackupRepository`: this covers data that's fine to lose (re-fetched or
/// re-extracted on demand), backup covers data that isn't.
class CacheManagementRepository {
  CacheManagementRepository({
    required this._albumDao,
    required this._lyricsCacheDao,
    required this._translationsCacheDao,
    required this._recommendationSeedCacheDao,
  });

  final AlbumDao _albumDao;
  final LyricsCacheDao _lyricsCacheDao;
  final TranslationsCacheDao _translationsCacheDao;
  final RecommendationSeedCacheDao _recommendationSeedCacheDao;

  final _logger = Logger();

  /// Same `covers/` directory `LibraryScanner` writes album art into, under
  /// application support — created if it doesn't exist yet (a fresh
  /// install that hasn't scanned) so callers never have to check first.
  Future<Directory> _coversDirectory() async {
    final dir = Directory(p.join((await getApplicationSupportDirectory()).path, 'covers'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<int> _coverArtBytes() async {
    final dir = await _coversDirectory();
    var total = 0;
    await for (final entity in dir.list()) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  Future<CacheSizes> computeSizes() async {
    return CacheSizes(
      coverArtBytes: await _coverArtBytes(),
      lyricsBytes: await _lyricsCacheDao.cacheSizeBytesExcludingUserAdded(),
      translationsBytes: await _translationsCacheDao.cacheSizeBytes(),
      recommendationsBytes: await _recommendationSeedCacheDao.cacheSizeBytes(),
    );
  }

  /// Deletes every extracted cover file and nulls `albums.cover_art_path`
  /// so the next library scan regenerates them — same mechanism
  /// `_migrationV11` used for the memory-usage fix, just user-triggered
  /// here instead of an automatic one-time migration. A single file's
  /// delete failing (e.g. a transient Windows lock — see CLAUDE.md's cover
  /// art investigation) doesn't abort the rest; it's logged and skipped,
  /// same non-fatal-per-item philosophy `LibraryScanner._ensureCoverArt`
  /// already uses for writes.
  Future<void> clearCoverArt() async {
    final dir = await _coversDirectory();
    var deleted = 0;
    var failed = 0;
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      try {
        await entity.delete();
        deleted++;
      } catch (e) {
        failed++;
        _logger.w('[cache_clear] failed to delete cover file ${entity.path}: $e');
      }
    }
    await _albumDao.clearAllCoverArtPaths();
    _logger.i('[cache_clear] album cover art: deleted=$deleted failed=$failed');
  }

  /// Preserves `source = 'user_added'` rows — see `LyricsCacheDao.
  /// clearAllExceptUserAdded`'s doc for why that split exists at all.
  Future<void> clearLyrics() async {
    await _lyricsCacheDao.clearAllExceptUserAdded();
    _logger.i('[cache_clear] cleared lyrics cache (user-added lyrics preserved)');
  }

  Future<void> clearTranslations() async {
    await _translationsCacheDao.clearAll();
    _logger.i('[cache_clear] cleared translations cache');
  }

  Future<void> clearRecommendations() async {
    await _recommendationSeedCacheDao.clear();
    _logger.i('[cache_clear] cleared recommendation seed cache');
  }

  Future<void> clearAll() async {
    await clearCoverArt();
    await clearLyrics();
    await clearTranslations();
    await clearRecommendations();
    _logger.i('[cache_clear] cleared all caches');
  }
}
