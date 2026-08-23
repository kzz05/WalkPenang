// ---------------------------------------------------------------------------
// badge_milestone_test.dart
// Module 5 — Reward & Achievement
// Use Case : UC510 Unlock badges
// FR       : FR-R02 Badge Milestone System
// Task     : T-R02.5 Badge evaluation unit tests
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// BadgeEvaluator is a pure function over RewardModel, so these run with no
// Flutter binding and no Firebase project.

import 'package:test/test.dart';
import 'package:walkpenang/models/badge_model.dart';
import 'package:walkpenang/models/reward_model.dart';
import 'package:walkpenang/utils/reward_constants.dart';

RewardModel stats({
  int checkIns = 0,
  int metres = 0,
  int points = 0,
  double carbonKg = 0,
}) {
  return RewardModel(
    userId: 'tourist_001',
    totalCheckIns: checkIns,
    totalDistanceMetres: metres,
    totalPoints: points,
    totalCarbonSavedKg: carbonKg,
  );
}

List<String> idsEarned(RewardModel from, {Set<String> already = const {}}) {
  return BadgeEvaluator.newlyEarned(stats: from, earnedBadgeIds: already)
      .map((badge) => badge.id)
      .toList();
}

/// The two check-in badges below Sightseer, as a tourist past them would hold
/// them. Named once so a test about a later milestone is not obscured by the
/// earlier ones it has to exclude.
const _belowSightseer = {
  RewardConstants.firstStepsBadgeId,
  RewardConstants.explorerBadgeId,
};

void main() {
  group('check-in count boundaries', () {
    test('nothing unlocks before the first check-in', () {
      expect(idsEarned(stats(checkIns: 0)), isEmpty);
    });

    test('First Steps unlocks on the very first check-in', () {
      expect(
        idsEarned(stats(checkIns: RewardConstants.firstStepsCheckIns)),
        [RewardConstants.firstStepsBadgeId],
      );
    });

    test('nothing new unlocks between First Steps and Explorer', () {
      expect(
        idsEarned(
          stats(checkIns: 4),
          already: {RewardConstants.firstStepsBadgeId},
        ),
        isEmpty,
      );
    });

    test('Explorer unlocks exactly on the 5th check-in', () {
      // The comparison is >=, so landing on the milestone earns it. Off-by-one
      // here would make the badge arrive a check-in late.
      expect(
        idsEarned(
          stats(checkIns: RewardConstants.explorerCheckIns),
          already: {RewardConstants.firstStepsBadgeId},
        ),
        [RewardConstants.explorerBadgeId],
      );
    });

    test('Explorer still qualifies past the threshold', () {
      expect(
        idsEarned(
          stats(checkIns: 6),
          already: {RewardConstants.firstStepsBadgeId},
        ),
        [RewardConstants.explorerBadgeId],
      );
    });

    test('Sightseer unlocks exactly at 15 check-ins', () {
      expect(
        idsEarned(
          stats(checkIns: RewardConstants.sightseerCheckIns),
          already: _belowSightseer,
        ),
        [RewardConstants.sightseerBadgeId],
      );
    });

    test('Sightseer does not unlock one check-in short', () {
      expect(
        idsEarned(
          stats(checkIns: RewardConstants.sightseerCheckIns - 1),
          already: _belowSightseer,
        ),
        isEmpty,
      );
    });

    test('Pearl Pathfinder unlocks exactly at 30 check-ins', () {
      expect(
        idsEarned(
          stats(checkIns: RewardConstants.pearlPathfinderCheckIns),
          already: {..._belowSightseer, RewardConstants.sightseerBadgeId},
        ),
        [RewardConstants.pearlPathfinderBadgeId],
      );
    });
  });

  group('distance boundaries', () {
    test('Trailblazer unlocks exactly at 10 km', () {
      expect(
        idsEarned(stats(metres: RewardConstants.trailblazerMetres)),
        [RewardConstants.trailblazerBadgeId],
      );
    });

    test('Trailblazer does not unlock one metre short', () {
      // Distance is compared in whole metres precisely so that a boundary this
      // tight cannot be decided by floating point representation error.
      expect(
        idsEarned(stats(metres: RewardConstants.trailblazerMetres - 1)),
        isEmpty,
      );
    });

    test('Penang Wanderer unlocks exactly at 50 km', () {
      expect(
        idsEarned(stats(metres: RewardConstants.penangWandererMetres)),
        contains(RewardConstants.penangWandererBadgeId),
      );
    });

    test('Century Walker unlocks exactly at 100 km', () {
      expect(
        idsEarned(stats(metres: RewardConstants.centuryWalkerMetres)),
        contains(RewardConstants.centuryWalkerBadgeId),
      );
    });

    test('Century Walker does not unlock one metre short', () {
      expect(
        idsEarned(
          stats(metres: RewardConstants.centuryWalkerMetres - 1),
          already: {
            RewardConstants.trailblazerBadgeId,
            RewardConstants.penangWandererBadgeId,
          },
        ),
        isEmpty,
      );
    });
  });

  group('points boundaries', () {
    test('Point Collector unlocks exactly at 500 points', () {
      expect(
        idsEarned(stats(points: RewardConstants.pointCollectorPoints)),
        [RewardConstants.pointCollectorBadgeId],
      );
    });

    test('Point Collector does not unlock one point short', () {
      expect(
        idsEarned(stats(points: RewardConstants.pointCollectorPoints - 1)),
        isEmpty,
      );
    });

    test('Reward Legend unlocks at 2,000 points', () {
      // A balance that high has necessarily passed 500 as well, so both come
      // back at once for a tourist holding neither.
      expect(idsEarned(stats(points: RewardConstants.rewardLegendPoints)), [
        RewardConstants.pointCollectorBadgeId,
        RewardConstants.rewardLegendBadgeId,
      ]);
    });
  });

  group('carbon boundaries', () {
    test('Green Strider unlocks exactly at 5 kg saved', () {
      expect(
        idsEarned(stats(carbonKg: 5.0)),
        [RewardConstants.greenStriderBadgeId],
      );
    });

    test('Green Strider does not unlock just under 5 kg', () {
      // 4.999 kg rounds to 4,999 g — one gram short of the milestone.
      expect(idsEarned(stats(carbonKg: 4.999)), isEmpty);
    });

    test('carbon is compared in whole grams, not as a float', () {
      // 0.21 kg/km over 23.81 km is 5.000100000000001 kg in binary. Rounding
      // to grams is what makes the comparison land on the milestone instead of
      // being decided by which side of 5.0 the accumulated double fell.
      final tourist = stats(carbonKg: 0.21 * 23.81);

      expect(
        tourist.totalCarbonSavedGrams,
        RewardConstants.greenStriderCarbonGrams,
      );
      expect(
        idsEarned(tourist),
        contains(RewardConstants.greenStriderBadgeId),
      );
    });
  });

  group('multiple badges from one check-in', () {
    test('crossing two distance thresholds at once returns both', () {
      // A single very long check-in can pass 10 km and 50 km together. UC510
      // awards both, so returning only the first would silently lose one.
      final earned = idsEarned(stats(metres: 52000));

      expect(earned, [
        RewardConstants.trailblazerBadgeId,
        RewardConstants.penangWandererBadgeId,
      ]);
    });

    test('milestones on different criteria unlock together', () {
      final earned = idsEarned(stats(checkIns: 5, metres: 50000, points: 600));

      expect(earned, [
        RewardConstants.firstStepsBadgeId,
        RewardConstants.explorerBadgeId,
        RewardConstants.trailblazerBadgeId,
        RewardConstants.penangWandererBadgeId,
        RewardConstants.pointCollectorBadgeId,
      ]);
    });

    test('results come back in gallery order', () {
      // Totals past every threshold, so the result is the whole catalogue and
      // any drift in BadgeCatalogue.all's ordering shows up here.
      expect(
        idsEarned(
          stats(checkIns: 40, metres: 120000, points: 3000, carbonKg: 9),
        ),
        BadgeCatalogue.all.map((badge) => badge.id).toList(),
      );
    });
  });

  group('already-held badges', () {
    test('a badge already earned is never returned again', () {
      // Totals only ever grow, so a crossed threshold stays crossed. Without
      // this filter Explorer would re-award on every check-in after the 5th.
      final earned = idsEarned(
        stats(checkIns: 20),
        already: {..._belowSightseer, RewardConstants.sightseerBadgeId},
      );

      expect(earned, isEmpty);
    });

    test('holding one badge does not block another from unlocking', () {
      final earned = idsEarned(
        stats(checkIns: 12, metres: 11000),
        already: _belowSightseer,
      );

      expect(earned, [RewardConstants.trailblazerBadgeId]);
    });

    test('holding every badge returns nothing', () {
      final earned = idsEarned(
        stats(checkIns: 99, metres: 99000, points: 9999, carbonKg: 99),
        already: BadgeCatalogue.all.map((badge) => badge.id).toSet(),
      );

      expect(earned, isEmpty);
    });
  });

  group('empty state', () {
    test('a tourist with no check-ins unlocks nothing', () {
      expect(idsEarned(const RewardModel.empty('tourist_001')), isEmpty);
    });
  });

  group('badge definitions', () {
    test('the proposal thresholds are unchanged', () {
      // These three are fixed by the submitted proposal. The badges added
      // around them must never move these numbers.
      expect(BadgeCatalogue.explorer.threshold, 5);
      expect(BadgeCatalogue.trailblazer.thresholdKm, 10.0);
      expect(BadgeCatalogue.penangWanderer.thresholdKm, 50.0);
    });

    test('the added thresholds read back in their display units', () {
      expect(BadgeCatalogue.firstSteps.threshold, 1);
      expect(BadgeCatalogue.sightseer.threshold, 15);
      expect(BadgeCatalogue.pearlPathfinder.threshold, 30);
      expect(BadgeCatalogue.centuryWalker.thresholdKm, 100.0);
      expect(BadgeCatalogue.greenStrider.thresholdKg, 5.0);
      expect(BadgeCatalogue.pointCollector.threshold, 500);
      expect(BadgeCatalogue.rewardLegend.threshold, 2000);
    });

    test('every badge ID is unique', () {
      // IDs are Firestore document IDs and the key an earned badge is stored
      // under, so a duplicate would make two badges share one unlock.
      final ids = BadgeCatalogue.all.map((badge) => badge.id).toSet();

      expect(ids, hasLength(BadgeCatalogue.all.length));
    });

    test('byId round-trips every catalogue entry', () {
      for (final badge in BadgeCatalogue.all) {
        expect(BadgeCatalogue.byId(badge.id), same(badge));
      }
      expect(BadgeCatalogue.byId('not_a_badge'), isNull);
    });

    test('a definition survives a map round trip', () {
      // The gallery reads definitions out of Firestore, so a criterion that
      // did not survive serialisation would silently evaluate as check-ins.
      final restored = BadgeModel.fromMap(BadgeCatalogue.trailblazer.toMap());

      expect(restored.id, BadgeCatalogue.trailblazer.id);
      expect(restored.criterion, BadgeCriterion.cumulativeDistance);
      expect(restored.threshold, RewardConstants.trailblazerMetres);
      expect(restored.hue, BadgeCatalogue.trailblazer.hue);
    });

    test('every criterion survives a map round trip', () {
      // fromMap falls back to totalCheckIns when it cannot match the stored
      // name. A points or carbon badge that failed to serialise would come
      // back looking like a check-in badge with a nonsense threshold, and the
      // gallery would show it as unreachable rather than error.
      for (final badge in BadgeCatalogue.all) {
        final restored = BadgeModel.fromMap(badge.toMap());

        expect(restored.criterion, badge.criterion, reason: badge.id);
        expect(restored.threshold, badge.threshold, reason: badge.id);
      }
    });
  });
}
