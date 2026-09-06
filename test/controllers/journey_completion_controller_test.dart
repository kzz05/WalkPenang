// Unit tests for US-W05/UC-W06 — journey completion, arrival verification,
// and the handoff to Module 5's RewardService.
//
// Every dependency is a fake declared in this file (or, for the happy-path
// reward mapping, the same fakes the interactive demo uses) — no GPS, no
// Firebase, matching how the rest of this module's tests avoid both.

import 'package:flutter_test/flutter_test.dart';

import 'package:walkpenang/controllers/journey_completion_controller.dart';
import 'package:walkpenang/controllers/reward_service.dart';
import '../support/fake_journey_dependencies.dart';
import 'package:walkpenang/models/check_in_result.dart';
import 'package:walkpenang/models/journey_reward_ui_state.dart';
import 'package:walkpenang/models/verify_location_ui_data.dart';
import 'package:walkpenang/models/walking_route_summary.dart';
import 'package:walkpenang/services/arrival_verification_service.dart';
import 'package:walkpenang/services/check_in_repository.dart';

const _summary = WalkingRouteSummary(
  destinationName: 'Fort Cornwallis',
  areaLabel: 'George Town Heritage Zone',
  distanceKm: 2.4,
  estimatedDuration: Duration(minutes: 32),
  rewardPoints: 15,
  rewardBadgeLabel: 'a heritage badge for Fort Cornwallis',
  destinationId: 'test-fort-cornwallis',
  destinationLatitude: 5.4229,
  destinationLongitude: 100.3402,
);

/// Returns a fixed [ArrivalCheckReading] every call, so each test controls
/// exactly what the "GPS" reports without any real location source.
class _ScriptedArrivalService implements ArrivalVerificationService {
  _ScriptedArrivalService(this.reading);

  final ArrivalCheckReading reading;
  int callCount = 0;

  @override
  Future<ArrivalCheckReading> checkDistanceTo({
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    callCount++;
    return reading;
  }
}

/// Records every [CheckInResult] it's asked to save, without writing
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

/// Always throws — for the reward-service-failure case.
class _ThrowingRewardService implements RewardService {
  int callCount = 0;

  @override
  Future<RewardOutcome> onCheckInVerified(CheckInResult result) async {
    callCount++;
    throw Exception('network error');
  }
}

/// Records how many times it was called, and with which results, without
/// doing anything else — for the duplicate-completion guard test.
class _CountingRewardService implements RewardService {
  int callCount = 0;

  @override
  Future<RewardOutcome> onCheckInVerified(CheckInResult result) async {
    callCount++;
    return const RewardOutcome(pointsAwarded: 15);
  }
}

JourneyCompletionController _buildController({
  required ArrivalVerificationService arrival,
  required RewardService reward,
  CheckInRepository? checkInRepository,
  String userId = 'tourist_001',
}) {
  return JourneyCompletionController(
    routeSummary: _summary,
    userId: userId,
    rewardService: reward,
    checkInRepository: checkInRepository ?? _RecordingCheckInRepository(),
    arrivalVerificationService: arrival,
    carbonSavedKg: 0.504,
    bodyWeightKg: 65,
  );
}

void main() {
  group('arrival verification', () {
    test('within the check-in threshold verifies the journey', () async {
      final controller = _buildController(
        arrival: _ScriptedArrivalService(const ArrivalCheckReading.success(42)),
        reward: _CountingRewardService(),
      );
      addTearDown(controller.dispose);

      await controller.beginVerification();

      expect(controller.step, JourneyStep.verifyingLocation);
      expect(
          controller.verifyLocationUiData.phase, VerifyLocationPhase.verified);
      expect(controller.verifyLocationUiData.currentDistanceMeters, 42);
      expect(controller.verifyLocationUiData.blockReason, isNull);
    });

    test('farther than the check-in threshold blocks with tooFar', () async {
      final controller = _buildController(
        arrival:
            _ScriptedArrivalService(const ArrivalCheckReading.success(260)),
        reward: _CountingRewardService(),
      );
      addTearDown(controller.dispose);

      await controller.beginVerification();

      expect(
          controller.verifyLocationUiData.phase, VerifyLocationPhase.blocked);
      expect(controller.verifyLocationUiData.blockReason,
          VerifyBlockReason.tooFar);
      expect(controller.verifyLocationUiData.currentDistanceMeters, 260);
    });

    test('permission denied blocks with permissionDenied, no distance',
        () async {
      final controller = _buildController(
        arrival: _ScriptedArrivalService(
          const ArrivalCheckReading.failure(
              ArrivalCheckStatus.permissionDenied),
        ),
        reward: _CountingRewardService(),
      );
      addTearDown(controller.dispose);

      await controller.beginVerification();

      expect(controller.verifyLocationUiData.blockReason,
          VerifyBlockReason.permissionDenied);
      expect(controller.verifyLocationUiData.currentDistanceMeters, isNull);
    });

    test('GPS unavailable blocks with gpsDisabled', () async {
      final controller = _buildController(
        arrival: _ScriptedArrivalService(
          const ArrivalCheckReading.failure(ArrivalCheckStatus.gpsUnavailable),
        ),
        reward: _CountingRewardService(),
      );
      addTearDown(controller.dispose);

      await controller.beginVerification();

      expect(
        controller.verifyLocationUiData.blockReason,
        VerifyBlockReason.gpsDisabled,
      );
    });

    test('weak signal blocks with weakSignal', () async {
      final controller = _buildController(
        arrival: _ScriptedArrivalService(
          const ArrivalCheckReading.failure(ArrivalCheckStatus.weakSignal),
        ),
        reward: _CountingRewardService(),
      );
      addTearDown(controller.dispose);

      await controller.beginVerification();

      expect(
        controller.verifyLocationUiData.blockReason,
        VerifyBlockReason.weakSignal,
      );
    });

    test('retryVerification re-runs the check', () async {
      final arrival =
          _ScriptedArrivalService(const ArrivalCheckReading.success(42));
      final controller = _buildController(
        arrival: arrival,
        reward: _CountingRewardService(),
      );
      addTearDown(controller.dispose);

      await controller.beginVerification();
      expect(arrival.callCount, 1);

      await controller.retryVerification();
      expect(arrival.callCount, 2);
    });

    test('carries both positions through for the Verify Location map',
        () async {
      final controller = _buildController(
        arrival: _ScriptedArrivalService(
          const ArrivalCheckReading.success(
            42,
            userLatitude: 5.4231,
            userLongitude: 100.3407,
          ),
        ),
        reward: _CountingRewardService(),
      );
      addTearDown(controller.dispose);

      await controller.beginVerification();
      final data = controller.verifyLocationUiData;

      expect(data.destinationLatitude, _summary.destinationLatitude);
      expect(data.destinationLongitude, _summary.destinationLongitude);
      expect(data.userLatitude, 5.4231);
      expect(data.userLongitude, 100.3407);
      // The map is drawn from the fix the distance was measured from, so the
      // verified distance must still be exactly what the reading reported.
      expect(data.currentDistanceMeters, 42);
    });

    test('a failed reading leaves no position to plot the tourist from',
        () async {
      final controller = _buildController(
        arrival: _ScriptedArrivalService(
          const ArrivalCheckReading.failure(ArrivalCheckStatus.gpsUnavailable),
        ),
        reward: _CountingRewardService(),
      );
      addTearDown(controller.dispose);

      await controller.beginVerification();
      final data = controller.verifyLocationUiData;

      expect(data.hasUserPosition, isFalse);
      // The destination is still known, so the zone can still be shown.
      expect(data.hasDestinationPosition, isTrue);
    });

    test('continueWalking returns to the active step', () async {
      final controller = _buildController(
        arrival:
            _ScriptedArrivalService(const ArrivalCheckReading.success(260)),
        reward: _CountingRewardService(),
      );
      addTearDown(controller.dispose);

      await controller.beginVerification();
      expect(controller.step, JourneyStep.verifyingLocation);

      controller.continueWalking();
      expect(controller.step, JourneyStep.active);
    });
  });

  group('reward handoff', () {
    test('a successful RewardOutcome maps to a success reward state', () async {
      final checkInRepo = _RecordingCheckInRepository();
      final controller = _buildController(
        arrival: _ScriptedArrivalService(const ArrivalCheckReading.success(42)),
        reward:
            FakeRewardService(pointsAwarded: 13, newlyEarnedBadgeIds: const []),
        checkInRepository: checkInRepo,
      );
      addTearDown(controller.dispose);

      await controller.beginVerification();
      await controller.completeJourney();

      final reward = controller.journeyCompletedUiData.reward;
      expect(reward.status, JourneyRewardUiStatus.success);
      expect(reward.pointsAwarded, 13);
      expect(reward.newlyEarnedBadgeNames, isEmpty);
      expect(reward.alreadyAwarded, isFalse);
      expect(checkInRepo.saved, hasLength(1));
      expect(checkInRepo.saved.single.destinationId, 'test-fort-cornwallis');
    });

    test('newly earned badge IDs resolve to their catalogue names', () async {
      final controller = _buildController(
        arrival: _ScriptedArrivalService(const ArrivalCheckReading.success(42)),
        reward: FakeRewardService(
          pointsAwarded: 15,
          newlyEarnedBadgeIds: const ['explorer', 'trailblazer'],
        ),
      );
      addTearDown(controller.dispose);

      await controller.beginVerification();
      await controller.completeJourney();

      expect(
        controller.journeyCompletedUiData.reward.newlyEarnedBadgeNames,
        containsAll(['Explorer', 'Trailblazer']),
      );
    });

    test('alreadyAwarded is passed through and not presented as new', () async {
      final reward = FakeRewardService(pointsAwarded: 13);
      final controller = _buildController(
        arrival: _ScriptedArrivalService(const ArrivalCheckReading.success(42)),
        reward: reward,
      );
      addTearDown(controller.dispose);

      await controller.beginVerification();
      await controller.completeJourney();
      expect(controller.journeyCompletedUiData.reward.alreadyAwarded, isFalse);

      // Simulate the same journey's reward being retried after the fact —
      // reuses the same cached CheckInResult/checkInId.
      await controller.retryReward();
      expect(controller.journeyCompletedUiData.reward.alreadyAwarded, isTrue);
      expect(controller.journeyCompletedUiData.reward.pointsAwarded, 13);
    });

    test('a RewardService failure maps to an error reward state', () async {
      final controller = _buildController(
        arrival: _ScriptedArrivalService(const ArrivalCheckReading.success(42)),
        reward: _ThrowingRewardService(),
      );
      addTearDown(controller.dispose);

      await controller.beginVerification();
      await controller.completeJourney();

      final reward = controller.journeyCompletedUiData.reward;
      expect(reward.status, JourneyRewardUiStatus.error);
      expect(reward.errorMessage, isNotNull);
    });

    test(
        'an empty userId short-circuits to an error without calling '
        'the reward service', () async {
      final rewardService = _CountingRewardService();
      final checkInRepo = _RecordingCheckInRepository();
      final controller = _buildController(
        arrival: _ScriptedArrivalService(const ArrivalCheckReading.success(42)),
        reward: rewardService,
        checkInRepository: checkInRepo,
        userId: '',
      );
      addTearDown(controller.dispose);

      await controller.beginVerification();
      await controller.completeJourney();

      expect(
        controller.journeyCompletedUiData.reward.status,
        JourneyRewardUiStatus.error,
      );
      expect(rewardService.callCount, 0);
      expect(checkInRepo.saved, isEmpty);
    });
  });

  group('duplicate-completion prevention', () {
    test(
        'completeJourney only calls the reward service once even if '
        'invoked twice', () async {
      final rewardService = _CountingRewardService();
      final controller = _buildController(
        arrival: _ScriptedArrivalService(const ArrivalCheckReading.success(42)),
        reward: rewardService,
      );
      addTearDown(controller.dispose);

      await controller.beginVerification();

      final first = controller.completeJourney();
      final second = controller.completeJourney();
      await Future.wait([first, second]);

      expect(rewardService.callCount, 1);
      expect(controller.isCompleted, isTrue);
    });

    test('completeJourney is a no-op before verification succeeds', () async {
      final rewardService = _CountingRewardService();
      final controller = _buildController(
        arrival:
            _ScriptedArrivalService(const ArrivalCheckReading.success(260)),
        reward: rewardService,
      );
      addTearDown(controller.dispose);

      await controller.beginVerification(); // blocked: tooFar
      await controller.completeJourney();

      expect(rewardService.callCount, 0);
      expect(controller.isCompleted, isFalse);
      expect(controller.step, JourneyStep.verifyingLocation);
    });
  });

  // UC-M05 arrival -> UC-W06 in one tap. The navigation screen has already
  // told the tourist they have arrived; verifyAndComplete is what stops the
  // app then asking them to say so twice more.
  group('one-tap arrival', () {
    test('a passing check completes the journey without a second call',
        () async {
      final rewardService = _CountingRewardService();
      final checkIns = _RecordingCheckInRepository();
      final controller = _buildController(
        arrival: _ScriptedArrivalService(const ArrivalCheckReading.success(42)),
        reward: rewardService,
        checkInRepository: checkIns,
      );
      addTearDown(controller.dispose);

      await controller.verifyAndComplete();

      expect(controller.step, JourneyStep.completed);
      expect(controller.isCompleted, isTrue);
      expect(rewardService.callCount, 1);
      expect(checkIns.saved, hasLength(1));
    });

    test('a failed check stops at Verify Location with its reason', () async {
      final rewardService = _CountingRewardService();
      final controller = _buildController(
        arrival:
            _ScriptedArrivalService(const ArrivalCheckReading.success(260)),
        reward: rewardService,
      );
      addTearDown(controller.dispose);

      await controller.verifyAndComplete();

      // The tourist is left on the one screen that can explain why and offer
      // a retry — completing anyway would reward a journey never verified.
      expect(controller.step, JourneyStep.verifyingLocation);
      expect(
          controller.verifyLocationUiData.phase, VerifyLocationPhase.blocked);
      expect(controller.verifyLocationUiData.blockReason,
          VerifyBlockReason.tooFar);
      expect(controller.isCompleted, isFalse);
      expect(rewardService.callCount, 0);
    });

    test('does not verify at all once the journey was given up', () async {
      final arrival =
          _ScriptedArrivalService(const ArrivalCheckReading.success(42));
      final rewardService = _CountingRewardService();
      final controller = _buildController(
        arrival: arrival,
        reward: rewardService,
      );
      addTearDown(controller.dispose);

      controller.cancelJourney();
      await controller.verifyAndComplete();

      expect(arrival.callCount, 0);
      expect(controller.isCompleted, isFalse);
      expect(rewardService.callCount, 0);
    });
  });

  group('completedJournalEntry (View Journey)', () {
    test('is null before the journey completes', () async {
      final controller = _buildController(
        arrival: _ScriptedArrivalService(const ArrivalCheckReading.success(42)),
        reward: _CountingRewardService(),
      );
      addTearDown(controller.dispose);

      expect(controller.completedJournalEntry, isNull);

      await controller.beginVerification();

      // Verified, but not completed — there is no journey record yet, so
      // there is nothing for View Journey to open.
      expect(controller.completedJournalEntry, isNull);
    });

    test('carries the same checkInId as the record that was saved', () async {
      final repository = _RecordingCheckInRepository();
      final controller = _buildController(
        arrival: _ScriptedArrivalService(const ArrivalCheckReading.success(42)),
        reward: _CountingRewardService(),
        checkInRepository: repository,
      );
      addTearDown(controller.dispose);

      await controller.verifyAndComplete();

      expect(repository.saved, hasLength(1));
      final entry = controller.completedJournalEntry;
      expect(entry, isNotNull);
      expect(entry!.checkInId, repository.saved.single.checkInId);
    });

    test('reports this journey, from the record rather than the screen',
        () async {
      final repository = _RecordingCheckInRepository();
      final controller = _buildController(
        arrival: _ScriptedArrivalService(const ArrivalCheckReading.success(42)),
        reward: _CountingRewardService(),
        checkInRepository: repository,
      );
      addTearDown(controller.dispose);

      await controller.verifyAndComplete();
      final entry = controller.completedJournalEntry!;
      final saved = repository.saved.single;

      expect(entry.destinationName, _summary.destinationName);
      expect(entry.destinationId, _summary.destinationId);
      // Built from the persisted record rather than from the completed
      // screen's own state, so the detail screen agrees with what the journal
      // will show for this journey later. Both distances come across: the
      // planned one the award was scored on, and the walked one the journal
      // displays — null here, since this controller tracks no progress.
      expect(entry.distanceKm, saved.distanceKm);
      expect(entry.walkedDistanceKm, saved.walkedDistanceKm);
      expect(entry.walkedDistanceKm, isNull);
      // With nothing tracked, the journal falls back to the planned figure
      // rather than showing a gap.
      expect(entry.displayDistanceKm, saved.distanceKm);
      expect(entry.carbonSavedKg, saved.carbonSavedKg);
      expect(entry.caloriesBurned, saved.caloriesBurned);
      expect(entry.transportMode, saved.transportMode);
      expect(entry.checkInTime, saved.checkInTime);
      expect(entry.pointsAwarded, 15);
    });

    test('reading it never saves a second check-in or awards again', () async {
      final repository = _RecordingCheckInRepository();
      final rewardService = _CountingRewardService();
      final controller = _buildController(
        arrival: _ScriptedArrivalService(const ArrivalCheckReading.success(42)),
        reward: rewardService,
        checkInRepository: repository,
      );
      addTearDown(controller.dispose);

      await controller.verifyAndComplete();
      expect(repository.saved, hasLength(1));
      expect(rewardService.callCount, 1);

      final first = controller.completedJournalEntry!;
      final second = controller.completedJournalEntry!;
      final third = controller.completedJournalEntry!;

      // Opening View Journey is a read of state already held. Nothing is
      // written, nothing is awarded, and the journey keeps its one identity.
      expect(repository.saved, hasLength(1));
      expect(rewardService.callCount, 1);
      expect(first.checkInId, second.checkInId);
      expect(second.checkInId, third.checkInId);
    });

    test('a failed award still opens the journey, with no points recorded',
        () async {
      final repository = _RecordingCheckInRepository();
      final controller = _buildController(
        arrival: _ScriptedArrivalService(const ArrivalCheckReading.success(42)),
        reward: _ThrowingRewardService(),
        checkInRepository: repository,
      );
      addTearDown(controller.dispose);

      await controller.verifyAndComplete();

      final entry = controller.completedJournalEntry;
      expect(entry, isNotNull);
      expect(entry!.checkInId, repository.saved.single.checkInId);
      // 0 rather than a fabricated figure — the detail screen renders that as
      // "not recorded" for a walk.
      expect(entry.pointsAwarded, 0);
    });

    test('an unauthenticated tourist still gets no check-in record', () async {
      final repository = _RecordingCheckInRepository();
      final rewardService = _CountingRewardService();
      final controller = _buildController(
        arrival: _ScriptedArrivalService(const ArrivalCheckReading.success(42)),
        reward: rewardService,
        checkInRepository: repository,
        userId: '',
      );
      addTearDown(controller.dispose);

      await controller.verifyAndComplete();

      // Unchanged by this feature: no record is created merely so that View
      // Journey has something to open. The button is disabled instead.
      expect(repository.saved, isEmpty);
      expect(rewardService.callCount, 0);
      expect(controller.completedJournalEntry, isNull);
      expect(controller.journeyCompletedUiData.reward.status,
          JourneyRewardUiStatus.error);
    });

    test('a retried reward keeps the same journey record', () async {
      final repository = _RecordingCheckInRepository();
      final rewardService = _CountingRewardService();
      final controller = _buildController(
        arrival: _ScriptedArrivalService(const ArrivalCheckReading.success(42)),
        reward: rewardService,
        checkInRepository: repository,
      );
      addTearDown(controller.dispose);

      await controller.verifyAndComplete();
      final before = controller.completedJournalEntry!.checkInId;

      await controller.retryReward();

      expect(controller.completedJournalEntry!.checkInId, before);
      expect(repository.saved.map((r) => r.checkInId).toSet(), {before});
    });
  });
}
