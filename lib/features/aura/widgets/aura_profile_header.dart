import 'package:flutter/material.dart';

import '../../../core/theme/elevation.dart';
import '../../../core/theme/spacing.dart';
import '../../../data/models/aura_level.dart';

/// The Aura page's profile section: the current level's bundled image in a
/// glowing ring, the static "Aura Listener" name (no accounts, no editable
/// profile — see CLAUDE.md), and a level badge chip.
class AuraProfileHeader extends StatelessWidget {
  const AuraProfileHeader({super.key, required this.level});

  final AuraLevel level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 128,
          height: 128,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: theme.colorScheme.primaryContainer, width: 2),
            boxShadow: [AppElevation.activeGlow(theme.colorScheme.primaryContainer)],
          ),
          child: ClipOval(
            child: Image.asset(level.imageAssetPath, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: AppSpacing.stackSm),
        Text('Aura Listener', style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.stackSm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: theme.colorScheme.secondary),
              const SizedBox(width: 6),
              Text(
                level.displayName.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.secondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
