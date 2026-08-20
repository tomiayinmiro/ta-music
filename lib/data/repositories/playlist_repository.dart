import '../database/daos/playlist_dao.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import 'reactive_query.dart';

/// A playlist's aggregate stats — song count and total duration — computed
/// alongside the list rather than requiring a separate round-trip per
/// playlist in the Playlists list screen.
class PlaylistSummary {
  const PlaylistSummary({required this.playlist, required this.songCount, required this.totalDurationMs});

  final Playlist playlist;
  final int songCount;
  final int totalDurationMs;
}

class PlaylistRepository {
  PlaylistRepository(this._dao);

  final PlaylistDao _dao;

  Stream<List<Playlist>> watchAll() => watchQuery({'playlists'}, _dao.getAll);

  Stream<Playlist?> watchById(int id) =>
      watchQuery({'playlists'}, () => _dao.getById(id));

  Stream<List<Song>> watchSongs(int playlistId) =>
      watchQuery({'playlist_songs', 'songs'}, () => _dao.getSongs(playlistId));

  Stream<List<PlaylistSummary>> watchAllWithSummaries() => watchQuery(
        {'playlists', 'playlist_songs', 'songs'},
        () async {
          final playlists = await _dao.getAll();
          final summaries = <PlaylistSummary>[];
          for (final playlist in playlists) {
            summaries.add(PlaylistSummary(
              playlist: playlist,
              songCount: await _dao.getSongCount(playlist.id!),
              totalDurationMs: await _dao.getTotalDurationMs(playlist.id!),
            ));
          }
          return summaries;
        },
      );

  Future<bool> hasAny() async => (await _dao.count()) > 0;

  Future<Set<int>> getPlaylistIdsContaining(int songId) =>
      _dao.getPlaylistIdsContaining(songId);

  Future<int> create({required String name, String? description}) async {
    final now = DateTime.now();
    return _dao.insert(Playlist(name: name, description: description, createdAt: now, updatedAt: now));
  }

  Future<void> rename(Playlist playlist, {required String name, String? description}) =>
      _dao.update(playlist.copyWith(name: name, description: description, updatedAt: DateTime.now()));

  Future<void> delete(int id) => _dao.delete(id);

  Future<void> addSongs(int playlistId, List<int> songIds) => _dao.addSongs(playlistId, songIds);

  Future<void> removeSong(int playlistId, int songId) => _dao.removeSong(playlistId, songId);

  Future<void> reorderSongs(int playlistId, int oldIndex, int newIndex) =>
      _dao.reorderSongs(playlistId, oldIndex, newIndex);

  /// Applies the add-to-playlist sheet's selection diff in one call: songs
  /// newly checked get added, songs newly unchecked get removed. Playlists
  /// untouched by the user aren't touched here.
  Future<void> applyMembership(int songId, {required Set<int> addTo, required Set<int> removeFrom}) async {
    for (final playlistId in addTo) {
      await _dao.addSongs(playlistId, [songId]);
    }
    for (final playlistId in removeFrom) {
      await _dao.removeSong(playlistId, songId);
    }
  }
}
