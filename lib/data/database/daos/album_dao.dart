import 'package:sqflite/sqflite.dart';

import '../../models/album.dart';
import '../database_change_notifier.dart';

/// Raw CRUD against the `albums` table, plus scanner upsert support.
class AlbumDao {
  AlbumDao(this._db);

  final Database _db;

  Future<List<Album>> getAll({String orderBy = 'name COLLATE NOCASE'}) async {
    final rows = await _db.query('albums', orderBy: orderBy);
    return rows.map(Album.fromMap).toList();
  }

  Future<Album?> getById(int id) async {
    final rows = await _db.query('albums', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Album.fromMap(rows.first);
  }

  Future<Album?> findByNameAndArtist(String? name, String? artist) async {
    // sqflite's whereArgs rejects null outright (even bound to `IS ?`), so
    // NULL has to be matched with a literal `IS NULL` instead of a param.
    final clauses = <String>[];
    final args = <Object?>[];
    if (name == null) {
      clauses.add('name IS NULL');
    } else {
      clauses.add('name = ?');
      args.add(name);
    }
    if (artist == null) {
      clauses.add('artist IS NULL');
    } else {
      clauses.add('artist = ?');
      args.add(artist);
    }
    final rows = await _db.query(
      'albums',
      where: clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      limit: 1,
    );
    return rows.isEmpty ? null : Album.fromMap(rows.first);
  }

  /// Finds an existing album by (name, artist) or inserts a new one.
  /// Returns the resolved album id.
  Future<int> upsert(Album album) async {
    final existing = await findByNameAndArtist(album.name, album.artist);
    if (existing != null) {
      if (album.year != existing.year || album.coverArtPath != null) {
        await _db.update(
          'albums',
          {
            'year': album.year ?? existing.year,
            'cover_art_path': album.coverArtPath ?? existing.coverArtPath,
          },
          where: 'id = ?',
          whereArgs: [existing.id],
        );
        DatabaseChangeNotifier.instance.notify({'albums'});
      }
      return existing.id!;
    }
    final id = await _db.insert('albums', album.toMap());
    DatabaseChangeNotifier.instance.notify({'albums'});
    return id;
  }

  Future<void> setCoverArtPath(int id, String coverArtPath) async {
    await _db.update('albums', {'cover_art_path': coverArtPath}, where: 'id = ?', whereArgs: [id]);
    DatabaseChangeNotifier.instance.notify({'albums'});
  }

  /// Nulls every album's `cover_art_path` — the DB half of the Storage &
  /// Cache screen's "Album cover art" clear action (the other half deletes
  /// the actual `covers/*.jpg` files on disk). Same mechanism `_migrationV11`
  /// used to force a one-time regeneration; here it's user-triggered instead
  /// of a migration, but the effect on the next library scan is identical —
  /// `LibraryScanner._ensureCoverArt` treats a null path as "not extracted
  /// yet" and regenerates it.
  Future<void> clearAllCoverArtPaths() async {
    await _db.update('albums', {'cover_art_path': null});
    DatabaseChangeNotifier.instance.notify({'albums'});
  }
}
