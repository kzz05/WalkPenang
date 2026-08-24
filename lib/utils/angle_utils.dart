import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Compass-angle helpers shared by the live location puck (UC-008) and the
/// in-app navigation camera (UC-M05).
///
/// Headings are degrees clockwise from north and wrap at 360, so plain
/// arithmetic on them misbehaves exactly where it matters most: interpolating
/// from 350° to 10° the naive way spins the puck 340° the wrong way round
/// instead of 20° the right way.

/// Normalises any angle into `[0, 360)`.
double normaliseDegrees(double degrees) {
  final wrapped = degrees % 360;
  return wrapped < 0 ? wrapped + 360 : wrapped;
}

/// Smallest absolute angle between two headings, always `0..180`.
double angleDifference(double a, double b) {
  final diff = (a - b).abs() % 360;
  return diff > 180 ? 360 - diff : diff;
}

/// Interpolates from [from] to [to] the short way round the compass.
double lerpDegrees(double from, double to, double t) {
  final delta = ((to - from + 540) % 360) - 180;
  return normaliseDegrees(from + delta * t);
}

/// Straight-line interpolation between two coordinates. Over the tens of
/// metres between consecutive GPS fixes the earth is flat enough that a
/// linear blend is indistinguishable from a great-circle one.
LatLng lerpLatLng(LatLng from, LatLng to, double t) {
  return LatLng(
    from.latitude + (to.latitude - from.latitude) * t,
    from.longitude + (to.longitude - from.longitude) * t,
  );
}

/// Initial bearing from [from] to [to], degrees clockwise from north.
///
/// Used as the last-resort heading source while navigating: if the device has
/// no magnetometer and the tourist is moving too slowly for GPS course over
/// ground to mean anything, the direction they just travelled between two
/// fixes still points the puck the right way.
double bearingBetween(LatLng from, LatLng to) {
  final lat1 = from.latitude * math.pi / 180;
  final lat2 = to.latitude * math.pi / 180;
  final deltaLng = (to.longitude - from.longitude) * math.pi / 180;

  final y = math.sin(deltaLng) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(deltaLng);

  return normaliseDegrees(math.atan2(y, x) * 180 / math.pi);
}
