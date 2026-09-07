import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/eq_preset.dart';
import '../services/playback/playback_models.dart';
import 'playback_providers.dart';
import 'repository_providers.dart';

/// Whether the current platform can drive a live equalizer at all —
/// Android only (Phase 6 batch 2, see CLAUDE.md). Settings and any
/// equalizer entry point are gated on this rather than showing a disabled
/// state, per the approved "hide entirely on Windows" decision.
final isEqualizerSupportedProvider = Provider<bool>((ref) {
  return ref.watch(playbackServiceProvider).isEqualizerSupported;
});

/// The device's real equalizer band layout. Stays loading until audio has
/// actually been loaded at least once this session — see
/// `AudioPlayerHandler.equalizerParameters`'s doc.
final equalizerParametersProvider = FutureProvider<EqualizerParameters>((ref) {
  return ref.watch(playbackServiceProvider).equalizerParameters;
});

final equalizerEnabledProvider = StreamProvider<bool>((ref) {
  return ref.watch(playbackServiceProvider).equalizerEnabledStream;
});

/// Live gain (decibels) for every device band, in band-index order.
final equalizerBandGainsProvider = StreamProvider<List<double>>((ref) {
  return ref.watch(playbackServiceProvider).equalizerBandGainsStream;
});

final eqPresetsProvider = StreamProvider<List<EqPreset>>((ref) async* {
  final repo = await ref.watch(eqPresetRepositoryProvider.future);
  yield* repo.watchAll();
});
