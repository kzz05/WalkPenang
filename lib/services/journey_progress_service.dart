import 'dart:async';

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
  /// Cumulative metres walked since the stream was subscribed to.
  ///
  /// Emits on each accepted position fix, so a listener can render distance
  /// covered without accumulating anything itself.
  Stream<double> metresWalked();
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
  Stream<double> metresWalked() => const Stream<double>.empty();
}

/// The production implementation, summing the distance between consecutive
/// GPS fixes from [LocationService].
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
  Stream<double> metresWalked() {
    GpsLocation? previous;
    var total = 0.0;

    return _locationService.startLocationUpdates().map((fix) {
      final last = previous;
      previous = fix;
      if (last == null) return total;

      final step = _locationService.distanceMeters(
        startLatitude: last.latitude,
        startLongitude: last.longitude,
        endLatitude: fix.latitude,
        endLongitude: fix.longitude,
      );

      // The position stream already applies a distance filter, so anything
      // below it is jitter around a stationary tourist rather than movement.
      // Counting it would have someone standing still slowly "walking" a
      // route they never left the spot for.
      if (step < MapConstants.locationUpdateDistanceFilterMeters ||
          step > _implausibleJumpMeters) {
        return total;
      }

      total += step;
      return total;
    });
  }
}
