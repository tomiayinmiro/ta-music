import 'package:flutter_test/flutter_test.dart';
import 'package:ta_music/data/services/playback/listening_time_accumulator.dart';

/// Guards the "total minutes credits full track duration instead of actual
/// time listened" bug: this accumulator only ever measures real elapsed
/// time between `start`/`flush` calls — it has no idea what a track's
/// duration is, so it physically cannot credit more than what really
/// elapsed, regardless of how a caller misuses it.
void main() {
  final t0 = DateTime(2026, 1, 1, 12, 0, 0);

  test('2 minutes of listening credits 2 minutes, not a 30-minute track duration', () {
    final accumulator = ListeningTimeAccumulator();
    accumulator.start(1, t0);
    final segment = accumulator.flush(t0.add(const Duration(minutes: 2)));

    expect(segment, isNotNull);
    expect(segment!.songId, 1);
    expect(segment.elapsedMs, const Duration(minutes: 2).inMilliseconds);
  });

  test('seeking forward does not credit skipped time — only wall-clock time is measured', () {
    final accumulator = ListeningTimeAccumulator();
    accumulator.start(1, t0);
    // A seek jumps the player's *position* far ahead, but takes ~no real
    // time — the accumulator has no position-aware API at all to be misled
    // by, so a flush immediately "after" a hypothetical 10-minute seek
    // still only credits the real time that passed.
    final segment = accumulator.flush(t0.add(const Duration(seconds: 3)));

    expect(segment!.elapsedMs, const Duration(seconds: 3).inMilliseconds);
  });

  test('flush with nothing open returns null', () {
    final accumulator = ListeningTimeAccumulator();
    expect(accumulator.flush(t0), isNull);
  });

  test('flush closes the window — a second flush with no new start returns null', () {
    final accumulator = ListeningTimeAccumulator();
    accumulator.start(1, t0);
    accumulator.flush(t0.add(const Duration(minutes: 1)));

    expect(accumulator.isOpen, isFalse);
    expect(accumulator.flush(t0.add(const Duration(minutes: 2))), isNull);
  });

  test('keepOpen re-opens immediately for the periodic crash-resilience flush', () {
    final accumulator = ListeningTimeAccumulator();
    accumulator.start(1, t0);

    final first = accumulator.flush(t0.add(const Duration(seconds: 30)), keepOpen: true);
    expect(first!.elapsedMs, const Duration(seconds: 30).inMilliseconds);
    expect(accumulator.isOpen, isTrue);

    // Tracking continues from where the flush left off, not from `t0`.
    final second = accumulator.flush(
      t0.add(const Duration(seconds: 45)),
      keepOpen: true,
    );
    expect(second!.elapsedMs, const Duration(seconds: 15).inMilliseconds);
  });

  test('starting the same song twice does not reset the clock', () {
    final accumulator = ListeningTimeAccumulator();
    accumulator.start(1, t0);
    accumulator.start(1, t0.add(const Duration(seconds: 10)));
    final segment = accumulator.flush(t0.add(const Duration(seconds: 20)));

    expect(segment!.elapsedMs, const Duration(seconds: 20).inMilliseconds);
  });

  test('starting a different song replaces the open window (skip mid-song)', () {
    final accumulator = ListeningTimeAccumulator();
    accumulator.start(1, t0);
    accumulator.start(2, t0.add(const Duration(seconds: 5)));
    final segment = accumulator.flush(t0.add(const Duration(seconds: 15)));

    // Only song 2's 10 seconds is credited — song 1's 5 seconds was
    // dropped without a flush, matching how `AudioPlayerHandler` always
    // flushes before starting a new window on an index change (this test
    // documents what would happen if a caller skipped that step).
    expect(segment!.songId, 2);
    expect(segment.elapsedMs, const Duration(seconds: 10).inMilliseconds);
  });
}
