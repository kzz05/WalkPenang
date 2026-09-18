// What the navigation screen's figures do as the tourist actually walks
// (UC-M05).
//
// The controller is driven through injected fakes: a LocationService subclass
// that replays a scripted GPS track and a CompassService subclass that reports
// no magnetometer, so nothing here reaches a platform channel.
//
// Route geometry matches test/services/navigation_service_test.dart — a
// right-angled walk east, then north, then east again.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:walkpenang/controllers/navigation_controller.dart';
import 'package:walkpenang/models/gps_location.dart';
import 'package:walkpenang/models/place_model.dart';
import 'package:walkpenang/models/route_result.dart';
import 'package:walkpenang/models/route_step.dart';
import 'package:walkpenang/models/transport_mode.dart';
import 'package:walkpenang/services/compass_service.dart';
import 'package:walkpenang/services/location_service.dart';

const _a = LatLng(5.4141, 100.3288);
const _b = LatLng(5.4141, 100.3298);
const _c = LatLng(5.4151, 100.3298);
const _d = LatLng(5.4151, 100.3308);

class _ScriptedLocationService extends LocationService {
  final _controller = StreamController<GpsLocation>.broadcast();

  @override
  Stream<GpsLocation> startNavigationUpdates() => _controller.stream;

  Future<void> emit(LatLng position) async {
    _controller.add(
      GpsLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: 8,
        timestamp: DateTime(2026, 9, 18),
      ),
    );
    // Let the controller's subscription run before the next assertion.
    await Future<void>.delayed(Duration.zero);
  }
}

class _NoCompassService extends CompassService {
  @override
  bool get isCompassAvailable => false;
}

RouteStep _step(LatLng from, LatLng to, double metres, int seconds) => RouteStep(
      instruction: 'Walk',
      maneuver: 'turn-left',
      distanceMeters: metres,
      durationSeconds: seconds,
      startLocation: from,
      endLocation: to,
      polylinePoints: [from, to],
    );

RouteResult _route() => RouteResult(
      distanceKm: 0.332,
      durationMinutes: 5,
      polylinePoints: const [_a, _b, _c, _d],
      steps: [
        _step(_a, _b, 110.8, 90),
        _step(_b, _c, 111.3, 90),
        _step(_c, _d, 110.8, 90),
      ],
    );

final _destination = PlaceModel(
  placeId: 'test-lebuh-light',
  name: 'Lebuh Light',
  category: 'attraction',
  latitude: _d.latitude,
  longitude: _d.longitude,
);

void main() {
  late _ScriptedLocationService location;
  late NavigationController controller;

  setUp(() {
    location = _ScriptedLocationService();
    controller = NavigationController(
      route: _route(),
      destination: _destination,
      mode: TransportMode.walking,
      initialPosition: _a,
      locationService: location,
      compassService: _NoCompassService(),
    );
  });

  tearDown(() => controller.dispose());

  // Regression: navigation used to stick on the step whose waypoint was
  // missed, and every figure below it then described a route the tourist had
  // already walked — 19 min and 1.5 km left on a screen whose sibling was
  // reading 11 min.
  test('a track that misses every waypoint still advances and counts down',
      () async {
    final startDistance = controller.remainingDistanceMeters;
    final startDuration = controller.remainingDurationSeconds;

    // Fixes at ~35 m spacing along the route, none of which lands inside the
    // 15 m arrival radius of B or C.
    await location.emit(const LatLng(5.41410, 100.32912));
    expect(controller.currentStepIndex, 0, reason: 'still on the first leg');

    // Past the corner at B and 17 m up the next street.
    await location.emit(const LatLng(5.41425, 100.32982));
    expect(controller.currentStepIndex, 1);

    final midDistance = controller.remainingDistanceMeters;
    expect(midDistance, lessThan(startDistance));
    expect(controller.remainingDurationSeconds, lessThan(startDuration));

    // Past the corner at C and well along the last leg.
    await location.emit(const LatLng(5.41512, 100.33020));
    expect(controller.currentStepIndex, 2);
    expect(controller.remainingDistanceMeters, lessThan(midDistance));
    expect(controller.routeProgress, greaterThan(0.5));
  });

  test('a fix short of the first manoeuvre leaves the whole route ahead',
      () async {
    await location.emit(const LatLng(5.41410, 100.32900));

    expect(controller.currentStepIndex, 0);
    expect(controller.travelledPolyline, isEmpty);
    // Two untouched legs plus the tail of this one.
    expect(controller.remainingDistanceMeters, greaterThan(222));
  });

  test('arrival is still detected from the live stream', () async {
    await location.emit(_d);

    expect(controller.hasArrived, isTrue);
    expect(controller.justArrived, isTrue);
  });
}
