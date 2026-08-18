import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/route_result.dart';
import '../models/route_step.dart';
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
      steps: _extractSteps(leg['steps'] as List<dynamic>?),
    );
  }

  RouteResult handleNoRouteFound() => RouteResult.notFound();

  /// UC-M05: turn-by-turn instructions for in-app navigation, one per
  /// Directions API leg step.
  List<RouteStep> _extractSteps(List<dynamic>? steps) {
    if (steps == null) return [];

    return steps.map((raw) {
      final step = raw as Map<String, dynamic>;
      final startLocation = step['start_location'] as Map<String, dynamic>?;
      final endLocation = step['end_location'] as Map<String, dynamic>?;

      return RouteStep(
        instruction: _stripHtml(step['html_instructions'] as String? ?? ''),
        maneuver: step['maneuver'] as String? ?? '',
        distanceMeters: (step['distance']?['value'] as num?)?.toDouble() ?? 0,
        durationSeconds: (step['duration']?['value'] as num?)?.toInt() ?? 0,
        startLocation: LatLng(
          (startLocation?['lat'] as num?)?.toDouble() ?? 0,
          (startLocation?['lng'] as num?)?.toDouble() ?? 0,
        ),
        endLocation: LatLng(
          (endLocation?['lat'] as num?)?.toDouble() ?? 0,
          (endLocation?['lng'] as num?)?.toDouble() ?? 0,
        ),
        polylinePoints:
            _decodePolyline(step['polyline']?['points'] as String?),
      );
    }).toList();
  }

  /// Directions API instructions come as HTML fragments (e.g.
  /// `<b>Turn left</b> onto <b>Lebuh Chulia</b>`) — strips the markup down
  /// to plain text for display in the navigation banner.
  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .trim();
  }

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
