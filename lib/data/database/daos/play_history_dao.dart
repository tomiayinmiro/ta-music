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

  /// Flips a row inserted at the 50%-played mark to `completed: true` once
  /// the same listen actually reaches the end of the track, without a
  /// second `play_count` increment — see `AudioPlayerHandler` for the rule.
  Future<void> markCompleted(int id) async {
    await _db.update('play_history', {'completed': 1}, where: 'id = ?', whereArgs: [id]);
    DatabaseChangeNotifier.instance.notify({'play_history'});
  }

  Future<int> totalPlayCount() async {
    final result = await _db.rawQuery('SELECT COUNT(*) AS c FROM play_history');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Distinct songs played — deliberately `COUNT(DISTINCT song_id)`, not
  /// [totalPlayCount]'s `COUNT(*)`: playing one song ten times (repeat, or
  /// skipping back to it) must read as "1 song played," not "10". Only
  /// used for the Aura Stats card's "Songs Played" tile — the nav-drawer
  /// stats' "Songs played" tile intentionally keeps using [totalPlayCount]
  /// (out of scope for the 2026-08-21 Aura fix; not touched here).
  Future<int> distinctSongsPlayed({DateTime? since}) async {
    final where = since != null ? 'WHERE played_at >= ${since.millisecondsSinceEpoch}' : '';
    final result = await _db.rawQuery(
      'SELECT COUNT(DISTINCT song_id) AS c FROM play_history $where',
    );
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
