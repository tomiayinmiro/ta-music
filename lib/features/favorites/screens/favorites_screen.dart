import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/models/song.dart';
import '../../../data/providers/library_providers.dart';
import '../../../data/providers/playback_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../shared/widgets/alphabet_fast_scroller.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/cover_art.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/song_context_menu.dart';

const double _kRowHeight = 68;
const double _kHeaderEstimate = 210;

/// A pushed route (nav drawer + the song context menu's "Go to Favorites").
/// Was the bottom nav's 3rd tab through Phase 4; Phase 4.5 (approved
/// 2026-08-21) replaced that tab with Aura, so this moved off the shell's
/// `IndexedStack` onto the root `Navigator` — hence `AppScaffold` (keeps the
/// mini player visible) instead of the bare `Scaffold` it used to need as a
/// tab body. Sorted by play count (most-played first) — songs with 0 plays
/// are excluded even when manually favorited, per CLAUDE.md ("songs with 0
/// plays are excluded") — confirmed 2026-08-20: the 0-play exclusion wins
/// over a manual add. No dedicated Stitch design (DESIGN_MAP: "not in
/// Stitch folders — ask before building"), built from sonic_sanctuary_2
/// tokens matching the other unmapped Phase 4 screens.
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favoritesAsync = ref.watch(favoriteSongsProvider);

    return AppScaffold(
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
          final letterIndex = indexByLetter(songs, (s) => s.displayTitle);
          final totalDuration = Duration(milliseconds: songs.fold(0, (sum, s) => sum + (s.durationMs ?? 0)));

          return Stack(
            children: [
              CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(child: _Header(count: songs.length, totalDuration: totalDuration)),
                  SliverFixedExtentList(
                    itemExtent: _kRowHeight,
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _FavoriteRow(song: songs[i], queueContext: songs),
                      childCount: songs.length,
                    ),
                  ),
                ],
              ),
              AlphabetFastScroller(
                scrollController: _scrollController,
                availableLetters: letterIndex.letters,
                onLetterSelected: (letter) {
                  final i = letterIndex.firstIndexByLetter[letter];
                  if (i == null) return;
                  _scrollController.animateTo(
                    _kHeaderEstimate + i * _kRowHeight,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.count, required this.totalDuration});

  final int count;
  final Duration totalDuration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.containerMargin,
        AppSpacing.stackSm,
        AppSpacing.containerMargin,
        AppSpacing.stackMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$count songs · ${formatDuration(totalDuration)}', style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.stackMd),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    final songs = await ref.read(favoriteSongsProvider.future);
                    if (songs.isNotEmpty) {
                      ref.read(playbackServiceProvider).playFromSong(songs.first, songs);
                    }
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Play All'),
                ),
              ),
              const SizedBox(width: AppSpacing.stackSm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final songs = await ref.read(favoriteSongsProvider.future);
                    if (songs.isEmpty) return;
                    final service = ref.read(playbackServiceProvider);
                    await service.playFromSong(songs.first, songs);
                    await service.setShuffleMode(true);
                  },
                  icon: const Icon(Icons.shuffle_rounded),
                  label: const Text('Shuffle All'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FavoriteRow extends ConsumerWidget {
  const _FavoriteRow({required this.song, required this.queueContext});

  final Song song;
  final List<Song> queueContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final coverArtPath =
        song.albumId != null ? ref.watch(albumByIdProvider(song.albumId!)).value?.coverArtPath : null;

    return InkWell(
      onTap: () => ref.read(playbackServiceProvider).playFromSong(song, queueContext),
      onLongPress: () => showSongContextMenu(context, song, queueContext: queueContext),
      borderRadius: AppRadius.borderRadiusMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter, vertical: AppSpacing.stackSm),
        child: Row(
          children: [
            CoverArt(path: coverArtPath, size: 48, song: song),
            const SizedBox(width: AppSpacing.stackSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(song.displayTitle, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(song.displayArtist, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.stackSm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: AppRadius.borderRadiusFull,
              ),
              child: Text(
                '${song.playCount} ${song.playCount == 1 ? "play" : "plays"}',
                style: theme.textTheme.labelSmall,
              ),
            ),
            const SizedBox(width: AppSpacing.stackSm),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.favorite_rounded, size: 20, color: theme.colorScheme.secondary),
              onPressed: song.id == null
                  ? null
                  : () async {
                      final repo = await ref.read(favoriteRepositoryProvider.future);
                      await repo.setFavorite(song.id!, false);
                    },
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: () => showSongContextMenu(context, song, queueContext: queueContext),
            ),
          ],
        ),
      ),
    );
  }
}
