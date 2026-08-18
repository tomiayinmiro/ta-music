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
}
