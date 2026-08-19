import 'dart:math';

import 'package:just_audio/just_audio.dart';

/// A [ShuffleOrder] that behaves like just_audio's own `DefaultShuffleOrder`
/// for ordinary insertions, but special-cases "insert immediately after the
/// currently playing track" — which is exactly what
/// `AudioPlayerHandler.playNext` always does — to also land immediately
/// after it in shuffle *playback* order, instead of a random position.
///
/// Bug 7 (device testing pass): `DefaultShuffleOrder.insert()` always
/// places new entries at a random shuffle position, regardless of where
/// they were inserted in the underlying sequence. "Play Next" inserted the
/// track at the right sequence position (currentIndex + 1), but with
/// shuffle on, `seekToNext()` follows shuffle order, not sequence order —
/// so the track played was still random. An explicit user queue action
/// shouldn't be silently overridden by shuffle. Can't simply subclass
/// `DefaultShuffleOrder` and override `insert()` alone — its `_random`
/// field is private to `just_audio`'s own library, so the rest of the
/// interface (`shuffle`, `removeRange`, `clear`) is reimplemented here to
/// match it exactly.
class NextAwareShuffleOrder extends ShuffleOrder {
  NextAwareShuffleOrder({required this.getCurrentIndex, Random? random}) : _random = random ?? Random();

  /// The sequence index of the currently playing item, or null — read
  /// fresh on every [insert] call since the shuffle order object is
  /// long-lived across index changes.
  final int? Function() getCurrentIndex;

  final Random _random;

  @override
  final indices = <int>[];

  @override
  void shuffle({int? initialIndex}) {
    assert(initialIndex == null || indices.contains(initialIndex));
    if (indices.length <= 1) return;
    indices.shuffle(_random);
    if (initialIndex == null) return;

    const initialPos = 0;
    final swapPos = indices.indexOf(initialIndex);
    final swapIndex = indices[initialPos];
    indices[initialPos] = initialIndex;
    indices[swapPos] = swapIndex;
  }

  @override
  void insert(int index, int count) {
    final current = getCurrentIndex();

    for (var i = 0; i < indices.length; i++) {
      if (indices[i] >= index) indices[i] += count;
    }

    final newIndices = List.generate(count, (i) => index + i);

    if (current != null && index == current + 1) {
      // Explicit "play next": place right after the current item's own
      // shuffle-order position, not randomly.
      final currentPos = indices.indexOf(current);
      var insertAt = currentPos == -1 ? indices.length : currentPos + 1;
      for (final newIndex in newIndices) {
        indices.insert(insertAt, newIndex);
        insertAt++;
      }
    } else {
      // Ordinary addition (e.g. append to the end via addToQueue) —
      // random position, same as DefaultShuffleOrder.
      for (final newIndex in newIndices) {
        final insertionIndex = _random.nextInt(indices.length + 1);
        indices.insert(insertionIndex, newIndex);
      }
    }
  }

  @override
  void removeRange(int start, int end) {
    final count = end - start;
    final oldIndices = List.generate(count, (i) => start + i).toSet();
    indices.removeWhere(oldIndices.contains);
    for (var i = 0; i < indices.length; i++) {
      if (indices[i] >= end) indices[i] -= count;
    }
  }

  @override
  void clear() => indices.clear();
}
