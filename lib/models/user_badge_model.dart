// ---------------------------------------------------------------------------
// user_badge_model.dart
// Module 5 — Reward & Achievement
// Use Case : UC510 Unlock badges
// FR       : FR-R02 Badge Milestone System, FR-R05 Badge Gallery
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// One badge a tourist has actually earned, as stored under
// users/{uid}/user_badges/{badgeId}.
//
// Separate from BadgeModel on purpose: BadgeModel is the definition (fixed by
// the proposal, identical for every tourist), this is the instance (per
// tourist, carries when it was earned). The gallery joins the two — it shows
// every definition and marks the ones with a matching instance as unlocked.
//
// Pure Dart with no Firestore import. The DAO converts the Timestamp at its
// edge so this stays testable without a Firebase project.

import '../utils/reward_constants.dart';

class UserBadgeModel {
  /// The badge earned. Matches [BadgeModel.id] and the Firestore document ID.
  final String badgeId;

  /// When the threshold was crossed. Shown on the badge detail screen so the
  /// tourist can see when they unlocked it (FR-R05).
  final DateTime dateEarned;

  const UserBadgeModel({
    required this.badgeId,
    required this.dateEarned,
  });

  /// [badgeId] comes from the document ID rather than a field, because the
  /// document ID is what makes a double unlock impossible.
  factory UserBadgeModel.fromMap(String badgeId, Map<String, dynamic> map) {
    final earned = map[RewardConstants.userBadgeDateEarnedField];
    return UserBadgeModel(
      badgeId: badgeId,
      // A badge written by an older build, or one whose server timestamp has
      // not resolved yet, must still render in the gallery rather than crash
      // it — so a missing date falls back to the epoch.
      dateEarned: earned is DateTime
          ? earned
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() {
    return {RewardConstants.userBadgeDateEarnedField: dateEarned};
  }

  @override
  String toString() => 'UserBadgeModel($badgeId, earned: $dateEarned)';
}
