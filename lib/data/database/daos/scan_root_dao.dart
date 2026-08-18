import 'package:sqflite/sqflite.dart';

import '../../models/scan_root.dart';
import '../database_change_notifier.dart';

/// Raw CRUD against the `scan_roots` table — the folders the library
/// scanner walks.
class ScanRootDao {
  ScanRootDao(this._db);

  final Database _db;

  Future<List<ScanRoot>> getAll() async {
    final rows = await _db.query('scan_roots', orderBy: 'added_at');
    return rows.map(ScanRoot.fromMap).toList();
  }

  Future<void> add(String path) async {
    await _db.insert(
      'scan_roots',
      {'path': path, 'added_at': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    DatabaseChangeNotifier.instance.notify({'scan_roots'});
  }

  Future<void> remove(int id) async {
    await _db.delete('scan_roots', where: 'id = ?', whereArgs: [id]);
    DatabaseChangeNotifier.instance.notify({'scan_roots'});
  }
}
