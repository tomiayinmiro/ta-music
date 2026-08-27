import 'dart:async';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../../models/song.dart';
import '../../repositories/lyrics_repository.dart';
import 'filename_lyrics_parser.dart';

/// Kicks off a background lyrics lookup whenever the playing song changes,
/// so the lyrics panel already has an answer cached by the time the user
/// taps LYRICS — see CLAUDE.md Phase 5 batch 1 rework's "background
/// auto-fetch" requirement. Owned by [AudioPlayerHandler] and driven from
/// its `_onIndexChanged`, the same event that updates the lockscreen
/// `mediaItem` — not the 50%-played `play_history` event, which fires much
/// later than a song actually starting.
///
/// Two independent guards keep this from competing with playback or
/// hammering the network:
/// - A debounce ([debounceDuration]) so rapidly skipping through songs only
///   ever fires a fetch for the song the user actually settles on, and any
///   fetch already in flight is cancelled via [CancelToken] the moment the
///   song changes again.
/// - An in-memory "last attempted" gate ([retryGate]): a song replayed
///   repeatedly within the same listening session won't re-hit the network
///   on every single replay, even if the previous attempt errored out
///   (network errors aren't cached in [LyricsRepository] — see its doc —
///   since a manual Retry tap from the lyrics panel should always bypass
///   this and try again immediately; this gate applies only to *this*
///   automatic path). Deliberately in-memory, not persisted: it resets on
///   app restart, which is fine — it exists to smooth out one session, not
///   to be a durable record.
class LyricsPrefetchService {
  LyricsPrefetchService({
    required this._repository,
    this.debounceDuration = const Duration(milliseconds: 1500),
    this.retryGate = const Duration(hours: 1),
    this._now = DateTime.now,
    this._scheduler = Timer.new,
  });

  final LyricsRepository _repository;
  final Duration debounceDuration;
  final Duration retryGate;
  final DateTime Function() _now;
  final Timer Function(Duration delay, void Function() callback) _scheduler;

  final _logger = Logger();
  final Map<String, DateTime> _lastAttemptedAt = {};

  Timer? _debounce;
  CancelToken? _cancelToken;

  /// Call whenever the currently-playing song changes. `null` (queue
  /// cleared/stopped) just cancels anything pending.
  void onSongChanged(Song? song) {
    _debounce?.cancel();
    _cancelToken?.cancel('song changed');
    if (song == null) return;
    _debounce = _scheduler(debounceDuration, () => unawaited(_fetch(song)));
  }

  Future<void> _fetch(Song song) async {
    // Many downloaded files carry no ID3 tags at all — recover a usable
    // artist/title from the filename before giving up, same resolution
    // `LyricsRepository.getLyrics` itself performs. Doing it here too (not
    // just inside the repository) lets a song that resolves to nothing
    // usable (e.g. "138697771_.mp3") skip without ever calling the
    // repository, matching this service's existing "skip silently, no
    // network" contract for untagged songs.
    final resolved = resolveArtistTitleForLyrics(
      id3Artist: song.artist,
      id3Title: song.title,
      audioFilePath: song.path,
    );
    final artist = resolved.artist;
    final title = resolved.title;
    if (artist == null || artist.isEmpty || title == null || title.isEmpty) {
      _logger.i(
        '[lyrics] prefetch SKIPPED (missing artist/title, filename fallback exhausted) '
        'path=${song.path}',
      );
      return;
    }
    if (resolved.usedFilenameFallback) {
      _logger.i(
        '[lyrics] prefetch using filename-parsed artist/title path=${song.path} '
        'artist="$artist" title="$title"',
      );
    }

    final key = '${artist.toLowerCase()}|${title.toLowerCase()}';
    final lastAttempt = _lastAttemptedAt[key];
    if (lastAttempt != null && _now().difference(lastAttempt) < retryGate) {
      _logger.i('[lyrics] prefetch SKIPPED (attempted recently) artist="$artist" title="$title"');
      return;
    }
    _lastAttemptedAt[key] = _now();

    final token = CancelToken();
    _cancelToken = token;
    _logger.i('[lyrics] prefetch START artist="$artist" title="$title"');
    try {
      final result = await _repository.getLyrics(
        artist: artist,
        title: title,
        album: song.album,
        duration: song.durationMs != null ? song.duration : null,
        audioFilePath: song.path,
        cancelToken: token,
      );
      _logger.i(
        '[lyrics] prefetch DONE artist="$artist" title="$title" result=${result.runtimeType}',
      );
    } on DioException catch (e) {
      if (e.type != DioExceptionType.cancel) rethrow;
      _logger.i(
        '[lyrics] prefetch CANCELLED (song changed mid-fetch) artist="$artist" title="$title"',
      );
    }
  }

  void dispose() {
    _debounce?.cancel();
    _cancelToken?.cancel('disposed');
  }
}
