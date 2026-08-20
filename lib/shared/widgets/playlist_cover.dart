import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/radius.dart';
import '../../data/models/playlist.dart';
import '../../data/models/song.dart';
import '../../data/providers/library_providers.dart';
import 'cover_art.dart';

/// A playlist's cover: [Playlist.coverArtPath] if the user has set one,
/// otherwise a 2x2 composite of its first (up to) 4 songs' album art —
/// falling back further to the plain [CoverArt] placeholder tile per empty
/// quadrant (0 songs, or fewer than 4, or a song with no album art).
class PlaylistCover extends ConsumerWidget {
  const PlaylistCover({super.key, required this.playlist, required this.size, this.borderRadius});

  final Playlist playlist;
  final double size;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radius = borderRadius ?? AppRadius.borderRadiusMd;

    if (playlist.coverArtPath != null) {
      return CoverArt(path: playlist.coverArtPath, size: size, borderRadius: radius);
    }

    final songs = ref.watch(playlistSongsProvider(playlist.id!)).value ?? const <Song>[];
    if (songs.length < 2) {
      // Not enough songs for a meaningful composite — a single cover (or
      // the placeholder, if empty) reads better than a mostly-empty grid.
      final only = songs.isEmpty ? null : songs.first;
      final coverPath = only?.albumId != null
          ? ref.watch(albumByIdProvider(only!.albumId!)).value?.coverArtPath
          : null;
      return CoverArt(path: coverPath, size: size, borderRadius: radius);
    }

    final leading = songs.take(4).toList();
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: size,
        height: size,
        child: GridView.count(
          crossAxisCount: 2,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            for (final song in leading) _CoverQuadrant(song: song),
            for (var i = leading.length; i < 4; i++) const CoverArt(path: null, size: double.infinity),
          ],
        ),
      ),
    );
  }
}

class _CoverQuadrant extends ConsumerWidget {
  const _CoverQuadrant({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverPath =
        song.albumId != null ? ref.watch(albumByIdProvider(song.albumId!)).value?.coverArtPath : null;
    return CoverArt(path: coverPath, size: double.infinity, borderRadius: BorderRadius.zero);
  }
}
