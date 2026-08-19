import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ta_music/data/database/database.dart';

const _expectedTables = {
  'songs',
  'albums',
  'artists',
  'playlists',
  'playlist_songs',
  'favorites',
  'play_history',
  'excluded_folders',
  'lyrics',
  'custom_eq_presets',
  'scan_roots',
  'settings',
  'playback_state',
};

void main() {
  setUpAll(() {
    // `flutter test` always runs on the host Dart VM, not a real Android
    // device, so sqflite's platform-channel implementation isn't available
    // here regardless of target platform — FFI is forced for this run only.
    // This proves the schema/migration SQL is correct; real on-device
    // behavior is still confirmed by running the app per the Phase 1 report.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Avoids path_provider's platform channel too (also unavailable here).
    AppDatabase.debugDatabasePath = inMemoryDatabasePath;
  });

  tearDown(() async {
    await AppDatabase.resetForTest();
  });

  test('database initializes and creates exactly the expected tables', () async {
    final db = await AppDatabase.instance;

    final rows = await db.query(
      'sqlite_master',
      columns: ['name'],
      where: "type = 'table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'",
    );
    final tableNames = rows.map((r) => r['name'] as String).toSet();

    expect(tableNames, _expectedTables);
  });

  test('all tables start empty', () async {
    final db = await AppDatabase.instance;
    for (final table in _expectedTables) {
      final count =
          Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $table'));
      expect(count, 0, reason: '$table should start empty');
    }
  });

  test('foreign keys are enforced', () async {
    final db = await AppDatabase.instance;
    final result = await db.rawQuery('PRAGMA foreign_keys');
    expect(Sqflite.firstIntValue(result), 1);
  });
}
