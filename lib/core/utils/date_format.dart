/// Formats an ISO-8601 date string (`"2026-09-15"`) as `"September 15,
/// 2026"`. Hand-written rather than pulling in `intl` for one call site —
/// see CLAUDE.md's Phase 1 decision to keep the dependency footprint
/// minimal wherever a small hand-rolled utility covers it.
///
/// Returns [isoDate] unchanged if it doesn't parse as a date, so a
/// malformed `release_date` in the remote manifest degrades to showing the
/// raw string rather than throwing.
String formatReleaseDate(String isoDate) {
  final date = DateTime.tryParse(isoDate);
  if (date == null) return isoDate;
  return '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';
}

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
