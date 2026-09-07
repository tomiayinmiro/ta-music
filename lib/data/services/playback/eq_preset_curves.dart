/// Quick-preset EQ curves shown on the main Equalizer screen
/// (`designs/audio_engine_eq/`'s "Presets" row) — distinct from user-saved
/// custom presets (`EqPreset`/`custom_eq_presets`), which snapshot literal
/// per-band gains for one specific device instead.
///
/// `spatialFocus` (the mockup's fourth preset) doesn't exist here — it
/// implied real spatial/3D audio processing this app doesn't have, so it was
/// renamed to [vocalBoost] rather than shipped as a mislabeled EQ curve.
enum BuiltInEqPreset {
  deepBass('Deep Bass'),
  nocturnal('Nocturnal'),
  crystalClear('Crystal Clear'),
  vocalBoost('Vocal Boost');

  const BuiltInEqPreset(this.label);

  final String label;
}

/// Each curve is defined across 5 canonical frequency regions (bass, low-mid,
/// mid, high-mid, treble) rather than a fixed band index — device equalizers
/// don't all report the same band count, and there's no way to set gain at
/// an arbitrary frequency that isn't backed by a real hardware band. See
/// [distributeBuiltInPreset].
const Map<BuiltInEqPreset, List<double>> _curveRegionGainsDb = {
  BuiltInEqPreset.deepBass: [8, 5, 0, -1, -2],
  BuiltInEqPreset.nocturnal: [4, 2, -1, -3, -4],
  BuiltInEqPreset.crystalClear: [-2, -1, 1, 4, 5],
  BuiltInEqPreset.vocalBoost: [-3, 1, 5, 3, -1],
};

/// Distributes [preset]'s 5-region curve across however many bands the
/// device's real equalizer reports, by mapping each band's normalized
/// position (0..1 across the band index range) onto the curve via linear
/// interpolation between its two nearest regions. Pure and side-effect-free
/// so it's unit-testable without a real `AndroidEqualizer` — see
/// `eq_preset_curves_test.dart`.
///
/// Every returned gain is clamped to [clampMinDb]/[clampMaxDb], the device's
/// own reported `AndroidEqualizerParameters.minDecibels`/`maxDecibels` — a
/// device with a narrower range than this curve's peak values (±8dB) still
/// gets a sensible, in-range result instead of a rejected out-of-range
/// `setGain` call.
List<double> distributeBuiltInPreset(
  BuiltInEqPreset preset,
  int bandCount, {
  double clampMinDb = -12,
  double clampMaxDb = 12,
}) {
  if (bandCount <= 0) return const [];
  final curve = _curveRegionGainsDb[preset]!;
  if (bandCount == 1) {
    return [curve[curve.length ~/ 2].clamp(clampMinDb, clampMaxDb)];
  }

  return List<double>.generate(bandCount, (i) {
    final t = i / (bandCount - 1); // 0..1 across the device's bands
    final pos = t * (curve.length - 1); // 0..(regionCount-1)
    final lower = pos.floor();
    final upper = pos.ceil();
    final frac = pos - lower;
    final gain = curve[lower] + (curve[upper] - curve[lower]) * frac;
    return gain.clamp(clampMinDb, clampMaxDb);
  });
}
