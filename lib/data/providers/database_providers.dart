import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../database/daos/album_dao.dart';
import '../database/daos/artist_dao.dart';
import '../database/daos/aura_state_dao.dart';
import '../database/daos/excluded_folder_dao.dart';
import '../database/daos/favorite_dao.dart';
import '../database/daos/listening_segment_dao.dart';
import '../database/daos/lyrics_cache_dao.dart';
import '../database/daos/play_history_dao.dart';
import '../database/daos/playlist_dao.dart';
import '../database/daos/playback_state_dao.dart';
import '../database/daos/scan_root_dao.dart';
import '../database/daos/settings_dao.dart';
import '../database/daos/song_dao.dart';
import '../database/daos/translations_cache_dao.dart';
import '../database/database.dart';

// Hand-written providers rather than `@riverpod` codegen — see
// `lib/data/models/song.dart` for why (build_runner is broken against the
// current Dart SDK given this project's pinned analyzer version).

final appDatabaseProvider = FutureProvider<Database>((ref) => AppDatabase.instance);

final songDaoProvider = FutureProvider<SongDao>((ref) async {
  return SongDao(await ref.watch(appDatabaseProvider.future));
});

final albumDaoProvider = FutureProvider<AlbumDao>((ref) async {
  return AlbumDao(await ref.watch(appDatabaseProvider.future));
});

final artistDaoProvider = FutureProvider<ArtistDao>((ref) async {
  return ArtistDao(await ref.watch(appDatabaseProvider.future));
});

final favoriteDaoProvider = FutureProvider<FavoriteDao>((ref) async {
  return FavoriteDao(await ref.watch(appDatabaseProvider.future));
});

final playlistDaoProvider = FutureProvider<PlaylistDao>((ref) async {
  return PlaylistDao(await ref.watch(appDatabaseProvider.future));
});

final playHistoryDaoProvider = FutureProvider<PlayHistoryDao>((ref) async {
  return PlayHistoryDao(await ref.watch(appDatabaseProvider.future));
});

final scanRootDaoProvider = FutureProvider<ScanRootDao>((ref) async {
  return ScanRootDao(await ref.watch(appDatabaseProvider.future));
});

final excludedFolderDaoProvider = FutureProvider<ExcludedFolderDao>((ref) async {
  return ExcludedFolderDao(await ref.watch(appDatabaseProvider.future));
});

final settingsDaoProvider = FutureProvider<SettingsDao>((ref) async {
  return SettingsDao(await ref.watch(appDatabaseProvider.future));
});

final playbackStateDaoProvider = FutureProvider<PlaybackStateDao>((ref) async {
  return PlaybackStateDao(await ref.watch(appDatabaseProvider.future));
});

final auraStateDaoProvider = FutureProvider<AuraStateDao>((ref) async {
  return AuraStateDao(await ref.watch(appDatabaseProvider.future));
});

final listeningSegmentDaoProvider = FutureProvider<ListeningSegmentDao>((ref) async {
  return ListeningSegmentDao(await ref.watch(appDatabaseProvider.future));
});

final lyricsCacheDaoProvider = FutureProvider<LyricsCacheDao>((ref) async {
  return LyricsCacheDao(await ref.watch(appDatabaseProvider.future));
});

final translationsCacheDaoProvider = FutureProvider<TranslationsCacheDao>((ref) async {
  return TranslationsCacheDao(await ref.watch(appDatabaseProvider.future));
});
