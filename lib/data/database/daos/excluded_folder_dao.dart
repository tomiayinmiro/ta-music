import 'package:sqflite/sqflite.dart';

import '../../models/excluded_folder.dart';
import '../database_change_notifier.dart';

/// Raw CRUD against the `excluded_folders` table — user-configurable
/// folders the scanner should skip (CLAUDE.md voice-recording rule (c)).
class ExcludedFolderDao {
  ExcludedFolderDao(this._db);

  final Database _db;

  Future<List<ExcludedFolder>> getAll() async {
    final rows = await _db.query('excluded_folders', orderBy: 'path');
    return rows.map(ExcludedFolder.fromMap).toList();
  }

  Future<void> add(String path) async {
    await _db.insert(
      'excluded_folders',
      {'path': path},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    DatabaseChangeNotifier.instance.notify({'excluded_folders'});
  }

  Future<void> remove(int id) async {
    await _db.delete('excluded_folders', where: 'id = ?', whereArgs: [id]);
    DatabaseChangeNotifier.instance.notify({'excluded_folders'});
  }
}
