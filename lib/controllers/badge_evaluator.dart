// ---------------------------------------------------------------------------
// badge_evaluator.dart
// Module 5 — Reward & Achievement
// Use Case : UC510 Unlock badges
// FR       : FR-R02 Badge Unlock Logic
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// Decides which badges a tourist has newly qualified for. Pure Dart: the
// definition list is passed in as a parameter rather than fetched, so this
// class has no Firestore dependency and its tests construct definitions inline.
//
// Persisting an unlocked badge is T-R02.3 and belongs to BadgeDao, not here.
// This class only decides; it never writes.

import 'package:walkpenang/models/badge_model.dart';
import 'package:walkpenang/models/reward_model.dart';

class BadgeEvaluator {
  const BadgeEvaluator._();

  /// Badges the tourist qualifies for but does not yet hold.
  ///
  /// UC510 basic flow steps 2 and 3. Returns an empty list when no milestone is
  /// met, which is alternate flow A1 — the use case ends silently rather than
  /// raising anything.
  ///
  /// A single check-in can cross more than one threshold at once (a long first
  /// walk can satisfy both distance badges), so every qualifying definition is
  /// returned, not just the first match.
  ///
  /// Results are ordered by ascending threshold so the UI presents multiple
  /// unlocks in the order the tourist earned them.
  static List<BadgeModel> evaluate({
    required RewardModel stats,
    required List<BadgeModel> definitions,
    required Set<String> alreadyEarnedBadgeIds,
  }) {
    final List<BadgeModel> unlocked = <BadgeModel>[];

    for (final BadgeModel definition in definitions) {
      if (alreadyEarnedBadgeIds.contains(definition.id)) {
        continue;
      }
      if (_isSatisfied(stats, definition)) {
        unlocked.add(definition);
      }
    }

    unlocked.sort(
      (BadgeModel a, BadgeModel b) => a.threshold.compareTo(b.threshold),
    );
    return unlocked;
  }

  static bool _isSatisfied(RewardModel stats, BadgeModel definition) {
    switch (definition.criterion) {
      case BadgeCriterion.checkIns:
        return stats.totalCheckIns >= definition.threshold;

      case BadgeCriterion.distanceKm:
        // Compared in whole metres for the same reason the points bonus is:
        // a cumulative total built by repeatedly adding doubles can land at
        // 9.999999999999998 after walks that sum to exactly 10 km, which would
        // wrongly withhold the badge at the threshold.
        final int walkedMetres = (stats.totalDistanceKm * 1000).round();
        final int requiredMetres = (definition.threshold * 1000).round();
        return walkedMetres >= requiredMetres;

      case BadgeCriterion.unknown:
        // A criterion string that did not parse is never satisfied, so bad
        // seed data withholds a badge rather than awarding it to everyone.
        return false;
    }
  }
}
