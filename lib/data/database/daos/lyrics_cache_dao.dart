import 'package:sqflite/sqflite.dart';

/// Aggregate counts for the debug "Lyrics cache" screen (Settings) — total
/// rows, a breakdown by [LyricsCacheDao.upsert]'s `source` value, how many
/// are confirmed misses, and the oldest `fetched_at` in the table.
class LyricsCacheStats {
  const LyricsCacheStats({
    required this.totalRows,
    required this.countBySource,
    required this.noneCount,
    required this.oldestFetchedAt,
  });

  final int totalRows;
  final Map<String, int> countBySource;
  final int noneCount;
  final DateTime? oldestFetchedAt;
}

/// Raw CRUD against `lyrics_cache`, keyed by a normalized (artist, title)
/// pair rather than `song_id` — see `_migrationV7`'s doc for why.
class LyricsCacheDao {
  LyricsCacheDao(this._db);

  final Database _db;

  Future<Map<String, Object?>?> find(String artistKey, String titleKey) async {
    final rows = await _db.query(
      'lyrics_cache',
      where: 'artist_key = ? AND title_key = ?',
      whereArgs: [artistKey, titleKey],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Upserts on the (artist_key, title_key) unique constraint — a re-fetch
  /// (e.g. a stale null entry past its TTL) replaces the existing row
  /// rather than accumulating duplicates. A manual save (`source:
  /// 'user_added'`) replaces an existing auto-fetched row under the same
  /// key the same way — see `LyricsRepository.saveManualLyrics`, which is
  /// how a manual entry "always wins": it's just the newest row.
  ///
  /// [source] is `'lrclib'`, `'lyrics.ovh'`, `'local_lrc'`, `'user_added'`,
  /// or `'none'` for a confirmed miss across all 3 layers. [syncedLyricsLrc]
  /// and [plainLyrics] may both be non-null at once — LRCLIB returns both
  /// side by side for the same track. [isPossibleMismatch] is true only
  /// when a LRCLIB hit came from the query cascade's last-resort,
  /// primary-artist-only variant. [displayArtist]/[displayTitle] are set
  /// only for `'user_added'` rows — what the user actually typed into the
  /// manual editor, for the Settings "Lyrics" management list; auto-fetched
  /// rows leave these null.
  Future<void> upsert({
    required String artistKey,
    required String titleKey,
    required String source,
    required bool hasSyncedTiming,
    String? syncedLyricsLrc,
    String? plainLyrics,
    bool isPossibleMismatch = false,
    String? displayArtist,
    String? displayTitle,
    required DateTime fetchedAt,
  }) async {
    await _db.insert('lyrics_cache', {
      'artist_key': artistKey,
      'title_key': titleKey,
      'source': source,
      'has_synced_timing': hasSyncedTiming ? 1 : 0,
      'synced_lyrics_lrc': syncedLyricsLrc,
      'plain_lyrics': plainLyrics,
      'is_possible_mismatch': isPossibleMismatch ? 1 : 0,
      'display_artist': displayArtist,
      'display_title': displayTitle,
      'fetched_at': fetchedAt.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Rows the user added manually from the "Add lyrics manually" screen,
  /// newest first — backs the Settings "Lyrics" screen's management list.
  Future<List<Map<String, Object?>>> findUserAdded() {
    return _db.query('lyrics_cache', where: "source = 'user_added'", orderBy: 'fetched_at DESC');
  }

  /// Deletes one row by its (artist_key, title_key) — used both for
  /// removing a manual entry (Settings "Lyrics" screen) and, generically,
  /// any cache row. After deletion the next lookup for that key re-runs the
  /// full LRCLIB/lyrics.ovh/local-`.lrc` chain.
  Future<void> deleteByKey(String artistKey, String titleKey) async {
    await _db.delete(
      'lyrics_cache',
      where: 'artist_key = ? AND title_key = ?',
      whereArgs: [artistKey, titleKey],
    );
  }

  Future<LyricsCacheStats> stats() async {
    final totalRows =
        Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM lyrics_cache')) ?? 0;

    final bySourceRows = await _db.rawQuery(
      'SELECT source, COUNT(*) AS c FROM lyrics_cache GROUP BY source',
    );
    final countBySource = {
      for (final row in bySourceRows) row['source'] as String: row['c'] as int,
    };

    final oldestRows = await _db.query(
      'lyrics_cache',
      columns: ['fetched_at'],
      orderBy: 'fetched_at ASC',
      limit: 1,
    );
    final oldestFetchedAt = oldestRows.isEmpty
        ? null
        : DateTime.fromMillisecondsSinceEpoch(oldestRows.first['fetched_at'] as int);

    return LyricsCacheStats(
      totalRows: totalRows,
      countBySource: countBySource,
      noneCount: countBySource['none'] ?? 0,
      oldestFetchedAt: oldestFetchedAt,
    );
  }
}
