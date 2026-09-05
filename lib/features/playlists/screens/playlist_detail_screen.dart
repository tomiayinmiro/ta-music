import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/models/playlist.dart';
import '../../../data/models/song.dart';
import '../../../data/providers/library_providers.dart';
import '../../../data/providers/playback_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../shared/widgets/alphabet_fast_scroller.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/cover_art.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/playlist_cover.dart';
import '../../../shared/widgets/song_context_menu.dart';

const double _kRowHeight = 64;

/// A single playlist — matches the visual language of the other unmapped
/// Phase 4 screens (glass surfaces, sonic_sanctuary_2 tokens), since
/// DESIGN_MAP has no dedicated Stitch folder for it. Header (cover, name,
/// description, Play/Shuffle, edit, delete), then its songs with
/// drag-to-reorder and swipe-to-remove.
class PlaylistDetailScreen extends ConsumerStatefulWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});

  final int playlistId;

  @override
  ConsumerState<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _editMetadata(Playlist playlist) async {
    final nameController = TextEditingController(text: playlist.name);
    final descController = TextEditingController(text: playlist.description ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Playlist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: AppSpacing.stackSm),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
        ],
      ),
    );
    if (result != true || !mounted) return;
    final name = nameController.text.trim();
    if (name.isEmpty) return;
    final repo = await ref.read(playlistRepositoryProvider.future);
    final desc = descController.text.trim();
    await repo.rename(playlist, name: name, description: desc.isEmpty ? null : desc);
  }

  Future<void> _deletePlaylist(Playlist playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Playlist?'),
        content: Text('"${playlist.name}" will be deleted. Your songs stay in your library.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final repo = await ref.read(playlistRepositoryProvider.future);
    await repo.delete(playlist.id!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final playlistAsync = ref.watch(playlistByIdProvider(widget.playlistId));
    final songsAsync = ref.watch(playlistSongsProvider(widget.playlistId));

    return AppScaffold(
      appBar: AppBar(
        actions: playlistAsync.value == null
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit',
                  onPressed: () => _editMetadata(playlistAsync.value!),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Delete',
                  onPressed: () => _deletePlaylist(playlistAsync.value!),
                ),
              ],
      ),
      body: playlistAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Something went wrong: $e')),
        data: (playlist) {
          if (playlist == null) {
            // Deleted (e.g. from another screen) while this one was open.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
            });
            return const SizedBox.shrink();
          }
          return songsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Something went wrong: $e')),
            data: (songs) => _PlaylistBody(
              playlist: playlist,
              songs: songs,
              scrollController: _scrollController,
            ),
          );
        },
      ),
    );
  }
}

class _PlaylistBody extends ConsumerWidget {
  const _PlaylistBody({required this.playlist, required this.songs, required this.scrollController});

  final Playlist playlist;
  final List<Song> songs;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final totalDuration = Duration(milliseconds: songs.fold(0, (sum, s) => sum + (s.durationMs ?? 0)));
    final letterIndex = indexByLetter(songs, (s) => s.displayTitle);

    return Stack(
      children: [
        CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.containerMargin),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: PlaylistCover(playlist: playlist, size: 160, borderRadius: AppRadius.borderRadiusLg),
                    ),
                    const SizedBox(height: AppSpacing.stackMd),
                    Text(playlist.name, style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
                    if (playlist.description != null && playlist.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(playlist.description!, style: theme.textTheme.bodyMedium),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${songs.length} songs · ${formatDuration(totalDuration)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.stackMd),
                    if (songs.isNotEmpty)
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () =>
                                  ref.read(playbackServiceProvider).playFromSong(songs.first, songs),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Play'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.stackSm),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final service = ref.read(playbackServiceProvider);
                                await service.playFromSong(songs.first, songs);
                                await service.setShuffleMode(true);
                              },
                              icon: const Icon(Icons.shuffle_rounded),
                              label: const Text('Shuffle'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            if (songs.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.playlist_add_rounded,
                  title: 'No songs yet',
                  message: 'Add songs to this playlist from any song\'s context menu.',
                ),
              )
            else
              SliverReorderableList(
                itemCount: songs.length,
                itemExtent: _kRowHeight,
                // `onReorderItem` (not the deprecated `onReorder`) already
                // adjusts `newIndex` for the removed item at `oldIndex` —
                // matches what `PlaylistDao.reorderSongs` expects.
                onReorderItem: (oldIndex, newIndex) {
                  ref
                      .read(playlistRepositoryProvider.future)
                      .then((repo) => repo.reorderSongs(playlist.id!, oldIndex, newIndex));
                },
                itemBuilder: (context, i) {
                  final song = songs[i];
                  return Dismissible(
                    key: ValueKey('playlist_song_${playlist.id}_${song.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: theme.colorScheme.errorContainer,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.containerMargin),
                      child: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.onErrorContainer),
                    ),
                    onDismissed: (_) async {
                      final repo = await ref.read(playlistRepositoryProvider.future);
                      await repo.removeSong(playlist.id!, song.id!);
                    },
                    // A dedicated drag handle, not the whole row: wrapping
                    // the row itself in a drag listener would fight the
                    // row's own onLongPress (the context menu) for the same
                    // gesture arena.
                    child: _PlaylistSongRow(
                      song: song,
                      index: i,
                      onTap: () => ref.read(playbackServiceProvider).playFromSong(song, songs),
                      onLongPress: () => showSongContextMenu(context, song, queueContext: songs),
                      onMore: () => showSongContextMenu(context, song, queueContext: songs),
                    ),
                  );
                },
              ),
          ],
        ),
        if (songs.isNotEmpty)
          AlphabetFastScroller(
            scrollController: scrollController,
            availableLetters: letterIndex.letters,
            onLetterSelected: (letter) {
              final i = letterIndex.firstIndexByLetter[letter];
              if (i == null) return;
              // Header block isn't a fixed height (description/duration/
              // buttons vary), so jumps land near — not pixel-exact at —
              // the letter's first row; acceptable for a fast-scroll jump.
              scrollController.animateTo(
                220 + i * _kRowHeight,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
              );
            },
          ),
      ],
    );
  }
}

class _PlaylistSongRow extends ConsumerWidget {
  const _PlaylistSongRow({
    required this.song,
    required this.index,
    required this.onTap,
    required this.onLongPress,
    required this.onMore,
  });

  final Song song;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final coverArtPath =
        song.albumId != null ? ref.watch(albumByIdProvider(song.albumId!)).value?.coverArtPath : null;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: AppRadius.borderRadiusMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter, vertical: AppSpacing.stackSm),
        child: Row(
          children: [
            CoverArt(path: coverArtPath, size: 44, song: song),
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
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: onMore,
            ),
            ReorderableDragStartListener(
              index: index,
              child: Icon(Icons.drag_handle_rounded, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
