import 'feature_tag_parser.dart';

/// One (title, artist) pair to try against LRCLIB. [isLastResort] marks the
/// primary-artist-only fallback — see [buildLrclibQueryVariants].
class QueryVariant {
  const QueryVariant({required this.title, required this.artist, required this.isLastResort});

  final String title;
  final String artist;
  final bool isLastResort;
}

/// Builds the ordered cascade of LRCLIB queries to try for a song whose
/// title and/or artist carry a feat./ft. tag (see `feature_tag_parser.dart`
/// for why that tag is preserved as a version discriminator rather than
/// stripped outright).
///
/// When no feature tag is present anywhere, this is a single clean-and-trim
/// variant — same one-shot query the app always sent before this rework, so
/// songs unaffected by Bug 1 make no extra LRCLIB calls.
///
/// When a feature tag IS present, four variants are tried in order, each a
/// different guess at how LRCLIB's own index formats the same track:
/// 1. feature info folded back into the title, primary artist alone
/// 2. clean title, every artist (primary + features) as one comma list
/// 3. clean title, primary artist with an inline "feat." suffix
/// 4. clean title, PRIMARY ARTIST ONLY — last resort, flagged
///    [QueryVariant.isLastResort] since dropping the feature entirely risks
///    matching a different version of the same title (see
///    `LyricsRepository`'s `isPossibleMismatch`).
///
/// The caller stops at the first variant that returns a hit.
List<QueryVariant> buildLrclibQueryVariants({required String artist, required String title}) {
  final titleTags = extractFeatureTags(title);
  final artistTags = extractFeatureTags(artist);
  final features = dedupeFeatures([...titleTags.features, ...artistTags.features]);

  final cleanTitle = titleTags.cleanText.isEmpty ? title.trim() : titleTags.cleanText;
  final cleanArtist = artistTags.cleanText.isEmpty ? artist.trim() : artistTags.cleanText;

  if (features.isEmpty) {
    return [QueryVariant(title: cleanTitle, artist: cleanArtist, isLastResort: false)];
  }

  final featureStr = features.join(', ');
  return [
    QueryVariant(
      title: '$cleanTitle (feat. $featureStr)',
      artist: cleanArtist,
      isLastResort: false,
    ),
    QueryVariant(
      title: cleanTitle,
      artist: [cleanArtist, ...features].join(', '),
      isLastResort: false,
    ),
    QueryVariant(title: cleanTitle, artist: '$cleanArtist feat. $featureStr', isLastResort: false),
    QueryVariant(title: cleanTitle, artist: cleanArtist, isLastResort: true),
  ];
}

/// The single query lyrics.ovh gets — it has no search/duration matching to
/// disambiguate versions, so retrying it with every LRCLIB variant would
/// mostly just add requests. Picks the "clean title + every artist as one
/// comma list" variant (index 1) when features were detected, otherwise the
/// sole clean variant.
QueryVariant bestOvhVariant(List<QueryVariant> lrclibVariants) {
  return lrclibVariants.length > 1 ? lrclibVariants[1] : lrclibVariants[0];
}
