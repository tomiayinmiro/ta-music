import 'package:flutter/material.dart';

import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../data/models/aura_level.dart';
import '../../../shared/widgets/glass_container.dart';

/// The Aura page's progress card: current level, tagline, a progress bar
/// toward the next level, and the minutes remaining. Matches
/// `designs/aura/local_stats/` — the "87% / Next: Supernova (1,204 mins
/// needed)" row.
class AuraLevelCard extends StatelessWidget {
  const AuraLevelCard({super.key, required this.progress});

  final AuraProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = progress.next;
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.containerMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Aura Level', style: theme.textTheme.headlineMedium),
                    Text(
                      next == null ? 'Max level reached' : 'Approaching ${next.displayName}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Text(
                '${(progress.progress * 100).round()}%',
                style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.stackMd),
          ClipRRect(
            borderRadius: AppRadius.borderRadiusFull,
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: theme.colorScheme.surfaceContainerHighest),
                  FractionallySizedBox(
                    widthFactor: progress.progress,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [theme.colorScheme.secondary, theme.colorScheme.primaryContainer],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.secondary.withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.stackSm),
          // A Row (matching the mockup's single-line layout) overflows once
          // both level names are long enough — e.g. "Current: Galactic
          // Voyager" + "Next: Supernova (19999 mins needed)" — so this
          // stacks the two instead of trying to fit them side by side.
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current: ${progress.level.displayName}', style: theme.textTheme.labelSmall),
              const SizedBox(height: 2),
              Text(
                next == null
                    ? 'Max level reached'
                    : 'Next: ${next.displayName} (${progress.minutesToNext} mins needed)',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
