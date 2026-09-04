import '../database/daos/settings_dao.dart';
import 'reactive_query.dart';

/// App-level preferences stored in the `settings` key-value table.
class SettingsRepository {
  SettingsRepository(this._dao);

  final SettingsDao _dao;

  static const _resumeAfterInterruptionKey = 'resume_after_interruption';

  /// Whether playback should resume automatically once an audio-focus
  /// interruption (a phone call, another app's audio) ends. Defaults to
  /// false — per CLAUDE.md's Phase 3 brief, the user has to opt in.
  Stream<bool> watchResumeAfterInterruption() =>
      watchQuery({'settings'}, () async => (await _dao.get(_resumeAfterInterruptionKey)) == 'true');

  Future<void> setResumeAfterInterruption(bool value) =>
      _dao.set(_resumeAfterInterruptionKey, value.toString());

  static const _translationTargetLanguageKey = 'translation_target_language';

  /// The user's chosen lyrics-translation target language, an ISO 639-1 code
  /// (e.g. `'yo'`) — null until they pick one in Settings > Lyrics. Stored
  /// as an empty string internally (the underlying `settings` DAO only
  /// stores non-null strings) and normalized back to null here, so "no
  /// language chosen" and "language explicitly cleared back to None" are
  /// the same state. Phase 5 batch 2.
  Stream<String?> watchTranslationTargetLanguage() => watchQuery({'settings'}, () async {
    final value = await _dao.get(_translationTargetLanguageKey);
    return (value == null || value.isEmpty) ? null : value;
  });

  Future<void> setTranslationTargetLanguage(String? code) =>
      _dao.set(_translationTargetLanguageKey, code ?? '');

  static const _recommendationsEnabledKey = 'recommendations_enabled';

  /// Whether the local recommendation engine (Home's "Because you played X"
  /// section, the context menu's "More like this") is active. Defaults to
  /// true — unlike `resumeAfterInterruption`, this is a feature the user
  /// opts *out* of, not into, so an unset key reads as enabled.
  Stream<bool> watchRecommendationsEnabled() =>
      watchQuery({'settings'}, () async => (await _dao.get(_recommendationsEnabledKey)) != 'false');

  Future<void> setRecommendationsEnabled(bool value) =>
      _dao.set(_recommendationsEnabledKey, value.toString());
}
