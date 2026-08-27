import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/spacing.dart';
import '../../../data/providers/lyrics_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glass_container.dart';

/// Settings screen for the lyrics fallback chain — started as a temporary
/// debug view (total cache rows, breakdown by source) and grew a real user
/// feature in the Phase 5 batch 1 bug-fix pass: managing lyrics added
/// manually from the Now Playing lyrics panel (see
/// `ManualLyricsEditorScreen`). The stats block is TODO(Phase 5 batch 1) for
/// removal before release; the manual-entries list is not.
class LyricsScreen extends ConsumerWidget {
  const LyricsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(lyricsCacheStatsProvider);
    final manualAsync = ref.watch(manualLyricsEntriesProvider);
    final theme = Theme.of(context);

    return AppScaffold(
      appBar: AppBar(title: const Text('Lyrics')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.containerMargin),
        children: [
          statsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (stats) => GlassContainer(
              padding: const EdgeInsets.all(AppSpacing.stackMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatRow(label: 'Total rows', value: '${stats.totalRows}'),
                  _StatRow(label: 'Confirmed no-lyrics ("none")', value: '${stats.noneCount}'),
                  _StatRow(label: 'Oldest entry', value: stats.oldestFetchedAt?.toString() ?? '—'),
                  const Divider(height: AppSpacing.stackLg),
                  Text('By source', style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.stackSm),
                  if (stats.countBySource.isEmpty) const Text('No entries yet.'),
                  for (final entry in stats.countBySource.entries)
                    _StatRow(label: entry.key, value: '${entry.value}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.stackMd),
          FilledButton.icon(
            onPressed: () => ref.invalidate(lyricsCacheStatsProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
          ),
          const SizedBox(height: AppSpacing.stackLg),
          Text('Manually added lyrics', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.stackSm),
          Text(
            'When we can\'t find lyrics for a song, you can add them yourself from the Now '
            'Playing screen. Delete an entry here to let the app search the online database '
            'again on next play.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.stackMd),
          manualAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (entries) => entries.isEmpty
                ? const Text('You haven\'t added any lyrics manually yet.')
                : GlassContainer(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final entry in entries)
                          ListTile(
                            title: Text(entry.displayTitle),
                            subtitle: Text(entry.displayArtist),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded),
                              tooltip: 'Delete',
                              onPressed: () async {
                                final repo = await ref.read(lyricsRepositoryProvider.future);
                                await repo.deleteManualLyrics(
                                  artistKey: entry.artistKey,
                                  titleKey: entry.titleKey,
                                );
                                ref.invalidate(manualLyricsEntriesProvider);
                                ref.invalidate(lyricsCacheStatsProvider);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
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
