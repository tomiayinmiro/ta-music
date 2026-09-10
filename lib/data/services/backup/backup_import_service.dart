import 'package:logger/logger.dart';

import '../../database/daos/favorite_dao.dart';
import '../../database/daos/lyrics_cache_dao.dart';
import '../../database/daos/play_history_dao.dart';
import '../../database/daos/playlist_dao.dart';
import '../../database/daos/recommendation_seed_cache_dao.dart';
import '../../database/daos/song_dao.dart';
import '../../models/play_history_entry.dart';
import '../../models/playlist.dart';
import '../../models/recommendation_seed_cache.dart';
import '../../repositories/settings_repository.dart';
import 'backup_models.dart';
import 'song_matcher.dart';

/// Counts + a short debug log for the post-import summary dialog. `skipped`
/// covers every reason an entry didn't make it in: no local song matched,
/// a duplicate favorite, a manual lyric that already exists locally, or a
/// malformed entry the backup file itself carried (see
/// [BackupPayload.parseWarnings]).
class ImportSummary {
  const ImportSummary({
    required this.playlistsImported,
    required this.favoritesImported,
    required this.playsImported,
    required this.manualLyricsImported,
    required this.skipped,
    required this.skipLog,
  });

  final int playlistsImported;
  final int favoritesImported;
  final int playsImported;
  final int manualLyricsImported;
  final int skipped;
  final List<String> skipLog;
}

/// Applies a validated [BackupPayload] onto this device's data, additively —
/// see CLAUDE.md's Backup & Restore decisions for the exact per-category
/// rules (playlist name collisions get "(imported)", favorites/manual
/// lyrics dedupe by skipping, history always appends, preferences only fill
/// in currently-unset keys).
class BackupImportService {
  BackupImportService({
    required this._songDao,
    required this._playlistDao,
    required this._favoriteDao,
    required this._playHistoryDao,
    required this._lyricsCacheDao,
    required this._recommendationSeedCacheDao,
    required this._settingsRepository,
  });

  final SongDao _songDao;
  final PlaylistDao _playlistDao;
  final FavoriteDao _favoriteDao;
  final PlayHistoryDao _playHistoryDao;
  final LyricsCacheDao _lyricsCacheDao;
  final RecommendationSeedCacheDao _recommendationSeedCacheDao;
  final SettingsRepository _settingsRepository;

  final _logger = Logger();

  Future<ImportSummary> import(BackupPayload payload) async {
    final allSongs = await _songDao.getAllRaw();
    final index = SongMatchIndex(allSongs);

    final skipLog = <String>[...payload.parseWarnings];
    var skipped = payload.parseWarnings.length;

    var playlistsImported = 0;
    final existingNames = (await _playlistDao.getAll()).map((p) => p.name.trim().toLowerCase()).toSet();
    for (final backupPlaylist in payload.playlists) {
      final songIds = <int>[];
      for (final entry in backupPlaylist.songs) {
        final matched = index.match(entry.song);
        if (matched?.id == null) {
          skipped++;
          skipLog.add('Playlist "${backupPlaylist.name}": no local match for ${entry.song.path}');
          continue;
        }
        songIds.add(matched!.id!);
      }

      final uniqueName = _uniqueName(backupPlaylist.name, existingNames);
      existingNames.add(uniqueName.toLowerCase());
      final playlistId = await _playlistDao.insert(
        Playlist(
          name: uniqueName,
          description: backupPlaylist.description,
          createdAt: DateTime.fromMillisecondsSinceEpoch(backupPlaylist.createdAtMs),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(backupPlaylist.updatedAtMs),
        ),
      );
      await _playlistDao.addSongs(playlistId, songIds);
      playlistsImported++;
    }

    var favoritesImported = 0;
    for (final backupFavorite in payload.favorites) {
      final matched = index.match(backupFavorite.song);
      if (matched?.id == null) {
        skipped++;
        skipLog.add('Favorite: no local match for ${backupFavorite.song.path}');
        continue;
      }
      if (await _favoriteDao.isFavorite(matched!.id!)) {
        skipped++;
        skipLog.add('Favorite "${backupFavorite.song.title}": already a favorite, skipped');
        continue;
      }
      await _favoriteDao.add(matched.id!, isManual: backupFavorite.isManual);
      favoritesImported++;
    }

    final historyEntries = <PlayHistoryEntry>[];
    for (final entry in payload.playHistory) {
      final matched = index.match(entry.song);
      if (matched?.id == null) {
        skipped++;
        skipLog.add('Play history: no local match for ${entry.song.path}');
        continue;
      }
      historyEntries.add(
        PlayHistoryEntry(
          songId: matched!.id!,
          playedAt: DateTime.fromMillisecondsSinceEpoch(entry.playedAtMs),
          completed: entry.completed,
        ),
      );
    }
    await _playHistoryDao.insertBatch(historyEntries);
    final playsImported = historyEntries.length;

    var manualLyricsImported = 0;
    for (final lyric in payload.manualLyrics) {
      final existing = await _lyricsCacheDao.find(lyric.artistKey, lyric.titleKey);
      if (existing != null) {
        skipped++;
        skipLog.add('Manual lyrics for "${lyric.titleKey}": kept existing entry');
        continue;
      }
      await _lyricsCacheDao.upsert(
        artistKey: lyric.artistKey,
        titleKey: lyric.titleKey,
        source: 'user_added',
        hasSyncedTiming: lyric.hasSyncedTiming,
        syncedLyricsLrc: lyric.syncedLyricsLrc,
        plainLyrics: lyric.plainLyrics,
        displayArtist: lyric.displayArtist,
        displayTitle: lyric.displayTitle,
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(lyric.fetchedAtMs),
      );
      manualLyricsImported++;
    }

    // Aura: additive offset only, never a direct write to aura_state — see
    // SettingsRepository.importedAuraMinutesOffsetKey's doc for why.
    if (payload.auraState.totalListeningMinsCached > 0) {
      await _settingsRepository.addImportedAuraMinutesOffset(payload.auraState.totalListeningMinsCached);
    }

    // Recommendation seed: best-effort, silently dropped if expired or
    // unmatched — it's disposable 1-hour cache, not user data, so it isn't
    // worth a skip-log entry.
    final seed = payload.recommendationSeed;
    if (seed != null && seed.expiresAtMs > DateTime.now().millisecondsSinceEpoch) {
      final matched = index.match(seed.song);
      if (matched?.id != null) {
        await _recommendationSeedCacheDao.set(
          RecommendationSeedCache(
            songId: matched!.id!,
            selectedAt: DateTime.fromMillisecondsSinceEpoch(seed.selectedAtMs),
            expiresAt: DateTime.fromMillisecondsSinceEpoch(seed.expiresAtMs),
          ),
        );
      }
    }

    await _settingsRepository.applyImportedPreferencesIfUnset(
      playbackSpeed: payload.preferences.playbackSpeed,
      translationTargetLanguage: payload.preferences.translationTargetLanguage,
      resumeAfterInterruption: payload.preferences.resumeAfterInterruption,
      recommendationsEnabled: payload.preferences.recommendationsEnabled,
    );

    _logger.i(
      '[backup_import] playlists=$playlistsImported favorites=$favoritesImported '
      'plays=$playsImported manualLyrics=$manualLyricsImported skipped=$skipped',
    );

    return ImportSummary(
      playlistsImported: playlistsImported,
      favoritesImported: favoritesImported,
      playsImported: playsImported,
      manualLyricsImported: manualLyricsImported,
      skipped: skipped,
      skipLog: skipLog,
    );
  }

  /// "Chill" colliding with an existing "Chill" becomes "Chill (imported)";
  /// a further collision (a second import of the same backup, say) counts
  /// up from there — "Chill (imported) (2)", "Chill (imported) (3)", ...
  String _uniqueName(String base, Set<String> existingLower) {
    final trimmedBase = base.trim();
    if (!existingLower.contains(trimmedBase.toLowerCase())) return trimmedBase;

    final imported = '$trimmedBase (imported)';
    if (!existingLower.contains(imported.toLowerCase())) return imported;

    var i = 2;
    while (existingLower.contains('$imported ($i)'.toLowerCase())) {
      i++;
    }
    return '$imported ($i)';
  }
}
