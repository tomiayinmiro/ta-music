import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../../core/theme/motion.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_data.dart';
import '../../../data/models/song.dart';
import '../../../data/providers/lyrics_providers.dart';
import '../../../data/providers/playback_providers.dart';
import '../../../data/repositories/lyrics_repository.dart';
import '../../../data/services/lyrics/lrc_parser.dart';
import '../../../data/services/lyrics/lyrics_line_sync.dart';
import '../../../shared/widgets/empty_state.dart';
import '../screens/manual_lyrics_editor_screen.dart';

/// Replaces the cover-art area on Now Playing when the LYRICS toggle is on
/// (see `now_playing_screen.dart`) — the transport controls below stay
/// exactly where they are. There's no dedicated lyrics mockup in `designs/`
/// to work from, and an in-place swap (rather than a `Navigator.push`ed
/// screen) sidesteps CLAUDE.md's `AppScaffold`/mini-player rule entirely —
/// there's nothing to push, so no new route needs to decide whether it's a
/// "normal" pushed screen or another `NowPlayingScreen`-style exception.
/// Renders instantly with a loading spinner rather than waiting on the
/// fetch, per Phase 5 batch 1's "must open fast" rule.
// TODO(manual-lyrics-crash-audit): temporary instrumentation added
// 2026-09-01 to chase a reproducible hang/crash entering the manual lyrics
// editor for a specific song — see CLAUDE.md. Remove once root-caused.
final _log = Logger();

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
          LyricsFound(:final lines, :final isSynced, :final isPossibleMismatch) => Column(
            children: [
              if (isPossibleMismatch) _VersionMismatchBanner(song: song),
              Expanded(
                child: _LyricsLines(lines: lines, isSynced: isSynced),
              ),
            ],
          ),
          LyricsNotFound() => EmptyState(
            icon: Icons.lyrics_outlined,
            title: 'No lyrics found',
            message: 'No lyrics found for this song.',
            actionLabel: 'Add lyrics manually',
            onAction: () {
              // TODO(manual-lyrics-crash-audit): remove once root-caused.
              _log.i(
                '[manual_lyrics] "Add lyrics manually" tapped (not-found empty state) '
                'artist="${song.artist}" title="${song.title}" path="${song.path}" '
                'durationMs=${song.durationMs}',
              );
              Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => ManualLyricsEditorScreen(song: song)));
            },
          ),
          LyricsMissingMetadata() => EmptyState(
            icon: Icons.info_outline_rounded,
            title: 'Missing song info',
            message: 'This song is missing artist or title tags, so lyrics can\'t be looked up.',
            actionLabel: 'Add lyrics manually',
            onAction: () {
              // TODO(manual-lyrics-crash-audit): remove once root-caused.
              _log.i(
                '[manual_lyrics] "Add lyrics manually" tapped (missing-metadata empty state) '
                'artist="${song.artist}" title="${song.title}" path="${song.path}" '
                'durationMs=${song.durationMs}',
              );
              Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => ManualLyricsEditorScreen(song: song)));
            },
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

/// Shown above the lyrics when [LyricsFound.isPossibleMismatch] is true —
/// the LRCLIB hit came from the query cascade's last-resort,
/// primary-artist-only variant (see `LyricsRepository`'s
/// `buildLrclibQueryVariants`), so these lyrics may actually belong to a
/// different feat./ft. version of this title.
class _VersionMismatchBanner extends StatelessWidget {
  const _VersionMismatchBanner({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warning = theme.extension<AppSemanticColors>()?.warning ?? theme.colorScheme.error;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.containerMargin,
        AppSpacing.stackSm,
        AppSpacing.containerMargin,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.stackSm),
        decoration: BoxDecoration(
          color: warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: warning.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, size: 18, color: warning),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Showing lyrics from a different version — these may not match exactly.',
                    style: theme.textTheme.bodySmall,
                  ),
                  InkWell(
                    onTap: () {
                      // TODO(manual-lyrics-crash-audit): remove once root-caused.
                      _log.i(
                        '[manual_lyrics] "Add correct lyrics manually" tapped (mismatch banner) '
                        'artist="${song.artist}" title="${song.title}" path="${song.path}" '
                        'durationMs=${song.durationMs}',
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => ManualLyricsEditorScreen(song: song)),
                      );
                    },
                    child: Text(
                      'Add correct lyrics manually',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: warning,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
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

class _LyricsLines extends ConsumerStatefulWidget {
  const _LyricsLines({required this.lines, required this.isSynced});

  final List<LyricsLine> lines;
  final bool isSynced;

  @override
  ConsumerState<_LyricsLines> createState() => _LyricsLinesState();
}

/// Karaoke-style layout (YouTube Music/Spotify pattern, per Tomi's spec) —
/// the current line (or, in estimated-sync mode, the current highlighted
/// region — see `estimatedRegionRange`) sits at ~30% down the viewport,
/// with past lines dimmed above and upcoming lines dimmed below, and the
/// view glides smoothly to the next line/region rather than jumping.
///
/// Built on a real `SingleChildScrollView` + `ScrollController`, NOT a
/// manually `Transform.translate`d, fixed-row-height `Column` (the
/// previous approach) — that assumed every lyric renders as exactly one
/// visual line, so a lyric long enough to wrap onto 2-3 lines on a narrow
/// phone screen got crammed into a slot sized for one, overflowing past
/// the panel's bottom edge ("BOTTOM OVERFLOWED BY n PIXELS", the bug this
/// replaced). Each line now takes its own natural, wrapped height, and
/// `Scrollable.ensureVisible(alignment: _currentLinePosition)` computes the
/// scroll offset needed to keep the live line/region at that position
/// directly from the render tree's actual (variable) geometry — no manual
/// cumulative-height math needed. A `GlobalKey` per line is how
/// `ensureVisible` finds each line's `BuildContext`; all lines are built
/// eagerly (a `Column` inside the scroll view, not `ListView.builder`) so
/// every key resolves to a mounted context regardless of current scroll
/// position — a song has at most a few hundred lines, cheap to build all
/// at once.
class _LyricsLinesState extends ConsumerState<_LyricsLines> {
  /// Fraction down the viewport the current line's (or region's) leading
  /// edge rests at — "about 1/3 down", not top, center, or bottom.
  static const _currentLinePosition = 0.3;

  static const _resumeAfterInactivity = Duration(seconds: 3);

  /// Fraction of the viewport, at each edge, that fades to transparent —
  /// hints at content continuing beyond the frame without a hard cut.
  static const _fadeFraction = 0.16;

  final ScrollController _scrollController = ScrollController();

  /// Marks the viewport box itself (see [_isIndexVisible]) — distinct from
  /// the per-line keys below.
  final GlobalKey _viewportKey = GlobalKey();

  /// One key per lyric line, rebuilt whenever the line count changes (a new
  /// song) — see the class doc for why `ensureVisible` needs these to
  /// always resolve to a mounted context.
  late List<GlobalKey> _lineKeys;

  bool _userScrolling = false;

  /// The auto-follow index the view has already glided to (or is gliding
  /// to) — `null` until the first sync, which jumps instead of animating.
  /// Distinct from the always-fresh [_liveIndex] below: this one is only
  /// updated on the auto-follow path, so a resume after user-scrolling
  /// always targets where playback actually is, not where auto-follow left
  /// off before the user took over.
  int? _lastAutoIndex;
  int _liveIndex = 0;

  Timer? _resumeTimer;

  @override
  void initState() {
    super.initState();
    _lineKeys = List.generate(widget.lines.length, (_) => GlobalKey());
  }

  @override
  void didUpdateWidget(covariant _LyricsLines oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lines.length != widget.lines.length) {
      _lineKeys = List.generate(widget.lines.length, (_) => GlobalKey());
      _lastAutoIndex = null;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _resumeTimer?.cancel();
    super.dispose();
  }

  void _followIndex(int index, {required bool animate}) {
    if (index < 0 || index >= _lineKeys.length) return;
    final keyContext = _lineKeys[index].currentContext;
    if (keyContext == null) return;
    Scrollable.ensureVisible(
      keyContext,
      alignment: _currentLinePosition,
      duration: animate ? AppMotion.lyricsGlide : Duration.zero,
      curve: AppMotion.lyricsGlideEasing,
    );
  }

  /// True when [index]'s line currently renders anywhere within the
  /// visible viewport — used only to let user-scrolling resume auto-follow
  /// early if the live line drifts entirely off-screen, rather than always
  /// waiting out [_resumeAfterInactivity].
  bool _isIndexVisible(int index) {
    if (index < 0 || index >= _lineKeys.length) return false;
    final viewportBox = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    final box = _lineKeys[index].currentContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null || box == null || !box.attached) return false;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: viewportBox);
    return topLeft.dy + box.size.height > 0 && topLeft.dy < viewportBox.size.height;
  }

  /// Called every frame from [build] via a post-frame callback — either
  /// keeps auto-follow in sync with the live current line, or, while the
  /// user is scrolling, watches for the current line drifting outside the
  /// visible range so it can resume early.
  void _syncPosition(int index) {
    _liveIndex = index;

    if (_userScrolling) {
      if (!_isIndexVisible(index)) _resumeAuto(index);
      return;
    }

    if (_lastAutoIndex == index) return;
    final isFirstSync = _lastAutoIndex == null;
    _lastAutoIndex = index;
    _followIndex(index, animate: !isFirstSync);
  }

  void _resumeAuto(int index) {
    _resumeTimer?.cancel();
    _userScrolling = false;
    _lastAutoIndex = index;
    _followIndex(index, animate: true);
  }

  void _scheduleResume() {
    _resumeTimer?.cancel();
    _resumeTimer = Timer(_resumeAfterInactivity, () {
      if (!mounted) return;
      _resumeAuto(_liveIndex);
    });
  }

  /// Only a real user drag starts this way — `Scrollable.ensureVisible`
  /// drives its own scroll via a ballistic/driven activity, whose
  /// [ScrollStartNotification.dragDetails] is always null, so auto-follow's
  /// own scrolling never falsely marks itself as user-initiated (and so
  /// never schedules a pointless resume timer against itself).
  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification && notification.dragDetails != null) {
      _resumeTimer?.cancel();
      _userScrolling = true;
    } else if (notification is ScrollEndNotification && _userScrolling) {
      _scheduleResume();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(playbackSnapshotProvider).value;
    final position = snapshot?.position ?? Duration.zero;
    final duration = snapshot?.duration ?? snapshot?.currentSong?.duration ?? Duration.zero;
    final playbackService = ref.read(playbackServiceProvider);

    // TODO(future session): per-song +/-0.5s offset adjustment for LRCLIB
    // timestamps that drift from the actual audio (see the doc comment on
    // `currentSyncedLyricLineIndex` in lyrics_line_sync.dart) — apply the
    // stored offset to `position` here once that feature exists.
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

    // Bug 2 (Option C): a single highlighted line is misleading once
    // estimated (equal-time-slot) sync drifts from the real audio, so
    // estimated mode highlights a whole sliding region instead — see
    // `estimatedRegionLineCount`/`estimatedRegionRange`. Synced lyrics keep
    // the original single-line highlight since their timing is real.
    final highlightRange = widget.isSynced
        ? (start: currentIndex, end: currentIndex)
        : estimatedRegionRange(
            currentIndex: currentIndex,
            lineCount: widget.lines.length,
            regionSize: estimatedRegionLineCount(lineCount: widget.lines.length, duration: duration),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportHeight = constraints.maxHeight;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _syncPosition(currentIndex);
        });

        return Stack(
          children: [
            SizedBox(
              key: _viewportKey,
              width: double.infinity,
              height: viewportHeight,
              child: ClipRect(
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) => LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: const [
                      Colors.transparent,
                      Colors.black,
                      Colors.black,
                      Colors.transparent,
                    ],
                    stops: [0.0, _fadeFraction, 1 - _fadeFraction, 1.0],
                  ).createShader(rect),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _handleScrollNotification,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      // Extra scroll room above the first line and below
                      // the last so `Scrollable.ensureVisible`'s
                      // `alignment` can be satisfied even for lines right
                      // at either end of the song — without it, the first
                      // or last line could never reach ~30% down the
                      // viewport since there's nothing further to scroll
                      // past them.
                      padding: EdgeInsets.symmetric(vertical: viewportHeight),
                      child: Column(
                        children: [
                          for (var i = 0; i < widget.lines.length; i++)
                            _LyricLineRow(
                              key: _lineKeys[i],
                              text: widget.lines[i].text,
                              isHighlighted: i >= highlightRange.start && i <= highlightRange.end,
                              onTap: () => playbackService.seek(
                                widget.isSynced
                                    ? widget.lines[i].timestamp!
                                    : lineStartPosition(
                                        lineIndex: i,
                                        duration: duration,
                                        lineCount: widget.lines.length,
                                      ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(top: 0, right: 0, child: _SyncIndicator(isSynced: widget.isSynced)),
          ],
        );
      },
    );
  }
}

class _LyricLineRow extends StatelessWidget {
  const _LyricLineRow({
    super.key,
    required this.text,
    required this.isHighlighted,
    required this.onTap,
  });

  final String text;

  /// True for the current line in synced mode, or for every line inside
  /// the current region in estimated mode (Bug 2 / Option C) — either way
  /// it gets the same bright/bold prominence, per spec. Since a whole
  /// lyric (even one that wraps onto several visual lines) is a single
  /// `Text` widget below, it highlights/dims as one visual unit
  /// automatically — no separate handling needed for wrapped lines.
  final bool isHighlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        // Bug 1 fix: no fixed height here — a lyric long enough to wrap
        // onto multiple visual lines on a narrow screen simply makes this
        // row taller instead of overflowing a slot sized for one line.
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.containerMargin,
          vertical: AppSpacing.stackSm,
        ),
        child: AnimatedDefaultTextStyle(
          duration: AppMotion.lyricsGlide,
          curve: AppMotion.lyricsGlideEasing,
          textAlign: TextAlign.center,
          style: isHighlighted
              ? theme.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold)
              : theme.textTheme.bodyLarge!.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
          child: Text(text),
        ),
      ),
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
