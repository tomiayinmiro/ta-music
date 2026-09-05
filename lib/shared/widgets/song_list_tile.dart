import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/duration_format.dart';
import '../../data/models/song.dart';
import '../../data/providers/library_providers.dart';
import 'cover_art.dart';

/// A single song row, used across the library gallery, singles list, queue,
/// favorites, playlist, artist/album detail, and recommendations screens.
///
/// In bulk-select mode ([selectionMode]) the cover art is replaced by a
/// checkbox and [onTap] toggles selection instead of playing.
///
/// [coverArtPath] is an optional override for a caller that already has the
/// art resolved more cheaply (Album detail already holds the one `Album`
/// every row on the page shares, so it passes `album.coverArtPath` directly
/// rather than re-resolving per row). Every other caller leaves it null and
/// this widget resolves it itself from `song.albumId` — cover art
/// investigation (2026-09-04) found most call sites simply never passed
/// anything, silently falling back to the "no art" placeholder for every
/// row; self-resolving here removes that whole class of caller mistake.
class SongListTile extends ConsumerWidget {
  const SongListTile({
    super.key,
    required this.song,
    required this.onTap,
    this.selectionMode = false,
    this.isSelected = false,
    this.onLongPress,
    this.onMore,
    this.coverArtPath,
    this.subtitleOverride,
  });

  final Song song;
  final VoidCallback onTap;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onMore;
  final String? coverArtPath;
  final String? subtitleOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final resolvedCoverArtPath = coverArtPath ??
        (song.albumId != null
            ? ref.watch(albumByIdProvider(song.albumId!)).value?.coverArtPath
            : null);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: AppRadius.borderRadiusMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gutter,
          vertical: AppSpacing.stackSm,
        ),
        child: Row(
          children: [
            if (selectionMode)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.stackSm),
                child: Checkbox(value: isSelected, onChanged: (_) => onTap()),
              )
            else
              CoverArt(path: resolvedCoverArtPath, size: 48, song: song),
            const SizedBox(width: AppSpacing.stackSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    song.displayTitle,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitleOverride ?? song.displayArtist,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.stackSm),
            Text(formatDurationOrUnknown(song.durationMs), style: theme.textTheme.bodySmall),
            if (!selectionMode)
              IconButton(
                icon: const Icon(Icons.more_vert_rounded),
                onPressed: onMore,
                tooltip: 'More',
              ),
          ],
        ),
      ),
    );
  }
}
