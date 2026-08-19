import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/database/daos/album_dao.dart';
import 'data/database/daos/play_history_dao.dart';
import 'data/database/daos/playback_state_dao.dart';
import 'data/database/daos/settings_dao.dart';
import 'data/database/daos/song_dao.dart';
import 'data/database/database.dart';
import 'data/providers/playback_providers.dart';
import 'data/repositories/album_repository.dart';
import 'data/repositories/playback_state_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/song_repository.dart';
import 'data/services/audio_service.dart';
import 'data/services/playback/audio_player_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initializeDatabaseFactory();

  // The AudioHandler is created here, before runApp, per audio_service's
  // documented pattern — it needs its own repository instances since
  // Riverpod's ProviderScope doesn't exist yet. Both hit the same
  // singleton AppDatabase/DatabaseChangeNotifier as the providers built
  // later, so writes from either side stay consistent.
  final db = await AppDatabase.instance;
  final songRepository = SongRepository(SongDao(db), PlayHistoryDao(db));
  final albumRepository = AlbumRepository(AlbumDao(db));
  final settingsRepository = SettingsRepository(SettingsDao(db));
  final playbackStateRepository = PlaybackStateRepository(PlaybackStateDao(db));

  final audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandler(
      songRepository: songRepository,
      albumRepository: albumRepository,
      settingsRepository: settingsRepository,
      playbackStateRepository: playbackStateRepository,
    ),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.tamusic.app.ta_music.playback',
      androidNotificationChannelName: 'TA MUSIC playback',
      // Must be paired — audio_service asserts on this. Android forces any
      // active foreground service's notification to be non-dismissible
      // regardless of androidNotificationOngoing, so "ongoing" only means
      // anything if the service can actually drop out of foreground state
      // on pause. Net effect: non-dismissible notification while playing
      // (lockscreen controls stay put), swipeable + wake lock released
      // once paused — same pattern Spotify/YouTube Music use.
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  // Bug 3 (device testing pass): restore the last-saved queue/position
  // before the UI ever shows, so the mini player and Now Playing screen
  // never render an initial "nothing playing" state that then jumps to
  // the restored song a frame later. Never starts playback — always
  // restores paused, per CLAUDE.md's "user chooses when to resume" rule.
  await audioHandler.restoreState();

  runApp(
    ProviderScope(
      overrides: [playbackServiceProvider.overrideWithValue(PlaybackService(audioHandler))],
      child: const App(),
    ),
  );
}
