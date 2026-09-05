import 'dart:convert';

import '../models/song.dart';

/// Deterministically maps a song with no embedded/resolved cover art to one
/// of the 20 bundled fallback images, so every song shows *some* visual
/// identity instead of the generic note-icon placeholder. Audio Bible files
/// all share one dedicated image instead of the general pool, so they read
/// as a single cohesive "album".
class FallbackCoverResolver {
  const FallbackCoverResolver._();

  static const int poolSize = 20;
  static const String bibleAssetPath = 'assets/fallback_covers/bible/audio_bible.jpg';

  static final RegExp _bibleBookPattern = RegExp(r'bible.*book\s*\d+|book\s*\d+.*bible');

  /// The asset to display for [song]. Same [Song.path] always resolves to
  /// the same asset — path (not id) is used as the stable identifier since
  /// it's always present, while an id could in principle be null.
  static String resolveFor(Song song) {
    if (isAudioBible(song)) return bibleAssetPath;
    final index = _stableHash(song.path) % poolSize;
    return 'assets/fallback_covers/fallback_${index.toString().padLeft(2, '0')}.jpg';
  }

  /// Detects the audio Bible special case from title/filename text, matched
  /// case-insensitively against "the holy bible", "holy bible" + "kjv", or
  /// "bible" + a book number (e.g. "Book 02"). Filename separators
  /// (underscores, dashes, dots) are normalized to spaces first, so
  /// "The_Holy_Bible_KJV_Book_02.mp3" matches the same as a naturally
  /// spaced title. A song with neither a title nor a matching filename
  /// simply falls through to the general pool — no harm done.
  static bool isAudioBible(Song song) {
    final haystack = _normalize('${song.title ?? ''} ${_fileNameOf(song.path)}');
    if (haystack.contains('the holy bible')) return true;
    if (haystack.contains('holy bible') && haystack.contains('kjv')) return true;
    if (_bibleBookPattern.hasMatch(haystack)) return true;
    return false;
  }

  static String _fileNameOf(String path) => path.split(RegExp(r'[\\/]')).last;

  static String _normalize(String s) => s.toLowerCase().replaceAll(RegExp(r'[_\-.]'), ' ');

  /// FNV-1a over the UTF-8 bytes of [input], plus a murmur3-style avalanche
  /// finalizer. `String.hashCode` is a content hash but not documented as
  /// stable across Dart SDK releases — this keeps the same song always
  /// landing on the same pool index regardless of Dart version or platform.
  ///
  /// The finalizer isn't optional decoration: plain FNV-1a's low bits mix
  /// poorly (each round's multiply-by-odd-prime step provably can't change
  /// the running parity, only the XOR does), which is invisible for a
  /// "spread across many buckets" hash but became a real bug against
  /// [poolSize] (20, i.e. `% 4` folded in) — paths shaped like
  /// `artist_$i/song_$i.mp3` (the same digit substring appearing twice)
  /// hashed to only 10 of the 20 buckets, because the digits' parity
  /// contributions to the final bit cancelled out. Caught by the pool
  /// "different songs distribute across the 20-image pool" test.
  static int _stableHash(String input) {
    const fnvPrime = 0x01000193;
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(input)) {
      hash ^= byte;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    hash ^= hash >> 16;
    hash = (hash * 0x85ebca6b) & 0xFFFFFFFF;
    hash ^= hash >> 13;
    hash = (hash * 0xc2b2ae35) & 0xFFFFFFFF;
    hash ^= hash >> 16;
    return hash;
  }
}
