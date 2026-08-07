// ---------------------------------------------------------------------------
// reward_constants.dart
// Module 5 — Reward & Achievement
// Use Case : UC500 Earn points from activities, UC510 Unlock badges
// FR       : FR-R01 Points Award System, FR-R02 Badge Unlock Logic
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// Single source of truth for every reward-domain literal. Nothing in this file
// imports Flutter or Firestore, so it can be unit tested as pure Dart.
//
// Colours are stored as int hex literals rather than Color so this file stays
// Flutter-free. Views wrap them in Color(...) at the point of use.

// --- Firestore collection names --------------------------------------------

const String kUsersCollection = 'users';
const String kBadgesCollection = 'badges';
const String kUserBadgesSubcollection = 'userBadges';
const String kPointsLedgerSubcollection = 'pointsLedger';

// --- Cumulative total field names on users/{uid} ----------------------------
//
// Module 1 reads kFieldTotalPoints for the Home profile card, so these names
// are a cross-module contract, not internal detail. Renaming any of them
// requires telling Ian.

const String kFieldTotalPoints = 'totalPoints';
const String kFieldTotalCheckIns = 'totalCheckIns';
const String kFieldTotalDistanceKm = 'totalDistanceKm';
const String kFieldTotalCarbonSavedKg = 'totalCarbonSavedKg';
const String kFieldTotalCaloriesBurned = 'totalCaloriesBurned';

// --- Badge definition field names on badges/{badgeId} -----------------------

const String kFieldBadgeName = 'name';
const String kFieldBadgeDescription = 'description';
const String kFieldBadgeCriterion = 'criterion';
const String kFieldBadgeThreshold = 'threshold';
const String kFieldBadgeIconAsset = 'iconAsset';

// --- Earned badge and points ledger field names -----------------------------

const String kFieldDateEarned = 'dateEarned';
const String kFieldPointsAwarded = 'pointsAwarded';
const String kFieldDistanceKm = 'distanceKm';
const String kFieldCarbonSavedKg = 'carbonSavedKg';
const String kFieldCaloriesBurned = 'caloriesBurned';
const String kFieldAwardedAt = 'awardedAt';

// --- Points formula (UC500, constraint C1) ----------------------------------
//
// 10 points per completed check-in, plus 1 point per 0.1 km walked, rounded
// down. The distance bonus is computed in whole metres rather than by
// multiplying the kilometre double, because 1.3 is representable as
// 12.999999999999998 once multiplied by 10 and would floor to 12 instead of 13.

/// Flat award for any successfully verified check-in.
const int kPointsPerCheckIn = 10;

/// Metres of walking that earn one bonus point. 0.1 km = 100 m.
const int kMetresPerBonusPoint = 100;

// --- Badge criterion identifiers --------------------------------------------
//
// Stored as strings in Firestore so a new badge is a data change, not a code
// change. Parsed into BadgeCriterion by BadgeModel.

const String kCriterionCheckIns = 'checkIns';
const String kCriterionDistanceKm = 'distanceKm';

// --- Badge identifiers -------------------------------------------------------

const String kBadgeExplorer = 'explorer';
const String kBadgeTrailblazer = 'trailblazer';
const String kBadgePenangWanderer = 'penang_wanderer';

// --- Badge seed data (UC510, constraint C1) ---------------------------------
//
// Used once to populate the badges collection. This is NOT a runtime source of
// truth: BadgeEvaluator reads definitions loaded from Firestore by BadgeDao.
// Duplicating the thresholds here is deliberate and limited to seeding.

const List<Map<String, dynamic>> kBadgeSeedData = <Map<String, dynamic>>[
  <String, dynamic>{
    'id': kBadgeExplorer,
    kFieldBadgeName: 'Explorer',
    kFieldBadgeDescription: 'Complete 5 check-ins across Penang.',
    kFieldBadgeCriterion: kCriterionCheckIns,
    kFieldBadgeThreshold: 5,
    kFieldBadgeIconAsset: 'assets/badges/explorer.svg',
  },
  <String, dynamic>{
    'id': kBadgeTrailblazer,
    kFieldBadgeName: 'Trailblazer',
    kFieldBadgeDescription: 'Walk a cumulative 10 km.',
    kFieldBadgeCriterion: kCriterionDistanceKm,
    kFieldBadgeThreshold: 10,
    kFieldBadgeIconAsset: 'assets/badges/trailblazer.svg',
  },
  <String, dynamic>{
    'id': kBadgePenangWanderer,
    kFieldBadgeName: 'Penang Wanderer',
    kFieldBadgeDescription: 'Walk a cumulative 50 km.',
    kFieldBadgeCriterion: kCriterionDistanceKm,
    kFieldBadgeThreshold: 50,
    kFieldBadgeIconAsset: 'assets/badges/penang_wanderer.svg',
  },
];

// --- Badge palette (see the badge visual specification in CLAUDE.md) --------

const int kColorBadgeExplorer = 0xFF2E9E6B;
const int kColorBadgeTrailblazer = 0xFF2F80ED;
const int kColorBadgePenangWanderer = 0xFFF2A93B;
