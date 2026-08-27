/// Detects "feat./ft./with" tags in a raw ID3 title or artist string and
/// separates them from the rest of the text — see CLAUDE.md Phase 5 batch 1
/// bug-fix pass: feature info is a VERSION DISCRIMINATOR (a song can exist
/// as both a solo version and a "feat. X" version with different lyrics),
/// never noise to strip and discard. [extractFeatureTags] is used to build
/// LRCLIB query variants in `lyrics_query_builder.dart` — the original,
/// uncleaned string is always what's still shown on Now Playing.
///
/// Deliberately does NOT match other bracket/paren suffixes that are their
/// own version discriminators — "[Live]", "(Remix)", "(Acoustic)",
/// "[Extended]", "[Radio Edit]", "[Instrumental]" — since none of those
/// contain a feat/ft/with keyword, the pattern below never touches them.
class FeatureTagResult {
  const FeatureTagResult({required this.cleanText, required this.features});

  /// [text] with every detected feature-tag block removed and whitespace
  /// collapsed. Equal to the trimmed/collapsed input when nothing matched.
  final String cleanText;

  /// Feature artist names, in the order they appeared, split on `,`, `&`,
  /// `and`, or `x` (e.g. "Wizkid x Burna Boy"). Empty when nothing matched.
  final List<String> features;

  bool get hasFeatures => features.isNotEmpty;
}

/// Matches `[feat. X]`, `(feat. X)`, `[ft. X]`, `(ft. X)`, `[ft X]`,
/// `(ft X)`, `[With X]`, `(With X)` — case-insensitive, either bracket
/// style. `with` is only recognized inside brackets — a bare trailing
/// "... with X" is too likely to be part of an actual title to treat as a
/// feature tag.
final _bracketFeatPattern = RegExp(
  r'[\(\[]\s*(?:feat\.?|ft\.?|with)\s+([^\)\]]+?)\s*[\)\]]',
  caseSensitive: false,
);

/// Bare trailing suffix with no brackets at all: `... feat. X`, `... ft X`
/// at the very end of the string. Only tried when no bracketed form
/// matched, and only for `feat`/`ft` — never `with` (see above).
final _bareSuffixFeatPattern = RegExp(r'\s+(?:feat\.?|ft\.?)\s+(.+)$', caseSensitive: false);

final _artistSeparator = RegExp(r'\s*(?:,|&|\band\b|\bx\b)\s*', caseSensitive: false);

final _whitespace = RegExp(r'\s+');

FeatureTagResult extractFeatureTags(String text) {
  final features = <String>[];
  var clean = text;

  final bracketMatches = _bracketFeatPattern.allMatches(text).toList();
  if (bracketMatches.isNotEmpty) {
    for (final match in bracketMatches) {
      features.addAll(_splitArtists(match.group(1)!));
    }
    clean = text.replaceAll(_bracketFeatPattern, '');
  } else {
    final bareMatch = _bareSuffixFeatPattern.firstMatch(text);
    if (bareMatch != null) {
      features.addAll(_splitArtists(bareMatch.group(1)!));
      clean = text.substring(0, bareMatch.start);
    }
  }

  clean = clean.replaceAll(_whitespace, ' ').trim();
  return FeatureTagResult(cleanText: clean, features: features);
}

List<String> _splitArtists(String raw) {
  return raw.split(_artistSeparator).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
}

/// Case-insensitive dedupe that keeps the first-seen casing — used when
/// combining features pulled from both the title and the artist tag, which
/// may name the same guest artist.
List<String> dedupeFeatures(List<String> items) {
  final seen = <String>{};
  final result = <String>[];
  for (final item in items) {
    if (seen.add(item.toLowerCase())) result.add(item);
  }
  return result;
}
