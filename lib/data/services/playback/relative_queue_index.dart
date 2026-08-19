import 'package:just_audio/just_audio.dart';

/// The queue index Previous/Next would land on from [currentIndex], or
/// `null` if there isn't one — i.e. whether `hasPrevious`/`hasNext` should
/// be true. Pulled out of `AudioPlayerHandler` as a pure function, taking
/// plain values instead of reading `AudioPlayer` state directly, so it can
/// be unit-tested without a real player (see
/// `test/data/services/playback/relative_queue_index_test.dart`).
///
/// This exists instead of trusting `AudioPlayer.hasNext`/`hasPrevious`
/// because both prior "fix the previous button" incidents were the same
/// mistake in different corners of the same state space: trusting a piece
/// of just_audio's own internal, native-fed bookkeeping that can be
/// transiently or persistently out of sync with the queue actually
/// playing. First it was `_player.currentIndex`/internal sequence state
/// (stale on Windows — a plugin event-channel threading bug). Then it was
/// `_player.shuffleIndices` (stale on whichever platform has shuffle on
/// when a new queue is set — it's fed via `sequenceStateStream`, not
/// updated synchronously by `ShuffleOrder.insert()`, so it can keep
/// holding the *previous* queue's indices indefinitely). [shuffleIndices]
/// here should come from the app's own live `NextAwareShuffleOrder`
/// instance instead, which is mutated in plain synchronous Dart and has
/// no such lag.
int? relativeQueueIndex({
  required int? currentIndex,
  required int queueLength,
  required LoopMode loopMode,
  required bool shuffleEnabled,
  required List<int> shuffleIndices,
  required int offset,
}) {
  if (currentIndex == null || queueLength == 0) return null;
  if (loopMode == LoopMode.one) return currentIndex;
  final order = shuffleEnabled
      ? shuffleIndices
      : List<int>.generate(queueLength, (i) => i);
  if (order.length != queueLength || currentIndex >= order.length) return null;
  final pos = order.indexOf(currentIndex);
  if (pos == -1) return null;
  var newPos = pos + offset;
  if (newPos >= order.length || newPos < 0) {
    if (loopMode == LoopMode.all) {
      newPos %= order.length;
    } else {
      return null;
    }
  }
  return order[newPos];
}
