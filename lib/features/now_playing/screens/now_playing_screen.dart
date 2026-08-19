import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/motion.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/providers/library_providers.dart';
import '../../../data/providers/playback_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/services/audio_service.dart';
import '../../../shared/widgets/cover_art.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/song_context_menu.dart';
import 'queue_screen.dart';

/// Full-screen "Now Playing" — matches `designs/now_playing/`: large cover,
/// title/artist/favorite, scrubable progress, shuffle/prev/play/next/repeat,
/// a queue button, a more-menu, and a lyrics placeholder (real lyrics land
/// in Phase 5).
class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  /// Slide-up-from-bottom route, dismissed via the header's down-chevron or
  /// a swipe-down gesture on the screen itself — matching the mockup's
  /// "contextual return" header pattern.
  static Route<void> route() {
    return PageRouteBuilder<void>(
      transitionDuration: AppMotion.emphasized,
      reverseTransitionDuration: AppMotion.emphasized,
      pageBuilder: (context, animation, secondaryAnimation) =>
          const NowPlayingScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .chain(CurveTween(curve: AppMotion.emphasizedEasing))
              .animate(animation),
          child: child,
        );
      },
    );
  }

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  double _dragOffset = 0;
  double? _scrubValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snapshotAsync = ref.watch(playbackSnapshotProvider);
    final snapshot = snapshotAsync.value;
    final song = snapshot?.currentSong;
    final playbackService = ref.read(playbackServiceProvider);

    if (song == null) {
      // Playback stopped/cleared while this screen was open (e.g. queue
      // ran out) — nothing left to show, so back out.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop())
          Navigator.of(context).pop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final duration = snapshot!.duration ?? song.duration;
    final position = snapshot.position > duration
        ? duration
        : snapshot.position;
    final isPlaying = snapshot.status == PlaybackStatus.playing;
    final isFavoriteAsync = song.id != null
        ? ref.watch(isFavoriteProvider(song.id!))
        : null;
    final isFavorite = isFavoriteAsync?.value ?? false;
    final coverArtPath = song.albumId != null
        ? ref.watch(albumByIdProvider(song.albumId!)).value?.coverArtPath
        : null;

    // Bug 9 (device testing pass): the swipe-to-dismiss drag detector used
    // to wrap the entire screen, including the scrollable content below —
    // competing in the same gesture arena as the queue/lyrics buttons
    // living in that content meant taps there were occasionally swallowed
    // as an accidental micro-drag instead of registering as a tap.
    // Scoped to just the header now; the down-chevron there (and the
    // header itself) is still a full-width, reliable way to dismiss, and
    // the drag *translation* still animates the whole screen.
    return AnimatedContainer(
      duration: _dragOffset == 0 ? AppMotion.standard : Duration.zero,
      transform: Matrix4.translationValues(0, _dragOffset, 0),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              GestureDetector(
                onVerticalDragUpdate: (details) {
                  setState(
                    () => _dragOffset = (_dragOffset + details.primaryDelta!)
                        .clamp(0, 400),
                  );
                },
                onVerticalDragEnd: (details) {
                  if (_dragOffset > 120 || details.primaryVelocity! > 800) {
                    Navigator.of(context).pop();
                  } else {
                    setState(() => _dragOffset = 0);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.containerMargin,
                    vertical: AppSpacing.stackSm,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 28,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          'Now Playing',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_horiz_rounded),
                        onPressed: () => showSongContextMenu(
                          context,
                          song,
                          queueContext: snapshot.queue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Bug (Windows Phase 3 completion pass): sizing this square
                    // off AspectRatio(aspectRatio: 1) against the available
                    // *width* looks right on a narrow phone portrait, but on a
                    // wide desktop window the width can dwarf the height,
                    // ballooning the cover art and pushing the transport
                    // controls off-screen. Bounded by the smaller of available
                    // width and a fraction of available height instead, which
                    // is a no-op on phones (width is already the limiting
                    // dimension there) and caps it on wide/landscape windows.
                    final coverSize = math.min(
                      constraints.maxWidth - AppSpacing.containerMargin * 2,
                      constraints.maxHeight * 0.45,
                    );
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.containerMargin,
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: AppSpacing.stackMd),
                          Hero(
                            tag: 'now_playing_cover',
                            child: CoverArt(
                              path: coverArtPath,
                              size: coverSize,
                              borderRadius: AppRadius.borderRadiusXl,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.stackLg),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      song.displayTitle,
                                      style: theme.textTheme.headlineSmall,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      song.displayArtist,
                                      style: theme.textTheme.bodyLarge,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (song.id != null)
                                IconButton(
                                  icon: Icon(
                                    isFavorite
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    size: 30,
                                    color: isFavorite
                                        ? theme.colorScheme.secondary
                                        : null,
                                  ),
                                  onPressed: () async {
                                    final repo = await ref.read(
                                      favoriteRepositoryProvider.future,
                                    );
                                    await repo.setFavorite(
                                      song.id!,
                                      !isFavorite,
                                    );
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.stackMd),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 14,
                              ),
                            ),
                            child: Slider(
                              value:
                                  (_scrubValue ??
                                          position.inMilliseconds.toDouble())
                                      .clamp(
                                        0,
                                        duration.inMilliseconds
                                            .toDouble()
                                            .clamp(1, double.infinity),
                                      ),
                              max: duration.inMilliseconds.toDouble().clamp(
                                1,
                                double.infinity,
                              ),
                              onChanged: (value) =>
                                  setState(() => _scrubValue = value),
                              onChangeEnd: (value) {
                                playbackService.seek(
                                  Duration(milliseconds: value.round()),
                                );
                                setState(() => _scrubValue = null);
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.stackSm,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  formatDuration(
                                    Duration(
                                      milliseconds:
                                          (_scrubValue ??
                                                  position.inMilliseconds
                                                      .toDouble())
                                              .round(),
                                    ),
                                  ),
                                  style: theme.textTheme.labelSmall,
                                ),
                                Text(
                                  formatDuration(duration),
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.stackMd),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.shuffle_rounded,
                                  color: snapshot.shuffleEnabled
                                      ? theme.colorScheme.secondary
                                      : null,
                                ),
                                onPressed: () => playbackService.setShuffleMode(
                                  !snapshot.shuffleEnabled,
                                ),
                              ),
                              // Not gated on hasPrevious — see mini_player.dart's
                              // matching comment. skipToPrevious() restarts the
                              // current track when >3s in, which is always
                              // meaningful regardless of whether a real
                              // previous track exists, and a song is
                              // guaranteed loaded here (see the early return
                              // above).
                              IconButton(
                                icon: const Icon(
                                  Icons.skip_previous_rounded,
                                  size: 40,
                                ),
                                onPressed: playbackService.previous,
                              ),
                              _PlayPauseOrb(
                                isPlaying: isPlaying,
                                playbackService: playbackService,
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.skip_next_rounded,
                                  size: 40,
                                ),
                                onPressed: snapshot.hasNext
                                    ? playbackService.next
                                    : null,
                              ),
                              IconButton(
                                icon: Icon(
                                  snapshot.repeatMode == PlayerRepeatMode.one
                                      ? Icons.repeat_one_rounded
                                      : Icons.repeat_rounded,
                                  color:
                                      snapshot.repeatMode !=
                                          PlayerRepeatMode.off
                                      ? theme.colorScheme.secondary
                                      : null,
                                ),
                                onPressed: () => playbackService.setRepeatMode(
                                  switch (snapshot.repeatMode) {
                                    PlayerRepeatMode.off =>
                                      PlayerRepeatMode.all,
                                    PlayerRepeatMode.all =>
                                      PlayerRepeatMode.one,
                                    PlayerRepeatMode.one =>
                                      PlayerRepeatMode.off,
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.stackMd),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (song.format != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    borderRadius: AppRadius.borderRadiusFull,
                                  ),
                                  child: Text(
                                    song.format!.toUpperCase(),
                                    style: theme.textTheme.labelSmall,
                                  ),
                                ),
                              const SizedBox(width: AppSpacing.stackMd),
                              // Bug 9 (device testing pass): real lyrics are
                              // Phase 5 scope. Visibly disabled (muted color,
                              // no toggle behavior) rather than hidden, so
                              // it's clear this is intentionally inactive —
                              // tapping explains why instead of doing nothing.
                              TextButton.icon(
                                onPressed: () => ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Lyrics are coming in a later phase.',
                                        ),
                                      ),
                                    ),
                                style: TextButton.styleFrom(
                                  foregroundColor: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.38),
                                ),
                                icon: const Icon(
                                  Icons.lyrics_outlined,
                                  size: 18,
                                ),
                                label: const Text('LYRICS'),
                              ),
                              IconButton(
                                icon: const Icon(Icons.queue_music_rounded),
                                tooltip: 'Up Next',
                                onPressed: () => showModalBottomSheet<void>(
                                  context: context,
                                  backgroundColor: Colors.transparent,
                                  isScrollControlled: true,
                                  builder: (_) => const QueueScreen(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.stackLg),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayPauseOrb extends StatelessWidget {
  const _PlayPauseOrb({required this.isPlaying, required this.playbackService});

  final bool isPlaying;
  final PlaybackService playbackService;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: AppRadius.borderRadiusFull,
      padding: const EdgeInsets.all(16),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () =>
            isPlaying ? playbackService.pause() : playbackService.resume(),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 40,
        ),
      ),
    );
  }
}
