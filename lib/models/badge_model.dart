// ---------------------------------------------------------------------------
// badge_model.dart
// Module 5 — Reward & Achievement
// Use Case : UC510 Unlock badges
// FR       : FR-R02 Badge Unlock Logic
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// A badge *definition* — the milestone rule, not an earned instance. Earned
// instances are UserBadgeModel.
//
// Definitions are data loaded from the badges collection, never hard-coded
// branches, so adding a fourth badge is a Firestore change with no code change.

import 'package:walkpenang/utils/reward_constants.dart';

/// The cumulative statistic a badge is measured against.
enum BadgeCriterion {
  /// Total number of completed check-ins.
  checkIns,

  /// Cumulative distance walked, in kilometres.
  distanceKm,

  /// Criterion string in Firestore did not match a known value. Treated as
  /// never satisfied so that a typo in seed data cannot silently award badges.
  unknown,
}

BadgeCriterion badgeCriterionFromString(String? raw) {
  switch (raw) {
    case kCriterionCheckIns:
      return BadgeCriterion.checkIns;
    case kCriterionDistanceKm:
      return BadgeCriterion.distanceKm;
    default:
      return BadgeCriterion.unknown;
  }
}

String badgeCriterionToString(BadgeCriterion criterion) {
  switch (criterion) {
    case BadgeCriterion.checkIns:
      return kCriterionCheckIns;
    case BadgeCriterion.distanceKm:
      return kCriterionDistanceKm;
    case BadgeCriterion.unknown:
      return 'unknown';
  }
}

class BadgeModel {
  /// Document ID in the badges collection. Also used as the document ID of the
  /// earned record, which is what makes a double unlock structurally
  /// impossible.
  final String id;

  final String name;
  final String description;
  final BadgeCriterion criterion;

  /// Value the criterion must reach. Check-in thresholds are whole numbers;
  /// distance thresholds are in kilometres.
  final num threshold;

  /// Path to the SVG asset. Produced in T-R05.5.
  final String iconAsset;

  const BadgeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.criterion,
    required this.threshold,
    required this.iconAsset,
  });

  factory BadgeModel.fromMap(String id, Map<String, dynamic> map) {
    return BadgeModel(
      id: id,
      name: map[kFieldBadgeName] as String? ?? '',
      description: map[kFieldBadgeDescription] as String? ?? '',
      criterion: badgeCriterionFromString(map[kFieldBadgeCriterion] as String?),
      threshold: map[kFieldBadgeThreshold] is num
          ? map[kFieldBadgeThreshold] as num
          : 0,
      iconAsset: map[kFieldBadgeIconAsset] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        kFieldBadgeName: name,
        kFieldBadgeDescription: description,
        kFieldBadgeCriterion: badgeCriterionToString(criterion),
        kFieldBadgeThreshold: threshold,
        kFieldBadgeIconAsset: iconAsset,
      };

  /// Builds the three seed definitions from [kBadgeSeedData].
  ///
  /// Used by the one-off seeding routine, and by tests that need a realistic
  /// definition set without touching Firestore.
  static List<BadgeModel> seedDefinitions() {
    return kBadgeSeedData
        .map((Map<String, dynamic> row) =>
            BadgeModel.fromMap(row['id'] as String, row))
        .toList(growable: false);
  }

  @override
  String toString() => 'BadgeModel($id, $name, '
      '${badgeCriterionToString(criterion)} >= $threshold)';
}
