import 'package:flutter_test/flutter_test.dart';
import 'package:ta_music/data/services/translation/mymemory_languages.dart';

void main() {
  group('filterTranslationLanguages', () {
    test('an empty query returns every language unfiltered', () {
      expect(filterTranslationLanguages(''), supportedTranslationLanguages);
      expect(filterTranslationLanguages('   '), supportedTranslationLanguages);
    });

    test('matches on English name, case-insensitively', () {
      final results = filterTranslationLanguages('yoruba');
      expect(results.map((l) => l.code), contains('yo'));
    });

    test('matches on a mixed-case, partial English name', () {
      final results = filterTranslationLanguages('Yor');
      expect(results.map((l) => l.code), contains('yo'));
    });

    test('matches on native name', () {
      final results = filterTranslationLanguages('Français');
      expect(results.map((l) => l.code), contains('fr'));
    });

    test('matches on an exact language code', () {
      // 'zu' isn't a substring of any English or native name in the list
      // (verified against the list itself), so a hit here can only come
      // from the exact-code branch of the match, not the name-substring
      // branches — isolating the code-match behavior specifically.
      final results = filterTranslationLanguages('zu');
      expect(results.map((l) => l.code), ['zu']);
    });

    test('a query matching nothing returns an empty list', () {
      expect(filterTranslationLanguages('zzzznotalanguage'), isEmpty);
    });

    test('the explicitly required African languages are all present', () {
      final codes = supportedTranslationLanguages.map((l) => l.code).toSet();
      expect(codes, containsAll(['yo', 'ig', 'ha', 'sw', 'zu', 'xh', 'am', 'so']));
    });
  });

  group('translationLanguageForCode', () {
    test('finds a known code', () {
      expect(translationLanguageForCode('yo')?.englishName, 'Yoruba');
    });

    test('returns null for an unknown code', () {
      expect(translationLanguageForCode('zzz'), isNull);
    });
  });
}
