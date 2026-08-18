import '../database/daos/artist_dao.dart';
import '../models/artist.dart';
import 'reactive_query.dart';

class ArtistRepository {
  ArtistRepository(this._dao);

  final ArtistDao _dao;

  Stream<List<Artist>> watchAll() => watchQuery({'artists'}, _dao.getAll);

  Future<Artist?> getById(int id) => _dao.getById(id);
}
