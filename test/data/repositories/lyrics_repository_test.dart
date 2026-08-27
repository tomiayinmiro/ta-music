import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ta_music/data/database/daos/lyrics_cache_dao.dart';
import 'package:ta_music/data/database/database.dart';
import 'package:ta_music/data/models/song.dart';
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

Song _song({String? artist, String? title, String path = '/Music/song.mp3'}) {
  return Song(path: path, artist: artist, title: title, dateAdded: DateTime(2026, 1, 1));
}

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
    expect(found.isPossibleMismatch, isFalse);
    expect(found.lines.map((l) => l.text), ['First line', 'Second line']);
    verifyNever(() => dio.getUri<Map<String, dynamic>>(any(), options: any(named: 'options')));

    final cached = await cacheDao.find('wizkid', 'essence');
    expect(cached!['source'], 'lrclib');
    expect(cached['has_synced_timing'], 1);
    expect(cached['is_possible_mismatch'], 0);
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
    when(() => localLrcFileReader.read(any())).thenAnswer((_) async => _lrclibSyncedLrc);

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

  test('a network error on one layer still lets a later layer succeed', () async {
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
      DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionError,
      ),
    );
    when(() => dio.getUri<Map<String, dynamic>>(any(), options: any(named: 'options')))
        .thenAnswer((_) async => _ovhSuccess('Fallback found it'));

    final result = await repo.getLyrics(artist: 'Someone', title: 'Some Song');

    expect(result, isA<LyricsFound>());
    expect((result as LyricsFound).source, 'lyrics.ovh');
  });

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
      DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionError,
      ),
    );
    when(() => dio.getUri<Map<String, dynamic>>(any(), options: any(named: 'options')))
        .thenThrow(_ovhErrorWithStatus(429));

    final result = await repo.getLyrics(artist: 'Someone', title: 'Some Song');

    expect(result, isA<LyricsFetchError>());
    expect((result as LyricsFetchError).isRateLimited, isTrue);
    expect(await cacheDao.find('someone', 'some song'), isNull);
  });

  group('multi-attempt query cascade (feat./ft. tag detected)', () {
    test('stops at the first variant that hits — variant 1 succeeding is never flagged', () async {
      await setUp();
      when(
        () => lrclibClient.get(
          trackName: 'Olorun Agbaye (feat. Chandler Moore, OBA)',
          artistName: 'Nathaniel Bassey',
          albumName: any(named: 'albumName'),
          duration: any(named: 'duration'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => const LrclibTrack(plainLyrics: 'Variant 1 lyrics'));

      final result = await repo.getLyrics(
        artist: 'Nathaniel Bassey',
        title: 'Olorun Agbaye [Feat. Chandler Moore & OBA]',
      );

      expect(result, isA<LyricsFound>());
      final found = result as LyricsFound;
      expect(found.isPossibleMismatch, isFalse);
      expect(found.lines.map((l) => l.text), ['Variant 1 lyrics']);
      // The last-resort variant's exact args were never sent — confirms the
      // cascade actually stopped after variant 1 rather than trying all 4.
      verifyNever(
        () => lrclibClient.get(
          trackName: 'Olorun Agbaye',
          artistName: 'Nathaniel Bassey',
          albumName: any(named: 'albumName'),
          duration: any(named: 'duration'),
          cancelToken: any(named: 'cancelToken'),
        ),
      );
    });

    test(
      'only the last-resort primary-artist-only variant hitting is flagged as a possible mismatch',
      () async {
        await setUp();
        when(
          () => lrclibClient.get(
            trackName: 'Olorun Agbaye',
            artistName: 'Nathaniel Bassey',
            albumName: any(named: 'albumName'),
            duration: any(named: 'duration'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async => const LrclibTrack(plainLyrics: 'Last resort lyrics'));

        final result = await repo.getLyrics(
          artist: 'Nathaniel Bassey',
          title: 'Olorun Agbaye [Feat. Chandler Moore & OBA]',
        );

        expect(result, isA<LyricsFound>());
        final found = result as LyricsFound;
        expect(found.isPossibleMismatch, isTrue);

        final cached = await cacheDao.find(
          'nathaniel bassey',
          'olorun agbaye [feat. chandler moore & oba]',
        );
        expect(cached!['is_possible_mismatch'], 1);
      },
    );

    test(
      'the cached mismatch flag is reused on a later lookup without re-running the cascade',
      () async {
        await setUp();
        when(
          () => lrclibClient.get(
            trackName: 'Olorun Agbaye',
            artistName: 'Nathaniel Bassey',
            albumName: any(named: 'albumName'),
            duration: any(named: 'duration'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async => const LrclibTrack(plainLyrics: 'Last resort lyrics'));

        await repo.getLyrics(
          artist: 'Nathaniel Bassey',
          title: 'Olorun Agbaye [Feat. Chandler Moore & OBA]',
        );
        final second = await repo.getLyrics(
          artist: 'Nathaniel Bassey',
          title: 'Olorun Agbaye [Feat. Chandler Moore & OBA]',
        );

        expect((second as LyricsFound).isPossibleMismatch, isTrue);
        // Only ever called once — the second lookup was a pure cache hit.
        verify(
          () => lrclibClient.get(
            trackName: 'Olorun Agbaye',
            artistName: 'Nathaniel Bassey',
            albumName: any(named: 'albumName'),
            duration: any(named: 'duration'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).called(1);
      },
    );

    test(
      'a network error partway through the cascade stops LRCLIB and falls through to lyrics.ovh',
      () async {
        await setUp();
        var callCount = 0;
        when(
          () => lrclibClient.get(
            trackName: any(named: 'trackName'),
            artistName: any(named: 'artistName'),
            albumName: any(named: 'albumName'),
            duration: any(named: 'duration'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async {
          callCount++;
          throw DioException(
            requestOptions: RequestOptions(path: ''),
            type: DioExceptionType.connectionError,
          );
        });
        when(() => dio.getUri<Map<String, dynamic>>(any(), options: any(named: 'options')))
            .thenAnswer((_) async => _ovhSuccess('Fallback lyrics'));

        final result = await repo.getLyrics(
          artist: 'Nathaniel Bassey',
          title: 'Olorun Agbaye [Feat. Chandler Moore & OBA]',
        );

        expect(result, isA<LyricsFound>());
        expect((result as LyricsFound).source, 'lyrics.ovh');
        // The cascade aborted after the first variant's error rather than
        // retrying the remaining 3 against a server that's already failing.
        expect(callCount, 1);
      },
    );

    test('a feature tag on the artist field alone still triggers the cascade', () async {
      await setUp();
      when(
        () => lrclibClient.get(
          trackName: 'Na You',
          artistName: 'Dunsin Oyekan',
          albumName: any(named: 'albumName'),
          duration: any(named: 'duration'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => const LrclibTrack(plainLyrics: 'Last resort lyrics'));

      final result = await repo.getLyrics(
        artist: 'Dunsin Oyekan feat. Kim Burrell',
        title: 'Na You',
      );

      expect(result, isA<LyricsFound>());
      expect((result as LyricsFound).isPossibleMismatch, isTrue);
    });

    test(
      'no feature tag anywhere makes exactly one LRCLIB query, same as before this rework',
      () async {
        await setUp();
        when(
          () => lrclibClient.get(
            trackName: 'Essence',
            artistName: 'Wizkid',
            albumName: any(named: 'albumName'),
            duration: any(named: 'duration'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async => const LrclibTrack(plainLyrics: 'Found it'));

        await repo.getLyrics(artist: 'Wizkid', title: 'Essence');

        verify(
          () => lrclibClient.get(
            trackName: any(named: 'trackName'),
            artistName: any(named: 'artistName'),
            albumName: any(named: 'albumName'),
            duration: any(named: 'duration'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).called(1);
      },
    );
  });

  group('artist/duration verification against the LRCLIB response (matching-fix pass)', () {
    // Regression test for the reported bug: "Most High" by Dunsin Oyekan
    // has no feat. tag, so this is a single, always-non-last-resort variant
    // — before this pass, isPossibleMismatch could never be set true here
    // no matter what LRCLIB actually returned.
    test('a single-variant (no feat. tag) hit with a wrong returned artist is flagged, '
        'not just accepted because it was never the last-resort variant', () async {
      await setUp();
      when(
        () => lrclibClient.get(
          trackName: 'Most High',
          artistName: 'Dunsin Oyekan',
          albumName: any(named: 'albumName'),
          duration: any(named: 'duration'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => const LrclibTrack(
          plainLyrics: 'Wrong song lyrics',
          artistName: 'Nathaniel Bassey',
          durationSeconds: 390,
        ),
      );

      final result = await repo.getLyrics(
        artist: 'Dunsin Oyekan',
        title: 'Most High',
        duration: const Duration(seconds: 472),
      );

      expect(result, isA<LyricsFound>());
      expect((result as LyricsFound).isPossibleMismatch, isTrue);
    });

    test(
      'a matching returned artist and duration is NOT flagged, even off the sole variant',
      () async {
        await setUp();
        when(
          () => lrclibClient.get(
            trackName: 'Most High',
            artistName: 'Dunsin Oyekan',
            albumName: any(named: 'albumName'),
            duration: any(named: 'duration'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer(
          (_) async => const LrclibTrack(
            plainLyrics: 'Correct song lyrics',
            artistName: 'Dunsin Oyekan',
            durationSeconds: 472,
          ),
        );

        final result = await repo.getLyrics(
          artist: 'Dunsin Oyekan',
          title: 'Most High',
          duration: const Duration(seconds: 472),
        );

        expect(result, isA<LyricsFound>());
        expect((result as LyricsFound).isPossibleMismatch, isFalse);
      },
    );

    test('a returned duration exactly at the 10s tolerance boundary is not flagged', () async {
      await setUp();
      when(
        () => lrclibClient.get(
          trackName: any(named: 'trackName'),
          artistName: any(named: 'artistName'),
          albumName: any(named: 'albumName'),
          duration: any(named: 'duration'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => const LrclibTrack(
          plainLyrics: 'Lyrics',
          artistName: 'Some Artist',
          durationSeconds: 310,
        ),
      );

      final result = await repo.getLyrics(
        artist: 'Some Artist',
        title: 'A Song',
        duration: const Duration(seconds: 300),
      );

      expect((result as LyricsFound).isPossibleMismatch, isFalse);
    });

    test('a returned duration 1 second past the tolerance is flagged', () async {
      await setUp();
      when(
        () => lrclibClient.get(
          trackName: any(named: 'trackName'),
          artistName: any(named: 'artistName'),
          albumName: any(named: 'albumName'),
          duration: any(named: 'duration'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => const LrclibTrack(
          plainLyrics: 'Lyrics',
          artistName: 'Some Artist',
          durationSeconds: 311,
        ),
      );

      final result = await repo.getLyrics(
        artist: 'Some Artist',
        title: 'A Song',
        duration: const Duration(seconds: 300),
      );

      expect((result as LyricsFound).isPossibleMismatch, isTrue);
    });

    test('no local duration to compare against skips the duration check entirely', () async {
      await setUp();
      when(
        () => lrclibClient.get(
          trackName: any(named: 'trackName'),
          artistName: any(named: 'artistName'),
          albumName: any(named: 'albumName'),
          duration: any(named: 'duration'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => const LrclibTrack(
          plainLyrics: 'Lyrics',
          artistName: 'Some Artist',
          durationSeconds: 999,
        ),
      );

      final result = await repo.getLyrics(artist: 'Some Artist', title: 'A Song');

      expect((result as LyricsFound).isPossibleMismatch, isFalse);
    });

    test(
      'a response with no artistName at all (older/sparse data) skips the artist check',
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
        ).thenAnswer((_) async => const LrclibTrack(plainLyrics: 'Lyrics', durationSeconds: 300));

        final result = await repo.getLyrics(
          artist: 'Some Artist',
          title: 'A Song',
          duration: const Duration(seconds: 300),
        );

        expect((result as LyricsFound).isPossibleMismatch, isFalse);
      },
    );
  });

  group('filename fallback for tag-less files', () {
    test('missing ID3 recovers via filename parsing and proceeds with the lookup', () async {
      await setUp();
      when(
        () => lrclibClient.get(
          trackName: any(named: 'trackName'),
          artistName: any(named: 'artistName'),
          albumName: any(named: 'albumName'),
          duration: any(named: 'duration'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => const LrclibTrack(plainLyrics: 'Found via filename fallback'));

      final result = await repo.getLyrics(
        artist: null,
        title: null,
        audioFilePath: '/Music/Burna_Boy_ft._Ed_Sheeran_-_For_My_Hand_(mp3.pm).mp3',
      );

      expect(result, isA<LyricsFound>());
      final cached = await cacheDao.find('burna boy ft. ed sheeran', 'for my hand');
      expect(cached, isNotNull);
    });

    test(
      'an unparseable filename with no ID3 tags reports missing metadata without calling any layer',
      () async {
        await setUp();

        final result = await repo.getLyrics(
          artist: null,
          title: null,
          audioFilePath: '/Music/138697771_.mp3',
        );

        expect(result, isA<LyricsMissingMetadata>());
        verifyNever(
          () => lrclibClient.get(
            trackName: any(named: 'trackName'),
            artistName: any(named: 'artistName'),
            albumName: any(named: 'albumName'),
            duration: any(named: 'duration'),
            cancelToken: any(named: 'cancelToken'),
          ),
        );
      },
    );
  });

  group('manual lyrics', () {
    test('saveManualLyrics rejects an empty artist, title, or lyrics text', () async {
      await setUp();
      final song = _song(artist: 'Real Artist', title: 'Real Title');

      await expectLater(
        repo.saveManualLyrics(song: song, displayArtist: '', displayTitle: 'T', lyrics: 'L'),
        throwsArgumentError,
      );
      await expectLater(
        repo.saveManualLyrics(song: song, displayArtist: 'A', displayTitle: '  ', lyrics: 'L'),
        throwsArgumentError,
      );
      await expectLater(
        repo.saveManualLyrics(song: song, displayArtist: 'A', displayTitle: 'T', lyrics: '  '),
        throwsArgumentError,
      );
    });

    test("saveManualLyrics keys the cache row off the song's own metadata, not the typed display values", () async {
      await setUp();
      final song = _song(artist: 'Actual ID3 Artist', title: 'Actual ID3 Title');

      await repo.saveManualLyrics(
        song: song,
        displayArtist: 'Corrected Artist',
        displayTitle: 'Corrected Title',
        lyrics: 'Pasted lyrics here',
      );

      final cached = await cacheDao.find('actual id3 artist', 'actual id3 title');
      expect(cached, isNotNull);
      expect(cached!['source'], 'user_added');
      expect(cached['display_artist'], 'Corrected Artist');
      expect(cached['display_title'], 'Corrected Title');
      expect(cached['plain_lyrics'], 'Pasted lyrics here');

      // A later lookup for the song's own metadata finds it — this is
      // what guarantees the entry reattaches to the file on replay,
      // regardless of what was typed into the editor to correct a
      // garbled tag.
      final result = await repo.getLyrics(
        artist: song.artist,
        title: song.title,
        audioFilePath: song.path,
      );
      expect(result, isA<LyricsFound>());
      expect((result as LyricsFound).source, 'user_added');
    });

    test('a cached user_added row is returned immediately, skipping every API layer', () async {
      await setUp();
      await cacheDao.upsert(
        artistKey: 'some artist',
        titleKey: 'some song',
        source: 'user_added',
        hasSyncedTiming: false,
        plainLyrics: 'Manually entered lyrics',
        displayArtist: 'Some Artist',
        displayTitle: 'Some Song',
        fetchedAt: DateTime(2026, 8, 23),
      );

      final result = await repo.getLyrics(artist: 'Some Artist', title: 'Some Song');

      expect(result, isA<LyricsFound>());
      expect((result as LyricsFound).source, 'user_added');
      verifyNever(
        () => lrclibClient.get(
          trackName: any(named: 'trackName'),
          artistName: any(named: 'artistName'),
          albumName: any(named: 'albumName'),
          duration: any(named: 'duration'),
          cancelToken: any(named: 'cancelToken'),
        ),
      );
      verifyNever(() => dio.getUri<Map<String, dynamic>>(any(), options: any(named: 'options')));
      verifyNever(() => localLrcFileReader.read(any()));
    });

    test(
      'deleteManualLyrics removes the row so the next lookup re-runs the fallback chain',
      () async {
        await setUp();
        await cacheDao.upsert(
          artistKey: 'some artist',
          titleKey: 'some song',
          source: 'user_added',
          hasSyncedTiming: false,
          plainLyrics: 'Manually entered lyrics',
          fetchedAt: DateTime(2026, 8, 23),
        );

        await repo.deleteManualLyrics(artistKey: 'some artist', titleKey: 'some song');

        when(
          () => lrclibClient.get(
            trackName: any(named: 'trackName'),
            artistName: any(named: 'artistName'),
            albumName: any(named: 'albumName'),
            duration: any(named: 'duration'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async => const LrclibTrack(plainLyrics: 'Fresh from LRCLIB'));

        final result = await repo.getLyrics(artist: 'Some Artist', title: 'Some Song');

        expect(result, isA<LyricsFound>());
        expect((result as LyricsFound).source, 'lrclib');
      },
    );

    test('getManualLyricsEntries lists only user_added rows, newest first', () async {
      await setUp();
      await cacheDao.upsert(
        artistKey: 'artist a',
        titleKey: 'title a',
        source: 'user_added',
        hasSyncedTiming: false,
        plainLyrics: 'lyrics a',
        displayArtist: 'Artist A',
        displayTitle: 'Title A',
        fetchedAt: DateTime(2026, 8, 20),
      );
      await cacheDao.upsert(
        artistKey: 'artist b',
        titleKey: 'title b',
        source: 'user_added',
        hasSyncedTiming: false,
        plainLyrics: 'lyrics b',
        displayArtist: 'Artist B',
        displayTitle: 'Title B',
        fetchedAt: DateTime(2026, 8, 23),
      );
      await cacheDao.upsert(
        artistKey: 'auto artist',
        titleKey: 'auto title',
        source: 'lrclib',
        hasSyncedTiming: false,
        plainLyrics: 'auto lyrics',
        fetchedAt: DateTime(2026, 8, 22),
      );

      final entries = await repo.getManualLyricsEntries();

      expect(entries.map((e) => e.displayTitle), ['Title B', 'Title A']);
    });
  });
}
