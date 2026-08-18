import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/spacing.dart';
import '../../../data/models/album.dart';
import '../../../data/providers/library_providers.dart';
import '../../../data/providers/playback_providers.dart';
import '../../../shared/widgets/cover_art.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/song_context_menu.dart';
import '../../../shared/widgets/song_list_tile.dart';

/// No dedicated Stitch design for album detail exists in Phase 2's
/// DESIGN_MAP — built plainly so tapping an album in the gallery grid has
/// somewhere to go instead of a dead end.
class AlbumDetailScreen extends ConsumerWidget {
  const AlbumDetailScreen({super.key, required this.album});

  final Album album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(songsByAlbumProvider(album.id!));

    return Scaffold(
      appBar: AppBar(title: Text(album.displayName)),
      body: songsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Something went wrong: $e')),
        data: (songs) {
          if (songs.isEmpty) {
            return const EmptyState(
              icon: Icons.album_outlined,
              title: 'No songs found',
              message: 'This album has no visible songs.',
            );
          }
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.containerMargin),
                child: Row(
                  children: [
                    CoverArt(path: album.coverArtPath, size: 96),
                    const SizedBox(width: AppSpacing.stackMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(album.displayName, style: Theme.of(context).textTheme.titleLarge),
                          if (album.artist != null) Text(album.artist!),
                          Text('${songs.length} songs'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              for (final song in songs)
                SongListTile(
                  song: song,
                  coverArtPath: album.coverArtPath,
                  subtitleOverride: song.displayArtist,
                  onTap: () => ref.read(playbackServiceProvider).playFromSong(song, songs),
                  onLongPress: () => showSongContextMenu(context, song, queueContext: songs),
                  onMore: () => showSongContextMenu(context, song, queueContext: songs),
                ),
            ],
          );
        },
      ),
    );
  }
}
