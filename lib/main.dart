import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import 'app.dart';
import 'data/database/daos/album_dao.dart';
import 'data/database/daos/listening_segment_dao.dart';
import 'data/database/daos/lyrics_cache_dao.dart';
import 'data/database/daos/play_history_dao.dart';
import 'data/database/daos/playback_state_dao.dart';
import 'data/database/daos/settings_dao.dart';
import 'data/database/daos/song_dao.dart';
import 'data/database/database.dart';
import 'data/providers/playback_providers.dart';
import 'data/repositories/album_repository.dart';
import 'data/repositories/lyrics_repository.dart';
import 'data/repositories/playback_state_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/song_repository.dart';
import 'data/services/audio_service.dart';
import 'data/services/lyrics/lrclib_client.dart';
import 'data/services/lyrics/local_lrc_file_reader.dart';
import 'data/services/lyrics/lyrics_prefetch_service.dart';
import 'data/services/playback/audio_player_handler.dart';

final _log = Logger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initializeDatabaseFactory();

  // TODO(manual-lyrics-crash-audit): temporary instrumentation added
  // 2026-09-01 to chase a reproducible hang/crash entering the manual
  // lyrics editor for a specific song — see CLAUDE.md. Catches uncaught
  // framework errors (build/layout/paint) and platform/async errors that
  // a local try/catch in the editor flow wouldn't see. Remove once
  // root-caused.
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    _log.e(
      '[manual_lyrics] FlutterError.onError',
      error: details.exception,
      stackTrace: details.stack,
    );
    previousOnError?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    _log.e('[manual_lyrics] PlatformDispatcher.onError (uncaught async error)', error: error, stackTrace: stack);
    return false;
  };

  // The AudioHandler is created here, before runApp, per audio_service's
  // documented pattern — it needs its own repository instances since
  // Riverpod's ProviderScope doesn't exist yet. Both hit the same
  // singleton AppDatabase/DatabaseChangeNotifier as the providers built
  // later, so writes from either side stay consistent.
  final db = await AppDatabase.instance;
  final songRepository = SongRepository(SongDao(db), PlayHistoryDao(db), ListeningSegmentDao(db));
  final albumRepository = AlbumRepository(AlbumDao(db));
  final settingsRepository = SettingsRepository(SettingsDao(db));
  final playbackStateRepository = PlaybackStateRepository(PlaybackStateDao(db));
  final lyricsDio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));
  final lyricsRepository = LyricsRepository(
    dio: lyricsDio,
    cacheDao: LyricsCacheDao(db),
    lrclibClient: LrclibClient(lyricsDio),
    localLrcFileReader: LocalLrcFileReader(),
  );
  final lyricsPrefetchService = LyricsPrefetchService(repository: lyricsRepository);

  // TODO(notification-controls-audit): bracketing logging added 2026-08-27
  // to chase a one-off report of the Android notification showing
  // title/artist with no control buttons — see CLAUDE.md. Remove once
  // resolved or confidently ruled out.
  _log.i('[audio_service] AudioService.init starting');
  final audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandler(
      songRepository: songRepository,
      albumRepository: albumRepository,
      settingsRepository: settingsRepository,
      playbackStateRepository: playbackStateRepository,
      lyricsPrefetchService: lyricsPrefetchService,
    ),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.tamusic.app.ta_music.playback',
      androidNotificationChannelName: 'TA Music playback',
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
  _log.i('[audio_service] AudioService.init done');

  // Bug 3 (device testing pass): restore the last-saved queue/position
  // before the UI ever shows, so the mini player and Now Playing screen
  // never render an initial "nothing playing" state that then jumps to
  // the restored song a frame later. Never starts playback — always
  // restores paused, per CLAUDE.md's "user chooses when to resume" rule.
  _log.i('[audio_service] restoreState starting');
  await audioHandler.restoreState();
  _log.i('[audio_service] restoreState done');

  runApp(
    ProviderScope(
      overrides: [playbackServiceProvider.overrideWithValue(PlaybackService(audioHandler))],
      child: const App(),
    ),
  );
}
