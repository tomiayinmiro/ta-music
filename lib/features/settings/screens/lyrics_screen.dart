import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/spacing.dart';
import '../../../data/providers/database_providers.dart';
import '../../../data/providers/lyrics_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/providers/translation_providers.dart';
import '../../../data/services/translation/mymemory_languages.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glass_container.dart';
import 'language_selector_screen.dart';

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
    final translationLangAsync = ref.watch(translationTargetLanguageProvider);
    final translationStatsAsync = ref.watch(translationCacheStatsProvider);
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
          const SizedBox(height: AppSpacing.stackLg),
          Text('Translation', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.stackSm),
          Text(
            'Pick a language to show a translation below each lyric line on Now '
            'Playing. Translations are cached per line, so replaying a song is instant.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.stackMd),
          GlassContainer(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.translate_rounded),
              title: const Text('Translation language'),
              subtitle: Text(
                translationLangAsync.when(
                  data: (code) => code == null
                      ? 'None'
                      : (translationLanguageForCode(code)?.englishName ?? code),
                  loading: () => '…',
                  error: (_, _) => 'None',
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final picked = await Navigator.of(context).push<String?>(
                  MaterialPageRoute<String?>(
                    builder: (_) =>
                        LanguageSelectorScreen(selectedCode: translationLangAsync.value),
                  ),
                );
                if (picked == null) return;
                final repo = await ref.read(settingsRepositoryProvider.future);
                await repo.setTranslationTargetLanguage(picked.isEmpty ? null : picked);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.stackMd),
          const _TranslationQualityDisclaimer(),
          const SizedBox(height: AppSpacing.stackMd),
          translationStatsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (stats) => GlassContainer(
              padding: const EdgeInsets.all(AppSpacing.stackMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatRow(label: 'Total translations cached', value: '${stats.totalRows}'),
                  const Divider(height: AppSpacing.stackLg),
                  Text('By target language', style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.stackSm),
                  if (stats.countByTargetLang.isEmpty) const Text('No entries yet.'),
                  for (final entry in stats.countByTargetLang.entries)
                    _StatRow(
                      label: translationLanguageForCode(entry.key)?.englishName ?? entry.key,
                      value: '${entry.value}',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.stackMd),
          OutlinedButton.icon(
            onPressed: () => _confirmClearTranslationCache(context, ref),
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Clear translation cache'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearTranslationCache(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear translation cache?'),
        content: const Text(
          'Every cached line translation will be deleted. They\'ll be re-fetched from '
          'MyMemory the next time you view translated lyrics.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Clear')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final dao = await ref.read(translationsCacheDaoProvider.future);
    await dao.clearAll();
    ref.invalidate(translationCacheStatsProvider);
  }
}

/// Collapsed by default — informational, not a warning, so it shouldn't
/// compete for attention every time this screen opens. Deliberately not
/// duplicated as an inline hint in the lyrics view itself (Phase 5 batch 2
/// UX fix spec): a hint the user sees on every song trains them to dismiss
/// it reflexively, which undermines a real warning later.
class _TranslationQualityDisclaimer extends StatelessWidget {
  const _TranslationQualityDisclaimer();

  static const _bullets = [
    'Songs with slang, poetry, or wordplay',
    'Songs that mix multiple languages',
    'Less-common languages',
    'Very short lines lacking context',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return GlassContainer(
      padding: EdgeInsets.zero,
      child: Theme(
        // The default ExpansionTile divider doesn't fit GlassContainer's
        // borderless glass-panel look — matches how ListTiles are used bare
        // (no Card) elsewhere on this screen.
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(Icons.info_outline_rounded, color: theme.colorScheme.onSurfaceVariant),
          title: Text('About translation quality', style: mutedStyle),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.stackMd,
            0,
            AppSpacing.stackMd,
            AppSpacing.stackMd,
          ),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Translations come from MyMemory, a free public translation service. Quality '
              'varies, and some lines may translate awkwardly — especially:',
              style: mutedStyle,
            ),
            const SizedBox(height: AppSpacing.stackSm),
            for (final bullet in _bullets)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('•  $bullet', style: mutedStyle),
              ),
            const SizedBox(height: AppSpacing.stackSm),
            Text(
              'This is an inherent limitation of automatic translation and cannot be fully '
              'fixed by the app.',
              style: mutedStyle,
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
