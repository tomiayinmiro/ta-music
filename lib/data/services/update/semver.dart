/// Compares two `major.minor.patch` version strings.
///
/// Returns negative if [a] < [b], zero if equal, positive if [a] > [b].
/// A version string with fewer than 3 numeric parts treats the missing
/// parts as 0 (`"1.2"` == `"1.2.0"`); non-numeric parts also parse as 0
/// rather than throwing, since this only ever reads a version string this
/// app itself wrote (pubspec) or a JSON file this app itself controls.
int compareSemver(String a, String b) {
  final partsA = _parse(a);
  final partsB = _parse(b);
  for (var i = 0; i < 3; i++) {
    final diff = partsA[i].compareTo(partsB[i]);
    if (diff != 0) return diff;
  }
  return 0;
}

bool isSemverLessThan(String a, String b) => compareSemver(a, b) < 0;

List<int> _parse(String version) {
  final segments = version.split('.');
  return List.generate(3, (i) => i < segments.length ? int.tryParse(segments[i]) ?? 0 : 0);
}
