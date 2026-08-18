import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/spacing.dart';
import '../../../data/providers/library_providers.dart';
import '../../../data/providers/playback_providers.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/song_context_menu.dart';
import '../../../shared/widgets/song_list_tile.dart';

/// Songs added in the last 14 days. Not a dedicated Stitch design (Phase 2's
/// DESIGN_MAP only names Home/Gallery/drawer) — built plainly from
/// sonic_sanctuary_2 tokens so the Home screen's "Recently Added" quick
/// access tile has somewhere real to go.
class RecentlyAddedScreen extends ConsumerWidget {
  const RecentlyAddedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(recentlyAddedSongsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Recently Added')),
      body: songsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Something went wrong: $e')),
        data: (songs) {
          if (songs.isEmpty) {
            return const EmptyState(
              icon: Icons.new_releases_outlined,
              title: 'Nothing added recently',
              message: 'Songs added to your library in the last 14 days show up here.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.stackSm),
            itemCount: songs.length,
            itemBuilder: (context, i) {
              final song = songs[i];
              return SongListTile(
                song: song,
                onTap: () => ref.read(playbackServiceProvider).playFromSong(song, songs),
                onLongPress: () => showSongContextMenu(context, song, queueContext: songs),
                onMore: () => showSongContextMenu(context, song, queueContext: songs),
              );
            },
          );
        },
      ),
    );
  }
}
