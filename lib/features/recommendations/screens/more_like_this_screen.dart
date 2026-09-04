import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/spacing.dart';
import '../../../data/models/song.dart';
import '../../../data/providers/playback_providers.dart';
import '../../../data/providers/recommendation_providers.dart';
import '../../../shared/widgets/alphabet_fast_scroller.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/song_context_menu.dart';
import '../../../shared/widgets/song_list_tile.dart';

const double _kRowHeight = 64;

/// Song context menu's "More like this" — 15-25 songs ranked by local-taste
/// similarity to [seed], via the same recommendation engine as Home's
/// "Similar to X" section. See Phase 6 batch 1.
class MoreLikeThisScreen extends ConsumerStatefulWidget {
  const MoreLikeThisScreen({super.key, required this.seed});

  final Song seed;

  @override
  ConsumerState<MoreLikeThisScreen> createState() => _MoreLikeThisScreenState();
}

class _MoreLikeThisScreenState extends ConsumerState<MoreLikeThisScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(moreLikeThisProvider(widget.seed));
    return AppScaffold(
      appBar: AppBar(title: Text('Similar to ${widget.seed.displayTitle}')),
      body: songsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Something went wrong: $e')),
        data: (songs) {
          if (songs.isEmpty) {
            return const EmptyState(
              icon: Icons.auto_awesome_outlined,
              title: 'Nothing similar yet',
              message: 'Keep listening and TA MUSIC will find songs that fit this one.',
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
                  return SongListTile(
                    song: song,
                    onTap: () => ref.read(playbackServiceProvider).playFromSong(song, songs),
                    onLongPress: () => showSongContextMenu(context, song, queueContext: songs),
                    onMore: () => showSongContextMenu(context, song, queueContext: songs),
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
