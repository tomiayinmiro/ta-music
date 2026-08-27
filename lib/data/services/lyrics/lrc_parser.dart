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
      final milliseconds = fraction == null
          ? 0
          : int.parse(fraction.padRight(3, '0').substring(0, 3));
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
///
/// A "line" longer than [_maxDisplayLineLength] is re-wrapped into several —
/// found via a device crash (2026-08-24): a manually-pasted lyric that lost
/// its real line breaks in the copy/paste became one several-thousand-
/// character line, and `LyricsPanel`'s `_LyricsLines` renders each line as
/// an unconstrained `Text` with no `maxLines`. Laying out one unbroken
/// string that long triggered an 8.5s single-frame stall (an Android ANR)
/// on a budget device — Skia's line-breaking/shaping cost doesn't stay
/// linear at that length. No real sung lyric line is anywhere near this
/// long, so wrapping here is display-only and never fires for normal
/// (LRCLIB/lyrics.ovh/manually-typed) lyrics.
List<LyricsLine> splitPlainLyrics(String text) {
  return text
      .split(RegExp(r'\r\n|\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .expand(_wrapLongLine)
      .map((line) => LyricsLine(text: line))
      .toList();
}

const _maxDisplayLineLength = 200;

Iterable<String> _wrapLongLine(String line) sync* {
  if (line.length <= _maxDisplayLineLength) {
    yield line;
    return;
  }
  var current = StringBuffer();
  for (final word in line.split(RegExp(r'\s+'))) {
    if (current.isNotEmpty && current.length + word.length + 1 > _maxDisplayLineLength) {
      yield current.toString();
      current = StringBuffer();
    }
    if (current.isNotEmpty) current.write(' ');
    current.write(word);
    // A single "word" with no whitespace at all (e.g. lost line breaks AND
    // spaces) could itself still exceed the cap — hard-chunk it so nothing
    // ever reaches the renderer unbounded.
    while (current.length > _maxDisplayLineLength) {
      yield current.toString().substring(0, _maxDisplayLineLength);
      current = StringBuffer(current.toString().substring(_maxDisplayLineLength));
    }
  }
  if (current.isNotEmpty) yield current.toString();
}
