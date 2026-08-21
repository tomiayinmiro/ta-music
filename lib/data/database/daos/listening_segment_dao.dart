import 'package:sqflite/sqflite.dart';

import '../database_change_notifier.dart';

/// Raw CRUD against `listening_segments` — real, wall-clock-measured
/// listening time (see `_migrationV6`'s doc for why this is a separate
/// table from `play_history`). Each row is one flush's worth of
/// accumulated time from `ListeningTimeAccumulator`; totals are a plain
/// `SUM`.
class ListeningSegmentDao {
  ListeningSegmentDao(this._db);

  final Database _db;

  /// No-ops for a non-positive [listenedMs] — a flush with nothing
  /// accumulated (e.g. a spurious start/stop with no real time between)
  /// shouldn't leave a zero-value row behind.
  Future<void> insert({
    required int songId,
    required int listenedMs,
    required DateTime recordedAt,
  }) async {
    if (listenedMs <= 0) return;
    await _db.insert('listening_segments', {
      'song_id': songId,
      'listened_ms': listenedMs,
      'recorded_at': recordedAt.millisecondsSinceEpoch,
    });
    DatabaseChangeNotifier.instance.notify({'listening_segments'});
  }

  /// Total real listened milliseconds, optionally since a cutoff — the
  /// accurate replacement for `PlayHistoryDao.totalListenedMs()`'s
  /// full-track-duration approximation.
  Future<int> totalListenedMs({DateTime? since}) async {
    final where = since != null
        ? 'WHERE recorded_at >= ${since.millisecondsSinceEpoch}'
        : '';
    final result = await _db.rawQuery(
      'SELECT COALESCE(SUM(listened_ms), 0) AS total FROM listening_segments $where',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
