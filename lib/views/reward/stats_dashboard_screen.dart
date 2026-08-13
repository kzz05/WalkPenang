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
import '../../dao/in_memory_reward_data.dart';
import '../../dao/reward_dao.dart';
import '../../models/badge_model.dart';
import '../../models/check_in_result.dart';
import '../../theme/app_theme.dart';
import '../../widgets/reward/badge_card.dart';
import '../../widgets/reward/badge_unlock_notification.dart';
import '../../widgets/reward/points_notification.dart';
import '../../widgets/reward/stat_summary_card.dart';
import '../widgets/wp_components.dart';
import 'badge_detail_screen.dart';
import 'badge_gallery_screen.dart';

class StatsDashboardScreen extends StatefulWidget {
  /// Injected by tests and by demo mode. Left null in the app, where the
  /// screen builds a Firestore-backed controller for the signed-in tourist.
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
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Swaps the screen between live Firestore data and the seeded in-memory
  /// tourist. Debug builds only — it exists so the reward screens can be
  /// walked through without 50 km of real walking behind them.
  void _toggleDemoMode() {
    final wasDemo = _controller.isDemo;
    final previous = _controller;

    setState(() {
      _controller = wasDemo
          ? _liveController()
          : RewardController(
              userId: DemoRewardData.userId,
              rewardDao: DemoRewardData.rewardDao(),
              badgeDao: DemoRewardData.badgeDao(),
              isDemo: true,
            );
    });

    previous.dispose();
    _controller.load();
  }

  /// The last check-in handed to the controller, kept so it can be submitted
  /// a second time to demonstrate the idempotency guard.
  CheckInResult? _lastCheckIn;

  /// Runs a *new* check-in through the real award path — points formula,
  /// ledger guard, badge evaluation — against the in-memory DAOs.
  ///
  /// Only offered in demo mode. Against Firestore this would write a reward
  /// for a check-in that never happened, so it is deliberately not available
  /// on live data.
  Future<void> _simulateCheckIn() {
    final now = DateTime.now();
    return _award(
      CheckInResult(
        // Unique per press, so each one is a genuinely new check-in rather
        // than a retry the guard would reject. A tourist who visits five
        // attractions has earned five awards.
        checkInId: 'demo_${now.microsecondsSinceEpoch}',
        userId: DemoRewardData.userId,
        destinationId: 'demo_destination',
        // Values Module 4 would have calculated. Module 5 never derives them.
        distanceKm: 2.1,
        carbonSavedKg: 0.44,
        caloriesBurned: 126.0,
        checkInTime: now,
      ),
    );
  }

  /// Re-submits the previous check-in unchanged, reusing its checkInId.
  ///
  /// This is the retry Module 4 would make after a dropped response or an app
  /// restart mid-award, and it must pay out nothing the second time (T-R01.5).
  /// Demonstrating it on screen matters because the guard is invisible when it
  /// works — the totals simply do not move.
  Future<void> _repeatLastCheckIn() {
    final last = _lastCheckIn;
    if (last == null) return Future.value();
    return _award(last);
  }

  Future<void> _award(CheckInResult result) async {
    final outcome = await _controller.onCheckInVerified(result);

    if (!mounted) return;
    setState(() => _lastCheckIn = result);
    showPointsConfirmation(context, outcome);

    final unlocked = outcome.newlyEarnedBadgeIds
        .map(BadgeCatalogue.byId)
        .whereType<BadgeModel>()
        .toList();
    if (unlocked.isNotEmpty) {
      await showBadgeUnlockConfirmation(context, unlocked);
    }
  }

  Future<void> _openGallery() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BadgeGalleryScreen(controller: _controller),
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
      return _MessageState(
        title: 'Could not load rewards',
        body: 'Check your connection and try again.',
        // The real exception in debug builds only. "Check your connection" is
        // the wrong advice for a permission-denied rule or a missing index,
        // and hiding which one it was makes the failure much harder to fix.
        detail: kDebugMode ? '${_controller.error}' : null,
        actionLabel: 'retry',
        onAction: _controller.load,
        secondary: _demoAction(),
      );
    }

    if (_controller.userId.isEmpty) {
      return _MessageState(
        title: 'Sign in to see rewards',
        body: 'Points and badges are tied to your account.',
        secondary: _demoAction(),
      );
    }

    final stats = _controller.stats;

    return RefreshIndicator(
      onRefresh: _controller.load,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          Row(
            children: [
              Expanded(child: Text('Rewards', style: AppType.display)),
              if (_controller.isDemo)
                const WpChip('demo data', uppercase: true),
              if (kDebugMode) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _toggleDemoMode,
                  tooltip: _controller.isDemo
                      ? 'Switch to live data'
                      : 'Preview with demo data',
                  icon: Icon(
                    _controller.isDemo
                        ? Icons.cloud_outlined
                        : Icons.science_outlined,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ],
          ),
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

          if (_controller.isDemo) ...[
            const SizedBox(height: 12),
            WpPrimaryButton(
              label: 'simulate a check-in',
              onPressed: _simulateCheckIn,
            ),
            const SizedBox(height: 10),
            // Greyed until there is a check-in to repeat, because before the
            // first press there is nothing to retry.
            _DisableableOutlineButton(
              label: 'repeat last check-in',
              onPressed: _lastCheckIn == null ? null : _repeatLastCheckIn,
            ),
            const SizedBox(height: 10),
            const WpMonoLabel(
              'demo only — runs the real points and badge rules against '
              'in-memory data. repeating a check-in awards nothing.',
              align: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  /// Offered alongside the empty and error states so the screens can still be
  /// demonstrated when there is nothing to read.
  Widget? _demoAction() {
    if (!kDebugMode || _controller.isDemo) return null;
    return WpOutlineButton(
      label: 'preview with demo data',
      onPressed: _toggleDemoMode,
    );
  }
}

/// WpOutlineButton with a disabled state.
///
/// Local to this screen rather than added to wp_components.dart, because that
/// file is the shared design system and only the demo controls need this.
class _DisableableOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _DisableableOutlineButton({required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.outline),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
        // The colour is set on the TextStyle, not through the button's
        // foregroundColor: AppType.button carries its own colour, which would
        // win over the button theme and leave a disabled label looking live.
        child: Text(
          label.toUpperCase(),
          style: AppType.button.copyWith(
            color: enabled ? AppColors.onPrimary : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

/// The three badges laid out across the dashboard.
class _BadgeStrip extends StatelessWidget {
  final RewardController controller;
  final ValueChanged<BadgeModel> onTapBadge;

  const _BadgeStrip({required this.controller, required this.onTapBadge});

  @override
  Widget build(BuildContext context) {
    final definitions = controller.definitions;
    if (definitions.isEmpty) {
      return const WpMonoLabel('no badges defined yet');
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < definitions.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: BadgeCard(
                badge: definitions[i],
                unlocked: controller.hasEarned(definitions[i].id),
                dateEarned: controller.earnedBadge(definitions[i].id)?.dateEarned,
                progress: controller.progressTowards(definitions[i]),
                remainingLabel: controller.remainingLabel(definitions[i]),
                onTap: () => onTapBadge(definitions[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shared layout for the empty, signed-out and error states.
class _MessageState extends StatelessWidget {
  final String title;
  final String body;

  /// Raw diagnostic text, shown in debug builds only.
  final String? detail;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? secondary;

  const _MessageState({
    required this.title,
    required this.body,
    this.detail,
    this.actionLabel,
    this.onAction,
    this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, textAlign: TextAlign.center, style: AppType.heading),
            const SizedBox(height: 10),
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(color: AppColors.muted),
            ),
            if (detail != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: AppRadius.smAll,
                  border: Border.all(color: AppColors.outline),
                ),
                child: SelectableText(
                  detail!,
                  style: AppType.monoValue.copyWith(
                    fontSize: 11,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              WpPrimaryButton(label: actionLabel!, onPressed: onAction!),
            ],
            if (secondary != null) ...[
              const SizedBox(height: 12),
              secondary!,
            ],
          ],
        ),
      ),
    );
  }
}
