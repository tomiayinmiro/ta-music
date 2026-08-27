import 'package:flutter_test/flutter_test.dart';
import 'package:ta_music/data/services/lyrics/lyrics_query_builder.dart';

void main() {
  group('buildLrclibQueryVariants — no feature tag', () {
    test('returns a single clean variant, not flagged last-resort', () {
      final variants = buildLrclibQueryVariants(artist: 'Wizkid', title: 'Essence');
      expect(variants, hasLength(1));
      expect(variants.single.artist, 'Wizkid');
      expect(variants.single.title, 'Essence');
      expect(variants.single.isLastResort, isFalse);
    });
  });

  group('buildLrclibQueryVariants — feature tag detected', () {
    late List<QueryVariant> variants;

    setUp(() {
      variants = buildLrclibQueryVariants(
        artist: 'Nathaniel Bassey',
        title: 'Olorun Agbaye [Feat. Chandler Moore & OBA]',
      );
    });

    test('produces 4 variants, tried in a fixed order', () {
      expect(variants, hasLength(4));
    });

    test('variant 1: feature info folded back into the title, primary artist alone', () {
      expect(variants[0].title, 'Olorun Agbaye (feat. Chandler Moore, OBA)');
      expect(variants[0].artist, 'Nathaniel Bassey');
      expect(variants[0].isLastResort, isFalse);
    });

    test('variant 2: clean title, every artist as one comma list', () {
      expect(variants[1].title, 'Olorun Agbaye');
      expect(variants[1].artist, 'Nathaniel Bassey, Chandler Moore, OBA');
      expect(variants[1].isLastResort, isFalse);
    });

    test('variant 3: clean title, primary artist with inline "feat." suffix', () {
      expect(variants[2].title, 'Olorun Agbaye');
      expect(variants[2].artist, 'Nathaniel Bassey feat. Chandler Moore, OBA');
      expect(variants[2].isLastResort, isFalse);
    });

    test('variant 4: clean title, primary artist ONLY — flagged last-resort', () {
      expect(variants[3].title, 'Olorun Agbaye');
      expect(variants[3].artist, 'Nathaniel Bassey');
      expect(variants[3].isLastResort, isTrue);
    });
  });

  test('a feature tag on the artist field alone still triggers the cascade', () {
    final variants = buildLrclibQueryVariants(
      artist: 'Dunsin Oyekan feat. Kim Burrell',
      title: 'Na You',
    );
    expect(variants, hasLength(4));
    expect(variants[3].artist, 'Dunsin Oyekan');
    expect(variants[3].isLastResort, isTrue);
  });

  group('bestOvhVariant', () {
    test('picks the sole variant when there is no feature tag', () {
      final variants = buildLrclibQueryVariants(artist: 'Wizkid', title: 'Essence');
      final best = bestOvhVariant(variants);
      expect(best.artist, 'Wizkid');
      expect(best.title, 'Essence');
    });

    test('picks variant 2 (clean title + combined-artist list) when features were detected', () {
      final variants = buildLrclibQueryVariants(
        artist: 'Nathaniel Bassey',
        title: 'Olorun Agbaye [Feat. Chandler Moore & OBA]',
      );
      final best = bestOvhVariant(variants);
      expect(best.title, 'Olorun Agbaye');
      expect(best.artist, 'Nathaniel Bassey, Chandler Moore, OBA');
      expect(best.isLastResort, isFalse);
    });
  });
}
