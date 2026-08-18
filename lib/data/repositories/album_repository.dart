import '../database/daos/album_dao.dart';
import '../models/album.dart';
import 'reactive_query.dart';

class AlbumRepository {
  AlbumRepository(this._dao);

  final AlbumDao _dao;

  Stream<List<Album>> watchAll() => watchQuery({'albums'}, _dao.getAll);

  Future<Album?> getById(int id) => _dao.getById(id);
}
