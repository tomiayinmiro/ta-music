import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../data/models/playlist.dart';
import '../../data/providers/library_providers.dart';
import '../../data/providers/repository_providers.dart';
import '../../features/playlists/screens/playlist_creation_screen.dart';
import 'glass_container.dart';
import 'playlist_cover.dart';

/// Matches `designs/add_to_playlist/`: a glass sheet with "Create New
/// Playlist" pinned above a checkable list of every existing playlist.
///
/// [songIds] with exactly one entry (the common case — a single song's
/// context menu) pre-checks whichever playlists already contain it, and
/// "Done" applies the full add/remove diff. With more than one entry (bulk
/// selection) there's no single well-defined "already in" state to diff
/// against, so it starts with nothing checked and only adds on "Done" —
/// removal isn't offered in bulk mode.
Future<void> showAddToPlaylistSheet(BuildContext context, {required List<int> songIds}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => AddToPlaylistSheet(songIds: songIds),
  );
}

class AddToPlaylistSheet extends ConsumerStatefulWidget {
  const AddToPlaylistSheet({super.key, required this.songIds});

  final List<int> songIds;

  @override
  ConsumerState<AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends ConsumerState<AddToPlaylistSheet> {
  Set<int>? _initiallySelected;
  late Set<int> _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.songIds.length == 1) {
      ref.read(playlistRepositoryProvider.future).then((repo) async {
        final existing = await repo.getPlaylistIdsContaining(widget.songIds.single);
        if (mounted) {
          setState(() {
            _initiallySelected = existing;
            _selected = {...existing};
          });
        }
      });
    } else {
      _initiallySelected = {};
      _selected = {};
    }
  }

  void _toggle(int playlistId) {
    setState(() {
      _selected.contains(playlistId) ? _selected.remove(playlistId) : _selected.add(playlistId);
    });
  }

  Future<void> _createNew() async {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlaylistCreationScreen(seedSongIds: widget.songIds.toSet()),
    ));
  }

  Future<void> _done() async {
    setState(() => _saving = true);
    final repo = await ref.read(playlistRepositoryProvider.future);
    if (widget.songIds.length == 1) {
      final initial = _initiallySelected ?? {};
      await repo.applyMembership(
        widget.songIds.single,
        addTo: _selected.difference(initial),
        removeFrom: initial.difference(_selected),
      );
    } else if (_selected.isNotEmpty) {
      for (final playlistId in _selected) {
        await repo.addSongs(playlistId, widget.songIds);
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playlistsAsync = ref.watch(allPlaylistsProvider);
    final ready = _initiallySelected != null;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.stackSm),
        child: GlassContainer(
          borderRadius: const BorderRadius.vertical(top: AppRadius.radiusXl),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.75,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.containerMargin,
                    vertical: AppSpacing.stackMd,
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text('Add to Playlist', style: theme.textTheme.headlineMedium)),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: _createNew,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.containerMargin,
                      vertical: AppSpacing.stackSm,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline_rounded, color: theme.colorScheme.secondary),
                        const SizedBox(width: AppSpacing.stackSm),
                        Text('Create New Playlist', style: theme.textTheme.titleSmall),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: !ready
                      ? const Center(child: CircularProgressIndicator())
                      : playlistsAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, _) => Center(child: Text('Something went wrong: $e')),
                          data: (playlists) {
                            if (playlists.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.all(AppSpacing.containerMargin),
                                child: Text(
                                  'No playlists yet — create one above.',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              );
                            }
                            return ListView.builder(
                              padding: const EdgeInsets.all(AppSpacing.containerMargin),
                              itemCount: playlists.length,
                              itemBuilder: (context, i) => _PlaylistCheckRow(
                                playlist: playlists[i],
                                selected: _selected.contains(playlists[i].id),
                                onTap: () => _toggle(playlists[i].id!),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.containerMargin,
                    AppSpacing.stackSm,
                    AppSpacing.containerMargin,
                    AppSpacing.stackSm + MediaQuery.of(context).padding.bottom,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: (!ready || _saving) ? null : _done,
                      child: _saving
                          ? const SizedBox(
                              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Done'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistCheckRow extends StatelessWidget {
  const _PlaylistCheckRow({required this.playlist, required this.selected, required this.onTap});

  final Playlist playlist;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderRadiusMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            PlaylistCover(playlist: playlist, size: 48),
            const SizedBox(width: AppSpacing.stackMd),
            Expanded(
              child: Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: selected ? theme.colorScheme.secondary : theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}
