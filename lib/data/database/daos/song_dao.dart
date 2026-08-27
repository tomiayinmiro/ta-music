import 'package:sqflite/sqflite.dart';

import '../../../core/utils/path_matching.dart';
import '../../models/song.dart';
import '../database_change_notifier.dart';

/// Raw CRUD + library-specific queries against the `songs` table.
class SongDao {
  SongDao(this._db);

  final Database _db;

  static const _visibleWhere = 'is_excluded = 0 AND is_missing = 0';

  Future<int> insert(Song song) async {
    final id = await _db.insert('songs', song.toMap());
    DatabaseChangeNotifier.instance.notify({'songs'});
    return id;
  }

  Future<void> update(Song song) async {
    await _db.update('songs', song.toMap(), where: 'id = ?', whereArgs: [song.id]);
    DatabaseChangeNotifier.instance.notify({'songs'});
  }

  /// Marks a song missing (soft-delete) without touching `is_excluded`.
  Future<void> markMissing(int id) async {
    await _db.update('songs', {'is_missing': 1}, where: 'id = ?', whereArgs: [id]);
    DatabaseChangeNotifier.instance.notify({'songs'});
  }

  /// Instantly hides every song already in the library whose path falls
  /// under [folderPath], without waiting for the next scan. Uses
  /// `is_missing` (not `is_excluded`) — the same field the scanner's own
  /// reconciliation pass uses for "not a candidate anymore" — so a
  /// subsequent scan naturally un-hides these songs again if the folder is
  /// later removed from the excluded list, with no special-casing needed.
  /// Matching is done in Dart (boundary-aware prefix match), not a SQL
  /// `LIKE`, to avoid "MusicOld" being treated as a child of "Music".
  Future<void> markMissingUnderPath(String folderPath) async {
    final rows = await _db.query('songs', columns: ['id', 'path'], where: 'is_missing = 0');
    final matchingIds = [
      for (final row in rows)
        if (isPathUnderRoot(row['path'] as String, folderPath)) row['id'] as int,
    ];
    if (matchingIds.isEmpty) return;
    await _db.update(
      'songs',
      {'is_missing': 1},
      where: 'id IN (${matchingIds.map((_) => '?').join(',')})',
      whereArgs: matchingIds,
    );
    DatabaseChangeNotifier.instance.notify({'songs'});
  }

  Future<void> markExcluded(int id, bool excluded) async {
    await _db.update('songs', {'is_excluded': excluded ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
    DatabaseChangeNotifier.instance.notify({'songs'});
  }

  Future<Song?> getById(int id) async {
    final rows = await _db.query('songs', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Song.fromMap(rows.first);
  }

  /// Batched — one query for the whole list, not one round-trip per id.
  /// Bug 10 (device testing pass): `AudioPlayerHandler.restoreState()`
  /// used to call [getById] in a loop, one row at a time; with queues now
  /// spanning a whole list (bug 11's fix), that meant hundreds of
  /// sequential DB round-trips blocking the main isolate before `runApp()`
  /// could even fire. Returned in whatever order sqflite gives them —
  /// callers that need the original id order re-sort themselves.
  Future<List<Song>> getByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await _db.query('songs', where: 'id IN ($placeholders)', whereArgs: ids);
    return rows.map(Song.fromMap).toList();
  }

  Future<Song?> getByPath(String path) async {
    final rows = await _db.query('songs', where: 'path = ?', whereArgs: [path], limit: 1);
    return rows.isEmpty ? null : Song.fromMap(rows.first);
  }

  Future<List<Song>> getAllVisible({String orderBy = 'title COLLATE NOCASE'}) async {
    final rows = await _db.query('songs', where: _visibleWhere, orderBy: orderBy);
    return rows.map(Song.fromMap).toList();
  }

  /// All rows regardless of exclusion/missing state — used by the scanner to
  /// reconcile what's already on disk against what's already in the DB.
  Future<List<Song>> getAllRaw() async {
    final rows = await _db.query('songs');
    return rows.map(Song.fromMap).toList();
  }

  Future<List<Song>> getByAlbumId(int albumId) async {
    final rows = await _db.query(
      'songs',
      where: '$_visibleWhere AND album_id = ?',
      whereArgs: [albumId],
      orderBy: 'disc_number, track_number, title COLLATE NOCASE',
    );
    return rows.map(Song.fromMap).toList();
  }

  Future<List<Song>> getByArtistId(int artistId) async {
    final rows = await _db.query(
      'songs',
      where: '$_visibleWhere AND artist_id = ?',
      whereArgs: [artistId],
      orderBy: 'title COLLATE NOCASE',
    );
    return rows.map(Song.fromMap).toList();
  }

  Future<List<Song>> getRecentlyAdded({required DateTime since}) async {
    final rows = await _db.query(
      'songs',
      where: '$_visibleWhere AND date_added >= ?',
      whereArgs: [since.millisecondsSinceEpoch],
      orderBy: 'date_added DESC',
    );
    return rows.map(Song.fromMap).toList();
  }

  Future<List<Song>> getRecentlyPlayed({int limit = 20}) async {
    final rows = await _db.query(
      'songs',
      where: '$_visibleWhere AND last_played_at IS NOT NULL',
      orderBy: 'last_played_at DESC',
      limit: limit,
    );
    return rows.map(Song.fromMap).toList();
  }

  Future<int> countVisible() async {
    final result = await _db.rawQuery('SELECT COUNT(*) AS c FROM songs WHERE $_visibleWhere');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> incrementPlayCount(int songId, DateTime playedAt) async {
    await _db.rawUpdate(
      'UPDATE songs SET play_count = play_count + 1, last_played_at = ? WHERE id = ?',
      [playedAt.millisecondsSinceEpoch, songId],
    );
    DatabaseChangeNotifier.instance.notify({'songs'});
  }
}
