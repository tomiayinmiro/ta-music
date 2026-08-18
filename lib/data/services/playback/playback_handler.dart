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
}
