// ---------------------------------------------------------------------------
// points_calculator.dart
// Module 5 — Reward & Achievement
// Use Case : UC500 Earn points from activities
// FR       : FR-R01 Points Award System
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// Implements the points formula from UC500 constraint C1. Pure Dart with no
// Flutter or Firestore import, so it is fully unit testable without a Firebase
// project or platform scaffolding.
//
// This class never derives distance itself. Distance arrives already computed
// from the Walking & Carbon Module; deriving it here would cross the module
// boundary.

import 'package:walkpenang/utils/reward_constants.dart';

class PointsCalculator {
  const PointsCalculator._();

  /// Points earned for one verified check-in of [distanceKm] kilometres.
  ///
  /// UC500 C1: 10 points per completed check-in, plus 1 point per 0.1 km
  /// walked, rounded down.
  ///
  /// The bonus is derived from whole metres rather than from the kilometre
  /// double. Multiplying first is unsafe because 1.3 * 10 evaluates to
  /// 12.999999999999998 in IEEE-754 and floors to 12 instead of the intended
  /// 13. Rounding to metres collapses that representation error before any
  /// truncation happens.
  ///
  /// A non-finite or non-positive distance still earns the flat check-in
  /// award, because arrival was verified by Module 4 regardless of what the
  /// distance figure looks like. It never produces a negative total.
  static int pointsForCheckIn(double distanceKm) {
    return kPointsPerCheckIn + distanceBonus(distanceKm);
  }

  /// The distance component of the award, in isolation.
  ///
  /// Exposed separately so the confirmation message in T-R01.4 can show the
  /// breakdown without recomputing it.
  static int distanceBonus(double distanceKm) {
    if (!distanceKm.isFinite || distanceKm <= 0) {
      return 0;
    }
    final int metres = (distanceKm * 1000).round();
    return metres ~/ kMetresPerBonusPoint;
  }
}
