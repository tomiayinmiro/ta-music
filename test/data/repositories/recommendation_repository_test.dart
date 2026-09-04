import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ta_music/data/database/daos/favorite_dao.dart';
import 'package:ta_music/data/database/daos/play_history_dao.dart';
import 'package:ta_music/data/database/daos/recommendation_seed_cache_dao.dart';
import 'package:ta_music/data/database/daos/song_dao.dart';
import 'package:ta_music/data/database/database.dart';
import 'package:ta_music/data/models/play_history_entry.dart';
import 'package:ta_music/data/models/song.dart';
import 'package:ta_music/data/repositories/recommendation_repository.dart';

/// Exercises `RecommendationRepository` against a real (in-memory) database
/// — the exclusion rules (voice memos, excluded folders) and the "not
/// enough listening history yet" hide-the-section rule both depend on real
/// SQL (`SongDao.getAllVisible`, `PlayHistoryDao.distinctSongsPlayed`)
/// rather than anything the pure `recommendation_service.dart` scorer sees,
/// so they need a database to test meaningfully.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    AppDatabase.debugDatabasePath = inMemoryDatabasePath;
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  Future<int> insertSong(
    SongDao songDao,
    String title, {
    String? artist,
    String path = '',
    bool isExcluded = false,
    bool isMissing = false,
  }) async {
    final id = await songDao.insert(
      Song(
        path: path.isEmpty ? 'C:/music/$title.mp3' : path,
        title: title,
        artist: artist,
        dateAdded: DateTime(2026, 1, 1),
      ),
    );
    if (isExcluded) await songDao.markExcluded(id, true);
    if (isMissing) await songDao.markMissing(id);
    return id;
  }

  Future<({SongDao songDao, PlayHistoryDao playHistoryDao, FavoriteDao favoriteDao,
      RecommendationSeedCacheDao seedCacheDao, RecommendationRepository repo})>
  buildRepo() async {
    final db = await AppDatabase.instance;
    final songDao = SongDao(db);
    final playHistoryDao = PlayHistoryDao(db);
    final favoriteDao = FavoriteDao(db);
    final seedCacheDao = RecommendationSeedCacheDao(db);
    final repo = RecommendationRepository(songDao, playHistoryDao, favoriteDao, seedCacheDao);
    return (
      songDao: songDao,
      playHistoryDao: playHistoryDao,
      favoriteDao: favoriteDao,
      seedCacheDao: seedCacheDao,
      repo: repo,
    );
  }

  group('exclusions', () {
    test('a voice-memo-flagged song never appears in recommendations', () async {
      final env = await buildRepo();
      final seed = await insertSong(env.songDao, 'Seed', artist: 'Burna Boy');
      final voiceMemo = await insertSong(
        env.songDao,
        'Voice Memo',
        artist: 'Burna Boy',
        isExcluded: true,
      );
      final visible = await insertSong(env.songDao, 'Visible', artist: 'Burna Boy');

      final seedSong = (await env.songDao.getById(seed))!;
      final resultIds = (await env.repo.recommendationsFor(seedSong, limit: 10))
          .map((s) => s.id)
          .toSet();

      expect(resultIds, contains(visible));
      expect(resultIds, isNot(contains(voiceMemo)));
    });

    test('a song in an excluded folder (is_missing) never appears in recommendations', () async {
      final env = await buildRepo();
      final seed = await insertSong(env.songDao, 'Seed', artist: 'Burna Boy');
      await insertSong(env.songDao, 'Excluded Folder Song', artist: 'Burna Boy', isMissing: true);
      final visible = await insertSong(env.songDao, 'Visible', artist: 'Burna Boy');

      final seedSong = (await env.songDao.getById(seed))!;
      final results = await env.repo.recommendationsFor(seedSong, limit: 10);
      final resultIds = results.map((s) => s.id).toSet();

      expect(resultIds, contains(visible));
      expect(resultIds.length, 1, reason: 'only the one visible candidate should survive');
    });
  });

  group('empty library / new user handling', () {
    test('homeSeed is null when fewer than 2 distinct songs have been played', () async {
      final env = await buildRepo();
      final songA = await insertSong(env.songDao, 'A');
      // Only 1 distinct song played, however many times — still under the
      // threshold (lowered to 2 on 2026-09-04, see
      // _kMinDistinctPlayedSongsForHome's doc).
      for (var i = 0; i < 5; i++) {
        await env.playHistoryDao.insert(
          PlayHistoryEntry(songId: songA, playedAt: DateTime(2026, 9, 1, 12, i), completed: true),
        );
      }

      expect(await env.repo.homeSeed(), isNull);
    });

    test('homeSeed is no longer hidden once exactly 2 distinct songs have been played', () async {
      final env = await buildRepo();
      final songA = await insertSong(env.songDao, 'A');
      final songB = await insertSong(env.songDao, 'B');
      final now = DateTime.now();
      // Neither song hits the 3+-in-24h or favorited fast path, so this
      // exercises the 7-day fallback — confirms the lowered gate actually
      // lets that fallback chain run instead of being blocked upstream.
      await env.playHistoryDao.insert(PlayHistoryEntry(songId: songA, playedAt: now, completed: true));
      await env.playHistoryDao.insert(PlayHistoryEntry(songId: songB, playedAt: now, completed: true));

      expect(await env.repo.homeSeed(), isNotNull);
    });

    test('recommendationsFor an empty library returns no results', () async {
      final env = await buildRepo();
      final onlySong = await insertSong(env.songDao, 'Only Song');
      final seedSong = (await env.songDao.getById(onlySong))!;

      expect(await env.repo.recommendationsFor(seedSong, limit: 10), isEmpty);
    });
  });

  group('home seed selection and caching', () {
    Future<void> seedFiveDistinctPlays(
      ({SongDao songDao, PlayHistoryDao playHistoryDao, FavoriteDao favoriteDao,
          RecommendationSeedCacheDao seedCacheDao, RecommendationRepository repo})
      env,
    ) async {
      // Five distinct played songs so the "not enough history" hide-rule
      // doesn't trip and mask the behavior under test.
      for (final title in ['P1', 'P2', 'P3', 'P4', 'P5']) {
        final id = await insertSong(env.songDao, title);
        await env.playHistoryDao.insert(
          PlayHistoryEntry(songId: id, playedAt: DateTime(2026, 1, 1), completed: true),
        );
      }
    }

    test('a song played 3+ times in the last 24h is picked as the seed', () async {
      final env = await buildRepo();
      await seedFiveDistinctPlays(env);
      final strongSignal = await insertSong(env.songDao, 'Strong Signal');
      final now = DateTime.now();
      for (var i = 0; i < 3; i++) {
        await env.playHistoryDao.insert(
          PlayHistoryEntry(
            songId: strongSignal,
            playedAt: now.subtract(Duration(hours: i)),
            completed: true,
          ),
        );
      }

      final seed = await env.repo.homeSeed();
      expect(seed?.id, strongSignal);
    });

    test('the picked seed is cached and reused within the TTL', () async {
      final env = await buildRepo();
      await seedFiveDistinctPlays(env);
      final firstSignal = await insertSong(env.songDao, 'First Signal');
      final now = DateTime.now();
      for (var i = 0; i < 3; i++) {
        await env.playHistoryDao.insert(
          PlayHistoryEntry(songId: firstSignal, playedAt: now, completed: true),
        );
      }

      final firstPick = await env.repo.homeSeed();
      expect(firstPick?.id, firstSignal);

      // A song with an even stronger recent signal shows up afterward —
      // if the cache weren't honored, this would become the new pick.
      final laterSignal = await insertSong(env.songDao, 'Later Signal');
      for (var i = 0; i < 10; i++) {
        await env.playHistoryDao.insert(
          PlayHistoryEntry(songId: laterSignal, playedAt: now, completed: true),
        );
      }

      final secondPick = await env.repo.homeSeed();
      expect(secondPick?.id, firstSignal, reason: 'cached seed should still be returned within its TTL');

      await env.repo.clearSeedCache();
      final thirdPick = await env.repo.homeSeed();
      expect(thirdPick?.id, laterSignal, reason: 'clearing the cache should force a fresh pick');
    });
  });
}
