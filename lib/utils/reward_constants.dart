// ---------------------------------------------------------------------------
// reward_constants.dart
// Module 5 — Reward & Achievement
// Use Case : UC500 Earn points from activities, UC510 Unlock badges
// FR       : FR-R01 Points Award System, FR-R02 Badge Milestone System
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// Single source of truth for every number, name and colour the Reward module
// depends on. Business rules are fixed by the submitted proposal, so they are
// declared here once rather than repeated as literals across controllers,
// DAOs and views.
//
// This file must stay free of package:flutter and package:cloud_firestore so
// that the rules can be unit tested without a Flutter binding or a live
// Firebase project. The one import below is pure Dart and imports nothing
// itself, so it preserves that.

import '../models/transport_mode.dart';

/// Numbers fixed by the proposal and the use case description tables.
class RewardConstants {
  RewardConstants._();

  // --- Points formula (UC500, constraint C1) -------------------------------

  /// Flat award for completing a check-in.
  static const int pointsPerCheckIn = 10;

  /// 1 bonus point per 0.1 km. Held in metres because the formula is evaluated
  /// in integer metres — see [RewardPoints.forCheckIn] for why.
  static const int metresPerDistancePoint = 100;

  // --- Badge milestones (UC510, constraint C1) -----------------------------

  /// Explorer — awarded on the tourist's 5th completed check-in.
  static const int explorerCheckIns = 5;

  /// Trailblazer — 10 km cumulative distance.
  static const int trailblazerMetres = 10000;

  /// Penang Wanderer — 50 km cumulative distance.
  static const int penangWandererMetres = 50000;

  // --- Badge identifiers ---------------------------------------------------
  //
  // These are document IDs in the BADGES collection and the keys the badge
  // gallery uses to look up an asset, so they must never be renamed once
  // tourist data exists.

  static const String explorerBadgeId = 'explorer';
  static const String trailblazerBadgeId = 'trailblazer';
  static const String penangWandererBadgeId = 'penang_wanderer';

  static const String explorerAsset = 'assets/badges/explorer.svg';
  static const String trailblazerAsset = 'assets/badges/trailblazer.svg';
  static const String penangWandererAsset = 'assets/badges/penang_wanderer.svg';

  // --- Firestore collections ----------------------------------------------

  /// Tourist documents. Owned by Module 1; Module 5 only increments its own
  /// cumulative fields on them.
  static const String usersCollection = 'users';

  /// One document per rewarded check-in, keyed by the check-in ID. Existence
  /// of the document is what makes awarding idempotent (T-R01.5).
  static const String pointsLedgerCollection = 'points_ledger';

  /// Verified check-in records written by Module 4 (Walking & Carbon).
  /// Module 5 only stamps [checkInRewardProcessedField] on them.
  static const String checkInsCollection = 'check_ins';

  /// Badge definitions (UC510).
  static const String badgesCollection = 'badges';

  /// Badges a tourist has earned, one document per badge.
  static const String userBadgesCollection = 'user_badges';

  // --- Cumulative fields on the tourist document (T-R01.2) -----------------
  //
  // Every one of these is written with FieldValue.increment() and never
  // read-then-written, so two check-ins completing at the same time cannot
  // clobber each other's totals.
  //
  // Distance is stored as an integer count of metres, not a double of
  // kilometres. Repeatedly incrementing a double accumulates representation
  // error, which would eventually make a badge threshold comparison such as
  // "50 km reached" wrong at the boundary. Views divide by 1000 for display.

  static const String totalPointsField = 'totalPoints';
  static const String totalCheckInsField = 'totalCheckIns';
  static const String totalDistanceMetresField = 'totalDistanceMetres';
  static const String totalCarbonSavedKgField = 'totalCarbonSavedKg';
  static const String totalCaloriesBurnedField = 'totalCaloriesBurned';

  // --- Points ledger document fields --------------------------------------

  static const String ledgerUserIdField = 'userId';
  static const String ledgerCheckInIdField = 'checkInId';
  static const String ledgerPointsAwardedField = 'pointsAwarded';
  static const String ledgerDistanceMetresField = 'distanceMetres';
  static const String ledgerAwardedAtField = 'awardedAt';

  // --- Earned badge document fields ---------------------------------------
  //
  // The document ID is the badge ID, so holding a badge twice is structurally
  // impossible rather than something the code has to remember to check.

  static const String userBadgeDateEarnedField = 'dateEarned';

  // --- Check-in document fields -------------------------------------------

  /// Guard flag stamped on Module 4's check-in document once Module 5 has
  /// awarded for it. Checked before processing so a retry is a no-op.
  static const String checkInRewardProcessedField = 'rewardProcessed';

  // --- Metres <-> kilometres ----------------------------------------------

  static const int metresPerKilometre = 1000;

  /// Converts the kilometre figure supplied by Module 4 into whole metres.
  ///
  /// Rounds rather than truncates: 1.3 km arrives as 1299.9999999999998 once
  /// multiplied out, and truncating would silently lose a metre on values
  /// that are exact in decimal but not in binary floating point.
  static int metresFromKm(double distanceKm) =>
      (distanceKm * metresPerKilometre).round();

  static double kmFromMetres(int distanceMetres) =>
      distanceMetres / metresPerKilometre;
}

/// The points formula (UC500, constraint C1): 10 points per completed
/// check-in, plus 1 point per 0.1 km walked, rounded down.
///
/// Pure functions with no Flutter or Firestore dependency, so T-R01.5 can
/// cover the boundaries without a Firebase project.
class RewardPoints {
  RewardPoints._();

  /// Points awarded for one completed check-in that covered
  /// [distanceMetres] metres by [transportMode].
  ///
  /// **Only walking earns points.** WalkPenang's whole premise is walking, so
  /// a journey completed by car, bus or bicycle records its distance and
  /// carbon for comparison but awards nothing. Without this a tourist could
  /// drive between destinations and out-earn someone who walked.
  ///
  /// The rule lives in the formula rather than in [RewardController], so that
  /// every caller gets it — a check computed at one award site is a check the
  /// next award site can forget.
  ///
  /// The distance bonus is computed by integer division on metres rather than
  /// `(distanceKm * 10).floor()`. The naive form is unsafe: 1.3 km is held in
  /// binary as 1.2999999999999998, so multiplying by 10 gives
  /// 12.999999999999998, which floors to 12 instead of the correct 13.
  static int forCheckIn({
    required int distanceMetres,
    TransportMode transportMode = TransportMode.walking,
  }) {
    if (!transportMode.earnsPoints) return 0;

    // A verified check-in always earns the flat award; only the bonus scales.
    // Negative distance cannot occur through Module 4, but clamping keeps a
    // corrupt record from subtracting from the tourist's balance.
    final metres = distanceMetres < 0 ? 0 : distanceMetres;
    return RewardConstants.pointsPerCheckIn +
        metres ~/ RewardConstants.metresPerDistancePoint;
  }

  /// Convenience overload for callers holding kilometres, which is the unit
  /// Module 4 reports in. Converts to metres first, then applies the formula.
  static int forCheckInKm({
    required double distanceKm,
    TransportMode transportMode = TransportMode.walking,
  }) =>
      forCheckIn(
        distanceMetres: RewardConstants.metresFromKm(distanceKm),
        transportMode: transportMode,
      );
}

/// Design tokens for Module 5 screens.
///
/// Stored as int hex literals rather than Color so this file never imports
/// package:flutter. Views wrap them: Color(RewardTokens.explorerHue).
class RewardTokens {
  RewardTokens._();

  /// Badge hues, one per badge (badge visual specification).
  static const int explorerHue = 0xFF2E9E6B; // green
  static const int trailblazerHue = 0xFF2F80ED; // blue
  static const int penangWandererHue = 0xFFF2A93B; // amber

  /// A locked badge is the same asset rendered greyscale at 40% opacity, so
  /// FR-R05 needs no second artwork file per badge.
  static const double lockedBadgeOpacity = 0.4;
}
