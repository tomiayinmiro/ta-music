import 'package:rxdart/rxdart.dart';

import '../models/song.dart';
import 'playback/playback_handler.dart';
import 'playback/playback_models.dart';

export 'playback/playback_handler.dart';
export 'playback/playback_models.dart';

/// The playback engine's public face — everything outside `data/services`
/// talks to this, never to `AudioPlayerHandler`/`just_audio`/`audio_service`
/// directly. Per CLAUDE.md's Phase 3 brief (deliverable 2).
///
/// Depends on the [PlaybackHandler] interface, not the concrete
/// `AudioPlayerHandler`, so it can be constructed with a lightweight fake
/// in tests instead of the real handler (whose constructor touches
/// `audio_session`/`just_audio` platform channels immediately).
class PlaybackService {
  PlaybackService(this._handler);

  final PlaybackHandler _handler;

  Stream<Song?> get currentSongStream => Rx.combineLatest2(
        _handler.queueSongsStream,
        _handler.currentIndexStream,
        (List<Song> queue, int? index) =>
            (index != null && index >= 0 && index < queue.length) ? queue[index] : null,
      ).distinct();

  Stream<Duration> get positionStream => _handler.positionStream;
  Stream<Duration?> get durationStream => _handler.durationStream;
  Stream<PlaybackStatus> get statusStream => _handler.statusStream;
  Stream<List<Song>> get queueStream => _handler.queueSongsStream;
  Stream<int?> get currentIndexStream => _handler.currentIndexStream;
  Stream<bool> get shuffleModeStream => _handler.shuffleModeStream;
  Stream<PlayerRepeatMode> get repeatModeStream => _handler.repeatModeStream;

  /// One combined snapshot, for widgets that want everything at once
  /// instead of watching several providers.
  Stream<PlaybackSnapshot> get snapshotStream => Rx.combineLatest6(
        _handler.queueSongsStream,
        _handler.currentIndexStream,
        _handler.statusStream,
        _handler.positionStream,
        _handler.shuffleModeStream,
        _handler.repeatModeStream,
        (List<Song> queue, int? index, PlaybackStatus status, Duration position, bool shuffle,
                PlayerRepeatMode repeat) =>
            PlaybackSnapshot(
          queue: queue,
          currentIndex: index,
          status: status,
          position: position,
          duration: _handler.duration,
          shuffleEnabled: shuffle,
          repeatMode: repeat,
          hasNext: _handler.hasNext,
          hasPrevious: _handler.hasPrevious,
        ),
      );

  Future<void> play() => _handler.play();
  Future<void> pause() => _handler.pause();
  Future<void> resume() => _handler.play();
  Future<void> seek(Duration position) => _handler.seek(position);
  Future<void> next() => _handler.skipToNext();
  Future<void> previous() => _handler.skipToPrevious();

  /// Starts playback of [song], queueing [sourceList] from that song's
  /// position onward.
  Future<void> playFromSong(Song song, List<Song> sourceList) => _handler.playFromSong(song, sourceList);

  Future<void> addToQueue(Song song) => _handler.addToQueue(song);
  Future<void> playNext(Song song) => _handler.playNext(song);
  Future<void> clearQueue() => _handler.clearQueue();
  Future<void> setShuffleMode(bool enabled) => _handler.setShuffleEnabled(enabled);
  Future<void> setRepeatMode(PlayerRepeatMode mode) => _handler.setPlayerRepeatMode(mode);
  Future<void> reorderQueue(int oldIndex, int newIndex) => _handler.reorderQueue(oldIndex, newIndex);
  Future<void> removeFromQueue(int index) => _handler.removeFromQueue(index);

  /// Jumps straight to the queue item at [index] — the Queue screen's
  /// tap-to-jump gesture.
  Future<void> skipToQueueItemAt(int index) => _handler.skipToQueueItem(index);

  // --- Equalizer (Phase 6 batch 2, Android-only) -----------------------

  bool get isEqualizerSupported => _handler.isEqualizerSupported;
  Future<EqualizerParameters> get equalizerParameters => _handler.equalizerParameters;
  Stream<bool> get equalizerEnabledStream => _handler.equalizerEnabledStream;
  Future<void> setEqualizerEnabled(bool enabled) => _handler.setEqualizerEnabled(enabled);
  Stream<List<double>> get equalizerBandGainsStream => _handler.equalizerBandGainsStream;
  Future<void> setEqualizerBandGain(int bandIndex, double gain) =>
      _handler.setEqualizerBandGain(bandIndex, gain);
}
