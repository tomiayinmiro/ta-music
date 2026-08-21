import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ta_music/data/database/daos/listening_segment_dao.dart';
import 'package:ta_music/data/database/daos/song_dao.dart';
import 'package:ta_music/data/database/database.dart';
import 'package:ta_music/data/models/song.dart';

/// Guards BUG B's persistence layer (2026-08-21): total listened time must
/// come from real, flushed listening segments — never a track's full
/// duration — and must respect the Local Insights time-window filters.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    AppDatabase.debugDatabasePath = inMemoryDatabasePath;
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  Future<int> insertSong(SongDao songDao, String title, {int durationMs = 30 * 60 * 1000}) {
    return songDao.insert(
      Song(path: 'C:/music/$title.mp3', title: title, durationMs: durationMs, dateAdded: DateTime(2026, 1, 1)),
    );
  }

  test('2 minutes of listening to a 30-minute track totals 2 minutes, not 30', () async {
    final db = await AppDatabase.instance;
    final songDao = SongDao(db);
    final segmentDao = ListeningSegmentDao(db);

    final songId = await insertSong(songDao, 'Long Track'); // 30-minute duration
    await segmentDao.insert(
      songId: songId,
      listenedMs: const Duration(minutes: 2).inMilliseconds,
      recordedAt: DateTime(2026, 8, 21, 12, 0),
    );

    expect(await segmentDao.totalListenedMs(), const Duration(minutes: 2).inMilliseconds);
  });

  test('skipping through many songs sums only the real seconds spent, not their durations', () async {
    final db = await AppDatabase.instance;
    final songDao = SongDao(db);
    final segmentDao = ListeningSegmentDao(db);

    // 20 songs, each with a long duration, but only ~15s actually listened
    // to per song (5 minutes total across all 20) before skipping.
    for (var i = 0; i < 20; i++) {
      final songId = await insertSong(songDao, 'Song $i');
      await segmentDao.insert(
        songId: songId,
        listenedMs: const Duration(seconds: 15).inMilliseconds,
        recordedAt: DateTime(2026, 8, 21, 12, 0),
      );
    }

    expect(await segmentDao.totalListenedMs(), const Duration(minutes: 5).inMilliseconds);
  });

  test('a zero or negative listened_ms flush is not recorded', () async {
    final db = await AppDatabase.instance;
    final songDao = SongDao(db);
    final segmentDao = ListeningSegmentDao(db);

    final songId = await insertSong(songDao, 'Instant Skip');
    await segmentDao.insert(songId: songId, listenedMs: 0, recordedAt: DateTime(2026, 8, 21));

    expect(await segmentDao.totalListenedMs(), 0);
  });

  test('totalListenedMs respects a since cutoff, matching the 7d/1m/all-time windows', () async {
    final db = await AppDatabase.instance;
    final songDao = SongDao(db);
    final segmentDao = ListeningSegmentDao(db);

    final songId = await insertSong(songDao, 'Recurring Listen');
    await segmentDao.insert(
      songId: songId,
      listenedMs: const Duration(minutes: 10).inMilliseconds,
      recordedAt: DateTime(2026, 1, 1), // well outside any window
    );
    await segmentDao.insert(
      songId: songId,
      listenedMs: const Duration(minutes: 3).inMilliseconds,
      recordedAt: DateTime(2026, 8, 20), // within the last 7 days of 2026-08-21
    );

    expect(
      await segmentDao.totalListenedMs(),
      const Duration(minutes: 13).inMilliseconds,
      reason: 'all-time includes both segments',
    );
    expect(
      await segmentDao.totalListenedMs(since: DateTime(2026, 8, 14)),
      const Duration(minutes: 3).inMilliseconds,
      reason: 'a 7-day window excludes the January segment',
    );
  });
}
