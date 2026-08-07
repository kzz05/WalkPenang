// ---------------------------------------------------------------------------
// badge_dao.dart
// Module 5 — Reward & Achievement
// Use Case : UC510 Unlock badges
// FR       : FR-R02 Badge Unlock Logic, FR-R05 Achievement History View
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// Data access for badge definitions and earned badges.
//
// Writing an unlocked badge is T-R02.3 in Sprint 2. This file currently
// provides the read side plus the one-off seeding routine that T-R02.1 needs.

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:walkpenang/models/badge_model.dart';
import 'package:walkpenang/utils/reward_constants.dart';

abstract class BadgeDao {
  /// All badge definitions.
  ///
  /// BadgeEvaluator receives this list as a parameter, which is what keeps the
  /// evaluation logic free of any Firestore dependency.
  Future<List<BadgeModel>> fetchDefinitions();

  /// IDs of badges [userId] already holds.
  ///
  /// Returned as a Set because the only question asked of it is membership,
  /// and because it guards against re-awarding.
  Future<Set<String>> fetchEarnedBadgeIds(String userId);

  /// Writes the three seed definitions if the collection is empty.
  ///
  /// Run once against the development project. Existing documents are left
  /// untouched so re-running cannot clobber a manually edited description.
  Future<void> seedDefinitionsIfEmpty();
}

class FirestoreBadgeDao implements BadgeDao {
  final FirebaseFirestore _firestore;

  FirestoreBadgeDao({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _badges =>
      _firestore.collection(kBadgesCollection);

  CollectionReference<Map<String, dynamic>> _userBadges(String userId) =>
      _firestore
          .collection(kUsersCollection)
          .doc(userId)
          .collection(kUserBadgesSubcollection);

  @override
  Future<List<BadgeModel>> fetchDefinitions() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _badges.get();
    return snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
            BadgeModel.fromMap(doc.id, doc.data()))
        .toList(growable: false);
  }

  @override
  Future<Set<String>> fetchEarnedBadgeIds(String userId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _userBadges(userId).get();
    return snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.id)
        .toSet();
  }

  @override
  Future<void> seedDefinitionsIfEmpty() async {
    final QuerySnapshot<Map<String, dynamic>> existing =
        await _badges.limit(1).get();
    if (existing.docs.isNotEmpty) {
      return;
    }

    final WriteBatch batch = _firestore.batch();
    for (final BadgeModel definition in BadgeModel.seedDefinitions()) {
      batch.set(_badges.doc(definition.id), definition.toMap());
    }
    await batch.commit();
  }
}
