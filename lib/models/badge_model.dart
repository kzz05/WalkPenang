// ---------------------------------------------------------------------------
// badge_model.dart
// Module 5 — Reward & Achievement
// Use Case : UC510 Unlock badges
// FR       : FR-R02 Badge Milestone System
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// A badge definition, the badge catalogue, and the rule that decides which of
// them a check-in has just unlocked.
//
// Pure Dart with no Flutter or Firestore import, so the milestone rule can be
// unit tested without a Firebase project.

import '../utils/reward_constants.dart';
import 'reward_model.dart';

/// Which cumulative total a badge is measured against (UC510, constraint C1).
enum BadgeCriterion {
  /// Number of completed check-ins.
  totalCheckIns,

  /// Cumulative distance walked, compared in whole metres.
  cumulativeDistance,

  /// Lifetime points balance, compared as a count of points.
  ///
  /// Points are already an integer produced by the points formula, so a
  /// milestone on them needs no unit conversion.
  totalPoints,

  /// Cumulative carbon saved, compared in whole grams.
  ///
  /// The total is stored as a double of kilograms because that is the unit
  /// Module 4 reports, but the comparison converts to grams first so that a
  /// threshold is never decided by accumulated floating point error.
  carbonSaved,
}

class BadgeModel {
  /// Document ID in the BADGES collection. Also the key the badge gallery
  /// uses to find the asset, so it must not change once tourists hold it.
  final String id;

  /// Display name, shown on the ribbon banner of the badge artwork.
  final String name;

  /// One-line explanation of how the badge is earned, shown on the badge
  /// detail screen (FR-R05).
  final String description;

  /// The total this badge is measured against.
  final BadgeCriterion criterion;

  /// The value the criterion must reach, in that criterion's own unit: a
  /// count of check-ins, a count of metres, a count of points, or a count of
  /// grams of carbon.
  final int threshold;

  /// Hand-authored SVG for this badge. Locked state is produced at render
  /// time by greyscaling this same asset, so there is only ever one file.
  final String assetPath;

  /// Badge hue as an int hex literal; views wrap it in Color(...).
  final int hue;

  const BadgeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.criterion,
    required this.threshold,
    required this.assetPath,
    required this.hue,
  });

  /// Whether [stats] meets this badge's threshold.
  ///
  /// The comparison is `>=` so that landing exactly on the milestone unlocks
  /// it: the 5th check-in earns Explorer, and 10.0 km earns Trailblazer.
  bool isEarnedBy(RewardModel stats) {
    switch (criterion) {
      case BadgeCriterion.totalCheckIns:
        return stats.totalCheckIns >= threshold;
      case BadgeCriterion.cumulativeDistance:
        return stats.totalDistanceMetres >= threshold;
      case BadgeCriterion.totalPoints:
        return stats.totalPoints >= threshold;
      case BadgeCriterion.carbonSaved:
        return stats.totalCarbonSavedGrams >= threshold;
    }
  }

  /// Threshold in the unit the badge detail screen displays.
  double get thresholdKm => RewardConstants.kmFromMetres(threshold);

  /// Threshold in kilograms, for a [BadgeCriterion.carbonSaved] badge.
  double get thresholdKg => RewardConstants.kgFromGrams(threshold);

  factory BadgeModel.fromMap(Map<String, dynamic> map) {
    return BadgeModel(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      criterion: BadgeCriterion.values.firstWhere(
        (c) => c.name == map['criterion'],
        orElse: () => BadgeCriterion.totalCheckIns,
      ),
      threshold: (map['threshold'] as num?)?.toInt() ?? 0,
      assetPath: map['assetPath'] as String? ?? '',
      hue: (map['hue'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'criterion': criterion.name,
      'threshold': threshold,
      'assetPath': assetPath,
      'hue': hue,
    };
  }

  @override
  String toString() => 'BadgeModel($id, $criterion >= $threshold)';
}

/// Every badge the gallery renders (UC510, constraint C1).
///
/// Held in code rather than read from Firestore because they are business
/// rules, not tourist data: a badge that quietly changed threshold would make
/// already-awarded badges inconsistent. The BADGES collection seeds from this
/// list so the gallery has something to read.
///
/// Explorer, Trailblazer and Penang Wanderer are the three fixed by the
/// submitted proposal and must keep their IDs and thresholds. The remaining
/// seven extend the set across the other totals the dashboard already tracks,
/// so that a tourist has a reachable next milestone at every stage rather
/// than a 40 km gap between the second badge and the third.
class BadgeCatalogue {
  BadgeCatalogue._();

  // --- Check-in count ------------------------------------------------------

  static const BadgeModel firstSteps = BadgeModel(
    id: RewardConstants.firstStepsBadgeId,
    name: 'First Steps',
    description: 'Complete your first check-in.',
    criterion: BadgeCriterion.totalCheckIns,
    threshold: RewardConstants.firstStepsCheckIns,
    assetPath: RewardConstants.firstStepsAsset,
    hue: RewardTokens.firstStepsHue,
  );

  static const BadgeModel explorer = BadgeModel(
    id: RewardConstants.explorerBadgeId,
    name: 'Explorer',
    description: 'Complete 5 check-ins.',
    criterion: BadgeCriterion.totalCheckIns,
    threshold: RewardConstants.explorerCheckIns,
    assetPath: RewardConstants.explorerAsset,
    hue: RewardTokens.explorerHue,
  );

  static const BadgeModel sightseer = BadgeModel(
    id: RewardConstants.sightseerBadgeId,
    name: 'Sightseer',
    description: 'Complete 15 check-ins.',
    criterion: BadgeCriterion.totalCheckIns,
    threshold: RewardConstants.sightseerCheckIns,
    assetPath: RewardConstants.sightseerAsset,
    hue: RewardTokens.sightseerHue,
  );

  static const BadgeModel pearlPathfinder = BadgeModel(
    id: RewardConstants.pearlPathfinderBadgeId,
    name: 'Pearl Pathfinder',
    description: 'Complete 30 check-ins.',
    criterion: BadgeCriterion.totalCheckIns,
    threshold: RewardConstants.pearlPathfinderCheckIns,
    assetPath: RewardConstants.pearlPathfinderAsset,
    hue: RewardTokens.pearlPathfinderHue,
  );

  // --- Cumulative distance -------------------------------------------------

  static const BadgeModel trailblazer = BadgeModel(
    id: RewardConstants.trailblazerBadgeId,
    name: 'Trailblazer',
    description: 'Walk 10 km in total.',
    criterion: BadgeCriterion.cumulativeDistance,
    threshold: RewardConstants.trailblazerMetres,
    assetPath: RewardConstants.trailblazerAsset,
    hue: RewardTokens.trailblazerHue,
  );

  static const BadgeModel penangWanderer = BadgeModel(
    id: RewardConstants.penangWandererBadgeId,
    name: 'Penang Wanderer',
    description: 'Walk 50 km in total.',
    criterion: BadgeCriterion.cumulativeDistance,
    threshold: RewardConstants.penangWandererMetres,
    assetPath: RewardConstants.penangWandererAsset,
    hue: RewardTokens.penangWandererHue,
  );

  static const BadgeModel centuryWalker = BadgeModel(
    id: RewardConstants.centuryWalkerBadgeId,
    name: 'Century Walker',
    description: 'Walk 100 km in total.',
    criterion: BadgeCriterion.cumulativeDistance,
    threshold: RewardConstants.centuryWalkerMetres,
    assetPath: RewardConstants.centuryWalkerAsset,
    hue: RewardTokens.centuryWalkerHue,
  );

  // --- Carbon saved --------------------------------------------------------

  static const BadgeModel greenStrider = BadgeModel(
    id: RewardConstants.greenStriderBadgeId,
    name: 'Green Strider',
    description: 'Save 5 kg of carbon by walking.',
    criterion: BadgeCriterion.carbonSaved,
    threshold: RewardConstants.greenStriderCarbonGrams,
    assetPath: RewardConstants.greenStriderAsset,
    hue: RewardTokens.greenStriderHue,
  );

  // --- Points balance ------------------------------------------------------

  static const BadgeModel pointCollector = BadgeModel(
    id: RewardConstants.pointCollectorBadgeId,
    name: 'Point Collector',
    description: 'Earn 500 points in total.',
    criterion: BadgeCriterion.totalPoints,
    threshold: RewardConstants.pointCollectorPoints,
    assetPath: RewardConstants.pointCollectorAsset,
    hue: RewardTokens.pointCollectorHue,
  );

  static const BadgeModel rewardLegend = BadgeModel(
    id: RewardConstants.rewardLegendBadgeId,
    name: 'Reward Legend',
    description: 'Earn 2,000 points in total.',
    criterion: BadgeCriterion.totalPoints,
    threshold: RewardConstants.rewardLegendPoints,
    assetPath: RewardConstants.rewardLegendAsset,
    hue: RewardTokens.rewardLegendHue,
  );

  /// Gallery order (FR-R05): grouped by criterion, easiest milestone first
  /// within each group.
  ///
  /// Grouping rather than interleaving by difficulty is deliberate — a
  /// tourist scanning the grid can see at once that there are four ways to
  /// earn, instead of a single ladder whose rungs change unit without
  /// warning. [BadgeEvaluator] returns newly-earned badges in this order, and
  /// [FirestoreBadgeDao.fetchDefinitions] sorts the collection back into it.
  static const List<BadgeModel> all = [
    firstSteps,
    explorer,
    sightseer,
    pearlPathfinder,
    trailblazer,
    penangWanderer,
    centuryWalker,
    greenStrider,
    pointCollector,
    rewardLegend,
  ];

  static BadgeModel? byId(String id) {
    for (final badge in all) {
      if (badge.id == id) return badge;
    }
    return null;
  }
}

/// The milestone rule (T-R02.2).
class BadgeEvaluator {
  BadgeEvaluator._();

  /// Badges that [stats] now qualifies for and the tourist does not already
  /// hold, in gallery order.
  ///
  /// Returns all of them, not just the first: a single long check-in can push
  /// a tourist past two thresholds at once, and UC510 awards both.
  ///
  /// [earnedBadgeIds] are the badges already held. Filtering on it here is
  /// what stops a badge being re-awarded on every subsequent check-in, since
  /// a total that has crossed a threshold stays across it forever.
  static List<BadgeModel> newlyEarned({
    required RewardModel stats,
    required Set<String> earnedBadgeIds,
  }) {
    return BadgeCatalogue.all
        .where((badge) =>
            !earnedBadgeIds.contains(badge.id) && badge.isEarnedBy(stats))
        .toList(growable: false);
  }
}
