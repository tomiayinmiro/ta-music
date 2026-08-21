/// Formats a stored `songs.duration_ms` value for display, showing "?"
/// instead of "0:00" when the duration is genuinely unknown (null or 0 —
/// bug 8a, device testing pass: a real 0-second track doesn't exist, so a
/// 0 here always means "couldn't be read", never an actual duration).
String formatDurationOrUnknown(int? durationMs) {
  if (durationMs == null || durationMs <= 0) return '?';
  return formatDuration(Duration(milliseconds: durationMs));
}

/// Formats a [Duration] as `m:ss`, or `h:mm:ss` once it reaches an hour.
String formatDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  final seconds = d.inSeconds.remainder(60);
  final secondsStr = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$secondsStr';
  }
  return '$minutes:$secondsStr';
}

/// Formats total listened time as e.g. "12.5 hrs" for the stats panel.
String formatListeningHours(Duration d) {
  final hours = d.inMinutes / 60;
  return '${hours.toStringAsFixed(hours < 10 ? 1 : 0)} hrs';
}

/// Formats a minute count compactly for the Aura Stats card, e.g. "845" or
/// "14.2k" once it crosses 1,000 — matches the mockup's "14.2k" total-mins
/// display without pulling in the `intl` package for one format.
String formatMinutesCompact(int minutes) {
  if (minutes < 1000) return '$minutes';
  return '${(minutes / 1000).toStringAsFixed(1)}k';
}
