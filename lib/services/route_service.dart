import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../constants/travel_mode.dart';
import '../models/route_result.dart';
import '../models/route_step.dart';
import '../models/transit_details.dart';
import 'map_service.dart';

/// Route Calculation Sub Module (UC-M04).
class RouteService {
  RouteService(this._mapService);
  final MapService _mapService;

  /// UC-M04 steps 2-4 / A1-A2: calls the Directions API for the given
  /// [mode] and extracts distance/duration from the response, so the
  /// tourist can compare walking, driving, and transit ETAs.
  Future<RouteResult> calculateRoute({
    required LatLng origin,
    required LatLng destination,
    required TravelMode mode,
  }) async {
    final uri = _mapService.buildDirectionsRequest(
      origin: origin,
      destination: destination,
      mode: mode.apiValue,
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
  /// Directions API leg step. A transit route's steps mix `WALKING` (to/from
  /// stops) and `TRANSIT` (the bus/train ride itself, carrying
  /// [TransitDetails]).
  List<RouteStep> _extractSteps(List<dynamic>? steps) {
    if (steps == null) return [];

    return steps.map((raw) {
      final step = raw as Map<String, dynamic>;
      final startLocation = step['start_location'] as Map<String, dynamic>?;
      final endLocation = step['end_location'] as Map<String, dynamic>?;
      final travelMode = step['travel_mode'] as String? ?? 'WALKING';

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
        travelMode: travelMode,
        transitDetails: travelMode == 'TRANSIT'
            ? _extractTransitDetails(
                step['transit_details'] as Map<String, dynamic>?,
              )
            : null,
      );
    }).toList();
  }

  /// UC-M05 transit navigation: the line/stop/schedule info shown for a
  /// `TRANSIT` step, parsed from the Directions API's `transit_details`.
  TransitDetails? _extractTransitDetails(Map<String, dynamic>? raw) {
    if (raw == null) return null;

    final line = raw['line'] as Map<String, dynamic>? ?? const {};
    final vehicle = line['vehicle'] as Map<String, dynamic>? ?? const {};
    final departureStop =
        raw['departure_stop'] as Map<String, dynamic>? ?? const {};
    final arrivalStop =
        raw['arrival_stop'] as Map<String, dynamic>? ?? const {};
    final departureTime = raw['departure_time'] as Map<String, dynamic>?;
    final arrivalTime = raw['arrival_time'] as Map<String, dynamic>?;

    return TransitDetails(
      lineName:
          line['short_name'] as String? ?? line['name'] as String? ?? 'Transit',
      vehicleType: vehicle['type'] as String? ?? 'BUS',
      headsign: raw['headsign'] as String? ?? '',
      departureStopName: departureStop['name'] as String? ?? '',
      arrivalStopName: arrivalStop['name'] as String? ?? '',
      numStops: (raw['num_stops'] as num?)?.toInt() ?? 0,
      // Directions API returns a ready-to-display local time string (e.g.
      // "6:24 PM") — using it directly avoids re-deriving one from the
      // accompanying Unix timestamp + time zone.
      departureTimeText: departureTime?['text'] as String? ?? '',
      arrivalTimeText: arrivalTime?['text'] as String? ?? '',
    );
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
