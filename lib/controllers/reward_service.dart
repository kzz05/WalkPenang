// ---------------------------------------------------------------------------
// reward_service.dart
// Module 5 — Reward & Achievement
// Use Case : UC500 Earn points from activities
// FR       : FR-R01 Points Award System
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// The narrow interface Module 4 (Walking & Carbon) depends on.
//
// Module 4 calls Module 5 directly rather than Module 5 listening to the
// check-in collection. A Firestore snapshot listener only fires while the app
// is foregrounded and the listener is still mounted, so a tourist who checks
// in and immediately closes the app would never be awarded points. Direct
// invocation also matches UC500 basic flow step 4, where the system passes
// the check-in data to the Reward Module.
//
// Coupling stays loose because Module 4 imports only this abstraction.
// RewardController implements it and is injected at app startup, so neither
// side reaches into the other's internals and either can be faked in tests.
//
// DECLARATION ONLY THIS SPRINT. Module 4 needs the signature to plan against;
// the implementation is T-R01.3 in Sprint 3.

import '../models/check_in_result.dart';

abstract class RewardService {
  /// Called by Module 4 once a check-in has been verified.
  ///
  /// Must be safe to call more than once with the same
  /// [CheckInResult.checkInId] — a retry reports the original award rather
  /// than granting points a second time.
  Future<RewardOutcome> onCheckInVerified(CheckInResult result);
}

/// What the tourist gained from one check-in, returned to Module 4 so the
/// confirmation message can be shown at the point of check-in.
class RewardOutcome {
  /// Points granted for this check-in.
  final int pointsAwarded;

  /// Badges that crossed their threshold on this check-in. Empty when none
  /// did. A single check-in may unlock more than one (UC510).
  final List<String> newlyEarnedBadgeIds;

  /// True when this check-in had already been rewarded, so nothing was
  /// granted this time. [pointsAwarded] then reports the original award.
  final bool alreadyAwarded;

  const RewardOutcome({
    required this.pointsAwarded,
    this.newlyEarnedBadgeIds = const [],
    this.alreadyAwarded = false,
  });

  @override
  String toString() => 'RewardOutcome(pointsAwarded: $pointsAwarded, '
      'newlyEarnedBadgeIds: $newlyEarnedBadgeIds, '
      'alreadyAwarded: $alreadyAwarded)';
}
