import 'package:sqflite/sqflite.dart';

import '../../models/playlist.dart';
import '../database_change_notifier.dart';

/// Raw CRUD against the `playlists` table.
///
/// Phase 2 only needs existence checks (for the bulk-select "Add to
/// playlist" stub sheet on the library gallery) — full playlist management
/// UI lands in Phase 4, at which point this DAO grows add/remove-song and
/// reorder methods alongside it.
class PlaylistDao {
  PlaylistDao(this._db);

  final Database _db;

  Future<List<Playlist>> getAll({String orderBy = 'updated_at DESC'}) async {
    final rows = await _db.query('playlists', orderBy: orderBy);
    return rows.map(Playlist.fromMap).toList();
  }

  Future<int> count() async {
    final result = await _db.rawQuery('SELECT COUNT(*) AS c FROM playlists');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> insert(Playlist playlist) async {
    final id = await _db.insert('playlists', playlist.toMap());
    DatabaseChangeNotifier.instance.notify({'playlists'});
    return id;
  }
}
