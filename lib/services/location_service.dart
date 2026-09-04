import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
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

  /// Journey tracking: fixes filtered to [MapConstants
  /// .locationUpdateDistanceFilterMeters] so a stationary tourist's GPS
  /// jitter is never counted as distance walked.
  Stream<GpsLocation> startLocationUpdates() {
    return Geolocator.getPositionStream(
      locationSettings: _settings(
        accuracy: LocationAccuracy.high,
        distanceFilter: MapConstants.locationUpdateDistanceFilterMeters,
        interval: MapConstants.mapUpdateInterval,
      ),
    ).map(_toGpsLocation);
  }

  /// UC-008 step 7: the map screen's live position marker.
  ///
  /// Unfiltered and once a second, because this is the one the tourist is
  /// looking at — see [MapConstants.mapUpdateDistanceFilterMeters]. Distance
  /// walked is not derived from this stream, so an unfiltered fix costs
  /// nothing but a metre of drawn wobble.
  Stream<GpsLocation> startMapUpdates() {
    return Geolocator.getPositionStream(
      locationSettings: _settings(
        accuracy: LocationAccuracy.high,
        distanceFilter: MapConstants.mapUpdateDistanceFilterMeters,
        interval: MapConstants.mapUpdateInterval,
      ),
    ).map(_toGpsLocation);
  }

  /// UC-M05: the navigation-grade variant of [startMapUpdates].
  ///
  /// `bestForNavigation` accuracy asks the platform for the fused sensor + GPS
  /// fix rate a turn-by-turn screen needs. It costs battery, which is why it
  /// is scoped to the navigation screen only.
  Stream<GpsLocation> startNavigationUpdates() {
    return Geolocator.getPositionStream(
      locationSettings: _settings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: MapConstants.navigationUpdateDistanceFilterMeters,
        interval: MapConstants.navigationUpdateInterval,
      ),
    ).map(_toGpsLocation);
  }

  /// Platform settings for a position stream.
  ///
  /// Android needs [AndroidSettings] rather than a plain [LocationSettings]:
  /// only the Android subclass carries `intervalDuration` across the channel.
  /// Without it geolocator_android defaults to 5000 ms *and* pins the minimum
  /// update interval to the same figure — one fix every five seconds, whatever
  /// the distance filter says. That is invisible from Dart, and it is what made
  /// both the map marker and the navigation puck move in five-second hops.
  LocationSettings _settings({
    required LocationAccuracy accuracy,
    required int distanceFilter,
    required Duration interval,
  }) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        intervalDuration: interval,
      );
    }

    return LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
    );
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
