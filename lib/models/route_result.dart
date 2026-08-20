import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'route_step.dart';

/// Result of a walking-route calculation (UC-M04), built from a Google Maps
/// Directions API response. [steps] carries the turn-by-turn instructions
/// used to drive in-app navigation (UC-M05).
class RouteResult {
  final double distanceKm;
  final int durationMinutes;
  final List<LatLng> polylinePoints;
  final List<RouteStep> steps;
  final bool routeFound;

  RouteResult({
    required this.distanceKm,
    required this.durationMinutes,
    required this.polylinePoints,
    this.steps = const [],
    this.routeFound = true,
  });

  factory RouteResult.notFound() => RouteResult(
    distanceKm: 0,
    durationMinutes: 0,
    polylinePoints: [],
    steps: [],
    routeFound: false,
  );
}
