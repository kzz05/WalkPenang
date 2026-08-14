// Walking & Carbon Module — arrival verification (UC-W06).
//
// Thin, Walking-owned abstraction over Map & GPS's LocationService
// (lib/services/location_service.dart). It exists purely as a seam:
// JourneyCompletionController depends on ArrivalVerificationService rather
// than on LocationService/Geolocator directly, so a lecturer demo (or a
// unit test) can supply a fake reading with no device GPS, no permission
// prompts and no timing flakiness. It never duplicates LocationService's
// logic — every call here delegates straight to it.

import '../models/gps_location.dart';
import 'location_service.dart';

/// How one arrival check resolved. [gpsUnavailable] covers both a location
/// fetch that threw (e.g. LocationService.getCurrentLocation's timeout) and
/// any other read failure — LocationService does not distinguish device-GPS
/// disabled from a fix that simply couldn't be acquired in time.
enum ArrivalCheckStatus {
  success,
  permissionDenied,
  gpsUnavailable,
  weakSignal
}

/// The result of one [ArrivalVerificationService.checkDistanceTo] call.
/// [distanceMeters] is only ever set alongside [ArrivalCheckStatus.success].
class ArrivalCheckReading {
  final ArrivalCheckStatus status;
  final double? distanceMeters;

  const ArrivalCheckReading.success(this.distanceMeters)
      : status = ArrivalCheckStatus.success;

  const ArrivalCheckReading.failure(this.status)
      : distanceMeters = null,
        assert(status != ArrivalCheckStatus.success,
            'use ArrivalCheckReading.success for a resolved distance');
}

/// Contract JourneyCompletionController depends on. Implemented for real by
/// [LocationArrivalVerificationService]; a lecturer-demo/test double can
/// implement it directly with no GPS or Firebase involved.
abstract class ArrivalVerificationService {
  /// One-shot check of the tourist's current distance to
  /// ([destinationLatitude], [destinationLongitude]).
  Future<ArrivalCheckReading> checkDistanceTo({
    required double destinationLatitude,
    required double destinationLongitude,
  });
}

/// Production implementation — wraps [LocationService] (UC-008) exactly as
/// the Map & GPS module exposes it, adding no GPS logic of its own.
class LocationArrivalVerificationService implements ArrivalVerificationService {
  LocationArrivalVerificationService({LocationService? locationService})
      : _locationService = locationService ?? LocationService();

  final LocationService _locationService;

  @override
  Future<ArrivalCheckReading> checkDistanceTo({
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    final access = await _locationService.requestLocationAccess();
    if (access != LocationAccessStatus.granted) {
      // The Map & GPS module now distinguishes "GPS service off" from
      // "permission denied", so this no longer has to report both as
      // permissionDenied. gpsUnavailable is what JourneyCompletionController
      // maps to VerifyBlockReason.gpsDisabled — the state VerifyLocationView
      // already renders but could not previously be reached.
      return ArrivalCheckReading.failure(
        access == LocationAccessStatus.serviceDisabled
            ? ArrivalCheckStatus.gpsUnavailable
            : ArrivalCheckStatus.permissionDenied,
      );
    }

    final GpsLocation location;
    try {
      location = await _locationService.getCurrentLocation();
    } catch (_) {
      // Covers getCurrentLocation's timeout and any other platform failure.
      return const ArrivalCheckReading.failure(
        ArrivalCheckStatus.gpsUnavailable,
      );
    }

    if (!_locationService.checkSignalAccuracy(location)) {
      return const ArrivalCheckReading.failure(ArrivalCheckStatus.weakSignal);
    }

    final distanceMeters = _locationService.distanceMeters(
      startLatitude: location.latitude,
      startLongitude: location.longitude,
      endLatitude: destinationLatitude,
      endLongitude: destinationLongitude,
    );
    return ArrivalCheckReading.success(distanceMeters);
  }
}
