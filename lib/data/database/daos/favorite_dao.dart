import 'package:sqflite/sqflite.dart';

import '../../models/favorite.dart';
import '../database_change_notifier.dart';

/// Raw CRUD against the `favorites` table.
class FavoriteDao {
  FavoriteDao(this._db);

  final Database _db;

  /// Favorites sorted by play count (most-played first). Songs with 0 plays
  /// are excluded, per CLAUDE.md — a song favorited manually but never
  /// played still shouldn't surface here until it's actually been listened
  /// to at least once.
  Future<List<Favorite>> getAllSortedByPlayCount() async {
    final rows = await _db.rawQuery('''
      SELECT f.* FROM favorites f
      JOIN songs s ON s.id = f.song_id
      WHERE s.play_count > 0 AND s.is_excluded = 0 AND s.is_missing = 0
      ORDER BY s.play_count DESC
    ''');
    return rows.map(Favorite.fromMap).toList();
  }

  /// Every favorite row, unfiltered by play count — unlike
  /// [getAllSortedByPlayCount], used where the raw membership set itself is
  /// needed (e.g. backup export), not the play-count-sorted display list.
  Future<List<Favorite>> getAll() async {
    final rows = await _db.query('favorites');
    return rows.map(Favorite.fromMap).toList();
  }

  Future<bool> isFavorite(int songId) async {
    final rows = await _db.query('favorites', where: 'song_id = ?', whereArgs: [songId], limit: 1);
    return rows.isNotEmpty;
  }

  Future<void> add(int songId, {required bool isManual}) async {
    await _db.insert(
      'favorites',
      {
        'song_id': songId,
        'added_at': DateTime.now().millisecondsSinceEpoch,
        'is_manual': isManual ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    DatabaseChangeNotifier.instance.notify({'favorites'});
  }

  Future<void> remove(int songId) async {
    await _db.delete('favorites', where: 'song_id = ?', whereArgs: [songId]);
    DatabaseChangeNotifier.instance.notify({'favorites'});
  }
}
