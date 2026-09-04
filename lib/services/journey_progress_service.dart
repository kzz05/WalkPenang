import 'dart:async';

import 'package:flutter/foundation.dart';

import '../constants/map_constants.dart';
import '../models/gps_location.dart';
import 'location_service.dart';

/// Live progress for an in-flight journey (UC-W05) — how far the tourist has
/// actually walked, as opposed to how far the route said they would.
///
/// Split out behind an interface for the same reason
/// [ArrivalVerificationService] is: [JourneyCompletionController] must not
/// talk to Geolocator itself, and the debug journey flow drives the real
/// views with no GPS at all.
///
/// Until this existed the Active Walking screen's KM COVERED and MIN
/// REMAINING tiles had no source, so they rendered their "not available"
/// state for the whole journey.
abstract class JourneyProgressService {
  /// Emits one [JourneyProgressUpdate] per accepted position fix, so a
  /// listener can render both distance covered and progress towards the
  /// destination without accumulating or measuring anything itself.
  ///
  /// The destination is a parameter rather than a constructor field so the
  /// two figures come off a single position stream. Measuring how far the
  /// tourist still has to go from a second subscription would double the
  /// GPS cost and let the two readings disagree about where the tourist is.
  Stream<JourneyProgressUpdate> track({
    required double destinationLatitude,
    required double destinationLongitude,
  });
}

/// One position fix, expressed as the two figures the Active Walking screen
/// needs — deliberately kept apart, because they answer different questions
/// and move independently.
@immutable
class JourneyProgressUpdate {
  /// Cumulative metres physically walked since the stream was subscribed to.
  /// Only ever grows, including when the tourist walks the wrong way.
  final double metresWalked;

  /// Straight-line metres from this fix to the destination. Falls as the
  /// tourist closes in, rises again if they walk away, and barely moves
  /// while they wander in circles.
  final double metresToDestination;

  const JourneyProgressUpdate({
    required this.metresWalked,
    required this.metresToDestination,
  });
}

/// Emits nothing, so KM COVERED and MIN REMAINING stay unavailable.
///
/// This is [JourneyCompletionController]'s default, and the production wiring
/// in journey_flow_view.dart overrides it with
/// [LocationJourneyProgressService]. That is the opposite of how
/// [ArrivalVerificationService] defaults — it defaults to the real thing —
/// and the difference is deliberate: arrival is verified by a one-shot call
/// that only touches Geolocator when invoked, whereas a position *stream*
/// binds to Geolocator's event channel the moment it is listened to. Doing
/// that from a constructor throws with no Flutter binding, as an
/// unhandled async error that no try/catch or onError around the
/// subscription can intercept — which took out every plain unit test that
/// builds the controller.
///
/// So the safe default is to track nothing, and the one production call site
/// opts in.
class NoJourneyProgressService implements JourneyProgressService {
  const NoJourneyProgressService();

  @override
  Stream<JourneyProgressUpdate> track({
    required double destinationLatitude,
    required double destinationLongitude,
  }) =>
      const Stream<JourneyProgressUpdate>.empty();
}

/// The production implementation: sums the distance between consecutive GPS
/// fixes from [LocationService] for [JourneyProgressUpdate.metresWalked], and
/// measures each fix against the destination for
/// [JourneyProgressUpdate.metresToDestination]. One subscription feeds both.
class LocationJourneyProgressService implements JourneyProgressService {
  LocationJourneyProgressService({LocationService? locationService})
      : _locationService = locationService ?? LocationService();

  final LocationService _locationService;

  /// A single fix further than this from the previous one is treated as a
  /// glitch rather than a walk — a tower hand-off or a mock-location jump can
  /// teleport the reported position, and one bad fix would otherwise add
  /// kilometres to the total that the tourist never walked.
  static const double _implausibleJumpMeters = 200;

  @override
  Stream<JourneyProgressUpdate> track({
    required double destinationLatitude,
    required double destinationLongitude,
  }) {
    GpsLocation? previous;
    var metresWalked = 0.0;
    double? metresToDestination;

    return _locationService.startLocationUpdates().map((fix) {
      final last = previous;
      previous = fix;

      final step = last == null
          ? null
          : _locationService.distanceMeters(
              startLatitude: last.latitude,
              startLongitude: last.longitude,
              endLatitude: fix.latitude,
              endLongitude: fix.longitude,
            );

      final isGlitch = step != null && step > _implausibleJumpMeters;

      // The position stream already applies a distance filter, so anything
      // below it is jitter around a stationary tourist rather than movement.
      // Counting it would have someone standing still slowly "walking" a
      // route they never left the spot for.
      if (step != null &&
          !isGlitch &&
          step >= MapConstants.locationUpdateDistanceFilterMeters) {
        metresWalked += step;
      }

      // A teleported fix is rejected for both figures, not just the walked
      // total — otherwise one bad reading would swing the progress bar to a
      // position the tourist was never at. The first fix has nothing to be a
      // jump from, and always sets the starting distance.
      if (!isGlitch || metresToDestination == null) {
        metresToDestination = _locationService.distanceMeters(
          startLatitude: fix.latitude,
          startLongitude: fix.longitude,
          endLatitude: destinationLatitude,
          endLongitude: destinationLongitude,
        );
      }

      return JourneyProgressUpdate(
        metresWalked: metresWalked,
        metresToDestination: metresToDestination!,
      );
    });
  }
}
