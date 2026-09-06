// Test harness for the Walking journey-completion flow (Active Walking ->
// Verify Location -> Journey Completed), reusing the exact same production
// views as journey_flow_view.dart, driven by one live
// JourneyCompletionController wired entirely to the fakes in
// fake_journey_dependencies.dart.
//
// Never reads real GPS, never writes to Firestore, never calls the real
// Reward Module — see fake_journey_dependencies.dart for how each dependency
// guarantees that.
//
// It used to double as an in-app lecturer demo reachable from the walking
// journal in debug builds. The app no longer offers that route, so this
// stays purely as what test/views/demo_journey_flow_view_test.dart drives:
// the three real views through real state transitions, including the
// "Complete Journey" -> reward result path.
//
// No `if (demoMode)` branch exists anywhere in the three views or in
// JourneyCompletionController: this file's only job is to supply that
// controller with fake dependencies instead of real ones.

import 'package:flutter/material.dart';

import 'package:walkpenang/controllers/journey_completion_controller.dart';
import 'package:walkpenang/views/active_walking_view.dart';
import 'package:walkpenang/views/journey_completed_view.dart';
import 'package:walkpenang/views/verify_location_view.dart';
import 'fake_journey_dependencies.dart';
import 'walking_fixtures.dart';

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
      routeSummary: demoRouteSummary,
      // Matches Module 5's own DemoRewardData.userId convention
      // (dao/in_memory_reward_data.dart) — clearly not a real tourist ID.
      userId: 'demo_tourist',
      // The carbon WalkingBenefits would compute for the demo route (see
      // test/controllers/walking_controller_test.dart) — a realistic, not
      // fabricated-looking, demo number.
      carbonSavedKg: 0.504,
      // A 65 kg reference walker, so the demo's KCAL BURNED counts up with
      // the scripted FakeJourneyProgressService walk exactly as it does on a
      // real journey, rather than sitting on one pre-walk figure.
      bodyWeightKg: 65,
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
