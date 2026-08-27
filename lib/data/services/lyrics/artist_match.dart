/// Verifies a lyrics API's returned artist actually corresponds to the
/// artist we queried for — see CLAUDE.md's Phase 5 batch 1 matching-fix
/// pass. LRCLIB's `/api/search` ranks candidates by text relevance, not a
/// strict artist filter (confirmed by direct testing: querying with a
/// deliberately wrong artist still returns results), so a hit's `artistName`
/// has to be checked against what we actually asked for rather than trusted
/// outright.
library;

/// True when [returned] (the artist name a lyrics API actually reports for
/// a hit) plausibly refers to the same artist as [queried] (what we sent).
/// Deliberately permissive about minor differences — a typo, casing, or one
/// name being a multi-artist superset of the other ("Nosa; Nathaniel
/// Bassey" vs "Nosa") — but rejects artists that are simply different
/// people ("Nathaniel Bassey" vs "Dunsin Oyekan").
///
/// Returns `true` (can't verify, don't block) when either string is empty
/// after normalizing — this only exists to catch a confident mismatch, not
/// to require a confident match.
bool isArtistFuzzyMatch(String queried, String returned, {double threshold = 0.65}) {
  final q = _normalize(queried);
  final r = _normalize(returned);
  if (q.isEmpty || r.isEmpty) return true;
  if (q == r) return true;
  // Handles a multi-artist string containing the single artist we queried
  // (or vice versa) — a legitimate variant, not a different song.
  if (r.contains(q) || q.contains(r)) return true;
  return _similarity(q, r) >= threshold;
}

String _normalize(String s) {
  return s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// 1 minus the normalized Levenshtein edit distance — 1.0 for identical
/// strings, trending toward 0.0 for completely different ones. Normalized
/// by the longer string's length so e.g. a 1-character typo on a long name
/// still scores high, while two short-but-unrelated names don't get an
/// inflated score just for being short.
double _similarity(String a, String b) {
  final maxLen = a.length > b.length ? a.length : b.length;
  if (maxLen == 0) return 1;
  return 1 - (_levenshtein(a, b) / maxLen);
}

int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var previousRow = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 0; i < a.length; i++) {
    final currentRow = List<int>.filled(b.length + 1, 0);
    currentRow[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      final deletionCost = previousRow[j + 1] + 1;
      final insertionCost = currentRow[j] + 1;
      final substitutionCost = previousRow[j] + (a[i] == b[j] ? 0 : 1);
      currentRow[j + 1] = [
        deletionCost,
        insertionCost,
        substitutionCost,
      ].reduce((v, e) => v < e ? v : e);
    }
    previousRow = currentRow;
  }
  return previousRow[b.length];
}
