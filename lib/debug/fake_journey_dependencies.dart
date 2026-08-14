// Debug-only fake dependencies for the interactive Demo Walking Journey
// (see demo_journey_flow_view.dart). None of these touch GPS, Firestore, or
// the real Reward Module — they exist so the real ActiveWalkingView,
// VerifyLocationView and JourneyCompletedView can be driven end-to-end for a
// lecturer demonstration with no network, GPS, or Firebase project required.
//
// Reused by test/controllers/journey_completion_controller_test.dart and
// test/views/demo_journey_flow_view_test.dart, so the same fakes back both
// the live demo and its test coverage.

import '../controllers/reward_service.dart';
import '../models/check_in_result.dart';
import '../services/arrival_verification_service.dart';
import '../services/check_in_repository.dart';

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

  @override
  Future<ArrivalCheckReading> checkDistanceTo({
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    await Future.delayed(delay);
    return ArrivalCheckReading.success(simulatedDistanceMeters);
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
