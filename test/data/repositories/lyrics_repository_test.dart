import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ta_music/data/database/daos/lyrics_cache_dao.dart';
import 'package:ta_music/data/database/database.dart';
import 'package:ta_music/data/repositories/lyrics_repository.dart';
import 'package:ta_music/data/services/lyrics/lrclib_client.dart';
import 'package:ta_music/data/services/lyrics/local_lrc_file_reader.dart';

class _MockDio extends Mock implements Dio {}

class _MockLrclibClient extends Mock implements LrclibClient {}

class _MockLocalLrcFileReader extends Mock implements LocalLrcFileReader {}

Response<Map<String, dynamic>> _ovhSuccess(String lyrics) {
  return Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: ''),
    statusCode: 200,
    data: {'lyrics': lyrics},
  );
}

DioException _ovhErrorWithStatus(int statusCode) {
  final requestOptions = RequestOptions(path: '');
  return DioException(
    requestOptions: requestOptions,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: requestOptions, statusCode: statusCode),
  );
}

const _lrclibSyncedLrc = '[00:01.00]First line\n[00:05.00]Second line';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    AppDatabase.debugDatabasePath = inMemoryDatabasePath;
    registerFallbackValue(Uri());
    registerFallbackValue(Options());
    registerFallbackValue(CancelToken());
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  late _MockDio dio;
  late _MockLrclibClient lrclibClient;
  late _MockLocalLrcFileReader localLrcFileReader;
  late LyricsCacheDao cacheDao;
  late LyricsRepository repo;

  // Neither LRCLIB nor lyrics.ovh nor the local file finds anything, by
  // default — individual tests override just the layer(s) they care about.
  Future<void> setUp() async {
    dio = _MockDio();
    lrclibClient = _MockLrclibClient();
    localLrcFileReader = _MockLocalLrcFileReader();
    cacheDao = LyricsCacheDao(await AppDatabase.instance);
    repo = LyricsRepository(
      dio: dio,
      cacheDao: cacheDao,
      lrclibClient: lrclibClient,
      localLrcFileReader: localLrcFileReader,
    );

    when(
      () => lrclibClient.get(
        trackName: any(named: 'trackName'),
        artistName: any(named: 'artistName'),
        albumName: any(named: 'albumName'),
        duration: any(named: 'duration'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => lrclibClient.search(
        trackName: any(named: 'trackName'),
        artistName: any(named: 'artistName'),
        duration: any(named: 'duration'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => null);
    when(() => dio.getUri<Map<String, dynamic>>(any(), options: any(named: 'options')))
        .thenThrow(_ovhErrorWithStatus(404));
    when(() => localLrcFileReader.read(any())).thenAnswer((_) async => null);
  }

  test('missing artist or title never calls any layer', () async {
    await setUp();

    expect(await repo.getLyrics(artist: null, title: 'A Song'), isA<LyricsMissingMetadata>());
    expect(await repo.getLyrics(artist: 'An Artist', title: ''), isA<LyricsMissingMetadata>());
    verifyNever(
      () => lrclibClient.get(
        trackName: any(named: 'trackName'),
        artistName: any(named: 'artistName'),
        albumName: any(named: 'albumName'),
        duration: any(named: 'duration'),
        cancelToken: any(named: 'cancelToken'),
      ),
    );
  });

  test('layer 1 (LRCLIB) hit with synced lyrics wins outright', () async {
    await setUp();
    when(
      () => lrclibClient.get(
        trackName: any(named: 'trackName'),
        artistName: any(named: 'artistName'),
        albumName: any(named: 'albumName'),
        duration: any(named: 'duration'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => const LrclibTrack(syncedLyrics: _lrclibSyncedLrc));

    final result = await repo.getLyrics(artist: 'Wizkid', title: 'Essence');

    expect(result, isA<LyricsFound>());
    final found = result as LyricsFound;
    expect(found.isSynced, isTrue);
    expect(found.source, 'lrclib');
    expect(found.lines.map((l) => l.text), ['First line', 'Second line']);
    verifyNever(() => dio.getUri<Map<String, dynamic>>(any(), options: any(named: 'options')));

    final cached = await cacheDao.find('wizkid', 'essence');
    expect(cached!['source'], 'lrclib');
    expect(cached['has_synced_timing'], 1);
  });

  test('LRCLIB falls back from get (404-equivalent null) to search', () async {
    await setUp();
    when(
      () => lrclibClient.search(
        trackName: any(named: 'trackName'),
        artistName: any(named: 'artistName'),
        duration: any(named: 'duration'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => const LrclibTrack(plainLyrics: 'Found via search'));

    final result = await repo.getLyrics(artist: 'Some Artist', title: 'Some Song');

    expect(result, isA<LyricsFound>());
    expect((result as LyricsFound).source, 'lrclib');
    expect(result.isSynced, isFalse);
  });

  test('layer 2 (lyrics.ovh) is used only when LRCLIB has nothing', () async {
    await setUp();
    when(() => dio.getUri<Map<String, dynamic>>(any(), options: any(named: 'options')))
        .thenAnswer((_) async => _ovhSuccess('Ovh line one\nOvh line two'));

    final result = await repo.getLyrics(artist: 'New Artist', title: 'New Song');

    expect(result, isA<LyricsFound>());
    final found = result as LyricsFound;
    expect(found.source, 'lyrics.ovh');
    expect(found.isSynced, isFalse);
    expect(found.lines.map((l) => l.text), ['Ovh line one', 'Ovh line two']);
  });

  test('layer 3 (local .lrc) is used only when both APIs have nothing', () async {
    await setUp();
    when(
      () => localLrcFileReader.read(any()),
    ).thenAnswer((_) async => _lrclibSyncedLrc);

    final result = await repo.getLyrics(
      artist: 'Nobody',
      title: 'Obscure Track',
      audioFilePath: '/Music/Nobody/Obscure Track.mp3',
    );

    expect(result, isA<LyricsFound>());
    final found = result as LyricsFound;
    expect(found.source, 'local_lrc');
    expect(found.isSynced, isTrue);
  });

  test('all 3 layers missing caches "none" and reports not-found', () async {
    await setUp();

    final result = await repo.getLyrics(artist: 'Nobody', title: 'No Lyrics Here');

    expect(result, isA<LyricsNotFound>());
    final cached = await cacheDao.find('nobody', 'no lyrics here');
    expect(cached!['source'], 'none');
  });

  test('a cached "none" within the 7-day TTL is reused without calling any layer', () async {
    await setUp();
    final fixedNow = DateTime(2026, 8, 22);
    await cacheDao.upsert(
      artistKey: 'nobody',
      titleKey: 'no lyrics here',
      source: 'none',
      hasSyncedTiming: false,
      fetchedAt: fixedNow.subtract(const Duration(days: 3)),
    );

    final result = await repo.getLyrics(
      artist: 'Nobody',
      title: 'No Lyrics Here',
      now: () => fixedNow,
    );

    expect(result, isA<LyricsNotFound>());
    verifyNever(
      () => lrclibClient.get(
        trackName: any(named: 'trackName'),
        artistName: any(named: 'artistName'),
        albumName: any(named: 'albumName'),
        duration: any(named: 'duration'),
        cancelToken: any(named: 'cancelToken'),
      ),
    );
  });

  test('a cached "none" past the 7-day TTL is re-fetched', () async {
    await setUp();
    final fixedNow = DateTime(2026, 8, 22);
    await cacheDao.upsert(
      artistKey: 'nobody',
      titleKey: 'no lyrics here',
      source: 'none',
      hasSyncedTiming: false,
      fetchedAt: fixedNow.subtract(const Duration(days: 8)),
    );
    when(
      () => lrclibClient.get(
        trackName: any(named: 'trackName'),
        artistName: any(named: 'artistName'),
        albumName: any(named: 'albumName'),
        duration: any(named: 'duration'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => const LrclibTrack(plainLyrics: 'Found it now'));

    final result = await repo.getLyrics(
      artist: 'Nobody',
      title: 'No Lyrics Here',
      now: () => fixedNow,
    );

    expect(result, isA<LyricsFound>());
  });

  test('a hit (any source) is cached indefinitely and reused on the next lookup', () async {
    await setUp();
    when(
      () => lrclibClient.get(
        trackName: any(named: 'trackName'),
        artistName: any(named: 'artistName'),
        albumName: any(named: 'albumName'),
        duration: any(named: 'duration'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => const LrclibTrack(syncedLyrics: _lrclibSyncedLrc));

    await repo.getLyrics(artist: 'Wizkid', title: 'Essence');
    final second = await repo.getLyrics(artist: 'Wizkid', title: 'Essence');

    expect(second, isA<LyricsFound>());
    verify(
      () => lrclibClient.get(
        trackName: any(named: 'trackName'),
        artistName: any(named: 'artistName'),
        albumName: any(named: 'albumName'),
        duration: any(named: 'duration'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).called(1);
  });

  test(
    'a network error on one layer still lets a later layer succeed',
    () async {
      await setUp();
      when(
        () => lrclibClient.get(
          trackName: any(named: 'trackName'),
          artistName: any(named: 'artistName'),
          albumName: any(named: 'albumName'),
          duration: any(named: 'duration'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenThrow(
        DioException(requestOptions: RequestOptions(path: ''), type: DioExceptionType.connectionError),
      );
      when(() => dio.getUri<Map<String, dynamic>>(any(), options: any(named: 'options')))
          .thenAnswer((_) async => _ovhSuccess('Fallback found it'));

      final result = await repo.getLyrics(artist: 'Someone', title: 'Some Song');

      expect(result, isA<LyricsFound>());
      expect((result as LyricsFound).source, 'lyrics.ovh');
    },
  );

  test('every layer erroring reports a fetch error and caches nothing', () async {
    await setUp();
    when(
      () => lrclibClient.get(
        trackName: any(named: 'trackName'),
        artistName: any(named: 'artistName'),
        albumName: any(named: 'albumName'),
        duration: any(named: 'duration'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenThrow(
      DioException(requestOptions: RequestOptions(path: ''), type: DioExceptionType.connectionError),
    );
    when(() => dio.getUri<Map<String, dynamic>>(any(), options: any(named: 'options')))
        .thenThrow(_ovhErrorWithStatus(429));

    final result = await repo.getLyrics(artist: 'Someone', title: 'Some Song');

    expect(result, isA<LyricsFetchError>());
    expect((result as LyricsFetchError).isRateLimited, isTrue);
    expect(await cacheDao.find('someone', 'some song'), isNull);
  });
}
