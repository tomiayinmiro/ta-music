import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../database/daos/aura_state_dao.dart';
import '../database/daos/favorite_dao.dart';
import '../database/daos/lyrics_cache_dao.dart';
import '../database/daos/play_history_dao.dart';
import '../database/daos/playlist_dao.dart';
import '../database/daos/recommendation_seed_cache_dao.dart';
import '../database/daos/song_dao.dart';
import '../services/backup/backup_export_service.dart';
import '../services/backup/backup_import_service.dart';
import '../services/backup/backup_models.dart';
import 'settings_repository.dart';

/// Filename convention for exported backups: `ta-music-backup-YYYY-MM-DD.json`.
String backupFileName([DateTime? now]) {
  final date = now ?? DateTime.now();
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return 'ta-music-backup-$y-$m-$d.json';
}

/// Orchestrates export/import for the Settings "Backup & Restore" section.
/// Deliberately has no `file_picker` dependency of its own — matching this
/// codebase's existing convention (see `SettingsScreen._addScanFolder`) of
/// calling `FilePicker` directly from the widget and handing this layer
/// plain bytes/strings, so this repository (and its tests) never need a
/// platform channel. JSON encode/decode for a large history is offloaded to
/// a background isolate via [compute] — the DB reads/writes themselves
/// can't cross isolates (sqflite), but they're batched, not the slow part;
/// encoding/decoding tens of thousands of rows' worth of JSON is.
class BackupRepository {
  BackupRepository({
    required SongDao songDao,
    required PlaylistDao playlistDao,
    required FavoriteDao favoriteDao,
    required PlayHistoryDao playHistoryDao,
    required AuraStateDao auraStateDao,
    required LyricsCacheDao lyricsCacheDao,
    required RecommendationSeedCacheDao recommendationSeedCacheDao,
    required SettingsRepository settingsRepository,
  }) : _exportService = BackupExportService(
         songDao: songDao,
         playlistDao: playlistDao,
         favoriteDao: favoriteDao,
         playHistoryDao: playHistoryDao,
         auraStateDao: auraStateDao,
         lyricsCacheDao: lyricsCacheDao,
         recommendationSeedCacheDao: recommendationSeedCacheDao,
         settingsRepository: settingsRepository,
       ),
       _importService = BackupImportService(
         songDao: songDao,
         playlistDao: playlistDao,
         favoriteDao: favoriteDao,
         playHistoryDao: playHistoryDao,
         lyricsCacheDao: lyricsCacheDao,
         recommendationSeedCacheDao: recommendationSeedCacheDao,
         settingsRepository: settingsRepository,
       );

  final BackupExportService _exportService;
  final BackupImportService _importService;

  /// Builds the full export payload and returns it already JSON-encoded,
  /// ready to hand to `FilePicker.saveFile`. The encode itself runs on a
  /// worker isolate via [compute] (needs a top-level/static function, hence
  /// [_encodeToJson] below) — the payload map is plain, isolate-safe data
  /// by the time it gets there.
  Future<String> buildExportJson({required String appVersion}) async {
    final payload = await _exportService.buildPayload(appVersion: appVersion);
    return compute(_encodeToJson, payload.toJson());
  }

  /// Parses, validates, and applies [raw] JSON. Throws
  /// [BackupFormatException] for anything that makes the whole file
  /// unusable — corrupted JSON, an unsupported `backup_format_version`, or
  /// a backup with no data — which the caller should show as a plain error
  /// dialog rather than an import summary. Decoding runs on a worker
  /// isolate via [compute] for a large backup file.
  Future<ImportSummary> importFromJson(String raw) async {
    final Map<String, Object?> decoded;
    try {
      decoded = await compute(_decodeJson, raw);
    } catch (_) {
      // Covers both a malformed JSON string (FormatException) and
      // well-formed JSON that isn't an object at its root (a cast error) —
      // either way, this isn't a readable TA Music backup.
      throw BackupFormatException('This backup file is corrupted or not valid JSON.');
    }
    final BackupPayload payload;
    try {
      payload = BackupPayload.fromJson(decoded);
    } on BackupFormatException {
      rethrow;
    } catch (_) {
      throw BackupFormatException('This backup file is corrupted or not a valid TA Music backup.');
    }
    return _importService.import(payload);
  }
}

Map<String, Object?> _decodeJson(String raw) => jsonDecode(raw) as Map<String, Object?>;

String _encodeToJson(Map<String, Object?> json) => jsonEncode(json);
