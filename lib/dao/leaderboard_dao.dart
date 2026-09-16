// ---------------------------------------------------------------------------
// leaderboard_dao.dart
// Module 5 — Reward & Achievement
// Use Case : UC540 Compare standing against other tourists
// FR       : FR-R06 Leaderboard
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// All Firestore reads and writes for the public standings.
//
// Why a separate collection rather than a query over `users`
// ----------------------------------------------------------
// The obvious implementation is
// `users.orderBy('totalPoints', descending: true)`, and it is the wrong one
// twice over:
//
//   1. Security. A tourist document carries email, phone number, weight and
//      height. Ranking every tourist means every tourist reading every other
//      tourist's document, so that query cannot be granted without handing
//      out the whole profile with it (NFR-04). The rule in firestore.rules
//      is `users/{userId}/{document=**}: if isOwner(userId)`, and it stays
//      that way.
//
//   2. Ownership. `users` belongs to Module 1. Module 5 already only
//      increments its own fields on it; it should not start dictating the
//      shape of that collection's indexes as well.
//
// So the standings live in their own top-level `leaderboard` collection,
// document ID = user ID, holding only the five public fields in
// LeaderboardEntryModel. It is a read model: derived data, mirrored from the
// cumulative totals after each award, never the source of truth for a points
// balance. If a mirror write is ever lost, the tourist's points are still
// correct and the next check-in republishes the row.
//
// The contract is an abstract class so the controller depends on the
// abstraction and tests substitute a fake with no Firebase project, matching
// RewardDao and BadgeDao. Firestore types appear only in the implementation.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/leaderboard_entry_model.dart';
import '../models/reward_model.dart';
import '../utils/reward_constants.dart';

/// Public standings across all tourists.
abstract class LeaderboardDao {
  /// The highest-scoring tourists, best first, capped at [limit].
  ///
  /// Returns an empty list rather than throwing when nobody has scored yet —
  /// an empty board is a normal starting point on a fresh project, and the
  /// screen distinguishes it from a failed read.
  Future<List<LeaderboardEntryModel>> fetchTopEntries({int limit});

  /// One tourist's own row, or null when they have never been published.
  ///
  /// Used to show a tourist their own standing when they rank below the
  /// [limit] the board fetched, so the screen never has to tell somebody who
  /// has walked that they are not on it.
  Future<LeaderboardEntryModel?> fetchEntry(String userId);

  /// Mirrors [stats] into the tourist's public row.
  ///
  /// [displayName] and [photoUrl] are looked up by the implementation rather
  /// than passed in, so no caller has to reach into Module 1's profile to
  /// publish a score.
  Future<void> publishEntry({required String userId, required RewardModel stats});
}

/// Firestore-backed implementation.
class FirestoreLeaderboardDao implements LeaderboardDao {
  final FirebaseFirestore _firestore;

  /// [firestore] is injected so tests can pass a fake instance.
  FirestoreLeaderboardDao({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _leaderboardRef =>
      _firestore.collection(RewardConstants.leaderboardCollection);

  DocumentReference<Map<String, dynamic>> _userRef(String userId) =>
      _firestore.collection(RewardConstants.usersCollection).doc(userId);

  @override
  Future<List<LeaderboardEntryModel>> fetchTopEntries({
    int limit = RewardConstants.leaderboardPageSize,
  }) async {
    // A single-field descending order, which Firestore indexes automatically —
    // no entry in firestore.indexes.json is needed and none should be added.
    // Ties are ordered here only by whatever Firestore returns; the display
    // order within a tie is settled by LeaderboardRanking.rank, on the client,
    // where the rule can be read and tested.
    final snapshot = await _leaderboardRef
        .orderBy(LeaderboardFields.totalPoints, descending: true)
        .limit(limit)
        .get();

    final entries = snapshot.docs
        .map((doc) => LeaderboardEntryModel.fromMap(doc.id, doc.data()))
        .toList(growable: false);

    return _withLivePublicProfiles(entries);
  }

  /// Replaces each row's stored name and photo with the tourist's current ones.
  ///
  /// The row carries its own copy, refreshed only when publishEntry runs — at
  /// a check-in, or when the tourist opens the board. So changing your profile
  /// picture left a stale avatar on the leaderboard until your next walk. The
  /// copy stays as the fallback for a uid with no projection yet.
  ///
  /// Failure is swallowed: a board with slightly stale names is far better
  /// than no board, and the stored copy is always a reasonable answer.
  Future<List<LeaderboardEntryModel>> _withLivePublicProfiles(
    List<LeaderboardEntryModel> entries,
  ) async {
    if (entries.isEmpty) return entries;

    try {
      final ids = entries.map((e) => e.userId).where((id) => id.isNotEmpty);
      if (ids.isEmpty) return entries;

      final snapshot = await _firestore
          .collection(publicProfilesCollection)
          .where(FieldPath.documentId, whereIn: ids.toList())
          .get();

      final live = {for (final doc in snapshot.docs) doc.id: doc.data()};
      if (live.isEmpty) return entries;

      return entries.map((entry) {
        final profile = live[entry.userId];
        if (profile == null) return entry;

        final name = (profile['displayName'] as String? ?? '').trim();
        final photo = (profile['photoUrl'] as String? ?? '').trim();

        return LeaderboardEntryModel(
          userId: entry.userId,
          displayName: name.isEmpty ? entry.displayName : name,
          photoUrl: photo.isEmpty ? null : photo,
          totalPoints: entry.totalPoints,
          totalCheckIns: entry.totalCheckIns,
          totalDistanceMetres: entry.totalDistanceMetres,
        );
      }).toList(growable: false);
    } catch (_) {
      return entries;
    }
  }

  /// Mirrors PublicProfile / syncPublicProfile in functions/moderation.js.
  static const String publicProfilesCollection = 'public_profiles';

  @override
  Future<LeaderboardEntryModel?> fetchEntry(String userId) async {
    if (userId.isEmpty) return null;

    final snapshot = await _leaderboardRef.doc(userId).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) return null;

    return LeaderboardEntryModel.fromMap(userId, data);
  }

  @override
  Future<void> publishEntry({
    required String userId,
    required RewardModel stats,
  }) async {
    if (userId.isEmpty) return;

    // A tourist with no points has nothing to publish. Writing the row anyway
    // would put a wall of zeroes at the bottom of every board, and — worse —
    // would enrol somebody who has not walked into a public list of names.
    // Being on the board is something a check-in earns.
    if (stats.totalPoints <= 0) return;

    // Name and picture are read from the tourist's own document, which they
    // are the owner of, so this stays inside the users/ rule. It is a
    // separate read from the award transaction on purpose: publishing is a
    // mirror, and it must not be able to fail the award that produced it.
    final profile = await _userRef(userId).get();
    final data = profile.data() ?? const <String, dynamic>{};

    final nickname =
        (data[RewardConstants.profileNicknameField] as String?)?.trim();
    final photoUrl =
        (data[RewardConstants.profilePhotoUrlField] as String?)?.trim();

    final entry = LeaderboardEntryModel(
      userId: userId,
      // Normalised on the way in as well as on the way out. A blank nickname
      // written straight through would land in the collection as an empty
      // name, and every other client would then have to defend against it.
      displayName: nickname == null || nickname.isEmpty
          ? kDefaultWalkerName
          : nickname,
      photoUrl: photoUrl == null || photoUrl.isEmpty ? null : photoUrl,
      totalPoints: stats.totalPoints,
      totalCheckIns: stats.totalCheckIns,
      totalDistanceMetres: stats.totalDistanceMetres,
    );

    // merge, not a plain set: the row is rewritten in full on every publish,
    // but merging means a field some later build adds is not silently dropped
    // by a client still running this version.
    await _leaderboardRef.doc(userId).set(
      {
        ...entry.toMap(),
        LeaderboardFields.updatedAt: FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
