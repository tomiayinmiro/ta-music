/// Pure skip-detection threshold check, pulled out of `AudioPlayerHandler`
/// for the same reason as `relative_queue_index.dart` — the handler talks to
/// platform channels immediately in its constructor, so nothing on it is
/// directly unit-testable in `flutter_test`'s host-VM environment.
///
/// A skip is a listen that was never counted as a real play (never crossed
/// the 50%-or-completion rule) whose furthest position reached landed under
/// both 30 seconds and 50% of the track's duration. See `_migrationV14`'s
/// doc in `database.dart` for why this, rather than `play_history` or
/// `listening_segments`, is what the recommendation engine's skip signal is
/// built on.
bool isSkip({required int positionMs, required int durationMs, required bool countedThisPlay}) {
  if (countedThisPlay || durationMs <= 0) return false;
  return positionMs < 30000 && positionMs / durationMs < 0.5;
}
