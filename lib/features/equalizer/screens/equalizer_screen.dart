import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers/equalizer_providers.dart';
import '../../../data/providers/playback_providers.dart';
import '../../../data/services/playback/eq_preset_curves.dart';
import '../../../data/services/playback/playback_models.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glass_container.dart';
import 'eq_presets_screen.dart';

/// The main Equalizer screen — `designs/audio_engine_eq/`, Android-only
/// (Phase 6 batch 2, see CLAUDE.md). Renders however many bands the
/// device's real `AndroidEqualizer` reports rather than the mockup's
/// hardcoded 10, since gain can only be set on a real hardware band (see
/// `distributeBuiltInPreset`'s doc). The mockup's "High-Fidelity Audio" /
/// "Spatial Audio" toggles are dropped entirely — neither maps to a real
/// capability in this offline-only app.
class EqualizerScreen extends ConsumerWidget {
  const EqualizerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paramsAsync = ref.watch(equalizerParametersProvider);
    final enabledAsync = ref.watch(equalizerEnabledProvider);
    final gainsAsync = ref.watch(equalizerBandGainsProvider);

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Equalizer'),
        actions: [
          IconButton(
            tooltip: 'Custom presets',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => const EqPresetsScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.containerMargin),
        children: [
          const _AmbientPanel(),
          const SizedBox(height: AppSpacing.stackLg),
          GlassContainer(
            padding: const EdgeInsets.all(AppSpacing.containerMargin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Equalizer', style: AppTypography.headlineMd.copyWith(color: AppColors.onSurface)),
                          const SizedBox(height: 2),
                          Text(
                            'Custom tuning profile',
                            style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: enabledAsync.value ?? false,
                      onChanged: (value) =>
                          ref.read(playbackServiceProvider).setEqualizerEnabled(value),
                    ),
                  ],
                ),
                const Divider(height: AppSpacing.stackLg, color: AppColors.outlineVariant),
                paramsAsync.when(
                  loading: () => const _WaitingForPlaybackNotice(),
                  error: (e, _) => const _WaitingForPlaybackNotice(),
                  data: (params) {
                    final gains = gainsAsync.value;
                    if (params.bands.isEmpty || gains == null || gains.length != params.bands.length) {
                      return const _WaitingForPlaybackNotice();
                    }
                    return _EqBandSliders(params: params, gains: gains);
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: paramsAsync.hasValue
                        ? () => _resetAll(ref, paramsAsync.value!.bands.length)
                        : null,
                    icon: const Icon(Icons.restart_alt_rounded, size: 18),
                    label: const Text('Reset'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.stackLg),
          Text(
            'PRESETS',
            style: AppTypography.labelMd.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.stackSm),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.gutter,
            crossAxisSpacing: AppSpacing.gutter,
            childAspectRatio: 2.6,
            children: [
              for (final preset in BuiltInEqPreset.values)
                _PresetButton(
                  preset: preset,
                  icon: _iconFor(preset),
                  enabled: paramsAsync.hasValue,
                  onTap: () => _applyBuiltInPreset(ref, preset, paramsAsync.value!.bands.length),
                ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconFor(BuiltInEqPreset preset) => switch (preset) {
    BuiltInEqPreset.deepBass => Icons.graphic_eq_rounded,
    BuiltInEqPreset.nocturnal => Icons.dark_mode_rounded,
    BuiltInEqPreset.crystalClear => Icons.diamond_outlined,
    BuiltInEqPreset.vocalBoost => Icons.mic_rounded,
  };

  Future<void> _applyBuiltInPreset(WidgetRef ref, BuiltInEqPreset preset, int bandCount) async {
    final gains = distributeBuiltInPreset(preset, bandCount);
    final service = ref.read(playbackServiceProvider);
    await service.setEqualizerEnabled(true);
    for (var i = 0; i < gains.length; i++) {
      await service.setEqualizerBandGain(i, gains[i]);
    }
  }

  Future<void> _resetAll(WidgetRef ref, int bandCount) async {
    final service = ref.read(playbackServiceProvider);
    for (var i = 0; i < bandCount; i++) {
      await service.setEqualizerBandGain(i, 0);
    }
  }
}

class _WaitingForPlaybackNotice extends StatelessWidget {
  const _WaitingForPlaybackNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.stackLg),
      child: Column(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(height: AppSpacing.stackSm),
          Text(
            'Play a song to activate the equalizer — its bands come from your '
            "device's own audio hardware.",
            textAlign: TextAlign.center,
            style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _EqBandSliders extends ConsumerWidget {
  const _EqBandSliders({required this.params, required this.gains});

  final EqualizerParameters params;
  final List<double> gains;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 260,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < params.bands.length; i++)
            Expanded(
              child: _EqBandSlider(
                band: params.bands[i],
                gain: gains[i],
                minDb: params.minDecibels,
                maxDb: params.maxDecibels,
                onChanged: (value) =>
                    ref.read(playbackServiceProvider).setEqualizerBandGain(i, value),
              ),
            ),
        ],
      ),
    );
  }
}

class _EqBandSlider extends StatelessWidget {
  const _EqBandSlider({
    required this.band,
    required this.gain,
    required this.minDb,
    required this.maxDb,
    required this.onChanged,
  });

  final EqualizerBand band;
  final double gain;
  final double minDb;
  final double maxDb;
  final ValueChanged<double> onChanged;

  String get _frequencyLabel {
    final hz = band.centerFrequencyHz;
    return hz >= 1000 ? '${(hz / 1000).toStringAsFixed(hz % 1000 == 0 ? 0 : 1)}k' : hz.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(maxDb.toStringAsFixed(0), style: AppTypography.labelSm.copyWith(color: AppColors.textTertiary)),
        Expanded(
          child: RotatedBox(
            quarterTurns: -1,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.secondary,
                inactiveTrackColor: AppColors.outlineVariant,
                thumbColor: AppColors.onSurface,
                overlayColor: AppColors.secondary.withValues(alpha: 0.2),
                trackHeight: 4,
              ),
              child: Slider(
                value: gain.clamp(minDb, maxDb),
                min: minDb,
                max: maxDb,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
        Text(minDb.toStringAsFixed(0), style: AppTypography.labelSm.copyWith(color: AppColors.textTertiary)),
        const SizedBox(height: 6),
        Text(_frequencyLabel, style: AppTypography.labelSm.copyWith(color: AppColors.onSurface)),
      ],
    );
  }
}

class _PresetButton extends StatelessWidget {
  const _PresetButton({required this.preset, required this.icon, required this.enabled, required this.onTap});

  final BuiltInEqPreset preset;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: AppRadius.borderRadiusMd,
          onTap: enabled ? onTap : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: enabled ? AppColors.secondary : AppColors.outline),
              const SizedBox(width: AppSpacing.stackSm),
              Flexible(
                child: Text(
                  preset.label,
                  style: AppTypography.labelMd.copyWith(
                    color: enabled ? AppColors.onSurface : AppColors.outline,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Purely decorative ambient header — a looping, non-audio-reactive visual
/// (approved: real audio-reactive visualizers are v1.5 scope, see
/// BACKLOG.md). Stands in for the mockup's animated waveform SVG without a
/// misleading "Live Sync" label, since nothing here is actually syncing to
/// anything.
class _AmbientPanel extends StatelessWidget {
  const _AmbientPanel();

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      child: SizedBox(
        height: 96,
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 5; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(
                        width: 6,
                        height: 28,
                        decoration: BoxDecoration(
                          color: i.isEven ? AppColors.secondary : AppColors.primary,
                          borderRadius: AppRadius.borderRadiusFull,
                        ),
                      )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scaleY(
                        begin: 0.3,
                        end: 1.4,
                        duration: (600 + i * 120).ms,
                        curve: Curves.easeInOut,
                      ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
