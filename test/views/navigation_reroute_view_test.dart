// What the navigation screen shows while it is rerouting (UC-M05).
//
// Rerouting is deliberately not a screen of its own. The tourist is still
// walking, and the directions already on screen — stale as they are — are the
// only thing telling them where the destination lies until the new ones land.
// So the assertions here are as much about what *stays* visible as about what
// appears.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
import 'package:walkpenang/views/navigation_view.dart';

const _a = LatLng(5.4141, 100.3288);
const _b = LatLng(5.4141, 100.3298);
const _c = LatLng(5.4151, 100.3298);

/// A street away from every remaining leg — a genuine wrong turn.
const _offRoute = LatLng(5.41300, 100.32990);

class _ScriptedLocationService extends LocationService {
  final _controller = StreamController<GpsLocation>.broadcast();

  @override
  Stream<GpsLocation> startNavigationUpdates() => _controller.stream;

  void emit(LatLng position) {
    _controller.add(
      GpsLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: 8,
        timestamp: DateTime(2026, 9, 18),
      ),
    );
  }
}

class _NoCompassService extends CompassService {
  @override
  bool get isCompassAvailable => false;
}

class _FakeRouteService extends RouteService {
  _FakeRouteService() : super(MapService());

  int calls = 0;
  bool holdInFlight = true;
  Completer<RouteResult>? inFlight;

  @override
  Future<RouteResult> calculateRoute({
    required LatLng origin,
    required LatLng destination,
    required TransportMode mode,
  }) {
    calls++;
    if (holdInFlight) {
      inFlight = Completer<RouteResult>();
      return inFlight!.future;
    }
    return Future<RouteResult>.error(MapServiceException('offline'));
  }
}

RouteResult _route() => RouteResult(
      distanceKm: 0.222,
      durationMinutes: 4,
      polylinePoints: const [_a, _b, _c],
      steps: [
        RouteStep(
          instruction: 'Head east on Lebuh Chulia',
          maneuver: 'straight',
          distanceMeters: 110.8,
          durationSeconds: 90,
          startLocation: _a,
          endLocation: _b,
          polylinePoints: const [_a, _b],
        ),
        RouteStep(
          instruction: 'Turn left onto Lebuh Penang',
          maneuver: 'turn-left',
          distanceMeters: 111.3,
          durationSeconds: 90,
          startLocation: _b,
          endLocation: _c,
          polylinePoints: const [_b, _c],
        ),
      ],
    );

final _destination = PlaceModel(
  placeId: 'test-lebuh-penang',
  name: 'Lebuh Penang',
  category: 'attraction',
  latitude: _c.latitude,
  longitude: _c.longitude,
);

void main() {
  late _ScriptedLocationService location;
  late _FakeRouteService routes;
  late NavigationController controller;

  /// Everything is built inside the test body rather than in `setUp`, and
  /// deliberately so. `testWidgets` runs its body in a fake-async zone, and
  /// only futures created *inside* that zone are advanced by `tester.pump()`.
  /// A controller built in `setUp` keeps its stream subscription — and the
  /// reroute request it starts from one — on the real event loop, where a
  /// pending Directions call never resolves however many frames are pumped.
  Future<void> pumpNavigation(
    WidgetTester tester, {
    double textScale = 1.0,
    bool failReroute = false,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    location = _ScriptedLocationService();
    routes = _FakeRouteService()..holdInFlight = !failReroute;
    controller = NavigationController(
      route: _route(),
      destination: _destination,
      mode: TransportMode.walking,
      initialPosition: _a,
      locationService: location,
      compassService: _NoCompassService(),
      routeService: routes,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: MaterialApp(
          home: NavigationView(
            route: _route(),
            destination: _destination,
            origin: _a,
            mode: TransportMode.walking,
            controller: controller,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Drives the tourist off route until the controller asks for a new route.
  Future<void> goOffRoute(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      location.emit(_offRoute);
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pump();
  }

  testWidgets('nothing about rerouting shows while the tourist is on route',
      (tester) async {
    await pumpNavigation(tester);

    expect(find.text(MapErrorMessages.rerouting), findsNothing);
    expect(find.text(MapErrorMessages.rerouteFailed), findsNothing);
  });

  testWidgets('a reroute in flight shows a strip, not a new screen',
      (tester) async {
    await pumpNavigation(tester);
    await goOffRoute(tester);

    expect(routes.calls, 1);
    expect(find.text(MapErrorMessages.rerouting), findsOneWidget);
    // The map, the instruction the tourist is still following and the
    // remaining-distance figures all stay on screen behind it.
    expect(find.byType(GoogleMap), findsOneWidget);
    expect(find.text('Head east on Lebuh Chulia'), findsOneWidget);
    expect(find.text('distance'), findsOneWidget);
  });

  testWidgets('the strip clears once the new route is applied', (tester) async {
    await pumpNavigation(tester);
    await goOffRoute(tester);

    routes.inFlight!.complete(
      RouteResult(
        distanceKm: 0.4,
        durationMinutes: 6,
        polylinePoints: const [_offRoute, _c],
        steps: [
          RouteStep(
            instruction: 'Head north-east on Lebuh Pantai',
            maneuver: 'turn-right',
            distanceMeters: 400,
            durationSeconds: 360,
            startLocation: _offRoute,
            endLocation: _c,
            polylinePoints: const [_offRoute, _c],
          ),
        ],
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(find.text(MapErrorMessages.rerouting), findsNothing);
    // The banner now reads off the replacement route.
    expect(find.text('Head north-east on Lebuh Pantai'), findsOneWidget);
    expect(find.text('Head east on Lebuh Chulia'), findsNothing);
  });

  testWidgets('a failed reroute offers a retry without ending the session',
      (tester) async {
    await pumpNavigation(tester, failReroute: true);
    await goOffRoute(tester);

    expect(find.text(MapErrorMessages.rerouteFailed), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    // Still navigating on the route it already had.
    expect(find.text('Head east on Lebuh Chulia'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(routes.calls, 2);
  });

  testWidgets('the failure notice can be dismissed', (tester) async {
    await pumpNavigation(tester, failReroute: true);
    await goOffRoute(tester);

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pump();

    expect(find.text(MapErrorMessages.rerouteFailed), findsNothing);
  });

  // The banners land on the most crowded part of the screen, between the
  // instruction and the remaining-distance bar, so they are swept at the text
  // scales the rest of the navigation layout is checked at.
  for (final scale in <double>[1.0, 1.3, 1.6, 2.0]) {
    testWidgets('the rerouting strip does not overflow @${scale}x',
        (tester) async {
      await pumpNavigation(tester, textScale: scale);
      await goOffRoute(tester);

      expect(find.text(MapErrorMessages.rerouting), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the reroute-failed strip does not overflow @${scale}x',
        (tester) async {
      await pumpNavigation(tester, textScale: scale, failReroute: true);
      await goOffRoute(tester);

      expect(find.text(MapErrorMessages.rerouteFailed), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
