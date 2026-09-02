import 'package:sqflite/sqflite.dart';

/// Aggregate counts for the Settings "Lyrics" screen's translation section —
/// total cached lines, and a breakdown by target language.
class TranslationCacheStats {
  const TranslationCacheStats({required this.totalRows, required this.countByTargetLang});

  final int totalRows;
  final Map<String, int> countByTargetLang;
}

/// Raw CRUD against `translations_cache`, keyed by (source_text, target_lang)
/// — see `_migrationV12`'s doc for why.
class TranslationsCacheDao {
  TranslationsCacheDao(this._db);

  final Database _db;

  Future<Map<String, Object?>?> find(String sourceText, String targetLang) async {
    final rows = await _db.query(
      'translations_cache',
      where: 'source_text = ? AND target_lang = ?',
      whereArgs: [sourceText, targetLang],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Upserts on the (source_text, target_lang) unique constraint — a
  /// translation never changes once produced, so this only ever runs once
  /// per line/language pair in practice, but replacing rather than ignoring
  /// on conflict keeps behavior well-defined if it's ever called twice.
  Future<void> upsert({
    required String sourceText,
    required String targetLang,
    required String translatedText,
    String? sourceLang,
    bool isSameLanguage = false,
    required DateTime translatedAt,
  }) async {
    await _db.insert('translations_cache', {
      'source_text': sourceText,
      'source_lang': sourceLang,
      'target_lang': targetLang,
      'translated_text': translatedText,
      'is_same_language': isSameLanguage ? 1 : 0,
      'translated_at': translatedAt.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<TranslationCacheStats> stats() async {
    final totalRows =
        Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM translations_cache')) ?? 0;

    final byTargetRows = await _db.rawQuery(
      'SELECT target_lang, COUNT(*) AS c FROM translations_cache GROUP BY target_lang',
    );
    final countByTargetLang = {
      for (final row in byTargetRows) row['target_lang'] as String: row['c'] as int,
    };

    return TranslationCacheStats(totalRows: totalRows, countByTargetLang: countByTargetLang);
  }

  /// Deletes every cached translation — Settings "Clear translation cache".
  Future<void> clearAll() async {
    await _db.delete('translations_cache');
  }
}
