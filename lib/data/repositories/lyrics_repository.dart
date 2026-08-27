import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../database/daos/lyrics_cache_dao.dart';
import '../models/song.dart';
import '../services/lyrics/artist_match.dart';
import '../services/lyrics/filename_lyrics_parser.dart';
import '../services/lyrics/lrc_parser.dart';
import '../services/lyrics/lrclib_client.dart';
import '../services/lyrics/local_lrc_file_reader.dart';
import '../services/lyrics/lyrics_query_builder.dart';

final _log = Logger();

/// A cached "not found" result is re-fetched after this long — coverage
/// across all 3 layers grows over time, so a song with no lyrics today
/// might have them later. A successful lookup has no TTL at all: lyrics
/// text doesn't change once found. A manual (`user_added`) entry is a
/// successful lookup too, so it's covered by the same no-TTL rule.
const _notFoundTtl = Duration(days: 7);

/// The outcome of a lyrics lookup. Plain sealed class (no `freezed` — see
/// `lib/data/models/song.dart` for why) with exhaustive `switch` at call
/// sites.
sealed class LyricsResult {
  const LyricsResult();
}

/// Lyrics were found, already split into display [lines]. [isSynced]
/// indicates whether [LyricsLine.timestamp] is real (parsed from an LRC
/// `[mm:ss.xx]` tag, source LRCLIB or a local `.lrc` file) or absent
/// (plain text — the Now Playing lyrics view falls back to the
/// equal-time-distribution estimate in `lyrics_line_sync.dart`). [source]
/// is `'lrclib'`, `'lyrics.ovh'`, `'local_lrc'`, or `'user_added'`.
/// [isPossibleMismatch] is true only when a LRCLIB hit came from the query
/// cascade's last-resort, primary-artist-only variant (see
/// `buildLrclibQueryVariants`) — the lyrics may belong to a different
/// feat./ft. version of this title. The Now Playing lyrics panel shows a
/// warning banner in that case, linking to the manual lyrics editor.
class LyricsFound extends LyricsResult {
  const LyricsFound({
    required this.lines,
    required this.isSynced,
    required this.source,
    this.isPossibleMismatch = false,
  });

  final List<LyricsLine> lines;
  final bool isSynced;
  final String source;
  final bool isPossibleMismatch;
}

/// Looked up (locally cached or via all 3 layers) and confirmed there are no
/// lyrics for this song.
class LyricsNotFound extends LyricsResult {
  const LyricsNotFound();
}

/// The current song has no artist or title to look up, even after trying to
/// recover one from the filename (see `filename_lyrics_parser.dart`) — no
/// layer was ever called.
class LyricsMissingMetadata extends LyricsResult {
  const LyricsMissingMetadata();
}

/// No layer could complete a definitive lookup — network error, timeout, or
/// rate limiting on every layer that could have found something. Never
/// cached, so the next attempt (e.g. a retry tap) tries again immediately
/// rather than waiting out [_notFoundTtl].
class LyricsFetchError extends LyricsResult {
  const LyricsFetchError({required this.message, this.isRateLimited = false});

  final String message;
  final bool isRateLimited;
}

/// One row from the Settings "Lyrics" screen's "Manually added lyrics"
/// list.
class ManualLyricsEntry {
  const ManualLyricsEntry({
    required this.artistKey,
    required this.titleKey,
    required this.displayArtist,
    required this.displayTitle,
    required this.addedAt,
  });

  final String artistKey;
  final String titleKey;
  final String displayArtist;
  final String displayTitle;
  final DateTime addedAt;
}

sealed class _LayerOutcome {
  const _LayerOutcome();
}

/// Raw hit — not yet parsed/validated. [syncedLrc] and [plainText] mirror
/// exactly what the layer returned (both may be present, e.g. LRCLIB), and
/// are cached verbatim so a later cache read can rebuild the same result.
class _RawHit extends _LayerOutcome {
  const _RawHit({this.syncedLrc, this.plainText, this.isPossibleMismatch = false});
  final String? syncedLrc;
  final String? plainText;
  final bool isPossibleMismatch;
}

class _Miss extends _LayerOutcome {
  const _Miss();
}

class _FetchFailure extends _LayerOutcome {
  const _FetchFailure(this.message, {this.isRateLimited = false});
  final String message;
  final bool isRateLimited;
}

/// Looks up lyrics through a 3-layer fallback chain, backed by an
/// indefinite-TTL cache for hits and a [_notFoundTtl]-bounded cache for
/// misses. Fetching never blocks or otherwise touches playback — this is
/// called from the lyrics panel (foreground) and [LyricsPrefetchService]
/// (background, on song start) alike.
///
/// Layer 1 — LRCLIB (`/api/get`, falling back to `/api/search` on a 404):
/// MIT-licensed, no API key, wide coverage including Afrobeats/international
/// music, and returns real `[mm:ss.xx]` synced timing where lyrics.ovh never
/// could. Layer 2 — lyrics.ovh, the original Batch 1 source, plain text
/// only. Layer 3 — a local `.lrc` sidecar file next to the audio file, for
/// whatever neither API has; see `LocalLrcFileReader` for why this is
/// best-effort on Android. A 4th "layer" that isn't part of the fallback
/// chain at all: a `user_added` cache row (see [saveManualLyrics]) is
/// checked before any of the above and, if present, returned immediately —
/// it's cached the same way any other hit is, just never overwritten by an
/// automatic re-fetch (see [saveManualLyrics]'s doc for why the cache
/// lookup already gives it priority for free).
///
/// A layer's network error doesn't stop the chain — the next layer is still
/// tried — but if every layer that could have produced an answer errored
/// out (none definitively found or definitively missed), the whole lookup
/// reports [LyricsFetchError] instead of caching a false "not found".
///
/// Many files' ID3 title/artist tags bake feature-artist info directly into
/// the string (e.g. `"Olorun Agbaye [Feat. Chandler Moore & OBA]"`), which
/// the raw string sent verbatim to LRCLIB usually fails to match. Rather
/// than stripping that info (`feat./ft.` is a version discriminator — a
/// solo version and a "feat. X" version of the same title are different
/// songs with different lyrics, see CLAUDE.md), [getLyrics] runs an ordered
/// cascade of query variants through LRCLIB when a feature tag is detected
/// — see `buildLrclibQueryVariants`. The ORIGINAL, uncleaned title/artist is
/// never touched: only the strings sent to the lyrics APIs are ever
/// reformatted, and the cache key is always the original (trimmed,
/// lowercased) artist/title, not any cleaned variant.
class LyricsRepository {
  LyricsRepository({
    required this._dio,
    required this._cacheDao,
    required this._lrclibClient,
    required this._localLrcFileReader,
  });

  final Dio _dio;
  final LyricsCacheDao _cacheDao;
  final LrclibClient _lrclibClient;
  final LocalLrcFileReader _localLrcFileReader;

  Future<LyricsResult> getLyrics({
    required String? artist,
    required String? title,
    String? album,
    Duration? duration,
    String? audioFilePath,
    CancelToken? cancelToken,
    DateTime Function() now = DateTime.now,
  }) async {
    final resolved = resolveArtistTitleForLyrics(
      id3Artist: artist,
      id3Title: title,
      audioFilePath: audioFilePath,
    );
    final effectiveArtist = resolved.artist;
    final effectiveTitle = resolved.title;
    if (resolved.filenameAmbiguous) {
      _log.i(
        '[lyrics] filename ambiguous (bare dashes, no reliable artist/title split) — '
        'skipping lyrics fetch path=$audioFilePath',
      );
    }
    if (effectiveArtist == null ||
        effectiveArtist.isEmpty ||
        effectiveTitle == null ||
        effectiveTitle.isEmpty) {
      return const LyricsMissingMetadata();
    }
    if (resolved.usedFilenameFallback) {
      _log.i(
        '[lyrics] filename fallback used (ID3 incomplete) id3Artist="$artist" id3Title="$title" '
        'resolvedArtist="$effectiveArtist" resolvedTitle="$effectiveTitle" path=$audioFilePath',
      );
    }
    final artistKey = effectiveArtist.toLowerCase();
    final titleKey = effectiveTitle.toLowerCase();

    final cached = await _cacheDao.find(artistKey, titleKey);
    if (cached != null) {
      final source = cached['source'] as String;
      if (source != 'none') {
        _log.i(
          '[lyrics] cache HIT source=$source artist="$effectiveArtist" title="$effectiveTitle"',
        );
        return _resultFromRow(cached);
      }
      final fetchedAt = DateTime.fromMillisecondsSinceEpoch(cached['fetched_at'] as int);
      if (now().difference(fetchedAt) < _notFoundTtl) {
        _log.i(
          '[lyrics] cache HIT (not-found, within TTL) artist="$effectiveArtist" title="$effectiveTitle"',
        );
        return const LyricsNotFound();
      }
      _log.i(
        '[lyrics] cache STALE (not-found, past TTL) artist="$effectiveArtist" title="$effectiveTitle" — re-fetching',
      );
      // Past the TTL — fall through and re-run the chain.
    } else {
      _log.i('[lyrics] cache MISS artist="$effectiveArtist" title="$effectiveTitle"');
    }

    return _fetchAndCache(
      artist: effectiveArtist,
      title: effectiveTitle,
      artistKey: artistKey,
      titleKey: titleKey,
      album: album,
      duration: duration,
      audioFilePath: audioFilePath,
      cancelToken: cancelToken,
      now: now,
    );
  }

  /// Saves a manual lyrics entry for [song], always keyed off the SONG's own
  /// resolved artist/title (ID3, or its filename fallback — the same
  /// resolution [getLyrics] itself performs) rather than [displayArtist]/
  /// [displayTitle] verbatim. This is what makes a manual entry reliably
  /// reattach to the file it was added from: [getLyrics] computes its cache
  /// key from the song's own metadata the same way on every future lookup,
  /// regardless of what the user typed into the editor's Artist/Title
  /// fields to correct a wrong tag. Those typed values are still stored
  /// (as [displayArtist]/[displayTitle]) purely for display on the Settings
  /// "Lyrics" management list.
  ///
  /// Upserts on the same (artist_key, title_key) unique constraint any
  /// auto-fetched row already uses, so this replaces whatever was cached
  /// for the song outright — combined with [getLyrics] already returning
  /// early on any non-`'none'` cache hit, that's the entirety of "a manual
  /// entry always wins": there's no separate priority check, it's just the
  /// newest row under that key.
  Future<void> saveManualLyrics({
    required Song song,
    required String displayArtist,
    required String displayTitle,
    required String lyrics,
    DateTime Function() now = DateTime.now,
  }) async {
    final trimmedDisplayArtist = displayArtist.trim();
    final trimmedDisplayTitle = displayTitle.trim();
    final trimmedLyrics = lyrics.trim();
    if (trimmedDisplayArtist.isEmpty || trimmedDisplayTitle.isEmpty) {
      throw ArgumentError('Artist and title are both required to save manual lyrics.');
    }
    if (trimmedLyrics.isEmpty) {
      throw ArgumentError('Lyrics text is required to save manual lyrics.');
    }

    final resolved = resolveArtistTitleForLyrics(
      id3Artist: song.artist,
      id3Title: song.title,
      audioFilePath: song.path,
    );
    final keyArtist = (resolved.artist ?? trimmedDisplayArtist).toLowerCase();
    final keyTitle = (resolved.title ?? trimmedDisplayTitle).toLowerCase();

    await _cacheDao.upsert(
      artistKey: keyArtist,
      titleKey: keyTitle,
      source: 'user_added',
      hasSyncedTiming: false,
      plainLyrics: trimmedLyrics,
      displayArtist: trimmedDisplayArtist,
      displayTitle: trimmedDisplayTitle,
      fetchedAt: now(),
    );
    _log.i('[lyrics] manual entry SAVED artistKey="$keyArtist" titleKey="$keyTitle"');
  }

  /// Deletes a manual entry — the next lookup for that key re-runs the full
  /// LRCLIB/lyrics.ovh/local-`.lrc` chain from scratch.
  Future<void> deleteManualLyrics({required String artistKey, required String titleKey}) async {
    await _cacheDao.deleteByKey(artistKey, titleKey);
    _log.i('[lyrics] manual entry DELETED artistKey="$artistKey" titleKey="$titleKey"');
  }

  /// All `user_added` rows, newest first — backs the Settings "Lyrics"
  /// screen's management list.
  Future<List<ManualLyricsEntry>> getManualLyricsEntries() async {
    final rows = await _cacheDao.findUserAdded();
    return rows
        .map(
          (row) => ManualLyricsEntry(
            artistKey: row['artist_key'] as String,
            titleKey: row['title_key'] as String,
            displayArtist: (row['display_artist'] as String?) ?? row['artist_key'] as String,
            displayTitle: (row['display_title'] as String?) ?? row['title_key'] as String,
            addedAt: DateTime.fromMillisecondsSinceEpoch(row['fetched_at'] as int),
          ),
        )
        .toList();
  }

  Future<LyricsResult> _fetchAndCache({
    required String artist,
    required String title,
    required String artistKey,
    required String titleKey,
    String? album,
    Duration? duration,
    String? audioFilePath,
    CancelToken? cancelToken,
    required DateTime Function() now,
  }) async {
    String? errorMessage;
    var rateLimited = false;

    // Builds+caches a [LyricsFound] from a raw hit, or returns null (and
    // records the error, if any) so the caller moves on to the next layer —
    // covers both a definitive miss and content too malformed to show.
    Future<LyricsFound?> tryLayer(_LayerOutcome outcome, String source) async {
      switch (outcome) {
        case _FetchFailure(:final message, :final isRateLimited):
          errorMessage ??= message;
          rateLimited = rateLimited || isRateLimited;
          return null;
        case _Miss():
          return null;
        case _RawHit(:final syncedLrc, :final plainText, :final isPossibleMismatch):
          final found = _buildFound(
            source: source,
            syncedLrc: syncedLrc,
            plainText: plainText,
            isPossibleMismatch: isPossibleMismatch,
          );
          if (found == null) return null;
          await _cacheDao.upsert(
            artistKey: artistKey,
            titleKey: titleKey,
            source: source,
            hasSyncedTiming: found.isSynced,
            syncedLyricsLrc: syncedLrc,
            plainLyrics: plainText,
            isPossibleMismatch: found.isPossibleMismatch,
            fetchedAt: now(),
          );
          _log.i(
            '[lyrics] result=FOUND source=$source synced=${found.isSynced} '
            'possibleMismatch=${found.isPossibleMismatch} artist="$artist" title="$title"',
          );
          return found;
      }
    }

    final variants = buildLrclibQueryVariants(artist: artist, title: title);
    _log.i(
      '[lyrics] query variants (${variants.length}) artist="$artist" title="$title" '
      '${variants.length > 1 ? "— feature tag detected" : "— no feature tag"}',
    );

    final lrclibResult = await tryLayer(
      await _tryLrclib(
        variants: variants,
        album: album,
        duration: duration,
        cancelToken: cancelToken,
      ),
      'lrclib',
    );
    if (lrclibResult != null) return lrclibResult;

    final ovhResult = await tryLayer(
      await _tryLyricsOvh(variant: bestOvhVariant(variants), cancelToken: cancelToken),
      'lyrics.ovh',
    );
    if (ovhResult != null) return ovhResult;

    if (audioFilePath != null) {
      final localResult = await tryLayer(await _tryLocalLrc(audioFilePath), 'local_lrc');
      if (localResult != null) return localResult;
    }

    if (errorMessage != null) {
      _log.i(
        '[lyrics] result=ERROR (all layers exhausted) artist="$artist" title="$title" '
        'message=$errorMessage',
      );
      return LyricsFetchError(message: errorMessage!, isRateLimited: rateLimited);
    }

    _log.i('[lyrics] result=NOT_FOUND (all 3 layers missed) artist="$artist" title="$title"');
    await _cacheDao.upsert(
      artistKey: artistKey,
      titleKey: titleKey,
      source: 'none',
      hasSyncedTiming: false,
      fetchedAt: now(),
    );
    return const LyricsNotFound();
  }

  /// A hit's reported duration more than this far from our file's own
  /// duration is treated as a possible mismatch — same-song re-encodes/
  /// re-rips vary by a couple seconds at most, but a genuinely different
  /// recording (live version, different artist's cover, or — the bug this
  /// pass fixes — a same-titled different song) routinely differs by much
  /// more. Matches Tomi's own suggested tolerance.
  static const _durationTolerance = Duration(seconds: 10);

  /// Tries each of [variants] against LRCLIB in order (`get`, then `search`
  /// on a 404) — duration/album passed every time to help LRCLIB pick the
  /// right version when it has multiple — stopping at the first variant
  /// that returns lyrics. A network error on one variant aborts the whole
  /// LRCLIB layer rather than hammering the remaining variants against a
  /// server that's already failing; the caller still falls through to
  /// lyrics.ovh.
  ///
  /// Neither LRCLIB endpoint is trustworthy enough to accept blindly:
  /// `/api/get` 404s on a duration mismatch (confirmed directly against the
  /// live API) but its own matching isn't otherwise verified end-to-end
  /// here, and `/api/search` ranks candidates by text relevance — its
  /// `artist_name` param is a ranking signal, not a hard filter (also
  /// confirmed directly: querying with a deliberately wrong artist still
  /// returns results). So every hit's actual `artistName`/`durationSeconds`
  /// is checked against what we asked for; either check failing marks
  /// [_RawHit.isPossibleMismatch] — same signal `variant.isLastResort`
  /// alone used to be the sole source of, which meant a title with no
  /// feat. tag (a single, always-non-last-resort variant) could never be
  /// flagged no matter what came back. That gap is what let a wrong-artist
  /// same-titled hit through silently — see CLAUDE.md's Phase 5 batch 1
  /// matching-fix pass.
  Future<_LayerOutcome> _tryLrclib({
    required List<QueryVariant> variants,
    String? album,
    Duration? duration,
    CancelToken? cancelToken,
  }) async {
    for (var i = 0; i < variants.length; i++) {
      final variant = variants[i];
      _log.i(
        '[lyrics] lrclib attempt ${i + 1}/${variants.length} title="${variant.title}" '
        'artist="${variant.artist}"${variant.isLastResort ? " (last resort)" : ""}',
      );
      try {
        var track = await _lrclibClient.get(
          trackName: variant.title,
          artistName: variant.artist,
          albumName: album,
          duration: duration,
          cancelToken: cancelToken,
        );
        track ??= await _lrclibClient.search(
          trackName: variant.title,
          artistName: variant.artist,
          duration: duration,
          cancelToken: cancelToken,
        );
        if (track != null && track.hasLyrics) {
          final artistMatches =
              track.artistName == null || isArtistFuzzyMatch(variant.artist, track.artistName!);
          final durationMatches = _durationWithinTolerance(duration, track.durationSeconds);
          final isPossibleMismatch = variant.isLastResort || !artistMatches || !durationMatches;
          _log.i(
            '[lyrics] lrclib attempt ${i + 1} SUCCEEDED returnedArtist="${track.artistName}" '
            'returnedDuration=${track.durationSeconds} artistMatches=$artistMatches '
            'durationMatches=$durationMatches isPossibleMismatch=$isPossibleMismatch',
          );
          return _RawHit(
            syncedLrc: track.syncedLyrics,
            plainText: track.plainLyrics,
            isPossibleMismatch: isPossibleMismatch,
          );
        }
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) rethrow;
        _log.i('[lyrics] lrclib attempt ${i + 1} FAILED message=${e.message}');
        return _FetchFailure(_messageFor(e), isRateLimited: e.response?.statusCode == 429);
      }
    }
    return const _Miss();
  }

  /// True when either duration is unknown (can't verify, don't block) or
  /// they're within [_durationTolerance] of each other.
  bool _durationWithinTolerance(Duration? ours, num? theirs) {
    if (ours == null || theirs == null) return true;
    final diffSeconds = (theirs - ours.inSeconds).abs();
    return diffSeconds <= _durationTolerance.inSeconds;
  }

  Future<_LayerOutcome> _tryLyricsOvh({
    required QueryVariant variant,
    CancelToken? cancelToken,
  }) async {
    final uri = Uri(
      scheme: 'https',
      host: 'api.lyrics.ovh',
      pathSegments: ['v1', variant.artist, variant.title],
    );
    _log.i('[lyrics] lyrics.ovh GET $uri');
    try {
      final response = await _dio.getUri<Map<String, dynamic>>(
        uri,
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
        cancelToken: cancelToken,
      );
      final lyricsText = response.data?['lyrics'] as String?;
      if (lyricsText == null || lyricsText.trim().isEmpty) return const _Miss();
      return _RawHit(plainText: lyricsText);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      if (e.response?.statusCode == 404) return const _Miss();
      _log.i('[lyrics] lyrics.ovh FAILED message=${e.message}');
      return _FetchFailure(_messageFor(e), isRateLimited: e.response?.statusCode == 429);
    }
  }

  Future<_LayerOutcome> _tryLocalLrc(String audioFilePath) async {
    final content = await _localLrcFileReader.read(audioFilePath);
    if (content == null || content.trim().isEmpty) return const _Miss();
    return _RawHit(syncedLrc: content);
  }

  LyricsResult _resultFromRow(Map<String, Object?> row) {
    final found = _buildFound(
      source: row['source'] as String,
      syncedLrc: row['synced_lyrics_lrc'] as String?,
      plainText: row['plain_lyrics'] as String?,
      isPossibleMismatch: (row['is_possible_mismatch'] as int? ?? 0) != 0,
    );
    return found ?? const LyricsNotFound();
  }

  /// Prefers real timing: [syncedLrc] is parsed first, and only falls back
  /// to [plainText] (or, failing that, [syncedLrc]'s own raw text) if
  /// parsing yields nothing usable. Returns null if there's genuinely
  /// nothing displayable, so the caller can treat this layer as a miss
  /// rather than showing an empty lyrics view.
  LyricsFound? _buildFound({
    required String source,
    String? syncedLrc,
    String? plainText,
    bool isPossibleMismatch = false,
  }) {
    if (syncedLrc != null && syncedLrc.trim().isNotEmpty) {
      final parsed = parseLrc(syncedLrc);
      if (parsed.isNotEmpty) {
        return LyricsFound(
          lines: parsed,
          isSynced: true,
          source: source,
          isPossibleMismatch: isPossibleMismatch,
        );
      }
    }
    final fallbackText = plainText ?? syncedLrc;
    if (fallbackText == null) return null;
    final plainLines = splitPlainLyrics(fallbackText);
    if (plainLines.isEmpty) return null;
    return LyricsFound(
      lines: plainLines,
      isSynced: false,
      source: source,
      isPossibleMismatch: isPossibleMismatch,
    );
  }

  String _messageFor(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => 'Lyrics lookup timed out.',
      DioExceptionType.connectionError => 'No connection — check your network and try again.',
      _ => 'Couldn\'t fetch lyrics right now.',
    };
  }
}
