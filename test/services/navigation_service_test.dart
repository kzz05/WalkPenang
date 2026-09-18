// Step advancement for in-app turn-by-turn navigation (UC-M05).
//
// NavigationService is pure geometry — Geolocator.distanceBetween is a plain
// Dart haversine in geolocator_platform_interface, so nothing here touches a
// platform channel and no binding is needed.
//
// The route below is a right-angled walk through George Town, deliberately
// laid out on round offsets so every expected figure can be read off it:
// ~111 m per 0.001° of latitude, ~110.8 m per 0.001° of longitude at this
// latitude.
//
//        C ────────────── D      step 2, east
//        │
//        │ step 1, north
//        │
//   A ── B                       step 0, east

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:walkpenang/models/route_step.dart';
import 'package:walkpenang/services/navigation_service.dart';

const _a = LatLng(5.4141, 100.3288);
const _b = LatLng(5.4141, 100.3298);
const _c = LatLng(5.4151, 100.3298);
const _d = LatLng(5.4151, 100.3308);

RouteStep _step(LatLng from, LatLng to, String instruction) => RouteStep(
      instruction: instruction,
      maneuver: 'turn-left',
      distanceMeters: 110,
      durationSeconds: 90,
      startLocation: from,
      endLocation: to,
      polylinePoints: [from, to],
    );

final _route = [
  _step(_a, _b, 'Head east on Lebuh Chulia'),
  _step(_b, _c, 'Turn left onto Lebuh Penang'),
  _step(_c, _d, 'Turn right onto Lebuh Light'),
];

void main() {
  final service = NavigationService();

  group('proximity advancement (unchanged behaviour)', () {
    test('a fix short of the manoeuvre point holds the step', () {
      // Half way along step 0, nowhere near its end.
      expect(
        service.advanceStepIndex(_route, 0, const LatLng(5.4141, 100.3293)),
        0,
      );
    });

    test('walking through the manoeuvre point advances one step', () {
      // ~11 m short of B — inside the 15 m arrival radius.
      expect(
        service.advanceStepIndex(_route, 0, const LatLng(5.4141, 100.32979)),
        1,
      );
    });

    test('closely spaced manoeuvre points are consumed together', () {
      // Two crossings a few metres apart, both inside the arrival radius of
      // the same fix.
      final crossing = [
        _step(_a, const LatLng(5.41410, 100.32880), 'Cross the road'),
        _step(const LatLng(5.41410, 100.32880), const LatLng(5.41412, 100.32882),
            'Cross again'),
        _step(const LatLng(5.41412, 100.32882), _b, 'Continue east'),
      ];

      expect(
        service.advanceStepIndex(crossing, 0, const LatLng(5.41411, 100.32881)),
        2,
      );
    });

    test('the final step is never advanced past', () {
      expect(service.advanceStepIndex(_route, 2, _d), 2);
    });

    test('an empty route leaves the index alone', () {
      expect(service.advanceStepIndex(const [], 0, _a), 0);
    });
  });

  // --- Missed waypoints (regression) ----------------------------------------
  //
  // Navigation used to sit on "step 1 of 5" for the rest of a journey whenever
  // no single fix landed inside the 15 m arrival radius of a waypoint — a
  // corner cut wide, a sparse mock route, a fix dropped between shophouses.
  // The banner kept showing a manoeuvre already made, and remaining distance
  // and ETA kept counting route the tourist had already walked, which is how
  // Active Walking came to read 11 min remaining while navigation still said
  // 19 min and 1.5 km.

  group('progress advancement after a missed waypoint', () {
    test('a fix past the corner and up the next street advances the step', () {
      // ~17 m north of B along step 1, and 2 m east of it: the tourist turned
      // the corner, but no fix ever came within 15 m of B itself.
      const pastTheCorner = LatLng(5.41425, 100.32982);

      expect(service.distanceToStepEnd(pastTheCorner, _route[0]),
          greaterThan(15));
      expect(service.advanceStepIndex(_route, 0, pastTheCorner), 1);
    });

    test('two missed waypoints in a row are both dropped', () {
      // Well along step 2, having missed the radius at both B and C.
      const alongTheLastStep = LatLng(5.41512, 100.33020);

      expect(service.advanceStepIndex(_route, 0, alongTheLastStep), 2);
    });

    test('overshooting a junction onto the wrong road holds the step', () {
      // ~78 m past B, still heading east instead of turning: the instruction
      // the tourist just missed is the one they most need to see.
      const wrongRoad = LatLng(5.41411, 100.33050);

      expect(service.advanceStepIndex(_route, 0, wrongRoad), 0);
    });

    test('being near a later leg without having passed the manoeuvre holds',
        () {
      // Standing on step 0 at a point that happens to be close to step 1's
      // road, but still short of the junction.
      const beforeTheJunction = LatLng(5.41405, 100.32960);

      expect(service.advanceStepIndex(_route, 0, beforeTheJunction), 0);
    });

    test('the index never rewinds onto an earlier leg', () {
      // Back at the very start of the route while the banner is on step 1 —
      // GPS wander, not a journey restarting.
      expect(service.advanceStepIndex(_route, 1, _a), 1);
    });

    test('a step with no usable polyline still advances on its end points', () {
      // Transit legs and very short manoeuvres come back with a one-point
      // polyline; the straight line between the step's own end points stands
      // in for it.
      final sparse = [
        RouteStep(
          instruction: 'Head east on Lebuh Chulia',
          maneuver: '',
          distanceMeters: 110,
          durationSeconds: 90,
          startLocation: _a,
          endLocation: _b,
          polylinePoints: const [_a],
        ),
        RouteStep(
          instruction: 'Turn left onto Lebuh Penang',
          maneuver: 'turn-left',
          distanceMeters: 111,
          durationSeconds: 90,
          startLocation: _b,
          endLocation: _c,
          polylinePoints: const [],
        ),
      ];

      expect(
        service.advanceStepIndex(sparse, 0, const LatLng(5.41425, 100.32982)),
        1,
      );
    });
  });
}
