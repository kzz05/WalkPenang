// walking_journal_screen.dart — Module 5 View
// Chronological list of completed check-ins, most recent first. UC520 / FR-R03

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../controllers/journal_controller.dart';
import '../../dao/in_memory_reward_data.dart';
import '../../dao/journal_dao.dart';
import '../../debug/demo_journey_flow_view.dart';
import '../../models/journal_entry_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/reward/journal_entry_tile.dart';
import '../../widgets/reward/message_state.dart';
import '../widgets/wp_components.dart';
import 'journal_detail_screen.dart';

/// The tourist's walking history — every completed journey, newest first.
///
/// Reached from the bottom nav's walk tab. That slot used to open UC-W01's
/// transport-mode picker, which became redundant once the map's route summary
/// grew its own Walk/Drive/Bus tabs and journeys started from a tapped place.
class WalkingJournalScreen extends StatefulWidget {
  /// Injected by tests. Production builds their own from the signed-in
  /// tourist, matching StatsDashboardScreen.
  final JournalController? controller;

  const WalkingJournalScreen({super.key, this.controller});

  @override
  State<WalkingJournalScreen> createState() => _WalkingJournalScreenState();
}

class _WalkingJournalScreenState extends State<WalkingJournalScreen> {
  late JournalController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? _liveController();
    _controller.load();
  }

  JournalController _liveController() {
    return JournalController(
      userId: FirebaseAuth.instance.currentUser?.uid ?? '',
      journalDao: FirestoreJournalDao(firestore: FirebaseFirestore.instance),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Swaps between live Firestore data and the seeded in-memory tourist,
  /// exactly as the statistics dashboard does — so the journal can be shown
  /// with seven journeys behind it rather than however many the demo phone
  /// has actually walked. Debug builds only.
  void _toggleDemoMode() {
    final wasDemo = _controller.isDemo;
    final previous = _controller;

    setState(() {
      _controller = wasDemo
          ? _liveController()
          : JournalController(
              userId: DemoRewardData.userId,
              journalDao: DemoRewardData.journalDao(),
              isDemo: true,
            );
    });

    previous.dispose();
    _controller.load();
  }

  void _openEntry(JournalEntryModel entry) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => JournalDetailScreen(entry: entry)),
    );
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
                      child: Text('Walking journal', style: AppType.display),
                    ),
                  ],
                ),
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

    // A failed read and a tourist who has walked nothing both show an empty
    // list, and they must not look the same — one is a problem to retry, the
    // other is a normal starting point.
    if (_controller.error != null) {
      return RewardMessageState(
        title: 'Could not load your journal',
        body: 'Check your connection and try again.',
        // The real exception in debug builds only. "Check your connection" is
        // the wrong advice for a missing composite index, which is the most
        // likely failure here and comes with a console link that fixes it.
        detail: kDebugMode ? '${_controller.error}' : null,
        actionLabel: 'retry',
        onAction: _controller.load,
        secondary: _demoAction(),
      );
    }

    if (_controller.userId.isEmpty) {
      return RewardMessageState(
        title: 'Sign in to see your journal',
        body: 'Your journeys are tied to your account.',
        secondary: _demoAction(),
      );
    }

    if (_controller.isEmpty) {
      return RewardMessageState(
        title: 'No journeys yet',
        body: 'Pick a place on the map and walk there — '
            'completed journeys show up here.',
        secondary: _demoAction(),
      );
    }

    final now = DateTime.now();

    return RefreshIndicator(
      onRefresh: _controller.load,
      color: AppColors.primary,
      child: ListView.separated(
        // Always scrollable, so pull-to-refresh still works on a list too
        // short to overflow.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: _controller.entries.length + (kDebugMode ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == _controller.entries.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                children: [
                  _demoAction() ?? const SizedBox.shrink(),
                  const SizedBox(height: 10),
                  // The lecturer demo entry point, kept when walking_view.dart
                  // was deleted — it drives the real journey screens against
                  // fakes with no GPS or Firebase.
                  WpOutlineButton(
                    label: 'demo walking journey',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DemoJourneyFlowView(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final entry = _controller.entries[index];
          return JournalEntryTile(
            entry: entry,
            now: now,
            onTap: () => _openEntry(entry),
          );
        },
      ),
    );
  }
}
