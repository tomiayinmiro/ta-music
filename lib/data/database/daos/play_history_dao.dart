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

  /// Every play_history row, unfiltered — backup export's source for the
  /// full listening history. Can run into the thousands for a long-lived
  /// library; callers doing anything CPU-heavy with the result (JSON
  /// encoding) should offload that work, not this query itself (sqflite
  /// can't cross an isolate boundary).
  Future<List<PlayHistoryEntry>> getAll() async {
    final rows = await _db.query('play_history');
    return rows.map(PlayHistoryEntry.fromMap).toList();
  }

  /// Inserts every entry in one batch — backup import's counterpart to
  /// [getAll]. Appends unconditionally (no dedupe): each row represents an
  /// individual real listen, so importing a backup's history is additive by
  /// definition, same as the live 50%-or-completion recording path.
  Future<void> insertBatch(List<PlayHistoryEntry> entries) async {
    if (entries.isEmpty) return;
    final batch = _db.batch();
    for (final entry in entries) {
      batch.insert('play_history', entry.toMap());
    }
    await batch.commit(noResult: true);
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

  /// Every `played_at` timestamp (ms since epoch) recorded for [songId] —
  /// the recommendation engine's co-occurrence signal windows around each
  /// of these. Unordered; small in practice (one row per real listen of a
  /// single song).
  Future<List<int>> playedAtTimestampsForSong(int songId) async {
    final rows = await _db.query(
      'play_history',
      columns: ['played_at'],
      where: 'song_id = ?',
      whereArgs: [songId],
    );
    return rows.map((r) => r['played_at'] as int).toList();
  }

  /// For each timestamp in [seedTimestamps] (ms since epoch), counts other
  /// songs' `play_history` rows within [windowMs] on either side — "played
  /// in the same listening session as the seed." Returns candidate song id
  /// -> distinct co-occurring play count.
  ///
  /// Runs one indexed `played_at` range query per seed timestamp (bounded
  /// by how many times the seed itself has been played, not library size)
  /// rather than one query per candidate song, so it scales with listening
  /// history instead of library size. Dedupes by `play_history.id` so two
  /// overlapping seed-play windows never double-count the same candidate
  /// play.
  Future<Map<int, int>> coOccurringPlayCounts({
    required int excludeSongId,
    required List<int> seedTimestamps,
    int windowMs = 30 * 60 * 1000,
  }) async {
    if (seedTimestamps.isEmpty) return {};

    final seenRowIds = <int>{};
    final counts = <int, int>{};
    for (final t in seedTimestamps) {
      final rows = await _db.query(
        'play_history',
        columns: ['id', 'song_id'],
        where: 'song_id != ? AND played_at BETWEEN ? AND ?',
        whereArgs: [excludeSongId, t - windowMs, t + windowMs],
      );
      for (final row in rows) {
        if (!seenRowIds.add(row['id'] as int)) continue;
        final songId = row['song_id'] as int;
        counts[songId] = (counts[songId] ?? 0) + 1;
      }
    }
    return counts;
  }
}
