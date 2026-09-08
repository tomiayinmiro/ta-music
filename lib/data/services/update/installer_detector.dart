/// Whether the update-check flow should run at all, given the platform and
/// (on Android) the installer package that put this APK on the device.
///
/// Pure so it's unit-testable without touching `package_info_plus`'s actual
/// platform channel — the caller reads `PackageInfo.installerStore` and
/// `Platform.isAndroid`/`Platform.isWindows` and passes them in here.
///
/// - Android, installed via Play Store (`installerStore ==
///   'com.android.vending'`): Google handles updates — never check.
/// - Android, any other installer (sideloaded, ADB, a file manager, or
///   `installerStore` null): direct-APK install — check.
/// - Windows: always check — there's no Play-Store-equivalent concept for
///   this app's distribution there.
/// - Any other platform (not currently shipped, but the app could run in a
///   debug/test host): don't check.
bool shouldCheckForUpdates({
  required bool isAndroid,
  required bool isWindows,
  required String? installerStore,
}) {
  if (isAndroid) return installerStore != 'com.android.vending';
  return isWindows;
}
