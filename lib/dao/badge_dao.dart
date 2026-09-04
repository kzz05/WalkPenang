// ---------------------------------------------------------------------------
// badge_dao.dart
// Module 5 — Reward & Achievement
// Use Case : UC510 Unlock badges
// FR       : FR-R02 Badge Milestone System, FR-R05 Badge Gallery
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// All Firestore reads and writes for the BADGES and USER_BADGES collections.
//
// The contract is an abstract class so the controller depends on the
// abstraction and the dashboard can be driven by an in-memory double with no
// Firebase project (see test/support/in_memory_reward_data.dart).

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/badge_model.dart';
import '../models/user_badge_model.dart';
import '../utils/reward_constants.dart';

/// Badge definitions and the badges one tourist has earned.
abstract class BadgeDao {
  /// The badge definitions the gallery renders.
  ///
  /// Returned as data rather than branched on, so adding a fourth badge is a
  /// Firestore change and not a code change.
  Future<List<BadgeModel>> fetchDefinitions();

  /// Badges this tourist already holds.
  Future<List<UserBadgeModel>> fetchEarnedBadges(String userId);

  /// Records [badges] as earned by [userId].
  ///
  /// Must never overwrite the date on a badge already held: the tourist
  /// earned Explorer on their 5th check-in, and their 40th check-in must not
  /// move that date forward.
  Future<void> awardBadges({
    required String userId,
    required List<BadgeModel> badges,
    DateTime? earnedAt,
  });
}

/// Firestore-backed implementation.
class FirestoreBadgeDao implements BadgeDao {
  final FirebaseFirestore _firestore;

  /// [firestore] is injected so tests can pass a fake instance.
  FirestoreBadgeDao({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _badgesRef =>
      _firestore.collection(RewardConstants.badgesCollection);

  CollectionReference<Map<String, dynamic>> _userBadgesRef(String userId) =>
      _firestore
          .collection(RewardConstants.usersCollection)
          .doc(userId)
          .collection(RewardConstants.userBadgesCollection);

  @override
  Future<List<BadgeModel>> fetchDefinitions() async {
    final snapshot = await _badgesRef.get();

    // An unseeded collection falls back to the catalogue rather than showing
    // an empty gallery. The catalogue is the seed source for this collection,
    // so the two cannot disagree — and a fresh clone of the project renders a
    // correct gallery before anyone has run seedDefinitions().
    if (snapshot.docs.isEmpty) return BadgeCatalogue.all;

    final definitions = snapshot.docs
        .map((doc) => BadgeModel.fromMap({...doc.data(), 'id': doc.id}))
        .toList();

    // Gallery order is easiest milestone first (FR-R05). Firestore returns
    // documents in ID order, which would put Trailblazer before Explorer.
    definitions.sort((a, b) => _catalogueRank(a).compareTo(_catalogueRank(b)));
    return definitions;
  }

  /// Position in [BadgeCatalogue.all]; unknown badges sort to the end so a
  /// badge added in Firestore before the catalogue knows about it still shows.
  int _catalogueRank(BadgeModel badge) {
    final index = BadgeCatalogue.all.indexWhere((b) => b.id == badge.id);
    return index < 0 ? BadgeCatalogue.all.length : index;
  }

  @override
  Future<List<UserBadgeModel>> fetchEarnedBadges(String userId) async {
    final snapshot = await _userBadgesRef(userId).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      final raw = data[RewardConstants.userBadgeDateEarnedField];
      return UserBadgeModel.fromMap(doc.id, {
        // Timestamp is a Firestore type and must not leave this layer, so it
        // is converted to DateTime here at the edge.
        RewardConstants.userBadgeDateEarnedField:
            raw is Timestamp ? raw.toDate() : raw,
      });
    }).toList();
  }

  @override
  Future<void> awardBadges({
    required String userId,
    required List<BadgeModel> badges,
    DateTime? earnedAt,
  }) async {
    if (badges.isEmpty) return;

    final stamp = earnedAt ?? DateTime.now();

    for (final badge in badges) {
      final ref = _userBadgesRef(userId).doc(badge.id);

      // Read-then-write rather than a blind set, so re-running an award does
      // not reset dateEarned. The document ID is the badge ID, so there is at
      // most one document per badge to check.
      final existing = await ref.get();
      if (existing.exists) continue;

      await ref.set({
        RewardConstants.userBadgeDateEarnedField: Timestamp.fromDate(stamp),
      });
    }
  }

  /// Writes the three definitions into the BADGES collection.
  ///
  /// Run once per environment. Not part of the [BadgeDao] contract because it
  /// is a setup step, not something the controller ever calls: the thresholds
  /// are fixed by the proposal, so seeding is a deployment concern.
  Future<void> seedDefinitions() async {
    final batch = _firestore.batch();
    for (final badge in BadgeCatalogue.all) {
      final map = badge.toMap()..remove('id');
      batch.set(_badgesRef.doc(badge.id), map);
    }
    await batch.commit();
  }
}
