import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/spacing.dart';
import '../../../data/providers/cache_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../shared/widgets/glass_container.dart';

enum _CacheType { coverArt, lyrics, translations, recommendations }

/// Settings > "Storage & Cache" — per-cache sizes and clear buttons, plus a
/// "Clear all caches" action. Replaces the old standalone "Clear
/// recommendation cache" button that used to live in the Recommendations
/// section; recommendations are just one of the four cache types here now.
///
/// `ConsumerStatefulWidget` to track which cache(s) are mid-clear, same
/// reasoning as `BackupRestoreSection` — plain widget state for a one-off
/// async action, not DB-reactive state.
class StorageCacheSection extends ConsumerStatefulWidget {
  const StorageCacheSection({super.key});

  @override
  ConsumerState<StorageCacheSection> createState() => _StorageCacheSectionState();
}

class _StorageCacheSectionState extends ConsumerState<StorageCacheSection> {
  final Set<_CacheType> _clearing = {};
  bool _clearingAll = false;

  Future<void> _clear(_CacheType type) async {
    setState(() => _clearing.add(type));
    try {
      final repo = await ref.read(cacheManagementRepositoryProvider.future);
      switch (type) {
        case _CacheType.coverArt:
          await repo.clearCoverArt();
        case _CacheType.lyrics:
          await repo.clearLyrics();
        case _CacheType.translations:
          await repo.clearTranslations();
        case _CacheType.recommendations:
          await repo.clearRecommendations();
      }
      ref.invalidate(cacheSizesProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cache cleared.')));
      }
    } finally {
      if (mounted) setState(() => _clearing.remove(type));
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear all caches?'),
        content: const Text(
          'Your playlists, favorites, listening history, and manually-added lyrics will NOT '
          'be affected. Cached lyrics, translations, cover art, and recommendation data will '
          'be regenerated as you use the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _clearingAll = true);
    try {
      final repo = await ref.read(cacheManagementRepositoryProvider.future);
      await repo.clearAll();
      ref.invalidate(cacheSizesProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('All caches cleared.')));
      }
    } finally {
      if (mounted) setState(() => _clearingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sizesAsync = ref.watch(cacheSizesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Storage & Cache', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.stackSm),
        Text(
          'Cached data helps the app run smoothly. Clearing caches frees up storage — '
          'content will be re-downloaded or regenerated as needed.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.stackMd),
        GlassContainer(
          padding: const EdgeInsets.all(AppSpacing.stackMd),
          child: sizesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.stackSm),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Text('Error: $e', style: theme.textTheme.bodySmall),
            data: (sizes) => Text(
              'TA Music is using ${formatCacheBytes(sizes.totalBytes)} total',
              style: theme.textTheme.titleMedium,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.stackSm),
        sizesAsync.maybeWhen(
          data: (sizes) => Column(
            children: [
              _CacheTile(
                icon: Icons.image_outlined,
                name: 'Album cover art',
                description: 'Extracted album art for your songs',
                sizeBytes: sizes.coverArtBytes,
                clearNote: 'Clearing forces re-extraction on next library scan',
                isClearing: _clearing.contains(_CacheType.coverArt),
                onClear: () => _clear(_CacheType.coverArt),
              ),
              const SizedBox(height: AppSpacing.stackSm),
              _CacheTile(
                icon: Icons.lyrics_outlined,
                name: 'Lyrics',
                description: 'Fetched song lyrics from LRCLIB and lyrics.ovh',
                sizeBytes: sizes.lyricsBytes,
                clearNote:
                    'Clearing forces re-fetching when you view lyrics. Your '
                    'manually-added lyrics will NOT be deleted.',
                isClearing: _clearing.contains(_CacheType.lyrics),
                onClear: () => _clear(_CacheType.lyrics),
              ),
              const SizedBox(height: AppSpacing.stackSm),
              _CacheTile(
                icon: Icons.translate_rounded,
                name: 'Translations',
                description: 'Translated lyric lines from MyMemory',
                sizeBytes: sizes.translationsBytes,
                clearNote: 'Clearing forces re-translation when you view translated lyrics',
                isClearing: _clearing.contains(_CacheType.translations),
                onClear: () => _clear(_CacheType.translations),
              ),
              const SizedBox(height: AppSpacing.stackSm),
              _CacheTile(
                icon: Icons.auto_awesome_outlined,
                name: 'Recommendations',
                description: 'Seed choices and cached recommendation data',
                sizeBytes: sizes.recommendationsBytes,
                clearNote:
                    'Clearing resets recommendations — the app rebuilds them fresh '
                    'from your listening history',
                isClearing: _clearing.contains(_CacheType.recommendations),
                onClear: () => _clear(_CacheType.recommendations),
              ),
            ],
          ),
          orElse: () => const SizedBox.shrink(),
        ),
        const SizedBox(height: AppSpacing.stackLg),
        OutlinedButton.icon(
          onPressed: _clearingAll ? null : _clearAll,
          icon: _clearingAll
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_sweep_outlined),
          label: Text(_clearingAll ? 'Clearing…' : 'Clear all caches'),
        ),
      ],
    );
  }
}

/// `1.0 MB`/`24.0 KB`-style formatting for cache sizes — no existing
/// formatter for this in the codebase (file sizes elsewhere are shown as raw
/// `songs.file_size` in the Song Info dialog, unformatted).
String formatCacheBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class _CacheTile extends StatelessWidget {
  const _CacheTile({
    required this.icon,
    required this.name,
    required this.description,
    required this.sizeBytes,
    required this.clearNote,
    required this.isClearing,
    required this.onClear,
  });

  final IconData icon;
  final String name;
  final String description;
  final int sizeBytes;
  final String clearNote;
  final bool isClearing;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.stackMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.stackSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.titleMedium),
                    Text(description, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.stackSm),
              Text(formatCacheBytes(sizeBytes), style: theme.textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.stackSm),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: isClearing ? null : onClear,
              icon: isClearing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text(isClearing ? 'Clearing…' : 'Clear'),
            ),
          ),
          const SizedBox(height: 4),
          Text(clearNote, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
