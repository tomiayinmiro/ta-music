import 'package:flutter/material.dart';

import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/duration_format.dart';
import '../../data/models/song.dart';
import 'cover_art.dart';

/// A single song row, used across the library gallery, singles list, and
/// (later) queue/favorites/playlist screens.
///
/// In bulk-select mode ([selectionMode]) the cover art is replaced by a
/// checkbox and [onTap] toggles selection instead of playing.
class SongListTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              CoverArt(path: coverArtPath, size: 48),
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
            Text(formatDuration(song.duration), style: theme.textTheme.bodySmall),
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
