import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../constants/map_constants.dart';
import '../models/gps_location.dart';

/// Boundary Validation Sub Module (UC-009). Checks GPS points against the
/// fixed Penang [LatLngBounds] — nothing here talks to the network.
class BoundaryValidatorService {
  /// UC-009 step 2 / A1: is the tourist's current position inside Penang?
  bool validateUserLocation(GpsLocation location) {
    return _isWithinBounds(
      LatLng(location.latitude, location.longitude),
      MapConstants.penangBounds,
    );
  }

  /// UC-009 step 5 / A2: is a tapped destination pin inside Penang?
  bool validateDestination(LatLng destination) {
    return _isWithinBounds(destination, MapConstants.penangBounds);
  }

  /// UC-009 step 3: the bounds `GoogleMap.cameraTargetBounds` is built from,
  /// so panning outside Penang is blocked at the map-widget level.
  LatLngBounds get panningBounds => MapConstants.penangBounds;

  bool _isWithinBounds(LatLng point, LatLngBounds bounds) {
    final withinLat = point.latitude >= bounds.southwest.latitude &&
        point.latitude <= bounds.northeast.latitude;
    final withinLng = point.longitude >= bounds.southwest.longitude &&
        point.longitude <= bounds.northeast.longitude;
    return withinLat && withinLng;
  }
}
