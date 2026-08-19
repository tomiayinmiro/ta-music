import 'package:sqflite/sqflite.dart';

/// Raw CRUD against the single-row `playback_state` table.
class PlaybackStateDao {
  PlaybackStateDao(this._db);

  final Database _db;

  Future<void> save(Map<String, Object?> row) async {
    await _db.insert(
      'playback_state',
      {'id': 1, ...row},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, Object?>?> load() async {
    final rows = await _db.query('playback_state', where: 'id = 1', limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> clear() async {
    await _db.delete('playback_state', where: 'id = 1');
  }
}
