import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ta_music/data/models/feedback_type.dart';
import 'package:ta_music/data/providers/network_providers.dart';
import 'package:ta_music/data/providers/update_providers.dart';
import 'package:ta_music/data/services/feedback/feedback_client.dart';
import 'package:ta_music/features/feedback/widgets/feedback_form.dart';

class _MockFeedbackClient extends Mock implements FeedbackClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(FeedbackType.bugReport);
  });

  late _MockFeedbackClient client;

  Widget harness() {
    return ProviderScope(
      overrides: [
        feedbackClientProvider.overrideWithValue(client),
        // FeedbackForm reads the installed version off this to send with
        // the report — PackageInfo.fromPlatform() has no real platform
        // channel to answer it in a widget test, so it's overridden with a
        // fixed value rather than left to hang.
        packageInfoProvider.overrideWith(
          (ref) async => PackageInfo(
            appName: 'TA MUSIC',
            packageName: 'com.tamusic.app.ta_music',
            version: '1.0.0',
            buildNumber: '1',
          ),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: FeedbackForm())),
    );
  }

  Future<void> fillValidForm(WidgetTester tester) async {
    await tester.tap(find.byType(DropdownButtonFormField<FeedbackType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bug report').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Subject'), 'Crash on skip');
    await tester.enterText(
      find.widgetWithText(TextField, 'Message'),
      'The app crashes when I skip repeatedly.',
    );
  }

  setUp(() {
    client = _MockFeedbackClient();
  });

  testWidgets('tapping Submit with every field empty rejects the submission with field errors', (
    tester,
  ) async {
    await tester.pumpWidget(harness());

    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a feedback type.'), findsOneWidget);
    expect(find.text('Subject is required.'), findsOneWidget);
    expect(find.text('Message is required.'), findsOneWidget);
    verifyNever(
      () => client.submit(
        type: any(named: 'type'),
        subject: any(named: 'subject'),
        message: any(named: 'message'),
        platform: any(named: 'platform'),
        appVersion: any(named: 'appVersion'),
        email: any(named: 'email'),
      ),
    );
  });

  testWidgets('a successful submission shows the thank-you message and clears the form', (
    tester,
  ) async {
    when(
      () => client.submit(
        type: any(named: 'type'),
        subject: any(named: 'subject'),
        message: any(named: 'message'),
        platform: any(named: 'platform'),
        appVersion: any(named: 'appVersion'),
        email: any(named: 'email'),
      ),
    ).thenAnswer((_) async => const FeedbackSubmitSuccess());

    await tester.pumpWidget(harness());
    await fillValidForm(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Thank you! Your feedback has been sent.'), findsOneWidget);
    final subjectField = tester.widget<TextField>(find.widgetWithText(TextField, 'Subject'));
    expect(subjectField.controller!.text, isEmpty);
    final messageField = tester.widget<TextField>(find.widgetWithText(TextField, 'Message'));
    expect(messageField.controller!.text, isEmpty);
  });

  testWidgets(
    'a failed submission shows the error message with a Retry button and keeps the typed data',
    (tester) async {
      when(
        () => client.submit(
          type: any(named: 'type'),
          subject: any(named: 'subject'),
          message: any(named: 'message'),
          platform: any(named: 'platform'),
          appVersion: any(named: 'appVersion'),
          email: any(named: 'email'),
        ),
      ).thenAnswer(
        (_) async => const FeedbackSubmitFailure(
          'Something went wrong. Please check your internet connection and try again.',
        ),
      );

      await tester.pumpWidget(harness());
      await fillValidForm(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Something went wrong. Please check your internet connection and try again.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);

      final subjectField = tester.widget<TextField>(find.widgetWithText(TextField, 'Subject'));
      expect(subjectField.controller!.text, 'Crash on skip');
      final messageField = tester.widget<TextField>(find.widgetWithText(TextField, 'Message'));
      expect(messageField.controller!.text, 'The app crashes when I skip repeatedly.');

      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pump();
      await tester.pump();

      verify(
        () => client.submit(
          type: any(named: 'type'),
          subject: any(named: 'subject'),
          message: any(named: 'message'),
          platform: any(named: 'platform'),
          appVersion: any(named: 'appVersion'),
          email: any(named: 'email'),
        ),
      ).called(2);
    },
  );
}
