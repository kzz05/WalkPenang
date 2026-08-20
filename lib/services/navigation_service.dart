import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../constants/map_constants.dart';
import '../models/route_step.dart';

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

  /// UC-M05 step 4: advances through [steps] while the tourist is within
  /// [arrivalRadiusMeters] of the current step's end, so a burst of closely
  /// spaced steps (e.g. a short crossing) doesn't strand the instruction
  /// banner one step behind the tourist's actual position.
  int advanceStepIndex(
    List<RouteStep> steps,
    int currentIndex,
    LatLng position, {
    double arrivalRadiusMeters = 15,
  }) {
    var index = currentIndex;
    while (index < steps.length - 1 &&
        distanceToStepEnd(position, steps[index]) <= arrivalRadiusMeters) {
      index++;
    }
    return index;
  }

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
