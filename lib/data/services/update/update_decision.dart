import 'semver.dart';

/// What the update-check flow should do once a remote version manifest has
/// been fetched and compared against the installed version.
enum UpdateAction {
  /// Nothing to show — installed version is current, or the newer version
  /// was already dismissed in an earlier session.
  none,

  /// Installed version is below `minimum_supported_version` — show the
  /// non-dismissible mandatory-update dialog. Takes priority over
  /// [dismissible]: an installed version can never be both below the
  /// minimum and merely "not latest".
  mandatory,

  /// A newer version exists and installed is still supported — show the
  /// dismissible "Update Available" dialog.
  dismissible,
}

/// Pure decision logic for "what should the update dialog do", kept
/// DB/network-free like `relative_queue_index.dart` and `skip_detection.dart`
/// elsewhere in this codebase, so it's unit-tested directly against plain
/// values rather than through a repository + mocks.
UpdateAction decideUpdateAction({
  required String installedVersion,
  required String latestVersion,
  required String minimumSupportedVersion,
  required String? lastDismissedVersion,
}) {
  if (isSemverLessThan(installedVersion, minimumSupportedVersion)) {
    return UpdateAction.mandatory;
  }
  if (!isSemverLessThan(installedVersion, latestVersion)) {
    return UpdateAction.none;
  }
  if (lastDismissedVersion == latestVersion) {
    return UpdateAction.none;
  }
  return UpdateAction.dismissible;
}
