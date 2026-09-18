import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../constants/map_constants.dart';
import '../constants/map_error_messages.dart';
import '../models/gps_location.dart';
import '../models/place_model.dart';
import '../models/route_result.dart';
import '../models/route_step.dart';
import '../models/transport_mode.dart';
import '../services/compass_service.dart';
import '../services/location_service.dart';
import '../services/map_service.dart';
import '../services/navigation_service.dart';
import '../services/route_service.dart';
import '../utils/angle_utils.dart';

/// Drives [NavigationView] — live turn-by-turn navigation rendered on
/// WalkPenang's own map (UC-M05), for whichever travel mode the tourist
/// picked in UC-M04. Reuses the [RouteResult] already fetched by
/// [RouteSummaryController] rather than re-requesting it (constraint C1).
///
/// This class owns *where the tourist actually is*; [NavigationView] owns how
/// that position is drawn between fixes. Keeping the raw fix here means every
/// distance and ETA below is computed from real GPS data, never from an
/// interpolated animation frame.
class NavigationController extends ChangeNotifier {
  NavigationController({
    required RouteResult route,
    required this.destination,
    required this.mode,
    required LatLng initialPosition,
    LocationService? locationService,
    NavigationService? navigationService,
    CompassService? compassService,
    RouteService? routeService,
  }) : _route = route,
       _locationService = locationService ?? LocationService(),
       _navigationService = navigationService ?? NavigationService(),
       _compassService = compassService ?? CompassService(),
       _routeService = routeService ?? RouteService(MapService()),
       _totalRouteMeters = route.distanceKm * 1000,
       currentPosition = initialPosition {
    _startTracking();
  }

  /// The route currently being navigated.
  ///
  /// Not final, and deliberately so: a tourist who takes a wrong road is
  /// rerouted from where they now are, and everything downstream — the
  /// instruction banner, the polyline, remaining distance and the ETA — has to
  /// follow. It used to be a `final` field read straight off the widget, which
  /// is what made in-app navigation keep pointing down the road the tourist
  /// had already left.
  RouteResult _route;
  RouteResult get route => _route;

  final PlaceModel destination;

  /// The mode the tourist picked in UC-M04. A reroute is requested in this
  /// same mode — a walking journey stays a walking journey, and a driven one
  /// must never be handed a route down a footpath.
  final TransportMode mode;

  final LocationService _locationService;
  final NavigationService _navigationService;
  final CompassService _compassService;
  final RouteService _routeService;

  StreamSubscription<GpsLocation>? _locationSubscription;
  StreamSubscription<double?>? _compassSubscription;

  /// Latest raw GPS fix.
  LatLng currentPosition;

  int currentStepIndex = 0;
  bool hasArrived = false;

  /// Set once when arrival is first detected, so [NavigationView] can fire its
  /// haptic exactly once rather than on every subsequent fix inside the
  /// check-in radius.
  bool justArrived = false;

  /// UC-008 A1/A3 surfaced on the navigation screen: the GPS stream can fail
  /// mid-route (permission revoked, location services switched off).
  String? errorMessage;

  /// Gap between the last two fixes. [NavigationView] sizes its interpolation
  /// from this so the puck finishes gliding to a fix just as the next one
  /// lands — too short and it stutters, too long and it lags behind the
  /// tourist.
  Duration fixInterval = MapConstants.maxNavigationInterpolation;

  DateTime? _lastFixAt;
  LatLng? _previousPosition;

  /// Direction of travel from GPS, plus when it was last trustworthy. Kept
  /// separate from the compass reading so [currentHeading] can prefer
  /// whichever source is actually meaningful right now.
  double? _gpsCourse;
  DateTime? _gpsCourseAt;
  double? _compassHeading;
  double _lastKnownHeading = 0;

  /// Total length of the route currently being navigated — the denominator
  /// for [routeProgress]. Taken from the route rather than accumulated from
  /// the live stream so GPS wobble can't make the progress bar run backwards.
  ///
  /// Rebaselined on every reroute: the replacement route is measured from
  /// where the tourist is *now*, so keeping the original total would show them
  /// most of the way through a journey they have just restarted.
  double _totalRouteMeters;

  // ── UC-M05 rerouting ────────────────────────────────────────────────────

  /// Consecutive fixes that have landed outside
  /// [MapConstants.navigationOffRouteThresholdMeters]. Reset by any fix back
  /// inside the corridor, so only a sustained departure from the route counts.
  int _consecutiveOffRouteFixes = 0;

  /// True while a replacement route is being fetched. Guards against a second
  /// request being started on the next fix while the first is still in flight
  /// — at one fix a second, an unguarded reroute would fire a Directions call
  /// every second for as long as the tourist stayed off route.
  bool _isRerouting = false;
  bool get isRerouting => _isRerouting;

  /// Set when a reroute attempt fails. Navigation carries on with the route it
  /// already has; this is what [NavigationView] shows its retry affordance
  /// from.
  String? rerouteErrorMessage;

  /// The location stream outlives an in-flight Directions call, so a reroute
  /// that returns after the screen is gone must not touch state or notify.
  bool _isDisposed = false;

  void _startTracking() {
    _locationSubscription = _locationService.startNavigationUpdates().listen(
      _onLocationUpdate,
      onError: (Object _) {
        errorMessage = MapErrorMessages.locationTimeout;
        notifyListeners();
      },
    );

    if (_compassService.isCompassAvailable) {
      _compassSubscription = _compassService.headingStream.listen(
        _onCompassUpdate,
      );
    }
  }

  /// Where the puck should point, degrees clockwise from north, resolved from
  /// the most trustworthy source available at this instant.
  ///
  /// GPS course over ground is the truest "which way am I travelling" signal,
  /// but it is pure noise below walking pace, so it is only trusted while the
  /// tourist is actually moving and for a few seconds afterwards. The
  /// magnetometer keeps working while stationary — it reports where the phone
  /// is pointing, which is what a tourist holding it up to read the next turn
  /// means anyway. With neither available the arrow holds its last direction
  /// instead of snapping back to north.
  double get currentHeading {
    final courseAt = _gpsCourseAt;
    if (_gpsCourse != null &&
        courseAt != null &&
        DateTime.now().difference(courseAt) < const Duration(seconds: 5)) {
      return _gpsCourse!;
    }
    return _compassHeading ?? _lastKnownHeading;
  }

  RouteStep? get currentStep =>
      route.steps.isEmpty ? null : route.steps[currentStepIndex];

  /// The manoeuvre after the current one, shown as a "then …" preview so the
  /// tourist can plan two turns ahead instead of one.
  RouteStep? get nextStep => currentStepIndex + 1 < route.steps.length
      ? route.steps[currentStepIndex + 1]
      : null;

  /// UC-M05 step 4: metres remaining to the current step's manoeuvre point.
  double get distanceToNextStepMeters {
    final step = currentStep;
    if (step == null) return 0;
    return _navigationService.distanceToStepEnd(currentPosition, step);
  }

  /// Live distance remaining to the destination — the un-walked tail of the
  /// current step plus every step still ahead.
  double get remainingDistanceMeters {
    if (route.steps.isEmpty) return 0;
    var remaining = distanceToNextStepMeters;
    for (var i = currentStepIndex + 1; i < route.steps.length; i++) {
      remaining += route.steps[i].distanceMeters;
    }
    return remaining;
  }

  /// Live ETA, prorated from each step's own duration rather than
  /// re-querying the Directions API on every GPS update.
  int get remainingDurationSeconds {
    if (route.steps.isEmpty) return 0;
    final step = route.steps[currentStepIndex];
    final stepRemainingRatio = step.distanceMeters > 0
        ? (distanceToNextStepMeters / step.distanceMeters).clamp(0, 1)
        : 0.0;
    var remaining = step.durationSeconds * stepRemainingRatio;
    for (var i = currentStepIndex + 1; i < route.steps.length; i++) {
      remaining += route.steps[i].durationSeconds;
    }
    return remaining.round();
  }

  /// Wall-clock arrival time — easier to act on than "37 min left" when the
  /// tourist is deciding whether they have time for a detour.
  DateTime get estimatedArrivalTime =>
      DateTime.now().add(Duration(seconds: remainingDurationSeconds));

  /// 0 at the start of the route, 1 on arrival. Drives the progress bar.
  double get routeProgress {
    if (_totalRouteMeters <= 0) return 0;
    final travelled = _totalRouteMeters - remainingDistanceMeters;
    return (travelled / _totalRouteMeters).clamp(0.0, 1.0);
  }

  /// The part of the route already covered, drawn dimmed underneath the live
  /// route line so progress is visible on the map itself and not only in the
  /// progress bar.
  ///
  /// Approximated at the current step's boundary rather than by projecting the
  /// live fix onto the polyline: at navigation zoom the difference is a few
  /// metres, and a step boundary can never jitter backwards the way a per-fix
  /// projection would.
  List<LatLng> get travelledPolyline {
    if (route.steps.isEmpty || currentStepIndex == 0) return const [];
    return [
      for (var i = 0; i < currentStepIndex; i++) ...route.steps[i].polylinePoints,
    ];
  }

  void _onLocationUpdate(GpsLocation location) {
    final now = DateTime.now();
    final position = LatLng(location.latitude, location.longitude);

    if (_lastFixAt != null) fixInterval = now.difference(_lastFixAt!);
    _lastFixAt = now;
    _previousPosition = currentPosition;
    currentPosition = position;
    errorMessage = null;

    _updateGpsCourse(location, now);
    _lastKnownHeading = currentHeading;

    if (route.steps.isNotEmpty) {
      currentStepIndex = _navigationService.advanceStepIndex(
        route.steps,
        currentStepIndex,
        currentPosition,
      );
    }

    final destLatLng = LatLng(destination.latitude, destination.longitude);
    if (!hasArrived &&
        _navigationService.hasArrived(currentPosition, destLatLng)) {
      hasArrived = true;
      justArrived = true;
    }

    _evaluateOffRoute();

    notifyListeners();
  }

  /// UC-M05 rerouting: decides, from this one fix, whether the tourist has
  /// genuinely left the route.
  ///
  /// The question this asks is deliberately different from the one
  /// [NavigationService.advanceStepIndex] asks. Step advancement is forgiving
  /// by design — it would rather keep showing a manoeuvre the tourist missed
  /// than skip the instruction that gets them back on track — so on its own it
  /// leaves someone who took the wrong road following directions for a road
  /// they are no longer on, forever. Rerouting is the other half of that
  /// bargain: once enough consecutive fixes agree the tourist is nowhere near
  /// the remaining route, the route itself is the thing that is wrong, and it
  /// gets replaced rather than re-explained.
  ///
  /// Nothing happens once the tourist has arrived: a fix that drifts 50 m from
  /// the last leg while they stand at the destination is not a wrong turn, and
  /// rerouting them to somewhere they already are would be absurd.
  void _evaluateOffRoute() {
    if (hasArrived || _route.steps.isEmpty) {
      _consecutiveOffRouteFixes = 0;
      return;
    }

    final offRoute = _navigationService.isOffRoute(
      _route.steps,
      currentStepIndex,
      currentPosition,
    );

    if (!offRoute) {
      // Rejoining the route — or a spike falling back into the corridor —
      // clears the tally outright rather than decaying it. A tourist who is
      // back on the road needs no new directions, however many stray fixes
      // preceded this one.
      _consecutiveOffRouteFixes = 0;
      return;
    }

    _consecutiveOffRouteFixes++;
    if (_consecutiveOffRouteFixes <
        MapConstants.navigationOffRouteFixesBeforeReroute) {
      return;
    }

    // Already fetching one: the tally keeps climbing but no second request is
    // made, and whichever way the in-flight one resolves resets it.
    if (_isRerouting) return;

    unawaited(_requestReroute());
  }

  /// UC-M05 rerouting: asks for a fresh route from the tourist's live position
  /// to the destination they were always heading for, in the mode they chose.
  ///
  /// The origin is read at the moment of the call rather than captured when
  /// the off-route tally started: by now the tourist has been walking the
  /// wrong way for several seconds, and routing them from where they were is
  /// routing them from a position they have already left.
  Future<void> _requestReroute() async {
    _isRerouting = true;
    rerouteErrorMessage = null;
    notifyListeners();

    final origin = currentPosition;
    RouteResult? replacement;
    try {
      replacement = await _routeService.calculateRoute(
        origin: origin,
        // The destination never changes — a wrong turn is a question about how
        // to get there, not about where the tourist is going.
        destination: LatLng(destination.latitude, destination.longitude),
        mode: mode,
      );
    } catch (_) {
      replacement = null;
    }

    if (_isDisposed) return;

    _isRerouting = false;
    // Either outcome clears the tally. On success the tourist is on the new
    // route and there is nothing to count; on failure it acts as a backoff —
    // another full run of off-route fixes has to accumulate before the API is
    // asked again, instead of every subsequent fix retrying a call that has
    // just failed.
    _consecutiveOffRouteFixes = 0;

    // A route that came back empty is no more usable than one that failed to
    // arrive, and both leave the tourist better off with the directions
    // already on screen than with none.
    if (replacement == null ||
        !replacement.routeFound ||
        replacement.steps.isEmpty) {
      rerouteErrorMessage = MapErrorMessages.rerouteFailed;
      notifyListeners();
      return;
    }

    _applyRoute(replacement);
    notifyListeners();
  }

  /// Swaps in a replacement route and rebaselines everything derived from the
  /// old one.
  ///
  /// [remainingDistanceMeters], [remainingDurationSeconds],
  /// [estimatedArrivalTime] and [routeProgress] are all computed from
  /// [_route], [currentStepIndex] and [_totalRouteMeters], so resetting those
  /// three is what updates the whole screen.
  void _applyRoute(RouteResult replacement) {
    _route = replacement;
    // The new route starts at the tourist's current position, so its first
    // step is the one they are on — there is no earlier progress to preserve.
    currentStepIndex = 0;
    _totalRouteMeters = replacement.distanceKm * 1000;
    rerouteErrorMessage = null;
  }

  /// Lets [NavigationView] ask again after a failed reroute, without waiting
  /// for another run of off-route fixes to build up.
  void retryReroute() {
    if (_isRerouting || hasArrived) return;
    unawaited(_requestReroute());
  }

  /// Dismisses the failure notice without retrying — the tourist has decided
  /// the original directions are good enough.
  void dismissRerouteError() {
    if (rerouteErrorMessage == null) return;
    rerouteErrorMessage = null;
    notifyListeners();
  }

  /// Refreshes the GPS-derived heading. The reported course is used while the
  /// tourist is moving fast enough for it to mean something; otherwise, on a
  /// device with no magnetometer to fall back on, the bearing between two
  /// fixes a few metres apart still beats leaving the arrow stuck.
  void _updateGpsCourse(GpsLocation location, DateTime now) {
    if (location.speedMetersPerSecond >=
        MapConstants.navigationCourseMinSpeedMps) {
      _gpsCourse = normaliseDegrees(location.headingDegrees);
      _gpsCourseAt = now;
      return;
    }

    final previous = _previousPosition;
    if (_compassHeading != null || previous == null) return;

    final moved = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      currentPosition.latitude,
      currentPosition.longitude,
    );
    if (moved >= 3) {
      _gpsCourse = bearingBetween(previous, currentPosition);
      _gpsCourseAt = now;
    }
  }

  /// Raw magnetometer output is noisy, so a reading is dropped unless it moves
  /// the heading by at least
  /// [MapConstants.compassHeadingChangeThresholdDegrees] — otherwise the puck
  /// would twitch continuously while the tourist stands still.
  void _onCompassUpdate(double? heading) {
    if (heading == null) return;
    final normalised = normaliseDegrees(heading);
    final previous = _compassHeading;
    if (previous != null &&
        angleDifference(previous, normalised) <
            MapConstants.compassHeadingChangeThresholdDegrees) {
      return;
    }

    final before = currentHeading;
    _compassHeading = normalised;
    // While GPS course is fresh it outranks the compass, so a magnetometer
    // sample that doesn't actually change where the puck points shouldn't wake
    // the view up and restart its interpolation for nothing.
    if (currentHeading == before) return;

    _lastKnownHeading = currentHeading;
    notifyListeners();
  }

  /// Consumed by [NavigationView] so the arrival haptic fires only once.
  void acknowledgeArrival() => justArrived = false;

  @override
  void dispose() {
    _isDisposed = true;
    _locationSubscription?.cancel();
    _compassSubscription?.cancel();
    super.dispose();
  }
}
