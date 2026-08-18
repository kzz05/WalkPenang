import 'package:google_maps_flutter/google_maps_flutter.dart';

/// A single turn-by-turn instruction within a walking route (UC-M05), one
/// entry from a Directions API leg's `steps[]` array.
class RouteStep {
  final String instruction;
  final String maneuver;
  final double distanceMeters;
  final int durationSeconds;
  final LatLng startLocation;
  final LatLng endLocation;
  final List<LatLng> polylinePoints;

  RouteStep({
    required this.instruction,
    required this.maneuver,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.startLocation,
    required this.endLocation,
    required this.polylinePoints,
  });
}
