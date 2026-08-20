// Interactive lecturer demo for the Walking journey-completion flow
// (Active Walking -> Verify Location -> Journey Completed), reusing the
// exact same production views as journey_flow_view.dart, driven by one live
// JourneyCompletionController wired entirely to the fakes in
// fake_journey_dependencies.dart.
//
// Debug-only: only ever reachable when kDebugMode is true (see the entry
// point guard in ../views/reward/walking_journal_screen.dart). Never reads
// real GPS, never
// writes to Firestore, never calls the real Reward Module — see
// fake_journey_dependencies.dart for how each dependency guarantees that.
//
// This is deliberately separate from journey_ui_preview_main.dart, which
// stays untouched as the fixed-state Figma preview
// (`flutter run -t lib/debug/journey_ui_preview_main.dart`) — a gallery of
// static samples with its own `main()`. This widget is reached from inside
// the running app instead, and drives the same three views live, through
// real (fake-backed) state transitions rather than static per-state
// samples — including a working "Complete Journey" -> reward result path.
//
// No `if (demoMode)` branch exists anywhere in the three views or in
// JourneyCompletionController: this file's only job is to supply that
// controller with fake dependencies instead of real ones.

import 'package:flutter/material.dart';

import '../controllers/journey_completion_controller.dart';
import '../models/walking_route_summary.dart';
import '../views/active_walking_view.dart';
import '../views/journey_completed_view.dart';
import '../views/verify_location_view.dart';
import 'fake_journey_dependencies.dart';

class DemoJourneyFlowView extends StatefulWidget {
  const DemoJourneyFlowView({super.key});

  @override
  State<DemoJourneyFlowView> createState() => _DemoJourneyFlowViewState();
}

class _DemoJourneyFlowViewState extends State<DemoJourneyFlowView> {
  late final JourneyCompletionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = JourneyCompletionController(
      routeSummary: WalkingRouteSummary.demo,
      // Matches Module 5's own DemoRewardData.userId convention
      // (dao/in_memory_reward_data.dart) — clearly not a real tourist ID.
      userId: 'demo_tourist',
      // Same figures WalkingBenefits would compute for the demo route at a
      // 65kg reference weight (see test/controllers/walking_controller_test
      // .dart) — a realistic, not fabricated-looking, demo number.
      carbonSavedKg: 0.504,
      caloriesBurned: 140.4,
      rewardService: FakeRewardService(),
      checkInRepository: NoopCheckInRepository(),
      arrivalVerificationService: const FakeArrivalVerificationService(),
      // Without this the demo would hit the real GPS stream and the
      // KM COVERED / MIN REMAINING tiles would sit unavailable.
      journeyProgressService: const FakeJourneyProgressService(),
      // No NavigationLauncherService: Open Navigation must never launch a
      // real external app mid-demo.
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _exitDemo() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return Banner(
      message: 'DEMO',
      location: BannerLocation.topEnd,
      color: Colors.deepOrange,
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          switch (_controller.step) {
            case JourneyStep.active:
              return ActiveWalkingView(
                data: _controller.activeWalkingUiData,
                onBack: _exitDemo,
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
                onBack: _exitDemo,
                onReturnHome: _exitDemo,
                onRetryReward: _controller.retryReward,
              );
          }
        },
      ),
    );
  }
}
