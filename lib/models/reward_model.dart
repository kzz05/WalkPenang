// ---------------------------------------------------------------------------
// reward_model.dart
// Module 5 — Reward & Achievement
// Use Case : UC530 View statistics dashboard
// FR       : FR-R04 Statistics Dashboard
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// A tourist's cumulative reward totals, read back from the fields Module 5
// increments on the tourist document.
//
// Also the input to badge evaluation (UC510): a badge unlocks when one of
// these totals crosses its threshold.
//
// None of these values are calculated here. Distance, carbon and calories are
// produced by Module 4 per check-in and only accumulated by Module 5.

import '../utils/reward_constants.dart';

class RewardModel {
  final String userId;

  /// Lifetime points balance (UC500). Drives the points badges.
  final int totalPoints;

  /// Number of completed check-ins. Drives the check-in count badges.
  final int totalCheckIns;

  /// Lifetime distance in whole metres. Drives the distance badges.
  ///
  /// Stored as an integer rather than a double of kilometres because these
  /// fields are accumulated with repeated increments, and accumulated
  /// floating point error would eventually decide a threshold comparison the
  /// wrong way at the boundary.
  final int totalDistanceMetres;

  /// Lifetime carbon saved, as reported by Module 4. Drives the Green
  /// Strider badge, which compares [totalCarbonSavedGrams].
  final double totalCarbonSavedKg;

  /// Lifetime calories burned, as reported by Module 4.
  final double totalCaloriesBurned;

  const RewardModel({
    required this.userId,
    this.totalPoints = 0,
    this.totalCheckIns = 0,
    this.totalDistanceMetres = 0,
    this.totalCarbonSavedKg = 0.0,
    this.totalCaloriesBurned = 0.0,
  });

  /// The empty state: a tourist who has never checked in. The dashboard shows
  /// zeroes and the badge gallery shows every badge locked.
  const RewardModel.empty(this.userId)
      : totalPoints = 0,
        totalCheckIns = 0,
        totalDistanceMetres = 0,
        totalCarbonSavedKg = 0.0,
        totalCaloriesBurned = 0.0;

  /// Distance for display. Storage stays in metres.
  double get totalDistanceKm =>
      RewardConstants.kmFromMetres(totalDistanceMetres);

  /// Carbon saved as whole grams, for the Green Strider threshold.
  ///
  /// Carbon is stored as a double of kilograms because that is what Module 4
  /// reports, but a badge comparison must not be decided by representation
  /// error, so the rule compares this integer instead.
  int get totalCarbonSavedGrams =>
      RewardConstants.gramsFromKg(totalCarbonSavedKg);

  bool get hasCheckIns => totalCheckIns > 0;

  /// Reads the cumulative fields off a tourist document.
  ///
  /// Every field defaults to zero: a tourist created by Module 1 has no
  /// reward fields at all until their first check-in, and that absence must
  /// read as the empty state rather than crash the dashboard.
  factory RewardModel.fromMap(String userId, Map<String, dynamic> map) {
    return RewardModel(
      userId: userId,
      totalPoints:
          (map[RewardConstants.totalPointsField] as num?)?.toInt() ?? 0,
      totalCheckIns:
          (map[RewardConstants.totalCheckInsField] as num?)?.toInt() ?? 0,
      totalDistanceMetres:
          (map[RewardConstants.totalDistanceMetresField] as num?)?.toInt() ?? 0,
      totalCarbonSavedKg:
          (map[RewardConstants.totalCarbonSavedKgField] as num?)?.toDouble() ??
              0.0,
      totalCaloriesBurned:
          (map[RewardConstants.totalCaloriesBurnedField] as num?)?.toDouble() ??
              0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      RewardConstants.totalPointsField: totalPoints,
      RewardConstants.totalCheckInsField: totalCheckIns,
      RewardConstants.totalDistanceMetresField: totalDistanceMetres,
      RewardConstants.totalCarbonSavedKgField: totalCarbonSavedKg,
      RewardConstants.totalCaloriesBurnedField: totalCaloriesBurned,
    };
  }

  @override
  String toString() => 'RewardModel(userId: $userId, points: $totalPoints, '
      'checkIns: $totalCheckIns, metres: $totalDistanceMetres)';
}
