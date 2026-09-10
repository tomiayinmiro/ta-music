import '../../models/song.dart';
import 'backup_models.dart';

/// Resolves [BackupSongRef]s (a backup's song references) against this
/// device's actual library. Built once per import from the full song list,
/// then queried per reference in O(1) average instead of re-scanning the
/// whole library for every playlist entry/favorite/history row — a backup
/// with 10,000+ play_history rows against a library of a few thousand songs
/// would otherwise be a many-million-comparison operation.
///
/// Exact `path` match wins first — the common case (reinstalling on the
/// same phone, where absolute paths are usually unchanged). When that
/// misses — a backup imported on a different device, or a different
/// platform entirely (a Windows export's `C:\...` paths can never equal an
/// Android `/storage/...` path) — falls back to matching by normalized
/// (title, artist), disambiguated by album and duration (±2s) when more
/// than one local song shares that title/artist. There's no file hash
/// anywhere in this app to match on instead — see CLAUDE.md's Backup &
/// Restore decisions for why this two-tier approach was chosen over adding
/// one.
class SongMatchIndex {
  SongMatchIndex(List<Song> songs)
    : _byPath = {for (final s in songs) s.path: s},
      _byTitleArtist = _buildFuzzyIndex(songs);

  final Map<String, Song> _byPath;
  final Map<String, List<Song>> _byTitleArtist;

  static Map<String, List<Song>> _buildFuzzyIndex(List<Song> songs) {
    final index = <String, List<Song>>{};
    for (final song in songs) {
      final key = _fuzzyKey(song.title, song.artist);
      if (key == null) continue;
      index.putIfAbsent(key, () => []).add(song);
    }
    return index;
  }

  /// Resolves [ref] to a local [Song], or `null` if nothing matches closely
  /// enough to be trusted.
  Song? match(BackupSongRef ref) {
    final byPath = _byPath[ref.path];
    if (byPath != null) return byPath;

    final key = _fuzzyKey(ref.title, ref.artist);
    if (key == null) return null;
    final candidates = _byTitleArtist[key];
    if (candidates == null || candidates.isEmpty) return null;
    if (candidates.length == 1) return candidates.first;

    final refAlbum = _normalize(ref.album);
    for (final candidate in candidates) {
      if (refAlbum != null) {
        final candidateAlbum = _normalize(candidate.album);
        if (candidateAlbum != null && candidateAlbum != refAlbum) continue;
      }
      if (ref.durationMs != null && candidate.durationMs != null) {
        if ((candidate.durationMs! - ref.durationMs!).abs() > 2000) continue;
      }
      return candidate;
    }
    // Same title+artist, but album/duration ruled out every candidate
    // individually (e.g. a re-recorded/remastered version with a slightly
    // different length) — fall back to the first title/artist match rather
    // than dropping a song that's almost certainly the right one.
    return candidates.first;
  }

  static String? _normalize(String? value) {
    if (value == null) return null;
    final trimmed = value.trim().toLowerCase();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? _fuzzyKey(String? title, String? artist) {
    final normalizedTitle = _normalize(title);
    final normalizedArtist = _normalize(artist);
    if (normalizedTitle == null || normalizedArtist == null) return null;
    return '$normalizedTitle\u0000$normalizedArtist';
  }
}
