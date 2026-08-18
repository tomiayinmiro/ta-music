import 'package:flutter/material.dart';

import '../../core/theme/spacing.dart';
import 'glass_container.dart';

/// Bottom action bar shown while the library gallery is in bulk-select
/// mode, matching `designs/the_gallery_bulk_actions_sorting/`.
///
/// The design's "Delete" action is deliberately relabeled/implemented as
/// "Remove from library" here — it excludes songs from the library
/// (`is_excluded`), it never deletes the underlying file. Outright file
/// deletion is too destructive for a bulk action in v1.
class BulkActionBar extends StatelessWidget {
  const BulkActionBar({
    super.key,
    required this.selectedCount,
    required this.onClose,
    required this.onAddToPlaylist,
    required this.onToggleFavorite,
    required this.onRemoveFromLibrary,
    required this.onShare,
  });

  final int selectedCount;
  final VoidCallback onClose;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onToggleFavorite;
  final VoidCallback onRemoveFromLibrary;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.stackSm),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.stackSm,
          vertical: AppSpacing.stackSm,
        ),
        child: Row(
          children: [
            IconButton(icon: const Icon(Icons.close_rounded), onPressed: onClose),
            Expanded(
              child: Text(
                '$selectedCount selected',
                style: theme.textTheme.labelMedium,
              ),
            ),
            _BulkActionButton(icon: Icons.playlist_add_rounded, label: 'Add', onTap: onAddToPlaylist),
            _BulkActionButton(icon: Icons.favorite_border_rounded, label: 'Favorite', onTap: onToggleFavorite),
            _BulkActionButton(icon: Icons.delete_outline_rounded, label: 'Remove', onTap: onRemoveFromLibrary),
            _BulkActionButton(icon: Icons.ios_share_rounded, label: 'Share', onTap: onShare),
          ],
        ),
      ),
    );
  }
}

class _BulkActionButton extends StatelessWidget {
  const _BulkActionButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: theme.colorScheme.onSurface),
            const SizedBox(height: 2),
            Text(label, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
