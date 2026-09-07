import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ta_music/data/models/feedback_type.dart';
import 'package:ta_music/data/services/feedback/feedback_client.dart';

class _MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> _response(Map<String, dynamic> data, {int statusCode = 200}) {
  return Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: ''),
    statusCode: statusCode,
    data: data,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  late _MockDio dio;
  late FeedbackClient client;

  void setUp() {
    dio = _MockDio();
    client = FeedbackClient(dio);
  }

  test('a successful submit posts the exact expected body to the Web3Forms endpoint', () async {
    setUp();
    when(
      () => dio.post<Map<String, dynamic>>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => _response({'success': true}));

    final result = await client.submit(
      type: FeedbackType.bugReport,
      subject: 'Crash on skip',
      message: 'The app crashes when I skip repeatedly.',
      email: 'user@example.com',
      appVersion: '1.0.0',
      platform: 'Android',
    );

    expect(result, isA<FeedbackSubmitSuccess>());

    final captured = verify(
      () => dio.post<Map<String, dynamic>>(
        captureAny(),
        data: captureAny(named: 'data'),
        options: captureAny(named: 'options'),
      ),
    ).captured;

    expect(captured[0], 'https://api.web3forms.com/submit');
    final body = captured[1] as Map<String, dynamic>;
    expect(body, {
      'access_key': '5a77dac4-0a68-4983-87cc-59288081ad66',
      'type': 'Bug report',
      'subject': 'Crash on skip',
      'message': 'The app crashes when I skip repeatedly.',
      'app_version': '1.0.0',
      'platform': 'Android',
      'email': 'user@example.com',
    });
    final options = captured[2] as Options;
    expect(options.headers?['Content-Type'], 'application/json');
  });

  test('a blank email is omitted from the body entirely, not sent as an empty string', () async {
    setUp();
    when(
      () => dio.post<Map<String, dynamic>>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => _response({'success': true}));

    await client.submit(
      type: FeedbackType.featureRequest,
      subject: 'Add dark mode toggle',
      message: 'Would love a manual light/dark override.',
      email: '',
      appVersion: '1.0.0',
      platform: 'Windows',
    );

    final body = verify(
      () => dio.post<Map<String, dynamic>>(
        any(),
        data: captureAny(named: 'data'),
        options: any(named: 'options'),
      ),
    ).captured.single as Map<String, dynamic>;
    expect(body.containsKey('email'), isFalse);
    expect(body['type'], 'Feature request');
  });

  test('Web3Forms reporting success:false surfaces its own message as a failure', () async {
    setUp();
    when(
      () => dio.post<Map<String, dynamic>>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => _response({'success': false, 'message': 'Invalid access key.'}));

    final result = await client.submit(
      type: FeedbackType.generalComment,
      subject: 'Hi',
      message: 'Just saying hello.',
      appVersion: '1.0.0',
      platform: 'Android',
    );

    expect(result, isA<FeedbackSubmitFailure>());
    expect((result as FeedbackSubmitFailure).message, 'Invalid access key.');
  });

  test('a network/connection DioException maps to the connectivity-specific message', () async {
    setUp();
    when(
      () => dio.post<Map<String, dynamic>>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenThrow(
      DioException(requestOptions: RequestOptions(path: ''), type: DioExceptionType.connectionError),
    );

    final result = await client.submit(
      type: FeedbackType.bugReport,
      subject: 'Subject',
      message: 'Message',
      appVersion: '1.0.0',
      platform: 'Android',
    );

    expect(result, isA<FeedbackSubmitFailure>());
    expect(
      (result as FeedbackSubmitFailure).message,
      'Something went wrong. Please check your internet connection and try again.',
    );
  });
}
