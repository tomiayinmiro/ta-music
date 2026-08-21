import 'package:sqflite/sqflite.dart';

import '../database_change_notifier.dart';

/// Raw CRUD against the single-row `aura_state` table. `id` is pinned to 1
/// by the table's CHECK constraint, same convention as `playback_state`.
class AuraStateDao {
  AuraStateDao(this._db);

  final Database _db;

  Future<Map<String, Object?>?> load() async {
    final rows = await _db.query('aura_state', where: 'id = 1', limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> save(Map<String, Object?> row) async {
    await _db.insert(
      'aura_state',
      {'id': 1, ...row},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    DatabaseChangeNotifier.instance.notify({'aura_state'});
  }
}
