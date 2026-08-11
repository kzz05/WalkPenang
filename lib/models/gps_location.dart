import '../constants/map_constants.dart';

/// A single GPS reading (UC-008), timestamped so the caller can tell how
/// fresh it is.
class GpsLocation {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime timestamp;

  GpsLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.timestamp,
  });

  /// UC-008 A2: below the threshold, the reading is shown but flagged as
  /// possibly unreliable rather than discarded outright.
  bool get isAccurate =>
      accuracyMeters <= MapConstants.gpsAccuracyThresholdMeters;
}
