// Walking & Carbon Module — the real journey-completion flow (UC-W05,
// UC-W06), pushed by PreWalkSummaryView once Start Journey succeeds.
//
// This widget owns a JourneyCompletionController wired to real GPS
// (ArrivalVerificationService's default LocationArrivalVerificationService),
// real Firestore persistence (FirestoreCheckInRepository) and the real
// Reward Module (RewardController, constructed exactly the way the reward
// screens already do — see stats_dashboard_screen.dart). It does not modify
// ActiveWalkingView, VerifyLocationView or JourneyCompletedView — it only
// swaps between them based on JourneyCompletionController.step.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../controllers/journey_completion_controller.dart';
import '../controllers/reward_controller.dart';
import '../controllers/walking_controller.dart';
import '../dao/badge_dao.dart';
import '../dao/reward_dao.dart';
import '../services/check_in_repository.dart';
import '../services/journey_progress_service.dart';
import '../services/map_service.dart';
import '../services/navigation_launcher_service.dart';
import '../theme/app_theme.dart';
import 'active_walking_view.dart';
import 'journey_completed_view.dart';
import 'reward/stats_dashboard_screen.dart';
import 'verify_location_view.dart';

class JourneyFlowView extends StatefulWidget {
  /// The same WalkingController instance PreWalkSummaryView used — read
  /// once here for its already-validated routeSummary and its already
  /// computed carbon/calorie figures (US-W03/US-W04), never recomputed.
  final WalkingController walkingController;

  /// Opens the app's own turn-by-turn view for this journey, supplied by
  /// route_summary_view where the RouteResult lives.
  ///
  /// When null — the debug journey flow, which runs with no map — the Active
  /// Walking screen falls back to
  /// [JourneyCompletionController.openExternalNavigation] and its Google Maps
  /// deep link.
  final void Function(BuildContext)? onOpenNavigation;

  const JourneyFlowView({
    super.key,
    required this.walkingController,
    this.onOpenNavigation,
  });

  @override
  State<JourneyFlowView> createState() => _JourneyFlowViewState();
}

class _JourneyFlowViewState extends State<JourneyFlowView> {
  late final JourneyCompletionController _controller;

  @override
  void initState() {
    super.initState();

    // Guaranteed non-null/valid here: PreWalkSummaryView only reaches this
    // screen after WalkingController.startJourney() succeeds, which itself
    // requires a non-null, valid routeSummary.
    final summary = widget.walkingController.routeSummary!;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final firestore = FirebaseFirestore.instance;

    _controller = JourneyCompletionController(
      routeSummary: summary,
      userId: uid,
      carbonSavedKg: widget.walkingController.carbonSavedKg,
      caloriesBurned: widget.walkingController.caloriesBurned,
      rewardService: RewardController(
        userId: uid,
        rewardDao: FirestoreRewardDao(firestore: firestore),
        badgeDao: FirestoreBadgeDao(firestore: firestore),
      ),
      checkInRepository: FirestoreCheckInRepository(firestore: firestore),
      // Live KM COVERED / MIN REMAINING on the Active Walking screen.
      journeyProgressService: LocationJourneyProgressService(),
      navigationLauncherService: NavigationLauncherService(MapService()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// "Back to Explore" / the completed screen's own back arrow both return
  /// the tourist to the app's root (Home), matching the Figma copy — there
  /// is no "previous state" to go back to once a journey is recorded.
  void _returnHome() {
    Navigator.of(context, rootNavigator: true)
        .popUntil((route) => route.isFirst);
  }

  void _openRewards() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StatsDashboardScreen()),
    );
  }

  /// Leaving an active journey throws away everything walked so far, and the
  /// back control necessarily sits under a thumb holding the phone — so it
  /// asks first. Answering "No" simply closes the dialog: nothing here
  /// touches the controller, so the elapsed timer and the progress stream
  /// keep running untouched.
  Future<bool> _confirmEndJourney() async {
    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('End Journey?'),
        content: const Text(
          'Are you sure you want to end your current journey?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('No', style: AppType.button.copyWith(fontSize: 14)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Yes, End Journey',
              style: AppType.button.copyWith(
                fontSize: 14,
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
    return shouldEnd ?? false;
  }

  /// "Yes, End Journey": abandons the journey without completing it — no
  /// check-in, no reward — and returns the tourist to the Journey Preview
  /// screen by popping *this* route, the one PreWalkSummaryView pushed.
  /// Popping rather than pushing is what keeps a second Journey Preview off
  /// the stack.
  Future<void> _handleEndJourneyRequest() async {
    if (!await _confirmEndJourney()) return;
    if (!mounted) return;

    _controller.cancelJourney();
    Navigator.of(context).pop();
  }

  /// The Android system back button / back gesture, routed to whatever the
  /// step currently on screen does with its own back control — so the
  /// hardware gesture and the drawn arrow always agree.
  void _handleSystemBack() {
    switch (_controller.step) {
      case JourneyStep.active:
        _handleEndJourneyRequest();
      case JourneyStep.verifyingLocation:
        // Back out of verification only, never out of the journey: the
        // tourist returns to Active Walking with the timer still running.
        _controller.continueWalking();
      case JourneyStep.completed:
        _returnHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    // canPop: false on every step — the journey screens are a state
    // machine inside one route, so a system back has to be interpreted
    // (see [_handleSystemBack]) rather than allowed to tear the route off
    // the stack mid-journey.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleSystemBack();
      },
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          switch (_controller.step) {
            case JourneyStep.active:
              return ActiveWalkingView(
                data: _controller.activeWalkingUiData,
                onBack: _handleEndJourneyRequest,
                // In-app navigation when the Map module handed us a way to
                // open it; the external Google Maps hand-off only as a
                // fallback, which is what the debug flow still takes.
                onOpenNavigation: widget.onOpenNavigation != null
                    ? () => widget.onOpenNavigation!(context)
                    : _controller.openExternalNavigation,
                onCompleteJourney: _controller.beginVerification,
              );
            case JourneyStep.verifyingLocation:
              return VerifyLocationView(
                data: _controller.verifyLocationUiData,
                onBack: _controller.continueWalking,
                onCompleteJourney: _controller.completeJourney,
                onRetry: _controller.retryVerification,
                onContinueWalking: _controller.continueWalking,
              );
            case JourneyStep.completed:
              return JourneyCompletedView(
                data: _controller.journeyCompletedUiData,
                onBack: _returnHome,
                onReturnHome: _returnHome,
                onViewRewards: _openRewards,
                onRetryReward: _controller.retryReward,
              );
          }
        },
      ),
    );
  }
}
