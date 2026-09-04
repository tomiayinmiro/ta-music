import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ta_music/data/database/daos/play_history_dao.dart';
import 'package:ta_music/data/database/daos/song_dao.dart';
import 'package:ta_music/data/database/database.dart';
import 'package:ta_music/data/models/play_history_entry.dart';
import 'package:ta_music/data/models/song.dart';

/// Guards BUG A (2026-08-21): the Aura Stats card's "Songs Played" tile
/// must count distinct songs, not play events — putting one song on
/// repeat, or repeatedly skipping back to it, must never inflate this
/// number.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    AppDatabase.debugDatabasePath = inMemoryDatabasePath;
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  Future<int> insertSong(SongDao songDao, String title) {
    return songDao.insert(Song(path: 'C:/music/$title.mp3', title: title, dateAdded: DateTime(2026, 1, 1)));
  }

  test('playing the same song 5 times counts as 1 distinct song', () async {
    final db = await AppDatabase.instance;
    final songDao = SongDao(db);
    final playHistoryDao = PlayHistoryDao(db);

    final songId = await insertSong(songDao, 'Repeat Offender');
    for (var i = 0; i < 5; i++) {
      await playHistoryDao.insert(
        PlayHistoryEntry(songId: songId, playedAt: DateTime(2026, 8, 21, 12, i), completed: true),
      );
    }

    // The old, buggy metric (a raw play count) would report 5 here.
    expect(await playHistoryDao.totalPlayCount(), 5);
    // The fixed metric reports 1 distinct song.
    expect(await playHistoryDao.distinctSongsPlayed(), 1);
  });

  test('distinct count still reflects multiple different songs correctly', () async {
    final db = await AppDatabase.instance;
    final songDao = SongDao(db);
    final playHistoryDao = PlayHistoryDao(db);

    final songA = await insertSong(songDao, 'Song A');
    final songB = await insertSong(songDao, 'Song B');
    // Song A played 3 times, Song B played once.
    for (var i = 0; i < 3; i++) {
      await playHistoryDao.insert(
        PlayHistoryEntry(songId: songA, playedAt: DateTime(2026, 8, 21, 12, i), completed: true),
      );
    }
    await playHistoryDao.insert(
      PlayHistoryEntry(songId: songB, playedAt: DateTime(2026, 8, 21, 13), completed: true),
    );

    expect(await playHistoryDao.distinctSongsPlayed(), 2);
  });

  test('distinctSongsPlayed respects a since cutoff', () async {
    final db = await AppDatabase.instance;
    final songDao = SongDao(db);
    final playHistoryDao = PlayHistoryDao(db);

    final oldSong = await insertSong(songDao, 'Old Song');
    final recentSong = await insertSong(songDao, 'Recent Song');
    await playHistoryDao.insert(
      PlayHistoryEntry(songId: oldSong, playedAt: DateTime(2026, 1, 1), completed: true),
    );
    await playHistoryDao.insert(
      PlayHistoryEntry(songId: recentSong, playedAt: DateTime(2026, 8, 20), completed: true),
    );

    expect(await playHistoryDao.distinctSongsPlayed(), 2);
    expect(
      await playHistoryDao.distinctSongsPlayed(since: DateTime(2026, 8, 1)),
      1,
      reason: 'only the recent song falls within the window',
    );
  });

  group('co-occurrence (Phase 6 batch 1 recommendation engine)', () {
    test('a play within 30 minutes of a seed play counts as co-occurring', () async {
      final db = await AppDatabase.instance;
      final songDao = SongDao(db);
      final playHistoryDao = PlayHistoryDao(db);

      final seed = await insertSong(songDao, 'Seed');
      final companion = await insertSong(songDao, 'Companion');
      final seedPlayedAt = DateTime(2026, 9, 1, 12, 0);
      await playHistoryDao.insert(
        PlayHistoryEntry(songId: seed, playedAt: seedPlayedAt, completed: true),
      );
      await playHistoryDao.insert(
        PlayHistoryEntry(
          songId: companion,
          playedAt: seedPlayedAt.add(const Duration(minutes: 20)),
          completed: true,
        ),
      );

      final counts = await playHistoryDao.coOccurringPlayCounts(
        excludeSongId: seed,
        seedTimestamps: [seedPlayedAt.millisecondsSinceEpoch],
      );

      expect(counts[companion], 1);
    });

    test('a play outside the 30 minute window does not count', () async {
      final db = await AppDatabase.instance;
      final songDao = SongDao(db);
      final playHistoryDao = PlayHistoryDao(db);

      final seed = await insertSong(songDao, 'Seed');
      final stranger = await insertSong(songDao, 'Stranger');
      final seedPlayedAt = DateTime(2026, 9, 1, 12, 0);
      await playHistoryDao.insert(
        PlayHistoryEntry(songId: seed, playedAt: seedPlayedAt, completed: true),
      );
      await playHistoryDao.insert(
        PlayHistoryEntry(
          songId: stranger,
          playedAt: seedPlayedAt.add(const Duration(hours: 3)),
          completed: true,
        ),
      );

      final counts = await playHistoryDao.coOccurringPlayCounts(
        excludeSongId: seed,
        seedTimestamps: [seedPlayedAt.millisecondsSinceEpoch],
      );

      expect(counts[stranger], isNull);
    });

    test('overlapping seed-play windows never double-count the same candidate play', () async {
      final db = await AppDatabase.instance;
      final songDao = SongDao(db);
      final playHistoryDao = PlayHistoryDao(db);

      final seed = await insertSong(songDao, 'Seed');
      final companion = await insertSong(songDao, 'Companion');
      final firstSeedPlay = DateTime(2026, 9, 1, 12, 0);
      final secondSeedPlay = firstSeedPlay.add(const Duration(minutes: 10));
      await playHistoryDao.insert(
        PlayHistoryEntry(songId: seed, playedAt: firstSeedPlay, completed: true),
      );
      await playHistoryDao.insert(
        PlayHistoryEntry(songId: seed, playedAt: secondSeedPlay, completed: true),
      );
      // Falls inside both seed plays' +/-30min windows.
      await playHistoryDao.insert(
        PlayHistoryEntry(
          songId: companion,
          playedAt: firstSeedPlay.add(const Duration(minutes: 5)),
          completed: true,
        ),
      );

      final counts = await playHistoryDao.coOccurringPlayCounts(
        excludeSongId: seed,
        seedTimestamps: [
          firstSeedPlay.millisecondsSinceEpoch,
          secondSeedPlay.millisecondsSinceEpoch,
        ],
      );

      expect(counts[companion], 1, reason: 'the same play_history row must only count once');
    });

    test('the seed song is never counted against itself', () async {
      final db = await AppDatabase.instance;
      final songDao = SongDao(db);
      final playHistoryDao = PlayHistoryDao(db);

      final seed = await insertSong(songDao, 'Seed');
      final seedPlayedAt = DateTime(2026, 9, 1, 12, 0);
      await playHistoryDao.insert(
        PlayHistoryEntry(songId: seed, playedAt: seedPlayedAt, completed: true),
      );
      await playHistoryDao.insert(
        PlayHistoryEntry(
          songId: seed,
          playedAt: seedPlayedAt.add(const Duration(minutes: 5)),
          completed: true,
        ),
      );

      final counts = await playHistoryDao.coOccurringPlayCounts(
        excludeSongId: seed,
        seedTimestamps: [seedPlayedAt.millisecondsSinceEpoch],
      );

      expect(counts[seed], isNull);
    });

    test('empty seed timestamps returns no co-occurrence', () async {
      final db = await AppDatabase.instance;
      final playHistoryDao = PlayHistoryDao(db);

      final counts = await playHistoryDao.coOccurringPlayCounts(
        excludeSongId: 1,
        seedTimestamps: const [],
      );

      expect(counts, isEmpty);
    });
  });
}
