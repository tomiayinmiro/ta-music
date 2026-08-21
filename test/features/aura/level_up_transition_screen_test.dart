import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ta_music/core/theme/theme_data.dart';
import 'package:ta_music/data/models/aura_level.dart';
import 'package:ta_music/features/aura/screens/level_up_transition_screen.dart';

/// Guards the bug found by hand on-device: "Atmosphere" wrapped mid-word
/// ("Atmosphe" / "re") because `displayLarge` (48px) didn't fit the glass
/// panel at every level name's length — fixed with a `FittedBox`. Runs every
/// level name through the real app theme so a regression on any of the 8
/// (not just the one that broke first) fails a `RenderFlex overflowed`
/// assertion here instead of on a real phone.
///
/// Uses a bounded `pump()` rather than `pumpAndSettle()` — the badge's float
/// and ring-spin effects repeat forever (`onPlay: (c) => c.repeat(...)`), so
/// `pumpAndSettle` would never converge, same reason as `widget_test.dart`.
void main() {
  for (final level in AuraLevel.values) {
    testWidgets('renders ${level.displayName} without overflowing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.dark, home: LevelUpTransitionScreen(level: level)),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(tester.takeException(), isNull);
      expect(find.text(level.displayName), findsOneWidget);
    });
  }
}
