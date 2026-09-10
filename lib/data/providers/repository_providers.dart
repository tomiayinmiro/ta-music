import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/translation_constants.dart';
import '../repositories/album_repository.dart';
import '../repositories/artist_repository.dart';
import '../repositories/backup_repository.dart';
import '../repositories/cache_management_repository.dart';
import '../repositories/eq_preset_repository.dart';
import '../repositories/favorite_repository.dart';
import '../repositories/library_repository.dart';
import '../repositories/lyrics_repository.dart';
import '../repositories/playback_state_repository.dart';
import '../repositories/playlist_repository.dart';
import '../repositories/recommendation_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/song_repository.dart';
import '../repositories/translation_repository.dart';
import '../services/aura_service.dart';
import '../services/stats_service.dart';
import 'database_providers.dart';
import 'network_providers.dart';

// Hand-written providers rather than `@riverpod` codegen — see
// `lib/data/models/song.dart` for why.

final songRepositoryProvider = FutureProvider<SongRepository>((ref) async {
  return SongRepository(
    await ref.watch(songDaoProvider.future),
    await ref.watch(playHistoryDaoProvider.future),
    await ref.watch(listeningSegmentDaoProvider.future),
  );
});

final albumRepositoryProvider = FutureProvider<AlbumRepository>((ref) async {
  return AlbumRepository(await ref.watch(albumDaoProvider.future));
});

final artistRepositoryProvider = FutureProvider<ArtistRepository>((ref) async {
  return ArtistRepository(await ref.watch(artistDaoProvider.future));
});

final favoriteRepositoryProvider = FutureProvider<FavoriteRepository>((ref) async {
  return FavoriteRepository(await ref.watch(favoriteDaoProvider.future));
});

final playlistRepositoryProvider = FutureProvider<PlaylistRepository>((ref) async {
  return PlaylistRepository(await ref.watch(playlistDaoProvider.future));
});

final libraryRepositoryProvider = FutureProvider<LibraryRepository>((ref) async {
  return LibraryRepository(
    scanRootDao: await ref.watch(scanRootDaoProvider.future),
    excludedFolderDao: await ref.watch(excludedFolderDaoProvider.future),
    songDao: await ref.watch(songDaoProvider.future),
  );
});

final statsServiceProvider = FutureProvider<StatsService>((ref) async {
  return StatsService(
    playHistoryDao: await ref.watch(playHistoryDaoProvider.future),
    songDao: await ref.watch(songDaoProvider.future),
    listeningSegmentDao: await ref.watch(listeningSegmentDaoProvider.future),
  );
});

final settingsRepositoryProvider = FutureProvider<SettingsRepository>((ref) async {
  return SettingsRepository(await ref.watch(settingsDaoProvider.future));
});

final playbackStateRepositoryProvider = FutureProvider<PlaybackStateRepository>((ref) async {
  return PlaybackStateRepository(await ref.watch(playbackStateDaoProvider.future));
});

final auraServiceProvider = FutureProvider<AuraService>((ref) async {
  return AuraService(
    auraStateDao: await ref.watch(auraStateDaoProvider.future),
    playHistoryDao: await ref.watch(playHistoryDaoProvider.future),
    songDao: await ref.watch(songDaoProvider.future),
    listeningSegmentDao: await ref.watch(listeningSegmentDaoProvider.future),
    settingsDao: await ref.watch(settingsDaoProvider.future),
  );
});

final lyricsRepositoryProvider = FutureProvider<LyricsRepository>((ref) async {
  return LyricsRepository(
    dio: ref.watch(dioProvider),
    cacheDao: await ref.watch(lyricsCacheDaoProvider.future),
    lrclibClient: ref.watch(lrclibClientProvider),
    localLrcFileReader: ref.watch(localLrcFileReaderProvider),
  );
});

final translationRepositoryProvider = FutureProvider<TranslationRepository>((ref) async {
  return TranslationRepository(
    client: ref.watch(translationClientProvider),
    cacheDao: await ref.watch(translationsCacheDaoProvider.future),
    email: myMemoryContactEmail,
  );
});

final recommendationRepositoryProvider = FutureProvider<RecommendationRepository>((ref) async {
  return RecommendationRepository(
    await ref.watch(songDaoProvider.future),
    await ref.watch(playHistoryDaoProvider.future),
    await ref.watch(favoriteDaoProvider.future),
    await ref.watch(recommendationSeedCacheDaoProvider.future),
  );
});

final eqPresetRepositoryProvider = FutureProvider<EqPresetRepository>((ref) async {
  return EqPresetRepository(await ref.watch(eqPresetDaoProvider.future));
});

final backupRepositoryProvider = FutureProvider<BackupRepository>((ref) async {
  return BackupRepository(
    songDao: await ref.watch(songDaoProvider.future),
    playlistDao: await ref.watch(playlistDaoProvider.future),
    favoriteDao: await ref.watch(favoriteDaoProvider.future),
    playHistoryDao: await ref.watch(playHistoryDaoProvider.future),
    auraStateDao: await ref.watch(auraStateDaoProvider.future),
    lyricsCacheDao: await ref.watch(lyricsCacheDaoProvider.future),
    recommendationSeedCacheDao: await ref.watch(recommendationSeedCacheDaoProvider.future),
    settingsRepository: await ref.watch(settingsRepositoryProvider.future),
  );
});

final cacheManagementRepositoryProvider = FutureProvider<CacheManagementRepository>((ref) async {
  return CacheManagementRepository(
    albumDao: await ref.watch(albumDaoProvider.future),
    lyricsCacheDao: await ref.watch(lyricsCacheDaoProvider.future),
    translationsCacheDao: await ref.watch(translationsCacheDaoProvider.future),
    recommendationSeedCacheDao: await ref.watch(recommendationSeedCacheDaoProvider.future),
  );
});
