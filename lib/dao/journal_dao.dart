// ---------------------------------------------------------------------------
// journal_dao.dart
// Module 5 — Reward & Achievement
// Use Case : UC520 View walking journal
// FR       : FR-R03 Walking Journal
// ---------------------------------------------------------------------------
//
// All Firestore reads for the tourist's completed journeys.
//
// Declared as an abstract class so the controller depends on the abstraction
// and tests substitute a fake with no Firebase project, matching RewardDao.
// Firestore types appear only in the implementation below.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/journal_entry_model.dart';
import '../utils/reward_constants.dart';

/// Completed journeys for one tourist, newest first.
abstract class JournalDao {
  /// The tourist's journeys, most recent first.
  ///
  /// A tourist who has walked nothing yet returns an empty list rather than
  /// throwing — an empty journal is a normal starting point, not a failure,
  /// and the screen distinguishes the two.
  Future<List<JournalEntryModel>> fetchEntries(
    String userId, {
    int limit = 50,
  });
}

/// Firestore-backed implementation, reading Module 4's `check_ins`.
class FirestoreJournalDao implements JournalDao {
  FirestoreJournalDao({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<List<JournalEntryModel>> fetchEntries(
    String userId, {
    int limit = 50,
  }) async {
    if (userId.isEmpty) return const <JournalEntryModel>[];

    // Needs the composite index (userId ASC, checkInTime DESC) declared in
    // firestore.indexes.json. Without it this throws a FAILED_PRECONDITION
    // carrying a console link — which is why WalkingJournalScreen surfaces the
    // real exception in debug builds rather than blaming the connection.
    final snapshot = await _firestore
        .collection(RewardConstants.checkInsCollection)
        .where(RewardConstants.checkInUserIdField, isEqualTo: userId)
        .orderBy(RewardConstants.checkInTimeField, descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      // Timestamp is a Firestore type and must not leave this layer, so it is
      // converted here — the same edge conversion badge_dao.dart does.
      final raw = data[RewardConstants.checkInTimeField];
      data[RewardConstants.checkInTimeField] =
          raw is Timestamp ? raw.toDate() : raw;
      return JournalEntryModel.fromMap(doc.id, data);
    }).toList();
  }
}
