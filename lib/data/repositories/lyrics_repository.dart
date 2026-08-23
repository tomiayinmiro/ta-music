import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../database/daos/lyrics_cache_dao.dart';
import '../services/lyrics/lrc_parser.dart';
import '../services/lyrics/lrclib_client.dart';
import '../services/lyrics/local_lrc_file_reader.dart';

final _log = Logger();

/// A cached "not found" result is re-fetched after this long — coverage
/// across all 3 layers grows over time, so a song with no lyrics today
/// might have them later. A successful lookup has no TTL at all: lyrics
/// text doesn't change once found.
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
/// is `'lrclib'`, `'lyrics.ovh'`, or `'local_lrc'`.
class LyricsFound extends LyricsResult {
  const LyricsFound({required this.lines, required this.isSynced, required this.source});

  final List<LyricsLine> lines;
  final bool isSynced;
  final String source;
}

/// Looked up (locally cached or via all 3 layers) and confirmed there are no
/// lyrics for this song.
class LyricsNotFound extends LyricsResult {
  const LyricsNotFound();
}

/// The current song has no artist or title tag to look up — no layer was
/// ever called.
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

sealed class _LayerOutcome {
  const _LayerOutcome();
}

/// Raw hit — not yet parsed/validated. [syncedLrc] and [plainText] mirror
/// exactly what the layer returned (both may be present, e.g. LRCLIB), and
/// are cached verbatim so a later cache read can rebuild the same result.
class _RawHit extends _LayerOutcome {
  const _RawHit({this.syncedLrc, this.plainText});
  final String? syncedLrc;
  final String? plainText;
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
/// best-effort on Android.
///
/// A layer's network error doesn't stop the chain — the next layer is still
/// tried — but if every layer that could have produced an answer errored
/// out (none definitively found or definitively missed), the whole lookup
/// reports [LyricsFetchError] instead of caching a false "not found".
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
    final trimmedArtist = artist?.trim();
    final trimmedTitle = title?.trim();
    if (trimmedArtist == null ||
        trimmedArtist.isEmpty ||
        trimmedTitle == null ||
        trimmedTitle.isEmpty) {
      return const LyricsMissingMetadata();
    }
    final artistKey = trimmedArtist.toLowerCase();
    final titleKey = trimmedTitle.toLowerCase();

    final cached = await _cacheDao.find(artistKey, titleKey);
    if (cached != null) {
      final source = cached['source'] as String;
      if (source != 'none') {
        _log.i('[lyrics] cache HIT source=$source artist="$trimmedArtist" title="$trimmedTitle"');
        return _resultFromRow(cached);
      }
      final fetchedAt = DateTime.fromMillisecondsSinceEpoch(cached['fetched_at'] as int);
      if (now().difference(fetchedAt) < _notFoundTtl) {
        _log.i(
          '[lyrics] cache HIT (not-found, within TTL) artist="$trimmedArtist" title="$trimmedTitle"',
        );
        return const LyricsNotFound();
      }
      _log.i(
        '[lyrics] cache STALE (not-found, past TTL) artist="$trimmedArtist" title="$trimmedTitle" — re-fetching',
      );
      // Past the TTL — fall through and re-run the chain.
    } else {
      _log.i('[lyrics] cache MISS artist="$trimmedArtist" title="$trimmedTitle"');
    }

    return _fetchAndCache(
      artist: trimmedArtist,
      title: trimmedTitle,
      artistKey: artistKey,
      titleKey: titleKey,
      album: album,
      duration: duration,
      audioFilePath: audioFilePath,
      cancelToken: cancelToken,
      now: now,
    );
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
        case _RawHit(:final syncedLrc, :final plainText):
          final found = _buildFound(source: source, syncedLrc: syncedLrc, plainText: plainText);
          if (found == null) return null;
          await _cacheDao.upsert(
            artistKey: artistKey,
            titleKey: titleKey,
            source: source,
            hasSyncedTiming: found.isSynced,
            syncedLyricsLrc: syncedLrc,
            plainLyrics: plainText,
            fetchedAt: now(),
          );
          _log.i(
            '[lyrics] result=FOUND source=$source synced=${found.isSynced} '
            'artist="$artist" title="$title"',
          );
          return found;
      }
    }

    final lrclibResult = await tryLayer(
      await _tryLrclib(
        artist: artist,
        title: title,
        album: album,
        duration: duration,
        cancelToken: cancelToken,
      ),
      'lrclib',
    );
    if (lrclibResult != null) return lrclibResult;

    final ovhResult = await tryLayer(
      await _tryLyricsOvh(artist: artist, title: title, cancelToken: cancelToken),
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

  Future<_LayerOutcome> _tryLrclib({
    required String artist,
    required String title,
    String? album,
    Duration? duration,
    CancelToken? cancelToken,
  }) async {
    try {
      var track = await _lrclibClient.get(
        trackName: title,
        artistName: artist,
        albumName: album,
        duration: duration,
        cancelToken: cancelToken,
      );
      track ??= await _lrclibClient.search(
        trackName: title,
        artistName: artist,
        duration: duration,
        cancelToken: cancelToken,
      );
      if (track == null || !track.hasLyrics) return const _Miss();
      return _RawHit(syncedLrc: track.syncedLyrics, plainText: track.plainLyrics);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      _log.i('[lyrics] lrclib FAILED artist="$artist" title="$title" message=${e.message}');
      return _FetchFailure(_messageFor(e), isRateLimited: e.response?.statusCode == 429);
    }
  }

  Future<_LayerOutcome> _tryLyricsOvh({
    required String artist,
    required String title,
    CancelToken? cancelToken,
  }) async {
    final uri = Uri(scheme: 'https', host: 'api.lyrics.ovh', pathSegments: ['v1', artist, title]);
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
      _log.i('[lyrics] lyrics.ovh FAILED artist="$artist" title="$title" message=${e.message}');
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
    );
    return found ?? const LyricsNotFound();
  }

  /// Prefers real timing: [syncedLrc] is parsed first, and only falls back
  /// to [plainText] (or, failing that, [syncedLrc]'s own raw text) if
  /// parsing yields nothing usable. Returns null if there's genuinely
  /// nothing displayable, so the caller can treat this layer as a miss
  /// rather than showing an empty lyrics view.
  LyricsFound? _buildFound({required String source, String? syncedLrc, String? plainText}) {
    if (syncedLrc != null && syncedLrc.trim().isNotEmpty) {
      final parsed = parseLrc(syncedLrc);
      if (parsed.isNotEmpty) {
        return LyricsFound(lines: parsed, isSynced: true, source: source);
      }
    }
    final fallbackText = plainText ?? syncedLrc;
    if (fallbackText == null) return null;
    final plainLines = splitPlainLyrics(fallbackText);
    if (plainLines.isEmpty) return null;
    return LyricsFound(lines: plainLines, isSynced: false, source: source);
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
