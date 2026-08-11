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
  static const noWalkableRoute =
      'No walking route found for this destination. Please select a different location.';
  static const networkLostDuringRoute =
      'Unable to calculate route. Please check your internet connection.';

  // UC-M05
  static const navigationLaunchFailed =
      'Unable to open navigation. Please try again.';
  static const googleMapsNotInstalled =
      'Google Maps is not installed. Redirecting to the Play Store.';
}
