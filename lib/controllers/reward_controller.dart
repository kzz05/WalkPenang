// ---------------------------------------------------------------------------
// reward_controller.dart
// Module 5 — Reward & Achievement
// Use Case : UC500 Earn points from activities, UC510 Unlock badges,
//            UC530 View statistics dashboard
// FR       : FR-R01 Points Award System, FR-R02 Badge Milestone System,
//            FR-R04 Statistics Dashboard
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// Orchestration for Module 5: award points for a verified check-in, evaluate
// the badge milestones against the updated totals, persist anything newly
// unlocked, and hold the state the dashboard and gallery render.
//
// Deliberately free of package:cloud_firestore. Both DAOs are injected as
// abstractions, so this class can be driven by an in-memory double with no
// Firebase project — which is what makes the dashboard runnable in a demo and
// unit testable at the same time.

import 'package:flutter/foundation.dart';

import '../dao/badge_dao.dart';
import '../dao/reward_dao.dart';
import '../models/badge_model.dart';
import '../models/check_in_result.dart';
import '../models/reward_model.dart';
import '../models/user_badge_model.dart';
import '../utils/reward_constants.dart';
import 'reward_service.dart';

class RewardController extends ChangeNotifier implements RewardService {
  final String userId;
  final RewardDao _rewardDao;
  final BadgeDao _badgeDao;

  /// True when the DAOs behind this controller are in-memory demo doubles
  /// rather than Firestore. The dashboard surfaces this so a screenshot of
  /// seeded data can never be mistaken for a real tourist's totals.
  final bool isDemo;

  RewardController({
    required this.userId,
    required RewardDao rewardDao,
    required BadgeDao badgeDao,
    this.isDemo = false,
  })  : _rewardDao = rewardDao,
        _badgeDao = badgeDao;

  // --- State the views render ----------------------------------------------

  RewardModel _stats = const RewardModel.empty('');
  List<BadgeModel> _definitions = const [];
  Map<String, UserBadgeModel> _earned = const {};
  bool _isLoading = false;
  Object? _error;

  /// Cumulative totals (UC530). Zeroes until [load] completes.
  RewardModel get stats => _stats;

  /// Every badge that exists, in gallery order (FR-R05).
  List<BadgeModel> get definitions => _definitions;

  /// Badges the tourist holds, keyed by badge ID.
  Map<String, UserBadgeModel> get earnedBadges => _earned;

  bool get isLoading => _isLoading;

  /// Non-null when the last load or award failed. The dashboard shows a retry
  /// rather than an empty state, because zero totals and a failed read look
  /// identical to a tourist and must not.
  Object? get error => _error;

  Set<String> get earnedBadgeIds => _earned.keys.toSet();

  int get unlockedBadgeCount => _earned.length;

  int get totalBadgeCount => _definitions.length;

  bool hasEarned(String badgeId) => _earned.containsKey(badgeId);

  UserBadgeModel? earnedBadge(String badgeId) => _earned[badgeId];

  /// How far the tourist is towards [badge], clamped to 0..1.
  ///
  /// Progress on a badge already held reads as complete even if the
  /// definition's threshold were later raised, so the gallery never shows an
  /// unlocked badge as partially earned.
  double progressTowards(BadgeModel badge) {
    if (hasEarned(badge.id)) return 1.0;
    if (badge.threshold <= 0) return 1.0;

    final current = switch (badge.criterion) {
      BadgeCriterion.totalCheckIns => _stats.totalCheckIns,
      BadgeCriterion.cumulativeDistance => _stats.totalDistanceMetres,
    };
    return (current / badge.threshold).clamp(0.0, 1.0);
  }

  /// What is still outstanding on [badge], phrased for the gallery caption.
  String remainingLabel(BadgeModel badge) {
    if (hasEarned(badge.id)) return 'Unlocked';

    switch (badge.criterion) {
      case BadgeCriterion.totalCheckIns:
        final left = badge.threshold - _stats.totalCheckIns;
        return left == 1 ? '1 check-in to go' : '$left check-ins to go';
      case BadgeCriterion.cumulativeDistance:
        final left = badge.threshold - _stats.totalDistanceMetres;
        final km = RewardConstants.kmFromMetres(left < 0 ? 0 : left);
        return '${km.toStringAsFixed(1)} km to go';
    }
  }

  // --- Loading -------------------------------------------------------------

  /// Loads everything the dashboard and gallery need.
  ///
  /// Definitions, totals and earned badges are fetched together because the
  /// gallery is a join of all three: showing any one of them before the
  /// others would flash badges as locked that the tourist already holds.
  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Definitions are loaded separately from the tourist's own data, and a
    // failure is absorbed rather than propagated. They are business rules with
    // a known local copy, so an unseeded or unreadable BADGES collection must
    // not take the points balance down with it — the gallery just falls back
    // to the catalogue the collection is seeded from.
    try {
      _definitions = await _badgeDao.fetchDefinitions();
    } catch (_) {
      _definitions = BadgeCatalogue.all;
    }

    try {
      final results = await Future.wait([
        _rewardDao.fetchRewardSummary(userId),
        _badgeDao.fetchEarnedBadges(userId),
      ]);

      _stats = results[0] as RewardModel;
      _earned = {
        for (final badge in results[1] as List<UserBadgeModel>)
          badge.badgeId: badge,
      };
    } catch (error) {
      // The tourist's totals have no local fallback — showing zeroes here
      // would claim they have earned nothing, so this one does surface.
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- The Module 4 entry point (UC500 basic flow step 4) ------------------

  @override
  Future<RewardOutcome> onCheckInVerified(CheckInResult result) async {
    // Distance, carbon and calories arrive already calculated by Module 4 and
    // are never recomputed here — Module 5 begins at "receive verified
    // check-in data".
    final points = RewardPoints.forCheckIn(distanceMetres: result.distanceMetres);

    final awarded = await _rewardDao.awardForCheckIn(
      result: result,
      points: points,
    );

    if (!awarded) {
      // Already rewarded, so nothing was written. The points figure is still
      // correct to report back: the formula is deterministic on the check-in's
      // own distance, so recomputing it yields exactly the original award
      // without needing to read the ledger entry.
      return RewardOutcome(
        pointsAwarded: points,
        alreadyAwarded: true,
      );
    }

    // Badges are evaluated from the totals as they stand *after* the award,
    // read back from the DAO rather than added up locally, so the check is
    // made against the same numbers any other device would see.
    final updatedStats = await _rewardDao.fetchRewardSummary(userId);
    final earnedBefore = await _badgeDao.fetchEarnedBadges(userId);
    final earnedIds = earnedBefore.map((b) => b.badgeId).toSet();

    final newlyEarned = BadgeEvaluator.newlyEarned(
      stats: updatedStats,
      earnedBadgeIds: earnedIds,
    );

    await _badgeDao.awardBadges(
      userId: userId,
      badges: newlyEarned,
      earnedAt: result.checkInTime,
    );

    _stats = updatedStats;
    _earned = {
      for (final badge in earnedBefore) badge.badgeId: badge,
      for (final badge in newlyEarned)
        badge.id: UserBadgeModel(
          badgeId: badge.id,
          dateEarned: result.checkInTime,
        ),
    };
    if (_definitions.isEmpty) {
      _definitions = await _badgeDao.fetchDefinitions();
    }
    notifyListeners();

    return RewardOutcome(
      pointsAwarded: points,
      newlyEarnedBadgeIds: newlyEarned.map((b) => b.id).toList(growable: false),
    );
  }
}
