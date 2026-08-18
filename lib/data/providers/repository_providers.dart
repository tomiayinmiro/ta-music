import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/album_repository.dart';
import '../repositories/artist_repository.dart';
import '../repositories/favorite_repository.dart';
import '../repositories/library_repository.dart';
import '../repositories/playlist_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/song_repository.dart';
import '../services/stats_service.dart';
import 'database_providers.dart';

// Hand-written providers rather than `@riverpod` codegen — see
// `lib/data/models/song.dart` for why.

final songRepositoryProvider = FutureProvider<SongRepository>((ref) async {
  return SongRepository(
    await ref.watch(songDaoProvider.future),
    await ref.watch(playHistoryDaoProvider.future),
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
  );
});

final settingsRepositoryProvider = FutureProvider<SettingsRepository>((ref) async {
  return SettingsRepository(await ref.watch(settingsDaoProvider.future));
});
