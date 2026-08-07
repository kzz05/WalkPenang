// ---------------------------------------------------------------------------
// reward_dao.dart
// Module 5 — Reward & Achievement
// Use Case : UC500 Earn points from activities, UC530 View statistics dashboard
// FR       : FR-R01 Points Award System, FR-R04 Cumulative Statistics Dashboard
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// Data access for points and cumulative totals.
//
// The abstract class is the contract controllers depend on. Firestore types
// appear only in the implementation below, so controller and evaluator tests
// run against an in-memory fake with no Firebase project.

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:walkpenang/models/reward_model.dart';
import 'package:walkpenang/utils/reward_constants.dart';

abstract class RewardDao {
  /// Current cumulative totals for [userId].
  ///
  /// Returns [RewardModel.empty] when the tourist has no user document or no
  /// reward fields yet, because UC530 alternate flow A1 treats that as a valid
  /// zero state rather than an error.
  Future<RewardModel> fetchStats(String userId);

  /// Live totals for [userId].
  ///
  /// UC530 constraint C1 requires the dashboard to refresh whenever a new
  /// check-in is recorded.
  Stream<RewardModel> watchStats(String userId);

  /// Awards points for one verified check-in and advances the cumulative
  /// totals.
  ///
  /// Returns true when the award was applied, false when this [checkInId] had
  /// already been rewarded. The caller uses the result to decide whether to
  /// show the points confirmation message.
  ///
  /// Idempotency is structural: the ledger document ID is the check-in ID, so
  /// a retried or duplicated call finds the entry already present and makes no
  /// further change.
  Future<bool> awardPointsForCheckIn({
    required String userId,
    required String checkInId,
    required int pointsAwarded,
    required double distanceKm,
    required double carbonSavedKg,
    required double caloriesBurned,
  });
}

class FirestoreRewardDao implements RewardDao {
  final FirebaseFirestore _firestore;

  FirestoreRewardDao({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userRef(String userId) =>
      _firestore.collection(kUsersCollection).doc(userId);

  DocumentReference<Map<String, dynamic>> _ledgerRef(
    String userId,
    String checkInId,
  ) =>
      _userRef(userId).collection(kPointsLedgerSubcollection).doc(checkInId);

  @override
  Future<RewardModel> fetchStats(String userId) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _userRef(userId).get();
    final Map<String, dynamic>? data = snapshot.data();
    if (data == null) {
      return RewardModel.empty;
    }
    return RewardModel.fromMap(data);
  }

  @override
  Stream<RewardModel> watchStats(String userId) {
    return _userRef(userId).snapshots().map(
      (DocumentSnapshot<Map<String, dynamic>> snapshot) {
        final Map<String, dynamic>? data = snapshot.data();
        return data == null ? RewardModel.empty : RewardModel.fromMap(data);
      },
    );
  }

  @override
  Future<bool> awardPointsForCheckIn({
    required String userId,
    required String checkInId,
    required int pointsAwarded,
    required double distanceKm,
    required double carbonSavedKg,
    required double caloriesBurned,
  }) {
    // A transaction rather than a plain write, so the existence check and the
    // increment cannot interleave with a concurrent award for the same
    // check-in.
    return _firestore.runTransaction<bool>((Transaction transaction) async {
      final DocumentReference<Map<String, dynamic>> ledger =
          _ledgerRef(userId, checkInId);

      final DocumentSnapshot<Map<String, dynamic>> existing =
          await transaction.get(ledger);
      if (existing.exists) {
        return false;
      }

      transaction.set(ledger, <String, dynamic>{
        kFieldPointsAwarded: pointsAwarded,
        kFieldDistanceKm: distanceKm,
        kFieldCarbonSavedKg: carbonSavedKg,
        kFieldCaloriesBurned: caloriesBurned,
        kFieldAwardedAt: FieldValue.serverTimestamp(),
      });

      // Atomic increments rather than read-then-write, so two check-ins
      // completing close together cannot overwrite one another's totals.
      // merge:true creates the user document if Module 1 has not yet written
      // one.
      transaction.set(
        _userRef(userId),
        <String, dynamic>{
          kFieldTotalPoints: FieldValue.increment(pointsAwarded),
          kFieldTotalCheckIns: FieldValue.increment(1),
          kFieldTotalDistanceKm: FieldValue.increment(distanceKm),
          kFieldTotalCarbonSavedKg: FieldValue.increment(carbonSavedKg),
          kFieldTotalCaloriesBurned: FieldValue.increment(caloriesBurned),
        },
        SetOptions(merge: true),
      );

      return true;
    });
  }
}
