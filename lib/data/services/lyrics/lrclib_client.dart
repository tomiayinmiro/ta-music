import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// One LRCLIB track result — either endpoint can return both fields
/// populated (LRCLIB stores plain and synced lyrics side by side), one, or
/// neither (an instrumental track with no lyrics at all, which is a
/// legitimate miss, not an error).
@immutable
class LrclibTrack {
  const LrclibTrack({
    this.plainLyrics,
    this.syncedLyrics,
    this.durationSeconds,
    this.artistName,
    this.trackName,
  });

  final String? plainLyrics;
  final String? syncedLyrics;
  final num? durationSeconds;

  /// The artist/track name LRCLIB actually has this hit filed under —
  /// previously discarded entirely, so nothing could ever verify a hit
  /// actually matches the artist we queried for. See `artist_match.dart`.
  final String? artistName;
  final String? trackName;

  bool get hasLyrics =>
      (plainLyrics != null && plainLyrics!.trim().isNotEmpty) ||
      (syncedLyrics != null && syncedLyrics!.trim().isNotEmpty);
}

/// Client for lrclib.net's public API (https://lrclib.net/docs) — MIT
/// licensed, no API key, no meaningful rate limit. Primary lyrics source per
/// Phase 5 batch 1's rework; see `LyricsRepository` for where this sits in
/// the 3-layer fallback chain.
class LrclibClient {
  LrclibClient(this._dio);

  final Dio _dio;
  final _logger = Logger();

  static Options get _timeouts => Options(
    sendTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  );

  /// Exact-match lookup. Returns `null` on a 404 (no exact match — the
  /// caller should fall back to [search]); throws [DioException] for any
  /// other failure so the repository can classify it as a transient error.
  Future<LrclibTrack?> get({
    required String trackName,
    required String artistName,
    String? albumName,
    Duration? duration,
    CancelToken? cancelToken,
  }) async {
    final uri = Uri.https('lrclib.net', '/api/get', {
      'track_name': trackName,
      'artist_name': artistName,
      if (albumName != null && albumName.trim().isNotEmpty) 'album_name': albumName,
      if (duration != null && duration > Duration.zero) 'duration': duration.inSeconds.toString(),
    });
    _logger.i('[lyrics] lrclib GET $uri');
    try {
      final response = await _dio.getUri<Map<String, dynamic>>(
        uri,
        options: _timeouts,
        cancelToken: cancelToken,
      );
      return _fromMap(response.data);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      if (e.response?.statusCode == 404) {
        _logger.i('[lyrics] lrclib GET 404 (no exact match) $uri');
        return null;
      }
      rethrow;
    }
  }

  /// Fuzzy search, used when [get] 404s. Picks the candidate whose duration
  /// is closest to [duration] (when known); otherwise the first candidate
  /// that actually has lyrics. Returns `null` if nothing usable comes back.
  Future<LrclibTrack?> search({
    required String trackName,
    required String artistName,
    Duration? duration,
    CancelToken? cancelToken,
  }) async {
    final uri = Uri.https('lrclib.net', '/api/search', {
      'track_name': trackName,
      'artist_name': artistName,
    });
    _logger.i('[lyrics] lrclib SEARCH $uri');
    final response = await _dio.getUri<List<dynamic>>(
      uri,
      options: _timeouts,
      cancelToken: cancelToken,
    );
    final candidates = (response.data ?? [])
        .whereType<Map<String, dynamic>>()
        .map(_fromMap)
        .where((track) => track.hasLyrics)
        .toList();
    if (candidates.isEmpty) {
      _logger.i('[lyrics] lrclib SEARCH no lyrics-bearing candidates $uri');
      return null;
    }
    if (duration == null) return candidates.first;

    final targetSeconds = duration.inSeconds;
    candidates.sort((a, b) {
      final diffA = (a.durationSeconds ?? targetSeconds) - targetSeconds;
      final diffB = (b.durationSeconds ?? targetSeconds) - targetSeconds;
      return diffA.abs().compareTo(diffB.abs());
    });
    return candidates.first;
  }

  LrclibTrack _fromMap(Map<String, dynamic>? map) {
    if (map == null) return const LrclibTrack();
    return LrclibTrack(
      plainLyrics: map['plainLyrics'] as String?,
      syncedLyrics: map['syncedLyrics'] as String?,
      durationSeconds: map['duration'] as num?,
      artistName: map['artistName'] as String?,
      trackName: map['trackName'] as String?,
    );
  }
}
