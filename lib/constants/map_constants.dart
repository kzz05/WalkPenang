import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Fixed values for the Map & GPS module (UC-007, UC-008, UC-009, UC-M04).
///
/// Never hardcode the Penang boundary, radius options, or check-in threshold
/// anywhere else — everything reads from here.
class MapConstants {
  const MapConstants._();

  /// Approximate bounding box for Penang State, used to restrict map panning
  /// (UC-009) and to reject destinations outside the state.
  ///
  /// `final`, not `const` — [LatLngBounds]'s constructor runs an `assert`,
  /// which disqualifies it from being a compile-time constant.
  static final LatLngBounds penangBounds = LatLngBounds(
    southwest: const LatLng(5.2350, 100.1500),
    northeast: const LatLng(5.5900, 100.5500),
  );

  static const LatLng georgeTownCenter = LatLng(5.4141, 100.3288);

  static const double defaultSearchRadiusKm = 2.0;
  static const List<double> radiusOptions = [1.0, 2.0, 5.0];

  /// UC-008 A2: below this accuracy the system still shows the reading, but
  /// flags it as unreliable.
  static const double gpsAccuracyThresholdMeters = 20.0;

  /// NFR-02: how close a tourist must be to a destination to count as arrived.
  /// Owned by the Walking & Carbon module's check-in logic, defined here so
  /// both modules read the same number.
  static const double checkInThresholdMeters = 100.0;

  static const double defaultZoom = 14.0;

  /// UC-008: how far (in metres) the tourist must move before the live
  /// position marker refreshes while the map screen is open.
  static const int locationUpdateDistanceFilterMeters = 5;

  /// Compass-follow map rotation (UC-008): skip a camera bearing / puck
  /// rotation update unless the heading has drifted at least this many
  /// degrees since the last applied reading — raw magnetometer output is
  /// noisy enough that redrawing on every sample would look jittery and
  /// burn battery for no visible benefit.
  static const double compassHeadingChangeThresholdDegrees = 3.0;

  /// UC-007: how far the camera must drift from the last search before the
  /// pins on screen stop describing what the tourist is actually looking at,
  /// and "Search this area" becomes worth offering.
  static const double searchThisAreaThresholdMeters = 600;

  // ── UC-M05 in-app navigation ──────────────────────────────────────────

  /// While navigating, every fix matters — the puck is interpolated between
  /// them, so a distance filter would just starve the interpolation and make
  /// the marker jump. The browse screen keeps its 5 m filter for battery.
  static const int navigationUpdateDistanceFilterMeters = 0;

  /// How long the puck/camera takes to glide from the previous fix to the
  /// new one. Clamped around the actual gap between fixes so the marker
  /// neither races ahead of the tourist nor lags visibly behind them.
  static const Duration minNavigationInterpolation = Duration(milliseconds: 350);
  static const Duration maxNavigationInterpolation = Duration(milliseconds: 1600);

  /// Cap on how often the interpolated puck/camera is pushed across the
  /// platform channel. 25 fps reads as continuous motion while costing well
  /// under half of what a per-frame (60 fps) update would.
  static const Duration navigationRenderInterval = Duration(milliseconds: 40);

  /// Below this ground speed, GPS course-over-ground is noise rather than a
  /// direction (the tourist is standing at a crossing), so the puck falls
  /// back to the magnetometer instead.
  static const double navigationCourseMinSpeedMps = 0.6;

  /// Camera tilt while navigating — a slight lean forward shows more of the
  /// road ahead, the way a dedicated turn-by-turn app does.
  static const double navigationCameraTilt = 45.0;

  /// Fraction of the screen height the puck sits at while following, so most
  /// of the map shows what's *ahead* rather than what's already behind.
  /// Applied through `GoogleMap.padding`.
  static const double navigationPuckScreenAnchor = 0.68;
}
