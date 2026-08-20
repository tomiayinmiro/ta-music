import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/spacing.dart';
import '../../../data/models/song.dart';
import '../../../data/providers/library_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/cover_art.dart';
import '../../../shared/widgets/empty_state.dart';
import 'playlist_detail_screen.dart';

/// "New Playlist" — matches `designs/playlist_creation_mini_player/`'s name
/// entry treatment and glass-panel language, kept visually consistent with
/// the mini player staying visible throughout via [AppScaffold]. The
/// mockup's curated "Suggested Tracks" bento grid assumes a recommendation
/// engine that doesn't exist yet (that's Phase 6) — replaced with a real
/// searchable list of the library instead (approved 2026-08-20).
class PlaylistCreationScreen extends ConsumerStatefulWidget {
  const PlaylistCreationScreen({super.key, this.seedSongIds = const {}});

  /// Pre-selected songs — e.g. arriving from the add-to-playlist sheet's
  /// "Create New Playlist" entry, which should carry the song(s) the user
  /// was already adding over into the new playlist.
  final Set<int> seedSongIds;

  @override
  ConsumerState<PlaylistCreationScreen> createState() => _PlaylistCreationScreenState();
}

class _PlaylistCreationScreenState extends ConsumerState<PlaylistCreationScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _searchController = TextEditingController();
  late final Set<int> _selectedIds = {...widget.seedSongIds};
  String _query = '';
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Give your playlist a name first.')));
      return;
    }
    setState(() => _saving = true);
    final repo = await ref.read(playlistRepositoryProvider.future);
    final description = _descriptionController.text.trim();
    final id = await repo.create(name: name, description: description.isEmpty ? null : description);
    if (_selectedIds.isNotEmpty) await repo.addSongs(id, _selectedIds.toList());
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => PlaylistDetailScreen(playlistId: id)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final songsAsync = ref.watch(allVisibleSongsProvider);

    return AppScaffold(
      appBar: AppBar(
        title: const Text('New Playlist'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _create,
            child: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Create'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.containerMargin,
              AppSpacing.stackMd,
              AppSpacing.containerMargin,
              AppSpacing.stackSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _nameController,
                  style: theme.textTheme.headlineMedium,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Name your playlist...',
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.stackSm),
                TextField(
                  controller: _descriptionController,
                  style: theme.textTheme.bodyMedium,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Add a description (optional)',
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.containerMargin,
              vertical: AppSpacing.stackSm,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Find songs to add...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainer,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: songsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Something went wrong: $e')),
              data: (songs) {
                final filtered = _query.isEmpty
                    ? songs
                    : songs
                        .where((s) =>
                            s.displayTitle.toLowerCase().contains(_query) ||
                            s.displayArtist.toLowerCase().contains(_query))
                        .toList();
                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No songs found',
                    message: 'Try a different search.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.stackSm),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => _SongPickRow(
                    song: filtered[i],
                    selected: filtered[i].id != null && _selectedIds.contains(filtered[i].id),
                    onToggle: filtered[i].id == null
                        ? null
                        : () => setState(() {
                              final id = filtered[i].id!;
                              _selectedIds.contains(id) ? _selectedIds.remove(id) : _selectedIds.add(id);
                            }),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SongPickRow extends ConsumerWidget {
  const _SongPickRow({required this.song, required this.selected, required this.onToggle});

  final Song song;
  final bool selected;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final coverArtPath =
        song.albumId != null ? ref.watch(albumByIdProvider(song.albumId!)).value?.coverArtPath : null;

    return ListTile(
      onTap: onToggle,
      leading: CoverArt(path: coverArtPath, size: 44),
      title: Text(song.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(song.displayArtist, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Icon(
        selected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
        color: selected ? theme.colorScheme.secondary : theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
