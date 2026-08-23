import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/spacing.dart';
import '../../../data/providers/lyrics_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glass_container.dart';

/// Temporary diagnostic screen for the Phase 5 batch 1 rework — total
/// `lyrics_cache` rows, a breakdown by source, how many are confirmed
/// misses, and the oldest cached entry. TODO(Phase 5 batch 1): remove this
/// screen (and its Settings entry point) before release once the 3-layer
/// fallback chain's real-world coverage has been confirmed.
class LyricsCacheDebugScreen extends ConsumerWidget {
  const LyricsCacheDebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(lyricsCacheStatsProvider);
    final theme = Theme.of(context);

    return AppScaffold(
      appBar: AppBar(title: const Text('Lyrics cache (debug)')),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (stats) => ListView(
          padding: const EdgeInsets.all(AppSpacing.containerMargin),
          children: [
            GlassContainer(
              padding: const EdgeInsets.all(AppSpacing.stackMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatRow(label: 'Total rows', value: '${stats.totalRows}'),
                  _StatRow(label: 'Confirmed no-lyrics ("none")', value: '${stats.noneCount}'),
                  _StatRow(
                    label: 'Oldest entry',
                    value: stats.oldestFetchedAt?.toString() ?? '—',
                  ),
                  const Divider(height: AppSpacing.stackLg),
                  Text('By source', style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.stackSm),
                  if (stats.countBySource.isEmpty) const Text('No entries yet.'),
                  for (final entry in stats.countBySource.entries)
                    _StatRow(label: entry.key, value: '${entry.value}'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            FilledButton.icon(
              onPressed: () => ref.invalidate(lyricsCacheStatsProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
