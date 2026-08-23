// ---------------------------------------------------------------------------
// in_memory_reward_data.dart
// Module 5 — Reward & Achievement
// Use Case : UC510 Unlock badges, UC530 View statistics dashboard
// FR       : FR-R02 Badge Milestone System, FR-R04 Statistics Dashboard
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// In-memory implementations of the two Module 5 DAO contracts.
//
// Two jobs. They are the test doubles the controller is unit tested against,
// and they back the dashboard's demo mode so the reward screens can be walked
// through — badges locking and unlocking as check-ins accumulate — without a
// Firebase project, a signed-in tourist, or 50 km of real walking.
//
// Nothing here writes to Firestore, so demo mode can never touch live data.

import '../models/badge_model.dart';
import '../models/check_in_result.dart';
import '../models/journal_entry_model.dart';
import '../models/reward_model.dart';
import '../models/transport_mode.dart';
import '../models/user_badge_model.dart';
import 'badge_dao.dart';
import 'journal_dao.dart';
import 'reward_dao.dart';

/// Cumulative totals held in memory.
class InMemoryRewardDao implements RewardDao {
  RewardModel _stats;

  /// Check-ins already rewarded, keyed by check-in ID. This is the in-memory
  /// stand-in for the points ledger, and it is what makes awarding idempotent
  /// here for the same reason the ledger does in Firestore.
  final Map<String, int> _ledger = {};

  InMemoryRewardDao({RewardModel? initial})
      : _stats = initial ?? const RewardModel.empty('demo_tourist');

  @override
  Future<RewardModel> fetchRewardSummary(String userId) async => _stats;

  @override
  Future<bool> isCheckInRewarded(String checkInId) async =>
      _ledger.containsKey(checkInId);

  @override
  Future<bool> awardForCheckIn({
    required CheckInResult result,
    required int points,
  }) async {
    if (_ledger.containsKey(result.checkInId)) return false;

    _ledger[result.checkInId] = points;
    _stats = RewardModel(
      userId: _stats.userId,
      totalPoints: _stats.totalPoints + points,
      totalCheckIns: _stats.totalCheckIns + 1,
      totalDistanceMetres: _stats.totalDistanceMetres + result.distanceMetres,
      totalCarbonSavedKg: _stats.totalCarbonSavedKg + result.carbonSavedKg,
      totalCaloriesBurned: _stats.totalCaloriesBurned + result.caloriesBurned,
    );
    return true;
  }
}

/// Badge definitions and earned badges held in memory.
class InMemoryBadgeDao implements BadgeDao {
  final List<BadgeModel> _definitions;
  final Map<String, UserBadgeModel> _earned;

  InMemoryBadgeDao({
    List<BadgeModel>? definitions,
    List<UserBadgeModel> earned = const [],
  })  : _definitions = definitions ?? BadgeCatalogue.all,
        _earned = {for (final badge in earned) badge.badgeId: badge};

  @override
  Future<List<BadgeModel>> fetchDefinitions() async => _definitions;

  @override
  Future<List<UserBadgeModel>> fetchEarnedBadges(String userId) async =>
      _earned.values.toList(growable: false);

  @override
  Future<void> awardBadges({
    required String userId,
    required List<BadgeModel> badges,
    DateTime? earnedAt,
  }) async {
    final stamp = earnedAt ?? DateTime.now();
    for (final badge in badges) {
      // putIfAbsent, not [], so a re-award leaves the original date alone —
      // the same guarantee the Firestore implementation gives.
      _earned.putIfAbsent(
        badge.id,
        () => UserBadgeModel(badgeId: badge.id, dateEarned: stamp),
      );
    }
  }
}

/// A tourist part-way through the badge set, for demo mode.
///
/// Chosen so every gallery state is visible at once: First Steps, Explorer
/// and Trailblazer unlocked, and the rest locked — Penang Wanderer showing
/// partial progress on distance, Point Collector on points, Green Strider on
/// carbon, so one screenshot exercises all four badge criteria.
/// The totals are internally consistent with the points formula — 7 check-ins
/// at 10 points each plus 124 points of distance bonus for 12.4 km — so the
/// numbers on screen survive a tutor checking them against the rule.
class DemoRewardData {
  DemoRewardData._();

  static const String userId = 'demo_tourist';

  static const RewardModel stats = RewardModel(
    userId: userId,
    totalPoints: 194,
    totalCheckIns: 7,
    totalDistanceMetres: 12400,
    totalCarbonSavedKg: 2.61,
    totalCaloriesBurned: 744.0,
  );

  static List<UserBadgeModel> get earnedBadges => [
        UserBadgeModel(
          badgeId: BadgeCatalogue.firstSteps.id,
          dateEarned: DateTime(2026, 7, 2, 15, 50),
        ),
        UserBadgeModel(
          badgeId: BadgeCatalogue.explorer.id,
          dateEarned: DateTime(2026, 7, 19, 11, 05),
        ),
        UserBadgeModel(
          badgeId: BadgeCatalogue.trailblazer.id,
          dateEarned: DateTime(2026, 8, 2, 16, 40),
        ),
      ];

  /// The seven journeys behind [stats], newest first.
  ///
  /// Deliberately reconciled with everything else on this class rather than
  /// invented: the distances sum to 12,400 m, the points to 194 by the real
  /// formula (10 flat plus metres/100 each), the carbon to 2.61 kg at
  /// 0.21 kg/km, and the calories to 744. The earliest journey is 2 July, the
  /// fifth lands on 19 July, and the sixth pushes the running total past 10 km
  /// on 2 August — exactly the three dates [earnedBadges] gives for First
  /// Steps, Explorer and Trailblazer. A tutor adding up the journal gets the
  /// dashboard.
  static List<JournalEntryModel> get entries => [
        _entry('Kek Lok Si Temple', 'demo-kek-lok-si',
            DateTime(2026, 8, 14, 9, 20), 2.2, 32),
        _entry('Penang Botanic Gardens', 'demo-botanic-gardens',
            DateTime(2026, 8, 2, 17, 05), 1.4, 24),
        _entry('Chew Jetty', 'demo-chew-jetty',
            DateTime(2026, 7, 19, 10, 45), 2.6, 36),
        _entry('Street of Harmony', 'demo-street-of-harmony',
            DateTime(2026, 7, 15, 16, 30), 1.8, 28),
        _entry('Cheong Fatt Tze Mansion', 'demo-blue-mansion',
            DateTime(2026, 7, 12, 11, 15), 0.9, 19),
        _entry('Penang Hill', 'demo-penang-hill',
            DateTime(2026, 7, 8, 8, 40), 2.3, 33),
        _entry('Fort Cornwallis', 'demo-fort-cornwallis',
            DateTime(2026, 7, 2, 15, 50), 1.2, 22),
      ];

  /// Carbon and calories are derived rather than typed in, so the per-journey
  /// figures cannot drift away from the rates the Walking module applies.
  static JournalEntryModel _entry(
    String name,
    String id,
    DateTime at,
    double km,
    int points,
  ) {
    return JournalEntryModel(
      checkInId: id,
      destinationName: name,
      destinationId: id,
      checkInTime: at,
      distanceKm: km,
      pointsAwarded: points,
      carbonSavedKg: km * 0.21,
      caloriesBurned: km * 60,
      transportMode: TransportMode.walking,
    );
  }

  static InMemoryRewardDao rewardDao() => InMemoryRewardDao(initial: stats);

  static InMemoryBadgeDao badgeDao() =>
      InMemoryBadgeDao(earned: earnedBadges);

  static InMemoryJournalDao journalDao() =>
      InMemoryJournalDao(entries: entries);
}

/// Completed journeys held in memory.
class InMemoryJournalDao implements JournalDao {
  InMemoryJournalDao({List<JournalEntryModel>? entries})
      : _entries = entries ?? const <JournalEntryModel>[];

  final List<JournalEntryModel> _entries;

  @override
  Future<List<JournalEntryModel>> fetchEntries(
    String userId, {
    int limit = 50,
  }) async {
    // Sorted here rather than trusted from the caller, so this behaves like
    // the Firestore implementation's orderBy however the list was built.
    final sorted = [..._entries]
      ..sort((a, b) => b.checkInTime.compareTo(a.checkInTime));
    return sorted.take(limit).toList();
  }
}
