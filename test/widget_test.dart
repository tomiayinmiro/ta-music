import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ta_music/app.dart';

void main() {
  testWidgets('App builds and shows the app name on the placeholder home screen',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
    await tester.pumpAndSettle();

    expect(find.text('TA MUSIC'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
