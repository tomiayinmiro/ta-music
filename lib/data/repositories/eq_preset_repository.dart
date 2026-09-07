import '../database/daos/eq_preset_dao.dart';
import '../models/eq_preset.dart';
import 'reactive_query.dart';

class EqPresetRepository {
  EqPresetRepository(this._dao);

  final EqPresetDao _dao;

  Stream<List<EqPreset>> watchAll() => watchQuery({'custom_eq_presets'}, _dao.getAll);

  Future<int> save({required String name, required EqPresetIcon icon, required List<double> bandGains}) {
    return _dao.insert(EqPreset(name: name, icon: icon, bandGains: bandGains, createdAt: DateTime.now()));
  }

  Future<void> rename(EqPreset preset, String newName) => _dao.update(preset.copyWith(name: newName));

  Future<void> delete(int id) => _dao.delete(id);
}
