import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:ta_music/data/services/playback/relative_queue_index.dart';

/// Guards the exact regression the app has now hit three times: a
/// Previous/Next getter that trusts stale internal player state instead of
/// data the app owns. See `relative_queue_index.dart`'s doc for the full
/// history — this is a pure function specifically so these cases can be
/// asserted directly, with no player/plugin involved.
void main() {
  group('no shuffle', () {
    test('previous/next are available mid-list', () {
      expect(
        relativeQueueIndex(
          currentIndex: 3,
          queueLength: 6,
          loopMode: LoopMode.off,
          shuffleEnabled: false,
          shuffleIndices: const [],
          offset: -1,
        ),
        2,
      );
      expect(
        relativeQueueIndex(
          currentIndex: 3,
          queueLength: 6,
          loopMode: LoopMode.off,
          shuffleEnabled: false,
          shuffleIndices: const [],
          offset: 1,
        ),
        4,
      );
    });

    test('previous is null at index 0, next is null at the last index, without loop', () {
      expect(
        relativeQueueIndex(
          currentIndex: 0,
          queueLength: 6,
          loopMode: LoopMode.off,
          shuffleEnabled: false,
          shuffleIndices: const [],
          offset: -1,
        ),
        isNull,
      );
      expect(
        relativeQueueIndex(
          currentIndex: 5,
          queueLength: 6,
          loopMode: LoopMode.off,
          shuffleEnabled: false,
          shuffleIndices: const [],
          offset: 1,
        ),
        isNull,
      );
    });

    test('loop all wraps around at both ends', () {
      expect(
        relativeQueueIndex(
          currentIndex: 0,
          queueLength: 6,
          loopMode: LoopMode.all,
          shuffleEnabled: false,
          shuffleIndices: const [],
          offset: -1,
        ),
        5,
      );
      expect(
        relativeQueueIndex(
          currentIndex: 5,
          queueLength: 6,
          loopMode: LoopMode.all,
          shuffleEnabled: false,
          shuffleIndices: const [],
          offset: 1,
        ),
        0,
      );
    });

    test('loop one always returns the current index', () {
      expect(
        relativeQueueIndex(
          currentIndex: 3,
          queueLength: 6,
          loopMode: LoopMode.one,
          shuffleEnabled: false,
          shuffleIndices: const [],
          offset: -1,
        ),
        3,
      );
    });
  });

  group('shuffle enabled', () {
    test('previous/next follow shuffle order, not sequence order', () {
      // Sequence order is 0..5; shuffle order plays 4, 1, 3, 0, 5, 2.
      const shuffleIndices = [4, 1, 3, 0, 5, 2];
      expect(
        relativeQueueIndex(
          currentIndex: 3, // shuffle position 2
          queueLength: 6,
          loopMode: LoopMode.off,
          shuffleEnabled: true,
          shuffleIndices: shuffleIndices,
          offset: -1,
        ),
        1, // shuffle position 1
      );
      expect(
        relativeQueueIndex(
          currentIndex: 3,
          queueLength: 6,
          loopMode: LoopMode.off,
          shuffleEnabled: true,
          shuffleIndices: shuffleIndices,
          offset: 1,
        ),
        0, // shuffle position 3
      );
    });

    test('stale shuffle indices from a previous, different-length queue disable previous/next '
        'instead of navigating wrong — the exact regression this guards', () {
      // A 305-song queue's leftover shuffle indices, still present after
      // a tap started a fresh 6-song queue (e.g. an Album) — this is
      // what "shuffle left on from earlier testing" produced on Android.
      final staleShuffleIndices = List<int>.generate(305, (i) => i)..shuffle();
      expect(
        relativeQueueIndex(
          currentIndex: 3,
          queueLength: 6,
          loopMode: LoopMode.off,
          shuffleEnabled: true,
          shuffleIndices: staleShuffleIndices,
          offset: -1,
        ),
        isNull,
      );
    });

    test('an index not present in shuffle indices returns null rather than throwing', () {
      expect(
        relativeQueueIndex(
          currentIndex: 3,
          queueLength: 6,
          loopMode: LoopMode.off,
          shuffleEnabled: true,
          shuffleIndices: const [0, 1, 2, 4, 5, 99],
          offset: -1,
        ),
        isNull,
      );
    });
  });

  test('null current index or empty queue returns null', () {
    expect(
      relativeQueueIndex(
        currentIndex: null,
        queueLength: 6,
        loopMode: LoopMode.off,
        shuffleEnabled: false,
        shuffleIndices: const [],
        offset: -1,
      ),
      isNull,
    );
    expect(
      relativeQueueIndex(
        currentIndex: 0,
        queueLength: 0,
        loopMode: LoopMode.off,
        shuffleEnabled: false,
        shuffleIndices: const [],
        offset: -1,
      ),
      isNull,
    );
  });
}
