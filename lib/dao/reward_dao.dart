// ---------------------------------------------------------------------------
// reward_dao.dart
// Module 5 — Reward & Achievement
// Use Case : UC500 Earn points from activities
// FR       : FR-R01 Points Award System
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// All Firestore reads and writes for the tourist's points balance and
// cumulative totals.
//
// The contract is declared as an abstract class so the controller depends on
// the abstraction and tests can substitute a fake with no Firebase project.
// Firestore types appear only in the implementation below.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/check_in_result.dart';
import '../models/reward_model.dart';
import '../utils/reward_constants.dart';

/// Points and cumulative totals for one tourist.
abstract class RewardDao {
  /// The tourist's cumulative totals, used by the statistics dashboard and as
  /// the input to badge evaluation.
  ///
  /// A tourist with no check-ins yet returns [RewardModel.empty] rather than
  /// throwing: Module 1 creates the tourist document without reward fields.
  Future<RewardModel> fetchRewardSummary(String userId);

  /// Whether this check-in has already been rewarded.
  Future<bool> isCheckInRewarded(String checkInId);

  /// Awards [points] for [result] and adds its distance, carbon and calories
  /// to the tourist's cumulative totals.
  ///
  /// Returns true when the award was made, false when this check-in had
  /// already been rewarded and nothing was written.
  ///
  /// Must be idempotent: calling it twice with the same
  /// [CheckInResult.checkInId] awards once (T-R01.5).
  Future<bool> awardForCheckIn({
    required CheckInResult result,
    required int points,
  });
}

/// Firestore-backed implementation.
class FirestoreRewardDao implements RewardDao {
  final FirebaseFirestore _firestore;

  /// [firestore] is injected so tests can pass a fake instance.
  FirestoreRewardDao({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userRef(String userId) =>
      _firestore.collection(RewardConstants.usersCollection).doc(userId);

  DocumentReference<Map<String, dynamic>> _ledgerRef(String checkInId) =>
      _firestore
          .collection(RewardConstants.pointsLedgerCollection)
          .doc(checkInId);

  DocumentReference<Map<String, dynamic>> _checkInRef(String checkInId) =>
      _firestore.collection(RewardConstants.checkInsCollection).doc(checkInId);

  @override
  Future<RewardModel> fetchRewardSummary(String userId) async {
    final snapshot = await _userRef(userId).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      return RewardModel.empty(userId);
    }
    return RewardModel.fromMap(userId, data);
  }

  @override
  Future<bool> isCheckInRewarded(String checkInId) async {
    final ledger = await _ledgerRef(checkInId).get();
    if (ledger.exists) return true;

    // Second guard: Module 4's check-in document carries a rewardProcessed
    // flag. Both are checked because either write could be the one that
    // survived if the app was killed part-way through an earlier award.
    final checkIn = await _checkInRef(checkInId).get();
    return checkIn.data()?[RewardConstants.checkInRewardProcessedField] == true;
  }

  @override
  Future<bool> awardForCheckIn({
    required CheckInResult result,
    required int points,
  }) {
    final ledgerRef = _ledgerRef(result.checkInId);
    final userRef = _userRef(result.userId);
    final checkInRef = _checkInRef(result.checkInId);

    // The ledger entry is keyed by check-in ID, so its existence is the record
    // of "already rewarded". The existence check and the writes run in one
    // transaction because the cumulative increments are not themselves
    // idempotent: without the transaction, two calls racing on the same
    // check-in could both pass the check and both increment.
    return _firestore.runTransaction<bool>((transaction) async {
      // Firestore requires every read in a transaction to happen before any
      // write, so all three documents are fetched up front.
      final ledgerSnapshot = await transaction.get(ledgerRef);
      if (ledgerSnapshot.exists) return false;

      final checkInSnapshot = await transaction.get(checkInRef);
      final alreadyProcessed = checkInSnapshot
              .data()?[RewardConstants.checkInRewardProcessedField] ==
          true;
      if (alreadyProcessed) return false;

      final userSnapshot = await transaction.get(userRef);

      transaction.set(ledgerRef, {
        RewardConstants.ledgerUserIdField: result.userId,
        RewardConstants.ledgerCheckInIdField: result.checkInId,
        RewardConstants.ledgerPointsAwardedField: points,
        RewardConstants.ledgerDistanceMetresField: result.distanceMetres,
        RewardConstants.ledgerAwardedAtField: FieldValue.serverTimestamp(),
      });

      if (userSnapshot.exists) {
        // Increment rather than read-then-write, so two check-ins completing
        // at the same moment cannot clobber each other's totals. update()
        // touches only the named fields, leaving Module 1's profile fields
        // alone, and increment treats a field that does not exist yet as
        // zero — which is the normal case on a tourist's first check-in.
        transaction.update(userRef, {
          RewardConstants.totalPointsField: FieldValue.increment(points),
          RewardConstants.totalCheckInsField: FieldValue.increment(1),
          RewardConstants.totalDistanceMetresField:
              FieldValue.increment(result.distanceMetres),
          RewardConstants.totalCarbonSavedKgField:
              FieldValue.increment(result.carbonSavedKg),
          RewardConstants.totalCaloriesBurnedField:
              FieldValue.increment(result.caloriesBurned),
        });
      } else {
        // No tourist document at all. Module 1 normally creates it at sign-up,
        // so this is a defensive path: seed the totals rather than lose the
        // award. Written as literals because there is nothing to add to.
        transaction.set(
          userRef,
          {
            RewardConstants.totalPointsField: points,
            RewardConstants.totalCheckInsField: 1,
            RewardConstants.totalDistanceMetresField: result.distanceMetres,
            RewardConstants.totalCarbonSavedKgField: result.carbonSavedKg,
            RewardConstants.totalCaloriesBurnedField: result.caloriesBurned,
          },
          SetOptions(merge: true),
        );
      }

      // Stamp Module 4's check-in document so the guard survives even if the
      // ledger collection is ever cleared. update() rather than set(), because
      // the document belongs to Module 4 and only this one field is ours.
      if (checkInSnapshot.exists) {
        transaction
            .update(checkInRef, {RewardConstants.checkInRewardProcessedField: true});
      } else {
        transaction.set(
          checkInRef,
          {RewardConstants.checkInRewardProcessedField: true},
          SetOptions(merge: true),
        );
      }

      return true;
    });
  }
}
