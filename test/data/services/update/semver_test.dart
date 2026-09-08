import 'package:flutter_test/flutter_test.dart';
import 'package:ta_music/data/services/update/semver.dart';

void main() {
  test('a simple ascending chain compares correctly in both directions', () {
    const chain = ['1.0.0', '1.0.1', '1.0.10', '1.1.0', '2.0.0'];
    for (var i = 0; i < chain.length - 1; i++) {
      expect(compareSemver(chain[i], chain[i + 1]), lessThan(0));
      expect(compareSemver(chain[i + 1], chain[i]), greaterThan(0));
    }
  });

  test('equal versions compare as zero', () {
    expect(compareSemver('1.2.3', '1.2.3'), 0);
  });

  test('a numerically double-digit patch does not lexicographically misorder', () {
    // "1.0.10" < "1.0.9" would be true under plain string comparison —
    // must not regress to that.
    expect(compareSemver('1.0.10', '1.0.9'), greaterThan(0));
  });

  test('missing trailing parts default to 0', () {
    expect(compareSemver('1.2', '1.2.0'), 0);
    expect(compareSemver('1', '1.0.0'), 0);
    expect(compareSemver('1.2', '1.2.1'), lessThan(0));
  });

  test('isSemverLessThan matches the sign of compareSemver', () {
    expect(isSemverLessThan('1.0.0', '1.0.1'), isTrue);
    expect(isSemverLessThan('1.0.1', '1.0.0'), isFalse);
    expect(isSemverLessThan('1.0.0', '1.0.0'), isFalse);
  });

  test('a non-numeric segment parses as 0 rather than throwing', () {
    expect(() => compareSemver('1.x.0', '1.0.0'), returnsNormally);
  });
}
