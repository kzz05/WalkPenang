// ---------------------------------------------------------------------------
// stats_dashboard_screen.dart
// Module 5 — Reward & Achievement
// Use Case : UC530 View statistics dashboard, UC510 Unlock badges
// FR       : FR-R04 Statistics Dashboard, FR-R05 Badge Gallery
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// The Reward module's landing screen: cumulative totals across the top, the
// badge set underneath, and a route into the full gallery.
//
// Owns the RewardController for the whole module. The gallery and detail
// screens are handed the same instance rather than creating their own, so a
// badge unlocked here is already unlocked when the tourist navigates on
// without a second round of Firestore reads.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../controllers/reward_controller.dart';
import '../../dao/badge_dao.dart';
import '../../dao/leaderboard_dao.dart';
import '../../dao/reward_dao.dart';
import '../../models/badge_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/reward/badge_card.dart';
import '../../widgets/reward/message_state.dart';
import '../../widgets/reward/stat_summary_card.dart';
import '../widgets/wp_components.dart';
import 'badge_detail_screen.dart';
import 'badge_gallery_screen.dart';
import 'leaderboard_screen.dart';

class StatsDashboardScreen extends StatefulWidget {
  /// Injected by tests. Left null in the app, where the screen builds a
  /// Firestore-backed controller for the signed-in tourist.
  final RewardController? controller;

  const StatsDashboardScreen({super.key, this.controller});

  @override
  State<StatsDashboardScreen> createState() => _StatsDashboardScreenState();
}

class _StatsDashboardScreenState extends State<StatsDashboardScreen> {
  late RewardController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? _liveController();
    _controller.load();
  }

  /// A controller wired to Firestore for the currently signed-in tourist.
  ///
  /// The user ID comes from Module 1's auth session. An empty ID (nobody
  /// signed in) still produces a valid controller — it simply reads no
  /// totals, which the empty state below handles.
  RewardController _liveController() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final firestore = FirebaseFirestore.instance;
    return RewardController(
      userId: uid,
      rewardDao: FirestoreRewardDao(firestore: firestore),
      badgeDao: FirestoreBadgeDao(firestore: firestore),
      // Supplied so a check-in updates the tourist's public standing as part
      // of the same award (UC540), rather than only when they next open the
      // leaderboard.
      leaderboardDao: FirestoreLeaderboardDao(firestore: firestore),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openGallery() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BadgeGalleryScreen(controller: _controller),
      ),
    );
  }

  /// The leaderboard (UC540). Pushed rather than embedded: it ranks every
  /// tourist, while everything else on this screen is about one tourist, and
  /// mixing the two under one scroll makes neither readable.
  Future<void> _openLeaderboard() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LeaderboardScreen(),
      ),
    );
  }

  Future<void> _openBadge(BadgeModel badge) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BadgeDetailScreen(
          badge: badge,
          controller: _controller,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: WpBackBar(onBack: () => Navigator.of(context).pop()),
        ),
        Expanded(child: _buildContent(context)),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // A failed read and a tourist with no check-ins both produce zeroes, and
    // they must not look the same on screen — one is a problem to retry, the
    // other is a normal starting point.
    if (_controller.error != null) {
      return RewardMessageState(
        title: 'Could not load rewards',
        body: 'Check your connection and try again.',
        // The real exception in debug builds only. "Check your connection" is
        // the wrong advice for a permission-denied rule or a missing index,
        // and hiding which one it was makes the failure much harder to fix.
        detail: kDebugMode ? '${_controller.error}' : null,
        actionLabel: 'retry',
        onAction: _controller.load,
      );
    }

    if (_controller.userId.isEmpty) {
      return const RewardMessageState(
        title: 'Sign in to see rewards',
        body: 'Points and badges are tied to your account.',
      );
    }

    final stats = _controller.stats;

    return RefreshIndicator(
      onRefresh: _controller.load,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          Text('Rewards', style: AppType.display),
          const SizedBox(height: 6),
          const WpMonoLabel('your walking totals'),
          const SizedBox(height: 20),

          PointsBalanceCard(
            totalPoints: stats.totalPoints,
            totalCheckIns: stats.totalCheckIns,
          ),
          const SizedBox(height: 12),

          // Distance, carbon and calories are Module 4's figures, accumulated
          // by Module 5 and only formatted here.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: StatSummaryCard(
                    label: 'distance',
                    value: stats.totalDistanceKm.toStringAsFixed(1),
                    unit: 'km',
                    icon: Icons.directions_walk,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatSummaryCard(
                    label: 'carbon saved',
                    value: stats.totalCarbonSavedKg.toStringAsFixed(2),
                    unit: 'kg',
                    icon: Icons.eco_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatSummaryCard(
                    label: 'calories',
                    value: stats.totalCaloriesBurned.round().toString(),
                    unit: 'kcal',
                    icon: Icons.local_fire_department_outlined,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          Row(
            children: [
              const Expanded(child: WpMonoLabel('badges')),
              WpMonoLabel(
                '${_controller.unlockedBadgeCount} of '
                '${_controller.totalBadgeCount} unlocked',
                color: AppColors.onPrimary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _BadgeStrip(controller: _controller, onTapBadge: _openBadge),
          const SizedBox(height: 16),
          WpOutlineButton(label: 'view all badges', onPressed: _openGallery),
          const SizedBox(height: 10),
          WpOutlineButton(label: 'leaderboard', onPressed: _openLeaderboard),
        ],
      ),
    );
  }
}

/// Every badge in the catalogue, laid out as a horizontally scrolling strip.
///
/// The cards are a fixed width rather than Expanded slots. The catalogue grew
/// from three badges to ten, and dividing one row between ten Expanded cards
/// left about 1dp for a 72dp emblem — a width SizedBox silently enforces
/// instead of overflowing, so the artwork was crushed with nothing in the
/// console to say why. A fixed width keeps every emblem at its intended size
/// however many badges the catalogue holds; the rest scroll into view, and
/// "view all badges" still opens the full grid.
class _BadgeStrip extends StatelessWidget {
  /// The 72dp emblem plus BadgeCard's 24dp of padding, with the remainder
  /// left for the name — close to the gallery tile's content width, so a
  /// caption ellipsises in the same place on both screens.
  static const double _cardWidth = 132;

  final RewardController controller;
  final ValueChanged<BadgeModel> onTapBadge;

  const _BadgeStrip({required this.controller, required this.onTapBadge});

  @override
  Widget build(BuildContext context) {
    final definitions = controller.definitions;
    if (definitions.isEmpty) {
      return const WpMonoLabel('no badges defined yet');
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // IntrinsicHeight sits inside the scroll view so an unlocked card (date
      // pill) and a locked one (progress bar plus caption) still share a
      // height. The children are a fixed width, which keeps the intrinsic
      // pass well defined.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < definitions.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              SizedBox(
                width: _cardWidth,
                child: BadgeCard(
                  badge: definitions[i],
                  unlocked: controller.hasEarned(definitions[i].id),
                  dateEarned:
                      controller.earnedBadge(definitions[i].id)?.dateEarned,
                  progress: controller.progressTowards(definitions[i]),
                  remainingLabel: controller.remainingLabel(definitions[i]),
                  onTap: () => onTapBadge(definitions[i]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shared layout for the empty, signed-out and error states.
