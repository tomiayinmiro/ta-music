import 'package:flutter/foundation.dart';

/// Pure wall-clock listened-time accumulator, deliberately decoupled from
/// `AudioPlayer`/`just_audio` so it's directly unit-testable — same
/// reasoning as `relative_queue_index.dart` (`AudioPlayerHandler` can't be
/// constructed in `flutter_test`'s host-VM environment; it talks to
/// platform channels immediately).
///
/// This class has no concept of track duration, position, or seeking — it
/// only ever measures real time elapsed between [start] and [flush] calls.
/// That's what makes seeking a non-issue for free: a seek changes the
/// player's reported position without any wall-clock time passing, so it
/// can't inflate what gets credited here no matter how far the position
/// itself jumps. `AudioPlayerHandler` is the only real caller — it opens a
/// window when `AudioPlayer.playing` becomes true, flushes and re-opens on
/// a song change, flushes (closing) when `playing` becomes false, and
/// flushes-and-reopens on a periodic timer for crash resilience.
@immutable
class ListenedSegment {
  const ListenedSegment({required this.songId, required this.elapsedMs});

  final int songId;
  final int elapsedMs;
}

class ListeningTimeAccumulator {
  int? _openSongId;
  DateTime? _windowStartedAt;

  /// True while a window is currently open (actively "listening").
  bool get isOpen => _windowStartedAt != null;

  /// Opens a new accumulation window for [songId] at [now]. A no-op if a
  /// window for the same song is already open, so a spurious duplicate
  /// start signal (e.g. two "playing" events in a row) doesn't reset the
  /// clock and lose whatever's already elapsed.
  void start(int songId, DateTime now) {
    if (isOpen && _openSongId == songId) return;
    _openSongId = songId;
    _windowStartedAt = now;
  }

  /// Closes whatever window is open, returning the elapsed time to credit
  /// — or `null` if nothing was open, or nothing measurable elapsed.
  ///
  /// [keepOpen] immediately re-opens a fresh window for the same song at
  /// [now] instead of closing outright — used by the periodic
  /// crash-resilience flush, where tracking should continue seamlessly
  /// after each chunk is persisted rather than losing the open window.
  ListenedSegment? flush(DateTime now, {bool keepOpen = false}) {
    final songId = _openSongId;
    final startedAt = _windowStartedAt;
    if (songId == null || startedAt == null) return null;

    final elapsedMs = now.difference(startedAt).inMilliseconds;
    _windowStartedAt = keepOpen ? now : null;
    if (!keepOpen) _openSongId = null;

    return elapsedMs > 0 ? ListenedSegment(songId: songId, elapsedMs: elapsedMs) : null;
  }
}
