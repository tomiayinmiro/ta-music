import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rxdart/rxdart.dart';

import '../../models/song.dart';
import '../../repositories/album_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../repositories/song_repository.dart';
import 'playback_handler.dart';
import 'playback_models.dart';

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
class AudioPlayerHandler extends BaseAudioHandler with QueueHandler, SeekHandler implements PlaybackHandler {
  AudioPlayerHandler({
    required this._songRepository,
    required this._albumRepository,
    required this._settingsRepository,
  }) {
    _init();
  }

  final SongRepository _songRepository;
  final AlbumRepository _albumRepository;
  final SettingsRepository _settingsRepository;

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
  bool get hasNext => _player.hasNext;
  @override
  bool get hasPrevious => _player.hasPrevious;

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

  Future<void> _init() async {
    // Android 13+ needs this granted before the foreground service's
    // notification (lockscreen/notification controls) can actually show —
    // declaring it in the manifest alone isn't enough. Fire-and-forget: if
    // denied, playback still works, just without a visible notification.
    if (Platform.isAndroid) {
      unawaited(Permission.notification.request());
    }

    _player.playbackEventStream.listen(_broadcastState, onError: (Object e, StackTrace st) {});
    _player.currentIndexStream.listen(_onIndexChanged);
    _player.positionStream.listen(_onPosition);
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) _finalizeItemTracking();
    });

    _settingsRepository.watchResumeAfterInterruption().listen((value) => _resumeAfterInterruption = value);

    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    session.interruptionEventStream.listen(_onInterruption);
    session.becomingNoisyEventStream.listen((_) => pause());
  }

  // --- Status/repeat mapping -----------------------------------------

  PlaybackStatus _toStatus(PlayerState state) {
    if (state.processingState == ProcessingState.idle) return PlaybackStatus.stopped;
    if (state.processingState == ProcessingState.loading ||
        state.processingState == ProcessingState.buffering) {
      return PlaybackStatus.buffering;
    }
    if (state.processingState == ProcessingState.completed) return PlaybackStatus.stopped;
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

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
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
      shuffleMode:
          _player.shuffleModeEnabled ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    ));
  }

  void _onIndexChanged(int? index) {
    if (index != null && index < queueSongs.length) {
      final item = _mediaItemFor(queueSongs[index]);
      mediaItem.add(item);
    } else {
      mediaItem.add(null);
    }
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

  final Map<int?, String?> _coverArtCache = {};

  Future<void> _resolveCoverArt(List<Song> songs) async {
    for (final song in songs) {
      if (song.albumId == null || _coverArtCache.containsKey(song.albumId)) continue;
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
    if (duration == null || duration == Duration.zero || index == null || index >= queueSongs.length) {
      return;
    }
    final song = queueSongs[index];
    if (song.id == null) return;

    final ratio = position.inMilliseconds / duration.inMilliseconds;
    if (ratio >= 0.98) _nearEndReached = true;

    if (!_countedThisPlay && ratio >= 0.5) {
      _countedThisPlay = true;
      unawaited(
        _songRepository.recordPlay(song.id!, completed: ratio >= 0.98).then((id) => _playHistoryId = id),
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

  // --- Queue construction ----------------------------------------------

  /// Builds a fresh queue starting at [song] and running to the end of
  /// [sourceList] (the tapped song plus everything after it in whatever
  /// list it was tapped from) — the standard "play from here" convention,
  /// matching how every song list in the app already reads top-to-bottom.
  @override
  Future<void> playFromSong(Song song, List<Song> sourceList) async {
    final tappedIndex = sourceList.indexWhere((s) => s.id != null && s.id == song.id);
    final newQueue = tappedIndex >= 0 ? sourceList.sublist(tappedIndex) : [song];

    await _resolveCoverArt(newQueue);
    _resetItemTracking(0);
    _queueSongsSubject.add(newQueue);
    queue.add([for (final s in newQueue) _mediaItemFor(s)]);
    await _player.setAudioSources(
      [for (final s in newQueue) AudioSource.uri(Uri.file(s.path))],
      initialIndex: 0,
      initialPosition: Duration.zero,
    );
    await play();
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
  Future<void> setPlayerRepeatMode(PlayerRepeatMode mode) => _player.setLoopMode(_fromRepeatMode(mode));

  // --- BaseAudioHandler overrides the OS can also trigger directly (e.g.
  // Android Auto, Assistant voice commands) — delegate to the same methods
  // above rather than duplicating logic.

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) =>
      setShuffleEnabled(shuffleMode != AudioServiceShuffleMode.none);

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) => setPlayerRepeatMode(switch (repeatMode) {
        AudioServiceRepeatMode.none => PlayerRepeatMode.off,
        AudioServiceRepeatMode.one => PlayerRepeatMode.one,
        AudioServiceRepeatMode.all || AudioServiceRepeatMode.group => PlayerRepeatMode.all,
      });

  // --- BaseAudioHandler overrides --------------------------------------

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToQueueItem(int index) => _player.seek(Duration.zero, index: index);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();
}
