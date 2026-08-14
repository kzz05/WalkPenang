import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'lat_lng.dart';

/// The only place the module's [LatLng] is converted to Mapbox geometry.
///
/// Mapbox follows GeoJSON, where a `Position` is **longitude first**, the
/// reverse of the latitude-first [LatLng] every other file in this module
/// uses. Getting that backwards is silent — no error, no crash, the map just
/// centres somewhere in the Indian Ocean — so the conversion lives here once
/// instead of being retyped at each call site.
extension LatLngMapbox on LatLng {
  Point get toPoint => Point(coordinates: Position(longitude, latitude));
}

extension LatLngBoundsMapbox on LatLngBounds {
  /// UC-009 step 3: the camera constraint that stops panning out of Penang.
  CoordinateBounds toCoordinateBounds() => CoordinateBounds(
    southwest: southwest.toPoint,
    northeast: northeast.toPoint,
    infiniteBounds: false,
  );
}

/// Mapbox -> module direction, for camera and annotation callbacks.
extension PointLatLng on Point {
  LatLng get toLatLng => LatLng(
    coordinates.lat.toDouble(),
    coordinates.lng.toDouble(),
  );
}
