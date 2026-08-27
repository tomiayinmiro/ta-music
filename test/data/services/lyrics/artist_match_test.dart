import 'package:flutter_test/flutter_test.dart';
import 'package:ta_music/data/services/lyrics/artist_match.dart';

void main() {
  group('isArtistFuzzyMatch', () {
    test('identical strings match', () {
      expect(isArtistFuzzyMatch('Dunsin Oyekan', 'Dunsin Oyekan'), isTrue);
    });

    test('case and whitespace differences match', () {
      expect(isArtistFuzzyMatch('  Dunsin Oyekan ', 'dunsin   oyekan'), isTrue);
    });

    test('a minor typo still matches', () {
      expect(isArtistFuzzyMatch('Ed Sheeran', 'Edd Sheeran'), isTrue);
    });

    test('one artist string containing the other matches (multi-artist superset)', () {
      expect(isArtistFuzzyMatch('Nosa', 'Nosa; Nathaniel Bassey'), isTrue);
      expect(isArtistFuzzyMatch('Dunsin Oyekan', 'Dunsin Oyekan, Lawrence Oyor'), isTrue);
    });

    test('the exact reported bug case rejects: completely different gospel artists', () {
      expect(isArtistFuzzyMatch('Dunsin Oyekan', 'Nathaniel Bassey'), isFalse);
      expect(isArtistFuzzyMatch('Dunsin Oyekan', 'Nosa; Nathaniel Bassey'), isFalse);
    });

    test('unrelated artists reject', () {
      expect(isArtistFuzzyMatch('Ed Sheeran', 'Vybz Kartel'), isFalse);
    });

    test('an empty queried or returned artist can\'t be verified, so it passes', () {
      expect(isArtistFuzzyMatch('', 'Dunsin Oyekan'), isTrue);
      expect(isArtistFuzzyMatch('Dunsin Oyekan', ''), isTrue);
      expect(isArtistFuzzyMatch('   ', 'Dunsin Oyekan'), isTrue);
    });

    test('a custom threshold can be made stricter or looser', () {
      // "Flavour" vs "Flavor" — 1-character edit on a short word.
      expect(isArtistFuzzyMatch('Flavour', 'Flavor', threshold: 0.8), isTrue);
      expect(isArtistFuzzyMatch('Flavour', 'Flavor', threshold: 0.99), isFalse);
    });
  });
}
