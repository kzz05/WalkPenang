// Automatic off-route rerouting for in-app navigation (UC-M05).
//
// Navigation could already recover when a fix *missed* a waypoint but the
// tourist was still travelling a later leg of the original route. What it
// could not do was notice that the tourist had taken a genuinely wrong road:
// NavigationService deliberately holds the instruction in that case, and the
// controller then followed the original RouteResult for the rest of the
// journey, pointing down a street the tourist had long since left.
//
// These tests drive the controller through a scripted GPS track and a fake
// RouteService, so nothing here reaches a platform channel or the Directions
// API.
//
// Route geometry matches the other navigation tests — a right-angled walk
// east, then north, then east again:
//
//        C ────────────── D      step 2, east
//        │
//        │ step 1, north
//        │
//   A ── B                       step 0, east
//
// ~111 m per 0.001° of latitude, ~110.8 m per 0.001° of longitude here.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:walkpenang/constants/map_constants.dart';
import 'package:walkpenang/constants/map_error_messages.dart';
import 'package:walkpenang/controllers/navigation_controller.dart';
import 'package:walkpenang/models/gps_location.dart';
import 'package:walkpenang/models/place_model.dart';
import 'package:walkpenang/models/route_result.dart';
import 'package:walkpenang/models/route_step.dart';
import 'package:walkpenang/models/transport_mode.dart';
import 'package:walkpenang/services/compass_service.dart';
import 'package:walkpenang/services/location_service.dart';
import 'package:walkpenang/services/map_service.dart';
import 'package:walkpenang/services/route_service.dart';

const _a = LatLng(5.4141, 100.3288);
const _b = LatLng(5.4141, 100.3298);
const _c = LatLng(5.4151, 100.3298);
const _d = LatLng(5.4151, 100.3308);

/// On the first leg, half way along it.
const _onRoute = LatLng(5.4141, 100.3293);

/// ~2 m off the first leg — the everyday wobble of a fix between shophouses.
const _noisyButOnRoute = LatLng(5.414118, 100.3293);

/// ~111 m south of the first leg and further still from the other two: the
/// tourist turned down the wrong street.
const _offRoute1 = LatLng(5.41310, 100.32930);
const _offRoute2 = LatLng(5.41305, 100.32960);
const _offRoute3 = LatLng(5.41300, 100.32990);
const _offRoute4 = LatLng(5.41295, 100.33020);

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
    await _settle();
  }
}

class _NoCompassService extends CompassService {
  @override
  bool get isCompassAvailable => false;
}

/// One Directions call the controller made while rerouting.
class _RerouteCall {
  _RerouteCall({
    required this.origin,
    required this.destination,
    required this.mode,
  });

  final LatLng origin;
  final LatLng destination;
  final TransportMode mode;
}

class _FakeRouteService extends RouteService {
  _FakeRouteService() : super(MapService());

  final List<_RerouteCall> calls = [];

  /// What the next call resolves to. Null means it throws instead, standing in
  /// for a lost connection mid-route.
  RouteResult? result = _replacementRoute();
  bool shouldThrow = false;

  /// While true, a call hands back a future the test completes by hand — the
  /// only way to hold a reroute "in flight" across several GPS fixes.
  bool holdInFlight = false;
  Completer<RouteResult>? inFlight;

  @override
  Future<RouteResult> calculateRoute({
    required LatLng origin,
    required LatLng destination,
    required TransportMode mode,
  }) {
    calls.add(
      _RerouteCall(origin: origin, destination: destination, mode: mode),
    );

    if (holdInFlight) {
      inFlight = Completer<RouteResult>();
      return inFlight!.future;
    }
    if (shouldThrow) {
      return Future<RouteResult>.error(MapServiceException('offline'));
    }
    return Future<RouteResult>.value(result ?? RouteResult.notFound());
  }
}

RouteStep _step(LatLng from, LatLng to, double metres, int seconds,
        {String instruction = 'Walk'}) =>
    RouteStep(
      instruction: instruction,
      maneuver: 'turn-left',
      distanceMeters: metres,
      durationSeconds: seconds,
      startLocation: from,
      endLocation: to,
      polylinePoints: [from, to],
    );

RouteResult _originalRoute() => RouteResult(
      distanceKm: 0.332,
      durationMinutes: 5,
      polylinePoints: const [_a, _b, _c, _d],
      steps: [
        _step(_a, _b, 110.8, 90, instruction: 'Head east on Lebuh Chulia'),
        _step(_b, _c, 111.3, 90, instruction: 'Turn left onto Lebuh Penang'),
        _step(_c, _d, 110.8, 90, instruction: 'Turn right onto Lebuh Light'),
      ],
    );

// The way back to the destination from the wrong street: east along it, then
// north, then west to the door. Four legs rather than three, and longer than
// what was left of the original, so every figure the screen reads is
// distinguishable from the route it replaced.
const _detour1 = LatLng(5.41300, 100.33150);
const _detour2 = LatLng(5.41300, 100.33300);
const _detour3 = LatLng(5.41510, 100.33300);

RouteResult _replacementRoute() => RouteResult(
      distanceKm: 0.85,
      durationMinutes: 12,
      polylinePoints: const [_offRoute3, _detour1, _detour2, _detour3, _d],
      steps: [
        _step(_offRoute3, _detour1, 177, 150,
            instruction: 'Head east on Lebuh Pantai'),
        _step(_detour1, _detour2, 166, 150, instruction: 'Continue east'),
        _step(_detour2, _detour3, 234, 200,
            instruction: 'Turn left onto Lebuh Gereja'),
        _step(_detour3, _d, 244, 220,
            instruction: 'Turn left onto Lebuh Light'),
      ],
    );

final _destination = PlaceModel(
  placeId: 'test-lebuh-light',
  name: 'Lebuh Light',
  category: 'attraction',
  latitude: _d.latitude,
  longitude: _d.longitude,
);

/// Lets the controller's stream subscription — and any reroute future it
/// started from it — run to completion before the next assertion.
Future<void> _settle() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _ScriptedLocationService location;
  late _FakeRouteService routes;
  late NavigationController controller;

  NavigationController build({TransportMode mode = TransportMode.walking}) {
    return NavigationController(
      route: _originalRoute(),
      destination: _destination,
      mode: mode,
      initialPosition: _a,
      locationService: location,
      compassService: _NoCompassService(),
      routeService: routes,
    );
  }

  /// Walks the tourist off route for exactly enough fixes to trip the
  /// threshold.
  Future<void> goOffRoute() async {
    const track = [_offRoute1, _offRoute2, _offRoute3, _offRoute4];
    for (var i = 0;
        i < MapConstants.navigationOffRouteFixesBeforeReroute;
        i++) {
      await location.emit(track[i % track.length]);
    }
    await _settle();
  }

  setUp(() {
    location = _ScriptedLocationService();
    routes = _FakeRouteService();
    controller = build();
  });

  tearDown(() => controller.dispose());

  group('when no reroute is warranted', () {
    test('staying on the route never asks for a new one', () async {
      await location.emit(_onRoute);
      await location.emit(const LatLng(5.4141, 100.32960));
      await location.emit(const LatLng(5.41412, 100.32979));
      await location.emit(const LatLng(5.41425, 100.32982));
      await _settle();

      expect(routes.calls, isEmpty);
      expect(controller.isRerouting, isFalse);
      expect(controller.rerouteErrorMessage, isNull);
    });

    test('one off-route GPS spike does not reroute', () async {
      await location.emit(_onRoute);
      // A single reading thrown a street away, then straight back.
      await location.emit(_offRoute1);
      await location.emit(const LatLng(5.4141, 100.32960));
      await _settle();

      expect(routes.calls, isEmpty);
    });

    test('noisy fixes beside the route do not reroute', () async {
      for (var i = 0; i < 8; i++) {
        await location.emit(_noisyButOnRoute);
      }
      await _settle();

      expect(routes.calls, isEmpty);
    });

    test('rejoining the route clears the pending off-route count', () async {
      // Two off-route fixes — one short of the threshold.
      await location.emit(_offRoute1);
      await location.emit(_offRoute2);
      expect(routes.calls, isEmpty);

      // Back on the route: the tally resets rather than decaying.
      await location.emit(_onRoute);

      // Two more off-route fixes therefore still fall short.
      await location.emit(_offRoute1);
      await location.emit(_offRoute2);
      await _settle();

      expect(routes.calls, isEmpty,
          reason: 'the count restarted when the tourist rejoined the route');

      // And the very next one — the third in this run — does trip it.
      await location.emit(_offRoute3);
      await _settle();
      expect(routes.calls, hasLength(1));
    });

    test('a fix drifting off the last leg after arrival does not reroute',
        () async {
      await location.emit(_d);
      expect(controller.hasArrived, isTrue);

      await goOffRoute();

      expect(routes.calls, isEmpty);
    });
  });

  group('triggering a reroute', () {
    test('repeated off-route fixes trigger exactly one reroute', () async {
      await goOffRoute();

      expect(routes.calls, hasLength(1));

      // Staying off route afterwards does not fire a second call — the
      // successful reroute reset the tally, and the tourist is now on the
      // replacement route anyway.
      await location.emit(_offRoute4);
      await location.emit(_offRoute4);
      await _settle();

      expect(routes.calls, hasLength(1));
    });

    test('the reroute starts from the latest GPS position', () async {
      await location.emit(_offRoute1);
      await location.emit(_offRoute2);
      await location.emit(_offRoute3);
      await _settle();

      expect(routes.calls, hasLength(1));
      expect(routes.calls.single.origin.latitude,
          closeTo(_offRoute3.latitude, 1e-9));
      expect(routes.calls.single.origin.longitude,
          closeTo(_offRoute3.longitude, 1e-9));
    });

    test('the destination is never changed by a reroute', () async {
      await goOffRoute();

      expect(routes.calls.single.destination.latitude,
          closeTo(_destination.latitude, 1e-9));
      expect(routes.calls.single.destination.longitude,
          closeTo(_destination.longitude, 1e-9));
    });

    test('a walking reroute is requested as walking', () async {
      await goOffRoute();

      expect(routes.calls.single.mode, TransportMode.walking);
    });

    test('a driving reroute is requested as driving', () async {
      controller.dispose();
      controller = build(mode: TransportMode.driving);

      await goOffRoute();

      expect(routes.calls.single.mode, TransportMode.driving);
    });
  });

  group('applying a successful reroute', () {
    test('the active route, steps, polyline, distance and ETA all follow',
        () async {
      final originalDistance = controller.remainingDistanceMeters;
      final originalDuration = controller.remainingDurationSeconds;
      expect(controller.route.steps, hasLength(3));

      await goOffRoute();

      expect(controller.route.distanceKm, 0.85);
      expect(controller.route.steps, hasLength(4));
      expect(controller.route.polylinePoints,
          const [_offRoute3, _detour1, _detour2, _detour3, _d]);
      expect(controller.currentStep?.instruction, 'Head east on Lebuh Pantai');
      expect(controller.nextStep?.instruction, 'Continue east');

      // The replacement route is longer than what was left of the original,
      // because the tourist has walked away from the destination.
      expect(controller.remainingDistanceMeters, greaterThan(originalDistance));
      expect(
        controller.remainingDurationSeconds,
        greaterThan(originalDuration),
      );
      expect(
        controller.estimatedArrivalTime.isAfter(DateTime.now()),
        isTrue,
      );
    });

    test('the step index and progress baseline are reset', () async {
      // Walk most of the original route first, so there is progress to lose.
      await location.emit(const LatLng(5.41425, 100.32982));
      expect(controller.currentStepIndex, 1);
      expect(controller.routeProgress, greaterThan(0));

      await goOffRoute();

      expect(controller.currentStepIndex, 0);
      expect(controller.travelledPolyline, isEmpty);
      // Measured against the new route's own length, not the old one's, so the
      // bar starts near empty again instead of claiming the journey is nearly
      // done.
      expect(controller.routeProgress, lessThan(0.2));
    });

    test('listeners are notified and the rerouting flag clears', () async {
      var notifications = 0;
      controller.addListener(() => notifications++);

      await goOffRoute();

      expect(notifications, greaterThan(0));
      expect(controller.isRerouting, isFalse);
      expect(controller.rerouteErrorMessage, isNull);
    });

    test('arrival is still detected on the replacement route', () async {
      await goOffRoute();
      expect(controller.route.steps, hasLength(4));

      await location.emit(_d);

      expect(controller.hasArrived, isTrue);
      expect(controller.justArrived, isTrue);
    });
  });

  group('when a reroute fails', () {
    test('the original route is kept and the session stays alive', () async {
      routes.shouldThrow = true;

      await goOffRoute();

      expect(routes.calls, hasLength(1));
      expect(controller.route.steps, hasLength(3));
      expect(controller.route.distanceKm, 0.332);
      expect(controller.currentStep?.instruction, 'Head east on Lebuh Chulia');
      expect(controller.isRerouting, isFalse);
      expect(controller.rerouteErrorMessage, MapErrorMessages.rerouteFailed);
    });

    test('an empty result is treated as a failure, not applied', () async {
      routes.result = RouteResult.notFound();

      await goOffRoute();

      expect(controller.route.steps, hasLength(3));
      expect(controller.rerouteErrorMessage, MapErrorMessages.rerouteFailed);
    });

    test('a failure does not retry on every following fix', () async {
      routes.shouldThrow = true;
      await goOffRoute();
      expect(routes.calls, hasLength(1));

      // Still off route, still failing: the tally has to build up again from
      // scratch rather than firing a Directions call once a second.
      await location.emit(_offRoute4);
      await location.emit(_offRoute1);
      await _settle();
      expect(routes.calls, hasLength(1));

      await location.emit(_offRoute2);
      await _settle();
      expect(routes.calls, hasLength(2));
    });

    test('retry asks again and clears the notice on success', () async {
      routes.shouldThrow = true;
      await goOffRoute();
      expect(controller.rerouteErrorMessage, isNotNull);

      routes.shouldThrow = false;
      controller.retryReroute();
      await _settle();

      expect(routes.calls, hasLength(2));
      expect(controller.rerouteErrorMessage, isNull);
      expect(controller.route.steps, hasLength(4));
    });

    test('the notice can be dismissed without retrying', () async {
      routes.shouldThrow = true;
      await goOffRoute();

      controller.dismissRerouteError();

      expect(controller.rerouteErrorMessage, isNull);
      expect(routes.calls, hasLength(1));
    });
  });

  group('reroute loop prevention', () {
    test('no second reroute starts while one is already in flight', () async {
      routes.holdInFlight = true;

      await goOffRoute();
      expect(routes.calls, hasLength(1));
      expect(controller.isRerouting, isTrue);

      // Several more fixes, all well off route, while the first call hangs.
      for (var i = 0; i < 6; i++) {
        await location.emit(_offRoute4);
      }
      await _settle();

      expect(routes.calls, hasLength(1),
          reason: 'one in-flight request at a time');
      expect(controller.isRerouting, isTrue);

      // Completing it applies the route and releases the guard.
      routes.inFlight!.complete(_replacementRoute());
      await _settle();

      expect(controller.isRerouting, isFalse);
      expect(controller.route.steps, hasLength(4));
    });

    test('retry is ignored while a reroute is in flight', () async {
      routes.holdInFlight = true;
      await goOffRoute();

      controller.retryReroute();
      await _settle();

      expect(routes.calls, hasLength(1));

      routes.inFlight!.complete(_replacementRoute());
      await _settle();
    });

    test('a reroute returning after disposal touches nothing', () async {
      routes.holdInFlight = true;
      await goOffRoute();

      controller.dispose();
      routes.inFlight!.complete(_replacementRoute());
      await _settle();

      // Still the route it was disposed with — and, more to the point, no
      // "notifyListeners() called after dispose" thrown by the completion.
      expect(controller.route.steps, hasLength(3));

      // tearDown disposes again; ChangeNotifier tolerates that, but rebuild a
      // live controller so the shared teardown has something valid to close.
      controller = build();
    });
  });
}
