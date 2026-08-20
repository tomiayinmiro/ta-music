import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/providers/library_providers.dart';
import '../../../data/repositories/playlist_repository.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/playlist_cover.dart';
import 'playlist_creation_screen.dart';
import 'playlist_detail_screen.dart';

/// Every user-created playlist — not a dedicated Stitch design (DESIGN_MAP:
/// "not in Stitch folders — ask before building"), built plainly from
/// sonic_sanctuary_2 tokens matching the other unmapped Phase 4 screens.
class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summariesAsync = ref.watch(allPlaylistSummariesProvider);

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Playlists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'New Playlist',
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const PlaylistCreationScreen())),
          ),
        ],
      ),
      body: summariesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Something went wrong: $e')),
        data: (summaries) {
          if (summaries.isEmpty) {
            return EmptyState(
              icon: Icons.playlist_play_rounded,
              title: 'No playlists yet',
              message: 'Build a playlist from any song\'s context menu, or start one here.',
              actionLabel: 'New Playlist',
              onAction: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const PlaylistCreationScreen())),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.containerMargin),
            itemCount: summaries.length,
            itemBuilder: (context, i) => _PlaylistRow(summary: summaries[i]),
          );
        },
      ),
    );
  }
}

class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow({required this.summary});

  final PlaylistSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playlist = summary.playlist;
    return InkWell(
      borderRadius: AppRadius.borderRadiusMd,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PlaylistDetailScreen(playlistId: playlist.id!)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.stackSm),
        child: Row(
          children: [
            PlaylistCover(playlist: playlist, size: 56),
            const SizedBox(width: AppSpacing.stackMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(playlist.name, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '${summary.songCount} songs · ${formatDuration(Duration(milliseconds: summary.totalDurationMs))}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
