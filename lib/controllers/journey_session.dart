// Walking & Carbon Module — the app-wide handle on a running journey.
//
// A journey used to live and die with JourneyFlowView's route: that widget
// built its own JourneyCompletionController in initState and disposed it on
// the way out, and blocked pops so the route could not leave the stack. The
// tourist was therefore locked inside the journey screens from Start Journey
// until they either arrived or gave the journey up.
//
// The controller now lives here instead, above every route. JourneyFlowView
// reads it rather than owning it, so the route can be popped and re-pushed
// while the elapsed timer and the position stream keep running underneath —
// which is all "minimise" is. JourneyMiniBar renders whenever a journey is
// live but its screen is not on top.
//
// One journey at a time, in memory only: nothing here survives the process
// being killed, exactly as before.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../dao/badge_dao.dart';
import '../dao/reward_dao.dart';
import '../services/check_in_repository.dart';
import '../services/journey_progress_service.dart';
import '../services/map_service.dart';
import '../services/navigation_launcher_service.dart';
import '../views/journey_flow_view.dart';
import 'journey_completion_controller.dart';
import 'reward_controller.dart';
import 'walking_controller.dart';

class JourneySession extends ChangeNotifier {
  JourneySession._();

  static final JourneySession instance = JourneySession._();

  /// The app's navigator, so a journey can be re-opened from the mini bar —
  /// which is drawn above every route and therefore has no route context of
  /// its own to push from.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  JourneyCompletionController? _controller;
  JourneyCompletionController? get controller => _controller;

  bool get isActive => _controller != null;

  /// True while a journey is running with its screens off the stack. Set by
  /// [minimize], cleared by [JourneyFlowView] itself as it mounts, so the bar
  /// and the journey screen can never both be showing the same journey.
  bool _isMinimized = false;
  bool get isMinimized => _isMinimized;

  /// Opens WalkPenang's own turn-by-turn view for this journey. Supplied by
  /// route_summary_view, where the RouteResult lives; null in the debug flow,
  /// which has no map.
  void Function(BuildContext)? _openNavigation;
  void Function(BuildContext)? get openNavigation => _openNavigation;

  /// Fired once the journey genuinely completes, so the Map module can grey
  /// out the destination's pin. Never fired for a journey ended early.
  VoidCallback? _onJourneyCompleted;
  VoidCallback? get onJourneyCompleted => _onJourneyCompleted;

  /// Begins a journey and takes ownership of its controller.
  ///
  /// The Firestore/Reward wiring below is the same wiring JourneyFlowView used
  /// to do in initState — moved rather than duplicated, so there is still
  /// exactly one place in the app that constructs a live journey.
  JourneyCompletionController start({
    required WalkingController walking,
    void Function(BuildContext)? openNavigation,
    VoidCallback? onJourneyCompleted,
  }) {
    // Guaranteed non-null/valid by the caller: PreWalkSummaryView only starts
    // a journey after WalkingController.startJourney() succeeds, which itself
    // requires a non-null, valid routeSummary.
    final summary = walking.routeSummary!;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final firestore = FirebaseFirestore.instance;

    _releaseActiveController();
    _controller = JourneyCompletionController(
      routeSummary: summary,
      userId: uid,
      carbonSavedKg: walking.carbonSavedKg,
      // The weight, not the pre-walk estimate: the journey recomputes
      // calories from the distance actually covered (US-W04).
      bodyWeightKg: walking.calorieBodyWeightKg,
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
    _openNavigation = openNavigation;
    _onJourneyCompleted = onJourneyCompleted;
    _isMinimized = false;
    notifyListeners();

    return _controller!;
  }

  /// Adopts an already-built controller. Only the debug/test flow uses this;
  /// the app always goes through [start].
  @visibleForTesting
  void adopt(
    JourneyCompletionController controller, {
    void Function(BuildContext)? openNavigation,
    VoidCallback? onJourneyCompleted,
  }) {
    _releaseActiveController();
    _controller = controller;
    _openNavigation = openNavigation;
    _onJourneyCompleted = onJourneyCompleted;
    _isMinimized = false;
    notifyListeners();
  }

  /// Clears whatever journey is still holding the session's one slot, before
  /// a new controller takes it.
  ///
  /// A safety net, not the guard: the tourist is asked before a live journey
  /// is replaced (see `confirmRouteOverActiveJourney`). But if anything ever
  /// reaches [start] with a journey still running, dropping it would leave a
  /// controller whose cancel latch was never set — disposed, yet still able
  /// to be verified, completed and rewarded by a callback already in flight.
  /// So it is cancelled first, exactly as [abandon] would have done, and only
  /// then released.
  void _releaseActiveController() {
    final previous = _controller;
    if (previous == null) return;
    previous.cancelJourney();
    previous.dispose();
    _controller = null;
  }

  /// The journey keeps running; its screens come off the stack.
  void minimize() {
    if (!isActive || _isMinimized) return;
    _isMinimized = true;
    notifyListeners();
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  /// Puts the journey screens back on top of whatever the tourist wandered
  /// into. Pushes rather than restores: JourneyFlowView is a state machine
  /// over one controller, so a fresh route shows exactly the step the journey
  /// is actually on.
  void expand() {
    if (!isActive || !_isMinimized) return;
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const JourneyFlowView()),
    );
  }

  /// Called by [JourneyFlowView] as it mounts — the journey's screen is on
  /// top, so the bar must not also be showing.
  ///
  /// The flag moves now; the notification waits for the end of the frame.
  /// This is the one place a listener is woken from *inside* a build: the
  /// caller is a route being mounted below the app's Navigator, while
  /// [JourneyOverlayHost] listens from `MaterialApp.builder` — above it, and
  /// already built earlier in the same frame. Notifying synchronously asks an
  /// ancestor to rebuild mid-build, which Flutter refuses ("setState() or
  /// markNeedsBuild() called during build"), so the flag would flip and the
  /// bar would stay on screen anyway until some unrelated rebuild happened to
  /// come along. Deferring costs one frame, spent underneath the incoming
  /// route's own transition.
  void markExpanded() {
    if (!_isMinimized) return;
    _isMinimized = false;
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  /// UC-M05 arrival, in one tap: closes the navigation screen and runs the
  /// UC-W06 check that finishes the journey. The pop happens first so the
  /// tourist watches verification on the screen that owns it, rather than
  /// behind a map they are done with.
  Future<void> completeFromNavigation(BuildContext context) async {
    final journey = _controller;
    Navigator.of(context).pop();
    await journey?.verifyAndComplete();
  }

  /// Gives up an unfinished journey and releases the session.
  ///
  /// The single correct way to terminate a journey that was never walked to
  /// its end — from the Active Walking back arrow, from the mini bar's end
  /// button, or when the tourist chooses a route to somewhere else. [end]
  /// alone is not enough: it only disposes the controller, leaving the cancel
  /// latch unset, so a callback already in flight could still verify,
  /// complete and reward a journey the tourist has walked away from.
  ///
  /// Deliberately not a completion: no check-in is written, no reward is
  /// requested, no badge progresses, and [onJourneyCompleted] never fires —
  /// so the Map module's pin stays un-greyed for a destination never reached.
  void abandon() {
    if (!isActive) return;
    _controller?.cancelJourney();
    end();
  }

  /// Ends the session — whether the journey completed or was given up. The
  /// controller's own latches (cancelJourney / completed) decide what was
  /// recorded; this only releases it.
  ///
  /// For a journey that did *not* complete, call [abandon] instead: it sets
  /// that latch before releasing.
  void end() {
    if (!isActive) return;
    _controller?.dispose();
    _controller = null;
    _openNavigation = null;
    _onJourneyCompleted = null;
    _isMinimized = false;
    notifyListeners();
  }
}
