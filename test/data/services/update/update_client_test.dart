import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ta_music/data/services/update/update_client.dart';

class _MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> _response(Map<String, dynamic> data) {
  return Response<Map<String, dynamic>>(requestOptions: RequestOptions(path: ''), statusCode: 200, data: data);
}

const _validJson = {
  'latest_version': '1.0.1',
  'minimum_supported_version': '1.0.0',
  'release_date': '2026-09-15',
  'download_url_android': 'https://github.com/tomiayinmiro/ta-music/releases/latest',
  'download_url_windows': 'https://github.com/tomiayinmiro/ta-music/releases/latest',
  'release_notes': 'Initial public release.',
};

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  late _MockDio dio;
  late UpdateClient client;

  void setUp() {
    dio = _MockDio();
    client = UpdateClient(dio);
  }

  test('a valid manifest is parsed and returned', () async {
    setUp();
    when(
      () => dio.get<Map<String, dynamic>>(any(), options: any(named: 'options')),
    ).thenAnswer((_) async => _response(_validJson));

    final result = await client.fetchLatest();

    expect(result, isNotNull);
    expect(result!.latestVersion, '1.0.1');
    expect(result.minimumSupportedVersion, '1.0.0');
    expect(result.releaseDate, '2026-09-15');
    expect(result.releaseNotes, 'Initial public release.');
  });

  test('a network failure (timeout, offline, DNS) is swallowed and returns null', () async {
    setUp();
    when(() => dio.get<Map<String, dynamic>>(any(), options: any(named: 'options'))).thenThrow(
      DioException(requestOptions: RequestOptions(path: ''), type: DioExceptionType.connectionTimeout),
    );

    final result = await client.fetchLatest();

    expect(result, isNull);
  });

  test('a malformed response (missing required field) returns null instead of throwing', () async {
    setUp();
    when(
      () => dio.get<Map<String, dynamic>>(any(), options: any(named: 'options')),
    ).thenAnswer((_) async => _response({'latest_version': '1.0.1'}));

    final result = await client.fetchLatest();

    expect(result, isNull);
  });

  test('an empty response body returns null instead of throwing', () async {
    setUp();
    when(
      () => dio.get<Map<String, dynamic>>(any(), options: any(named: 'options')),
    ).thenAnswer(
      (_) async =>
          Response<Map<String, dynamic>>(requestOptions: RequestOptions(path: ''), statusCode: 200, data: null),
    );

    final result = await client.fetchLatest();

    expect(result, isNull);
  });
}
