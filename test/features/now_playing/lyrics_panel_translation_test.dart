import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ta_music/data/models/song.dart';
import 'package:ta_music/data/providers/lyrics_providers.dart';
import 'package:ta_music/data/providers/playback_providers.dart';
import 'package:ta_music/data/providers/repository_providers.dart';
import 'package:ta_music/data/providers/translation_providers.dart';
import 'package:ta_music/data/repositories/lyrics_repository.dart';
import 'package:ta_music/data/repositories/translation_repository.dart';
import 'package:ta_music/data/services/audio_service.dart';
import 'package:ta_music/data/services/lyrics/lrc_parser.dart';
import 'package:ta_music/features/now_playing/widgets/lyrics_panel.dart';
import 'package:ta_music/features/now_playing/widgets/lyrics_translation_widgets.dart';

import '../../fakes/fake_playback_handler.dart';

class _MockTranslationRepository extends Mock implements TranslationRepository {}

/// Resolves every line to `'T:<original text>'` immediately, synchronously
/// invoking [onLineResult] for each line before returning — stands in for
/// the real network+cache round trip so these widget tests only exercise
/// the panel's own toggle/song-change orchestration.
void _stubImmediateTranslation(_MockTranslationRepository repo) {
  when(
    () => repo.translateLines(
      lines: any(named: 'lines'),
      targetLangCode: any(named: 'targetLangCode'),
      onLineResult: any(named: 'onLineResult'),
      cancelToken: any(named: 'cancelToken'),
    ),
  ).thenAnswer((invocation) async {
    final lines = invocation.namedArguments[#lines] as List<String>;
    final onLineResult =
        invocation.namedArguments[#onLineResult] as void Function(int, TranslationLineResult);
    for (var i = 0; i < lines.length; i++) {
      onLineResult(i, TranslationLineReady(translatedText: 'T:${lines[i]}'));
    }
    return false;
  });
}

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

Song _song(int id) => Song(
  id: id,
  path: 'C:/music/song_$id.mp3',
  title: 'Song $id',
  artist: 'Artist $id',
  dateAdded: DateTime(2026, 1, 1),
  durationMs: const Duration(minutes: 3).inMilliseconds,
);

void main() {
  setUpAll(() {
    registerFallbackValue(CancelToken());
    registerFallbackValue(<String>[]);
    registerFallbackValue((int i, TranslationLineResult r) {});
  });

  Widget harness({
    required Song song,
    required List<LyricsLine> lines,
    required TranslationRepository translationRepository,
    String? targetLanguage = 'fr',
  }) {
    return ProviderScope(
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
        translationTargetLanguageProvider.overrideWith((ref) => Stream.value(targetLanguage)),
        translationRepositoryProvider.overrideWith((ref) async => translationRepository),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 320, height: 220, child: LyricsPanel(song: song, height: 220)),
          ),
        ),
      ),
    );
  }

  testWidgets('translation is off by default — no translated text, outlined toggle icon', (
    tester,
  ) async {
    final song = _song(1);
    final lines = [const LyricsLine(text: 'Hello', timestamp: null)];
    final repo = _MockTranslationRepository();
    _stubImmediateTranslation(repo);

    await tester.pumpWidget(harness(song: song, lines: lines, translationRepository: repo));
    await tester.pumpAndSettle();

    expect(find.text('T:Hello'), findsNothing);
    final toggle = tester.widget<TranslateToggleButton>(find.byType(TranslateToggleButton));
    expect(toggle.enabled, isFalse);
    verifyNever(
      () => repo.translateLines(
        lines: any(named: 'lines'),
        targetLangCode: any(named: 'targetLangCode'),
        onLineResult: any(named: 'onLineResult'),
        cancelToken: any(named: 'cancelToken'),
      ),
    );
  });

  testWidgets('tapping the toggle shows a translated line below each original', (tester) async {
    final song = _song(1);
    final lines = [
      const LyricsLine(text: 'Hello', timestamp: null),
      const LyricsLine(text: 'World', timestamp: null),
    ];
    final repo = _MockTranslationRepository();
    _stubImmediateTranslation(repo);

    await tester.pumpWidget(harness(song: song, lines: lines, translationRepository: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TranslateToggleButton));
    await tester.pumpAndSettle();

    expect(find.text('T:Hello'), findsOneWidget);
    expect(find.text('T:World'), findsOneWidget);
    verify(
      () => repo.translateLines(
        lines: ['Hello', 'World'],
        targetLangCode: 'fr',
        onLineResult: any(named: 'onLineResult'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).called(1);
  });

  testWidgets('tapping the toggle off hides the translated lines again', (tester) async {
    final song = _song(1);
    final lines = [const LyricsLine(text: 'Hello', timestamp: null)];
    final repo = _MockTranslationRepository();
    _stubImmediateTranslation(repo);

    await tester.pumpWidget(harness(song: song, lines: lines, translationRepository: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TranslateToggleButton));
    await tester.pumpAndSettle();
    expect(find.text('T:Hello'), findsOneWidget);

    await tester.tap(find.byType(TranslateToggleButton));
    await tester.pumpAndSettle();

    expect(find.text('T:Hello'), findsNothing);
  });

  testWidgets('with no target language chosen, tapping the toggle does nothing (and warns)', (
    tester,
  ) async {
    final song = _song(1);
    final lines = [const LyricsLine(text: 'Hello', timestamp: null)];
    final repo = _MockTranslationRepository();
    _stubImmediateTranslation(repo);

    await tester.pumpWidget(
      harness(song: song, lines: lines, translationRepository: repo, targetLanguage: null),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TranslateToggleButton));
    await tester.pump();

    expect(find.text('Pick a translation language in Settings > Lyrics first.'), findsOneWidget);
    verifyNever(
      () => repo.translateLines(
        lines: any(named: 'lines'),
        targetLangCode: any(named: 'targetLangCode'),
        onLineResult: any(named: 'onLineResult'),
        cancelToken: any(named: 'cancelToken'),
      ),
    );
  });

  testWidgets(
    'switching to a new song while translation is enabled keeps translating '
    'without requiring the toggle to be tapped again',
    (tester) async {
      final song1 = _song(1);
      final song2 = _song(2);
      final lines1 = [const LyricsLine(text: 'Song one line', timestamp: null)];
      final lines2 = [const LyricsLine(text: 'Song two line', timestamp: null)];
      final repo = _MockTranslationRepository();
      _stubImmediateTranslation(repo);

      final scope = ProviderScope(
        overrides: [
          lyricsForSongProvider(song1).overrideWith(
            (ref) async => LyricsFound(lines: lines1, isSynced: false, source: 'lyrics.ovh'),
          ),
          lyricsForSongProvider(song2).overrideWith(
            (ref) async => LyricsFound(lines: lines2, isSynced: false, source: 'lyrics.ovh'),
          ),
          playbackServiceProvider.overrideWithValue(
            PlaybackService(
              _FixedPlaybackHandler(
                duration: const Duration(minutes: 3),
                position: const Duration(seconds: 45),
              ),
            ),
          ),
          translationTargetLanguageProvider.overrideWith((ref) => Stream.value('fr')),
          translationRepositoryProvider.overrideWith((ref) async => repo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(width: 320, height: 220, child: LyricsPanel(song: song1, height: 220)),
            ),
          ),
        ),
      );

      await tester.pumpWidget(scope);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TranslateToggleButton));
      await tester.pumpAndSettle();
      expect(find.text('T:Song one line'), findsOneWidget);

      // Same ProviderScope, new `song` — mirrors NowPlayingScreen rebuilding
      // LyricsPanel with a new song from the same still-mounted route (a
      // skip-next), not a fresh navigation. `_LyricsLinesState` survives
      // since neither its own widget nor any ancestor's type changed.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lyricsForSongProvider(song1).overrideWith(
              (ref) async => LyricsFound(lines: lines1, isSynced: false, source: 'lyrics.ovh'),
            ),
            lyricsForSongProvider(song2).overrideWith(
              (ref) async => LyricsFound(lines: lines2, isSynced: false, source: 'lyrics.ovh'),
            ),
            playbackServiceProvider.overrideWithValue(
              PlaybackService(
                _FixedPlaybackHandler(
                  duration: const Duration(minutes: 3),
                  position: const Duration(seconds: 45),
                ),
              ),
            ),
            translationTargetLanguageProvider.overrideWith((ref) => Stream.value('fr')),
            translationRepositoryProvider.overrideWith((ref) async => repo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(width: 320, height: 220, child: LyricsPanel(song: song2, height: 220)),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('T:Song two line'), findsOneWidget);
      final toggle = tester.widget<TranslateToggleButton>(find.byType(TranslateToggleButton));
      expect(toggle.enabled, isTrue);
    },
  );

  testWidgets(
    'a mixed-language song (Asake "Gratitude" scenario): a line already in the target '
    'language shows its original text only, while a line that actually translated shows '
    'both — with no error text anywhere',
    (tester) async {
      final song = _song(1);
      const yorubaLine = 'Ọmọ araye kala o';
      const englishLine = "Don't take it personal";
      final lines = [
        const LyricsLine(text: yorubaLine, timestamp: null),
        const LyricsLine(text: englishLine, timestamp: null),
      ];
      final repo = _MockTranslationRepository();
      when(
        () => repo.translateLines(
          lines: any(named: 'lines'),
          targetLangCode: any(named: 'targetLangCode'),
          onLineResult: any(named: 'onLineResult'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((invocation) async {
        final onLineResult =
            invocation.namedArguments[#onLineResult] as void Function(int, TranslationLineResult);
        // Line 0 is already Yoruba (the target) — MyMemory reports it back
        // unchanged. Line 1 is English and genuinely translates.
        onLineResult(
          0,
          const TranslationLineReady(translatedText: yorubaLine, isSameLanguage: true),
        );
        onLineResult(1, const TranslationLineReady(translatedText: 'Má gbà á lẹ́nu'));
        return false;
      });

      await tester.pumpWidget(harness(song: song, lines: lines, translationRepository: repo));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TranslateToggleButton));
      await tester.pumpAndSettle();

      // The already-in-target-language line: original shown once, no
      // separate translation row (it would otherwise duplicate the text).
      expect(find.text(yorubaLine), findsOneWidget);
      // The genuinely-translated line: both original and translation shown.
      expect(find.text(englishLine), findsOneWidget);
      expect(find.text('Má gbà á lẹ́nu'), findsOneWidget);
      // Never MyMemory's raw error text, and never a "select two distinct
      // languages" banner anywhere in the tree.
      expect(find.textContaining('distinct languages'), findsNothing);
      expect(find.textContaining('DISTINCT LANGUAGES'), findsNothing);
    },
  );
}
