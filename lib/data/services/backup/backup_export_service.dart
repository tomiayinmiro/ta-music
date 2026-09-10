import '../../database/daos/aura_state_dao.dart';
import '../../database/daos/favorite_dao.dart';
import '../../database/daos/lyrics_cache_dao.dart';
import '../../database/daos/play_history_dao.dart';
import '../../database/daos/playlist_dao.dart';
import '../../database/daos/recommendation_seed_cache_dao.dart';
import '../../database/daos/song_dao.dart';
import '../../models/song.dart';
import '../../repositories/settings_repository.dart';
import 'backup_models.dart';

/// Assembles a [BackupPayload] from every DAO/repository the "Backup &
/// Restore" export covers. Pure data assembly — no file I/O, no JSON
/// encoding (the caller, `BackupRepository`, handles those so the encode
/// step can be offloaded to an isolate without dragging sqflite along).
class BackupExportService {
  BackupExportService({
    required this._songDao,
    required this._playlistDao,
    required this._favoriteDao,
    required this._playHistoryDao,
    required this._auraStateDao,
    required this._lyricsCacheDao,
    required this._recommendationSeedCacheDao,
    required this._settingsRepository,
  });

  final SongDao _songDao;
  final PlaylistDao _playlistDao;
  final FavoriteDao _favoriteDao;
  final PlayHistoryDao _playHistoryDao;
  final AuraStateDao _auraStateDao;
  final LyricsCacheDao _lyricsCacheDao;
  final RecommendationSeedCacheDao _recommendationSeedCacheDao;
  final SettingsRepository _settingsRepository;

  Future<BackupPayload> buildPayload({required String appVersion}) async {
    // getAllRaw (not getAllVisible) so an excluded/soft-deleted-but-not-yet-
    // rescanned song can still be referenced and exported — it may well
    // resolve again on the importing device.
    final allSongs = await _songDao.getAllRaw();
    final songById = {for (final s in allSongs) if (s.id != null) s.id!: s};

    final playlists = await _playlistDao.getAll();
    final backupPlaylists = <BackupPlaylist>[];
    for (final playlist in playlists) {
      if (playlist.id == null) continue;
      final membership = await _playlistDao.getMembershipRows(playlist.id!);
      final songs = <BackupPlaylistSong>[];
      for (final entry in membership) {
        final song = songById[entry.songId];
        if (song == null) continue;
        songs.add(
          BackupPlaylistSong(
            song: _toRef(song),
            position: entry.position,
            addedAtMs: entry.addedAt.millisecondsSinceEpoch,
          ),
        );
      }
      backupPlaylists.add(
        BackupPlaylist(
          name: playlist.name,
          description: playlist.description,
          createdAtMs: playlist.createdAt.millisecondsSinceEpoch,
          updatedAtMs: playlist.updatedAt.millisecondsSinceEpoch,
          songs: songs,
        ),
      );
    }

    final favorites = await _favoriteDao.getAll();
    final backupFavorites = <BackupFavorite>[];
    for (final favorite in favorites) {
      final song = songById[favorite.songId];
      if (song == null) continue;
      backupFavorites.add(
        BackupFavorite(
          song: _toRef(song),
          addedAtMs: favorite.addedAt.millisecondsSinceEpoch,
          isManual: favorite.isManual,
        ),
      );
    }

    final history = await _playHistoryDao.getAll();
    final backupHistory = <BackupPlayHistoryEntry>[];
    for (final entry in history) {
      final song = songById[entry.songId];
      if (song == null) continue;
      backupHistory.add(
        BackupPlayHistoryEntry(
          song: _toRef(song),
          playedAtMs: entry.playedAt.millisecondsSinceEpoch,
          completed: entry.completed,
        ),
      );
    }

    final auraRow = await _auraStateDao.load();
    final auraState = auraRow == null
        ? BackupAuraState.empty
        : BackupAuraState(
            totalListeningMinsCached: auraRow['total_listening_mins_cached'] as int? ?? 0,
            currentLevel: auraRow['current_level'] as int? ?? 1,
            lastShownLevel: auraRow['last_shown_level'] as int? ?? 0,
          );

    final manualLyricRows = await _lyricsCacheDao.findUserAdded();
    final manualLyrics = [
      for (final row in manualLyricRows)
        BackupManualLyric(
          artistKey: row['artist_key'] as String,
          titleKey: row['title_key'] as String,
          displayArtist: row['display_artist'] as String?,
          displayTitle: row['display_title'] as String?,
          hasSyncedTiming: (row['has_synced_timing'] as int? ?? 0) != 0,
          syncedLyricsLrc: row['synced_lyrics_lrc'] as String?,
          plainLyrics: row['plain_lyrics'] as String?,
          fetchedAtMs: row['fetched_at'] as int,
        ),
    ];

    BackupRecommendationSeed? recommendationSeed;
    final seed = await _recommendationSeedCacheDao.get();
    if (seed != null) {
      final song = songById[seed.songId];
      if (song != null) {
        recommendationSeed = BackupRecommendationSeed(
          song: _toRef(song),
          selectedAtMs: seed.selectedAt.millisecondsSinceEpoch,
          expiresAtMs: seed.expiresAt.millisecondsSinceEpoch,
        );
      }
    }

    final preferences = BackupPreferences(
      playbackSpeed: await _settingsRepository.getPlaybackSpeed(),
      translationTargetLanguage: await _settingsRepository.getTranslationTargetLanguage(),
      resumeAfterInterruption: await _settingsRepository.getResumeAfterInterruption(),
      recommendationsEnabled: await _settingsRepository.getRecommendationsEnabled(),
    );

    final now = DateTime.now();
    return BackupPayload(
      backupFormatVersion: kBackupFormatVersion,
      appVersion: appVersion,
      exportedAtMs: now.millisecondsSinceEpoch,
      playlists: backupPlaylists,
      favorites: backupFavorites,
      playHistory: backupHistory,
      auraState: auraState,
      recommendationSeed: recommendationSeed,
      manualLyrics: manualLyrics,
      preferences: preferences,
    );
  }

  BackupSongRef _toRef(Song song) => BackupSongRef(
    path: song.path,
    title: song.title,
    artist: song.artist,
    album: song.album,
    durationMs: song.durationMs,
  );
}
