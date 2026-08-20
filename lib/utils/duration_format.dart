/// Formats minutes the way Google Maps does: "20 min" under an hour,
/// "1h 6m" (or "1h" on the hour) once it crosses one. Shared by the UC-M04
/// mode-comparison tabs and UC-M05's live remaining-time display.
String formatEtaMinutes(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  return remainingMinutes == 0 ? '${hours}h' : '${hours}h ${remainingMinutes}m';
}
