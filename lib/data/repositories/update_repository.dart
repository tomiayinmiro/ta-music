import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/update/installer_detector.dart';
import '../services/update/update_client.dart';
import '../services/update/update_decision.dart';
import 'settings_repository.dart';

/// What the update-check flow found, for callers that need to distinguish
/// more than just "show a dialog or don't" — the Settings screen's manual
/// "Check for updates" button reports each of these differently.
sealed class UpdateCheckOutcome {
  const UpdateCheckOutcome();
}

/// A newer version exists and should be shown to the user.
class UpdateAvailableOutcome extends UpdateCheckOutcome {
  const UpdateAvailableOutcome({
    required this.manifest,
    required this.installedVersion,
    required this.mandatory,
  });

  final UpdateManifest manifest;
  final String installedVersion;

  /// True when the installed version is below `minimum_supported_version`
  /// — the caller must show the non-dismissible variant of the dialog.
  final bool mandatory;
}

/// Installed version is already the latest.
class UpToDateOutcome extends UpdateCheckOutcome {
  const UpToDateOutcome();
}

/// The manifest couldn't be fetched or parsed (offline, timeout, GitHub
/// Pages down, malformed JSON). The on-launch path treats this identically
/// to [UpToDateOutcome] (show nothing); the manual check button surfaces it
/// differently so the user knows the button didn't silently no-op.
class UpdateCheckFailedOutcome extends UpdateCheckOutcome {
  const UpdateCheckFailedOutcome();
}

/// Orchestrates the update-notification flow: installer-source gating,
/// fetching the remote manifest, comparing versions, and persisting
/// dismissal/check-timestamp state. Kept thin — all the actual decision
/// logic lives in the pure, directly-unit-tested `update_decision.dart` and
/// `installer_detector.dart` functions; this class only wires them to the
/// real `PackageInfo`/`SettingsRepository`/`UpdateClient`.
class UpdateRepository {
  UpdateRepository({required this._client, required this._settingsRepository});

  final UpdateClient _client;
  final SettingsRepository _settingsRepository;
  final _logger = Logger();

  /// The silent on-launch check. Returns `null` whenever there is nothing
  /// to show — up to date, already dismissed for this exact version, the
  /// fetch failed, or this install should never be checked (Play Store) —
  /// so `app.dart` only ever has to handle "show this dialog" or "do
  /// nothing", never a tri-state result.
  Future<UpdateAvailableOutcome?> checkOnLaunch({
    required PackageInfo packageInfo,
    required bool isAndroid,
    required bool isWindows,
  }) async {
    if (!shouldCheckForUpdates(
      isAndroid: isAndroid,
      isWindows: isWindows,
      installerStore: packageInfo.installerStore,
    )) {
      _logger.i('[update_check] skipped — installer=${packageInfo.installerStore}');
      return null;
    }
    final outcome = await _check(packageInfo: packageInfo, ignoreDismissal: false);
    return outcome is UpdateAvailableOutcome ? outcome : null;
  }

  /// The Settings > About "Check for updates" button. Ignores prior
  /// dismissal — a user who explicitly asks should always see the true
  /// current state, not a version they dismissed weeks ago. Installer-source
  /// gating is the caller's job here (Settings hides the button entirely for
  /// Play Store installs rather than have it silently do nothing on tap).
  Future<UpdateCheckOutcome> checkManually({required PackageInfo packageInfo}) =>
      _check(packageInfo: packageInfo, ignoreDismissal: true);

  /// Records that the user tapped "Later" on [version] so [checkOnLaunch]
  /// won't show it again — a newer version published later still shows.
  Future<void> dismiss(String version) => _settingsRepository.setLastDismissedUpdateVersion(version);

  Future<UpdateCheckOutcome> _check({
    required PackageInfo packageInfo,
    required bool ignoreDismissal,
  }) async {
    final manifest = await _client.fetchLatest();
    if (manifest == null) return const UpdateCheckFailedOutcome();
    await _settingsRepository.setLastUpdateCheckAt(DateTime.now());

    final lastDismissed = ignoreDismissal
        ? null
        : await _settingsRepository.getLastDismissedUpdateVersion();
    final action = decideUpdateAction(
      installedVersion: packageInfo.version,
      latestVersion: manifest.latestVersion,
      minimumSupportedVersion: manifest.minimumSupportedVersion,
      lastDismissedVersion: lastDismissed,
    );

    return switch (action) {
      UpdateAction.none => const UpToDateOutcome(),
      UpdateAction.mandatory => UpdateAvailableOutcome(
        manifest: manifest,
        installedVersion: packageInfo.version,
        mandatory: true,
      ),
      UpdateAction.dismissible => UpdateAvailableOutcome(
        manifest: manifest,
        installedVersion: packageInfo.version,
        mandatory: false,
      ),
    };
  }
}
