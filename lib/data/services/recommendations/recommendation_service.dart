import 'dart:math' as math;

import 'package:path/path.dart' as p;

import '../../models/song.dart';
import '../lyrics/feature_tag_parser.dart';

// Similarity weights — starting values per the Phase 6 batch 1 spec, tuned
// later against real listening behavior rather than up front.
const double kArtistWeight = 3.0;
const double kAlbumWeight = 2.5;
const double kFolderWeight = 2.0;
const double kCoOccurrenceWeight = 4.0;
const double kPlayCountSimilarityWeight = 0.5;

/// Per-skip penalty once the down-rank trigger below fires.
const double kSkipPenaltyWeight = 2.0;

/// The first two skips on an otherwise-reasonable candidate are free —
/// approved 2026-09-02: accidental/impatient skips shouldn't tank a song's
/// ranking on their own.
const int kSkipFreeAllowance = 2;

/// The down-rank penalty only applies once a candidate has actually been
/// given a fair chance (5+ plays) and is still being skipped often (3+ of
/// them) — a song skipped twice out of two plays isn't enough evidence of
/// dislike yet.
const int kMinPlaysForSkipPenalty = 5;
const int kMinSkipsForPenalty = 3;

/// Hard exclusion: 3+ skips in a row with no intervening real play. Tracked
/// live on `songs.consecutive_skips` (resets on any counted play), so "no
/// completions" is automatically true whenever this is non-zero.
const int kConsecutiveSkipExclusionThreshold = 3;

/// One candidate's computed similarity score against a seed song. The score
/// itself is only exposed for tests — UI code only ever needs [song] via
/// [rankRecommendations].
class ScoredSong {
  const ScoredSong({required this.song, required this.score});

  final Song song;
  final double score;
}

/// Ranks [candidates] by local-taste similarity to [seed] and returns the
/// top [limit] songs, highest score first.
///
/// [coOccurrenceCounts] maps a candidate's song id to how many times it was
/// played within 30 minutes of one of the seed's own plays (see
/// `RecommendationRepository.recommendationsFor`, which builds this from
/// `play_history`) — deduped so an overlap between two seed-play windows
/// never double-counts the same candidate play. [seedPlayCount] is the
/// seed's total play count, the co-occurrence ratio's denominator.
///
/// Pure and DB-free by design (mirrors `relative_queue_index.dart`'s
/// pattern) so the scoring logic itself is directly unit-testable without a
/// real database.
List<Song> rankRecommendations({
  required Song seed,
  required List<Song> candidates,
  required Map<int, int> coOccurrenceCounts,
  required int seedPlayCount,
  required int limit,
}) {
  return scoreRecommendations(
    seed: seed,
    candidates: candidates,
    coOccurrenceCounts: coOccurrenceCounts,
    seedPlayCount: seedPlayCount,
  ).take(limit).map((s) => s.song).toList();
}

/// Same ranking as [rankRecommendations], but returns every surviving
/// candidate with its score attached — split out so tests can assert on the
/// scoring itself, not just the final truncated order.
List<ScoredSong> scoreRecommendations({
  required Song seed,
  required List<Song> candidates,
  required Map<int, int> coOccurrenceCounts,
  required int seedPlayCount,
}) {
  final seedArtistNames = _artistNames(seed);
  final seedFolder = _folderOf(seed.path);

  final scored = <ScoredSong>[];
  for (final candidate in candidates) {
    if (candidate.id == null || candidate.id == seed.id) continue;
    // Exclusion: 3+ skips in a row with no completion since — see class doc.
    if (candidate.consecutiveSkips >= kConsecutiveSkipExclusionThreshold) continue;

    var score = 0.0;

    if (seedArtistNames.intersection(_artistNames(candidate)).isNotEmpty) {
      score += kArtistWeight;
    }

    if (seed.albumId != null && seed.albumId == candidate.albumId) {
      score += kAlbumWeight;
    }

    if (seedFolder != null && seedFolder == _folderOf(candidate.path)) {
      score += kFolderWeight;
    }

    if (seedPlayCount > 0) {
      final coOccurring = coOccurrenceCounts[candidate.id] ?? 0;
      score += kCoOccurrenceWeight * (coOccurring / seedPlayCount);
    }

    // Simple inverse-distance similarity: identical play counts score 1.0,
    // falling off as the gap between candidate and seed grows.
    final playCountGap = (candidate.playCount - seed.playCount).abs();
    score += kPlayCountSimilarityWeight * (1.0 / (1 + playCountGap));

    if (candidate.playCount >= kMinPlaysForSkipPenalty &&
        candidate.skipCount >= kMinSkipsForPenalty) {
      final penalizedSkips = math.max(0, candidate.skipCount - kSkipFreeAllowance);
      score -= kSkipPenaltyWeight * penalizedSkips;
    }

    scored.add(ScoredSong(song: candidate, score: score));
  }

  scored.sort((a, b) {
    final cmp = b.score.compareTo(a.score);
    return cmp != 0 ? cmp : b.song.playCount.compareTo(a.song.playCount);
  });
  return scored;
}

String? _folderOf(String path) {
  final dir = p.dirname(path);
  return dir.isEmpty ? null : dir.toLowerCase();
}

/// Every artist-ish name attached to [song], lowercased/trimmed: the raw
/// artist/album-artist tags, plus any feat/collab names embedded in the
/// artist or title text. Reuses `extractFeatureTags` (Phase 5's lyrics
/// query-matching parser) rather than duplicating "feat./ft./with" parsing
/// — a Burna Boy solo track and a "Wizkid feat. Burna Boy" track share a
/// name here even though neither song's plain `artist` field matches the
/// other's.
Set<String> _artistNames(Song song) {
  final names = <String>{};
  void add(String? raw) {
    if (raw == null) return;
    final trimmed = raw.trim().toLowerCase();
    if (trimmed.isNotEmpty) names.add(trimmed);
  }

  add(song.artist);
  add(song.albumArtist);
  for (final feature in extractFeatureTags(song.artist ?? '').features) {
    add(feature);
  }
  for (final feature in extractFeatureTags(song.title ?? '').features) {
    add(feature);
  }
  return names;
}
