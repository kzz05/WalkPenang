import '../constants/map_constants.dart';

/// A single GPS reading (UC-008), timestamped so the caller can tell how
/// fresh it is.
class GpsLocation {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime timestamp;

  /// Course over ground in degrees clockwise from true north — the
  /// direction the tourist is *moving*, not the direction the device is
  /// physically pointing. 0.0 while stationary or unavailable (UC-M05
  /// in-app navigation arrow).
  final double headingDegrees;

  /// Ground speed in metres per second, used to tell "genuinely turning"
  /// apart from "GPS jitter while stationary" for [headingDegrees].
  final double speedMetersPerSecond;

  GpsLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.timestamp,
    this.headingDegrees = 0.0,
    this.speedMetersPerSecond = 0.0,
  });

  /// UC-008 A2: below the threshold, the reading is shown but flagged as
  /// possibly unreliable rather than discarded outright.
  bool get isAccurate =>
      accuracyMeters <= MapConstants.gpsAccuracyThresholdMeters;
}
