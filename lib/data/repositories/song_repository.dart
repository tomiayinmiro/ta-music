import '../database/daos/play_history_dao.dart';
import '../database/daos/song_dao.dart';
import '../models/play_history_entry.dart';
import '../models/song.dart';
import 'reactive_query.dart';

class SongRepository {
  SongRepository(this._songDao, this._playHistoryDao);

  final SongDao _songDao;
  final PlayHistoryDao _playHistoryDao;

  Stream<List<Song>> watchAllVisible() => watchQuery({'songs'}, _songDao.getAllVisible);

  Stream<List<Song>> watchByAlbum(int albumId) =>
      watchQuery({'songs'}, () => _songDao.getByAlbumId(albumId));

  Stream<List<Song>> watchByArtist(int artistId) =>
      watchQuery({'songs'}, () => _songDao.getByArtistId(artistId));

  Stream<List<Song>> watchSingles() => watchQuery({'songs'}, _songDao.getSingles);

  /// Songs added in the last 14 days, per CLAUDE.md's Recently Added rule.
  Stream<List<Song>> watchRecentlyAdded() => watchQuery(
        {'songs'},
        () => _songDao.getRecentlyAdded(since: DateTime.now().subtract(const Duration(days: 14))),
      );

  Stream<List<Song>> watchRecentlyPlayed({int limit = 20}) =>
      watchQuery({'songs'}, () => _songDao.getRecentlyPlayed(limit: limit));

  Stream<int> watchLibrarySize() => watchQuery({'songs'}, _songDao.countVisible);

  Future<Song?> getById(int id) => _songDao.getById(id);

  Future<List<Song>> getByIds(List<int> ids) => _songDao.getByIds(ids);

  Future<void> setExcluded(int id, bool excluded) => _songDao.markExcluded(id, excluded);

  /// Records one play: increments `songs.play_count` and inserts a
  /// `play_history` row, returning its id. Called once per listen, at
  /// whichever comes first of the 50%-played mark or natural completion
  /// (see `AudioPlayerHandler`) — never twice for the same listen. If the
  /// listen was already counted at 50% and later actually finishes, call
  /// [markPlayCompleted] with this id instead of recording a second play.
  Future<int> recordPlay(int songId, {required bool completed}) async {
    final now = DateTime.now();
    await _songDao.incrementPlayCount(songId, now);
    return _playHistoryDao.insert(PlayHistoryEntry(songId: songId, playedAt: now, completed: completed));
  }

  Future<void> markPlayCompleted(int playHistoryId) => _playHistoryDao.markCompleted(playHistoryId);
}
