import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ta_music/data/services/translation/translation_client.dart';

class _MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> _response(Map<String, dynamic> data) {
  return Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: ''),
    statusCode: 200,
    data: data,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(Options());
    registerFallbackValue(CancelToken());
  });

  late _MockDio dio;
  late TranslationClient client;

  void setUp() {
    dio = _MockDio();
    client = TranslationClient(dio);
  }

  test('a normal successful response is returned as-is', () async {
    setUp();
    when(
      () => dio.getUri<Map<String, dynamic>>(any(), options: any(named: 'options'), cancelToken: any(named: 'cancelToken')),
    ).thenAnswer(
      (_) async => _response({
        'responseStatus': 200,
        'responseData': {'translatedText': 'Bonjour', 'detectedLanguage': 'en'},
      }),
    );

    final result = await client.translate(text: 'Hello', targetLangCode: 'fr');

    expect(result, isA<TranslationApiSuccess>());
    final success = result as TranslationApiSuccess;
    expect(success.translatedText, 'Bonjour');
    expect(success.detectedSourceLang, 'en');
  });

  test(
    'MyMemory\'s "PLEASE SELECT TWO DISTINCT LANGUAGES" error is echoed back as the source text, '
    'not surfaced as if it were a real translation',
    () async {
      setUp();
      when(
        () => dio.getUri<Map<String, dynamic>>(any(), options: any(named: 'options'), cancelToken: any(named: 'cancelToken')),
      ).thenAnswer(
        (_) async => _response({
          'responseStatus': 200,
          'responseData': {'translatedText': 'PLEASE SELECT TWO DISTINCT LANGUAGES'},
        }),
      );

      final result = await client.translate(text: 'Ọmọ araye kala o', targetLangCode: 'yo');

      expect(result, isA<TranslationApiSuccess>());
      final success = result as TranslationApiSuccess;
      // Echoes the ORIGINAL source text, not MyMemory's error string —
      // this is what lets TranslationRepository's plain source/target
      // equality check treat it as "already in the target language"
      // without needing a separate special case for this error.
      expect(success.translatedText, 'Ọmọ araye kala o');
    },
  );

  test('the same-language detection is case- and whitespace-insensitive on the trigger phrase', () async {
    setUp();
    when(
      () => dio.getUri<Map<String, dynamic>>(any(), options: any(named: 'options'), cancelToken: any(named: 'cancelToken')),
    ).thenAnswer(
      (_) async => _response({
        'responseStatus': 200,
        'responseData': {
          'translatedText': 'Please select two distinct languages. EXAMPLE: LANGPAIR=EN|IT',
        },
      }),
    );

    final result = await client.translate(text: 'Some line', targetLangCode: 'en');

    expect((result as TranslationApiSuccess).translatedText, 'Some line');
  });

  test('quota exhaustion is still detected ahead of the same-language check', () async {
    setUp();
    when(
      () => dio.getUri<Map<String, dynamic>>(any(), options: any(named: 'options'), cancelToken: any(named: 'cancelToken')),
    ).thenAnswer(
      (_) async => _response({
        'responseStatus': 429,
        'quotaFinished': null,
        'responseData': {'translatedText': 'MYMEMORY WARNING: YOU USED ALL AVAILABLE FREE TRANSLATIONS'},
      }),
    );

    final result = await client.translate(text: 'Hello', targetLangCode: 'fr');

    expect(result, isA<TranslationApiRateLimited>());
  });
}
