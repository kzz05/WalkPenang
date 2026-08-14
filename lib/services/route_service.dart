import '../models/lat_lng.dart';
import '../models/route_result.dart';
import 'map_service.dart';

/// Route Calculation Sub Module (UC-M04).
class RouteService {
  RouteService(this._mapService);
  final MapService _mapService;

  /// UC-M04 steps 2-4 / A1-A2: calls the Directions API in walking mode and
  /// extracts distance/duration from the response.
  Future<RouteResult> calculateWalkingRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final uri = _mapService.buildDirectionsRequest(
      origin: origin,
      destination: destination,
    );
    final json = await _mapService.sendAPIRequest(uri);
    return extractDistanceAndDuration(json);
  }

  /// UC-M04 A1: `ZERO_RESULTS` (no walkable path) and an empty `routes`
  /// list both mean "no route" — [RouteResult.notFound] lets the caller
  /// show one consistent message either way.
  RouteResult extractDistanceAndDuration(Map<String, dynamic> directionsJson) {
    final routes = directionsJson['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) return handleNoRouteFound();

    final route = routes.first as Map<String, dynamic>;
    final legs = route['legs'] as List<dynamic>?;
    if (legs == null || legs.isEmpty) return handleNoRouteFound();

    final leg = legs.first as Map<String, dynamic>;
    final distanceMeters = (leg['distance']?['value'] as num?)?.toDouble() ?? 0;
    final durationSeconds = (leg['duration']?['value'] as num?)?.toInt() ?? 0;
    final polyline =
        _decodePolyline(route['overview_polyline']?['points'] as String?);

    return RouteResult(
      distanceKm: distanceMeters / 1000,
      durationMinutes: (durationSeconds / 60).round(),
      polylinePoints: polyline,
    );
  }

  RouteResult handleNoRouteFound() => RouteResult.notFound();

  /// Standard Google encoded-polyline decoder (5 decimal-place precision),
  /// used to draw the walking route line on the map.
  List<LatLng> _decodePolyline(String? encoded) {
    if (encoded == null || encoded.isEmpty) return [];

    final points = <LatLng>[];
    var index = 0, lat = 0, lng = 0;

    while (index < encoded.length) {
      var shift = 0, result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}
