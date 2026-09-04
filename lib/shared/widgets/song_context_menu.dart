import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../data/models/song.dart';
import '../../data/providers/library_providers.dart';
import '../../data/providers/playback_providers.dart';
import '../../data/providers/recommendation_providers.dart';
import '../../data/providers/repository_providers.dart';
import '../../features/favorites/screens/favorites_screen.dart';
import '../../features/library/screens/album_detail_screen.dart';
import '../../features/library/screens/artist_detail_screen.dart';
import '../../features/recommendations/screens/more_like_this_screen.dart';
import 'add_to_playlist_sheet.dart';
import 'cover_art.dart';
import 'glass_container.dart';
import 'song_info_dialog.dart';

/// Reusable long-press / overflow menu shown everywhere a song appears —
/// matches `designs/song_context_menu/`'s glass-sheet treatment, with two
/// substitutions approved 2026-08-18: "Share Aura" (the gamification
/// system CLAUDE.md excludes outright) and "Download Lossless" (files are
/// already local — nothing to download) are replaced with the actual 8
/// actions CLAUDE.md's Phase 3 brief lists.
///
/// [queueContext], if given, is the list "Play" queues alongside [song] —
/// everything from [song]'s position onward, matching the "play from here"
/// convention every song list in the app already uses. Falls back to just
/// [song] alone when omitted.
Future<void> showSongContextMenu(BuildContext context, Song song, {List<Song>? queueContext}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _SongContextMenu(outerContext: context, song: song, queueContext: queueContext),
  );
}

class _SongContextMenu extends ConsumerStatefulWidget {
  const _SongContextMenu({required this.outerContext, required this.song, required this.queueContext});

  /// The page context the menu was opened from — stays mounted independent
  /// of the sheet's own lifecycle, so post-close navigation/snackbars use
  /// this instead of the sheet's own (about-to-be-disposed) context.
  final BuildContext outerContext;
  final Song song;
  final List<Song>? queueContext;

  @override
  ConsumerState<_SongContextMenu> createState() => _SongContextMenuState();
}

class _SongContextMenuState extends ConsumerState<_SongContextMenu> {
  bool? _isFavorite;

  @override
  void initState() {
    super.initState();
    _loadFavoriteState();
  }

  Future<void> _loadFavoriteState() async {
    if (widget.song.id == null) return;
    final repo = await ref.read(favoriteRepositoryProvider.future);
    final value = await repo.isFavorite(widget.song.id!);
    if (mounted) setState(() => _isFavorite = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final song = widget.song;
    final outer = widget.outerContext;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.stackSm),
        child: GlassContainer(
          borderRadius: const BorderRadius.vertical(top: AppRadius.radiusXl),
          padding: const EdgeInsets.only(bottom: AppSpacing.stackSm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: AppRadius.borderRadiusFull,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.containerMargin),
                child: Row(
                  children: [
                    CoverArt(
                      path: song.albumId != null
                          ? ref.watch(albumByIdProvider(song.albumId!)).value?.coverArtPath
                          : null,
                      size: 56,
                    ),
                    const SizedBox(width: AppSpacing.stackMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            song.displayTitle,
                            style: theme.textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            song.displayArtist,
                            style: theme.textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
              const SizedBox(height: AppSpacing.stackSm),
              _ActionTile(
                icon: Icons.play_arrow_rounded,
                label: 'Play',
                onTap: () {
                  final service = ref.read(playbackServiceProvider);
                  Navigator.of(context).pop();
                  service.playFromSong(song, widget.queueContext ?? [song]);
                },
              ),
              _ActionTile(
                icon: Icons.queue_music_rounded,
                label: 'Play Next',
                onTap: () {
                  final service = ref.read(playbackServiceProvider);
                  Navigator.of(context).pop();
                  service.playNext(song);
                },
              ),
              _ActionTile(
                icon: Icons.add_to_queue_rounded,
                label: 'Add to Queue',
                onTap: () {
                  final service = ref.read(playbackServiceProvider);
                  Navigator.of(context).pop();
                  service.addToQueue(song);
                },
              ),
              _ActionTile(
                icon: Icons.playlist_add_rounded,
                label: 'Add to Playlist',
                onTap: song.id == null
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        showAddToPlaylistSheet(outer, songIds: [song.id!]);
                      },
              ),
              if (song.artistId != null)
                _ActionTile(
                  icon: Icons.person_outline_rounded,
                  label: 'Go to Artist',
                  onTap: () async {
                    final sheetNavigator = Navigator.of(context);
                    final repo = await ref.read(artistRepositoryProvider.future);
                    sheetNavigator.pop();
                    final artist = await repo.getById(song.artistId!);
                    if (artist != null && outer.mounted) {
                      Navigator.of(outer)
                          .push(MaterialPageRoute(builder: (_) => ArtistDetailScreen(artist: artist)));
                    }
                  },
                ),
              if (song.albumId != null)
                _ActionTile(
                  icon: Icons.album_outlined,
                  label: 'Go to Album',
                  onTap: () async {
                    final sheetNavigator = Navigator.of(context);
                    final repo = await ref.read(albumRepositoryProvider.future);
                    sheetNavigator.pop();
                    final album = await repo.getById(song.albumId!);
                    if (album != null && outer.mounted) {
                      Navigator.of(outer)
                          .push(MaterialPageRoute(builder: (_) => AlbumDetailScreen(album: album)));
                    }
                  },
                ),
              _ActionTile(
                icon: (_isFavorite ?? false) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                label: (_isFavorite ?? false) ? 'Remove from Favorites' : 'Add to Favorites',
                onTap: song.id == null
                    ? null
                    : () async {
                        final sheetNavigator = Navigator.of(context);
                        final repo = await ref.read(favoriteRepositoryProvider.future);
                        final next = !(_isFavorite ?? false);
                        sheetNavigator.pop();
                        await repo.setFavorite(song.id!, next);
                      },
              ),
              _ActionTile(
                icon: Icons.favorite_outline_rounded,
                label: 'Go to Favorites',
                // Navigation shortcut only — distinct from the toggle above.
                // Favorites is a pushed route, not a bottom-nav tab, since
                // Phase 4.5 gave that tab to Aura — push it directly instead
                // of switching shell tabs.
                onTap: () {
                  Navigator.of(context).pop();
                  if (outer.mounted) {
                    Navigator.of(
                      outer,
                    ).push(MaterialPageRoute(builder: (_) => const FavoritesScreen()));
                  }
                },
              ),
              if (ref.watch(recommendationsEnabledProvider).value ?? true)
                _ActionTile(
                  icon: Icons.auto_awesome_outlined,
                  label: 'More like this',
                  onTap: () {
                    Navigator.of(context).pop();
                    if (outer.mounted) {
                      Navigator.of(outer).push(
                        MaterialPageRoute(builder: (_) => MoreLikeThisScreen(seed: song)),
                      );
                    }
                  },
                ),
              _ActionTile(
                icon: Icons.info_outline_rounded,
                label: 'Song Info',
                onTap: () {
                  Navigator.of(context).pop();
                  SongInfoDialog.show(outer, song);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderRadiusMd,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.stackMd, vertical: AppSpacing.stackSm),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.stackMd),
            Text(label, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
