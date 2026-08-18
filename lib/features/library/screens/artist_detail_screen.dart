import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/utils/playback_stub.dart';
import '../../../data/models/artist.dart';
import '../../../data/providers/library_providers.dart';
import '../../../shared/widgets/cover_art.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/song_list_tile.dart';

/// No dedicated Stitch design for artist detail exists in Phase 2's
/// DESIGN_MAP — built plainly so tapping an artist in the gallery grid has
/// somewhere to go instead of a dead end.
class ArtistDetailScreen extends ConsumerWidget {
  const ArtistDetailScreen({super.key, required this.artist});

  final Artist artist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(songsByArtistProvider(artist.id!));

    return Scaffold(
      appBar: AppBar(title: Text(artist.displayName)),
      body: songsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Something went wrong: $e')),
        data: (songs) {
          if (songs.isEmpty) {
            return const EmptyState(
              icon: Icons.person_outline_rounded,
              title: 'No songs found',
              message: 'This artist has no visible songs.',
            );
          }
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.containerMargin),
                child: Row(
                  children: [
                    const CoverArt(path: null, size: 80, isCircle: true),
                    const SizedBox(width: AppSpacing.stackMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(artist.displayName, style: Theme.of(context).textTheme.titleLarge),
                          Text('${songs.length} songs'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              for (final song in songs)
                SongListTile(song: song, onTap: () => playSongStub(context, ref, song)),
            ],
          );
        },
      ),
    );
  }
}
