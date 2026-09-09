import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/song.dart';
import '../services/audio_service.dart';
import 'repository_providers.dart';

/// The real [PlaybackService] instance, created in `main()` (it wraps an
/// `AudioHandler` that must exist before `runApp`, so it can't be built
/// lazily like the app's other `FutureProvider`-based services). Overridden
/// via `ProviderScope(overrides: [...])` — there is no usable default.
final playbackServiceProvider = Provider<PlaybackService>((ref) {
  throw UnimplementedError('playbackServiceProvider must be overridden in main()');
});

final currentSongProvider = StreamProvider<Song?>((ref) {
  return ref.watch(playbackServiceProvider).currentSongStream;
});

final playbackPositionProvider = StreamProvider<Duration>((ref) {
  return ref.watch(playbackServiceProvider).positionStream;
});

final playbackStatusProvider = StreamProvider<PlaybackStatus>((ref) {
  return ref.watch(playbackServiceProvider).statusStream;
});

final playbackQueueProvider = StreamProvider<List<Song>>((ref) {
  return ref.watch(playbackServiceProvider).queueStream;
});

final playbackSnapshotProvider = StreamProvider<PlaybackSnapshot>((ref) {
  return ref.watch(playbackServiceProvider).snapshotStream;
});

/// Whether playback should resume automatically once an audio-focus
/// interruption ends — surfaced as a toggle in Settings.
final resumeAfterInterruptionProvider = StreamProvider<bool>((ref) async* {
  final repo = await ref.watch(settingsRepositoryProvider.future);
  yield* repo.watchResumeAfterInterruption();
});

/// Global playback speed multiplier (0.75x-2x) — surfaced in Settings and as
/// a quick-access cycling indicator on Now Playing. `AudioPlayerHandler`
/// applies this reactively via `_player.setSpeed()`.
final playbackSpeedProvider = StreamProvider<double>((ref) async* {
  final repo = await ref.watch(settingsRepositoryProvider.future);
  yield* repo.watchPlaybackSpeed();
});

/// The fixed cycle Now Playing's speed indicator and Settings' speed picker
/// both step through.
const kPlaybackSpeedOptions = [0.75, 1.0, 1.25, 1.5, 2.0];
