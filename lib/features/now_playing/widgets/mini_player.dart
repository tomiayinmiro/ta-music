import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../data/providers/library_providers.dart';
import '../../../data/providers/playback_providers.dart';
import '../../../data/services/audio_service.dart';
import '../../../shared/widgets/cover_art.dart';
import '../screens/now_playing_screen.dart';

/// Persistent bar shown above the bottom nav on every screen (per CLAUDE.md
/// Phase 3, deliverable 6). Hides entirely when nothing is queued. Tapping
/// it opens the full-screen Now Playing experience.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(playbackSnapshotProvider);
    final snapshot = snapshotAsync.value;
    final song = snapshot?.currentSong;

    if (song == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final playbackService = ref.read(playbackServiceProvider);
    final isPlaying = snapshot!.status == PlaybackStatus.playing;
    final progress = (snapshot.duration != null && snapshot.duration!.inMilliseconds > 0)
        ? snapshot.position.inMilliseconds / snapshot.duration!.inMilliseconds
        : 0.0;
    final coverArtPath =
        song.albumId != null ? ref.watch(albumByIdProvider(song.albumId!)).value?.coverArtPath : null;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(NowPlayingScreen.route()),
      child: Container(
        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainer),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 2,
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(theme.colorScheme.secondary),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.stackSm,
                vertical: AppSpacing.stackSm,
              ),
              child: Row(
                children: [
                  Hero(
                    tag: 'now_playing_cover',
                    child: CoverArt(
                      path: coverArtPath,
                      size: 44,
                      borderRadius: AppRadius.borderRadiusSm,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.stackSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          song.displayTitle,
                          style: theme.textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          song.displayArtist,
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 28),
                    onPressed: () => isPlaying ? playbackService.pause() : playbackService.resume(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded, size: 28),
                    onPressed: snapshot.hasNext ? playbackService.next : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
