// ---------------------------------------------------------------------------
// reward_model.dart
// Module 5 — Reward & Achievement
// Use Case : UC530 View statistics dashboard
// FR       : FR-R04 Cumulative Statistics Dashboard
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// Cumulative reward totals for one tourist, mirroring the fields stored on
// users/{uid}. Pure Dart: serialises to and from Map<String, dynamic> so the
// DAO owns all Firestore type handling.

import 'package:walkpenang/utils/reward_constants.dart';

class RewardModel {
  final int totalPoints;
  final int totalCheckIns;
  final double totalDistanceKm;
  final double totalCarbonSavedKg;
  final double totalCaloriesBurned;

  const RewardModel({
    this.totalPoints = 0,
    this.totalCheckIns = 0,
    this.totalDistanceKm = 0.0,
    this.totalCarbonSavedKg = 0.0,
    this.totalCaloriesBurned = 0.0,
  });

  /// Totals for a tourist with no completed check-ins.
  ///
  /// UC530 alternate flow A1 displays every figure as zero rather than an
  /// error, so the absence of a user document is a valid state, not a failure.
  static const RewardModel empty = RewardModel();

  factory RewardModel.fromMap(Map<String, dynamic> map) {
    return RewardModel(
      totalPoints: _toInt(map[kFieldTotalPoints]),
      totalCheckIns: _toInt(map[kFieldTotalCheckIns]),
      totalDistanceKm: _toDouble(map[kFieldTotalDistanceKm]),
      totalCarbonSavedKg: _toDouble(map[kFieldTotalCarbonSavedKg]),
      totalCaloriesBurned: _toDouble(map[kFieldTotalCaloriesBurned]),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        kFieldTotalPoints: totalPoints,
        kFieldTotalCheckIns: totalCheckIns,
        kFieldTotalDistanceKm: totalDistanceKm,
        kFieldTotalCarbonSavedKg: totalCarbonSavedKg,
        kFieldTotalCaloriesBurned: totalCaloriesBurned,
      };

  RewardModel copyWith({
    int? totalPoints,
    int? totalCheckIns,
    double? totalDistanceKm,
    double? totalCarbonSavedKg,
    double? totalCaloriesBurned,
  }) {
    return RewardModel(
      totalPoints: totalPoints ?? this.totalPoints,
      totalCheckIns: totalCheckIns ?? this.totalCheckIns,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      totalCarbonSavedKg: totalCarbonSavedKg ?? this.totalCarbonSavedKg,
      totalCaloriesBurned: totalCaloriesBurned ?? this.totalCaloriesBurned,
    );
  }

  /// Firestore returns a whole number as int even for a field declared double,
  /// so a direct `as double` cast throws in production but not in tests.
  static double _toDouble(Object? value) =>
      value is num ? value.toDouble() : 0.0;

  static int _toInt(Object? value) => value is num ? value.toInt() : 0;

  @override
  String toString() => 'RewardModel(points: $totalPoints, '
      'checkIns: $totalCheckIns, distance: ${totalDistanceKm}km)';
}
