import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/spacing.dart';
import '../../../data/providers/library_providers.dart';
import '../../../data/providers/playback_providers.dart';
import '../../../shared/widgets/alphabet_fast_scroller.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/song_context_menu.dart';
import '../../../shared/widgets/song_list_tile.dart';

const double _kRowHeight = 64;

/// Songs added in the last 14 days. Not a dedicated Stitch design (Phase 2's
/// DESIGN_MAP only names Home/Gallery/drawer) — built plainly from
/// sonic_sanctuary_2 tokens so the Home screen's "Recently Added" quick
/// access tile has somewhere real to go.
class RecentlyAddedScreen extends ConsumerStatefulWidget {
  const RecentlyAddedScreen({super.key});

  @override
  ConsumerState<RecentlyAddedScreen> createState() => _RecentlyAddedScreenState();
}

class _RecentlyAddedScreenState extends ConsumerState<RecentlyAddedScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(recentlyAddedSongsProvider);
    return AppScaffold(
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
          final letterIndex = indexByLetter(songs, (s) => s.displayTitle);
          return Stack(
            children: [
              ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.stackSm),
                itemExtent: _kRowHeight,
                itemCount: songs.length,
                itemBuilder: (context, i) {
                  final song = songs[i];
                  final daysAgo = DateTime.now().difference(song.dateAdded).inDays;
                  return SongListTile(
                    song: song,
                    subtitleOverride: daysAgo <= 0 ? 'Added today' : 'Added ${daysAgo}d ago',
                    onTap: () =>
                        ref.read(playbackServiceProvider).playFromSong(song, songs),
                    onLongPress: () =>
                        showSongContextMenu(context, song, queueContext: songs),
                    onMore: () =>
                        showSongContextMenu(context, song, queueContext: songs),
                  );
                },
              ),
              AlphabetFastScroller(
                scrollController: _scrollController,
                availableLetters: letterIndex.letters,
                onLetterSelected: (letter) {
                  final i = letterIndex.firstIndexByLetter[letter];
                  if (i == null) return;
                  _scrollController.animateTo(
                    AppSpacing.stackSm + i * _kRowHeight,
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
