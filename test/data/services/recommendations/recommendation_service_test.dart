import 'package:flutter_test/flutter_test.dart';
import 'package:ta_music/data/models/song.dart';
import 'package:ta_music/data/services/recommendations/recommendation_service.dart';

Song _song({
  required int id,
  String? path,
  String? artist,
  String? albumArtist,
  String? title,
  int? albumId,
  int playCount = 0,
  int skipCount = 0,
  int consecutiveSkips = 0,
}) {
  return Song(
    id: id,
    // Unique folder per song by default so tests that don't care about the
    // folder signal don't accidentally trigger it against each other.
    path: path ?? 'C:/music/artist_$id/song_$id.mp3',
    title: title ?? 'Song $id',
    artist: artist,
    albumArtist: albumArtist,
    albumId: albumId,
    playCount: playCount,
    skipCount: skipCount,
    consecutiveSkips: consecutiveSkips,
    dateAdded: DateTime(2026, 1, 1),
  );
}

/// The play-count-similarity signal contributes a nonzero baseline even
/// when neither song has ever been played (identical play counts of 0 are
/// still "similar") — tests that aren't specifically exercising that signal
/// need to account for it rather than expecting an exact 0.0.
double _playCountBaseline(int seedPlayCount, int candidatePlayCount) =>
    kPlayCountSimilarityWeight * (1.0 / (1 + (candidatePlayCount - seedPlayCount).abs()));

void main() {
  group('similarity signals', () {
    test('same artist adds the artist weight', () {
      final seed = _song(id: 1, artist: 'Burna Boy');
      final sameArtist = _song(id: 2, artist: 'Burna Boy');
      final differentArtist = _song(id: 3, artist: 'Wizkid');

      final scores = {
        for (final s in scoreRecommendations(
          seed: seed,
          candidates: [sameArtist, differentArtist],
          coOccurrenceCounts: const {},
          seedPlayCount: 0,
        ))
          s.song.id!: s.score,
      };

      expect(scores[2], greaterThanOrEqualTo(kArtistWeight));
      expect(scores[2], greaterThan(scores[3]!));
    });

    test('a feat/collab tag counts as the same artist', () {
      final seed = _song(id: 1, artist: 'Wizkid');
      // A Burna Boy solo track never literally shares the `artist` field
      // with a "Wizkid feat. Burna Boy" track, but they should still match.
      final collab = _song(id: 2, artist: 'Burna Boy', title: 'Ye (feat. Wizkid)');
      final unrelated = _song(id: 3, artist: 'Davido');

      final scores = {
        for (final s in scoreRecommendations(
          seed: seed,
          candidates: [collab, unrelated],
          coOccurrenceCounts: const {},
          seedPlayCount: 0,
        ))
          s.song.id!: s.score,
      };

      expect(scores[2], greaterThanOrEqualTo(kArtistWeight));
      expect(scores[3], lessThan(scores[2]!));
    });

    test('same album adds the album weight', () {
      final seed = _song(id: 1, albumId: 10);
      final sameAlbum = _song(id: 2, albumId: 10);
      final differentAlbum = _song(id: 3, albumId: 20);
      final noAlbum = _song(id: 4);

      final scores = {
        for (final s in scoreRecommendations(
          seed: seed,
          candidates: [sameAlbum, differentAlbum, noAlbum],
          coOccurrenceCounts: const {},
          seedPlayCount: 0,
        ))
          s.song.id!: s.score,
      };

      final baseline = _playCountBaseline(0, 0);
      expect(scores[2], closeTo(kAlbumWeight + baseline, 1e-9));
      expect(scores[3], closeTo(baseline, 1e-9));
      expect(scores[4], closeTo(baseline, 1e-9));
    });

    test('same folder adds the folder weight', () {
      final seed = _song(id: 1, path: 'C:/music/Gospel/track1.mp3');
      final sameFolder = _song(id: 2, path: 'C:/music/Gospel/track2.mp3');
      final differentFolder = _song(id: 3, path: 'C:/music/Afrobeats/track3.mp3');

      final scores = {
        for (final s in scoreRecommendations(
          seed: seed,
          candidates: [sameFolder, differentFolder],
          coOccurrenceCounts: const {},
          seedPlayCount: 0,
        ))
          s.song.id!: s.score,
      };

      final baseline = _playCountBaseline(0, 0);
      expect(scores[2], closeTo(kFolderWeight + baseline, 1e-9));
      expect(scores[3], closeTo(baseline, 1e-9));
    });

    test('co-occurrence ratio scales the co-occurrence weight', () {
      final seed = _song(id: 1);
      final oftenTogether = _song(id: 2);
      final rarelyTogether = _song(id: 3);

      final scores = {
        for (final s in scoreRecommendations(
          seed: seed,
          candidates: [oftenTogether, rarelyTogether],
          // Seed played 10 times; song 2 co-occurred 8 of those, song 3 once.
          coOccurrenceCounts: {2: 8, 3: 1},
          seedPlayCount: 10,
        ))
          s.song.id!: s.score,
      };

      final baseline = _playCountBaseline(0, 0);
      expect(scores[2], closeTo(kCoOccurrenceWeight * 0.8 + baseline, 1e-9));
      expect(scores[3], closeTo(kCoOccurrenceWeight * 0.1 + baseline, 1e-9));
    });

    test('zero seed plays never divides by zero', () {
      final seed = _song(id: 1);
      final candidate = _song(id: 2);

      final scored = scoreRecommendations(
        seed: seed,
        candidates: [candidate],
        coOccurrenceCounts: const {2: 5},
        seedPlayCount: 0,
      );

      expect(scored.single.score.isFinite, isTrue);
    });

    test('closer play counts score higher than a big gap', () {
      final seed = _song(id: 1, playCount: 20);
      final close = _song(id: 2, playCount: 22);
      final far = _song(id: 3, playCount: 200);

      final scores = {
        for (final s in scoreRecommendations(
          seed: seed,
          candidates: [close, far],
          coOccurrenceCounts: const {},
          seedPlayCount: 0,
        ))
          s.song.id!: s.score,
      };

      expect(scores[2], greaterThan(scores[3]!));
    });
  });

  group('skip penalty', () {
    test('no penalty below the 5-plays/3-skips trigger', () {
      final seed = _song(id: 1);
      final fewPlaysManySkips = _song(id: 2, playCount: 4, skipCount: 4);
      final manyPlaysFewSkips = _song(id: 3, playCount: 10, skipCount: 2);

      final scores = {
        for (final s in scoreRecommendations(
          seed: seed,
          candidates: [fewPlaysManySkips, manyPlaysFewSkips],
          coOccurrenceCounts: const {},
          seedPlayCount: 0,
        ))
          s.song.id!: s.score,
      };

      expect(scores[2], closeTo(_playCountBaseline(0, 4), 1e-9));
      expect(scores[3], closeTo(_playCountBaseline(0, 10), 1e-9));
    });

    test('the first 2 skips are free once the trigger fires', () {
      final seed = _song(id: 1);
      // 5+ plays, exactly 3 skips: 1 penalized skip beyond the allowance.
      final candidate = _song(id: 2, playCount: 5, skipCount: 3);

      final scored = scoreRecommendations(
        seed: seed,
        candidates: [candidate],
        coOccurrenceCounts: const {},
        seedPlayCount: 0,
      );

      final expected = _playCountBaseline(0, 5) - kSkipPenaltyWeight;
      expect(scored.single.score, closeTo(expected, 1e-9));
    });

    test('penalty grows with each skip beyond the allowance', () {
      final seed = _song(id: 1);
      final candidate = _song(id: 2, playCount: 10, skipCount: 6);

      final scored = scoreRecommendations(
        seed: seed,
        candidates: [candidate],
        coOccurrenceCounts: const {},
        seedPlayCount: 0,
      );

      // 6 skips - 2 free = 4 penalized skips.
      final expected = _playCountBaseline(0, 10) - kSkipPenaltyWeight * 4;
      expect(scored.single.score, closeTo(expected, 1e-9));
    });
  });

  group('exclusions', () {
    test('the seed itself never appears in its own results', () {
      final seed = _song(id: 1);
      final scored = scoreRecommendations(
        seed: seed,
        candidates: [seed, _song(id: 2)],
        coOccurrenceCounts: const {},
        seedPlayCount: 0,
      );

      expect(scored.map((s) => s.song.id), isNot(contains(1)));
    });

    test('3+ consecutive skips excludes a song entirely', () {
      final seed = _song(id: 1, artist: 'Burna Boy');
      // Would otherwise score highly (same artist), but was skipped 3 times
      // in a row with no completion since.
      final dislikedButSameArtist = _song(
        id: 2,
        artist: 'Burna Boy',
        consecutiveSkips: 3,
      );

      final scored = scoreRecommendations(
        seed: seed,
        candidates: [dislikedButSameArtist],
        coOccurrenceCounts: const {},
        seedPlayCount: 0,
      );

      expect(scored, isEmpty);
    });

    test('2 consecutive skips does not exclude', () {
      final seed = _song(id: 1, artist: 'Burna Boy');
      final candidate = _song(id: 2, artist: 'Burna Boy', consecutiveSkips: 2);

      final scored = scoreRecommendations(
        seed: seed,
        candidates: [candidate],
        coOccurrenceCounts: const {},
        seedPlayCount: 0,
      );

      expect(scored, hasLength(1));
    });
  });

  group('empty / new-library handling', () {
    test('no candidates yields no recommendations', () {
      final seed = _song(id: 1);
      expect(
        rankRecommendations(
          seed: seed,
          candidates: const [],
          coOccurrenceCounts: const {},
          seedPlayCount: 0,
          limit: 10,
        ),
        isEmpty,
      );
    });
  });

  group('ranking', () {
    test('rankRecommendations sorts highest score first and respects limit', () {
      final seed = _song(id: 1, artist: 'Burna Boy', albumId: 10);
      final best = _song(id: 2, artist: 'Burna Boy', albumId: 10); // artist + album
      final middle = _song(id: 3, artist: 'Burna Boy'); // artist only
      final worst = _song(id: 4, artist: 'Someone Else');

      final ranked = rankRecommendations(
        seed: seed,
        candidates: [worst, middle, best],
        coOccurrenceCounts: const {},
        seedPlayCount: 0,
        limit: 2,
      );

      expect(ranked.map((s) => s.id), [2, 3]);
    });
  });
}
