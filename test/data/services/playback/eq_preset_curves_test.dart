import 'package:flutter_test/flutter_test.dart';
import 'package:ta_music/data/services/playback/eq_preset_curves.dart';

/// Guards `distributeBuiltInPreset` — device equalizer band counts vary (5
/// is typical, but not guaranteed), and gain can only be set on a real
/// hardware band, so this pure function is what stands between a built-in
/// preset and whatever band layout a real device reports. See
/// `eq_preset_curves.dart`'s doc.
void main() {
  group('distributeBuiltInPreset', () {
    test('returns one gain per band for a typical 5-band device', () {
      final gains = distributeBuiltInPreset(BuiltInEqPreset.deepBass, 5);
      expect(gains, hasLength(5));
      // Deep Bass's curve is [8, 5, 0, -1, -2] across 5 regions — a 5-band
      // device maps 1:1 onto those regions with no interpolation needed.
      expect(gains, [8, 5, 0, -1, -2]);
    });

    test('interpolates for a band count other than the curve\'s 5 regions', () {
      final gains = distributeBuiltInPreset(BuiltInEqPreset.deepBass, 10);
      expect(gains, hasLength(10));
      // First and last bands land exactly on the curve's first/last region.
      expect(gains.first, 8);
      expect(gains.last, -2);
      // Values in between should move monotonically toward 0 as the curve
      // does (8 -> 5 -> 0), not jump around.
      for (var i = 0; i < 4; i++) {
        expect(gains[i], greaterThanOrEqualTo(gains[i + 1]));
      }
    });

    test('a single-band device gets the curve\'s middle region', () {
      final gains = distributeBuiltInPreset(BuiltInEqPreset.crystalClear, 1);
      expect(gains, [1]); // Crystal Clear's middle region ([-2, -1, 1, 4, 5][2])
    });

    test('an empty band list returns no gains', () {
      expect(distributeBuiltInPreset(BuiltInEqPreset.nocturnal, 0), isEmpty);
    });

    test('every gain is clamped within the device\'s reported range', () {
      final gains = distributeBuiltInPreset(BuiltInEqPreset.deepBass, 5, clampMinDb: -3, clampMaxDb: 3);
      for (final gain in gains) {
        expect(gain, inInclusiveRange(-3, 3));
      }
    });

    test('every built-in preset produces a curve for a standard 5-band device', () {
      for (final preset in BuiltInEqPreset.values) {
        final gains = distributeBuiltInPreset(preset, 5);
        expect(gains, hasLength(5));
      }
    });
  });
}
