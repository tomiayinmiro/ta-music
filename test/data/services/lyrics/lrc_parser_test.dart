import 'package:flutter_test/flutter_test.dart';
import 'package:ta_music/data/services/lyrics/lrc_parser.dart';

void main() {
  group('parseLrc', () {
    test('parses standard [mm:ss.xx] tags into ordered timestamped lines', () {
      final lines = parseLrc('[00:01.00]First line\n[00:05.50]Second line\n[00:10.25]Third line');

      expect(lines, hasLength(3));
      expect(lines[0].text, 'First line');
      expect(lines[0].timestamp, const Duration(seconds: 1));
      expect(lines[1].timestamp, const Duration(seconds: 5, milliseconds: 500));
      expect(lines[2].timestamp, const Duration(seconds: 10, milliseconds: 250));
    });

    test('handles a 2-digit centisecond fraction and a missing fraction identically in kind', () {
      final lines = parseLrc('[00:01.5]Tenths\n[00:02]No fraction at all');

      expect(lines[0].timestamp, const Duration(seconds: 1, milliseconds: 500));
      expect(lines[1].timestamp, const Duration(seconds: 2));
    });

    test('sorts output by timestamp even if the source file is out of order', () {
      final lines = parseLrc('[00:10.00]Later\n[00:01.00]Earlier');

      expect(lines[0].text, 'Earlier');
      expect(lines[1].text, 'Later');
    });

    test('skips metadata tags entirely rather than treating them as lyric lines', () {
      final lines = parseLrc('[ar:Some Artist]\n[ti:Some Title]\n[00:01.00]Real lyric');

      expect(lines, hasLength(1));
      expect(lines.single.text, 'Real lyric');
    });

    test('drops a line with no timestamp tag at all', () {
      final lines = parseLrc('Just plain text, no brackets\n[00:01.00]Has a tag');

      expect(lines, hasLength(1));
      expect(lines.single.text, 'Has a tag');
    });

    test('drops a timed line whose content is blank (instrumental gap marker)', () {
      final lines = parseLrc('[00:01.00]\n[00:02.00]   \n[00:03.00]Real content');

      expect(lines, hasLength(1));
      expect(lines.single.text, 'Real content');
    });

    test('a single lyric stacked under multiple timestamps produces one line per tag', () {
      final lines = parseLrc('[00:01.00][00:30.00]Chorus line');

      expect(lines, hasLength(2));
      expect(lines[0].timestamp, const Duration(seconds: 1));
      expect(lines[1].timestamp, const Duration(seconds: 30));
      expect(lines.every((l) => l.text == 'Chorus line'), isTrue);
    });

    test('malformed brackets (non-numeric) are ignored, not crashed on', () {
      final lines = parseLrc('[not a timestamp]Some text\n[00:01.00]Valid');

      expect(lines, hasLength(1));
      expect(lines.single.text, 'Valid');
    });

    test('empty input yields an empty list', () {
      expect(parseLrc(''), isEmpty);
    });

    test('input with only metadata tags yields an empty list', () {
      expect(parseLrc('[ar:Artist]\n[al:Album]\n[length:03:45]'), isEmpty);
    });
  });

  group('splitPlainLyrics', () {
    test('splits on newlines, trims, and drops blank lines', () {
      final lines = splitPlainLyrics('Line one\r\nLine two\r\n\r\nLine three\n  \n');

      expect(lines.map((l) => l.text), ['Line one', 'Line two', 'Line three']);
    });

    test('every produced line has a null timestamp', () {
      final lines = splitPlainLyrics('Line one\nLine two');

      expect(lines.every((l) => l.timestamp == null), isTrue);
    });

    test('all-blank input yields an empty list', () {
      expect(splitPlainLyrics('\n\n   \n'), isEmpty);
    });

    test('a normal-length line is left as a single line, untouched', () {
      final lines = splitPlainLyrics('A perfectly normal lyric line');

      expect(lines, hasLength(1));
      expect(lines.single.text, 'A perfectly normal lyric line');
    });

    test('a pasted paragraph that lost its line breaks is wrapped into several bounded lines '
        '(regression: an unbroken multi-thousand-char line caused an 8.5s render stall / ANR '
        'on a budget device, 2026-08-24)', () {
      final word = 'lorem'; // 5 chars + 1 space = 6 chars/word
      final longLine = List.filled(1000, word).join(' '); // ~6000 chars, one "line"

      final lines = splitPlainLyrics(longLine);

      expect(lines.length, greaterThan(1));
      for (final line in lines) {
        expect(line.text.length, lessThanOrEqualTo(200));
      }
      // No words were dropped or corrupted by the rewrap.
      expect(lines.map((l) => l.text).join(' '), longLine);
    });

    test('a single run with no whitespace at all is hard-chunked rather than left unbounded', () {
      final noSpaces = 'a' * 5000;

      final lines = splitPlainLyrics(noSpaces);

      expect(lines.length, greaterThan(1));
      for (final line in lines) {
        expect(line.text.length, lessThanOrEqualTo(200));
      }
      expect(lines.map((l) => l.text).join(), noSpaces);
    });

    test('a line right at the wrap threshold is not split unnecessarily', () {
      final exactly200 = 'a' * 200;

      final lines = splitPlainLyrics(exactly200);

      expect(lines, hasLength(1));
      expect(lines.single.text, exactly200);
    });
  });
}
