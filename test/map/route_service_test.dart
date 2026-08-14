// T-M04.3 — route calculation accuracy across multiple destinations
//
// UC-M04 / FR-M03. Exercises the pure half of RouteService: turning a
// Directions API response into a RouteResult. The HTTP call itself is
// MapService's job and needs an API key, so it is not touched here — every
// case below is a recorded response shape.
import 'package:flutter_test/flutter_test.dart';

import 'package:walkpenang/services/map_service.dart';
import 'package:walkpenang/services/route_service.dart';

/// One Directions response with a single leg.
Map<String, dynamic> directions({
  required int distanceMetres,
  required int durationSeconds,
  String polyline = '',
}) =>
    <String, dynamic>{
      'status': 'OK',
      'routes': <dynamic>[
        <String, dynamic>{
          'overview_polyline': <String, dynamic>{'points': polyline},
          'legs': <dynamic>[
            <String, dynamic>{
              'distance': <String, dynamic>{'value': distanceMetres},
              'duration': <String, dynamic>{'value': durationSeconds},
            },
          ],
        },
      ],
    };

void main() {
  final service = RouteService(MapService());

  group('distance and duration', () {
    test('metres become kilometres and seconds become whole minutes', () {
      final result = service.extractDistanceAndDuration(
        directions(distanceMetres: 1300, durationSeconds: 960),
      );

      expect(result.routeFound, isTrue);
      expect(result.distanceKm, closeTo(1.3, 1e-9));
      expect(result.durationMinutes, 16);
    });

    test('duration rounds to the nearest minute rather than truncating', () {
      // 9 min 50 s is 10 minutes to a walker, not 9.
      final result = service.extractDistanceAndDuration(
        directions(distanceMetres: 800, durationSeconds: 590),
      );
      expect(result.durationMinutes, 10);
    });

    test('a range of real walking distances converts correctly', () {
      const cases = <int, double>{
        250: 0.25, // across a couple of shophouses
        1000: 1.0, // Fort Cornwallis from Komtar
        2400: 2.4, // edge of the 2 km radius
        11200: 11.2, // Tropical Spice Garden
      };

      cases.forEach((metres, km) {
        final result = service.extractDistanceAndDuration(
          directions(distanceMetres: metres, durationSeconds: 60),
        );
        expect(result.distanceKm, closeTo(km, 1e-9),
            reason: '$metres m should be $km km');
      });
    });
  });

  group('UC-M04 A1 — no walkable route', () {
    test('ZERO_RESULTS with an empty routes list is not-found', () {
      final result = service.extractDistanceAndDuration(
        <String, dynamic>{'status': 'ZERO_RESULTS', 'routes': <dynamic>[]},
      );

      expect(result.routeFound, isFalse);
      expect(result.distanceKm, 0);
      expect(result.durationMinutes, 0);
      expect(result.polylinePoints, isEmpty);
    });

    test('a missing routes key is not-found rather than a crash', () {
      final result =
          service.extractDistanceAndDuration(<String, dynamic>{'status': 'OK'});
      expect(result.routeFound, isFalse);
    });

    test('a route with no legs is not-found', () {
      // Seen when the API returns a route object it could not resolve into
      // steps; reading legs.first here would throw.
      final result = service.extractDistanceAndDuration(<String, dynamic>{
        'routes': <dynamic>[
          <String, dynamic>{'legs': <dynamic>[]},
        ],
      });
      expect(result.routeFound, isFalse);
    });

    test('a leg missing distance or duration degrades to zero, not a throw',
        () {
      final result = service.extractDistanceAndDuration(<String, dynamic>{
        'routes': <dynamic>[
          <String, dynamic>{
            'legs': <dynamic>[<String, dynamic>{}],
          },
        ],
      });

      expect(result.routeFound, isTrue);
      expect(result.distanceKm, 0);
      expect(result.durationMinutes, 0);
    });

    test('handleNoRouteFound is the same shape as a not-found parse', () {
      final explicit = service.handleNoRouteFound();
      expect(explicit.routeFound, isFalse);
      expect(explicit.polylinePoints, isEmpty);
    });
  });

  group('polyline decoding', () {
    test('decodes the reference encoded polyline from Google docs', () {
      // "_p~iF~ps|U_ulLnnqC_mqNvxq`@" is Google's own worked example:
      // (38.5, -120.2), (40.7, -120.95), (43.252, -126.453).
      final result = service.extractDistanceAndDuration(
        directions(
          distanceMetres: 100,
          durationSeconds: 60,
          polyline: '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
        ),
      );

      expect(result.polylinePoints, hasLength(3));
      expect(result.polylinePoints[0].latitude, closeTo(38.5, 1e-5));
      expect(result.polylinePoints[0].longitude, closeTo(-120.2, 1e-5));
      expect(result.polylinePoints[1].latitude, closeTo(40.7, 1e-5));
      expect(result.polylinePoints[2].latitude, closeTo(43.252, 1e-5));
      expect(result.polylinePoints[2].longitude, closeTo(-126.453, 1e-5));
    });

    test('an empty or missing polyline yields no points, not a crash', () {
      expect(
        service
            .extractDistanceAndDuration(
                directions(distanceMetres: 10, durationSeconds: 10))
            .polylinePoints,
        isEmpty,
      );

      final noPolylineKey =
          service.extractDistanceAndDuration(<String, dynamic>{
        'routes': <dynamic>[
          <String, dynamic>{
            'legs': <dynamic>[
              <String, dynamic>{
                'distance': <String, dynamic>{'value': 100},
                'duration': <String, dynamic>{'value': 100},
              },
            ],
          },
        ],
      });
      expect(noPolylineKey.polylinePoints, isEmpty);
      expect(noPolylineKey.routeFound, isTrue);
    });
  });
}
