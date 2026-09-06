// Walking & Carbon Module — the real journey-completion flow (UC-W05,
// UC-W06), pushed by PreWalkSummaryView once Start Journey succeeds and
// re-pushed by the mini bar when a minimised journey is re-opened.
//
// The journey itself belongs to JourneySession, not to this route: its
// controller is wired there to real GPS (ArrivalVerificationService's default
// LocationArrivalVerificationService), real Firestore persistence
// (FirestoreCheckInRepository) and the real Reward Module. This widget only
// swaps between ActiveWalkingView, VerifyLocationView and JourneyCompletedView
// based on JourneyCompletionController.step, so it can be popped and rebuilt
// as often as the tourist likes without the journey noticing.

import 'package:flutter/material.dart';

import '../controllers/journey_completion_controller.dart';
import '../controllers/journey_session.dart';
import '../models/journal_entry_model.dart';
import '../theme/app_theme.dart';
import 'active_walking_view.dart';
import 'journey_completed_view.dart';
import 'reward/journal_detail_screen.dart';
import 'verify_location_view.dart';

class JourneyFlowView extends StatefulWidget {
  const JourneyFlowView({super.key});

  @override
  State<JourneyFlowView> createState() => _JourneyFlowViewState();
}

class _JourneyFlowViewState extends State<JourneyFlowView> {
  final JourneySession _session = JourneySession.instance;

  /// The running journey. Non-null for the lifetime of this route: the two
  /// things that clear it — completing and ending — both pop this route in the
  /// same breath.
  late final JourneyCompletionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _session.controller!;
    // The journey's own screen is on top, so the mini bar must not also be
    // advertising it.
    _session.markExpanded();
  }

  /// "Back to Explore" / the completed screen's own back arrow both return
  /// the tourist to the app's root (Home), matching the Figma copy — there
  /// is no "previous state" to go back to once a journey is recorded.
  ///
  /// This is also the one place [onJourneyCompleted] fires: every path that
  /// reaches here does so from [JourneyStep.completed] (see
  /// [_handleSystemBack] and the `completed` case below) — the tourist's GPS
  /// arrival was already verified before this screen showed up, regardless
  /// of whether the reward write that follows it succeeds.
  void _returnHome() {
    _session.onJourneyCompleted?.call();
    _session.end();
    Navigator.of(context, rootNavigator: true)
        .popUntil((route) => route.isFirst);
  }

  /// "View Journey" — opens the detail page for the journey that has just
  /// been completed, which is the same screen the walking journal opens for a
  /// historical entry (FR-R03). It used to open the statistics dashboard,
  /// which answered a question the button does not ask.
  ///
  /// The entry is handed over directly rather than re-read: the controller
  /// already holds the check-in record it wrote, so this costs no Firestore
  /// query, cannot race the reward transaction that stamps `pointsAwarded`,
  /// and shows the same figures the journal will show for this journey later.
  /// [JournalDetailScreen] is stateless, so opening it saves nothing and
  /// awards nothing.
  void _openJourneyDetail(JournalEntryModel entry) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => JournalDetailScreen(entry: entry)),
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
    _session.end();
    Navigator.of(context).pop();
  }

  /// The Android system back button / back gesture.
  ///
  /// On an active journey this minimises rather than offering to end it: back
  /// is the gesture for "I want to be somewhere else", which is now something
  /// the tourist can have without giving up the walk. Ending is still one tap
  /// away — the drawn back arrow, or the mini bar — and both still ask first.
  void _handleSystemBack() {
    switch (_controller.step) {
      case JourneyStep.active:
        _session.minimize();
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
                onOpenNavigation: _session.openNavigation != null
                    ? () => _session.openNavigation!(context)
                    : _controller.openExternalNavigation,
                onCompleteJourney: _controller.beginVerification,
                onMinimize: _session.minimize,
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
              // Null while the journey has no record to open — an
              // unauthenticated tourist, or the moment before the check-in is
              // built. The footer renders the action disabled rather than
              // falling back to a screen that is not this journey.
              final completedEntry = _controller.completedJournalEntry;
              return JourneyCompletedView(
                data: _controller.journeyCompletedUiData,
                onBack: _returnHome,
                onReturnHome: _returnHome,
                onViewJourney: completedEntry == null
                    ? null
                    : () => _openJourneyDetail(completedEntry),
                onRetryReward: _controller.retryReward,
              );
          }
        },
      ),
    );
  }
}
