import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ta_music/data/database/daos/translations_cache_dao.dart';
import 'package:ta_music/data/database/database.dart';
import 'package:ta_music/data/repositories/translation_repository.dart';
import 'package:ta_music/data/services/translation/translation_client.dart';

class _MockTranslationClient extends Mock implements TranslationClient {}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    AppDatabase.debugDatabasePath = inMemoryDatabasePath;
    registerFallbackValue(CancelToken());
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  late _MockTranslationClient client;
  late TranslationsCacheDao cacheDao;
  late TranslationRepository repo;

  Future<void> setUp() async {
    client = _MockTranslationClient();
    cacheDao = TranslationsCacheDao(await AppDatabase.instance);
    repo = TranslationRepository(client: client, cacheDao: cacheDao, email: 'test@example.com');
  }

  test('an uncached line is fetched from the client and cached for next time', () async {
    await setUp();
    when(
      () => client.translate(
        text: 'Hello',
        targetLangCode: 'yo',
        email: any(named: 'email'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => const TranslationApiSuccess(translatedText: 'Ẹ n lẹ o', detectedSourceLang: 'en'),
    );

    final results = <int, TranslationLineResult>{};
    final rateLimited = await repo.translateLines(
      lines: ['Hello'],
      targetLangCode: 'yo',
      onLineResult: (i, r) => results[i] = r,
    );

    expect(rateLimited, isFalse);
    expect(results[0], isA<TranslationLineReady>());
    expect((results[0] as TranslationLineReady).translatedText, 'Ẹ n lẹ o');
    verify(
      () => client.translate(
        text: 'Hello',
        targetLangCode: 'yo',
        email: any(named: 'email'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).called(1);

    final cached = await cacheDao.find('Hello', 'yo');
    expect(cached, isNotNull);
    expect(cached!['translated_text'], 'Ẹ n lẹ o');
    expect(cached['source_lang'], 'en');
  });

  test('a cached line is served without calling the client at all', () async {
    await setUp();
    await cacheDao.upsert(
      sourceText: 'Hello',
      targetLang: 'fr',
      translatedText: 'Bonjour',
      sourceLang: 'en',
      translatedAt: DateTime(2026, 9, 1),
    );

    final results = <int, TranslationLineResult>{};
    await repo.translateLines(
      lines: ['Hello'],
      targetLangCode: 'fr',
      onLineResult: (i, r) => results[i] = r,
    );

    expect((results[0] as TranslationLineReady).translatedText, 'Bonjour');
    verifyNever(
      () => client.translate(
        text: any(named: 'text'),
        targetLangCode: any(named: 'targetLangCode'),
        email: any(named: 'email'),
        cancelToken: any(named: 'cancelToken'),
      ),
    );
  });

  test('the same source text cached under a different target language is a fresh miss', () async {
    await setUp();
    await cacheDao.upsert(
      sourceText: 'Hello',
      targetLang: 'fr',
      translatedText: 'Bonjour',
      translatedAt: DateTime(2026, 9, 1),
    );
    when(
      () => client.translate(
        text: 'Hello',
        targetLangCode: 'yo',
        email: any(named: 'email'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => const TranslationApiSuccess(translatedText: 'Ẹ n lẹ o'));

    final results = <int, TranslationLineResult>{};
    await repo.translateLines(
      lines: ['Hello'],
      targetLangCode: 'yo',
      onLineResult: (i, r) => results[i] = r,
    );

    expect((results[0] as TranslationLineReady).translatedText, 'Ẹ n lẹ o');
    verify(
      () => client.translate(
        text: 'Hello',
        targetLangCode: 'yo',
        email: any(named: 'email'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).called(1);
  });

  test('a blank line is reported as empty without touching the cache or client', () async {
    await setUp();

    final results = <int, TranslationLineResult>{};
    await repo.translateLines(
      lines: ['   '],
      targetLangCode: 'yo',
      onLineResult: (i, r) => results[i] = r,
    );

    expect((results[0] as TranslationLineReady).translatedText, '');
    verifyNever(
      () => client.translate(
        text: any(named: 'text'),
        targetLangCode: any(named: 'targetLangCode'),
        email: any(named: 'email'),
        cancelToken: any(named: 'cancelToken'),
      ),
    );
    expect(await cacheDao.find('   ', 'yo'), isNull);
  });

  test('a rate-limited response stops the batch and reports every remaining line as rate-limited, '
      'without blocking lines that had already started', () async {
    await setUp();
    when(
      () => client.translate(
        text: 'Line 0',
        targetLangCode: 'yo',
        email: any(named: 'email'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => const TranslationApiRateLimited());
    // A concurrency limit of 5: with only 1 line, this stub only matters if
    // ever called, but isn't expected to be for the untouched lines below.
    when(
      () => client.translate(
        text: any(named: 'text', that: startsWith('Line')),
        targetLangCode: 'yo',
        email: any(named: 'email'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => const TranslationApiRateLimited());

    final lines = List.generate(10, (i) => 'Line $i');
    final results = <int, TranslationLineResult>{};
    final rateLimited = await repo.translateLines(
      lines: lines,
      targetLangCode: 'yo',
      onLineResult: (i, r) => results[i] = r,
    );

    expect(rateLimited, isTrue);
    // Every single line got a result — none are left stranded on
    // "never called back", which would otherwise leave the UI stuck
    // showing a loading placeholder forever.
    expect(results.length, lines.length);
    expect(results.values, everyElement(isA<TranslationLineRateLimited>()));
  });

  test('one line failing (network error) does not block the rest of the batch', () async {
    await setUp();
    when(
      () => client.translate(
        text: 'Bad line',
        targetLangCode: 'yo',
        email: any(named: 'email'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => const TranslationApiFailure('Network error'));
    when(
      () => client.translate(
        text: 'Good line',
        targetLangCode: 'yo',
        email: any(named: 'email'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => const TranslationApiSuccess(translatedText: 'O daa'));

    final results = <int, TranslationLineResult>{};
    final rateLimited = await repo.translateLines(
      lines: ['Bad line', 'Good line'],
      targetLangCode: 'yo',
      onLineResult: (i, r) => results[i] = r,
    );

    expect(rateLimited, isFalse);
    expect(results[0], isA<TranslationLineFailed>());
    expect(results[1], isA<TranslationLineReady>());
    expect((results[1] as TranslationLineReady).translatedText, 'O daa');
    // The failed line is never cached — a retry (re-toggle) should hit the
    // network again rather than replaying a failure forever.
    expect(await cacheDao.find('Bad line', 'yo'), isNull);
  });

  group('same-language lines (Phase 5 batch 2 UX fix)', () {
    test(
      'a translated_text identical to the source (ignoring case/whitespace) is reported and '
      'cached as same-language, not as a real translation',
      () async {
        await setUp();
        when(
          () => client.translate(
            text: 'Ọmọ araye kala o',
            targetLangCode: 'yo',
            email: any(named: 'email'),
            cancelToken: any(named: 'cancelToken'),
          ),
          // MyMemory echoing the line back with different surrounding
          // whitespace/case is still "no real translation happened".
        ).thenAnswer((_) async => const TranslationApiSuccess(translatedText: '  ỌMỌ ARAYE KALA O  '));

        final results = <int, TranslationLineResult>{};
        await repo.translateLines(
          lines: ['Ọmọ araye kala o'],
          targetLangCode: 'yo',
          onLineResult: (i, r) => results[i] = r,
        );

        final result = results[0] as TranslationLineReady;
        expect(result.isSameLanguage, isTrue);

        final cached = await cacheDao.find('Ọmọ araye kala o', 'yo');
        expect(cached!['is_same_language'], 1);
      },
    );

    test('a genuinely different translation is not flagged as same-language', () async {
      await setUp();
      when(
        () => client.translate(
          text: "Don't take it personal",
          targetLangCode: 'yo',
          email: any(named: 'email'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => const TranslationApiSuccess(translatedText: 'Má gbà á lẹ́nu'));

      final results = <int, TranslationLineResult>{};
      await repo.translateLines(
        lines: ["Don't take it personal"],
        targetLangCode: 'yo',
        onLineResult: (i, r) => results[i] = r,
      );

      final result = results[0] as TranslationLineReady;
      expect(result.isSameLanguage, isFalse);
      expect(result.translatedText, 'Má gbà á lẹ́nu');
    });

    test('a cached same-language row is served with isSameLanguage true, without a fresh API call', () async {
      await setUp();
      await cacheDao.upsert(
        sourceText: 'Ọmọ araye kala o',
        targetLang: 'yo',
        translatedText: 'Ọmọ araye kala o',
        isSameLanguage: true,
        translatedAt: DateTime(2026, 9, 5),
      );

      final results = <int, TranslationLineResult>{};
      await repo.translateLines(
        lines: ['Ọmọ araye kala o'],
        targetLangCode: 'yo',
        onLineResult: (i, r) => results[i] = r,
      );

      expect((results[0] as TranslationLineReady).isSameLanguage, isTrue);
      verifyNever(
        () => client.translate(
          text: any(named: 'text'),
          targetLangCode: any(named: 'targetLangCode'),
          email: any(named: 'email'),
          cancelToken: any(named: 'cancelToken'),
        ),
      );
    });

    test(
      'a mixed-language song batch: lines that translate and lines already in the target '
      'language are both reported correctly in the same call (Asake "Gratitude" scenario)',
      () async {
        await setUp();
        when(
          () => client.translate(
            text: 'Ọmọ araye kala o',
            targetLangCode: 'yo',
            email: any(named: 'email'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async => const TranslationApiSuccess(translatedText: 'Ọmọ araye kala o'));
        when(
          () => client.translate(
            text: "Don't take it personal",
            targetLangCode: 'yo',
            email: any(named: 'email'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async => const TranslationApiSuccess(translatedText: 'Má gbà á lẹ́nu'));

        final results = <int, TranslationLineResult>{};
        final rateLimited = await repo.translateLines(
          lines: ['Ọmọ araye kala o', "Don't take it personal"],
          targetLangCode: 'yo',
          onLineResult: (i, r) => results[i] = r,
        );

        expect(rateLimited, isFalse);
        expect((results[0] as TranslationLineReady).isSameLanguage, isTrue);
        expect((results[1] as TranslationLineReady).isSameLanguage, isFalse);
        expect((results[1] as TranslationLineReady).translatedText, 'Má gbà á lẹ́nu');
      },
    );

    test(
      'MyMemory\'s same-language error, once translated by TranslationClient into an echoed '
      'success, is still recognized by the repository\'s equality check',
      () async {
        await setUp();
        // Simulates what TranslationClient now does for MyMemory's "PLEASE
        // SELECT TWO DISTINCT LANGUAGES" error — echoes the source text back
        // rather than surfacing the raw error string.
        when(
          () => client.translate(
            text: 'Ọmọ araye kala o',
            targetLangCode: 'yo',
            email: any(named: 'email'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async => const TranslationApiSuccess(translatedText: 'Ọmọ araye kala o'));

        final results = <int, TranslationLineResult>{};
        await repo.translateLines(
          lines: ['Ọmọ araye kala o'],
          targetLangCode: 'yo',
          onLineResult: (i, r) => results[i] = r,
        );

        // Never the literal MyMemory error string — the app never shows
        // "Please select two distinct languages" anywhere.
        final result = results[0] as TranslationLineReady;
        expect(result.translatedText, isNot(contains('DISTINCT')));
        expect(result.isSameLanguage, isTrue);
      },
    );
  });
}
