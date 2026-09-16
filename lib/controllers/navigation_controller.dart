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
import '../services/compass_service.dart';
import '../services/location_service.dart';
import '../services/navigation_service.dart';
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
    required this.route,
    required this.destination,
    required LatLng initialPosition,
    LocationService? locationService,
    NavigationService? navigationService,
    CompassService? compassService,
  }) : _locationService = locationService ?? LocationService(),
       _navigationService = navigationService ?? NavigationService(),
       _compassService = compassService ?? CompassService(),
       currentPosition = initialPosition {
    _startTracking();
  }

  final RouteResult route;
  final PlaceModel destination;
  final LocationService _locationService;
  final NavigationService _navigationService;
  final CompassService _compassService;

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

  /// Total route length as originally calculated — the denominator for
  /// [routeProgress]. Taken from the route rather than accumulated from the
  /// live stream so GPS wobble can't make the progress bar run backwards.
  late final double _totalRouteMeters = route.distanceKm * 1000;

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
    _locationSubscription?.cancel();
    _compassSubscription?.cancel();
    super.dispose();
  }
}
