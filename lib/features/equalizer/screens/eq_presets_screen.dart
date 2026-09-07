import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../data/models/eq_preset.dart';
import '../../../data/providers/equalizer_providers.dart';
import '../../../data/providers/playback_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glass_container.dart';

/// Custom EQ preset management — `designs/custom_eq_presets/`. Reachable
/// only from the Equalizer screen, itself Android-only, so this screen never
/// needs its own platform gate (see CLAUDE.md, Phase 6 batch 2).
class EqPresetsScreen extends ConsumerStatefulWidget {
  const EqPresetsScreen({super.key});

  @override
  ConsumerState<EqPresetsScreen> createState() => _EqPresetsScreenState();
}

class _EqPresetsScreenState extends ConsumerState<EqPresetsScreen> {
  final _nameController = TextEditingController();
  EqPresetIcon _selectedIcon = EqPresetIcon.graphicEq;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    try {
      final gains = await ref.read(equalizerBandGainsProvider.future);
      final repo = await ref.read(eqPresetRepositoryProvider.future);
      await repo.save(name: name, icon: _selectedIcon, bandGains: gains);
      _nameController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved "$name".')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _apply(EqPreset preset) async {
    final params = await ref.read(equalizerParametersProvider.future);
    final service = ref.read(playbackServiceProvider);
    await service.setEqualizerEnabled(true);
    final count = params.bands.length < preset.bandGains.length ? params.bands.length : preset.bandGains.length;
    for (var i = 0; i < count; i++) {
      await service.setEqualizerBandGain(i, preset.bandGains[i]);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Applied "${preset.name}".')));
    }
  }

  Future<void> _rename(EqPreset preset) async {
    final controller = TextEditingController(text: preset.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename preset'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;
    final repo = await ref.read(eqPresetRepositoryProvider.future);
    await repo.rename(preset, newName);
  }

  Future<void> _delete(EqPreset preset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete preset?'),
        content: Text('"${preset.name}" will be removed permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    final repo = await ref.read(eqPresetRepositoryProvider.future);
    await repo.delete(preset.id!);
  }

  @override
  Widget build(BuildContext context) {
    final presetsAsync = ref.watch(eqPresetsProvider);

    return AppScaffold(
      appBar: AppBar(title: const Text('Custom EQ Presets')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.containerMargin),
        children: [
          Text(
            'Manage your personalized audio environments.',
            style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.stackLg),
          GlassContainer(
            padding: const EdgeInsets.all(AppSpacing.containerMargin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SAVE CURRENT EQ',
                  style: AppTypography.labelMd.copyWith(color: AppColors.primary),
                ),
                const SizedBox(height: AppSpacing.stackMd),
                Row(
                  children: [
                    for (final icon in EqPresetIcon.values)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.stackSm),
                        child: _IconPickerButton(
                          icon: icon,
                          selected: icon == _selectedIcon,
                          onTap: () => setState(() => _selectedIcon = icon),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.stackMd),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(hintText: 'Preset Name (e.g. Late Night Jazz)'),
                ),
                const SizedBox(height: AppSpacing.stackMd),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save Preset'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.stackLg),
          Text(
            'SAVED ENVIRONMENTS',
            style: AppTypography.labelMd.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.stackSm),
          presetsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.stackLg),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Error: $e'),
            data: (presets) {
              if (presets.isEmpty) {
                return Text(
                  "You haven't saved any presets yet.",
                  style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                );
              }
              return Column(
                children: [
                  for (final preset in presets)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.stackSm),
                      child: GlassContainer(
                        padding: const EdgeInsets.all(AppSpacing.stackMd),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.2),
                              child: Icon(_iconData(preset.icon), color: AppColors.primary),
                            ),
                            const SizedBox(width: AppSpacing.stackMd),
                            Expanded(
                              child: InkWell(
                                onTap: () => _apply(preset),
                                child: Text(preset.name, style: AppTypography.bodyLg),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _rename(preset),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 20),
                              onPressed: () => _delete(preset),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _iconData(EqPresetIcon icon) => switch (icon) {
    EqPresetIcon.graphicEq => Icons.graphic_eq_rounded,
    EqPresetIcon.headphones => Icons.headphones_rounded,
    EqPresetIcon.speaker => Icons.speaker_rounded,
  };
}

class _IconPickerButton extends StatelessWidget {
  const _IconPickerButton({required this.icon, required this.selected, required this.onTap});

  final EqPresetIcon icon;
  final bool selected;
  final VoidCallback onTap;

  IconData get _iconData => switch (icon) {
    EqPresetIcon.graphicEq => Icons.graphic_eq_rounded,
    EqPresetIcon.headphones => Icons.headphones_rounded,
    EqPresetIcon.speaker => Icons.speaker_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderRadiusFull,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(
            color: selected ? AppColors.primary.withValues(alpha: 0.3) : AppColors.outlineVariant,
          ),
        ),
        child: Icon(_iconData, color: selected ? AppColors.primary : AppColors.onSurfaceVariant),
      ),
    );
  }
}
