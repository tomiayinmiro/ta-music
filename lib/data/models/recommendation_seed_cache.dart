import 'package:flutter/foundation.dart';

/// The Home "Because you played X" section's currently-picked seed song,
/// mapped 1:1 to the single row in `recommendation_seed_cache`. Re-picking
/// a seed on every Lounge open would feel janky (the section reshuffling
/// under the user every time they tap Home), so the choice is cached with a
/// 1-hour TTL — see `RecommendationRepository.homeSeed`.
@immutable
class RecommendationSeedCache {
  const RecommendationSeedCache({
    required this.songId,
    required this.selectedAt,
    required this.expiresAt,
  });

  final int songId;
  final DateTime selectedAt;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory RecommendationSeedCache.fromMap(Map<String, Object?> map) {
    return RecommendationSeedCache(
      songId: map['current_seed_song_id'] as int,
      selectedAt: DateTime.fromMillisecondsSinceEpoch(map['selected_at'] as int),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(map['expires_at'] as int),
    );
  }

  Map<String, Object?> toMap() => {
    'id': 1,
    'current_seed_song_id': songId,
    'selected_at': selectedAt.millisecondsSinceEpoch,
    'expires_at': expiresAt.millisecondsSinceEpoch,
  };
}
