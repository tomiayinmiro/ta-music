/// Recovers a usable artist/title for a lyrics lookup from a file's NAME
/// when its ID3 tags don't have one — many downloaded files (see CLAUDE.md
/// Phase 5 batch 1 bug-fix pass, Bug 2) carry no tags at all, only a
/// filename like "Burna_Boy_ft._Ed_Sheeran_-_For_My_Hand_(mp3.pm).mp3".
///
/// This is a query-only enrichment: it's never written back to the song's
/// DB row or shown as the song's real metadata anywhere — only fed into the
/// lyrics lookup when the actual ID3 tag is missing. See
/// [resolveArtistTitleForLyrics], which callers should use instead of
/// calling [parseFilenameForLyrics] directly.
library;

/// Result of splitting a cleaned-up filename. Either field may be null —
/// see [parseFilenameForLyrics] for when.
class ParsedFilename {
  const ParsedFilename({this.artist, this.title, this.isAmbiguous = false});

  final String? artist;
  final String? title;

  /// True when a bare (unspaced) dash split found 3+ segments — the
  /// filename uses dashes as its word separator throughout, so there's no
  /// reliable way to tell where the artist ends and the title begins.
  /// [title] holds the whole cleaned name and [artist] is null; the caller
  /// should not guess a split, and should skip the lyrics lookup entirely
  /// rather than risk caching a false "not found" against a wrong guess.
  final bool isAmbiguous;
}

const _audioExtensions = ['.mp3', '.m4a', '.flac', '.ogg', '.wav', '.aac', '.wma', '.opus'];

/// A trailing bracket/paren block is a download-site watermark — not a
/// version discriminator like "(Live)"/"(Remix)" — only when its contents
/// look site-like: a dotted domain-style token ("mp3.pm") or a known
/// watermark keyword. Anything else trailing in brackets is left alone.
/// The optional leading dash/whitespace covers filenames like
/// "Sound-Of-Salem-CONNECT-(CeeNaija.com)", where the watermark bracket is
/// glued to the rest of the name by a dash rather than a space — that dash
/// belongs to the watermark, not the title, so it's stripped along with it.
final _trailingBracket = RegExp(r'[-–—]?\s*[\(\[]([^\(\)\[\]]+)[\)\]]\s*$');

const _watermarkKeywords = [
  'mp3pm',
  'mp3paw',
  'naijaload',
  'naijaloaded',
  'justnaija',
  'trendybeatz',
  'waploaded',
  'tooxclusive',
  'notjustok',
];

final _dashSplit = RegExp(r'\s+[-–—]\s+');

/// Fallback split for a dash with no surrounding whitespace at all, e.g.
/// "Sound-Of-Salem-CONNECT". Only ever tried when [_dashSplit] finds
/// nothing AND the whole name has no whitespace anywhere — see
/// [parseFilenameForLyrics]. That second condition is what keeps a
/// hyphenated word inside an otherwise normal title (e.g. "Afro-pop
/// Anthem") from being torn apart: mixing a bare dash with spaces
/// elsewhere in the name signals a hyphenated phrase, not a structured
/// artist-title separator.
final _bareDashSplit = RegExp(r'[-–—]');

final _hasWhitespace = RegExp(r'\s');

final _whitespace = RegExp(r'\s+');

/// Strips the extension, a trailing download-site watermark, converts
/// underscores to spaces, then splits on a spaced dash (` - `/` – `/` — `):
/// - 1 part (no dash found): the whole thing is [ParsedFilename.title],
///   artist stays null — covers both a title-only filename and a genuinely
///   unparseable one (e.g. "138697771_"), which the caller should treat as
///   unusable since there's no artist to look up with.
/// - 2 parts: artist, then title.
/// - 3+ parts: artist, then every remaining part rejoined with " - " as the
///   title — e.g. "Artist - Song - Remix" keeps "Song - Remix" as one
///   title, preserving "Remix" as part of the song identity rather than
///   discarding it.
///
/// Feature-tag detection (`feature_tag_parser.dart`) is deliberately NOT
/// applied here — it runs uniformly on whatever artist/title a lookup ends
/// up using, regardless of whether they came from ID3 or a filename.
ParsedFilename parseFilenameForLyrics(String path) {
  var name = path.split(RegExp(r'[\\/]')).last;

  final lowerName = name.toLowerCase();
  for (final ext in _audioExtensions) {
    if (lowerName.endsWith(ext)) {
      name = name.substring(0, name.length - ext.length);
      break;
    }
  }

  name = _stripWatermark(name).replaceAll('_', ' ').replaceAll(_whitespace, ' ').trim();
  // A dangling period right where the (now-removed) watermark bracket used
  // to be — e.g. "photograph._(mp3.pm)" — is watermark punctuation, not
  // part of the title; a real title's own mid-string abbreviations ("ft.")
  // are untouched since only a *trailing* period is stripped.
  name = name.replaceAll(RegExp(r'\.+$'), '').trim();
  if (name.isEmpty) return const ParsedFilename();

  var parts = name.split(_dashSplit).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();

  if (parts.length <= 1 && !_hasWhitespace.hasMatch(name)) {
    final bareParts =
        name.split(_bareDashSplit).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (bareParts.length == 2) {
      parts = bareParts;
    } else if (bareParts.length > 2) {
      return ParsedFilename(title: name, isAmbiguous: true);
    }
  }

  if (parts.length <= 1) {
    return ParsedFilename(title: parts.isEmpty ? null : parts.first);
  }

  final artist = parts.first;
  final title = parts.sublist(1).join(' - ');
  return ParsedFilename(
    artist: artist.isEmpty ? null : artist,
    title: title.isEmpty ? null : title,
  );
}

String _stripWatermark(String name) {
  final match = _trailingBracket.firstMatch(name);
  if (match == null) return name;

  final inner = match.group(1)!.trim().toLowerCase();
  final normalized = inner.replaceAll(RegExp(r'[\s._-]'), '');
  final looksLikeWatermark = inner.contains('.') || _watermarkKeywords.contains(normalized);
  if (!looksLikeWatermark) return name;

  return name.substring(0, match.start);
}

/// ID3 artist values that are placeholders from the download source, not a
/// real artist name — treated the same as an empty tag, so the filename
/// fallback kicks in instead of sending e.g. "Unknown Artist" to LRCLIB as
/// if it were real. "Various Artists" is deliberately NOT in this set: it's
/// only rejected when the title is also missing (see
/// [_isArtistPlaceholder]) since it's a legitimate compilation-album artist
/// otherwise, and there's no reliable way to tell the two cases apart from
/// the string alone.
const _artistPlaceholders = {'unknown artist', 'unknown', 'track'};

/// ID3 title placeholders, same rationale as [_artistPlaceholders].
const _titlePlaceholders = {'untitled', 'track', 'unknown title', 'unknown'};

/// A tag that's non-empty but made up entirely of whitespace/dashes/dots/
/// underscores (e.g. "---", "___", "...") carries no real information
/// either — same placeholder treatment.
final _placeholderSymbolsOnly = RegExp(r'^[\s._\-–—]+$');

bool _isArtistPlaceholder(String trimmed, {required bool titleMissing}) {
  final lower = trimmed.toLowerCase();
  if (_artistPlaceholders.contains(lower)) return true;
  if (lower == 'various artists' && titleMissing) return true;
  return _placeholderSymbolsOnly.hasMatch(trimmed);
}

bool _isTitlePlaceholder(String trimmed) {
  final lower = trimmed.toLowerCase();
  if (_titlePlaceholders.contains(lower)) return true;
  return _placeholderSymbolsOnly.hasMatch(trimmed);
}

/// The final artist/title a lyrics lookup should use for [id3Artist]/
/// [id3Title]: the ID3 value whenever it's present and not a placeholder
/// (see [_isArtistPlaceholder]/[_isTitlePlaceholder]), falling back to a
/// filename-derived value (see [parseFilenameForLyrics]) only for whichever
/// field ID3 left empty or placeholder-only. Never overwrites a real ID3
/// tag.
class ResolvedArtistTitle {
  const ResolvedArtistTitle({
    required this.artist,
    required this.title,
    required this.usedFilenameFallback,
    this.filenameAmbiguous = false,
  });

  final String? artist;
  final String? title;

  /// True if either field came from [parseFilenameForLyrics] rather than
  /// ID3 — purely informational, for diagnostic logging.
  final bool usedFilenameFallback;

  /// True if the filename fallback was attempted but the name turned out to
  /// use bare dashes throughout with no reliable artist/title split (see
  /// [ParsedFilename.isAmbiguous]) — [artist] is null in that case and the
  /// caller should skip the lyrics lookup rather than guess.
  final bool filenameAmbiguous;
}

ResolvedArtistTitle resolveArtistTitleForLyrics({
  required String? id3Artist,
  required String? id3Title,
  String? audioFilePath,
}) {
  final trimmedArtist = id3Artist?.trim();
  final trimmedTitle = id3Title?.trim();
  final artistEmpty = trimmedArtist == null || trimmedArtist.isEmpty;
  final titleEmpty = trimmedTitle == null || trimmedTitle.isEmpty;

  final artistIsPlaceholder =
      !artistEmpty && _isArtistPlaceholder(trimmedArtist, titleMissing: titleEmpty);
  final titleIsPlaceholder = !titleEmpty && _isTitlePlaceholder(trimmedTitle);

  final artistMissing = artistEmpty || artistIsPlaceholder;
  final titleMissing = titleEmpty || titleIsPlaceholder;

  if ((!artistMissing && !titleMissing) || audioFilePath == null) {
    return ResolvedArtistTitle(
      artist: artistMissing ? null : trimmedArtist,
      title: titleMissing ? null : trimmedTitle,
      usedFilenameFallback: false,
    );
  }

  final parsed = parseFilenameForLyrics(audioFilePath);
  final resolvedArtist = artistMissing ? parsed.artist : trimmedArtist;
  final resolvedTitle = titleMissing ? parsed.title : trimmedTitle;
  final usedFallback =
      (artistMissing && parsed.artist != null) || (titleMissing && parsed.title != null);

  return ResolvedArtistTitle(
    artist: resolvedArtist,
    title: resolvedTitle,
    usedFilenameFallback: usedFallback,
    filenameAmbiguous: parsed.isAmbiguous,
  );
}
