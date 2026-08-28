import 'package:geolocator/geolocator.dart';

import '../constants/map_constants.dart';
import '../models/gps_location.dart';

/// Why the app can't read the tourist's position (UC-008 A1).
///
/// "Permission denied" and "GPS switched off" used to collapse into one
/// boolean, which meant the map could only ever say "something's wrong" — the
/// two need different screens to fix, so the caller has to be able to tell
/// them apart to offer the right button.
enum LocationAvailability {
  granted,

  /// Device location services are off — fixed in system settings.
  serviceDisabled,

  /// The app was refused permission, but can ask again.
  permissionDenied,

  /// Refused permanently ("don't ask again") — only app settings can undo it.
  permissionDeniedForever,
}

/// GPS Location Sub Module (UC-008). Wraps the Geolocator package so the
/// rest of the app never talks to it directly.
class LocationService {
  /// UC-008 step 2 / A1: checks both the device's GPS service and the app's
  /// own location permission, reporting which one (if either) is blocking.
  Future<LocationAvailability> requestLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationAvailability.serviceDisabled;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationAvailability.granted;
      case LocationPermission.deniedForever:
        return LocationAvailability.permissionDeniedForever;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationAvailability.permissionDenied;
    }
  }

  /// Opens the device's location-services screen — the only place a tourist
  /// can switch GPS back on (UC-008 A1).
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  /// Opens this app's settings page, for a permission the app is no longer
  /// allowed to ask about in-line.
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  /// UC-008 steps 2-4 / A3: one-shot fix. Throws a [TimeoutException] if the
  /// device can't get a lock in time, which the caller maps to
  /// [MapErrorMessages.locationTimeout].
  Future<GpsLocation> getCurrentLocation() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return _toGpsLocation(position);
  }

  /// UC-008 step 7: continuous updates for the live position marker while
  /// the map screen is on screen.
  Stream<GpsLocation> startLocationUpdates() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: MapConstants.locationUpdateDistanceFilterMeters,
      ),
    ).map(_toGpsLocation);
  }

  /// UC-M05: the navigation-grade variant of [startLocationUpdates].
  ///
  /// Two deliberate differences from the browse-screen stream: no distance
  /// filter, because [NavigationView] interpolates the puck between fixes and
  /// a filter would starve that interpolation into a 5 m stutter; and
  /// `bestForNavigation` accuracy, which asks the platform for the fused
  /// sensor + GPS fix rate a turn-by-turn screen needs. Both cost battery,
  /// which is why they're scoped to the navigation screen only.
  Stream<GpsLocation> startNavigationUpdates() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: MapConstants.navigationUpdateDistanceFilterMeters,
      ),
    ).map(_toGpsLocation);
  }

  /// UC-008 A2: flags a weak fix without discarding it.
  bool checkSignalAccuracy(GpsLocation location) => location.isAccurate;

  /// Great-circle distance in metres. Used to decide when the tourist has
  /// walked far enough that the nearby pins are worth refetching.
  double distanceMeters({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  GpsLocation _toGpsLocation(Position position) => GpsLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        timestamp: position.timestamp,
        headingDegrees: position.heading,
        speedMetersPerSecond: position.speed,
      );
}
