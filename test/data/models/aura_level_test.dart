import 'package:flutter_test/flutter_test.dart';
import 'package:ta_music/data/models/aura_level.dart';

void main() {
  group('currentLevelFromMinutes boundaries', () {
    final cases = <int, AuraLevel>{
      0: AuraLevel.atmosphere,
      1400: AuraLevel.atmosphere,
      1401: AuraLevel.aurora,
      3000: AuraLevel.aurora,
      3001: AuraLevel.solarFlare,
      4200: AuraLevel.solarFlare,
      4201: AuraLevel.eclipse,
      7000: AuraLevel.eclipse,
      7001: AuraLevel.starlightNovice,
      10000: AuraLevel.starlightNovice,
      10001: AuraLevel.nebulaMaster,
      14700: AuraLevel.nebulaMaster,
      14701: AuraLevel.galacticVoyager,
      19999: AuraLevel.galacticVoyager,
      20000: AuraLevel.supernova,
      999999: AuraLevel.supernova,
    };

    for (final entry in cases.entries) {
      test('${entry.key} mins -> ${entry.value.displayName}', () {
        expect(currentLevelFromMinutes(entry.key), entry.value);
      });
    }

    test('negative minutes clamp to Atmosphere', () {
      expect(currentLevelFromMinutes(-1), AuraLevel.atmosphere);
    });
  });

  group('AuraLevel.number / fromNumber', () {
    test('numbers are 1-based in declaration order', () {
      expect(AuraLevel.atmosphere.number, 1);
      expect(AuraLevel.aurora.number, 2);
      expect(AuraLevel.solarFlare.number, 3);
      expect(AuraLevel.eclipse.number, 4);
      expect(AuraLevel.starlightNovice.number, 5);
      expect(AuraLevel.nebulaMaster.number, 6);
      expect(AuraLevel.galacticVoyager.number, 7);
      expect(AuraLevel.supernova.number, 8);
    });

    test('fromNumber round-trips with number', () {
      for (final level in AuraLevel.values) {
        expect(AuraLevel.fromNumber(level.number), level);
      }
    });
  });

  group('progressToNext', () {
    test('0 mins: fresh into Atmosphere, 0% toward Aurora', () {
      final p = progressToNext(0);
      expect(p.level, AuraLevel.atmosphere);
      expect(p.next, AuraLevel.aurora);
      expect(p.progress, 0.0);
      expect(p.minutesToNext, 1401);
    });

    test('1400 mins: last minute of Atmosphere, just under 100% toward Aurora', () {
      final p = progressToNext(1400);
      expect(p.level, AuraLevel.atmosphere);
      expect(p.next, AuraLevel.aurora);
      expect(p.progress, closeTo(1400 / 1401, 1e-9));
      expect(p.minutesToNext, 1);
    });

    test('1401 mins: fresh into Aurora, 0% toward Solar Flare', () {
      final p = progressToNext(1401);
      expect(p.level, AuraLevel.aurora);
      expect(p.next, AuraLevel.solarFlare);
      expect(p.progress, 0.0);
      expect(p.minutesToNext, 3001 - 1401);
    });

    test('10001 mins: fresh into Nebula Master, matches the mockup shape', () {
      final p = progressToNext(10001);
      expect(p.level, AuraLevel.nebulaMaster);
      expect(p.next, AuraLevel.galacticVoyager);
      expect(p.progress, 0.0);
    });

    test('20000 mins: Supernova has no next level and reads as 100% complete', () {
      final p = progressToNext(20000);
      expect(p.level, AuraLevel.supernova);
      expect(p.next, isNull);
      expect(p.progress, 1.0);
      expect(p.minutesToNext, 0);
    });

    test('999999 mins: still Supernova, still capped', () {
      final p = progressToNext(999999);
      expect(p.level, AuraLevel.supernova);
      expect(p.next, isNull);
      expect(p.progress, 1.0);
      expect(p.minutesToNext, 0);
    });
  });
}
