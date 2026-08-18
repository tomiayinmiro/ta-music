import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ta_music/app.dart';
import 'package:ta_music/data/providers/playback_providers.dart';
import 'package:ta_music/data/services/audio_service.dart';

import 'fakes/fake_playback_handler.dart';

void main() {
  testWidgets('App builds and shows the app name on the placeholder home screen',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [playbackServiceProvider.overrideWithValue(PlaybackService(FakePlaybackHandler()))],
        child: const App(),
      ),
    );
    // `pumpAndSettle` never converges here even on pre-Phase-3 code (some
    // widget keeps scheduling frames indefinitely, predating this change) —
    // a bounded pump is used instead until that's root-caused separately.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(find.text('TA MUSIC'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
