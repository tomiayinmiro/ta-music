import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/utils/playback_stub.dart';
import '../../../data/models/album.dart';
import '../../../data/models/artist.dart';
import '../../../data/models/song.dart';
import '../../../data/providers/library_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../shared/widgets/bulk_action_bar.dart';
import '../../../shared/widgets/cover_art.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/song_list_tile.dart';
import 'album_detail_screen.dart';
import 'artist_detail_screen.dart';

enum _GalleryTab { albums, artists, singles }

enum _SortOption { name, dateAdded, fileSize }

/// "The Gallery" — matches `designs/the_gallery_library/` (grid tabs) and
/// `designs/the_gallery_singles_list/` + `designs/the_gallery_bulk_actions_sorting/`
/// (the Singles list + bulk-select mode). The design's "Playlists" tab is
/// dropped per the 2026-08-17 scoping decision — playlists don't exist
/// until Phase 4, and an always-empty tab isn't worth shipping now.
class LibraryGalleryScreen extends ConsumerStatefulWidget {
  const LibraryGalleryScreen({super.key});

  @override
  ConsumerState<LibraryGalleryScreen> createState() => _LibraryGalleryScreenState();
}

class _LibraryGalleryScreenState extends ConsumerState<LibraryGalleryScreen> {
  _GalleryTab _tab = _GalleryTab.albums;
  _SortOption _sort = _SortOption.name;
  bool _selectionMode = false;
  final Set<int> _selectedIds = {};

  void _toggleSelection(int songId) {
    setState(() {
      if (_selectedIds.contains(songId)) {
        _selectedIds.remove(songId);
      } else {
        _selectedIds.add(songId);
      }
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('TA MUSIC'),
        actions: [
          if (_tab == _GalleryTab.singles)
            IconButton(
              icon: const Icon(Icons.checklist_rounded),
              tooltip: 'Select',
              onPressed: () => setState(() => _selectionMode = !_selectionMode),
            ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Search is coming in a later phase.')),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.containerMargin,
              vertical: AppSpacing.stackSm,
            ),
            child: Row(
              children: [
                for (final tab in _GalleryTab.values) ...[
                  ChoiceChip(
                    label: Text(switch (tab) {
                      _GalleryTab.albums => 'Albums',
                      _GalleryTab.artists => 'Artists',
                      _GalleryTab.singles => 'Singles',
                    }),
                    selected: _tab == tab,
                    onSelected: (_) => setState(() {
                      _tab = tab;
                      _selectionMode = false;
                      _selectedIds.clear();
                    }),
                  ),
                  const SizedBox(width: AppSpacing.stackSm),
                ],
                const Spacer(),
                if (_tab == _GalleryTab.singles)
                  PopupMenuButton<_SortOption>(
                    initialValue: _sort,
                    onSelected: (value) => setState(() => _sort = value),
                    icon: const Icon(Icons.sort_rounded),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: _SortOption.name, child: Text('Name')),
                      PopupMenuItem(value: _SortOption.dateAdded, child: Text('Date Added')),
                      PopupMenuItem(value: _SortOption.fileSize, child: Text('File Size')),
                    ],
                  ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
          if (_selectionMode && _tab == _GalleryTab.singles)
            BulkActionBar(
              selectedCount: _selectedIds.length,
              onClose: _exitSelection,
              onAddToPlaylist: _selectedIds.isEmpty ? () {} : () => _showAddToPlaylistStub(context),
              onToggleFavorite: _selectedIds.isEmpty ? () {} : _markSelectedFavorite,
              onRemoveFromLibrary: _selectedIds.isEmpty ? () {} : _removeSelectedFromLibrary,
              onShare: _selectedIds.isEmpty ? () {} : () => _showShareStub(context),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return switch (_tab) {
      _GalleryTab.albums => _AlbumsGrid(onOpen: _openAlbum),
      _GalleryTab.artists => _ArtistsGrid(onOpen: _openArtist),
      _GalleryTab.singles => _SinglesList(
          sort: _sort,
          selectionMode: _selectionMode,
          selectedIds: _selectedIds,
          onToggleSelection: _toggleSelection,
          onEnterSelection: (id) => setState(() {
            _selectionMode = true;
            _selectedIds.add(id);
          }),
        ),
    };
  }

  void _openAlbum(Album album) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AlbumDetailScreen(album: album)));
  }

  void _openArtist(Artist artist) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ArtistDetailScreen(artist: artist)));
  }

  Future<void> _markSelectedFavorite() async {
    final repo = await ref.read(favoriteRepositoryProvider.future);
    for (final id in _selectedIds) {
      await repo.setFavorite(id, true);
    }
    if (mounted) _exitSelection();
  }

  Future<void> _removeSelectedFromLibrary() async {
    final repo = await ref.read(songRepositoryProvider.future);
    for (final id in _selectedIds) {
      await repo.setExcluded(id, true);
    }
    if (mounted) _exitSelection();
  }

  void _showAddToPlaylistStub(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => const Padding(
        padding: EdgeInsets.all(AppSpacing.containerMargin),
        child: SizedBox(
          height: 120,
          child: Center(child: Text('No playlists yet — playlists arrive in a later phase.')),
        ),
      ),
    );
  }

  void _showShareStub(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sharing files is coming in a later phase.')),
    );
  }
}

class _AlbumsGrid extends ConsumerWidget {
  const _AlbumsGrid({required this.onOpen});

  final void Function(Album) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(allAlbumsProvider);
    return albumsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Something went wrong: $e')),
      data: (albums) {
        if (albums.isEmpty) {
          return const EmptyState(
            icon: Icons.album_outlined,
            title: 'No albums yet',
            message: 'Scan your library from Settings to see albums here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.read(libraryScanControllerProvider.notifier).startScan(),
          child: GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.containerMargin),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.stackMd,
              crossAxisSpacing: AppSpacing.stackMd,
              childAspectRatio: 0.78,
            ),
            itemCount: albums.length,
            itemBuilder: (context, i) {
              final album = albums[i];
              return GestureDetector(
                onTap: () => onOpen(album),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: CoverArt(
                        path: album.coverArtPath,
                        borderRadius: AppRadius.borderRadiusMd,
                        size: double.infinity,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.stackSm),
                    Text(
                      album.displayName,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (album.artist != null)
                      Text(
                        album.artist!,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ArtistsGrid extends ConsumerWidget {
  const _ArtistsGrid({required this.onOpen});

  final void Function(Artist) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistsAsync = ref.watch(allArtistsProvider);
    return artistsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Something went wrong: $e')),
      data: (artists) {
        if (artists.isEmpty) {
          return const EmptyState(
            icon: Icons.person_outline_rounded,
            title: 'No artists yet',
            message: 'Scan your library from Settings to see artists here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.read(libraryScanControllerProvider.notifier).startScan(),
          child: GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.containerMargin),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.stackMd,
              crossAxisSpacing: AppSpacing.stackMd,
              childAspectRatio: 0.78,
            ),
            itemCount: artists.length,
            itemBuilder: (context, i) {
              final artist = artists[i];
              return GestureDetector(
                onTap: () => onOpen(artist),
                child: Column(
                  children: [
                    Expanded(child: CoverArt(path: null, size: double.infinity, isCircle: true)),
                    const SizedBox(height: AppSpacing.stackSm),
                    Text(
                      artist.displayName,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _SinglesList extends ConsumerWidget {
  const _SinglesList({
    required this.sort,
    required this.selectionMode,
    required this.selectedIds,
    required this.onToggleSelection,
    required this.onEnterSelection,
  });

  final _SortOption sort;
  final bool selectionMode;
  final Set<int> selectedIds;
  final void Function(int) onToggleSelection;
  final void Function(int) onEnterSelection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(singlesProvider);
    return songsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Something went wrong: $e')),
      data: (songs) {
        if (songs.isEmpty) {
          return const EmptyState(
            icon: Icons.audiotrack_rounded,
            title: 'No singles yet',
            message: 'Scan your library from Settings to see standalone tracks here.',
          );
        }
        final sorted = _sortSongs(songs, sort);
        return RefreshIndicator(
          onRefresh: () => ref.read(libraryScanControllerProvider.notifier).startScan(),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.stackSm),
            itemCount: sorted.length,
            itemBuilder: (context, i) {
              final song = sorted[i];
              return SongListTile(
                song: song,
                selectionMode: selectionMode,
                isSelected: song.id != null && selectedIds.contains(song.id),
                onLongPress: song.id == null ? null : () => onEnterSelection(song.id!),
                onTap: () {
                  if (selectionMode) {
                    if (song.id != null) onToggleSelection(song.id!);
                  } else {
                    playSongStub(context, ref, song);
                  }
                },
              );
            },
          ),
        );
      },
    );
  }

  List<Song> _sortSongs(List<Song> songs, _SortOption sort) {
    final copy = [...songs];
    switch (sort) {
      case _SortOption.name:
        copy.sort((a, b) => a.displayTitle.toLowerCase().compareTo(b.displayTitle.toLowerCase()));
      case _SortOption.dateAdded:
        copy.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      case _SortOption.fileSize:
        copy.sort((a, b) => (b.fileSize ?? 0).compareTo(a.fileSize ?? 0));
    }
    return copy;
  }
}
