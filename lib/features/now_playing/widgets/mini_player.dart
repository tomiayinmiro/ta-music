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
///
/// Bug 10 (device testing pass): this widget is mounted on every screen for
/// the app's whole life, so it matters more than most that it doesn't
/// rebuild needlessly. It used to watch the full [playbackSnapshotProvider]
/// — which re-emits on every position tick (~5x/second while playing) — for
/// its entire subtree, meaning the cover art, title/artist, and all three
/// transport buttons re-rendered continuously regardless of whether
/// anything they show had actually changed. Split so only the thin
/// progress bar (genuinely position-driven) rebuilds that often; song
/// identity, playing state, and hasNext/hasPrevious are watched narrowly
/// via `.select()`, which only notifies when the *selected* value changes,
/// not on every raw stream emission.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(currentSongProvider).value;
    if (song == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final playbackService = ref.read(playbackServiceProvider);
    final status =
        ref.watch(playbackStatusProvider).value ?? PlaybackStatus.stopped;
    final isPlaying = status == PlaybackStatus.playing;
    final hasNext = ref.watch(
      playbackSnapshotProvider.select((a) => a.value?.hasNext ?? false),
    );
    final coverArtPath = song.albumId != null
        ? ref.watch(albumByIdProvider(song.albumId!)).value?.coverArtPath
        : null;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(NowPlayingScreen.route()),
      child: Container(
        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainer),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _MiniPlayerProgressBar(),
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
                  // Bug 6 (device testing pass): previous was missing here —
                  // tightened via VisualDensity.compact on all three
                  // transport buttons (rather than dropping one) so they
                  // still fit alongside the cover art and title/artist.
                  //
                  // Not gated on hasPrevious (Phase 3 completion pass,
                  // Android): skipToPrevious() already restarts the
                  // current track when >3s in, which needs no *actual*
                  // previous track to exist — gating the button on
                  // hasPrevious disabled it entirely (not even a restart)
                  // the moment a fresh shuffle tap put the tapped song at
                  // shuffle position 0, correctly with no track before it.
                  // A song is loaded here at all (see the early return
                  // above), so the button is always meaningful.
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.skip_previous_rounded, size: 26),
                    onPressed: playbackService.previous,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 28,
                    ),
                    onPressed: () => isPlaying
                        ? playbackService.pause()
                        : playbackService.resume(),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.skip_next_rounded, size: 26),
                    onPressed: hasNext ? playbackService.next : null,
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

/// Isolated so only this ~2px bar rebuilds on every position tick, instead
/// of the whole mini player.
class _MiniPlayerProgressBar extends ConsumerWidget {
  const _MiniPlayerProgressBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final position = ref.watch(playbackPositionProvider).value ?? Duration.zero;
    final duration = ref.watch(
      playbackSnapshotProvider.select((a) => a.value?.duration),
    );
    final progress = (duration != null && duration.inMilliseconds > 0)
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return SizedBox(
      height: 2,
      child: LinearProgressIndicator(
        value: progress.clamp(0.0, 1.0),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation(theme.colorScheme.secondary),
      ),
    );
  }
}
