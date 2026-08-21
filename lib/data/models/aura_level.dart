import 'package:flutter/foundation.dart';

/// The 8 Aura levels, ordered by ascending listening-minutes threshold.
/// Names, thresholds, and asset source folders come from `designs/aura/` —
/// see CLAUDE.md's Phase 4.5 section and `DESIGN_MAP.md`'s "Aura
/// gamification" table. [maxMinutes] is `null` only for [supernova], the
/// open-ended top level.
enum AuraLevel {
  atmosphere(
    minMinutes: 0,
    maxMinutes: 1400,
    displayName: 'Atmosphere',
    tagline: 'The beginning of the journey. Minimalist listening.',
    assetName: 'atmosphere',
  ),
  aurora(
    minMinutes: 1401,
    maxMinutes: 3000,
    displayName: 'Aurora',
    tagline: 'Starting to branch out into new genres and moods.',
    assetName: 'aurora',
  ),
  solarFlare(
    minMinutes: 3001,
    maxMinutes: 4200,
    displayName: 'Solar Flare',
    tagline: 'Consistent daily listening established.',
    assetName: 'solar_flare',
  ),
  eclipse(
    minMinutes: 4201,
    maxMinutes: 7000,
    displayName: 'Eclipse',
    tagline: 'Floating smoothly through complex audio landscapes.',
    assetName: 'eclipse',
  ),
  starlightNovice(
    minMinutes: 7001,
    maxMinutes: 10000,
    displayName: 'Starlight Novice',
    tagline: 'Exploring global frequencies and diverse artist origins.',
    assetName: 'starlight_novice',
  ),
  nebulaMaster(
    minMinutes: 10001,
    maxMinutes: 14700,
    displayName: 'Nebula Master',
    tagline: 'High-fidelity veteran. Reaching the elite upper echelons.',
    assetName: 'nebula_master',
  ),
  galacticVoyager(
    minMinutes: 14701,
    maxMinutes: 19999,
    displayName: 'Galactic Voyager',
    tagline: 'Your sonic footprint spans across vast musical constellations.',
    assetName: 'galactic_voyager',
  ),
  supernova(
    minMinutes: 20000,
    maxMinutes: null,
    displayName: 'Supernova',
    tagline: 'A high-impact milestone. Total sonic saturation.',
    assetName: 'supernova',
  );

  const AuraLevel({
    required this.minMinutes,
    required this.maxMinutes,
    required this.displayName,
    required this.tagline,
    required this.assetName,
  });

  /// Inclusive lower bound of this level's minutes range.
  final int minMinutes;

  /// Inclusive upper bound, or `null` for the open-ended top level.
  final int? maxMinutes;

  final String displayName;

  /// The level's general description, verbatim from `designs/aura/level_
  /// list/code.html` (the reference design's per-level copy) — used as the
  /// descriptive blurb on the level-up transition. Not the same as the Aura
  /// Level card's "Approaching X" line, which is computed dynamically from
  /// [AuraProgress.next] instead.
  final String tagline;
  final String assetName;

  /// 1-based level number (Atmosphere = 1 .. Supernova = 8), matching the
  /// numbering in `DESIGN_MAP.md` and what's persisted in `aura_state`.
  int get number => AuraLevel.values.indexOf(this) + 1;

  /// Bundled level image, cropped from `designs/aura/level_$assetName/` —
  /// see `assets/aura/`.
  String get imageAssetPath => 'assets/aura/level_$assetName.png';

  /// Resolves a persisted 1-based [number] back to its [AuraLevel].
  static AuraLevel fromNumber(int number) => AuraLevel.values[number - 1];
}

/// Resolves total listening minutes to the [AuraLevel] it falls in. Minutes
/// below 0 (shouldn't happen, but not worth a throw over) clamp to
/// [AuraLevel.atmosphere].
AuraLevel currentLevelFromMinutes(int totalMinutes) {
  for (final level in AuraLevel.values.reversed) {
    if (totalMinutes >= level.minMinutes) return level;
  }
  return AuraLevel.atmosphere;
}

/// Progress toward the next Aura level at a given total-minutes value.
@immutable
class AuraProgress {
  const AuraProgress({
    required this.level,
    required this.next,
    required this.progress,
    required this.minutesToNext,
  });

  /// The current level.
  final AuraLevel level;

  /// The next level to reach, or `null` if [level] is the top ([AuraLevel.supernova]).
  final AuraLevel? next;

  /// 0.0-1.0 progress from [level]'s threshold toward [next]'s threshold.
  /// Pinned to 1.0 when there is no next level.
  final double progress;

  /// Minutes remaining until [next] is reached. 0 when there is no next level.
  final int minutesToNext;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuraProgress &&
          runtimeType == other.runtimeType &&
          level == other.level &&
          next == other.next &&
          progress == other.progress &&
          minutesToNext == other.minutesToNext;

  @override
  int get hashCode => Object.hash(level, next, progress, minutesToNext);

  @override
  String toString() =>
      'AuraProgress(level: $level, next: $next, progress: $progress, minutesToNext: $minutesToNext)';
}

/// Computes [AuraProgress] for a given total-minutes value.
AuraProgress progressToNext(int totalMinutes) {
  final level = currentLevelFromMinutes(totalMinutes);
  final levelIndex = AuraLevel.values.indexOf(level);
  final isMaxLevel = levelIndex == AuraLevel.values.length - 1;
  if (isMaxLevel) {
    return AuraProgress(level: level, next: null, progress: 1.0, minutesToNext: 0);
  }

  final next = AuraLevel.values[levelIndex + 1];
  final span = next.minMinutes - level.minMinutes;
  final into = totalMinutes - level.minMinutes;
  final progress = span <= 0 ? 1.0 : (into / span).clamp(0.0, 1.0);
  final minutesToNext = (next.minMinutes - totalMinutes).clamp(0, next.minMinutes);

  return AuraProgress(level: level, next: next, progress: progress, minutesToNext: minutesToNext);
}
