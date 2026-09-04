// ---------------------------------------------------------------------------
// reward_controller_test.dart
// Module 5 — Reward & Achievement
// Use Case : UC500 Earn points from activities, UC510 Unlock badges
// FR       : FR-R01 Points Award System, FR-R02 Badge Milestone System
// Task     : T-R01.3 Controller orchestration
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// Runs the controller against the in-memory DAOs, so the whole award path —
// points formula, ledger guard, badge evaluation, persistence — is covered
// with no Firebase project.
//
// flutter_test rather than the plain test package, because RewardController
// extends ChangeNotifier to drive the dashboard.

import 'package:flutter_test/flutter_test.dart';
import 'package:walkpenang/controllers/reward_controller.dart';
import '../support/in_memory_reward_data.dart';
import 'package:walkpenang/models/badge_model.dart';
import 'package:walkpenang/models/check_in_result.dart';
import 'package:walkpenang/utils/reward_constants.dart';

const userId = 'tourist_001';

CheckInResult checkIn({
  String checkInId = 'chk_001',
  double distanceKm = 1.3,
}) {
  return CheckInResult(
    checkInId: checkInId,
    userId: userId,
    destinationId: 'kek_lok_si',
    distanceKm: distanceKm,
    carbonSavedKg: 0.26,
    caloriesBurned: 78.0,
    checkInTime: DateTime(2026, 8, 6, 9, 30),
  );
}

void main() {
  late InMemoryRewardDao rewardDao;
  late InMemoryBadgeDao badgeDao;
  late RewardController controller;

  setUp(() {
    rewardDao = InMemoryRewardDao();
    badgeDao = InMemoryBadgeDao();
    controller = RewardController(
      userId: userId,
      rewardDao: rewardDao,
      badgeDao: badgeDao,
    );
  });

  group('awarding', () {
    test('awards the flat points plus the distance bonus', () async {
      // 10 for the check-in, plus 13 for 1.3 km. The 1.3 is deliberate: it is
      // held in binary as 1.2999…, so a naive (km * 10).floor() gives 12.
      final outcome = await controller.onCheckInVerified(checkIn());

      expect(outcome.pointsAwarded, 23);
      expect(outcome.alreadyAwarded, isFalse);
      expect(controller.stats.totalPoints, 23);
      expect(controller.stats.totalCheckIns, 1);
      expect(controller.stats.totalDistanceMetres, 1300);
    });

    test('accumulates Module 4 figures without recalculating them', () async {
      await controller.onCheckInVerified(checkIn(checkInId: 'a'));
      await controller.onCheckInVerified(checkIn(checkInId: 'b'));

      expect(controller.stats.totalCarbonSavedKg, closeTo(0.52, 1e-9));
      expect(controller.stats.totalCaloriesBurned, closeTo(156.0, 1e-9));
    });

    test('notifies listeners so the dashboard rebuilds', () async {
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.onCheckInVerified(checkIn());

      expect(notifications, greaterThan(0));
    });
  });

  group('idempotency (T-R01.5)', () {
    test('the same check-in submitted twice awards points once', () async {
      final first = await controller.onCheckInVerified(checkIn());
      final second = await controller.onCheckInVerified(checkIn());

      expect(first.alreadyAwarded, isFalse);
      expect(second.alreadyAwarded, isTrue);
      expect(controller.stats.totalPoints, first.pointsAwarded);
      expect(controller.stats.totalCheckIns, 1);
    });

    test('a repeat reports the original award rather than zero', () async {
      await controller.onCheckInVerified(checkIn());
      final repeat = await controller.onCheckInVerified(checkIn());

      // The formula is deterministic on the check-in's own distance, so the
      // recomputed figure is exactly what was awarded the first time.
      expect(repeat.pointsAwarded, 23);
    });

    test('a repeat does not re-award a badge', () async {
      // Reach Explorer, then replay the check-in that unlocked it. Two badges
      // are held by then — First Steps from the first check-in, Explorer from
      // the fifth — and the replay must not add a third.
      for (var i = 1; i <= 5; i++) {
        await controller.onCheckInVerified(checkIn(checkInId: 'chk_$i'));
      }
      final replay = await controller.onCheckInVerified(
        checkIn(checkInId: 'chk_5'),
      );

      expect(replay.alreadyAwarded, isTrue);
      expect(replay.newlyEarnedBadgeIds, isEmpty);
      expect(controller.unlockedBadgeCount, 2);
    });
  });

  group('badge evaluation', () {
    test('Explorer unlocks on the 5th check-in and not before', () async {
      // The first check-in earns First Steps. Nothing further is due until
      // the Explorer threshold, so check-ins two to four must award nothing.
      final first =
          await controller.onCheckInVerified(checkIn(checkInId: 'chk_1'));
      expect(first.newlyEarnedBadgeIds, [RewardConstants.firstStepsBadgeId]);

      for (var i = 2; i <= 4; i++) {
        final outcome =
            await controller.onCheckInVerified(checkIn(checkInId: 'chk_$i'));
        expect(outcome.newlyEarnedBadgeIds, isEmpty, reason: 'check-in $i');
      }

      final fifth =
          await controller.onCheckInVerified(checkIn(checkInId: 'chk_5'));

      expect(fifth.newlyEarnedBadgeIds, [RewardConstants.explorerBadgeId]);
      expect(controller.hasEarned(RewardConstants.explorerBadgeId), isTrue);
    });

    test('one check-in can unlock more than one badge', () async {
      final outcome = await controller.onCheckInVerified(
        checkIn(checkInId: 'chk_long', distanceKm: 52.0),
      );

      // One 52 km check-in crosses milestones on three different criteria at
      // once: it is a first check-in, it passes 10 km and 50 km, and its
      // 530-point award passes the Point Collector threshold. All of them are
      // due, and they come back in gallery order.
      expect(outcome.newlyEarnedBadgeIds, [
        RewardConstants.firstStepsBadgeId,
        RewardConstants.trailblazerBadgeId,
        RewardConstants.penangWandererBadgeId,
        RewardConstants.pointCollectorBadgeId,
      ]);
    });

    test('an earned badge keeps its original date', () async {
      await controller.onCheckInVerified(
        checkIn(checkInId: 'chk_long', distanceKm: 12.0),
      );
      final firstEarned = controller
          .earnedBadge(RewardConstants.trailblazerBadgeId)!
          .dateEarned;

      await controller.onCheckInVerified(
        checkIn(checkInId: 'chk_later', distanceKm: 3.0),
      );

      expect(
        controller.earnedBadge(RewardConstants.trailblazerBadgeId)!.dateEarned,
        firstEarned,
      );
    });
  });

  group('dashboard state', () {
    test('load fills totals, definitions and earned badges', () async {
      final seeded = RewardController(
        userId: DemoRewardData.userId,
        rewardDao: DemoRewardData.rewardDao(),
        badgeDao: DemoRewardData.badgeDao(),
      );

      await seeded.load();

      expect(seeded.isLoading, isFalse);
      expect(seeded.error, isNull);
      expect(seeded.definitions, hasLength(BadgeCatalogue.all.length));
      expect(seeded.unlockedBadgeCount, 3);
      expect(seeded.stats.totalPoints, 194);
    });

    test('demo totals are consistent with the points formula', () async {
      // A tutor can check the seeded numbers against the rule, so they must
      // add up: 7 check-ins at 10, plus 124 points for 12.4 km.
      const expected = 7 * RewardConstants.pointsPerCheckIn +
          12400 ~/ RewardConstants.metresPerDistancePoint;

      expect(DemoRewardData.stats.totalPoints, expected);
    });

    test('progress and captions reflect an unfinished milestone', () async {
      final seeded = RewardController(
        userId: DemoRewardData.userId,
        rewardDao: DemoRewardData.rewardDao(),
        badgeDao: DemoRewardData.badgeDao(),
      );
      await seeded.load();

      expect(seeded.progressTowards(BadgeCatalogue.explorer), 1.0);
      expect(seeded.remainingLabel(BadgeCatalogue.explorer), 'Unlocked');

      // 12.4 km of 50 km.
      expect(
        seeded.progressTowards(BadgeCatalogue.penangWanderer),
        closeTo(0.248, 1e-9),
      );
      expect(
        seeded.remainingLabel(BadgeCatalogue.penangWanderer),
        '37.6 km to go',
      );
    });

    test('the empty state shows every badge locked', () async {
      await controller.load();

      expect(controller.definitions, hasLength(BadgeCatalogue.all.length));
      expect(controller.unlockedBadgeCount, 0);
      expect(controller.stats.totalPoints, 0);
      for (final badge in controller.definitions) {
        expect(controller.progressTowards(badge), 0.0);
      }
    });
  });
}
