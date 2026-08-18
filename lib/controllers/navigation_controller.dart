import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/gps_location.dart';
import '../models/place_model.dart';
import '../models/route_result.dart';
import '../models/route_step.dart';
import '../services/location_service.dart';
import '../services/navigation_service.dart';

/// Drives [NavigationView] — live turn-by-turn walking navigation rendered
/// on WalkPenang's own map (UC-M05), replacing the external Google Maps
/// hand-off. Reuses the [RouteResult] already fetched by
/// [RouteSummaryController] for UC-M04 rather than re-requesting it.
class NavigationController extends ChangeNotifier {
  NavigationController({
    required this.route,
    required this.destination,
    required LatLng initialPosition,
    LocationService? locationService,
    NavigationService? navigationService,
  }) : _locationService = locationService ?? LocationService(),
       _navigationService = navigationService ?? NavigationService(),
       currentPosition = initialPosition {
    _subscription = _locationService.startLocationUpdates().listen(
      _onLocationUpdate,
    );
  }

  final RouteResult route;
  final PlaceModel destination;
  final LocationService _locationService;
  final NavigationService _navigationService;
  StreamSubscription<GpsLocation>? _subscription;

  /// Below this ground speed, GPS course-over-ground is noisy/meaningless
  /// (e.g. the tourist paused at a crossing) — the arrow keeps pointing the
  /// way it last faced instead of snapping around.
  static const double _headingUpdateMinSpeedMps = 0.5;

  LatLng currentPosition;
  double currentHeading = 0.0;
  int currentStepIndex = 0;
  bool hasArrived = false;

  RouteStep? get currentStep =>
      route.steps.isEmpty ? null : route.steps[currentStepIndex];

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

  void _onLocationUpdate(GpsLocation location) {
    currentPosition = LatLng(location.latitude, location.longitude);
    if (location.speedMetersPerSecond >= _headingUpdateMinSpeedMps) {
      currentHeading = location.headingDegrees;
    }

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
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
