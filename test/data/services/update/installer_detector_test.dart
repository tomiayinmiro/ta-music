import 'package:flutter_test/flutter_test.dart';
import 'package:ta_music/data/services/update/installer_detector.dart';

void main() {
  group('shouldCheckForUpdates', () {
    test('Android installed via Play Store -> never check', () {
      expect(
        shouldCheckForUpdates(isAndroid: true, isWindows: false, installerStore: 'com.android.vending'),
        isFalse,
      );
    });

    test('Android sideloaded (a non-Play-Store installer) -> check', () {
      expect(
        shouldCheckForUpdates(isAndroid: true, isWindows: false, installerStore: 'com.google.android.packageinstaller'),
        isTrue,
      );
    });

    test('Android with a null installer (ADB install, or unknown) -> check', () {
      expect(
        shouldCheckForUpdates(isAndroid: true, isWindows: false, installerStore: null),
        isTrue,
      );
    });

    test('Windows -> always check regardless of installerStore', () {
      expect(shouldCheckForUpdates(isAndroid: false, isWindows: true, installerStore: null), isTrue);
    });

    test('neither Android nor Windows -> do not check', () {
      expect(shouldCheckForUpdates(isAndroid: false, isWindows: false, installerStore: null), isFalse);
    });
  });
}
