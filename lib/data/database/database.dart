import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Schema version. Bump this and add a new entry to [_migrations] for every
/// change — never edit an already-shipped migration in place.
const int kDatabaseVersion = 3;

typedef _Migration = Future<void> Function(Database db);

/// Ordered migrations, keyed by the version they migrate *to*.
/// [_onUpgrade] replays every entry between the installed version and
/// [kDatabaseVersion] in order, so this map must stay dense (1, 2, 3, ...).
final Map<int, _Migration> _migrations = {
  1: _migrationV1,
  2: _migrationV2,
  3: _migrationV3,
};

/// Must be called once, before any [AppDatabase.instance] access, so the
/// FFI factory is in place on Windows before sqflite tries to open a file.
/// On Android the default sqflite factory (backed by the platform's native
/// SQLite) is already correct and this is a no-op.
void initializeDatabaseFactory() {
  if (Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}

class AppDatabase {
  AppDatabase._();

  /// The in-flight/resolved open [Future] itself is memoized — not just the
  /// resolved [Database] — so that two callers racing before the first
  /// `openDatabase()` call completes both await the *same* Future instead
  /// of each starting their own. With only the resolved value cached (the
  /// old `_db ??= await _open()` pattern), a second caller arriving while
  /// the first `_open()` is still pending would see `_db == null` too and
  /// open a second connection to the same file — two connections both
  /// running `onCreate`/`onUpgrade` transactions concurrently collide with
  /// `DatabaseException(database is locked (code 5 SQLITE_BUSY))` on
  /// `BEGIN EXCLUSIVE`. This shouldn't normally happen within one isolate
  /// (Riverpod's `FutureProvider` already dedupes concurrent watchers), but
  /// it's cheap, correct insurance regardless of what calls this — e.g. if
  /// `audio_service` ever ends up running its own separate FlutterEngine
  /// (see `MainActivity.kt` for why it shouldn't).
  static Future<Database>? _dbFuture;

  /// Test-only override for the database path — e.g. sqflite's
  /// [inMemoryDatabasePath] sentinel, so tests never touch path_provider's
  /// platform channel (unavailable outside a widget-test binding) or disk.
  static String? debugDatabasePath;

  static Future<Database> get instance => _dbFuture ??= _open();

  static Future<Database> _open() async {
    final path = debugDatabasePath ??
        p.join((await getApplicationSupportDirectory()).path, 'ta_music.db');
    return openDatabase(
      path,
      version: kDatabaseVersion,
      onCreate: (db, version) async {
        for (var v = 1; v <= version; v++) {
          await _migrations[v]!(db);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        for (var v = oldVersion + 1; v <= newVersion; v++) {
          await _migrations[v]!(db);
        }
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  /// Test-only: closes and drops the cached instance so a fresh in-memory
  /// or temp-file database can be opened for the next test.
  static Future<void> resetForTest() async {
    final future = _dbFuture;
    _dbFuture = null;
    if (future != null) {
      await (await future).close();
    }
  }
}

Future<void> _migrationV1(Database db) async {
  await db.execute('''
    CREATE TABLE songs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      path TEXT NOT NULL UNIQUE,
      title TEXT,
      artist TEXT,
      album TEXT,
      album_artist TEXT,
      genre TEXT,
      year INTEGER,
      track_number INTEGER,
      disc_number INTEGER,
      duration_ms INTEGER,
      file_size INTEGER,
      format TEXT,
      sample_rate INTEGER,
      bit_rate INTEGER,
      date_added INTEGER NOT NULL,
      last_modified INTEGER,
      play_count INTEGER NOT NULL DEFAULT 0,
      last_played_at INTEGER,
      is_excluded INTEGER NOT NULL DEFAULT 0
    )
  ''');

  await db.execute('''
    CREATE TABLE albums (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT,
      artist TEXT,
      year INTEGER,
      cover_art_path TEXT
    )
  ''');

  await db.execute('''
    CREATE TABLE artists (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT
    )
  ''');

  await db.execute('''
    CREATE TABLE playlists (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      description TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      cover_art_path TEXT
    )
  ''');

  await db.execute('''
    CREATE TABLE playlist_songs (
      playlist_id INTEGER NOT NULL,
      song_id INTEGER NOT NULL,
      position INTEGER NOT NULL,
      added_at INTEGER NOT NULL,
      PRIMARY KEY (playlist_id, song_id),
      FOREIGN KEY (playlist_id) REFERENCES playlists (id) ON DELETE CASCADE,
      FOREIGN KEY (song_id) REFERENCES songs (id) ON DELETE CASCADE
    )
  ''');

  await db.execute('''
    CREATE TABLE favorites (
      song_id INTEGER PRIMARY KEY,
      added_at INTEGER NOT NULL,
      is_manual INTEGER NOT NULL,
      FOREIGN KEY (song_id) REFERENCES songs (id) ON DELETE CASCADE
    )
  ''');

  await db.execute('''
    CREATE TABLE play_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      song_id INTEGER NOT NULL,
      played_at INTEGER NOT NULL,
      completed INTEGER NOT NULL,
      FOREIGN KEY (song_id) REFERENCES songs (id) ON DELETE CASCADE
    )
  ''');

  await db.execute('''
    CREATE TABLE excluded_folders (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      path TEXT NOT NULL UNIQUE
    )
  ''');

  await db.execute('''
    CREATE TABLE lyrics (
      song_id INTEGER PRIMARY KEY,
      lyrics_text TEXT,
      is_synced INTEGER NOT NULL DEFAULT 0,
      source TEXT,
      fetched_at INTEGER,
      translation_text TEXT,
      translation_language TEXT,
      FOREIGN KEY (song_id) REFERENCES songs (id) ON DELETE CASCADE
    )
  ''');

  await db.execute('''
    CREATE TABLE custom_eq_presets (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      bands_json TEXT NOT NULL,
      created_at INTEGER NOT NULL
    )
  ''');

  await db.execute('CREATE INDEX idx_songs_is_excluded ON songs (is_excluded)');
  await db.execute('CREATE INDEX idx_play_history_song_id ON play_history (song_id)');
}

/// Adds the FK links Phase 1's schema was missing (songs.artist/album were
/// plain text with no relation to the artists/albums tables — grouping by
/// them required fragile text matching and gave cover-art storage nothing
/// stable to key off), a `scan_roots` table for the folders the scanner
/// should walk (Phase 1 only added `excluded_folders`), and `is_missing` to
/// soft-delete songs whose files vanish between scans without touching
/// `is_excluded`, which is reserved for voice-memo/user-exclusion rules.
Future<void> _migrationV2(Database db) async {
  await db.execute('ALTER TABLE songs ADD COLUMN album_id INTEGER REFERENCES albums (id)');
  await db.execute('ALTER TABLE songs ADD COLUMN artist_id INTEGER REFERENCES artists (id)');
  await db.execute(
      'ALTER TABLE songs ADD COLUMN is_missing INTEGER NOT NULL DEFAULT 0');

  await db.execute('''
    CREATE TABLE scan_roots (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      path TEXT NOT NULL UNIQUE,
      added_at INTEGER NOT NULL
    )
  ''');

  await db.execute('CREATE INDEX idx_songs_album_id ON songs (album_id)');
  await db.execute('CREATE INDEX idx_songs_artist_id ON songs (artist_id)');
  await db.execute('CREATE INDEX idx_songs_is_missing ON songs (is_missing)');
}

/// Phase 3 (Playback engine): a small key-value store for app-level
/// preferences that don't belong to any single row elsewhere — starting
/// with "resume playback after an audio-focus interruption ends" (default
/// off). Kept in sqflite rather than adding `shared_preferences`, staying
/// consistent with the rest of the app's storage and giving Phase 7's full
/// Settings screen a home to grow into. Approved 2026-08-18.
Future<void> _migrationV3(Database db) async {
  await db.execute('''
    CREATE TABLE settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''');
}
