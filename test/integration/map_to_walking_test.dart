// Tests for the Map & GPS -> Walking & Carbon hand-off.
//
// The seam these cover was designed long before it was connected:
// WalkingRouteSummary documented the contract, and walking_view.dart carried
// a TODO(map-gps) seeding WalkingRouteSummary.demo, so every journey went to
// Fort Cornwallis whatever pin the tourist had actually tapped. The route
// summary now builds a real summary from the tapped place.
//
// Three of these groups exist because the corresponding defect was found by
// hand rather than by a test. They are written to fail loudly if the wiring
// is unpicked again.
//
// Every dependency is a local fake — no GPS, no Firebase — matching
// test/controllers/journey_completion_controller_test.dart.

import 'package:flutter_test/flutter_test.dart';

import 'package:walkpenang/constants/map_constants.dart';
import 'package:walkpenang/controllers/journey_completion_controller.dart';
import 'package:walkpenang/controllers/reward_service.dart';
import 'package:walkpenang/controllers/walking_controller.dart';
import 'package:walkpenang/models/check_in_result.dart';
import 'package:walkpenang/models/transport_mode.dart';
import 'package:walkpenang/models/user_profile.dart';
import 'package:walkpenang/models/verify_location_ui_data.dart';
import 'package:walkpenang/models/walking_route_summary.dart';
import 'package:walkpenang/services/arrival_verification_service.dart';
import 'package:walkpenang/services/check_in_repository.dart';
import 'package:walkpenang/services/journey_progress_service.dart';
import 'package:walkpenang/utils/reward_constants.dart';

/// Stands in for a place the Map module resolved and a route it calculated.
WalkingRouteSummary _summaryFor(
  TransportMode mode, {
  double distanceKm = 2.3,
}) {
  return WalkingRouteSummary.fromDestination(
    destinationId: 'ChIJ_fort_cornwallis',
    destinationName: 'Fort Cornwallis',
    areaLabel: 'Jalan Light, George Town',
    destinationLatitude: 5.4206,
    destinationLongitude: 100.3436,
    distanceKm: distanceKm,
    estimatedDuration: const Duration(minutes: 33),
    transportMode: mode,
  );
}

/// Records every [CheckInResult] it is asked to save, without writing
/// anywhere.
class _RecordingCheckInRepository implements CheckInRepository {
  final List<CheckInResult> saved = [];
  int _counter = 0;

  @override
  String newCheckInId() => 'test-checkin-${_counter++}';

  @override
  Future<void> saveCheckIn(CheckInResult result) async {
    saved.add(result);
  }
}

/// Returns a fixed reading every call, so each test controls exactly what the
/// "GPS" reports.
class _ScriptedArrivalService implements ArrivalVerificationService {
  _ScriptedArrivalService(this.reading);

  final ArrivalCheckReading reading;

  @override
  Future<ArrivalCheckReading> checkDistanceTo({
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    return reading;
  }
}

/// Replays a scripted progress stream in place of GPS.
class _ScriptedProgressService implements JourneyProgressService {
  _ScriptedProgressService(this.updates);

  final Stream<JourneyProgressUpdate> updates;

  @override
  Stream<JourneyProgressUpdate> track({
    required double destinationLatitude,
    required double destinationLongitude,
  }) =>
      updates;
}

class _StubRewardService implements RewardService {
  @override
  Future<RewardOutcome> onCheckInVerified(CheckInResult result) async {
    return const RewardOutcome(pointsAwarded: 33);
  }
}

void main() {
  group('WalkingRouteSummary.fromDestination', () {
    test('carries the tapped place and calculated route through', () {
      final summary = _summaryFor(TransportMode.walking);

      expect(summary.destinationId, 'ChIJ_fort_cornwallis');
      expect(summary.destinationName, 'Fort Cornwallis');
      expect(summary.areaLabel, 'Jalan Light, George Town');
      expect(summary.destinationLatitude, 5.4206);
      expect(summary.destinationLongitude, 100.3436);
      expect(summary.distanceKm, 2.3);
      expect(summary.estimatedDuration, const Duration(minutes: 33));
      expect(summary.transportMode, TransportMode.walking);
    });

    test('previews the award the reward module will actually grant', () {
      final summary = _summaryFor(TransportMode.walking, distanceKm: 2.3);

      // The pre-walk screen promises "Complete this walk to earn N
      // WalkPoints", so N has to be the real figure — not the demo fixture's
      // hardcoded 15, which is what this replaced.
      expect(summary.rewardPoints, RewardPoints.forCheckInKm(distanceKm: 2.3));
      expect(
        summary.rewardPoints,
        isNot(WalkingRouteSummary.demo.rewardPoints),
      );
    });

    test('promises no badge it cannot deliver', () {
      final summary = _summaryFor(TransportMode.walking);

      // Every badge is a cumulative milestone (Explorer at 5 check-ins,
      // Trailblazer at 10 km, Penang Wanderer at 50 km) — there is no
      // per-place badge, so the copy must not name one.
      expect(summary.rewardBadgeLabel, isNot(contains('Fort Cornwallis')));
    });

    test('a route with no distance is rejected as invalid', () {
      expect(_summaryFor(TransportMode.walking).isValid, isTrue);
      expect(
        _summaryFor(TransportMode.walking, distanceKm: 0).isValid,
        isFalse,
      );
    });
  });

  group('transport mode reaches the saved check-in', () {
    Future<CheckInResult> completeJourneyWith(TransportMode mode) async {
      final repository = _RecordingCheckInRepository();
      final controller = JourneyCompletionController(
        routeSummary: _summaryFor(mode),
        userId: 'tourist_001',
        rewardService: _StubRewardService(),
        checkInRepository: repository,
        arrivalVerificationService:
            _ScriptedArrivalService(const ArrivalCheckReading.success(42)),
      );
      addTearDown(controller.dispose);

      await controller.beginVerification();
      await controller.completeJourney();

      return repository.saved.single;
    }

    test('a walk is recorded as a walk, and earns points', () async {
      final result = await completeJourneyWith(TransportMode.walking);

      expect(result.transportMode, TransportMode.walking);
      expect(result.earnsPoints, isTrue);
    });

    test('a drive is recorded as a drive, and earns nothing', () async {
      // The one that matters. CheckInResult.transportMode defaults to
      // walking, so if JourneyCompletionController stops passing the route
      // summary's mode this silently starts paying a driver a walker's
      // points (FR-W01).
      final result = await completeJourneyWith(TransportMode.driving);

      expect(result.transportMode, TransportMode.driving);
      expect(result.earnsPoints, isFalse);
    });

    test('public transport is recorded, and earns nothing', () async {
      final result = await completeJourneyWith(TransportMode.publicTransport);

      expect(result.transportMode, TransportMode.publicTransport);
      expect(result.earnsPoints, isFalse);
    });
  });

  group('live journey progress', () {
    // KM COVERED and MIN REMAINING had no source at all until
    // JourneyProgressService existed — JourneyCompletionController never
    // passed kmCovered or minutesRemaining, so both tiles sat on their
    // "not available" state for an entire journey.

    JourneyCompletionController controllerFrom(
      Stream<JourneyProgressUpdate> updates, {
      TransportMode mode = TransportMode.walking,
    }) {
      final controller = JourneyCompletionController(
        routeSummary: _summaryFor(mode, distanceKm: 2.0),
        userId: 'tourist_001',
        rewardService: _StubRewardService(),
        checkInRepository: _RecordingCheckInRepository(),
        arrivalVerificationService:
            _ScriptedArrivalService(const ArrivalCheckReading.success(42)),
        journeyProgressService: _ScriptedProgressService(updates),
      );
      addTearDown(controller.dispose);
      return controller;
    }

    /// These tests are about KM COVERED, so they script walked metres and
    /// hold the destination a constant 500 m away.
    JourneyCompletionController controllerWith(
      Stream<double> metres, {
      TransportMode mode = TransportMode.walking,
    }) {
      return controllerFrom(
        metres.map((m) => JourneyProgressUpdate(
              metresWalked: m,
              metresToDestination: 500,
            )),
        mode: mode,
      );
    }

    test('reports nothing until the first fix lands', () {
      final controller = controllerWith(const Stream<double>.empty());

      // Not 0.0 — the tiles must distinguish "not tracking" from "tracked,
      // and you have not moved yet".
      expect(controller.kmCovered, isNull);
      expect(controller.minutesRemaining, isNull);
      expect(controller.activeWalkingUiData.kmCovered, isNull);
      expect(controller.activeWalkingUiData.minutesRemaining, isNull);
    });

    test('reports distance covered once fixes arrive', () async {
      final controller = controllerWith(Stream<double>.fromIterable([250, 600]));
      await Future<void>.delayed(Duration.zero);

      expect(controller.kmCovered, closeTo(0.6, 1e-9));
      expect(controller.activeWalkingUiData.kmCovered, closeTo(0.6, 1e-9));
    });

    test('counts down the minutes remaining at the route pace', () async {
      // 2.0 km planned over 33 minutes. After 1.0 km there is half the route
      // left, so roughly half the planned time.
      final controller = controllerWith(Stream<double>.fromIterable([1000]));
      await Future<void>.delayed(Duration.zero);

      expect(controller.minutesRemaining, 17);
    });

    test('never reports negative time once the route is overshot', () async {
      final controller = controllerWith(Stream<double>.fromIterable([9000]));
      await Future<void>.delayed(Duration.zero);

      expect(controller.minutesRemaining, 0);
    });

    test('a failing position stream does not break the journey', () async {
      final controller = controllerWith(
        Stream<double>.error(StateError('GPS off')),
      );
      await Future<void>.delayed(Duration.zero);

      // Unavailable, not crashed: arrival has its own one-shot fix, so the
      // tourist can still complete and be rewarded.
      expect(controller.kmCovered, isNull);
      await controller.beginVerification();
      expect(
        controller.verifyLocationUiData.phase,
        VerifyLocationPhase.verified,
      );
    });

    test('the completed screen reports walked distance, not planned', () async {
      final controller = controllerWith(Stream<double>.fromIterable([1500]));
      await Future<void>.delayed(Duration.zero);

      await controller.beginVerification();
      await controller.completeJourney();

      // 1.5 km walked against a 2.0 km plan — the completed card must show
      // what happened, never the route's promise.
      expect(
        controller.journeyCompletedUiData.completedDistanceKm,
        closeTo(1.5, 1e-9),
      );
      expect(
        controller.journeyCompletedUiData.completedDistanceKm,
        isNot(closeTo(2.0, 1e-9)),
      );
    });
  });

  group('journey progress bar', () {
    // The bug this group exists for: the bar used to read
    // kmCovered / plannedDistanceKm, so it measured how far the tourist had
    // physically walked instead of how much closer they had got. On a 0.6 km
    // route, 0.5 km of wandering showed a nearly full bar while Verify
    // Location still reported 817 m to go. Progress is now the distance
    // actually closed on the destination, which can fall as well as rise.

    /// Scripts a walk as (cumulative metres walked, metres still to go).
    JourneyCompletionController walk(List<List<double>> fixes) {
      final controller = JourneyCompletionController(
        routeSummary: _summaryFor(TransportMode.walking, distanceKm: 2.0),
        userId: 'tourist_001',
        rewardService: _StubRewardService(),
        checkInRepository: _RecordingCheckInRepository(),
        arrivalVerificationService:
            _ScriptedArrivalService(const ArrivalCheckReading.success(42)),
        journeyProgressService: _ScriptedProgressService(
          Stream<JourneyProgressUpdate>.fromIterable(
            fixes.map((f) => JourneyProgressUpdate(
                  metresWalked: f[0],
                  metresToDestination: f[1],
                )),
          ),
        ),
      );
      addTearDown(controller.dispose);
      return controller;
    }

    double progressOf(JourneyCompletionController c) =>
        c.activeWalkingUiData.progressFraction;

    test('A · starts at 0% on the first fix, 600 m from the destination',
        () async {
      final controller = walk([
        [0, 600],
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(progressOf(controller), closeTo(0.0, 1e-9));
    });

    test('B · halfway in when the remaining 600 m becomes 300 m', () async {
      final controller = walk([
        [0, 600],
        [400, 300],
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(progressOf(controller), closeTo(0.5, 1e-9));
    });

    test('C · falls back when the tourist walks away from the destination',
        () async {
      final controller = walk([
        [0, 600],
        [400, 300],
      ]);
      await Future<void>.delayed(Duration.zero);
      final atHalfway = progressOf(controller);

      final backedOff = walk([
        [0, 600],
        [400, 300],
        [600, 450],
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(atHalfway, closeTo(0.5, 1e-9));
      expect(progressOf(backedOff), closeTo(0.25, 1e-9));
      expect(progressOf(backedOff), lessThan(atHalfway));
    });

    test('D · walking in circles moves KM COVERED but not the bar', () async {
      final controller = walk([
        [0, 600],
        [400, 300],
        [900, 305],
        [1400, 298],
      ]);
      await Future<void>.delayed(Duration.zero);

      // A further kilometre on the clock...
      expect(controller.kmCovered, closeTo(1.4, 1e-9));
      // ...and the destination is no nearer than it was at the halfway mark.
      expect(progressOf(controller), closeTo(0.503, 0.01));
    });

    test('E · clamps to 0% past the distance the journey started at',
        () async {
      final controller = walk([
        [0, 600],
        [2000, 900],
      ]);
      await Future<void>.delayed(Duration.zero);

      // Never negative, however far the wrong way they went.
      expect(progressOf(controller), 0.0);
    });

    test('F · clamps to 100% at (or past) the destination', () async {
      final controller = walk([
        [0, 600],
        [700, 0],
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(progressOf(controller), 1.0);
    });

    test('reads empty, not partly filled, before the first fix', () {
      final controller = walk(const []);

      expect(progressOf(controller), 0.0);
    });

    test('a journey that starts on the destination cannot divide by zero',
        () async {
      final controller = walk([
        [0, 0],
        [50, 40],
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(progressOf(controller).isNaN, isFalse);
      expect(progressOf(controller), 0.0);
    });

    test('G · leaves distance, carbon, calories and verification untouched',
        () async {
      final controller = JourneyCompletionController(
        routeSummary: _summaryFor(TransportMode.walking, distanceKm: 2.0),
        userId: 'tourist_001',
        rewardService: _StubRewardService(),
        checkInRepository: _RecordingCheckInRepository(),
        arrivalVerificationService:
            _ScriptedArrivalService(const ArrivalCheckReading.success(42)),
        journeyProgressService: _ScriptedProgressService(
          Stream<JourneyProgressUpdate>.fromIterable(const [
            JourneyProgressUpdate(metresWalked: 0, metresToDestination: 600),
            JourneyProgressUpdate(metresWalked: 800, metresToDestination: 150),
          ]),
        ),
        carbonSavedKg: 0.42,
        caloriesBurned: 117.0,
      );
      addTearDown(controller.dispose);
      await Future<void>.delayed(Duration.zero);

      // KM COVERED is still cumulative movement, not the closed distance.
      expect(controller.kmCovered, closeTo(0.8, 1e-9));
      expect(controller.activeWalkingUiData.kmCovered, closeTo(0.8, 1e-9));
      // Pre-walk promises, unchanged by anything the progress bar does.
      expect(controller.activeWalkingUiData.carbonSavedKg, 0.42);
      expect(controller.activeWalkingUiData.caloriesBurned, 117.0);
      // MIN REMAINING still runs off the planned pace, as before.
      expect(controller.minutesRemaining, 20);
      // And arrival is still decided by its own one-shot fix, not the bar.
      expect(progressOf(controller), closeTo(0.75, 1e-9));
      await controller.beginVerification();
      expect(
        controller.verifyLocationUiData.phase,
        VerifyLocationPhase.verified,
      );
    });
  });

  group('arrival threshold', () {
    // The Map module's navigation and the Walking module's verification each
    // used to write their own `distance <= checkInThresholdMeters`. Two
    // comparisons that must agree can drift, and `<` against `<=` decides
    // whether a tourist standing at exactly 100 m has arrived.
    test('is inclusive at exactly the threshold', () {
      expect(MapConstants.isWithinCheckInRange(99.9), isTrue);
      expect(
        MapConstants.isWithinCheckInRange(MapConstants.checkInThresholdMeters),
        isTrue,
      );
      expect(MapConstants.isWithinCheckInRange(100.1), isFalse);
    });
  });

  group('WalkingController mode gating', () {
    UserProfile buildProfile() => UserProfile(
          nickname: 'Tester',
          weightKg: 50,
          heightCm: 165,
          units: 'metric',
        );

    test('a walk reports carbon saved and calories burned', () {
      final controller = WalkingController()
        ..setUserProfile(buildProfile())
        ..selectMode(TransportMode.walking)
        ..setRouteSummary(_summaryFor(TransportMode.walking));
      addTearDown(controller.dispose);

      expect(controller.carbonSavedKg, greaterThan(0));
      expect(controller.caloriesBurned, isNotNull);
    });

    test('without a selected mode both are unavailable', () {
      // Documents why route_summary_view._startJourney's selectMode call is
      // load-bearing despite looking redundant next to setRouteSummary:
      // carbon and calories are gated on the controller's own mode, so
      // omitting it showed 0 kg CO2 saved and the missing-weight prompt on a
      // perfectly valid walk.
      //
      // Note this documents the behaviour, it does not guard the call site —
      // deleting that line still leaves the whole suite green, because
      // _startJourney is a view method needing ProfileStore and a Navigator.
      // Guarding it properly needs a RouteSummaryView widget test with a fake
      // RouteService; until then the device pass is what covers it.
      //
      // Making setRouteSummary adopt summary.transportMode would remove the
      // hazard outright, but the Walking module deliberately asserts the
      // opposite in walking_controller_test — "is null when no transport mode
      // is selected" — so that is its owner's call to make, not this seam's.
      final controller = WalkingController()
        ..setUserProfile(buildProfile())
        ..setRouteSummary(_summaryFor(TransportMode.walking));
      addTearDown(controller.dispose);

      expect(controller.carbonSavedKg, 0.0);
      expect(controller.caloriesBurned, isNull);
    });

    test('a drive saves no carbon and burns no attributable calories', () {
      final controller = WalkingController()
        ..setUserProfile(buildProfile())
        ..selectMode(TransportMode.driving)
        ..setRouteSummary(_summaryFor(TransportMode.driving));
      addTearDown(controller.dispose);

      expect(controller.carbonSavedKg, 0.0);
      expect(controller.caloriesBurned, isNull);
    });
  });
}
