// Walking & Carbon Module — journey completion orchestration.
// Use Case : UC-W05 Complete Walking Journey, UC-W06 Verify Destination
//            Proximity
//
// Drives ActiveWalkingView -> VerifyLocationView -> JourneyCompletedView by
// producing their (already existing, presentation-only) UI-data types and
// exposing the actions those views' callbacks invoke. Never recomputes
// points/badges (that stays Module 5's — see RewardService) and never talks
// to Geolocator/Firestore directly (that stays behind
// ArrivalVerificationService / JourneyProgressService / CheckInRepository).
//
// Every dependency is injected, so lib/views/journey_flow_view.dart wires
// this to real GPS + Firestore + the real RewardController, while
// test/support/demo_journey_flow_view.dart wires the exact same controller
// class to fakes. Neither the controller nor the three views it drives
// contain an `if (demoMode)` branch anywhere.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/active_walking_ui_data.dart';
import '../models/badge_model.dart';
import '../models/check_in_result.dart';
import '../models/journey_completed_ui_data.dart';
import '../models/journey_reward_ui_state.dart';
import '../models/verify_location_ui_data.dart';
import '../models/walking_route_summary.dart';
import '../constants/map_constants.dart';
import '../services/arrival_verification_service.dart';
import '../services/check_in_repository.dart';
import '../services/journey_progress_service.dart';
import '../services/navigation_launcher_service.dart';
import 'reward_service.dart';

/// Which of the three existing views is currently on screen.
enum JourneyStep { active, verifyingLocation, completed }

class JourneyCompletionController extends ChangeNotifier {
  JourneyCompletionController({
    required this.routeSummary,
    required this.userId,
    required RewardService rewardService,
    required CheckInRepository checkInRepository,
    ArrivalVerificationService? arrivalVerificationService,
    NavigationLauncherService? navigationLauncherService,
    JourneyProgressService? journeyProgressService,
    this.carbonSavedKg = 0.0,
    this.bodyWeightKg,
  })  : _rewardService = rewardService,
        _checkInRepository = checkInRepository,
        _arrivalVerificationService =
            arrivalVerificationService ?? LocationArrivalVerificationService(),
        _navigationLauncherService = navigationLauncherService,
        _journeyProgressService =
            journeyProgressService ?? const NoJourneyProgressService() {
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed += const Duration(seconds: 1);
      notifyListeners();
    });

    // Progress tracking is strictly additive: none of it is required for a
    // journey to be walked, verified and rewarded. A stream error is
    // swallowed rather than surfaced because arrival is checked by its own
    // one-shot fix — a position stream that dies mid-walk (permission
    // revoked, GPS switched off) must not take the journey with it. KM
    // COVERED then simply stays unavailable, exactly as it read before any
    // progress source existed.
    _progressSubscription = _journeyProgressService
        .track(
          destinationLatitude: routeSummary.destinationLatitude,
          destinationLongitude: routeSummary.destinationLongitude,
        )
        .listen((update) {
      _metresWalked = update.metresWalked;
      // The first fix of the journey sets the denominator, which is what
      // makes the bar start at 0%: at that moment current == initial.
      _initialMetresToDestination ??= update.metresToDestination;
      _metresToDestination = update.metresToDestination;
      notifyListeners();
    }, onError: (_) {});
  }

  final WalkingRouteSummary routeSummary;
  final String userId;

  /// Snapshotted once at construction from WalkingController: this stays the
  /// planned-route figure for the whole journey, exactly as Pre-Walk Summary
  /// already showed it.
  final double carbonSavedKg;

  /// The walker's body weight — deliberately not their calorie estimate.
  ///
  /// Calories used to be snapshotted here beside [carbonSavedKg], which
  /// pinned KCAL BURNED to the planned route for the whole journey: half way
  /// through a 1.2 km walk the tile still read the full route's ~60 kcal, and
  /// a detour that pushed KM COVERED up moved it not at all. US-W04's formula
  /// is distance x weight x 0.9, and on a journey being walked the distance
  /// in it has to be the distance actually covered — so the weight is what
  /// gets carried, and [caloriesBurned] does the arithmetic per fix.
  ///
  /// Null whenever calories are not attributable: a non-walking journey, or a
  /// profile with no usable body weight. [WalkingController.calorieBodyWeightKg]
  /// is the only thing that fills this in production, and nothing here
  /// substitutes a default weight when it comes back null.
  final double? bodyWeightKg;

  final RewardService _rewardService;
  final CheckInRepository _checkInRepository;
  final ArrivalVerificationService _arrivalVerificationService;
  final NavigationLauncherService? _navigationLauncherService;
  final JourneyProgressService _journeyProgressService;

  Timer? _elapsedTimer;
  StreamSubscription<JourneyProgressUpdate>? _progressSubscription;
  Duration _elapsed = Duration.zero;
  Duration? _completedDuration;

  /// Metres actually walked, accumulated from the position stream. Null until
  /// the first movement lands, so the UI can tell "not tracking yet" from
  /// "tracked, and you have not moved" — the Active Walking tiles render the
  /// former as unavailable rather than as a fabricated 0.0.
  double? _metresWalked;

  /// How far the destination was on the journey's first fix, and how far it
  /// is now. Together they answer "how much closer am I?", which is a
  /// different question from [kmCovered]'s "how far have I walked?" — a
  /// tourist can walk a kilometre in circles and close no distance at all.
  double? _initialMetresToDestination;
  double? _metresToDestination;

  /// Distance genuinely covered, never the route's planned distance.
  double? get kmCovered =>
      _metresWalked == null ? null : _metresWalked! / 1000;

  /// Calories burned so far (US-W04), from [kmCovered] — never the planned
  /// route's distance. Recomputed on every position fix, so KCAL BURNED
  /// climbs with KM COVERED, detours included.
  ///
  /// Null on either of the two "cannot know" grounds, which the tiles render
  /// as unavailable rather than as a fabricated number: no usable body weight
  /// ([bodyWeightKg]), or no position fix yet ([kmCovered]). 0.0 once
  /// tracking has started and the tourist has not yet moved — honestly zero,
  /// which is a different statement from unavailable.
  double? get caloriesBurned {
    final covered = kmCovered;
    final weightKg = bodyWeightKg;
    if (covered == null || weightKg == null) return null;
    return WalkingBenefits.calculateCaloriesBurned(covered, weightKg);
  }

  /// Minutes still to go, from the distance left at the route's own planned
  /// pace.
  ///
  /// Planned pace rather than the tourist's observed pace on purpose: over a
  /// short walk the observed figure swings wildly between fixes, and a
  /// countdown that jumps from 4 minutes to 20 and back reads as broken. Null
  /// whenever there is nothing sound to divide — no progress yet, or a route
  /// with no distance or duration to take a pace from.
  int? get minutesRemaining {
    final covered = kmCovered;
    final plannedKm = routeSummary.distanceKm;
    final plannedMinutes = routeSummary.estimatedDuration.inMinutes;
    if (covered == null || plannedKm <= 0 || plannedMinutes <= 0) return null;

    final remainingKm = plannedKm - covered;
    if (remainingKm <= 0) return 0;
    return (remainingKm / (plannedKm / plannedMinutes)).round();
  }

  JourneyStep _step = JourneyStep.active;
  JourneyStep get step => _step;

  VerifyLocationPhase? _verifyPhase;
  VerifyBlockReason? _blockReason;
  double? _currentDistanceMeters;

  /// Where the last arrival check found the tourist — carried purely so the
  /// Verify Location screen can plot that fix against the destination's
  /// radius. Nothing here feeds the arrival decision, which stays
  /// [MapConstants.isWithinCheckInRange] on the measured distance.
  double? _currentUserLatitude;
  double? _currentUserLongitude;
  bool _verifying = false;

  bool _completing = false;
  bool _completed = false;

  /// True once the tourist backed out of an active journey (the "End
  /// Journey?" confirmation on the Active Walking screen). Latches the
  /// controller closed so nothing can still verify, complete or reward
  /// after the screen has been popped.
  bool _cancelled = false;

  /// True once a completion attempt has been claimed — the client-side
  /// duplicate-completion guard, on top of Module 5's own server-side
  /// idempotency (points ledger + rewardProcessed flag).
  bool get isCompleted => _completed;

  JourneyRewardUiState _reward = const JourneyRewardUiState.unavailable();
  CheckInResult? _checkInResult;

  // --- UI-data for the three existing views --------------------------------

  ActiveWalkingUiData get activeWalkingUiData => ActiveWalkingUiData(
        destinationName: routeSummary.destinationName,
        elapsedTime: _elapsed,
        plannedDistanceKm: routeSummary.distanceKm,
        kmCovered: kmCovered,
        initialMetresToDestination: _initialMetresToDestination,
        metresToDestination: _metresToDestination,
        minutesRemaining: minutesRemaining,
        carbonSavedKg: carbonSavedKg,
        caloriesBurned: caloriesBurned,
      );

  VerifyLocationUiData get verifyLocationUiData => VerifyLocationUiData(
        phase: _verifyPhase ?? VerifyLocationPhase.checking,
        destinationName: routeSummary.destinationName,
        radiusMeters: MapConstants.checkInThresholdMeters,
        currentDistanceMeters: _currentDistanceMeters,
        blockReason: _blockReason,
        destinationLatitude: routeSummary.destinationLatitude,
        destinationLongitude: routeSummary.destinationLongitude,
        userLatitude: _currentUserLatitude,
        userLongitude: _currentUserLongitude,
      );

  JourneyCompletedUiData get journeyCompletedUiData => JourneyCompletedUiData(
        destinationName: routeSummary.destinationName,
        destinationAreaLabel: routeSummary.areaLabel,
        // The tracked distance, still never the planned one: null while the
        // position stream gave us nothing, exactly as this model's contract
        // requires.
        completedDistanceKm: kmCovered,
        journeyDuration: _completedDuration,
        carbonSavedKg: carbonSavedKg,
        caloriesBurned: caloriesBurned,
        reward: _reward,
      );

  // --- Active Walking (UC-W05) ----------------------------------------------

  /// Best-effort "Open Navigation" — a convenience, not part of the
  /// completion/reward critical path, so any failure here is swallowed
  /// rather than surfaced as a journey error. No-op when no
  /// [NavigationLauncherService] was supplied (the lecturer demo passes
  /// none, since it must never launch an external app).
  Future<void> openExternalNavigation() async {
    final launcher = _navigationLauncherService;
    if (launcher == null) return;

    final destination = LatLng(
      routeSummary.destinationLatitude,
      routeSummary.destinationLongitude,
    );
    try {
      final deepLink = launcher.buildNavigationDeepLink(destination);
      final installed = await launcher.isGoogleMapsInstalled(destination);
      if (!installed) {
        await launcher.redirectToPlayStore();
        return;
      }
      await launcher.launchGoogleMapsNavigation(deepLink);
    } catch (_) {
      // Non-critical — see method doc.
    }
  }

  /// UC-W05 step "User completes journey" -> UC-W06: moves to Verify
  /// Location and immediately runs the first GPS check.
  Future<void> beginVerification() async {
    if (_cancelled || _completed || _step == JourneyStep.verifyingLocation) {
      return;
    }

    _step = JourneyStep.verifyingLocation;
    _verifyPhase = VerifyLocationPhase.checking;
    _blockReason = null;
    _clearLastFix();
    notifyListeners();

    await _checkArrival();
  }

  /// UC-M05 -> UC-W06 in one tap: the navigation screen has already detected
  /// arrival, so the tourist should not have to ask for a check they have
  /// visibly passed.
  ///
  /// The check itself is not skipped. It is the same one-shot GPS fix against
  /// [MapConstants.checkInThresholdMeters] that the Verify Location screen
  /// runs — navigation's own arrival is a running estimate off a live stream,
  /// and a journey may only be rewarded on a deliberate fix. Anything other
  /// than a pass simply leaves the tourist on Verify Location, which is the
  /// only screen that can show the reason and offer a retry.
  Future<void> verifyAndComplete() async {
    await beginVerification();
    if (_verifyPhase == VerifyLocationPhase.verified) {
      await completeJourney();
    }
  }

  // --- Verify Location (UC-W06) ---------------------------------------------

  Future<void> _checkArrival() async {
    if (_verifying) return;
    _verifying = true;

    try {
      final reading = await _arrivalVerificationService.checkDistanceTo(
        destinationLatitude: routeSummary.destinationLatitude,
        destinationLongitude: routeSummary.destinationLongitude,
      );

      switch (reading.status) {
        case ArrivalCheckStatus.success:
          final distance = reading.distanceMeters!;
          _currentDistanceMeters = distance;
          // Kept in step with the distance above: the map must never plot a
          // position the current reading did not produce.
          _currentUserLatitude = reading.userLatitude;
          _currentUserLongitude = reading.userLongitude;
          if (MapConstants.isWithinCheckInRange(distance)) {
            _verifyPhase = VerifyLocationPhase.verified;
            _blockReason = null;
          } else {
            _verifyPhase = VerifyLocationPhase.blocked;
            _blockReason = VerifyBlockReason.tooFar;
          }
          break;
        case ArrivalCheckStatus.permissionDenied:
          _verifyPhase = VerifyLocationPhase.blocked;
          _blockReason = VerifyBlockReason.permissionDenied;
          _clearLastFix();
          break;
        case ArrivalCheckStatus.gpsUnavailable:
          _verifyPhase = VerifyLocationPhase.blocked;
          _blockReason = VerifyBlockReason.gpsDisabled;
          _clearLastFix();
          break;
        case ArrivalCheckStatus.weakSignal:
          _verifyPhase = VerifyLocationPhase.blocked;
          _blockReason = VerifyBlockReason.weakSignal;
          _clearLastFix();
          break;
      }
    } finally {
      _verifying = false;
      notifyListeners();
    }
  }

  /// Drops the last fix — the measured distance and the position it was
  /// measured from always go together, so neither the distance rows nor the
  /// map can outlive the reading behind them.
  void _clearLastFix() {
    _currentDistanceMeters = null;
    _currentUserLatitude = null;
    _currentUserLongitude = null;
  }

  /// "Try Again" on the blocked card.
  Future<void> retryVerification() async {
    if (_cancelled || _completed || _step != JourneyStep.verifyingLocation) {
      return;
    }
    _verifyPhase = VerifyLocationPhase.checking;
    notifyListeners();
    await _checkArrival();
  }

  /// "Continue Walking" on the blocked card, and the header back arrow on
  /// both Active Walking's and Verify Location's own [beginVerification]
  /// entry — returns to Active Walking without abandoning the journey.
  void continueWalking() {
    if (_cancelled || _completed) return;
    _step = JourneyStep.active;
    _verifyPhase = null;
    _blockReason = null;
    _clearLastFix();
    notifyListeners();
  }

  /// The tourist abandoned an active journey — the "Yes, End Journey"
  /// answer to the Active Walking back-button confirmation.
  ///
  /// Deliberately *not* a completion: no check-in is written, no reward is
  /// requested, and [step] never reaches [JourneyStep.completed]. It only
  /// tears down the two things that would otherwise keep running behind a
  /// popped screen (the elapsed timer and the progress stream) and latches
  /// the controller so a late callback cannot restart verification or
  /// completion. [dispose] still runs its own cancels, which stay harmless
  /// no-ops after this.
  void cancelJourney() {
    if (_cancelled || _completed) return;
    _cancelled = true;
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _progressSubscription?.cancel();
    _progressSubscription = null;
  }

  // --- Journey Completed (UC-W05 handoff to Module 5) -----------------------

  /// "Complete Journey" on the verified card. Guarded against duplicate
  /// completion: a second call while completing, or after completion, is a
  /// no-op. Only meaningful once [verifyLocationUiData] reports
  /// [VerifyLocationPhase.verified] — VerifyLocationView only renders this
  /// action in that phase, but the guard holds even if invoked otherwise.
  Future<void> completeJourney() async {
    if (_cancelled || _completed || _completing) return;
    if (_verifyPhase != VerifyLocationPhase.verified) return;

    _completing = true;
    _completed = true;
    _step = JourneyStep.completed;
    _completedDuration = _elapsed;
    _elapsedTimer?.cancel();
    // Stop accumulating: the journey is over, and the completed screen's
    // distance must be what was walked to get here, not whatever the phone
    // drifts through afterwards.
    _progressSubscription?.cancel();
    notifyListeners();

    await _awardReward();
    _completing = false;
  }

  /// "Retry" on the Journey Completed error card — re-attempts only the
  /// reward step, reusing the same [CheckInResult] (and therefore the same
  /// checkInId), so Module 5's own idempotency guard makes this safe even
  /// if an earlier attempt actually did get through.
  Future<void> retryReward() => _awardReward();

  Future<void> _awardReward() async {
    if (userId.isEmpty) {
      // Reward processing requires an authenticated tourist — matches
      // firestore.rules, which denies an unauthenticated check_ins write
      // outright, so there is nothing to retry until the tourist signs in.
      _reward = const JourneyRewardUiState.error(
        'Sign in to record points and badges for this journey.',
      );
      notifyListeners();
      return;
    }

    _reward = const JourneyRewardUiState.pending();
    notifyListeners();

    _checkInResult ??= CheckInResult(
      checkInId: _checkInRepository.newCheckInId(),
      userId: userId,
      destinationId: routeSummary.destinationId,
      // Stored alongside the id so the walking journal can name the
      // place without a Places lookup per row (FR-R03).
      destinationName: routeSummary.destinationName,
      distanceKm: routeSummary.distanceKm,
      carbonSavedKg: carbonSavedKg,
      // CheckInResult.caloriesBurned is non-nullable; a missing body weight
      // (US-W04) reports 0.0 to Module 5 rather than blocking completion.
      caloriesBurned: caloriesBurned ?? 0.0,
      // FR-W01: the reward module cannot tell a walk from a drive after the
      // fact, so the journey has to record how it was travelled. Without
      // this the field would silently take its walking default and a driven
      // route would earn a walker's points.
      transportMode: routeSummary.transportMode,
      checkInTime: DateTime.now(),
    );
    final result = _checkInResult!;

    try {
      // Best-effort: Module 5's DAO only ever merges its own
      // rewardProcessed flag onto this document and never requires it to
      // pre-exist (see check_in_repository.dart), so a persistence failure
      // here must not block the reward itself from being awarded.
      await _checkInRepository.saveCheckIn(result);
    } catch (_) {}

    try {
      final outcome = await _rewardService.onCheckInVerified(result);
      _reward = JourneyRewardUiState.success(
        pointsAwarded: outcome.pointsAwarded,
        newlyEarnedBadgeNames: outcome.newlyEarnedBadgeIds
            .map((id) => BadgeCatalogue.byId(id)?.name)
            .whereType<String>()
            .toList(growable: false),
        alreadyAwarded: outcome.alreadyAwarded,
      );
    } catch (_) {
      _reward = const JourneyRewardUiState.error(
        'Could not reach the reward service.',
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _progressSubscription?.cancel();
    super.dispose();
  }
}
