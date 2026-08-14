// T-M03.3 — boundary validation with coordinates inside and outside Penang
//
// UC-M03 / FR-M05. Pure arithmetic against a fixed bounding box, so this runs
// without a Flutter binding, a map SDK or a network call.
import 'package:test/test.dart';

import 'package:walkpenang/constants/map_constants.dart';
import 'package:walkpenang/models/gps_location.dart';
import 'package:walkpenang/models/lat_lng.dart';
import 'package:walkpenang/services/boundary_validator_service.dart';

GpsLocation at(double lat, double lng) => GpsLocation(
      latitude: lat,
      longitude: lng,
      accuracyMeters: 5,
      timestamp: DateTime(2026, 8, 15),
    );

void main() {
  final validator = BoundaryValidatorService();

  group('inside Penang', () {
    // Real places, so a wrong bounding box shows up as a recognisable
    // location being rejected rather than an abstract coordinate.
    const places = <String, LatLng>{
      'George Town': LatLng(5.4141, 100.3288),
      'Penang Hill': LatLng(5.4239, 100.2760),
      'Kek Lok Si': LatLng(5.3993, 100.2734),
      'Batu Ferringhi': LatLng(5.4720, 100.2450),
      'Penang Airport': LatLng(5.2971, 100.2769),
      'Butterworth (mainland Penang)': LatLng(5.3991, 100.3638),
    };

    places.forEach((name, point) {
      test('$name is accepted', () {
        expect(validator.validateDestination(point), isTrue,
            reason: '$name is in Penang and must not be rejected');
        expect(validator.validateUserLocation(at(point.latitude, point.longitude)),
            isTrue);
      });
    });
  });

  group('outside Penang', () {
    const elsewhere = <String, LatLng>{
      'Kuala Lumpur': LatLng(3.1390, 101.6869),
      'Langkawi': LatLng(6.3500, 99.8000),
      'Ipoh': LatLng(4.5975, 101.0901),
      'Hat Yai (Thailand)': LatLng(7.0086, 100.4747),
      'Null Island': LatLng(0, 0),
    };

    elsewhere.forEach((name, point) {
      test('$name is rejected', () {
        expect(validator.validateDestination(point), isFalse,
            reason: '$name is outside Penang and must not be accepted');
        expect(
            validator.validateUserLocation(at(point.latitude, point.longitude)),
            isFalse);
      });
    });
  });

  group('the boundary itself', () {
    const bounds = MapConstants.penangBounds;

    test('the corners are inside — the box is inclusive', () {
      expect(validator.validateDestination(bounds.southwest), isTrue);
      expect(validator.validateDestination(bounds.northeast), isTrue);
    });

    test('a hair outside each edge is rejected', () {
      const epsilon = 0.0001;
      final sw = bounds.southwest;
      final ne = bounds.northeast;

      expect(
          validator.validateDestination(
              LatLng(sw.latitude - epsilon, sw.longitude)),
          isFalse,
          reason: 'south of the box');
      expect(
          validator.validateDestination(
              LatLng(sw.latitude, sw.longitude - epsilon)),
          isFalse,
          reason: 'west of the box');
      expect(
          validator.validateDestination(
              LatLng(ne.latitude + epsilon, ne.longitude)),
          isFalse,
          reason: 'north of the box');
      expect(
          validator.validateDestination(
              LatLng(ne.latitude, ne.longitude + epsilon)),
          isFalse,
          reason: 'east of the box');
    });

    test('a point inside one axis but not the other is rejected', () {
      // Guards against an `||` creeping in where the check needs `&&`.
      expect(
        validator.validateDestination(
          LatLng(bounds.southwest.latitude, bounds.northeast.longitude + 1),
        ),
        isFalse,
      );
      expect(
        validator.validateDestination(
          LatLng(bounds.northeast.latitude + 1, bounds.southwest.longitude),
        ),
        isFalse,
      );
    });

    test('panningBounds is the same box the map camera is constrained to', () {
      expect(validator.panningBounds, same(MapConstants.penangBounds));
    });
  });
}
