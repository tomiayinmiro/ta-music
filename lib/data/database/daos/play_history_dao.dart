import 'package:sqflite/sqflite.dart';

import '../../models/play_history_entry.dart';
import '../database_change_notifier.dart';

/// Raw CRUD + aggregate queries against the `play_history` table — the
/// source of truth for local listening stats.
class PlayHistoryDao {
  PlayHistoryDao(this._db);

  final Database _db;

  Future<int> insert(PlayHistoryEntry entry) async {
    final id = await _db.insert('play_history', entry.toMap());
    DatabaseChangeNotifier.instance.notify({'play_history'});
    return id;
  }

  Future<int> totalPlayCount() async {
    final result = await _db.rawQuery('SELECT COUNT(*) AS c FROM play_history');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Total listening time in milliseconds, computed by joining each
  /// history row back to its song's duration.
  Future<int> totalListenedMs() async {
    final result = await _db.rawQuery('''
      SELECT COALESCE(SUM(s.duration_ms), 0) AS total FROM play_history ph
      JOIN songs s ON s.id = ph.song_id
    ''');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Top artists by play count. Returns (artistName, playCount) pairs.
  Future<List<(String, int)>> topArtists({int limit = 5, DateTime? since}) async {
    final where = since != null ? 'WHERE ph.played_at >= ${since.millisecondsSinceEpoch}' : '';
    final rows = await _db.rawQuery('''
      SELECT s.artist AS artist, COUNT(*) AS plays FROM play_history ph
      JOIN songs s ON s.id = ph.song_id
      $where
      GROUP BY s.artist
      ORDER BY plays DESC
      LIMIT ?
    ''', [limit]);
    return rows.map((r) => (r['artist'] as String? ?? 'Unknown Artist', r['plays'] as int)).toList();
  }

  /// Top songs by play count within the history window. Returns song ids.
  Future<List<(int, int)>> topSongIds({int limit = 5, DateTime? since}) async {
    final where = since != null ? 'WHERE played_at >= ${since.millisecondsSinceEpoch}' : '';
    final rows = await _db.rawQuery('''
      SELECT song_id, COUNT(*) AS plays FROM play_history
      $where
      GROUP BY song_id
      ORDER BY plays DESC
      LIMIT ?
    ''', [limit]);
    return rows.map((r) => (r['song_id'] as int, r['plays'] as int)).toList();
  }
}
