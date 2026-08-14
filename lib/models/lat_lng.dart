/// Project-owned coordinate types for the Map & GPS module.
///
/// Deliberately named [LatLng] / [LatLngBounds] with the same field names the
/// Google Maps SDK used, so the services, models and controllers that only
/// ever wanted the *types* could drop the SDK by changing one import line
/// each. Only the two map views talk to a rendering SDK now, which is what
/// made swapping the renderer a contained change rather than a rewrite.
///
/// Latitude first, matching every call site in this module. The Mapbox SDK
/// uses GeoJSON `Position(longitude, latitude)` — the opposite order — so
/// conversions go through the single extension in `lat_lng_mapbox.dart`
/// rather than being written inline anywhere.
class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);

  @override
  bool operator ==(Object other) =>
      other is LatLng &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'LatLng($latitude, $longitude)';
}

/// An axis-aligned bounding box. Used for the fixed Penang boundary
/// (UC-009) — both to reject out-of-state destinations and to constrain
/// map panning.
class LatLngBounds {
  final LatLng southwest;
  final LatLng northeast;

  const LatLngBounds({required this.southwest, required this.northeast});

  @override
  bool operator ==(Object other) =>
      other is LatLngBounds &&
      other.southwest == southwest &&
      other.northeast == northeast;

  @override
  int get hashCode => Object.hash(southwest, northeast);

  @override
  String toString() => 'LatLngBounds($southwest, $northeast)';
}
