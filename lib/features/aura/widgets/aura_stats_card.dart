import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/utils/duration_format.dart';
import '../../../shared/widgets/glass_container.dart';

/// The Aura page's "Aura Stats" card: all-time total listening minutes
/// (cached, see `AuraService.recompute`) and total songs played.
class AuraStatsCard extends StatelessWidget {
  const AuraStatsCard({super.key, required this.totalMinutes, required this.totalSongsPlayed});

  final int totalMinutes;
  final int totalSongsPlayed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.containerMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Aura Stats', style: theme.textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.stackMd),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  icon: Icons.headphones_rounded,
                  iconColor: theme.colorScheme.primary,
                  value: formatMinutesCompact(totalMinutes),
                  label: 'TOTAL MINS',
                ),
              ),
              Expanded(
                child: _Stat(
                  icon: Icons.explore_outlined,
                  iconColor: theme.colorScheme.secondary,
                  value: '$totalSongsPlayed',
                  label: 'SONGS PLAYED',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.displayLarge),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}
