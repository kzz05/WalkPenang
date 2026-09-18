/// User-facing strings for every alternative flow in the Map & GPS use
/// cases (UC-007, UC-008, UC-009, UC-M04, UC-M05). Views and controllers
/// reference these constants instead of inlining string literals, so wording
/// stays consistent and only needs to change in one place.
class MapErrorMessages {
  const MapErrorMessages._();

  // UC-007
  static const locationPermissionDenied =
      'Location permission is required. Please enable it in your device settings.';
  static const noPlacesFound =
      'No places found nearby. Try increasing your search radius.';
  static const mapLoadFailed =
      'Unable to load map. Please check your internet connection.';

  // UC-008
  static const gpsDisabled =
      'Please enable GPS to detect your current location.';
  static const weakGpsSignal =
      'Weak GPS signal. Your location may not be accurate.';
  static const locationTimeout =
      'Unable to detect your location. Please try again.';

  // UC-009
  static const outsidePenangUser =
      'You are currently outside Penang. Some features may be unavailable.';
  static const outsidePenangDestination =
      'This destination is outside Penang. Please select a location within Penang.';

  // UC-M04
  static const noRouteFound =
      'No route found for this travel mode. Try a different mode or destination.';
  static const networkLostDuringRoute =
      'Unable to calculate route. Please check your internet connection.';

  // UC-M05
  /// Shown when the public-transport hand-off to the Google Maps app (or the
  /// browser, if it isn't installed) could not be opened at all. The tourist
  /// stays on the route summary; nothing else about the journey changes.
  static const externalMapsLaunchFailed = 'Unable to open Google Maps.';

  /// UC-M05 rerouting: the tourist has left the route and the replacement
  /// route could not be fetched (no connection, API failure, or no route back
  /// from where they now are). Navigation deliberately keeps running on the
  /// original directions — a stale route still shows where the destination is,
  /// which is more than a blank screen does — so this is worded as something
  /// that can be retried, not as the session having ended.
  static const rerouteFailed =
      'Could not update your route. Still showing the original directions.';

  /// Shown while a replacement route is being fetched (UC-M05 rerouting).
  static const rerouting = 'Recalculating route…';
}
