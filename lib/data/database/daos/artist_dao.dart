import 'package:sqflite/sqflite.dart';

import '../../models/artist.dart';
import '../database_change_notifier.dart';

/// Raw CRUD against the `artists` table, plus scanner upsert support.
class ArtistDao {
  ArtistDao(this._db);

  final Database _db;

  Future<List<Artist>> getAll({String orderBy = 'name COLLATE NOCASE'}) async {
    final rows = await _db.query('artists', orderBy: orderBy);
    return rows.map(Artist.fromMap).toList();
  }

  Future<Artist?> getById(int id) async {
    final rows = await _db.query('artists', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Artist.fromMap(rows.first);
  }

  Future<Artist?> findByName(String? name) async {
    // sqflite's whereArgs rejects null outright (even bound to `IS ?`), so
    // NULL has to be matched with a literal `IS NULL` instead of a param.
    final rows = await _db.query(
      'artists',
      where: name == null ? 'name IS NULL' : 'name = ?',
      whereArgs: name == null ? null : [name],
      limit: 1,
    );
    return rows.isEmpty ? null : Artist.fromMap(rows.first);
  }

  /// Finds an existing artist by name or inserts a new one. Returns the
  /// resolved artist id.
  Future<int> upsert(String? name) async {
    final existing = await findByName(name);
    if (existing != null) return existing.id!;
    final id = await _db.insert('artists', {'name': name});
    DatabaseChangeNotifier.instance.notify({'artists'});
    return id;
  }
}
