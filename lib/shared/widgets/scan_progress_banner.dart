import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';
import '../../data/providers/library_providers.dart';
import '../../data/services/library_scanner.dart';
import 'glass_container.dart';

/// Persistent banner shown above the bottom nav while a library scan is
/// running, per the Phase 2 brief. Reads [libraryScanControllerProvider] so
/// it can be dropped into any screen without plumbing scan state through.
class ScanProgressBanner extends ConsumerWidget {
  const ScanProgressBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(libraryScanControllerProvider);
    if (progress == null) return const SizedBox.shrink();

    final theme = Theme.of(context);

    if (progress.error != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.stackSm,
        ),
        child: GlassContainer(
          padding: const EdgeInsets.all(AppSpacing.stackMd),
          child: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: theme.colorScheme.error),
              const SizedBox(width: AppSpacing.stackSm),
              Expanded(
                child: Text('Scan failed: ${progress.error}', style: theme.textTheme.bodySmall),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => ref.read(libraryScanControllerProvider.notifier).dismiss(),
              ),
            ],
          ),
        ),
      );
    }

    if (progress.isDone) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.stackSm,
        ),
        child: GlassContainer(
          padding: const EdgeInsets.all(AppSpacing.stackMd),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.stackSm),
              Expanded(
                child: Text(
                  'Scan complete — ${progress.inserted} added, ${progress.updated} updated'
                  '${progress.missing > 0 ? ', ${progress.missing} removed' : ''}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => ref.read(libraryScanControllerProvider.notifier).dismiss(),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.stackSm),
      child: GlassContainer(
        padding: const EdgeInsets.all(AppSpacing.stackMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.stackSm),
                Expanded(
                  child: Text(
                    _statusText(progress),
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.stackSm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.total > 0 ? progress.fraction : null,
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusText(ScanProgress progress) {
    if (progress.total <= 0) return 'Scanning your library…';
    return 'Scanning ${progress.scanned} of ${progress.total}…';
  }
}
