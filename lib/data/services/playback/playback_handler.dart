import '../../models/song.dart';
import 'playback_models.dart';

/// The subset of `AudioPlayerHandler` that `PlaybackService` depends on,
/// extracted as an interface so `PlaybackService` can be constructed with a
/// lightweight fake in tests — the real handler's constructor touches
/// `audio_session` and `just_audio` platform channels immediately, neither
/// of which exist in `flutter_test`'s host-VM environment.
abstract class PlaybackHandler {
  Stream<List<Song>> get queueSongsStream;
  Stream<int?> get currentIndexStream;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Duration? get duration;
  Stream<PlaybackStatus> get statusStream;
  Stream<bool> get shuffleModeStream;
  Stream<PlayerRepeatMode> get repeatModeStream;

  /// Shuffle/repeat-aware — see `PlaybackSnapshot.hasNext`/`hasPrevious`.
  bool get hasNext;
  bool get hasPrevious;

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> skipToNext();
  Future<void> skipToPrevious();
  Future<void> skipToQueueItem(int index);

  Future<void> playFromSong(Song song, List<Song> sourceList);
  Future<void> addToQueue(Song song);
  Future<void> playNext(Song song);
  Future<void> clearQueue();
  Future<void> setShuffleEnabled(bool enabled);
  Future<void> setPlayerRepeatMode(PlayerRepeatMode mode);
  Future<void> reorderQueue(int oldIndex, int newIndex);
  Future<void> removeFromQueue(int index);

  /// Whether this handler can drive a live equalizer at all — false on every
  /// platform except Android (Phase 6 batch 2, see CLAUDE.md). UI gates the
  /// entire Equalizer entry point on this rather than attempting the feature
  /// and showing an error.
  bool get isEqualizerSupported;

  /// Resolves once the device's real equalizer band layout is known — which,
  /// per `just_audio`'s `AndroidEqualizer`, only happens after the effect
  /// activates on the platform side (audio has actually loaded at least
  /// once). Never resolves on a platform where [isEqualizerSupported] is
  /// false, so callers must check that first rather than awaiting this
  /// unconditionally.
  Future<EqualizerParameters> get equalizerParameters;

  Stream<bool> get equalizerEnabledStream;
  Future<void> setEqualizerEnabled(bool enabled);

  /// Live gain (decibels) for every device band, in band-index order —
  /// updates immediately as [setEqualizerBandGain] is called, including from
  /// other listeners (e.g. a preset applying several bands at once).
  Stream<List<double>> get equalizerBandGainsStream;
  Future<void> setEqualizerBandGain(int bandIndex, double gain);
}
