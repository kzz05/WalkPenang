import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Where a live GPS fix sits relative to one leg of a route (UC-M05).
///
/// In-app navigation used to decide "have I finished this step?" purely from
/// the distance to the step's end point. That answers a *proximity* question,
/// and the question it needed answering was a *progress* one: a tourist who
/// cuts a corner wide, or a mock route whose sample points straddle the
/// waypoint, can walk the whole step without any single fix landing inside the
/// arrival radius, and the banner then sticks on that step for the rest of the
/// journey. Matching the fix against the leg's geometry answers the progress
/// question directly.
@immutable
class PathMatch {
  const PathMatch({required this.offsetMeters, required this.isPastEnd});

  /// Distance from the fix to the nearest point anywhere on the leg — how far
  /// off this leg the tourist is, rather than how far from its end.
  final double offsetMeters;

  /// True when that nearest point is the leg's final vertex, which is
  /// geometrically the same as saying the fix lies beyond the line drawn
  /// across the end of the leg: the tourist has passed it, however wide.
  ///
  /// False for a degenerate leg (fewer than two distinct points), which has no
  /// direction to be past — proximity is the only sensible test there.
  final bool isPastEnd;

  /// A leg that could not be matched at all.
  static const PathMatch none =
      PathMatch(offsetMeters: double.infinity, isPastEnd: false);
}

/// Matches [position] against [path], a leg of the route as an ordered list of
/// coordinates.
///
/// The whole computation runs on a local flat-earth projection centred on
/// [position]. Over the tens or hundreds of metres a single route step spans,
/// the error against a great-circle calculation is well under a metre — far
/// less than the GPS noise the result is compared against — and it buys the
/// vector arithmetic a projection needs and a great-circle distance cannot do.
PathMatch matchToPath(LatLng position, List<LatLng> path) {
  if (path.length < 2) return PathMatch.none;

  final origin = position;
  final metresPerDegreeLongitude =
      _metresPerDegreeLatitude * math.cos(origin.latitude * math.pi / 180);

  _Point toLocal(LatLng point) => _Point(
        (point.longitude - origin.longitude) * metresPerDegreeLongitude,
        (point.latitude - origin.latitude) * _metresPerDegreeLatitude,
      );

  var best = double.infinity;
  var bestIsFinalVertex = false;

  var start = toLocal(path.first);
  for (var i = 1; i < path.length; i++) {
    final end = toLocal(path[i]);
    final dx = end.x - start.x;
    final dy = end.y - start.y;
    final lengthSquared = dx * dx + dy * dy;

    // A repeated coordinate contributes no segment of its own; the vertex
    // itself is still covered by the segments either side of it.
    if (lengthSquared == 0) {
      start = end;
      continue;
    }

    // Projection of the fix (which is the local origin) onto the segment,
    // clamped to it: t == 1 means the fix lies beyond the segment's far end.
    final t = ((-start.x * dx + -start.y * dy) / lengthSquared).clamp(0.0, 1.0);
    final closestX = start.x + dx * t;
    final closestY = start.y + dy * t;
    final distance = math.sqrt(closestX * closestX + closestY * closestY);

    if (distance < best) {
      best = distance;
      bestIsFinalVertex = i == path.length - 1 && t == 1.0;
    }

    start = end;
  }

  if (best == double.infinity) return PathMatch.none;
  return PathMatch(offsetMeters: best, isPastEnd: bestIsFinalVertex);
}

/// Metres per degree of latitude — constant enough anywhere on earth, and the
/// same figure the longitude scale above is derived from.
const double _metresPerDegreeLatitude = 111320.0;

class _Point {
  const _Point(this.x, this.y);
  final double x;
  final double y;
}
