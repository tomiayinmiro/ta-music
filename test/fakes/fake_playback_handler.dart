import 'package:ta_music/data/models/song.dart';
import 'package:ta_music/data/services/audio_service.dart';

/// A no-op [PlaybackHandler] for widget tests — the real `AudioPlayerHandler`
/// touches `audio_session`/`just_audio` platform channels in its
/// constructor, neither of which exist in `flutter_test`'s host-VM
/// environment.
class FakePlaybackHandler implements PlaybackHandler {
  @override
  Stream<List<Song>> get queueSongsStream => Stream.value(const <Song>[]);
  @override
  Stream<int?> get currentIndexStream => Stream.value(null);
  @override
  Stream<Duration> get positionStream => Stream.value(Duration.zero);
  @override
  Stream<Duration?> get durationStream => Stream.value(null);
  @override
  Duration? get duration => null;
  @override
  Stream<PlaybackStatus> get statusStream => Stream.value(PlaybackStatus.stopped);
  @override
  Stream<bool> get shuffleModeStream => Stream.value(false);
  @override
  Stream<PlayerRepeatMode> get repeatModeStream => Stream.value(PlayerRepeatMode.off);
  @override
  bool get hasNext => false;
  @override
  bool get hasPrevious => false;

  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> skipToNext() async {}
  @override
  Future<void> skipToPrevious() async {}
  @override
  Future<void> skipToQueueItem(int index) async {}

  @override
  Future<void> playFromSong(Song song, List<Song> sourceList) async {}
  @override
  Future<void> addToQueue(Song song) async {}
  @override
  Future<void> playNext(Song song) async {}
  @override
  Future<void> clearQueue() async {}
  @override
  Future<void> setShuffleEnabled(bool enabled) async {}
  @override
  Future<void> setPlayerRepeatMode(PlayerRepeatMode mode) async {}
  @override
  Future<void> reorderQueue(int oldIndex, int newIndex) async {}
  @override
  Future<void> removeFromQueue(int index) async {}

  @override
  bool get isEqualizerSupported => false;
  @override
  Future<EqualizerParameters> get equalizerParameters =>
      Future<EqualizerParameters>.error(StateError('equalizer not supported in tests'));
  @override
  Stream<bool> get equalizerEnabledStream => Stream.value(false);
  @override
  Future<void> setEqualizerEnabled(bool enabled) async {}
  @override
  Stream<List<double>> get equalizerBandGainsStream => Stream.value(const <double>[]);
  @override
  Future<void> setEqualizerBandGain(int bandIndex, double gain) async {}
}
