import '../database/daos/song_dao.dart';
import '../models/song.dart';
import 'reactive_query.dart';

class SongRepository {
  SongRepository(this._dao);

  final SongDao _dao;

  Stream<List<Song>> watchAllVisible() => watchQuery({'songs'}, _dao.getAllVisible);

  Stream<List<Song>> watchByAlbum(int albumId) =>
      watchQuery({'songs'}, () => _dao.getByAlbumId(albumId));

  Stream<List<Song>> watchByArtist(int artistId) =>
      watchQuery({'songs'}, () => _dao.getByArtistId(artistId));

  Stream<List<Song>> watchSingles() => watchQuery({'songs'}, _dao.getSingles);

  /// Songs added in the last 14 days, per CLAUDE.md's Recently Added rule.
  Stream<List<Song>> watchRecentlyAdded() => watchQuery(
        {'songs'},
        () => _dao.getRecentlyAdded(since: DateTime.now().subtract(const Duration(days: 14))),
      );

  Stream<List<Song>> watchRecentlyPlayed({int limit = 20}) =>
      watchQuery({'songs'}, () => _dao.getRecentlyPlayed(limit: limit));

  Stream<int> watchLibrarySize() => watchQuery({'songs'}, _dao.countVisible);

  Future<Song?> getById(int id) => _dao.getById(id);

  Future<void> setExcluded(int id, bool excluded) => _dao.markExcluded(id, excluded);

  Future<void> recordPlay(int songId) => _dao.incrementPlayCount(songId, DateTime.now());
}
