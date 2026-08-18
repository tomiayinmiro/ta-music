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
