import 'package:sqflite/sqflite.dart';

import '../database_change_notifier.dart';

/// Raw key-value CRUD against the `settings` table.
class SettingsDao {
  SettingsDao(this._db);

  final Database _db;

  Future<String?> get(String key) async {
    final rows = await _db.query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> set(String key, String value) async {
    await _db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    DatabaseChangeNotifier.instance.notify({'settings'});
  }
}
