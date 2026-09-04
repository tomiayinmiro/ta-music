import '../database/daos/favorite_dao.dart';
import '../database/daos/play_history_dao.dart';
import '../database/daos/recommendation_seed_cache_dao.dart';
import '../database/daos/song_dao.dart';
import '../models/recommendation_seed_cache.dart';
import '../models/song.dart';
import '../services/recommendations/recommendation_service.dart';

/// A recently-played song is only considered as the Home seed if it shows a
/// strong-enough signal — otherwise "Because you played X" would surface
/// whatever song happened to be tapped last, not something the algorithm
/// actually has a real opinion about.
const int _kMinRecentPlaysForSeed = 3;

/// Below this many distinct played songs, there isn't enough listening
/// history for any recommendation to be more than noise — hide the Home
/// section entirely rather than show a section with barely-related songs.
///
/// Lowered from 5 to 2 (approved 2026-09-04, Android seed-selection
/// investigation): the existing seed-quality fallback chain in
/// [_pickHomeSeed] (3+ plays in 24h → favorited → most-played in 7 days)
/// already degrades gracefully for thin history — this gate was blocking
/// that chain from ever running at all for a new or freshly-reset install,
/// keeping the section invisible for longer than the seed logic itself
/// actually required.
const int _kMinDistinctPlayedSongsForHome = 2;

const Duration _kSeedCacheTtl = Duration(hours: 1);

/// Orchestrates the local recommendation engine: sources visible candidates
/// (voice memos and excluded folders are already filtered out by
/// `SongDao.getAllVisible`), builds the co-occurrence signal from
/// `play_history`, and delegates actual scoring to the pure
/// `recommendation_service.dart` functions. Also owns the Home "Because you
/// played X" seed's 1-hour cache.
class RecommendationRepository {
  RecommendationRepository(
    this._songDao,
    this._playHistoryDao,
    this._favoriteDao,
    this._seedCacheDao,
  );

  final SongDao _songDao;
  final PlayHistoryDao _playHistoryDao;
  final FavoriteDao _favoriteDao;
  final RecommendationSeedCacheDao _seedCacheDao;

  /// Ranked recommendations for [seed] — used by both surfaces (Home passes
  /// its auto-picked seed, "More like this" passes the user-selected song).
  Future<List<Song>> recommendationsFor(Song seed, {required int limit}) async {
    if (seed.id == null) return const [];

    final allVisible = await _songDao.getAllVisible();
    final candidates = allVisible.where((s) => s.id != seed.id).toList();
    if (candidates.isEmpty) return const [];

    final seedTimestamps = await _playHistoryDao.playedAtTimestampsForSong(seed.id!);
    final coOccurrence = await _playHistoryDao.coOccurringPlayCounts(
      excludeSongId: seed.id!,
      seedTimestamps: seedTimestamps,
    );

    return rankRecommendations(
      seed: seed,
      candidates: candidates,
      coOccurrenceCounts: coOccurrence,
      seedPlayCount: seedTimestamps.length,
      limit: limit,
    );
  }

  /// The Home section's seed song, or `null` when the section should be
  /// hidden (too little listening history, or nothing qualifies). Reuses a
  /// cached choice within its 1-hour TTL so the section doesn't reshuffle
  /// on every Lounge open — see `RecommendationSeedCache`.
  Future<Song?> homeSeed() async {
    final cached = await _seedCacheDao.get();
    if (cached != null && !cached.isExpired) {
      final song = await _songDao.getById(cached.songId);
      if (song != null) return song;
    }

    final distinctPlayed = await _playHistoryDao.distinctSongsPlayed();
    if (distinctPlayed < _kMinDistinctPlayedSongsForHome) return null;

    final seed = await _pickHomeSeed();
    if (seed?.id != null) {
      final now = DateTime.now();
      await _seedCacheDao.set(
        RecommendationSeedCache(
          songId: seed!.id!,
          selectedAt: now,
          expiresAt: now.add(_kSeedCacheTtl),
        ),
      );
    }
    return seed;
  }

  /// Forces a fresh seed pick on the next [homeSeed] call — Settings >
  /// Recommendations > "Clear recommendation cache".
  Future<void> clearSeedCache() => _seedCacheDao.clear();

  /// A recently played (last 24h) song with a strong signal — played 3+
  /// times in that window, or favorited — preferring whichever such song
  /// was played most in the window. Falls back to the single most-played
  /// song of the last 7 days when nothing in the last 24h qualifies.
  Future<Song?> _pickHomeSeed() async {
    final last24h = DateTime.now().subtract(const Duration(hours: 24));
    final recentTop = await _playHistoryDao.topSongIds(limit: 20, since: last24h);

    final favoritedIds = <int>{};
    for (final (songId, _) in recentTop) {
      if (await _favoriteDao.isFavorite(songId)) favoritedIds.add(songId);
    }

    for (final (songId, count) in recentTop) {
      if (count >= _kMinRecentPlaysForSeed || favoritedIds.contains(songId)) {
        final song = await _songDao.getById(songId);
        if (song != null) return song;
      }
    }

    final last7d = DateTime.now().subtract(const Duration(days: 7));
    final weeklyTop = await _playHistoryDao.topSongIds(limit: 1, since: last7d);
    if (weeklyTop.isEmpty) return null;
    return _songDao.getById(weeklyTop.first.$1);
  }
}
