import 'package:flutter_test/flutter_test.dart';
import 'package:ta_music/data/services/lyrics/lyrics_line_sync.dart';

void main() {
  group('currentLyricLineIndex', () {
    test('splits duration equally across lines', () {
      // 10 lines over a 100s song -> 10s per line.
      expect(
        currentLyricLineIndex(
          position: const Duration(seconds: 0),
          duration: const Duration(seconds: 100),
          lineCount: 10,
        ),
        0,
      );
      expect(
        currentLyricLineIndex(
          position: const Duration(seconds: 25),
          duration: const Duration(seconds: 100),
          lineCount: 10,
        ),
        2,
      );
      expect(
        currentLyricLineIndex(
          position: const Duration(seconds: 99),
          duration: const Duration(seconds: 100),
          lineCount: 10,
        ),
        9,
      );
    });

    test('clamps to the last line when position reaches or exceeds duration', () {
      expect(
        currentLyricLineIndex(
          position: const Duration(seconds: 100),
          duration: const Duration(seconds: 100),
          lineCount: 10,
        ),
        9,
      );
      expect(
        currentLyricLineIndex(
          position: const Duration(seconds: 500),
          duration: const Duration(seconds: 100),
          lineCount: 10,
        ),
        9,
      );
    });

    test('a single line is always current', () {
      expect(
        currentLyricLineIndex(
          position: const Duration(seconds: 0),
          duration: const Duration(seconds: 100),
          lineCount: 1,
        ),
        0,
      );
      expect(
        currentLyricLineIndex(
          position: const Duration(seconds: 100),
          duration: const Duration(seconds: 100),
          lineCount: 1,
        ),
        0,
      );
    });

    test('degenerate lineCount or duration returns 0 rather than dividing by zero', () {
      expect(
        currentLyricLineIndex(
          position: const Duration(seconds: 10),
          duration: const Duration(seconds: 100),
          lineCount: 0,
        ),
        0,
      );
      expect(
        currentLyricLineIndex(
          position: const Duration(seconds: 10),
          duration: Duration.zero,
          lineCount: 10,
        ),
        0,
      );
    });
  });

  group('lineStartPosition', () {
    test('is the inverse of currentLyricLineIndex at each line boundary', () {
      expect(
        lineStartPosition(lineIndex: 0, duration: const Duration(seconds: 100), lineCount: 10),
        Duration.zero,
      );
      expect(
        lineStartPosition(lineIndex: 5, duration: const Duration(seconds: 100), lineCount: 10),
        const Duration(seconds: 50),
      );
      expect(
        lineStartPosition(lineIndex: 9, duration: const Duration(seconds: 100), lineCount: 10),
        const Duration(seconds: 90),
      );
    });

    test('clamps an out-of-range line index', () {
      expect(
        lineStartPosition(lineIndex: 99, duration: const Duration(seconds: 100), lineCount: 10),
        const Duration(seconds: 90),
      );
      expect(
        lineStartPosition(lineIndex: -1, duration: const Duration(seconds: 100), lineCount: 10),
        Duration.zero,
      );
    });

    test('degenerate lineCount or duration returns zero', () {
      expect(
        lineStartPosition(lineIndex: 3, duration: const Duration(seconds: 100), lineCount: 0),
        Duration.zero,
      );
      expect(
        lineStartPosition(lineIndex: 3, duration: Duration.zero, lineCount: 10),
        Duration.zero,
      );
    });
  });

  group('currentSyncedLyricLineIndex', () {
    const timestamps = [
      Duration(seconds: 0),
      Duration(seconds: 10),
      Duration(seconds: 25),
      Duration(seconds: 40),
    ];

    test('before the first timestamp returns index 0', () {
      expect(
        currentSyncedLyricLineIndex(timestamps: timestamps, position: Duration.zero),
        0,
      );
    });

    test('returns the last timestamp at or before position', () {
      expect(
        currentSyncedLyricLineIndex(
          timestamps: timestamps,
          position: const Duration(seconds: 24),
        ),
        1,
      );
      expect(
        currentSyncedLyricLineIndex(
          timestamps: timestamps,
          position: const Duration(seconds: 25),
        ),
        2,
      );
    });

    test('past the last timestamp stays on the last line', () {
      expect(
        currentSyncedLyricLineIndex(
          timestamps: timestamps,
          position: const Duration(minutes: 10),
        ),
        3,
      );
    });

    test('an empty timestamp list returns 0', () {
      expect(
        currentSyncedLyricLineIndex(timestamps: const [], position: const Duration(seconds: 5)),
        0,
      );
    });
  });
}
