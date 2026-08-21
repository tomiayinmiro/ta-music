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
}
