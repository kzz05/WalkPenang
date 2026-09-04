// ---------------------------------------------------------------------------
// leaderboard_screen.dart
// Module 5 — Reward & Achievement
// Use Case : UC540 Compare standing against other tourists
// FR       : FR-R06 Leaderboard
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// Every tourist ranked by lifetime points, highest first.
//
// The screen answers one question — who is ahead, and by how much — so the
// winner is on a podium at the top, the tourist's own row is outlined
// wherever it falls, and the gap to the position above them is stated in
// points rather than left to be worked out from two numbers.
//
// Reached from the statistics dashboard, and built the same way it is: the
// controller is injected by tests and by demo mode, and otherwise wired to
// Firestore for the signed-in tourist.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../controllers/leaderboard_controller.dart';
import '../../dao/in_memory_reward_data.dart';
import '../../dao/leaderboard_dao.dart';
import '../../dao/reward_dao.dart';
import '../../theme/app_theme.dart';
import '../../widgets/reward/leaderboard_row.dart';
import '../../widgets/reward/message_state.dart';
import '../widgets/wp_components.dart';

class LeaderboardScreen extends StatefulWidget {
  /// Injected by tests and by demo mode. Left null in the app, where the
  /// screen builds a Firestore-backed controller for the signed-in tourist —
  /// matching StatsDashboardScreen and WalkingJournalScreen.
  final LeaderboardController? controller;

  const LeaderboardScreen({super.key, this.controller});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late LeaderboardController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? _liveController();
    _controller.load();
  }

  LeaderboardController _liveController() {
    final firestore = FirebaseFirestore.instance;
    return LeaderboardController(
      userId: FirebaseAuth.instance.currentUser?.uid ?? '',
      leaderboardDao: FirestoreLeaderboardDao(firestore: firestore),
      // Supplied so that opening the board republishes the tourist's own row
      // from their real totals — which is what puts a tourist who earned
      // points before this screen existed onto the board at all.
      rewardDao: FirestoreRewardDao(firestore: firestore),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Swaps between live Firestore data and the seeded in-memory board, as the
  /// dashboard and the journal do — so the screen can be demonstrated with a
  /// full field of tourists rather than however many have installed the app.
  /// Debug builds only.
  void _toggleDemoMode() {
    final wasDemo = _controller.isDemo;
    final previous = _controller;

    setState(() {
      _controller = wasDemo
          ? _liveController()
          : LeaderboardController(
              userId: DemoRewardData.userId,
              leaderboardDao: DemoRewardData.leaderboardDao(),
              isDemo: true,
            );
    });

    previous.dispose();
    _controller.load();
  }

  Widget? _demoAction() {
    if (!kDebugMode) return null;
    return WpOutlineButton(
      label: _controller.isDemo ? 'use live data' : 'preview with demo data',
      onPressed: _toggleDemoMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WpBackBar(onBack: () => Navigator.of(context).maybePop()),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text('Leaderboard', style: AppType.display),
                    ),
                    if (_controller.isDemo)
                      const WpChip('demo data', uppercase: true),
                  ],
                ),
                const SizedBox(height: 6),
                const WpMonoLabel('ranked by lifetime points'),
                const SizedBox(height: 20),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.isLoading && _controller.entries.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    // A failed read and an empty board both show nothing, and they must not
    // look the same — one is a problem to retry, the other is a normal
    // starting point on a project nobody has walked for yet.
    if (_controller.error != null) {
      return RewardMessageState(
        title: 'Could not load the leaderboard',
        body: 'Check your connection and try again.',
        // The real exception in debug builds only. "Check your connection" is
        // the wrong advice for a security rule denying the read, which is the
        // most likely failure here and needs a rules deploy to fix.
        detail: kDebugMode ? '${_controller.error}' : null,
        actionLabel: 'retry',
        onAction: _controller.load,
        secondary: _demoAction(),
      );
    }

    if (_controller.isEmpty) {
      return RewardMessageState(
        title: 'Nobody on the board yet',
        body: 'Complete a walk and check in — the first tourist to earn '
            'points takes first place.',
        secondary: _demoAction(),
      );
    }

    return RefreshIndicator(
      onRefresh: _controller.load,
      color: AppColors.primary,
      child: ListView(
        // Always scrollable, so pull-to-refresh still works on a board too
        // short to overflow.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          LeaderboardPodium(
            places: _controller.podium,
            currentUserId: _controller.userId,
          ),
          const SizedBox(height: 24),
          _buildStandingBanner(),
          if (_controller.chasingPack.isNotEmpty) ...[
            const WpMonoLabel('everyone else'),
            const SizedBox(height: 10),
            for (final ranked in _controller.chasingPack) ...[
              LeaderboardRowTile(
                ranked: ranked,
                isCurrentUser: ranked.entry.userId == _controller.userId,
              ),
              const SizedBox(height: 10),
            ],
          ],
          if (_controller.isCurrentUserOffBoard) ...[
            const SizedBox(height: 6),
            const WpMonoLabel('your standing'),
            const SizedBox(height: 10),
            LeaderboardRowTile(
              ranked: _controller.currentUserEntry!,
              isCurrentUser: true,
              // The exact position is not knowable from the client without
              // counting every tourist ahead, so the board says where it
              // stopped rather than inventing a number.
              rankOverride: '${_controller.limit}+',
            ),
          ],
          if (kDebugMode) ...[
            const SizedBox(height: 20),
            _demoAction() ?? const SizedBox.shrink(),
          ],
        ],
      ),
    );
  }

  /// The one line of feedback the screen exists to deliver: where the tourist
  /// stands, and what it would take to move up.
  ///
  /// Rendered as a card rather than a caption because it is the thing they
  /// came for — "18 points off 3rd" is what sends somebody out walking, and
  /// "you are 4th" on its own does not.
  Widget _buildStandingBanner() {
    final own = _controller.currentUserEntry;

    if (_controller.userId.isEmpty) {
      return _banner(
        title: 'Sign in to join the board',
        body: 'Points are tied to your account.',
      );
    }

    if (own == null) {
      return _banner(
        title: 'You are not on the board yet',
        body: 'Check in at a place you walked to and your first points put '
            'you on it.',
      );
    }

    if (own.isLeader) {
      return _banner(
        title: 'You are in first place',
        body: '${own.entry.totalPoints} points. Keep walking to hold it.',
        emphasised: true,
      );
    }

    final gap = _controller.pointsToNextRank;
    final position = _controller.isCurrentUserOffBoard
        ? 'below the top ${_controller.limit}'
        : 'ranked #${own.rank}';

    return _banner(
      title: 'You are $position',
      body: gap == null
          ? '${own.entry.totalPoints} points so far.'
          // A walk of 1 km is 20 points, so quoting the gap in points is
          // something the tourist can convert into a walk themselves.
          : '$gap ${gap == 1 ? "point" : "points"} behind the tourist above '
              'you.',
      emphasised: true,
    );
  }

  Widget _banner({
    required String title,
    required String body,
    bool emphasised = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: emphasised ? AppColors.surface : AppColors.card,
          borderRadius: AppRadius.smAll,
          border: emphasised ? null : Border.all(color: AppColors.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: AppType.heading.copyWith(
                fontSize: 16,
                color: emphasised ? AppColors.onSurface : AppColors.onPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: AppType.body.copyWith(
                fontSize: 13,
                color:
                    emphasised ? AppColors.onSurfaceMuted : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
