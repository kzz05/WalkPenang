import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'transit_details.dart';

/// A single turn-by-turn instruction within a route (UC-M05), one entry
/// from a Directions API leg's `steps[]` array. For a transit route this
/// mixes plain walking steps (to/from stops) with `TRANSIT` steps that
/// carry [transitDetails].
class RouteStep {
  final String instruction;
  final String maneuver;
  final double distanceMeters;
  final int durationSeconds;
  final LatLng startLocation;
  final LatLng endLocation;
  final List<LatLng> polylinePoints;

  /// Raw Directions API `travel_mode` for this step — `WALKING`, `DRIVING`,
  /// or `TRANSIT`. Only meaningful within a transit route, where steps mix
  /// modes; for a walking/driving route every step shares the route's mode.
  final String travelMode;

  /// Non-null only when [travelMode] is `TRANSIT` — the bus/train leg this
  /// step rides.
  final TransitDetails? transitDetails;

  RouteStep({
    required this.instruction,
    required this.maneuver,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.startLocation,
    required this.endLocation,
    required this.polylinePoints,
    this.travelMode = 'WALKING',
    this.transitDetails,
  });
}
