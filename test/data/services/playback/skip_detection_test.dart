import 'package:flutter_test/flutter_test.dart';
import 'package:ta_music/data/services/playback/skip_detection.dart';

/// Guards the Phase 6 batch 1 skip definition: furthest position reached
/// under both 30s and 50% of duration, and never already counted as a real
/// play. See `_migrationV14`'s doc in `database.dart`.
void main() {
  test('under 30s and under 50% duration is a skip', () {
    expect(
      isSkip(positionMs: 15000, durationMs: 200000, countedThisPlay: false),
      isTrue,
    );
  });

  test('past 30s but still under 50% duration is not a skip', () {
    // 35s into a 200s track: under 50%, but past the 30s mark.
    expect(
      isSkip(positionMs: 35000, durationMs: 200000, countedThisPlay: false),
      isFalse,
    );
  });

  test('under 30s but past 50% duration is not a skip (very short track)', () {
    // 20s into a 30s track: under 30s, but already past 50%.
    expect(
      isSkip(positionMs: 20000, durationMs: 30000, countedThisPlay: false),
      isFalse,
    );
  });

  test('a listen already counted as a real play is never a skip', () {
    // Would satisfy both thresholds on position alone, but the 50%-play
    // rule already counted it — e.g. seeking backward after crossing 50%.
    expect(
      isSkip(positionMs: 5000, durationMs: 200000, countedThisPlay: true),
      isFalse,
    );
  });

  test('exactly at the 30s boundary is not a skip', () {
    expect(
      isSkip(positionMs: 30000, durationMs: 200000, countedThisPlay: false),
      isFalse,
    );
  });

  test('exactly at the 50% boundary is not a skip', () {
    expect(
      isSkip(positionMs: 10000, durationMs: 20000, countedThisPlay: false),
      isFalse,
    );
  });

  test('zero or unknown duration never registers as a skip', () {
    expect(isSkip(positionMs: 5000, durationMs: 0, countedThisPlay: false), isFalse);
  });
}
