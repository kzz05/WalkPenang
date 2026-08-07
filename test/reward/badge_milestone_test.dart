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

RewardModel stats({int checkIns = 0, int metres = 0}) {
  return RewardModel(
    userId: 'tourist_001',
    totalCheckIns: checkIns,
    totalDistanceMetres: metres,
  );
}

List<String> idsEarned(RewardModel from, {Set<String> already = const {}}) {
  return BadgeEvaluator.newlyEarned(stats: from, earnedBadgeIds: already)
      .map((badge) => badge.id)
      .toList();
}

void main() {
  group('threshold boundaries', () {
    test('nothing unlocks below the Explorer threshold', () {
      expect(idsEarned(stats(checkIns: 4)), isEmpty);
    });

    test('Explorer unlocks exactly on the 5th check-in', () {
      // The comparison is >=, so landing on the milestone earns it. Off-by-one
      // here would make the badge arrive a check-in late.
      expect(
        idsEarned(stats(checkIns: RewardConstants.explorerCheckIns)),
        [RewardConstants.explorerBadgeId],
      );
    });

    test('Explorer still qualifies past the threshold', () {
      expect(idsEarned(stats(checkIns: 6)), [RewardConstants.explorerBadgeId]);
    });

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

    test('all three can unlock together', () {
      final earned = idsEarned(stats(checkIns: 5, metres: 50000));

      expect(earned, hasLength(3));
      expect(earned, [
        RewardConstants.explorerBadgeId,
        RewardConstants.trailblazerBadgeId,
        RewardConstants.penangWandererBadgeId,
      ]);
    });

    test('results come back in gallery order', () {
      expect(
        idsEarned(stats(checkIns: 9, metres: 60000)),
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
        already: {RewardConstants.explorerBadgeId},
      );

      expect(earned, isEmpty);
    });

    test('holding one badge does not block another from unlocking', () {
      final earned = idsEarned(
        stats(checkIns: 12, metres: 11000),
        already: {RewardConstants.explorerBadgeId},
      );

      expect(earned, [RewardConstants.trailblazerBadgeId]);
    });

    test('holding every badge returns nothing', () {
      final earned = idsEarned(
        stats(checkIns: 99, metres: 99000),
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
    test('thresholds match the proposal', () {
      expect(BadgeCatalogue.explorer.threshold, 5);
      expect(BadgeCatalogue.trailblazer.thresholdKm, 10.0);
      expect(BadgeCatalogue.penangWanderer.thresholdKm, 50.0);
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
      final restored =
          BadgeModel.fromMap(BadgeCatalogue.trailblazer.toMap());

      expect(restored.id, BadgeCatalogue.trailblazer.id);
      expect(restored.criterion, BadgeCriterion.cumulativeDistance);
      expect(restored.threshold, RewardConstants.trailblazerMetres);
      expect(restored.hue, BadgeCatalogue.trailblazer.hue);
    });
  });
}
