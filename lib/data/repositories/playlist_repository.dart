import '../database/daos/playlist_dao.dart';
import '../models/playlist.dart';
import 'reactive_query.dart';

/// Minimal for Phase 2: existence checks only, for the bulk-select
/// "Add to playlist" stub sheet on the library gallery. Full playlist CRUD
/// (create/rename/delete/add-remove-song/reorder) lands in Phase 4.
class PlaylistRepository {
  PlaylistRepository(this._dao);

  final PlaylistDao _dao;

  Stream<List<Playlist>> watchAll() => watchQuery({'playlists'}, _dao.getAll);

  Future<bool> hasAny() async => (await _dao.count()) > 0;
}
