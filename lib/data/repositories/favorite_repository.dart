import '../database/daos/favorite_dao.dart';
import '../models/favorite.dart';
import 'reactive_query.dart';

class FavoriteRepository {
  FavoriteRepository(this._dao);

  final FavoriteDao _dao;

  /// Sorted by play count, most-played first, 0-play songs excluded — per
  /// CLAUDE.md's Favorites collection rule.
  Stream<List<Favorite>> watchAllSortedByPlayCount() =>
      watchQuery({'favorites', 'songs'}, _dao.getAllSortedByPlayCount);

  Future<bool> isFavorite(int songId) => _dao.isFavorite(songId);

  Future<void> setFavorite(int songId, bool isFavorite) =>
      isFavorite ? _dao.add(songId, isManual: true) : _dao.remove(songId);
}
