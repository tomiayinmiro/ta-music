import 'package:flutter_test/flutter_test.dart';
import 'package:ta_music/data/services/lyrics/feature_tag_parser.dart';

void main() {
  group('extractFeatureTags — bracket variants', () {
    test('square brackets with "Feat."', () {
      final result = extractFeatureTags('Olorun Agbaye [Feat. Chandler Moore & OBA]');
      expect(result.cleanText, 'Olorun Agbaye');
      expect(result.features, ['Chandler Moore', 'OBA']);
    });

    test('parens with "feat."', () {
      final result = extractFeatureTags('Essence (feat. Justin Bieber)');
      expect(result.cleanText, 'Essence');
      expect(result.features, ['Justin Bieber']);
    });

    test('square brackets with "ft."', () {
      final result = extractFeatureTags('For My Hand [ft. Ed Sheeran]');
      expect(result.cleanText, 'For My Hand');
      expect(result.features, ['Ed Sheeran']);
    });

    test('parens with bare "ft" (no period)', () {
      final result = extractFeatureTags('Song (ft Sarkodie)');
      expect(result.cleanText, 'Song');
      expect(result.features, ['Sarkodie']);
    });

    test('square brackets with "With"', () {
      final result = extractFeatureTags('Most High [With Nathaniel Bassey]');
      expect(result.cleanText, 'Most High');
      expect(result.features, ['Nathaniel Bassey']);
    });

    test('parens with "with" lowercase', () {
      final result = extractFeatureTags('I Will Follow (with Nathaniel Bassey)');
      expect(result.cleanText, 'I Will Follow');
      expect(result.features, ['Nathaniel Bassey']);
    });
  });

  group('extractFeatureTags — case variants', () {
    test('all-caps FEAT', () {
      final result = extractFeatureTags('Song [FEAT NATHANIEL BASSEY]');
      expect(result.cleanText, 'Song');
      expect(result.features, ['NATHANIEL BASSEY']);
    });

    test('mixed-case Feat.', () {
      final result = extractFeatureTags('Song (Feat. Kim Burrell)');
      expect(result.cleanText, 'Song');
      expect(result.features, ['Kim Burrell']);
    });
  });

  group('extractFeatureTags — bare suffix (no brackets)', () {
    test('trailing "feat." with no brackets', () {
      final result = extractFeatureTags('Most High feat. Nathaniel Bassey');
      expect(result.cleanText, 'Most High');
      expect(result.features, ['Nathaniel Bassey']);
    });

    test('trailing "ft" with no period, no brackets', () {
      final result = extractFeatureTags('Na You ft Kim Burrell');
      expect(result.cleanText, 'Na You');
      expect(result.features, ['Kim Burrell']);
    });
  });

  group('extractFeatureTags — multiple features / separators', () {
    test('comma-separated', () {
      final result = extractFeatureTags('Song [feat. A, B, C]');
      expect(result.features, ['A', 'B', 'C']);
    });

    test('"x" separator (Wizkid x Burna Boy style)', () {
      final result = extractFeatureTags('Song [feat. Wizkid x Burna Boy]');
      expect(result.features, ['Wizkid', 'Burna Boy']);
    });

    test('"and" separator', () {
      final result = extractFeatureTags('Song [feat. Wizkid and Burna Boy]');
      expect(result.features, ['Wizkid', 'Burna Boy']);
    });

    test('hyphenated guest name is not split on the "x" separator', () {
      final result = extractFeatureTags('Na You [Feat. Kim-Burell]');
      expect(result.features, ['Kim-Burell']);
    });

    test('multiple bracketed feat blocks in one string', () {
      final result = extractFeatureTags('Song [feat. A] (feat. B)');
      expect(result.cleanText, 'Song');
      expect(result.features, ['A', 'B']);
    });
  });

  group('extractFeatureTags — does NOT strip version discriminators', () {
    test('[Live] untouched', () {
      final result = extractFeatureTags('Song [Live]');
      expect(result.cleanText, 'Song [Live]');
      expect(result.features, isEmpty);
    });

    test('(Remix) untouched', () {
      final result = extractFeatureTags('Song (Remix)');
      expect(result.cleanText, 'Song (Remix)');
      expect(result.features, isEmpty);
    });

    test('- Live suffix untouched', () {
      final result = extractFeatureTags('Song - Live');
      expect(result.cleanText, 'Song - Live');
      expect(result.features, isEmpty);
    });

    test('(Acoustic) untouched', () {
      final result = extractFeatureTags('Song (Acoustic)');
      expect(result.cleanText, 'Song (Acoustic)');
      expect(result.features, isEmpty);
    });

    test('[Extended] untouched', () {
      final result = extractFeatureTags('Song [Extended]');
      expect(result.cleanText, 'Song [Extended]');
      expect(result.features, isEmpty);
    });

    test('[Radio Edit] untouched', () {
      final result = extractFeatureTags('Song [Radio Edit]');
      expect(result.cleanText, 'Song [Radio Edit]');
      expect(result.features, isEmpty);
    });

    test('[Instrumental] untouched', () {
      final result = extractFeatureTags('Song [Instrumental]');
      expect(result.cleanText, 'Song [Instrumental]');
      expect(result.features, isEmpty);
    });

    test('bare "with" suffix (no brackets) is left alone', () {
      final result = extractFeatureTags('Dancing with Myself');
      expect(result.cleanText, 'Dancing with Myself');
      expect(result.features, isEmpty);
    });
  });

  group('extractFeatureTags — no feature tag at all', () {
    test('plain title round-trips unchanged (trimmed)', () {
      final result = extractFeatureTags('  Plain Song Title  ');
      expect(result.cleanText, 'Plain Song Title');
      expect(result.features, isEmpty);
      expect(result.hasFeatures, isFalse);
    });
  });

  group('dedupeFeatures', () {
    test('drops case-insensitive duplicates, keeps first-seen casing', () {
      expect(dedupeFeatures(['Chandler Moore', 'OBA', 'chandler moore']), [
        'Chandler Moore',
        'OBA',
      ]);
    });
  });
}
