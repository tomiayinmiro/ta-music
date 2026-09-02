import '../../../data/repositories/translation_repository.dart';

/// Display state for one lyric line's translation — separate from
/// [TranslationLineResult] (the repository's per-request outcome) because
/// the panel needs a "not asked for yet" state too, before [load] resolves
/// even the first cache check.
sealed class TranslationLineDisplayState {
  const TranslationLineDisplayState();
}

class TranslationLoading extends TranslationLineDisplayState {
  const TranslationLoading();
}

class TranslationReady extends TranslationLineDisplayState {
  const TranslationReady(this.text);
  final String text;
}

/// Failed, rate-limited, a blank source line, or a line already in the
/// target language ([TranslationLineReady.isSameLanguage]) — all render the
/// same way (original text only, no translation row shown below it). The
/// line itself is never hidden in any of these cases, only the translation
/// row underneath it.
class TranslationUnavailable extends TranslationLineDisplayState {
  const TranslationUnavailable();
}

/// Owns the per-line translation state for whatever song's lyrics are
/// currently on screen. A plain Dart class, not a widget — [_LyricsLines]
/// (`lyrics_panel.dart`) creates one, keeps it alive across song changes
/// (matching that widget's own State lifetime — see its class doc), and
/// calls [setState] from [onUpdate].
class LyricsTranslationController {
  LyricsTranslationController({required this._repository, required this._onUpdate});

  final TranslationRepository _repository;
  final void Function() _onUpdate;

  final Map<int, TranslationLineDisplayState> _results = {};

  /// MyMemory's own guess at the source language of the most recent [load]'s
  /// lines, surfaced as the Now Playing lyrics panel's source-language
  /// badge. Set from whichever line resolves first with a non-null
  /// `sourceLang` — every line of one song is overwhelmingly likely to
  /// detect the same source language, so the first hit is enough to show a
  /// badge rather than waiting for every line.
  String? detectedSourceLanguage;

  /// True once the most recent [load] hit MyMemory's rate limit at any
  /// point — the caller shows a one-time "try again tomorrow" notice.
  bool rateLimited = false;

  /// Bumped by every [load] call so a superseded batch's late-arriving
  /// callbacks (from a fast song change starting a new [load] before the
  /// previous one finished) can't overwrite newer state.
  int _generation = 0;

  TranslationLineDisplayState stateFor(int index) => _results[index] ?? const TranslationLoading();

  /// Starts translating [lines] into [targetLangCode], replacing whatever
  /// state a previous [load] left behind.
  Future<void> load({required List<String> lines, required String targetLangCode}) async {
    final generation = ++_generation;
    _results.clear();
    for (var i = 0; i < lines.length; i++) {
      _results[i] = const TranslationLoading();
    }
    rateLimited = false;
    detectedSourceLanguage = null;
    _onUpdate();

    final hitRateLimit = await _repository.translateLines(
      lines: lines,
      targetLangCode: targetLangCode,
      onLineResult: (index, result) {
        if (generation != _generation) return;
        switch (result) {
          case TranslationLineReady(:final translatedText, :final sourceLang, :final isSameLanguage):
            _results[index] = (translatedText.isEmpty || isSameLanguage)
                ? const TranslationUnavailable()
                : TranslationReady(translatedText);
            detectedSourceLanguage ??= sourceLang;
          case TranslationLineFailed():
          case TranslationLineRateLimited():
            _results[index] = const TranslationUnavailable();
        }
        _onUpdate();
      },
    );

    if (generation != _generation) return;
    rateLimited = hitRateLimit;
    _onUpdate();
  }

  /// Discards all state without starting a new load — used when the user
  /// toggles translation off, so re-toggling on doesn't briefly flash the
  /// previous language's results before the new [load] call replaces them.
  void clear() {
    _generation++;
    _results.clear();
    rateLimited = false;
    detectedSourceLanguage = null;
  }
}
