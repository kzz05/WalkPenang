// Fake dependencies for the journey-completion flow. None of these touch
// GPS, Firestore, or the real Reward Module — they exist so the real
// ActiveWalkingView, VerifyLocationView and JourneyCompletedView can be
// driven end-to-end with no network, GPS, or Firebase project required.
//
// Used by test/controllers/journey_completion_controller_test.dart and
// test/views/demo_journey_flow_view_test.dart via demo_journey_flow_view.dart.

import 'package:walkpenang/controllers/reward_service.dart';
import 'package:walkpenang/models/check_in_result.dart';
import 'package:walkpenang/services/arrival_verification_service.dart';
import 'package:walkpenang/services/check_in_repository.dart';
import 'package:walkpenang/services/journey_progress_service.dart';

/// Always reports the tourist within [MapConstants.checkInThresholdMeters],
/// after [delay] so the "Checking your location…" (04a) state is actually
/// visible during the demo rather than flashing past instantly.
class FakeArrivalVerificationService implements ArrivalVerificationService {
  const FakeArrivalVerificationService({
    this.delay = const Duration(seconds: 2),
    this.simulatedDistanceMeters = 42,
  });

  final Duration delay;
  final double simulatedDistanceMeters;

  /// Metres per degree of latitude — only used to place the demo's fake
  /// tourist [simulatedDistanceMeters] due north of the destination, so the
  /// Verify Location map has a dot to draw inside the radius. Nothing about
  /// arrival is decided from it; the reported distance is still
  /// [simulatedDistanceMeters] exactly.
  static const _metresPerDegreeLatitude = 111320.0;

  @override
  Future<ArrivalCheckReading> checkDistanceTo({
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    await Future.delayed(delay);
    return ArrivalCheckReading.success(
      simulatedDistanceMeters,
      userLatitude: destinationLatitude +
          simulatedDistanceMeters / _metresPerDegreeLatitude,
      userLongitude: destinationLongitude,
    );
  }
}

/// Never writes anywhere — the demo's stand-in for [CheckInRepository], so
/// the interactive demo can never create a real check_ins document.
class NoopCheckInRepository implements CheckInRepository {
  int _counter = 0;

  @override
  String newCheckInId() => 'demo-checkin-${_counter++}';

  @override
  Future<void> saveCheckIn(CheckInResult result) async {
    // Intentionally does nothing — see class doc.
  }
}

/// Returns a realistic, canned [RewardOutcome] instead of calling the real
/// RewardController/Firestore, so the demo can show points and a newly
/// earned badge without awarding anything real. Mirrors the real
/// RewardService's idempotency contract (a repeated checkInId reports
/// alreadyAwarded) purely in memory, so the demo can also show that state on
/// request without touching a ledger anywhere.
class FakeRewardService implements RewardService {
  FakeRewardService({
    this.pointsAwarded = 15,
    this.newlyEarnedBadgeIds = const ['explorer'],
    this.delay = const Duration(milliseconds: 800),
  });

  final int pointsAwarded;
  final List<String> newlyEarnedBadgeIds;
  final Duration delay;

  final Set<String> _rewarded = {};

  @override
  Future<RewardOutcome> onCheckInVerified(CheckInResult result) async {
    await Future.delayed(delay);
    if (_rewarded.contains(result.checkInId)) {
      return RewardOutcome(pointsAwarded: pointsAwarded, alreadyAwarded: true);
    }
    _rewarded.add(result.checkInId);
    return RewardOutcome(
      pointsAwarded: pointsAwarded,
      newlyEarnedBadgeIds: newlyEarnedBadgeIds,
    );
  }
}

/// Walks a scripted distance so the demo's KM COVERED and MIN REMAINING
/// tiles count up without a GPS fix, the same way
/// [FakeArrivalVerificationService] stands in for the arrival check.
///
/// Emits [stepMeters] every [interval] up to [totalMeters], then stops —
/// mirroring a tourist arriving rather than walking on forever.
///
/// The scripted walker heads straight at the destination, so the distance
/// still to go is whatever is left of [totalMeters]. That drives the demo's
/// progress bar from 0% to 100% without a GPS fix; the destination
/// coordinates are ignored precisely because there is no real position to
/// measure them against.
class FakeJourneyProgressService implements JourneyProgressService {
  const FakeJourneyProgressService({
    this.stepMeters = 60,
    this.totalMeters = 2400,
    this.interval = const Duration(seconds: 1),
  });

  final double stepMeters;
  final double totalMeters;
  final Duration interval;

  @override
  Stream<JourneyProgressUpdate> track({
    required double destinationLatitude,
    required double destinationLongitude,
  }) async* {
    var walked = 0.0;
    yield JourneyProgressUpdate(
      metresWalked: walked,
      metresToDestination: totalMeters,
    );
    while (walked < totalMeters) {
      await Future<void>.delayed(interval);
      walked = (walked + stepMeters).clamp(0, totalMeters).toDouble();
      yield JourneyProgressUpdate(
        metresWalked: walked,
        metresToDestination: totalMeters - walked,
      );
    }
  }
}
