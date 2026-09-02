import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

/// The outcome of one MyMemory translate call.
sealed class TranslationApiResult {
  const TranslationApiResult();
}

class TranslationApiSuccess extends TranslationApiResult {
  const TranslationApiSuccess({required this.translatedText, this.detectedSourceLang});

  final String translatedText;

  /// MyMemory's own guess at the source language (e.g. `'fr'`), returned
  /// only when the request used `langpair=autodetect|...` — see [translate].
  final String? detectedSourceLang;
}

/// MyMemory's free-tier daily quota is exhausted. Confirmed directly against
/// the live API: quota exhaustion is signaled inside a `200 OK` JSON body
/// (`responseStatus`/`quotaFinished`), not reliably a true HTTP 429 — see
/// [translate]'s doc. Never retried automatically; the caller stops
/// dispatching further requests for the rest of the batch.
class TranslationApiRateLimited extends TranslationApiResult {
  const TranslationApiRateLimited();
}

class TranslationApiFailure extends TranslationApiResult {
  const TranslationApiFailure(this.message);

  final String message;
}

/// Client for MyMemory's free translation REST API
/// (https://mymemory.translated.net/doc/spec.php) — no API key, no signup.
/// Talks to it directly over the app's shared [Dio] rather than depending on
/// the `mymemory_translate` pub.dev package: that package bundles its own
/// `http` client (a second HTTP stack alongside `dio`, used nowhere else in
/// this app) and its documented language table omits Yoruba and Igbo, both
/// explicitly wanted for this app's Afrobeats/Nigerian-focused library, even
/// though MyMemory's actual API supports both fine via plain ISO 639-1
/// codes. See CLAUDE.md Phase 5 batch 2.
class TranslationClient {
  TranslationClient(this._dio);

  final Dio _dio;
  final _logger = Logger();

  static Options get _timeouts =>
      Options(sendTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 10));

  /// Translates [text] into [targetLangCode] (a plain ISO 639-1 code, e.g.
  /// `'yo'`). Source language is always `autodetect` rather than a fixed
  /// value — this app's lyrics come from whatever language a song happens
  /// to be in, and MyMemory returns its guess back as `detectedLanguage`
  /// (confirmed live: `langpair=autodetect|en` on French input returns
  /// `detectedLanguage: "fr"`), which is what [TranslationApiSuccess.detectedSourceLang]
  /// surfaces for the Now Playing lyrics panel's source-language badge.
  ///
  /// [email] is MyMemory's own documented way to raise the free daily quota
  /// from 5,000 to 50,000 characters — no account or auth, just a `de=`
  /// query param.
  Future<TranslationApiResult> translate({
    required String text,
    required String targetLangCode,
    String? email,
    CancelToken? cancelToken,
  }) async {
    final uri = Uri.https('api.mymemory.translated.net', '/get', {
      'q': text,
      'langpair': 'autodetect|$targetLangCode',
      if (email != null && email.trim().isNotEmpty) 'de': email,
    });
    try {
      final response = await _dio.getUri<Map<String, dynamic>>(
        uri,
        options: _timeouts,
        cancelToken: cancelToken,
      );
      return _parseBody(response.data, sourceText: text);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      if (e.response?.statusCode == 429) return const TranslationApiRateLimited();
      _logger.i('[translation] FAILED message=${e.message}');
      return TranslationApiFailure(_messageFor(e));
    }
  }

  /// A `200 OK` body doesn't always mean success — MyMemory signals quota
  /// exhaustion as `responseStatus` becoming `429` (sometimes a string,
  /// sometimes an int) or `quotaFinished: true` inside an otherwise-normal
  /// response, confirmed by reading MyMemory's own community-documented
  /// behavior; this project hasn't exhausted the quota live to observe it
  /// directly, so both signals are checked defensively alongside the real
  /// HTTP 429 handled above.
  TranslationApiResult _parseBody(Map<String, dynamic>? data, {required String sourceText}) {
    if (data == null) return const TranslationApiFailure('Empty translation response.');

    final quotaFinished = data['quotaFinished'] == true;
    final rawStatus = data['responseStatus'];
    final statusCode = rawStatus is int ? rawStatus : int.tryParse('$rawStatus');
    if (quotaFinished || statusCode == 429) {
      _logger.i('[translation] rate limited (quota exhausted)');
      return const TranslationApiRateLimited();
    }

    final responseData = data['responseData'] as Map<String, dynamic>?;
    final translatedText = responseData?['translatedText'] as String?;
    if (translatedText == null || translatedText.trim().isEmpty) {
      return const TranslationApiFailure('No translation returned.');
    }

    // MyMemory refuses a request whose (autodetected) source and requested
    // target resolve to the same language with this literal error string in
    // place of a translation — confirmed by a real repro (Asake's
    // "Gratitude", a Yoruba/English mix, with target=Yoruba: Yoruba lines
    // hit this). Left unhandled, that error text would render verbatim in
    // the lyrics panel as if it were the line's actual translation. Since a
    // same-language line legitimately has nothing to translate, echoing
    // [sourceText] back here makes it read exactly like a genuine "no-op"
    // translation to [TranslationRepository]'s own source/target equality
    // check below — one code path handles both ways this can happen,
    // instead of a separate special case for MyMemory's error message.
    if (translatedText.toUpperCase().contains('SELECT TWO DISTINCT LANGUAGES')) {
      _logger.i('[translation] MyMemory reported same source/target language — treating as a no-op');
      return TranslationApiSuccess(translatedText: sourceText, detectedSourceLang: null);
    }

    return TranslationApiSuccess(
      translatedText: translatedText,
      detectedSourceLang: responseData?['detectedLanguage'] as String?,
    );
  }

  String _messageFor(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => 'Translation request timed out.',
      DioExceptionType.connectionError => 'No connection — check your network and try again.',
      _ => 'Couldn\'t translate right now.',
    };
  }
}
