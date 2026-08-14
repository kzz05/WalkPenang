// Walking & Carbon Module — completed-journey persistence (UC-W05).
//
// Module 5 (Reward & Achievement)'s FirestoreRewardDao only ever merges its
// own `rewardProcessed` flag onto check_ins/{checkInId} — it never writes
// the check-in record itself (see reward_dao.dart / firestore.rules, which
// already documents this write as "Written by the Walking & Carbon module
// on arrival"). This repository is that write, isolated behind a small
// Walking-owned abstraction rather than scattered as raw Firestore calls in
// JourneyCompletionController.
//
// Does not touch, modify or duplicate anything in lib/dao/ or
// lib/controllers/reward_*.dart — it writes the same `check_ins` collection
// name Module 5 already reads, via the constant Module 5 already exports
// for that purpose (RewardConstants.checkInsCollection).

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/check_in_result.dart';
import '../utils/reward_constants.dart';

abstract class CheckInRepository {
  /// A fresh, unique ID for a new check-in. Used as
  /// [CheckInResult.checkInId] — the idempotency key Module 5's points
  /// ledger and `rewardProcessed` guard are both keyed on.
  String newCheckInId();

  /// Persists the completed journey's check-in record.
  Future<void> saveCheckIn(CheckInResult result);
}

/// Firestore-backed implementation.
class FirestoreCheckInRepository implements CheckInRepository {
  FirestoreCheckInRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _checkIns =>
      _firestore.collection(RewardConstants.checkInsCollection);

  @override
  String newCheckInId() => _checkIns.doc().id;

  @override
  Future<void> saveCheckIn(CheckInResult result) {
    // checkInTime is converted explicitly rather than relying on the plugin
    // to coerce a raw DateTime, matching how the rest of the codebase always
    // hands Firestore a Timestamp at the DAO edge (see badge_dao.dart).
    final data = result.toMap()
      ..['checkInTime'] = Timestamp.fromDate(result.checkInTime);

    return _checkIns.doc(result.checkInId).set(data, SetOptions(merge: true));
  }
}
