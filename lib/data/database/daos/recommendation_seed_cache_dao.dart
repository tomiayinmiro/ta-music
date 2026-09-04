import 'package:sqflite/sqflite.dart';

import '../../models/recommendation_seed_cache.dart';
import '../database_change_notifier.dart';

/// Raw CRUD against the single-row `recommendation_seed_cache` table — see
/// `_migrationV14` and `RecommendationSeedCache`'s doc.
class RecommendationSeedCacheDao {
  RecommendationSeedCacheDao(this._db);

  final Database _db;

  Future<RecommendationSeedCache?> get() async {
    final rows = await _db.query('recommendation_seed_cache', where: 'id = 1', limit: 1);
    return rows.isEmpty ? null : RecommendationSeedCache.fromMap(rows.first);
  }

  Future<void> set(RecommendationSeedCache cache) async {
    await _db.insert(
      'recommendation_seed_cache',
      cache.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    DatabaseChangeNotifier.instance.notify({'recommendation_seed_cache'});
  }

  Future<void> clear() async {
    await _db.delete('recommendation_seed_cache', where: 'id = 1');
    DatabaseChangeNotifier.instance.notify({'recommendation_seed_cache'});
  }
}
