import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ta_music/data/models/song.dart';
import 'package:ta_music/data/providers/lyrics_providers.dart';
import 'package:ta_music/data/providers/playback_providers.dart';
import 'package:ta_music/data/repositories/lyrics_repository.dart';
import 'package:ta_music/data/services/audio_service.dart';
import 'package:ta_music/data/services/lyrics/lrc_parser.dart';
import 'package:ta_music/features/now_playing/widgets/lyrics_panel.dart';

import '../../fakes/fake_playback_handler.dart';

/// A [FakePlaybackHandler] whose position/duration are fixed at
/// construction, instead of always-zero/null — the karaoke lyrics view
/// needs a real duration to compute an estimated-sync region.
class _FixedPlaybackHandler extends FakePlaybackHandler {
  _FixedPlaybackHandler({required this.duration, required this.position});

  @override
  final Duration? duration;
  final Duration position;

  @override
  Stream<Duration> get positionStream => Stream.value(position);
  @override
  Stream<Duration?> get durationStream => Stream.value(duration);
}

void main() {
  final song = Song(
    id: 1,
    path: 'C:/music/song_1.mp3',
    title: 'Song 1',
    artist: 'Artist 1',
    dateAdded: DateTime(2026, 1, 1),
    durationMs: const Duration(minutes: 3).inMilliseconds,
  );

  /// Regression test for Bug 1 (karaoke redesign layout overflow): a long
  /// lyrics list rendered in the small, cover-art-sized box `NowPlayingScreen`
  /// gives `LyricsPanel` used to force the internal lines `Column` into a
  /// tight height it couldn't fit in, throwing "BOTTOM OVERFLOWED BY n
  /// PIXELS". Fixed by loosening that constraint with `OverflowBox` before
  /// clipping back down to the viewport. 60 lines stress the scroll/overflow
  /// behavior the bug report specifically asked to verify (50+ lines).
  testWidgets('a 60-line lyrics list does not overflow its constrained box', (tester) async {
    final manyLines = List.generate(
      60,
      (i) => LyricsLine(text: 'Lyric line number $i', timestamp: null),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lyricsForSongProvider(
            song,
          ).overrideWith((ref) async => LyricsFound(lines: manyLines, isSynced: false, source: 'lyrics.ovh')),
          playbackServiceProvider.overrideWithValue(
            PlaybackService(
              _FixedPlaybackHandler(
                duration: const Duration(minutes: 3),
                position: const Duration(seconds: 45),
              ),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            // Deliberately small, like the cover-art-sized box
            // `NowPlayingScreen` gives `LyricsPanel` (~45% of a phone's
            // available height, further squeezed on a short window).
            body: Center(
              child: SizedBox(width: 320, height: 220, child: LyricsPanel(song: song, height: 220)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  /// Regression test for the corrected Bug 1 diagnosis: the karaoke view
  /// wasn't overflowing its container — individual long lyrics that wrap
  /// onto 2-3 visual lines on a narrow phone screen were being forced into
  /// a row sized for exactly one visual line (a fixed `_rowHeight`),
  /// overflowing that row. Fixed by giving each line its own natural,
  /// wrapped height (`SingleChildScrollView` + `Scrollable.ensureVisible`
  /// instead of a fixed-height `Transform.translate`d `Column`). Mirrors
  /// the real "Gratitude" repro: several long Yoruba lyric lines that only
  /// fit on one line on a wide window, but wrap on a narrow phone width.
  testWidgets('a long lyric that wraps onto multiple visual lines does not overflow, and is not '
      'truncated', (tester) async {
    const longLine =
        "No give me yawa o (yawa o), no give me vawa o, vawa o, Ọmọ araye kala o, "
        "ti o ba s'owo wọn ma japa o";
    final lines = [
      const LyricsLine(text: 'Short line one', timestamp: null),
      const LyricsLine(text: longLine, timestamp: null),
      const LyricsLine(text: 'Short line two', timestamp: null),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lyricsForSongProvider(
            song,
          ).overrideWith((ref) async => LyricsFound(lines: lines, isSynced: false, source: 'lyrics.ovh')),
          playbackServiceProvider.overrideWithValue(
            PlaybackService(
              _FixedPlaybackHandler(
                duration: const Duration(minutes: 3),
                position: const Duration(seconds: 45),
              ),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            // Narrow, phone-portrait-like width — wide enough on a
            // desktop window for `longLine` to fit on one visual line
            // (the "Windows: verify no regression" case), but narrow here
            // to force wrapping the way the phone repro did.
            body: Center(
              child: SizedBox(width: 320, height: 220, child: LyricsPanel(song: song, height: 220)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The full, untruncated lyric is present as one Text widget — proves
    // it isn't cut with an ellipsis, and that the whole (possibly
    // multi-visual-line) lyric highlights/dims as a single unit rather
    // than being split across separately-styled rows.
    final textWidget = tester.widget<Text>(find.text(longLine));
    expect(textWidget.maxLines, isNull);
    expect(textWidget.overflow, isNot(TextOverflow.ellipsis));
  });
}
