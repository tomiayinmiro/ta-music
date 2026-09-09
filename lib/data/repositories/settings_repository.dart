import 'dart:convert';

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

  static const _eqEnabledKey = 'eq_enabled';

  /// Whether the Android equalizer effect is switched on. Defaults to false
  /// — `AndroidEqualizer` itself starts disabled (see `just_audio`'s
  /// `AudioEffect` doc), so an unset key matches the underlying effect's own
  /// default rather than silently diverging from it. Phase 6 batch 2.
  Stream<bool> watchEqualizerEnabled() =>
      watchQuery({'settings'}, () async => (await _dao.get(_eqEnabledKey)) == 'true');

  Future<void> setEqualizerEnabled(bool value) => _dao.set(_eqEnabledKey, value.toString());

  static const _eqBandGainsKey = 'eq_band_gains';

  /// The last-set gain (decibels) for each device equalizer band, in device
  /// band-index order — null if never set (fresh install, or the equalizer
  /// has never activated on this device yet). `AudioPlayerHandler` restores
  /// these onto the live `AndroidEqualizer` once its real band count is
  /// known; a stored list whose length no longer matches the device's
  /// current band count is ignored by the caller rather than applied
  /// mismatched.
  Future<List<double>?> getEqualizerBandGains() async {
    final raw = await _dao.get(_eqBandGainsKey);
    if (raw == null) return null;
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((e) => (e as num).toDouble()).toList();
  }

  Future<void> setEqualizerBandGains(List<double> gains) =>
      _dao.set(_eqBandGainsKey, jsonEncode(gains));

  static const _lastDismissedUpdateVersionKey = 'last_dismissed_update_version';

  /// The version string the user last tapped "Later" on in the update
  /// dialog — null if never dismissed, or if a newer version has since been
  /// published (only ever set to the exact version shown, so an older
  /// dismissal never suppresses a version the user hasn't seen yet).
  Future<String?> getLastDismissedUpdateVersion() async {
    final value = await _dao.get(_lastDismissedUpdateVersionKey);
    return (value == null || value.isEmpty) ? null : value;
  }

  Future<void> setLastDismissedUpdateVersion(String version) =>
      _dao.set(_lastDismissedUpdateVersionKey, version);

  static const _playbackSpeedKey = 'playback_speed';

  /// Global playback speed multiplier applied to every song — not per-song
  /// for v1, per CLAUDE.md's Settings-expansion decisions. Defaults to 1.0.
  Stream<double> watchPlaybackSpeed() => watchQuery({'settings'}, () async {
    final raw = await _dao.get(_playbackSpeedKey);
    return raw != null ? (double.tryParse(raw) ?? 1.0) : 1.0;
  });

  Future<void> setPlaybackSpeed(double speed) => _dao.set(_playbackSpeedKey, speed.toString());

  static const _lastUpdateCheckAtKey = 'last_update_check_at';

  /// When the update manifest was last successfully fetched, as an ISO-8601
  /// string — informational only (surfaced nowhere in the UI yet), kept for
  /// future diagnostics in the same spirit as the Phase 5 "Lyrics cache"
  /// debug screen.
  Future<DateTime?> getLastUpdateCheckAt() async {
    final value = await _dao.get(_lastUpdateCheckAtKey);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  Future<void> setLastUpdateCheckAt(DateTime timestamp) =>
      _dao.set(_lastUpdateCheckAtKey, timestamp.toIso8601String());
}
