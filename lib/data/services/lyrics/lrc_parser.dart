import 'package:flutter/foundation.dart';

/// One line of lyrics, optionally carrying a real timestamp parsed from an
/// LRC `[mm:ss.xx]` tag. [timestamp] is null for plain, unsynced text.
@immutable
class LyricsLine {
  const LyricsLine({required this.text, this.timestamp});

  final String text;
  final Duration? timestamp;
}

final RegExp _lrcTagPattern = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');

/// Parses LRC-formatted text (`[mm:ss.xx]Lyric text`, possibly several
/// timestamp tags stacked on one line for a repeated lyric) into
/// timestamp-ordered [LyricsLine]s.
///
/// Metadata tags (`[ar:...]`, `[ti:...]`, `[offset:...]`, etc.) never match
/// the digit-only pattern above, so they're skipped naturally rather than
/// needing an explicit denylist. A line with no recognizable timestamp tag
/// at all is dropped entirely — callers fall back to [splitPlainLyrics] when
/// this returns an empty list, rather than mixing timed and untimed lines
/// together in one display.
List<LyricsLine> parseLrc(String text) {
  final lines = <LyricsLine>[];
  for (final rawLine in text.split(RegExp(r'\r\n|\n'))) {
    final matches = _lrcTagPattern.allMatches(rawLine).toList();
    if (matches.isEmpty) continue;
    final content = rawLine.substring(matches.last.end).trim();
    if (content.isEmpty) continue;
    for (final match in matches) {
      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final fraction = match.group(3);
      // A 2-digit fraction is centiseconds (".34" -> 340ms), a 3-digit one
      // is already milliseconds — padding a shorter fraction out to 3
      // digits before parsing handles both with the same arithmetic.
      final milliseconds =
          fraction == null ? 0 : int.parse(fraction.padRight(3, '0').substring(0, 3));
      lines.add(
        LyricsLine(
          text: content,
          timestamp: Duration(minutes: minutes, seconds: seconds, milliseconds: milliseconds),
        ),
      );
    }
  }
  lines.sort((a, b) => a.timestamp!.compareTo(b.timestamp!));
  return lines;
}

/// Plain, unsynced text split into display lines — blank lines dropped, same
/// rule the original lyrics.ovh-only implementation used (an equal-time slot
/// per line has nothing to show for a blank one).
List<LyricsLine> splitPlainLyrics(String text) {
  return text
      .split(RegExp(r'\r\n|\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .map((line) => LyricsLine(text: line))
      .toList();
}
