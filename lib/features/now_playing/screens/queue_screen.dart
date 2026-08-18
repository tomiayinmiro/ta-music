import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../data/models/song.dart';
import '../../../data/providers/library_providers.dart';
import '../../../data/providers/playback_providers.dart';
import '../../../shared/widgets/cover_art.dart';
import '../../../shared/widgets/glass_container.dart';

/// "Up Next" queue — matches `designs/up_next_queue_gestures/`: a pinned
/// "Now Playing" row, then the upcoming queue as a reorderable, swipeable
/// list (drag handle to reorder, swipe left to remove, swipe right to move
/// a track to play next). Opened as a bottom sheet.
class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final snapshotAsync = ref.watch(playbackSnapshotProvider);
    final snapshot = snapshotAsync.value;
    final playbackService = ref.read(playbackServiceProvider);

    final queue = snapshot?.queue ?? const <Song>[];
    final currentIndex = snapshot?.currentIndex;
    final current = snapshot?.currentSong;
    final upcoming = currentIndex != null ? queue.sublist(currentIndex + 1) : const <Song>[];
    final offset = (currentIndex ?? -1) + 1;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.stackSm),
          child: GlassContainer(
            borderRadius: const BorderRadius.vertical(top: AppRadius.radiusXl),
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: AppRadius.borderRadiusFull,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.containerMargin,
                    vertical: AppSpacing.stackSm,
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 48),
                      Expanded(
                        child: Text('Up Next', textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
                      ),
                      TextButton(
                        onPressed: upcoming.isEmpty ? null : playbackService.clearQueue,
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerMargin),
                    children: [
                      if (current != null) ...[
                        Text(
                          'NOW PLAYING',
                          style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary),
                        ),
                        const SizedBox(height: AppSpacing.stackSm),
                        _QueueTile(
                          song: current,
                          isCurrent: true,
                          coverArtPath: current.albumId != null
                              ? ref.watch(albumByIdProvider(current.albumId!)).value?.coverArtPath
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.stackLg),
                      ],
                      Text(
                        'NEXT IN QUEUE',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: AppSpacing.stackSm),
                      if (upcoming.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.stackLg),
                          child: Text(
                            'Nothing queued after this.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        )
                      else
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          itemCount: upcoming.length,
                          // `onReorderItem` (not the deprecated `onReorder`)
                          // already adjusts `newIndex` for the removed item
                          // at `oldIndex`, matching what `reorderQueue`
                          // expects — no manual off-by-one correction here.
                          onReorderItem: (oldIndex, newIndex) {
                            playbackService.reorderQueue(offset + oldIndex, offset + newIndex);
                          },
                          itemBuilder: (context, i) {
                            final song = upcoming[i];
                            return Dismissible(
                              key: ValueKey(song.id ?? song.path),
                              direction: DismissDirection.horizontal,
                              background: _SwipeBackground(
                                alignment: Alignment.centerLeft,
                                color: theme.colorScheme.secondaryContainer,
                                icon: Icons.skip_next_rounded,
                                label: 'Play Next',
                              ),
                              secondaryBackground: _SwipeBackground(
                                alignment: Alignment.centerRight,
                                color: theme.colorScheme.errorContainer,
                                icon: Icons.close_rounded,
                                label: 'Remove',
                              ),
                              confirmDismiss: (direction) async {
                                if (direction == DismissDirection.startToEnd) {
                                  // "Play next": move this track to right after
                                  // the currently playing one instead of
                                  // actually removing it from the list.
                                  playbackService.reorderQueue(offset + i, offset);
                                  return false;
                                }
                                return true;
                              },
                              onDismissed: (_) => playbackService.removeFromQueue(offset + i),
                              child: _QueueTile(
                                song: song,
                                coverArtPath: song.albumId != null
                                    ? ref.watch(albumByIdProvider(song.albumId!)).value?.coverArtPath
                                    : null,
                                dragHandle: ReorderableDragStartListener(
                                  index: i,
                                  child: Icon(
                                    Icons.drag_handle_rounded,
                                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                  ),
                                ),
                                onTap: () => playbackService.skipToQueueItemAt(offset + i),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: AppSpacing.stackLg),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QueueTile extends StatelessWidget {
  const _QueueTile({
    required this.song,
    this.isCurrent = false,
    this.coverArtPath,
    this.dragHandle,
    this.onTap,
  });

  final Song song;
  final bool isCurrent;
  final String? coverArtPath;
  final Widget? dragHandle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderRadiusMd,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.stackSm),
        decoration: BoxDecoration(
          color: isCurrent ? theme.colorScheme.primary.withValues(alpha: 0.08) : null,
          borderRadius: AppRadius.borderRadiusMd,
          border: isCurrent ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)) : null,
        ),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                CoverArt(
                  path: coverArtPath,
                  size: isCurrent ? 56 : 48,
                  borderRadius: AppRadius.borderRadiusSm,
                ),
                if (isCurrent)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: AppRadius.borderRadiusSm,
                    ),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: Icon(Icons.graphic_eq_rounded, color: theme.colorScheme.onPrimary),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: AppSpacing.stackMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(song.displayTitle, style: theme.textTheme.bodyLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(song.displayArtist, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            ?dragHandle,
          ],
        ),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.stackMd),
      decoration: BoxDecoration(color: color, borderRadius: AppRadius.borderRadiusMd),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alignment == Alignment.centerRight) Text(label),
          if (alignment == Alignment.centerRight) const SizedBox(width: AppSpacing.stackSm),
          Icon(icon),
          if (alignment == Alignment.centerLeft) const SizedBox(width: AppSpacing.stackSm),
          if (alignment == Alignment.centerLeft) Text(label),
        ],
      ),
    );
  }
}
