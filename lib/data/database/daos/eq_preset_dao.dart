import 'package:sqflite/sqflite.dart';

import '../../models/eq_preset.dart';
import '../database_change_notifier.dart';

/// Raw CRUD against the `custom_eq_presets` table.
class EqPresetDao {
  EqPresetDao(this._db);

  final Database _db;

  Future<List<EqPreset>> getAll() async {
    final rows = await _db.query('custom_eq_presets', orderBy: 'created_at DESC');
    return rows.map(EqPreset.fromMap).toList();
  }

  Future<int> insert(EqPreset preset) async {
    final id = await _db.insert('custom_eq_presets', preset.toMap());
    DatabaseChangeNotifier.instance.notify({'custom_eq_presets'});
    return id;
  }

  Future<void> update(EqPreset preset) async {
    await _db.update(
      'custom_eq_presets',
      preset.toMap(),
      where: 'id = ?',
      whereArgs: [preset.id],
    );
    DatabaseChangeNotifier.instance.notify({'custom_eq_presets'});
  }

  Future<void> delete(int id) async {
    await _db.delete('custom_eq_presets', where: 'id = ?', whereArgs: [id]);
    DatabaseChangeNotifier.instance.notify({'custom_eq_presets'});
  }
}
