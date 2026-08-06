// ---------------------------------------------------------------------------
// check_in_result.dart
// Module 5 — Reward & Achievement
// Use Case : UC500 Earn points from activities
// FR       : FR-R01 Points Award System
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// The boundary object between Module 4 (Walking & Carbon) and Module 5.
//
// Module 5 begins at "receive verified check-in data". Every value here has
// already been produced by Module 4: the arrival radius was checked against
// FR-W05, and distance, carbon and calories were calculated there. Module 5
// consumes them and must never recompute or re-verify any of them.

import '../utils/reward_constants.dart';

class CheckInResult {
  /// Firestore document ID of the verified check-in.
  ///
  /// Doubles as the idempotency key: the points ledger entry is written under
  /// this ID, so a retried award overwrites rather than appends (T-R01.5).
  final String checkInId;

  /// The tourist who checked in. Supplied by Module 1 via Module 4.
  final String userId;

  /// The attraction checked into, from Module 2's catalogue.
  final String destinationId;

  /// Distance walked for this check-in, as calculated by Module 4.
  final double distanceKm;

  /// Carbon saved versus driving the same distance, as calculated by Module 4.
  final double carbonSavedKg;

  /// Calories burned, as calculated by Module 4.
  final double caloriesBurned;

  /// When the check-in was verified.
  final DateTime checkInTime;

  const CheckInResult({
    required this.checkInId,
    required this.userId,
    required this.destinationId,
    required this.distanceKm,
    required this.carbonSavedKg,
    required this.caloriesBurned,
    required this.checkInTime,
  });

  /// Distance in whole metres.
  ///
  /// The points formula and the badge thresholds both work in integer metres
  /// so that binary floating point cannot shift a result across a boundary.
  int get distanceMetres => RewardConstants.metresFromKm(distanceKm);

  factory CheckInResult.fromMap(Map<String, dynamic> map) {
    return CheckInResult(
      checkInId: map['checkInId'] as String,
      userId: map['userId'] as String,
      destinationId: map['destinationId'] as String? ?? '',
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0.0,
      carbonSavedKg: (map['carbonSavedKg'] as num?)?.toDouble() ?? 0.0,
      caloriesBurned: (map['caloriesBurned'] as num?)?.toDouble() ?? 0.0,
      checkInTime: map['checkInTime'] as DateTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'checkInId': checkInId,
      'userId': userId,
      'destinationId': destinationId,
      'distanceKm': distanceKm,
      'carbonSavedKg': carbonSavedKg,
      'caloriesBurned': caloriesBurned,
      'checkInTime': checkInTime,
    };
  }

  @override
  String toString() =>
      'CheckInResult(checkInId: $checkInId, userId: $userId, '
      'distanceKm: $distanceKm)';
}
