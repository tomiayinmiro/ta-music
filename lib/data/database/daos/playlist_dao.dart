import 'package:sqflite/sqflite.dart';

import '../../models/playlist.dart';
import '../../models/playlist_song.dart';
import '../../models/song.dart';
import '../database_change_notifier.dart';

/// Raw CRUD against the `playlists` and `playlist_songs` tables.
class PlaylistDao {
  PlaylistDao(this._db);

  final Database _db;

  Future<List<Playlist>> getAll({String orderBy = 'updated_at DESC'}) async {
    final rows = await _db.query('playlists', orderBy: orderBy);
    return rows.map(Playlist.fromMap).toList();
  }

  Future<Playlist?> getById(int id) async {
    final rows = await _db.query('playlists', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Playlist.fromMap(rows.first);
  }

  Future<int> count() async {
    final result = await _db.rawQuery('SELECT COUNT(*) AS c FROM playlists');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> insert(Playlist playlist) async {
    final id = await _db.insert('playlists', playlist.toMap());
    DatabaseChangeNotifier.instance.notify({'playlists'});
    return id;
  }

  Future<void> update(Playlist playlist) async {
    await _db.update(
      'playlists',
      playlist.toMap(),
      where: 'id = ?',
      whereArgs: [playlist.id],
    );
    DatabaseChangeNotifier.instance.notify({'playlists'});
  }

  /// `playlist_songs` rows cascade-delete via the FK's `ON DELETE CASCADE`.
  Future<void> delete(int id) async {
    await _db.delete('playlists', where: 'id = ?', whereArgs: [id]);
    DatabaseChangeNotifier.instance.notify({'playlists', 'playlist_songs'});
  }

  /// A playlist's songs, in position order.
  Future<List<Song>> getSongs(int playlistId) async {
    final rows = await _db.rawQuery('''
      SELECT s.* FROM playlist_songs ps
      JOIN songs s ON s.id = ps.song_id
      WHERE ps.playlist_id = ?
      ORDER BY ps.position
    ''', [playlistId]);
    return rows.map(Song.fromMap).toList();
  }

  /// Raw `playlist_songs` rows for [playlistId], in position order — backup
  /// export's source for a playlist's membership, since [getSongs] only
  /// returns resolved [Song]s and drops `position`/`added_at`.
  Future<List<PlaylistSong>> getMembershipRows(int playlistId) async {
    final rows = await _db.query(
      'playlist_songs',
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
      orderBy: 'position',
    );
    return rows.map(PlaylistSong.fromMap).toList();
  }

  Future<int> getSongCount(int playlistId) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM playlist_songs WHERE playlist_id = ?',
      [playlistId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getTotalDurationMs(int playlistId) async {
    final result = await _db.rawQuery('''
      SELECT COALESCE(SUM(s.duration_ms), 0) AS total FROM playlist_songs ps
      JOIN songs s ON s.id = ps.song_id
      WHERE ps.playlist_id = ?
    ''', [playlistId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Every playlist id that already contains [songId] — the add-to-playlist
  /// sheet's pre-checked state.
  Future<Set<int>> getPlaylistIdsContaining(int songId) async {
    final rows = await _db.query(
      'playlist_songs',
      columns: ['playlist_id'],
      where: 'song_id = ?',
      whereArgs: [songId],
    );
    return rows.map((row) => row['playlist_id'] as int).toSet();
  }

  /// Appends [songIds] to the end of [playlistId], skipping any already
  /// present (the table's primary key is `(playlist_id, song_id)`, so a
  /// plain insert would otherwise throw on a duplicate).
  Future<void> addSongs(int playlistId, List<int> songIds) async {
    if (songIds.isEmpty) return;
    final startResult = await _db.rawQuery(
      'SELECT COALESCE(MAX(position), -1) AS m FROM playlist_songs WHERE playlist_id = ?',
      [playlistId],
    );
    var nextPosition = (Sqflite.firstIntValue(startResult) ?? -1) + 1;
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = _db.batch();
    for (final songId in songIds) {
      batch.insert(
        'playlist_songs',
        {
          'playlist_id': playlistId,
          'song_id': songId,
          'position': nextPosition++,
          'added_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
    DatabaseChangeNotifier.instance.notify({'playlist_songs'});
  }

  Future<void> removeSong(int playlistId, int songId) async {
    await _db.delete(
      'playlist_songs',
      where: 'playlist_id = ? AND song_id = ?',
      whereArgs: [playlistId, songId],
    );
    DatabaseChangeNotifier.instance.notify({'playlist_songs'});
  }

  /// Moves the song at [oldIndex] to [newIndex] (both 0-based, in the
  /// playlist's current position order) and renumbers every row so
  /// positions stay a dense 0..n-1 sequence. [newIndex] is expected already
  /// adjusted for the removed item — the same convention
  /// `AudioPlayerHandler.reorderQueue` and `SliverReorderableList`'s
  /// `onReorderItem` (not the deprecated `onReorder`) use.
  Future<void> reorderSongs(int playlistId, int oldIndex, int newIndex) async {
    final songs = await getSongs(playlistId);
    if (oldIndex < 0 || oldIndex >= songs.length) return;
    final moved = songs.removeAt(oldIndex);
    songs.insert(newIndex.clamp(0, songs.length), moved);

    final batch = _db.batch();
    for (var i = 0; i < songs.length; i++) {
      batch.update(
        'playlist_songs',
        {'position': i},
        where: 'playlist_id = ? AND song_id = ?',
        whereArgs: [playlistId, songs[i].id],
      );
    }
    await batch.commit(noResult: true);
    DatabaseChangeNotifier.instance.notify({'playlist_songs'});
  }
}
