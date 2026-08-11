import 'package:geolocator/geolocator.dart';

import '../constants/map_constants.dart';
import '../models/gps_location.dart';

/// GPS Location Sub Module (UC-008). Wraps the Geolocator package so the
/// rest of the app never talks to it directly.
class LocationService {
  /// UC-008 step 2 / A1: true only once both the device's GPS service and
  /// the app's location permission are confirmed on.
  Future<bool> requestLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
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
