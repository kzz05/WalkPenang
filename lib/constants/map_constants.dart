import '../models/lat_lng.dart';

/// Fixed values for the Map & GPS module (UC-007, UC-008, UC-009, UC-M04).
///
/// Never hardcode the Penang boundary, radius options, or check-in threshold
/// anywhere else — everything reads from here.
class MapConstants {
  const MapConstants._();

  /// Approximate bounding box for Penang State, used to restrict map panning
  /// (UC-009) and to reject destinations outside the state.
  static const LatLngBounds penangBounds = LatLngBounds(
    southwest: LatLng(5.2350, 100.1500),
    northeast: LatLng(5.5900, 100.5500),
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

  /// A compromise between two failure modes seen on-device.
  ///
  /// At 14 (the original) the style's building extrusions haven't started, so
  /// the map is flat and the gamified look is absent. At 16 the buildings are
  /// great but a 55-degree pitch leaves only a few hundred metres of ground
  /// visible — the app would fetch twenty nearby places and show none of
  /// their pins on screen.
  ///
  /// 15 keeps the extrusions (they ramp in from 14 in the style) while showing
  /// roughly four times the ground area, so the pins are actually findable.
  static const double defaultZoom = 15.0;

  /// UC-008: how far (in metres) the tourist must move before the live
  /// position marker refreshes while the map screen is open.
  static const int locationUpdateDistanceFilterMeters = 5;

  /// The custom Mapbox Studio style — the sand palette from
  /// `theme/app_theme.dart` applied to the basemap, labels stripped back, and
  /// buildings extruded. Overridable at build time so a teammate without
  /// access to the shared Studio account can point at their own copy:
  /// `flutter run --dart-define=MAPBOX_STYLE_URI=mapbox://styles/...`
  static const String gamifiedStyleUri = String.fromEnvironment(
    'MAPBOX_STYLE_URI',
    defaultValue: 'mapbox://styles/ianw52/cmssura7i000301qw83jtfjx5',
  );

  /// Camera tilt. The single biggest contributor to the gamified read — a
  /// flat top-down map reads as a utility, a pitched one reads as a game
  /// board. Pitch gestures are disabled so it can't be flattened back to 2D.
  static const double gamifiedPitchDegrees = 55.0;

  /// Feeds `CameraBoundsOptions` alongside [penangBounds] (UC-009 step 3).
  /// The floor is 12 rather than 10: below that the Penang bounds occupy so
  /// little of the viewport that the constraint fights every pan gesture.
  static const double minZoom = 12.0;
  static const double maxZoom = 19.0;
}
