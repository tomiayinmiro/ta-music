import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ta_music/data/services/lyrics/lrclib_client.dart';

class _MockDio extends Mock implements Dio {}

DioException _notFound() {
  final requestOptions = RequestOptions(path: '');
  return DioException(
    requestOptions: requestOptions,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: requestOptions, statusCode: 404),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(Options());
  });

  late _MockDio dio;
  late LrclibClient client;

  setUp(() {
    dio = _MockDio();
    client = LrclibClient(dio);
  });

  group('get', () {
    test('returns a track on success', () async {
      when(
        () => dio.getUri<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: {'plainLyrics': 'Plain text', 'syncedLyrics': '[00:01.00]Synced text'},
        ),
      );

      final track = await client.get(trackName: 'Essence', artistName: 'Wizkid');

      expect(track!.plainLyrics, 'Plain text');
      expect(track.syncedLyrics, '[00:01.00]Synced text');
    });

    test('returns null on a 404 rather than throwing', () async {
      when(
        () => dio.getUri<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenThrow(_notFound());

      expect(await client.get(trackName: 'Unknown', artistName: 'Unknown'), isNull);
    });

    test('rethrows a non-404 error for the repository to classify', () async {
      when(
        () => dio.getUri<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenThrow(
        DioException(requestOptions: RequestOptions(path: ''), type: DioExceptionType.connectionError),
      );

      expect(
        () => client.get(trackName: 'X', artistName: 'Y'),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('search', () {
    test('picks the candidate with the closest duration', () async {
      when(
        () => dio.getUri<List<dynamic>>(
          any(),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => Response<List<dynamic>>(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: [
            {'plainLyrics': 'Too short', 'duration': 120},
            {'plainLyrics': 'Just right', 'duration': 200},
            {'plainLyrics': 'Too long', 'duration': 400},
          ],
        ),
      );

      final track = await client.search(
        trackName: 'Song',
        artistName: 'Artist',
        duration: const Duration(seconds: 205),
      );

      expect(track!.plainLyrics, 'Just right');
    });

    test('skips candidates with no lyrics at all (instrumental entries)', () async {
      when(
        () => dio.getUri<List<dynamic>>(
          any(),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => Response<List<dynamic>>(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: [
            {'plainLyrics': null, 'syncedLyrics': null, 'duration': 200},
            {'plainLyrics': 'Has lyrics', 'duration': 400},
          ],
        ),
      );

      final track = await client.search(
        trackName: 'Song',
        artistName: 'Artist',
        duration: const Duration(seconds: 200),
      );

      expect(track!.plainLyrics, 'Has lyrics');
    });

    test('returns null when no candidate has usable lyrics', () async {
      when(
        () => dio.getUri<List<dynamic>>(
          any(),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => Response<List<dynamic>>(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: <dynamic>[],
        ),
      );

      expect(
        await client.search(trackName: 'Song', artistName: 'Artist'),
        isNull,
      );
    });
  });
}
