import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../constants/map_constants.dart';
import '../models/route_step.dart';
import '../utils/route_geometry.dart';

/// In-App Navigation Sub Module (UC-M05). Pure step-advancement / arrival
/// logic for turn-by-turn walking navigation rendered on WalkPenang's own
/// map — no external app hand-off. Driven by the live GPS stream in
/// [NavigationController].
class NavigationService {
  /// UC-M05 step 4: metres from [position] to the end of [step] — used both
  /// to decide when to advance to the next step and to show "in N m, turn…".
  double distanceToStepEnd(LatLng position, RouteStep step) {
    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      step.endLocation.latitude,
      step.endLocation.longitude,
    );
  }

  /// UC-M05 step 4: advances [currentIndex] to the step the tourist is
  /// actually on, given the fix at [position].
  ///
  /// A step is finished on either of two grounds:
  ///
  /// * **Proximity** — the fix is within [arrivalRadiusMeters] of the step's
  ///   manoeuvre point. The ordinary case: the tourist walked through the
  ///   waypoint. Applied in a loop, so a burst of closely spaced steps (a
  ///   short crossing) doesn't strand the banner one step behind.
  /// * **Progress** — the fix lies beyond the end of the current step's own
  ///   geometry *and* matches a later leg of the route, within
  ///   [routeCorridorMeters]. The tourist walked *past* the waypoint rather
  ///   than through it.
  ///
  /// The second ground is what stops navigation freezing on "step 1 of 5".
  /// With proximity as the only test, any fix pattern that straddles a
  /// waypoint — a corner cut wide, a sparse mock route, a fix dropped in an
  /// urban canyon — leaves the index on a step the tourist finished long ago,
  /// and every figure derived from it (distance remaining, ETA, progress bar,
  /// the dimmed travelled polyline) keeps counting route already covered.
  /// Widening the radius would only move where that happens; asking which leg
  /// of the route the tourist is *on* answers the question the index is really
  /// posing, and lets a missed waypoint be recovered from on the next fix.
  ///
  /// Matching against every remaining leg rather than just the next one is
  /// deliberate: a tourist can be two legs further on by the time a fix
  /// arrives (a short manoeuvre between two long ones), and the stale legs in
  /// between must be dropped together or the index sticks again on the first
  /// of them.
  ///
  /// The index only ever moves forward, so a fix that wanders back over an
  /// earlier leg — or a route that doubles back on itself — cannot rewind the
  /// banner.
  int advanceStepIndex(
    List<RouteStep> steps,
    int currentIndex,
    LatLng position, {
    double arrivalRadiusMeters =
        MapConstants.navigationStepArrivalRadiusMeters,
    double routeCorridorMeters = MapConstants.navigationRouteCorridorMeters,
  }) {
    if (steps.isEmpty) return currentIndex;

    var index = currentIndex;
    var advanced = true;
    while (advanced && index < steps.length - 1) {
      advanced = false;

      while (index < steps.length - 1 &&
          distanceToStepEnd(position, steps[index]) <= arrivalRadiusMeters) {
        index++;
        advanced = true;
      }
      if (index >= steps.length - 1) break;

      final matched = _laterStepBeingTravelled(
        steps,
        index,
        position,
        routeCorridorMeters,
      );
      if (matched != null) {
        index = matched;
        advanced = true;
      }
    }
    return index;
  }

  /// The later leg [position] says the tourist is now travelling, or null if
  /// nothing about this fix says they have left [index] behind.
  ///
  /// Both halves of the test are required. Being beyond the end of the current
  /// step alone is equally true of a tourist who overshot a junction onto the
  /// wrong road, and skipping the step for them would drop the very
  /// instruction they need to get back on route. Matching a later leg alone is
  /// true at the shared vertex before the manoeuvre has been made. Together
  /// they say the tourist is past this manoeuvre *and* on the road it leads
  /// to.
  ///
  /// The candidate also has to match its leg better than the fix matches the
  /// current one, which leaves a tourist standing right at the manoeuvre point
  /// on the step they are still being instructed through.
  int? _laterStepBeingTravelled(
    List<RouteStep> steps,
    int index,
    LatLng position,
    double routeCorridorMeters,
  ) {
    final onCurrent = matchToPath(position, _pathOf(steps[index]));
    if (!onCurrent.isPastEnd) return null;

    int? best;
    var bestOffset = onCurrent.offsetMeters;
    for (var i = index + 1; i < steps.length; i++) {
      final match = matchToPath(position, _pathOf(steps[i]));
      if (match.offsetMeters <= routeCorridorMeters &&
          match.offsetMeters < bestOffset) {
        best = i;
        bestOffset = match.offsetMeters;
      }
    }
    return best;
  }

  /// A step's own geometry, falling back to the straight line between its end
  /// points. Very short manoeuvres come back from the Directions API with a
  /// one-point (or empty) polyline, and those still have a direction worth
  /// measuring against.
  List<LatLng> _pathOf(RouteStep step) => step.polylinePoints.length >= 2
      ? step.polylinePoints
      : <LatLng>[step.startLocation, step.endLocation];

  /// UC-M05 postcondition: within the Walking & Carbon module's check-in
  /// threshold of the destination counts as arrived.
  bool hasArrived(LatLng position, LatLng destination) {
    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      destination.latitude,
      destination.longitude,
    );
    return MapConstants.isWithinCheckInRange(distance);
  }
}
