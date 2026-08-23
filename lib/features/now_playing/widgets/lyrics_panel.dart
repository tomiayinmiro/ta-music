import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/motion.dart';
import '../../../core/theme/spacing.dart';
import '../../../data/models/song.dart';
import '../../../data/providers/lyrics_providers.dart';
import '../../../data/providers/playback_providers.dart';
import '../../../data/repositories/lyrics_repository.dart';
import '../../../data/services/lyrics/lrc_parser.dart';
import '../../../data/services/lyrics/lyrics_line_sync.dart';
import '../../../shared/widgets/empty_state.dart';

/// Replaces the cover-art area on Now Playing when the LYRICS toggle is on
/// (see `now_playing_screen.dart`) — the transport controls below stay
/// exactly where they are. There's no dedicated lyrics mockup in `designs/`
/// to work from, and an in-place swap (rather than a `Navigator.push`ed
/// screen) sidesteps CLAUDE.md's `AppScaffold`/mini-player rule entirely —
/// there's nothing to push, so no new route needs to decide whether it's a
/// "normal" pushed screen or another `NowPlayingScreen`-style exception.
/// Renders instantly with a loading spinner rather than waiting on the
/// fetch, per Phase 5 batch 1's "must open fast" rule.
class LyricsPanel extends ConsumerWidget {
  const LyricsPanel({super.key, required this.song, required this.height});

  final Song song;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultAsync = ref.watch(lyricsForSongProvider(song));

    return SizedBox(
      height: height,
      child: resultAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Couldn\'t load lyrics',
          message: 'Something went wrong fetching lyrics.',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(lyricsForSongProvider(song)),
        ),
        data: (result) => switch (result) {
          LyricsFound(:final lines, :final isSynced) =>
            _LyricsLines(lines: lines, isSynced: isSynced),
          LyricsNotFound() => const EmptyState(
              icon: Icons.lyrics_outlined,
              title: 'No lyrics found',
              message: 'No lyrics found for this song.',
            ),
          LyricsMissingMetadata() => const EmptyState(
              icon: Icons.info_outline_rounded,
              title: 'Missing song info',
              message: 'This song is missing artist or title tags, so lyrics can\'t be looked up.',
            ),
          LyricsFetchError(:final message) => EmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'Couldn\'t load lyrics',
              message: message,
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(lyricsForSongProvider(song)),
            ),
        },
      ),
    );
  }
}

class _LyricsLines extends ConsumerStatefulWidget {
  const _LyricsLines({required this.lines, required this.isSynced});

  final List<LyricsLine> lines;
  final bool isSynced;

  @override
  ConsumerState<_LyricsLines> createState() => _LyricsLinesState();
}

class _LyricsLinesState extends ConsumerState<_LyricsLines> {
  static const _itemExtent = 44.0;

  final _scrollController = ScrollController();
  int? _lastCenteredIndex;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Keeps [index] centered in the viewport. The very first sync (opening
  /// the panel, or a fresh song) jumps straight there; every sync after
  /// that animates, so the current line visibly glides into place as
  /// playback advances rather than snapping each time.
  void _centerOn(int index, double viewportHeight) {
    if (_lastCenteredIndex == index) return;
    final isFirstSync = _lastCenteredIndex == null;
    _lastCenteredIndex = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = (index * _itemExtent) - (viewportHeight / 2) + (_itemExtent / 2);
      final clamped = target.clamp(0.0, _scrollController.position.maxScrollExtent);
      if (isFirstSync) {
        _scrollController.jumpTo(clamped);
      } else {
        _scrollController.animateTo(
          clamped,
          duration: AppMotion.standard,
          curve: AppMotion.standardEasing,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snapshot = ref.watch(playbackSnapshotProvider).value;
    final position = snapshot?.position ?? Duration.zero;
    final duration = snapshot?.duration ?? snapshot?.currentSong?.duration ?? Duration.zero;
    final playbackService = ref.read(playbackServiceProvider);

    final currentIndex = widget.isSynced
        ? currentSyncedLyricLineIndex(
            timestamps: widget.lines.map((l) => l.timestamp!).toList(growable: false),
            position: position,
          )
        : currentLyricLineIndex(
            position: position,
            duration: duration,
            lineCount: widget.lines.length,
          );

    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            _centerOn(currentIndex, constraints.maxHeight);

            return ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(
                vertical: constraints.maxHeight / 2 - _itemExtent / 2,
              ),
              itemCount: widget.lines.length,
              itemExtent: _itemExtent,
              itemBuilder: (context, index) {
                final isCurrent = index == currentIndex;
                final line = widget.lines[index];
                return InkWell(
                  onTap: () => playbackService.seek(
                    widget.isSynced
                        ? line.timestamp!
                        : lineStartPosition(
                            lineIndex: index,
                            duration: duration,
                            lineCount: widget.lines.length,
                          ),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.containerMargin,
                      ),
                      child: Text(
                        line.text,
                        textAlign: TextAlign.center,
                        style: isCurrent
                            ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
                            : theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
        Positioned(top: 0, right: 0, child: _SyncIndicator(isSynced: widget.isSynced)),
      ],
    );
  }
}

/// Small "Synced"/"Estimated" badge — lets the user tell real per-line
/// timing (LRCLIB or a local `.lrc` file) apart from the equal-time-slot
/// approximation (plain text only, e.g. lyrics.ovh), which drifts on longer
/// or unevenly-paced songs. See `lyrics_line_sync.dart`.
class _SyncIndicator extends StatelessWidget {
  const _SyncIndicator({required this.isSynced});

  final bool isSynced;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSynced ? Icons.graphic_eq_rounded : Icons.timelapse_rounded,
            size: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            isSynced ? 'Synced' : 'Estimated',
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
