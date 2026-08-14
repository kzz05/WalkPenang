import 'package:geolocator/geolocator.dart';

import '../constants/map_constants.dart';
import '../models/gps_location.dart';

/// Why the app cannot read the tourist's location — or that it can.
///
/// These two failures need telling apart because the tourist has to do
/// something different about each: [serviceDisabled] means switching GPS on,
/// [permissionDenied] means granting the app access in settings. Collapsing
/// them into one `false` told a tourist with GPS switched off to change a
/// permission they had already granted.
enum LocationAccessStatus {
  granted,

  /// The device's location service is switched off entirely (UC-M02 A1).
  serviceDisabled,

  /// The service is on, but this app may not use it (UC-M01 A1).
  permissionDenied,
}

/// GPS Location Sub Module (UC-M02). Wraps the Geolocator package so the
/// rest of the app never talks to it directly.
class LocationService {
  /// UC-M02 step 2 / A1: checks the device's location service first, then
  /// this app's permission, and reports which of the two blocked it.
  ///
  /// Order matters: on Android a permission check while the location service
  /// is off can still report `granted`, so asking about the service first is
  /// what makes "GPS is off" distinguishable at all.
  Future<LocationAccessStatus> requestLocationAccess() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationAccessStatus.serviceDisabled;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    final granted = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
    return granted
        ? LocationAccessStatus.granted
        : LocationAccessStatus.permissionDenied;
  }

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
      );
}
