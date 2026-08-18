import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/utils/playback_stub.dart';
import '../../../data/providers/library_providers.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/song_list_tile.dart';

/// The bottom nav's 3rd tab. Favorites don't get their full designed
/// screen until Phase 4 (per DESIGN_MAP), but the underlying data — the
/// `favorites` table, sorted by play count, 0-play songs excluded per
/// CLAUDE.md — already works via the bulk-select "Favorite" action, so
/// this shows it plainly rather than being a dead tab.
class FavoritesStubScreen extends ConsumerWidget {
  const FavoritesStubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoriteSongsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: favoritesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Something went wrong: $e')),
        data: (songs) {
          if (songs.isEmpty) {
            return const EmptyState(
              icon: Icons.favorite_outline_rounded,
              title: 'No favorites yet',
              message: 'Favorite a song from The Gallery and, once you\'ve played it '
                  'at least once, it\'ll show up here.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.stackSm),
            itemCount: songs.length,
            itemBuilder: (context, i) {
              final song = songs[i];
              return SongListTile(song: song, onTap: () => playSongStub(context, ref, song));
            },
          );
        },
      ),
    );
  }
}
