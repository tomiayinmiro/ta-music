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

/// One frequency band of the device's real Android equalizer — a
/// platform-decoupled projection of `just_audio`'s `AndroidEqualizerBand`
/// (Phase 6 batch 2, Android-only per CLAUDE.md; see `AudioPlayerHandler`).
/// [centerFrequencyHz] and [index] are read-only device facts, not something
/// the app chooses — device band count/frequencies vary (5 is typical, but
/// not guaranteed), which is why the Equalizer screen renders however many
/// bands [EqualizerParameters.bands] actually reports rather than a fixed
/// count.
@immutable
class EqualizerBand {
  const EqualizerBand({required this.index, required this.centerFrequencyHz});

  final int index;
  final double centerFrequencyHz;
}

/// The device's real equalizer capabilities, resolved once `AndroidEqualizer`
/// activates on the platform side (only after audio has actually loaded —
/// see `AudioPlayerHandler.equalizerParameters`'s doc).
@immutable
class EqualizerParameters {
  const EqualizerParameters({required this.minDecibels, required this.maxDecibels, required this.bands});

  final double minDecibels;
  final double maxDecibels;
  final List<EqualizerBand> bands;
}
