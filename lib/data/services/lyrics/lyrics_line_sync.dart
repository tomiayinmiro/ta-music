/// Plain-text lyrics (no per-line timestamps — currently only lyrics.ovh, of
/// the 3 fallback layers `LyricsRepository` tries) fall back to an estimate:
/// [duration] is divided equally across [lineCount] lines, so a line's
/// "slot" is `duration / lineCount` wide regardless of how long that line
/// actually takes to sing. This drifts increasingly out of sync on longer
/// songs and songs with uneven line lengths (a two-word line and a ten-word
/// line get the same slot) — an accepted approximation, not a bug. Real
/// timestamps (LRCLIB's `syncedLyrics`, or a local `.lrc` file) use
/// [currentSyncedLyricLineIndex] instead, which needs no estimate at all.
library;

/// The estimated current line index for [position] within a song of
/// [duration] split into [lineCount] equal slots. Clamped to a valid line
/// index; returns 0 for a degenerate [lineCount] or [duration].
int currentLyricLineIndex({
  required Duration position,
  required Duration duration,
  required int lineCount,
}) {
  if (lineCount <= 0 || duration.inMilliseconds <= 0) return 0;
  final msPerLine = duration.inMilliseconds / lineCount;
  final index = (position.inMilliseconds / msPerLine).floor();
  return index.clamp(0, lineCount - 1);
}

/// The estimated playback position at which [lineIndex] begins — the
/// inverse of [currentLyricLineIndex], used to seek when a line is tapped.
Duration lineStartPosition({
  required int lineIndex,
  required Duration duration,
  required int lineCount,
}) {
  if (lineCount <= 0 || duration.inMilliseconds <= 0) return Duration.zero;
  final msPerLine = duration.inMilliseconds / lineCount;
  final clampedIndex = lineIndex.clamp(0, lineCount - 1);
  return Duration(milliseconds: (msPerLine * clampedIndex).round());
}

/// The current line index among real, ascending [timestamps] — the last one
/// at or before [position]. Assumes [timestamps] is sorted ascending, which
/// is guaranteed by `parseLrc`. Returns 0 for an empty list or a [position]
/// before the first timestamp.
int currentSyncedLyricLineIndex({required List<Duration> timestamps, required Duration position}) {
  if (timestamps.isEmpty) return 0;
  var index = 0;
  for (var i = 0; i < timestamps.length; i++) {
    if (timestamps[i] > position) break;
    index = i;
  }
  return index;
}

// TODO(future session): LRCLIB's community-contributed synced timing can
// drift a few seconds off the actual audio for a given song (tighter/looser
// contributor sync, not fixable at this layer). Planned fix is a per-song,
// user-adjustable +/-0.5s offset stored alongside the cached lyrics and
// applied to `position` before it reaches [currentSyncedLyricLineIndex] —
// don't re-derive this from scratch, the offset just needs to shift the
// comparison here.

/// How many consecutive lines to highlight together as one "current
/// section" for estimated (non-synced) lyrics — see [estimatedRegionRange].
/// A single highlighted line reads as flatly wrong once real playback
/// drifts from the equal-time-slot estimate ([currentLyricLineIndex]), so a
/// shifting region of lines reads as "approximately here" instead of
/// claiming exactness it doesn't have. Sized so the region spans roughly
/// [_targetRegionSeconds] of estimated playback time regardless of how
/// dense a song's lines are — a song with short, frequent lines needs more
/// of them to cover that many seconds; a song with long, sparse lines
/// needs fewer — then clamped to a range that always still reads visually
/// as "a few lines," not one and not a whole verse.
const double _targetRegionSeconds = 12.5;
const int minEstimatedRegionLines = 2;
const int maxEstimatedRegionLines = 5;

/// The estimated-sync region size for a song of [duration] with [lineCount]
/// lines. Returns [minEstimatedRegionLines] for degenerate input.
int estimatedRegionLineCount({required int lineCount, required Duration duration}) {
  if (lineCount <= 0 || duration.inMilliseconds <= 0) return minEstimatedRegionLines;
  final secondsPerLine = duration.inMilliseconds / 1000 / lineCount;
  if (secondsPerLine <= 0) return minEstimatedRegionLines;
  final size = (_targetRegionSeconds / secondsPerLine).round();
  return size.clamp(minEstimatedRegionLines, maxEstimatedRegionLines);
}

/// The highlighted region for estimated sync: [regionSize] consecutive
/// lines starting at [currentIndex] (the same anchor
/// [currentLyricLineIndex] already computes), clamped so it never runs
/// past the last line — the region shrinks near the end of the song rather
/// than wrapping or going out of range.
({int start, int end}) estimatedRegionRange({
  required int currentIndex,
  required int lineCount,
  required int regionSize,
}) {
  if (lineCount <= 0) return (start: 0, end: 0);
  final start = currentIndex.clamp(0, lineCount - 1);
  final end = (start + regionSize - 1).clamp(0, lineCount - 1);
  return (start: start, end: end);
}
