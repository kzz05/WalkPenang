// walking_journal_screen.dart — Module 5 View
// Chronological list of completed check-ins, most recent first. UC520 / FR-R03

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../controllers/journal_controller.dart';
import '../../dao/journal_dao.dart';
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

  void _openEntry(JournalEntryModel entry) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => JournalDetailScreen(entry: entry)),
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
                if (_showsFilter) ...[
                  const SizedBox(height: 16),
                  _JournalFilterPills(controller: _controller),
                ],
                const SizedBox(height: 20),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Only shown over an actual list. Offering "Today" above a failed read, a
  /// signed-out tourist, or a journal with nothing in it would be a control
  /// with nothing to control.
  bool get _showsFilter =>
      _controller.error == null &&
      _controller.userId.isNotEmpty &&
      _controller.entries.isNotEmpty;

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
      );
    }

    if (_controller.userId.isEmpty) {
      return const RewardMessageState(
        title: 'Sign in to see your journal',
        body: 'Your journeys are tied to your account.',
      );
    }

    if (_controller.isEmpty) {
      return const RewardMessageState(
        title: 'No journeys yet',
        body: 'Pick a place on the map and walk there — '
            'completed journeys show up here.',
      );
    }

    // Distinct from "No journeys yet" above: this tourist has a journal, it
    // just has nothing in it from today. Saying "no journeys yet" here would
    // read as their history having been lost.
    final visible = _controller.visibleEntries;
    if (visible.isEmpty) {
      return RewardMessageState(
        title: 'No journeys today',
        body: 'Pick a place on the map and walk there — '
            "today's journeys show up here.",
        actionLabel: 'Show all journeys',
        onAction: () => _controller.setFilter(JournalFilter.all),
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
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final entry = visible[index];
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

/// The journal's one control: All / Today.
///
/// Drawn from the app's own tokens rather than a stock [ChoiceChip] or a
/// [TabBar], matching the map's radius chips and the route summary's mode tabs
/// — those are the two pill controls this app already has, and a third
/// variant would be the odd one out.
class _JournalFilterPills extends StatelessWidget {
  final JournalController controller;

  const _JournalFilterPills({required this.controller});

  @override
  Widget build(BuildContext context) {
    // Wrap rather than Row, for the same reason the radius chips use one: at a
    // large system font size the pills would overflow a Row's right edge.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final filter in JournalFilter.values)
          _FilterPill(
            key: Key('journalFilter_${filter.name}'),
            label: filter == JournalFilter.all ? 'All' : 'Today',
            isSelected: controller.filter == filter,
            onTap: () => controller.setFilter(filter),
          ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterPill({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.primary : AppColors.card,
      borderRadius: AppRadius.mdAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Text(
            label,
            style: AppType.monoValue.copyWith(
              color: isSelected ? AppColors.onPrimary : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}
