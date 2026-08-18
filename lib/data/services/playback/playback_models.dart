import 'package:flutter/foundation.dart';

import '../../models/song.dart';

/// Playback status as the app understands it — a simplified projection of
/// `just_audio`'s `ProcessingState` + `playing` flag, named the way
/// CLAUDE.md's Phase 3 brief asks for (playing / paused / buffering /
/// stopped) rather than exposing `just_audio` types to the rest of the app.
enum PlaybackStatus { stopped, buffering, playing, paused }

/// Repeat mode. Named `PlayerRepeatMode` (not `RepeatMode`) to avoid any
/// ambiguity with types from `package:audio_service` or `package:just_audio`.
enum PlayerRepeatMode { off, one, all }

/// A snapshot of everything the UI needs to render playback state in one
/// shot, so widgets can watch a single provider instead of combining many.
@immutable
class PlaybackSnapshot {
  const PlaybackSnapshot({
    required this.queue,
    required this.currentIndex,
    required this.status,
    required this.position,
    required this.duration,
    required this.shuffleEnabled,
    required this.repeatMode,
    required this.hasNext,
    required this.hasPrevious,
  });

  final List<Song> queue;
  final int? currentIndex;
  final PlaybackStatus status;
  final Duration position;
  final Duration? duration;
  final bool shuffleEnabled;
  final PlayerRepeatMode repeatMode;

  /// From the player directly (`AudioPlayer.hasNext`/`hasPrevious`) rather
  /// than computed from [currentIndex]/[queue] here, so these stay correct
  /// under shuffle (where "next" isn't sequential index order).
  final bool hasNext;
  final bool hasPrevious;

  Song? get currentSong =>
      (currentIndex != null && currentIndex! >= 0 && currentIndex! < queue.length)
          ? queue[currentIndex!]
          : null;

  static const empty = PlaybackSnapshot(
    queue: [],
    currentIndex: null,
    status: PlaybackStatus.stopped,
    position: Duration.zero,
    duration: null,
    shuffleEnabled: false,
    repeatMode: PlayerRepeatMode.off,
    hasNext: false,
    hasPrevious: false,
  );
}
