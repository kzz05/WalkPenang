/// Formats minutes the way Google Maps does: "20 min" under an hour,
/// "1h 6m" (or "1h" on the hour) once it crosses one. Shared by the UC-M04
/// mode-comparison tabs and UC-M05's live remaining-time display.
String formatEtaMinutes(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  return remainingMinutes == 0 ? '${hours}h' : '${hours}h ${remainingMinutes}m';
}

/// Wall-clock arrival time in the 12-hour form Malaysian tourists read on
/// bus timetables and Google Maps alike ("3:45 pm").
String formatClockTime(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${time.hour < 12 ? 'am' : 'pm'}';
}
