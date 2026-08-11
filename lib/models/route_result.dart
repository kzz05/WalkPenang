import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Result of a walking-route calculation (UC-M04), built from a Google Maps
/// Directions API response.
class RouteResult {
  final double distanceKm;
  final int durationMinutes;
  final List<LatLng> polylinePoints;
  final bool routeFound;

  RouteResult({
    required this.distanceKm,
    required this.durationMinutes,
    required this.polylinePoints,
    this.routeFound = true,
  });

  factory RouteResult.notFound() => RouteResult(
    distanceKm: 0,
    durationMinutes: 0,
    polylinePoints: [],
    routeFound: false,
  );
}
