/// Formats a distance the way Google Maps does: whole metres while they're
/// still countable, kilometres once they aren't. Shared by UC-M04's route
/// summary and UC-M05's live navigation read-outs.
String formatDistanceMeters(double meters) {
  if (meters < 1000) {
    // Round to 10 m above 100 m — GPS isn't accurate to the metre at that
    // range, and "480 m" reads more honestly than "483 m".
    final rounded = meters >= 100 ? (meters / 10).round() * 10 : meters.round();
    return '$rounded m';
  }
  final km = meters / 1000;
  return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
}

String formatDistanceKm(double km) => formatDistanceMeters(km * 1000);
