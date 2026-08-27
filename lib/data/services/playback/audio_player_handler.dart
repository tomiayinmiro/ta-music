import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleListener, AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rxdart/rxdart.dart';

import '../../models/song.dart';
import '../../repositories/album_repository.dart';
import '../../repositories/playback_state_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../repositories/song_repository.dart';
import '../lyrics/lyrics_prefetch_service.dart';
import 'listening_time_accumulator.dart';
import 'next_aware_shuffle_order.dart';
import 'playback_handler.dart';
import 'playback_models.dart';
import 'relative_queue_index.dart';

/// The single top-level `AudioHandler`, per `audio_service`'s documented
/// pattern — created once in `main()`, before `runApp`, via
/// `AudioService.init`. Owns the real `just_audio` player; everything else
/// in the app (including `PlaybackService`, its thin public wrapper) goes
/// through this. Queue mutation goes through `AudioPlayer`'s own
/// `*AudioSource*` methods directly (not a hand-held `ConcatenatingAudioSource`
/// — that constructor is deprecated as of this `just_audio` version in favor
/// of these).
///
/// Two parallel sources of truth are kept deliberately separate:
/// - `queue` / `mediaItem` (inherited `BehaviorSubject`s from
///   `BaseAudioHandler`) carry only what the OS needs for the lockscreen,
///   notification, and SMTC — title/artist/album/art/duration.
/// - [queueSongsStream] carries the full `Song` objects the rest of the app
///   actually works with, so `PlaybackService` never has to reconstruct a
///   `Song` out of a `MediaItem`.
class AudioPlayerHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler
    implements PlaybackHandler {
  AudioPlayerHandler({
    required this._songRepository,
    required this._albumRepository,
    required this._settingsRepository,
    required this._playbackStateRepository,
    required this._lyricsPrefetchService,
  }) {
    _init();
  }

  final SongRepository _songRepository;
  final AlbumRepository _albumRepository;
  final SettingsRepository _settingsRepository;
  final PlaybackStateRepository _playbackStateRepository;
  final LyricsPrefetchService _lyricsPrefetchService;

  final _logger = Logger();

  final _player = AudioPlayer();

  final _queueSongsSubject = BehaviorSubject<List<Song>>.seeded(const []);
  @override
  Stream<List<Song>> get queueSongsStream => _queueSongsSubject.stream;
  List<Song> get queueSongs => _queueSongsSubject.value;

  @override
  Stream<int?> get currentIndexStream => _player.currentIndexStream;
  int? get currentIndex => _player.currentIndex;

  @override
  Stream<Duration> get positionStream => _player.positionStream;
  @override
  Stream<Duration?> get durationStream => _player.durationStream;
  @override
  Duration? get duration => _player.duration;

  @override
  Stream<PlaybackStatus> get statusStream => _player.playerStateStream.map(_toStatus);
  PlaybackStatus get status => _toStatus(_player.playerState);

  @override
  Stream<bool> get shuffleModeStream => _player.shuffleModeEnabledStream;
  @override
  Stream<PlayerRepeatMode> get repeatModeStream => _player.loopModeStream.map(_toRepeatMode);

  @override
  bool get hasNext => _relativeIndex(1) != null;
  @override
  bool get hasPrevious => _relativeIndex(-1) != null;

  /// The [NextAwareShuffleOrder] passed to whichever `setAudioSources` call
  /// last built the current queue (`playFromSong` or `restoreState`) — kept
  /// so [_relativeIndex] can read its `indices` directly rather than
  /// `_player.shuffleIndices`. See [relativeQueueIndex]'s doc for why.
  NextAwareShuffleOrder? _activeShuffleOrder;

  /// See [relativeQueueIndex] — this class's job is just supplying it the
  /// state it needs from data we own synchronously, instead of from
  /// just_audio's own internal bookkeeping.
  int? _relativeIndex(int offset) => relativeQueueIndex(
    currentIndex: currentIndex,
    queueLength: queueSongs.length,
    loopMode: _player.loopMode,
    shuffleEnabled: _player.shuffleModeEnabled,
    shuffleIndices: _activeShuffleOrder?.indices ?? const <int>[],
    offset: offset,
  );

  // Per-current-item play-count/history tracking state — see `_onPosition`
  // and `_finalizeItemTracking` for the 50%-or-completion rule (CLAUDE.md
  // Phase 3, deliverable 3).
  int? _trackedIndex;
  bool _countedThisPlay = false;
  bool _nearEndReached = false;
  int? _playHistoryId;
  Duration _lastPosition = Duration.zero;

  bool _resumeAfterInterruption = false;
  bool _pausedByInterruption = false;

  // Real, wall-clock-measured listening time (Aura's total minutes /
  // nav-drawer "Hours listened") — deliberately independent of the
  // play-count tracking above, see `listening_time_accumulator.dart` and
  // `_migrationV6`'s doc for why a track's full duration must never be
  // credited for a partial listen. `_wasPlaying` detects the play/pause
  // boundary from `playerStateStream` (see `_onPlayerStateChangedForListening`);
  // `_onIndexChanged` separately closes/reopens the window at song
  // boundaries so a skip doesn't misattribute one song's time to another.
  final _listenAccumulator = ListeningTimeAccumulator();
  bool _wasPlaying = false;
  Timer? _listenFlushTimer;
  static const _listenFlushInterval = Duration(seconds: 30);

  // Debounces position saves from seeking — bug 3 (device testing pass)
  // asks for this specifically rather than a continuous periodic save, to
  // avoid writing to disk on every position tick.
  Timer? _seekSaveDebounce;

  // Bug 1 (device testing pass): periodic lightweight instrumentation so a
  // recurrence of the "crashes after 30+ minutes" report leaves a trail —
  // process RSS, queue length, and cache sizes are cheap to sample and are
  // exactly the numbers needed to tell a real leak from OS memory pressure.
  Timer? _instrumentationTimer;

  // Keeps the listener instance alive for the app's lifetime — not just a
  // local variable — so it isn't garbage-collected and silently stops
  // firing.
  AppLifecycleListener? _lifecycleListener;

  // TODO(notification-controls-audit): temporary instrumentation added
  // 2026-08-27 to chase a one-off, non-reproducible report of the Android
  // notification showing title/artist with no play/pause/skip buttons — see
  // CLAUDE.md. Remove once we either root-cause it from a real logcat
  // capture or are confident it's gone. `_memoryPressureObserver` keeps this
  // instance alive for the same reason as `_lifecycleListener` above.
  StreamSubscription<Object>? _asyncErrorSubscription;
  _MemoryPressureObserver? _memoryPressureObserver;

  Future<void> _init() async {
    _logger.i('[audio_service] AudioPlayerHandler initializing');

    // Android 13+ needs this granted before the foreground service's
    // notification (lockscreen/notification controls) can actually show —
    // declaring it in the manifest alone isn't enough. Fire-and-forget: if
    // denied, playback still works, just without a visible notification.
    if (Platform.isAndroid) {
      unawaited(Permission.notification.request());
    }

    _player.playbackEventStream.listen(
      (_) => _broadcastState(),
      // TODO(notification-controls-audit): this used to swallow stream
      // errors silently — if just_audio's own event stream ever errors out,
      // no further state broadcast happens until the next successful event,
      // and we'd previously have no trace of why.
      onError: (Object e, StackTrace st) {
        _logger.w('[audio_service] playbackEventStream error', error: e, stackTrace: st);
      },
    );
    // TODO(notification-controls-audit): audio_service pushes mediaItem
    // (title/artist/art) and playbackState (controls) to the Android
    // notification via two independent platform-channel calls with no
    // ordering guarantee between them — see the package's
    // `_observeMediaItem`/`_observePlaybackState`. Broadcasting the full
    // control set synchronously in the same tick as every mediaItem update
    // (see `_onIndexChanged`) narrows, but can't fully close, the window
    // where the notification could briefly show metadata against a stale
    // (possibly seeded-empty) controls state.
    playbackState.listen(_logIfControlsIncomplete);
    // TODO(notification-controls-audit): `AudioService.asyncError` surfaces
    // exceptions from the platform-channel calls above (e.g. `setState`
    // failing under memory pressure) — previously nothing in the app
    // listened to it, so such a failure left zero trace.
    _asyncErrorSubscription = AudioService.asyncError.listen((e) {
      _logger.e('[audio_service] asyncError from platform channel', error: e);
    });
    _memoryPressureObserver = _MemoryPressureObserver(_logger)..attach();

    _player.currentIndexStream.listen(_onIndexChanged);
    _player.positionStream.listen(_onPosition);
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) _finalizeItemTracking();
    });
    _player.playerStateStream.listen(_onPlayerStateChangedForListening);
    _listenFlushTimer = Timer.periodic(
      _listenFlushInterval,
      // Crash resilience: whatever's accumulated since the last flush is
      // durably persisted every 30s rather than only on pause/stop/skip —
      // a force-kill mid-playback loses at most this interval's worth of
      // credited time. `keepOpen` re-opens the window immediately so
      // tracking continues seamlessly rather than losing the open window.
      (_) => unawaited(_flushListeningWindow(keepOpen: true)),
    );

    _settingsRepository.watchResumeAfterInterruption().listen(
      (value) => _resumeAfterInterruption = value,
    );

    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    session.interruptionEventStream.listen(_onInterruption);
    session.becomingNoisyEventStream.listen((_) => pause());

    // Bug 3: save whenever the app is about to stop being visible/alive,
    // so a swipe-away-from-recents (which may not hit pause() at all)
    // still persists the current position.
    _lifecycleListener = AppLifecycleListener(
      onStateChange: (state) {
        if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
          unawaited(_savePlaybackState());
        }
      },
    );

    _instrumentationTimer = Timer.periodic(const Duration(minutes: 1), (_) => _logMemorySnapshot());
  }

  void _logMemorySnapshot() {
    final rssMb = (ProcessInfo.currentRss / (1024 * 1024)).toStringAsFixed(1);
    _logger.i(
      'playback snapshot — rss: ${rssMb}MB, queue: ${queueSongs.length}, '
      'coverArtCache: ${_coverArtCache.length}, status: $status, '
      'index: $currentIndex',
    );
  }

  // TODO(notification-controls-audit): the full expected control set is
  // always exactly [skipToPrevious, play-or-pause, stop, skipToNext] with
  // MediaAction.seek in systemActions — see `_broadcastState`. This watches
  // every emission on `playbackState` (not just the ones `_broadcastState`
  // itself constructs, which by definition are always complete) so it also
  // catches the base-class-seeded initial empty state and anything
  // `super.stop()` does. Only logs when a song is actually loaded
  // (`mediaItem.valueOrNull != null`) — an empty control set is expected and
  // correct with nothing queued.
  void _logIfControlsIncomplete(PlaybackState state) {
    final hasSong = mediaItem.valueOrNull != null;
    final hasFullControls = state.controls.length >= 4;
    final hasSeek = state.systemActions.contains(MediaAction.seek);
    if (hasSong && (!hasFullControls || !hasSeek)) {
      _logger.w(
        '[audio_service] PlaybackState emitted with incomplete controls while a song is '
        'loaded — controls: ${state.controls}, systemActions: ${state.systemActions}, '
        'processingState: ${state.processingState}, playing: ${state.playing}, '
        'mediaItem: ${mediaItem.valueOrNull?.id}',
      );
    }
  }

  // --- Status/repeat mapping -----------------------------------------

  PlaybackStatus _toStatus(PlayerState state) {
    if (state.processingState == ProcessingState.idle) {
      return PlaybackStatus.stopped;
    }
    if (state.processingState == ProcessingState.loading ||
        state.processingState == ProcessingState.buffering) {
      return PlaybackStatus.buffering;
    }
    if (state.processingState == ProcessingState.completed) {
      return PlaybackStatus.stopped;
    }
    return state.playing ? PlaybackStatus.playing : PlaybackStatus.paused;
  }

  PlayerRepeatMode _toRepeatMode(LoopMode mode) => switch (mode) {
    LoopMode.off => PlayerRepeatMode.off,
    LoopMode.one => PlayerRepeatMode.one,
    LoopMode.all => PlayerRepeatMode.all,
  };

  LoopMode _fromRepeatMode(PlayerRepeatMode mode) => switch (mode) {
    PlayerRepeatMode.off => LoopMode.off,
    PlayerRepeatMode.one => LoopMode.one,
    PlayerRepeatMode.all => LoopMode.all,
  };

  // --- OS-facing state broadcast --------------------------------------

  // No longer takes a `PlaybackEvent` — called both reactively off
  // `_player.playbackEventStream` and directly from `_onIndexChanged`, in
  // the same synchronous tick as the paired `mediaItem` update (see
  // `_onIndexChanged`'s TODO(notification-controls-audit) for why).
  void _broadcastState() {
    final playing = _player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0, 1, 3],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        repeatMode: switch (_player.loopMode) {
          LoopMode.off => AudioServiceRepeatMode.none,
          LoopMode.one => AudioServiceRepeatMode.one,
          LoopMode.all => AudioServiceRepeatMode.all,
        },
        shuffleMode: _player.shuffleModeEnabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _player.currentIndex,
      ),
    );
  }

  void _onIndexChanged(int? index) {
    Song? newSong;
    if (index != null && index < queueSongs.length) {
      newSong = queueSongs[index];
      final item = _mediaItemFor(newSong);
      mediaItem.add(item);
    } else {
      mediaItem.add(null);
    }
    // TODO(notification-controls-audit): paired with the mediaItem update
    // above in the same synchronous tick, rather than waiting on the next
    // unrelated `playbackEventStream` event — see the audit note on
    // `_broadcastState`.
    _broadcastState();
    unawaited(_savePlaybackState());

    // Kicks off a debounced background lyrics fetch for the new song — see
    // `LyricsPrefetchService`'s doc for why this event (the same one that
    // updates the lockscreen `mediaItem`), not the 50%-played
    // `recordPlay` call below, is the right "song started" signal.
    _lyricsPrefetchService.onSongChanged(newSong);

    // Close out the outgoing song's listening window before crediting the
    // incoming one — without this, a skip mid-song would misattribute
    // whatever time had accumulated to the wrong song at the next flush.
    unawaited(_flushListeningWindow());
    final newSongId = (index != null && index >= 0 && index < queueSongs.length)
        ? queueSongs[index].id
        : null;
    if (_player.playing && newSongId != null) {
      _listenAccumulator.start(newSongId, DateTime.now());
    }
  }

  // --- Actual-listened-time tracking (Aura total minutes / nav-drawer
  // "Hours listened") — see the `_listenAccumulator` field doc. -----------

  /// Opens/closes the listening window on the `playing` boundary —
  /// `state.playing` alone isn't quite right at natural queue-end, where
  /// just_audio can report `playing: true` with `processingState:
  /// completed` for a moment before actually stopping.
  void _onPlayerStateChangedForListening(PlayerState state) {
    final isPlaying = state.playing && state.processingState != ProcessingState.completed;
    if (isPlaying && !_wasPlaying) {
      final songId = _currentTrackedSongId;
      if (songId != null) _listenAccumulator.start(songId, DateTime.now());
    } else if (!isPlaying && _wasPlaying) {
      unawaited(_flushListeningWindow());
    }
    _wasPlaying = isPlaying;
  }

  int? get _currentTrackedSongId {
    final index = _player.currentIndex;
    if (index == null || index < 0 || index >= queueSongs.length) return null;
    return queueSongs[index].id;
  }

  /// Flushes whatever's accumulated in the open listening window to
  /// `listening_segments` — a no-op if nothing is currently accumulating
  /// (paused, stopped, or between songs). [keepOpen] re-opens a fresh
  /// window for the same song immediately instead of closing outright; see
  /// the periodic timer in [_init].
  Future<void> _flushListeningWindow({bool keepOpen = false}) async {
    final segment = _listenAccumulator.flush(DateTime.now(), keepOpen: keepOpen);
    if (segment == null) return;
    await _songRepository.recordListenedTime(segment.songId, segment.elapsedMs);
  }

  MediaItem _mediaItemFor(Song song) {
    return MediaItem(
      id: song.id?.toString() ?? song.path,
      title: song.displayTitle,
      artist: song.displayArtist,
      album: song.album,
      duration: song.durationMs != null ? Duration(milliseconds: song.durationMs!) : null,
      artUri: _coverArtCache[song.albumId] != null ? Uri.file(_coverArtCache[song.albumId]!) : null,
    );
  }

  // Bug 1 (device testing pass): bounded rather than left to grow for the
  // app's entire lifetime. Entries are tiny (a nullable path string per
  // album), so this was never likely to be *the* crash cause on its own,
  // but there's no reason to let it grow unbounded either — past the cap,
  // the whole cache is dropped and rebuilt lazily on next lookup, which is
  // cheap (one DB read per album re-encountered).
  static const _kMaxCoverArtCacheEntries = 500;
  final Map<int?, String?> _coverArtCache = {};

  Future<void> _resolveCoverArt(List<Song> songs) async {
    if (_coverArtCache.length > _kMaxCoverArtCacheEntries) {
      _coverArtCache.clear();
    }
    for (final song in songs) {
      if (song.albumId == null || _coverArtCache.containsKey(song.albumId)) {
        continue;
      }
      final album = await _albumRepository.getById(song.albumId!);
      _coverArtCache[song.albumId] = album?.coverArtPath;
    }
  }

  // --- Play-count / play-history (50%-or-completion rule) -------------

  void _resetItemTracking(int? index) {
    _trackedIndex = index;
    _countedThisPlay = false;
    _nearEndReached = false;
    _playHistoryId = null;
    _lastPosition = Duration.zero;
  }

  void _finalizeItemTracking() {
    final id = _playHistoryId;
    if (_nearEndReached && id != null) {
      unawaited(_songRepository.markPlayCompleted(id));
    }
  }

  void _onPosition(Duration position) {
    final index = _player.currentIndex;
    if (index != _trackedIndex) {
      _finalizeItemTracking();
      _resetItemTracking(index);
    }

    // A large backward jump (manual rewind, or a repeat-one loop restarting)
    // starts a fresh listen for counting purposes — see class doc.
    if (position < _lastPosition - const Duration(seconds: 2)) {
      _finalizeItemTracking();
      _resetItemTracking(index);
    }
    _lastPosition = position;

    final duration = _player.duration;
    if (duration == null ||
        duration == Duration.zero ||
        index == null ||
        index >= queueSongs.length) {
      return;
    }
    final song = queueSongs[index];
    if (song.id == null) return;

    final ratio = position.inMilliseconds / duration.inMilliseconds;
    if (ratio >= 0.98) _nearEndReached = true;

    if (!_countedThisPlay && ratio >= 0.5) {
      _countedThisPlay = true;
      unawaited(
        _songRepository
            .recordPlay(song.id!, completed: ratio >= 0.98)
            .then((id) => _playHistoryId = id),
      );
    }
  }

  // --- Interruptions / becoming noisy (deliverables 10, 11) -----------

  void _onInterruption(AudioInterruptionEvent event) {
    if (event.begin) {
      switch (event.type) {
        case AudioInterruptionType.duck:
          _player.setVolume(0.3);
        case AudioInterruptionType.pause:
        case AudioInterruptionType.unknown:
          if (_player.playing) {
            _pausedByInterruption = true;
            pause();
          }
      }
    } else {
      switch (event.type) {
        case AudioInterruptionType.duck:
          _player.setVolume(1.0);
        case AudioInterruptionType.pause:
        case AudioInterruptionType.unknown:
          if (_pausedByInterruption && _resumeAfterInterruption) play();
          _pausedByInterruption = false;
      }
    }
  }

  // --- Persistence (bug 3, device testing pass) ------------------------
  //
  // Saved on: song change (_onIndexChanged), pause(), a debounced tick
  // after seek(), and app-lifecycle transitions to paused/detached
  // (_lifecycleListener in _init()). Restored once at startup via
  // restoreState(), called from main() before runApp() — the queue is
  // rebuilt and the player is seeked to the saved position, but play() is
  // never called, so the app always reopens paused, never auto-playing.

  Future<void> _savePlaybackState() async {
    final index = currentIndex;
    final songs = queueSongs;
    if (index == null || index < 0 || index >= songs.length) {
      await _playbackStateRepository.clear();
      return;
    }
    await _playbackStateRepository.save(
      PersistedPlaybackState(
        currentSongId: songs[index].id,
        positionMs: _player.position.inMilliseconds,
        queueSongIds: [
          for (final s in songs)
            if (s.id != null) s.id!,
        ],
        currentIndex: index,
        shuffleEnabled: _player.shuffleModeEnabled,
        repeatMode: _toRepeatMode(_player.loopMode),
      ),
    );
  }

  /// Restores the last-saved queue/position/index/shuffle/repeat, without
  /// starting playback. Songs whose file no longer exists on disk are
  /// dropped from the restored queue; if that leaves nothing playable (or
  /// the saved current song itself is gone), the saved state is cleared
  /// and the app opens with nothing queued rather than a broken restore.
  Future<void> restoreState() async {
    final persisted = await _playbackStateRepository.load();
    if (persisted == null) return;

    // Bug 10 (device testing pass): this used to call SongRepository.getById
    // in a loop — one DB round-trip per queued song — plus a synchronous
    // File.existsSync() per song, all sequential, all on the main isolate,
    // all before runApp() could fire. With queues now spanning a whole list
    // (bug 11's fix), a 200-song Singles queue meant ~400 blocking
    // operations at every cold start — exactly what a 7+ second onCreate
    // and hundreds of skipped frames looks like. One batched query plus
    // concurrent, non-blocking existence checks instead.
    final allIds = {
      ...persisted.queueSongIds,
      if (persisted.currentSongId != null) persisted.currentSongId!,
    };
    final fetchedById = {
      for (final song in await _songRepository.getByIds(allIds.toList())) song.id!: song,
    };

    final existenceChecks = await Future.wait([
      for (final song in fetchedById.values)
        File(song.path).exists().then((exists) => MapEntry(song.id!, exists)),
    ]);
    final fileExists = Map.fromEntries(existenceChecks);

    final resolvedQueue = <Song>[];
    for (final id in persisted.queueSongIds) {
      final song = fetchedById[id];
      if (song != null && fileExists[id] == true) {
        resolvedQueue.add(song);
      }
    }

    final currentSong = persisted.currentSongId != null
        ? fetchedById[persisted.currentSongId]
        : null;
    final restoredIndex = currentSong == null
        ? -1
        : resolvedQueue.indexWhere((s) => s.id == currentSong.id);

    if (currentSong == null || fileExists[currentSong.id] != true || restoredIndex == -1) {
      await _playbackStateRepository.clear();
      return;
    }

    await _resolveCoverArt(resolvedQueue);
    _queueSongsSubject.add(resolvedQueue);
    queue.add([for (final s in resolvedQueue) _mediaItemFor(s)]);
    _resetItemTracking(restoredIndex);

    final restoredPosition = Duration(milliseconds: persisted.positionMs);
    _activeShuffleOrder = NextAwareShuffleOrder(getCurrentIndex: () => _player.currentIndex);
    final duration = await _player.setAudioSources(
      [for (final s in resolvedQueue) AudioSource.uri(Uri.file(s.path))],
      initialIndex: restoredIndex,
      initialPosition: restoredPosition,
      shuffleOrder: _activeShuffleOrder,
    );
    // If the saved position was already past the 50% mark, this listen was
    // necessarily already recorded before the app closed — _onPosition
    // reacts to every position change including seeks, not just active
    // playback, so it would have already fired last session. Marking it
    // counted here just prevents a spurious re-count on resume, it doesn't
    // skip counting a genuinely new listen.
    if (duration != null &&
        duration.inMilliseconds > 0 &&
        restoredPosition.inMilliseconds / duration.inMilliseconds >= 0.5) {
      _countedThisPlay = true;
    }

    await _player.setShuffleModeEnabled(persisted.shuffleEnabled);
    await _player.setLoopMode(_fromRepeatMode(persisted.repeatMode));
    mediaItem.add(_mediaItemFor(resolvedQueue[restoredIndex]));
    // TODO(notification-controls-audit): this is the cold-start path — the
    // one most likely to race the notification, since `main()` calls this
    // right after the un-awaited platform-channel setup in
    // `AudioService.init()`. See `_broadcastState`'s audit note.
    _broadcastState();
  }

  /// Not invoked anywhere in normal operation — this handler is a
  /// singleton for the app's lifetime, matching just_audio's own
  /// recommended pattern for a persistent background player — but gives
  /// the timers/listener above a documented teardown path rather than
  /// leaving them as fields nothing ever reads.
  Future<void> dispose() async {
    _logger.i('[audio_service] AudioPlayerHandler disposing');
    _seekSaveDebounce?.cancel();
    _instrumentationTimer?.cancel();
    _listenFlushTimer?.cancel();
    _lifecycleListener?.dispose();
    unawaited(_asyncErrorSubscription?.cancel());
    _memoryPressureObserver?.detach();
    _lyricsPrefetchService.dispose();
    await _player.dispose();
  }

  // --- Queue construction ----------------------------------------------

  /// Queues the entire [sourceList] — the whole list [song] was tapped
  /// from (Singles, an album, an artist, Favorites, Recently Added, a
  /// "Recently Played" shelf...) — with [song] as the current index, not
  /// just [song] plus whatever came after it. Matches standard music-app
  /// behavior (Spotify, YouTube Music, Poweramp, Musicolet): previous/next
  /// can navigate the *whole* list in either direction, and shuffle
  /// shuffles the whole list rather than only what happened to be after
  /// the tapped track. Bug 11 (device testing pass) — the previous version
  /// dropped everything before the tapped song, which is why previous was
  /// wrongly disabled/inconsistent when tapping deep into a long list.
  @override
  Future<void> playFromSong(Song song, List<Song> sourceList) async {
    final tappedIndex = sourceList.indexWhere((s) => s.id != null && s.id == song.id);
    final newQueue = tappedIndex >= 0 ? sourceList : [song];
    final initialIndex = tappedIndex >= 0 ? tappedIndex : 0;

    await _resolveCoverArt(newQueue);
    _resetItemTracking(initialIndex);
    _queueSongsSubject.add(newQueue);
    queue.add([for (final s in newQueue) _mediaItemFor(s)]);
    _activeShuffleOrder = NextAwareShuffleOrder(getCurrentIndex: () => _player.currentIndex);
    await _player.setAudioSources(
      [for (final s in newQueue) AudioSource.uri(Uri.file(s.path))],
      initialIndex: initialIndex,
      initialPosition: Duration.zero,
      shuffleOrder: _activeShuffleOrder,
    );
    if (Platform.isWindows && initialIndex != 0) {
      await _reseekWindowsInitialIndex(initialIndex);
    }
    await play();
  }

  /// Windows Phase 3 completion pass: `just_audio_windows`'s native `load`
  /// handler calls `MediaPlaybackList.MoveTo(initialIndex)` synchronously,
  /// immediately after assigning the new source to the player — before
  /// Windows' media pipeline has actually finished opening it. That throws
  /// ("The request is invalid in the current state", visible in the
  /// plugin's own native log), and the plugin swallows the error rather
  /// than surfacing it, silently leaving playback parked on item 0
  /// regardless of the requested index. A longer playlist takes the
  /// pipeline longer to open, widening that race — which is why this
  /// reproduced reliably on the large Singles list but not the much
  /// smaller Album/Artist track lists. Re-issuing the seek ourselves, as a
  /// separate call after giving the pipeline a moment, lands correctly
  /// because it's a genuinely later point in wall-clock time than the
  /// immediate in-native-callback attempt. Can't fix this in the plugin
  /// itself — it's vendored third-party code.
  Future<void> _reseekWindowsInitialIndex(int index) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await _player.seek(Duration.zero, index: index);
  }

  @override
  Future<void> addToQueue(Song song) async {
    await _resolveCoverArt([song]);
    await _player.addAudioSource(AudioSource.uri(Uri.file(song.path)));
    _queueSongsSubject.add([...queueSongs, song]);
    queue.add([...queue.value, _mediaItemFor(song)]);
  }

  @override
  Future<void> playNext(Song song) async {
    final insertAt = (currentIndex ?? -1) + 1;
    await _resolveCoverArt([song]);
    await _player.insertAudioSource(insertAt, AudioSource.uri(Uri.file(song.path)));
    final songs = [...queueSongs]..insert(insertAt, song);
    _queueSongsSubject.add(songs);
    final items = [...queue.value]..insert(insertAt, _mediaItemFor(song));
    queue.add(items);
  }

  /// Drops everything queued after the currently playing song. Matches the
  /// Queue screen's "Clear" action, which only ever clears "Next in Queue"
  /// — the currently playing track keeps playing.
  @override
  Future<void> clearQueue() async {
    final index = currentIndex;
    if (index == null || index + 1 >= queueSongs.length) return;
    await _player.removeAudioSourceRange(index + 1, queueSongs.length);
    _queueSongsSubject.add(queueSongs.sublist(0, index + 1));
    queue.add(queue.value.sublist(0, index + 1));
  }

  /// [oldIndex]/[newIndex] are absolute positions in [queueSongsStream]'s
  /// list (already resolved from the "next in queue" sublist the Queue
  /// screen renders), with [newIndex] the item's final resting position —
  /// i.e. already adjusted for the removal, not Flutter's
  /// `ReorderableListView` raw pre-removal index.
  @override
  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    await _player.moveAudioSource(oldIndex, newIndex);
    final songs = [...queueSongs];
    songs.insert(newIndex, songs.removeAt(oldIndex));
    _queueSongsSubject.add(songs);
    final items = [...queue.value];
    items.insert(newIndex, items.removeAt(oldIndex));
    queue.add(items);
  }

  @override
  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= queueSongs.length) return;
    await _player.removeAudioSourceAt(index);
    final songs = [...queueSongs]..removeAt(index);
    _queueSongsSubject.add(songs);
    final items = [...queue.value]..removeAt(index);
    queue.add(items);
  }

  @override
  Future<void> setShuffleEnabled(bool enabled) => _player.setShuffleModeEnabled(enabled);

  @override
  Future<void> setPlayerRepeatMode(PlayerRepeatMode mode) =>
      _player.setLoopMode(_fromRepeatMode(mode));

  // --- BaseAudioHandler overrides the OS can also trigger directly (e.g.
  // Android Auto, Assistant voice commands) — delegate to the same methods
  // above rather than duplicating logic.

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) =>
      setShuffleEnabled(shuffleMode != AudioServiceShuffleMode.none);

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) =>
      setPlayerRepeatMode(switch (repeatMode) {
        AudioServiceRepeatMode.none => PlayerRepeatMode.off,
        AudioServiceRepeatMode.one => PlayerRepeatMode.one,
        AudioServiceRepeatMode.all || AudioServiceRepeatMode.group => PlayerRepeatMode.all,
      });

  // --- BaseAudioHandler overrides --------------------------------------

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() async {
    await _player.pause();
    unawaited(_savePlaybackState());
  }

  @override
  Future<void> stop() async {
    _logger.i('[audio_service] stop() called — index: $currentIndex, status: $status');
    await _player.stop();
    return super.stop();
  }

  // TODO(notification-controls-audit): the OS calling either of these is a
  // real "the service is being torn down/rebuilt" signal worth a trail —
  // neither was overridden (and neither logged) before this pass.
  // `onTaskRemoved` fires when the user swipes the app from Recents;
  // `BaseAudioHandler`'s default `onNotificationDeleted` already calls
  // `stop()`, so this only adds a log line ahead of the same behavior.
  @override
  Future<void> onTaskRemoved() async {
    _logger.i(
      '[audio_service] onTaskRemoved (app swiped from recents) — '
      'playing: ${_player.playing}, index: $currentIndex',
    );
    return super.onTaskRemoved();
  }

  @override
  Future<void> onNotificationDeleted() async {
    _logger.i('[audio_service] onNotificationDeleted (notification swiped away)');
    return super.onNotificationDeleted();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _seekSaveDebounce?.cancel();
    _seekSaveDebounce = Timer(const Duration(seconds: 2), () => unawaited(_savePlaybackState()));
  }

  @override
  Future<void> skipToQueueItem(int index) => _player.seek(Duration.zero, index: index);

  // Bug 5 (device testing pass): skipping a track always resumes
  // playback, regardless of whether the player was paused beforehand —
  // Tomi's stated preference. Applies uniformly everywhere these are
  // triggered from (Now Playing, mini player, lockscreen, Bluetooth
  // media buttons, SMTC), since they all funnel through this one handler.
  @override
  Future<void> skipToNext() async {
    await _player.seekToNext();
    await play();
  }

  // Bug 4: restarts the current track from the beginning if more than 3
  // seconds in, matching standard music-app "previous" behavior — only
  // skips to the actual previous track when pressed near the start.
  @override
  Future<void> skipToPrevious() async {
    if (_player.position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
    } else {
      await _player.seekToPrevious();
    }
    await play();
  }
}

// TODO(notification-controls-audit): `AppLifecycleListener` (used elsewhere
// in this file) mixes in `WidgetsBindingObserver` but doesn't override
// `didHaveMemoryPressure`, so it never forwards Android's low-memory
// signal — there was previously no hook for this anywhere in the app. A
// dedicated observer, separate from `AppLifecycleListener`, is the smallest
// way to add one.
class _MemoryPressureObserver with WidgetsBindingObserver {
  _MemoryPressureObserver(this._logger);

  final Logger _logger;

  void attach() => WidgetsBinding.instance.addObserver(this);

  void detach() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didHaveMemoryPressure() {
    _logger.w('[audio_service] OS low-memory warning received (didHaveMemoryPressure)');
  }
}
