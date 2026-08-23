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
