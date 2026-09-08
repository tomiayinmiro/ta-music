import 'package:flutter_test/flutter_test.dart';
import 'package:ta_music/data/services/update/update_decision.dart';

void main() {
  group('decideUpdateAction', () {
    test('installed == latest -> none', () {
      final action = decideUpdateAction(
        installedVersion: '1.0.0',
        latestVersion: '1.0.0',
        minimumSupportedVersion: '1.0.0',
        lastDismissedVersion: null,
      );
      expect(action, UpdateAction.none);
    });

    test('installed > latest (shouldn\'t happen in practice, but must not misfire) -> none', () {
      final action = decideUpdateAction(
        installedVersion: '1.1.0',
        latestVersion: '1.0.0',
        minimumSupportedVersion: '1.0.0',
        lastDismissedVersion: null,
      );
      expect(action, UpdateAction.none);
    });

    test('installed < latest, never dismissed -> dismissible', () {
      final action = decideUpdateAction(
        installedVersion: '1.0.0',
        latestVersion: '1.0.1',
        minimumSupportedVersion: '1.0.0',
        lastDismissedVersion: null,
      );
      expect(action, UpdateAction.dismissible);
    });

    test('installed < latest, already dismissed for this exact latest version -> none', () {
      final action = decideUpdateAction(
        installedVersion: '1.0.0',
        latestVersion: '1.0.1',
        minimumSupportedVersion: '1.0.0',
        lastDismissedVersion: '1.0.1',
      );
      expect(action, UpdateAction.none);
    });

    test('installed < latest, dismissed a DIFFERENT (older) version -> dismissible again', () {
      // A newer version than the one dismissed was published — must show.
      final action = decideUpdateAction(
        installedVersion: '1.0.0',
        latestVersion: '1.0.2',
        minimumSupportedVersion: '1.0.0',
        lastDismissedVersion: '1.0.1',
      );
      expect(action, UpdateAction.dismissible);
    });

    test('installed below minimum_supported -> mandatory, regardless of dismissal', () {
      final action = decideUpdateAction(
        installedVersion: '0.9.0',
        latestVersion: '1.0.1',
        minimumSupportedVersion: '1.0.0',
        lastDismissedVersion: '1.0.1',
      );
      expect(action, UpdateAction.mandatory);
    });

    test('installed exactly at minimum_supported -> not mandatory', () {
      final action = decideUpdateAction(
        installedVersion: '1.0.0',
        latestVersion: '1.0.0',
        minimumSupportedVersion: '1.0.0',
        lastDismissedVersion: null,
      );
      expect(action, UpdateAction.none);
    });

    test('mandatory takes priority even when installed also equals latest '
        '(a manifest edited inconsistently should still protect the user)', () {
      final action = decideUpdateAction(
        installedVersion: '0.9.0',
        latestVersion: '0.9.0',
        minimumSupportedVersion: '1.0.0',
        lastDismissedVersion: null,
      );
      expect(action, UpdateAction.mandatory);
    });
  });
}
