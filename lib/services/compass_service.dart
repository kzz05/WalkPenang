import 'package:flutter_compass/flutter_compass.dart';

/// Wraps the device magnetometer via flutter_compass so the rest of the app
/// never talks to the sensor plugin directly.
///
/// This is the tourist's actual facing direction — distinct from
/// [GpsLocation.headingDegrees] (in `models/gps_location.dart`), which is GPS
/// course-over-ground and only meaningful while moving. Compass heading is
/// available while stationary, which is what compass-follow map rotation and
/// the location puck's direction indicator need.
class CompassService {
  /// False on devices/platforms without a magnetometer (some tablets,
  /// emulators, desktop) — callers should hide compass-dependent UI rather
  /// than subscribing to [headingStream].
  bool get isCompassAvailable => FlutterCompass.events != null;

  /// Heading in degrees clockwise from true north. Emits null for individual
  /// readings the sensor couldn't resolve (e.g. needs calibration); callers
  /// should keep showing the last good heading rather than treating null as
  /// "facing north".
  Stream<double?> get headingStream {
    final events = FlutterCompass.events;
    if (events == null) return const Stream.empty();
    return events.map((event) => event.heading);
  }
}
