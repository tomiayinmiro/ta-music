import 'package:dio/dio.dart';

import '../database/daos/translations_cache_dao.dart';
import '../services/translation/translation_client.dart';

/// The outcome of translating one lyric line, reported per-line so the
/// caller (the Now Playing lyrics panel) can update each line's display in
/// place as results arrive, rather than waiting for the whole batch.
sealed class TranslationLineResult {
  const TranslationLineResult();
}

class TranslationLineReady extends TranslationLineResult {
  const TranslationLineReady({required this.translatedText, this.sourceLang, this.isSameLanguage = false});

  final String translatedText;
  final String? sourceLang;

  /// True when this line was already in the target language — [translatedText]
  /// is the original text unchanged (or MyMemory reported nothing to
  /// translate). The caller displays the original line only, no separate
  /// translation row below it. See `TranslationRepository.translateLines`
  /// for how this is determined.
  final bool isSameLanguage;
}

/// This specific line failed (network error, or MyMemory returned nothing
/// usable) — the caller falls back to showing the original line without a
/// translation, and does not retry automatically. Other lines in the same
/// batch are unaffected.
class TranslationLineFailed extends TranslationLineResult {
  const TranslationLineFailed();
}

/// This line was never attempted (or its own attempt hit the quota) because
/// [TranslationRepository.translateLines] stopped dispatching new requests
/// after a rate-limit signal. Treated the same as [TranslationLineFailed] by
/// the UI — original text only, no translation shown.
class TranslationLineRateLimited extends TranslationLineResult {
  const TranslationLineRateLimited();
}

/// Translates lyric lines via MyMemory, on demand only — no background
/// prefetch (see CLAUDE.md Phase 5 batch 2's non-negotiables). Cache-first
/// per line, indefinite TTL (a translation never goes stale), with up to
/// [_concurrency] requests in flight at once for whatever lines aren't
/// already cached.
class TranslationRepository {
  TranslationRepository({required this._client, required this._cacheDao, required this._email});

  final TranslationClient _client;
  final TranslationsCacheDao _cacheDao;
  final String _email;

  static const _concurrency = 5;

  /// Translates every line in [lines] into [targetLangCode], calling
  /// [onLineResult] once per line index as its result becomes available
  /// (cache hits resolve near-instantly; network misses arrive as each of
  /// up to [_concurrency] concurrent requests completes — order across
  /// indices is not guaranteed). A blank line is reported as an empty
  /// [TranslationLineReady] without ever hitting the cache or network.
  ///
  /// Returns `true` if the batch hit MyMemory's rate limit at any point.
  /// Once that happens, no further requests are dispatched — every line
  /// that hadn't already started is reported via [onLineResult] as
  /// [TranslationLineRateLimited] rather than being left to call back never,
  /// which would otherwise strand the UI on its "loading" placeholder
  /// forever.
  Future<bool> translateLines({
    required List<String> lines,
    required String targetLangCode,
    required void Function(int index, TranslationLineResult result) onLineResult,
    CancelToken? cancelToken,
  }) async {
    var rateLimited = false;
    var nextIndex = 0;
    final handled = <int>{};

    void report(int index, TranslationLineResult result) {
      handled.add(index);
      onLineResult(index, result);
    }

    Future<void> worker() async {
      while (true) {
        if (rateLimited) return;
        if (nextIndex >= lines.length) return;
        final index = nextIndex++;
        final text = lines[index];

        if (text.trim().isEmpty) {
          report(index, const TranslationLineReady(translatedText: ''));
          continue;
        }

        final cached = await _cacheDao.find(text, targetLangCode);
        if (cached != null) {
          report(
            index,
            TranslationLineReady(
              translatedText: cached['translated_text'] as String,
              sourceLang: cached['source_lang'] as String?,
              isSameLanguage: (cached['is_same_language'] as int? ?? 0) != 0,
            ),
          );
          continue;
        }

        final apiResult = await _client.translate(
          text: text,
          targetLangCode: targetLangCode,
          email: _email,
          cancelToken: cancelToken,
        );
        switch (apiResult) {
          case TranslationApiSuccess(:final translatedText, :final detectedSourceLang):
            // A line already in the target language — a mixed-language song,
            // or the target happens to match the song's own language — isn't
            // a failure or something to retry; MyMemory just has nothing to
            // translate. Detected by comparing content (normalized: trimmed,
            // lowercased) rather than trusting the `autodetect` source-
            // language guess, which is unreliable for short lines, slang, or
            // code-switched lyrics (confirmed: it misclassified some of
            // Asake's English lines as Igbo on the same song used to find
            // this). `TranslationClient` also routes MyMemory's "PLEASE
            // SELECT TWO DISTINCT LANGUAGES" error through here by echoing
            // the source text back, so that error is caught by this same
            // check instead of needing a separate case.
            final isSameLanguage = translatedText.trim().toLowerCase() == text.trim().toLowerCase();
            await _cacheDao.upsert(
              sourceText: text,
              targetLang: targetLangCode,
              translatedText: translatedText,
              sourceLang: detectedSourceLang,
              isSameLanguage: isSameLanguage,
              translatedAt: DateTime.now(),
            );
            report(
              index,
              TranslationLineReady(
                translatedText: translatedText,
                sourceLang: detectedSourceLang,
                isSameLanguage: isSameLanguage,
              ),
            );
          case TranslationApiRateLimited():
            rateLimited = true;
            report(index, const TranslationLineRateLimited());
          case TranslationApiFailure():
            report(index, const TranslationLineFailed());
        }
      }
    }

    await Future.wait(List.generate(_concurrency, (_) => worker()));

    if (rateLimited) {
      for (var i = 0; i < lines.length; i++) {
        if (!handled.contains(i)) {
          report(i, const TranslationLineRateLimited());
        }
      }
    }

    return rateLimited;
  }
}
