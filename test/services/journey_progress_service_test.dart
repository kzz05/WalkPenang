// Unit tests for LocationJourneyProgressService — the source of the Active
// Walking screen's KM COVERED tile and its progress bar.
//
// The LocationService is a hand-written subclass rather than the real thing:
// every method used here is overridden, so no Geolocator call (and therefore
// no platform binding) is ever reached.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:walkpenang/models/gps_location.dart';
import 'package:walkpenang/services/journey_progress_service.dart';
import 'package:walkpenang/services/location_service.dart';

/// Replays scripted fixes and measures distance on a flat plane, which is
/// accurate enough over the tens of metres these tests script and keeps the
/// expected numbers obvious.
class _FakeLocationService extends LocationService {
  _FakeLocationService(this.fixes);

  final List<GpsLocation> fixes;

  @override
  Stream<GpsLocation> startLocationUpdates() => Stream<GpsLocation>.fromIterable(fixes);

  @override
  double distanceMeters({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    final dx = endLatitude - startLatitude;
    final dy = endLongitude - startLongitude;
    return math.sqrt(dx * dx + dy * dy);
  }
}

/// Coordinates are used as plain metres by [_FakeLocationService].
GpsLocation _at(double x, double y) => GpsLocation(
      latitude: x,
      longitude: y,
      accuracyMeters: 5,
      timestamp: DateTime(2026, 8, 28),
    );

Future<List<JourneyProgressUpdate>> _run(
  List<GpsLocation> fixes, {
  double destX = 0,
  double destY = 0,
}) {
  return LocationJourneyProgressService(
    locationService: _FakeLocationService(fixes),
  )
      .track(destinationLatitude: destX, destinationLongitude: destY)
      .toList();
}

void main() {
  test('the first fix sets the starting distance and walks nothing', () async {
    final updates = await _run([_at(600, 0)]);

    expect(updates, hasLength(1));
    expect(updates.single.metresWalked, 0);
    expect(updates.single.metresToDestination, closeTo(600, 1e-9));
  });

  test('closing on the destination lowers the distance still to go', () async {
    // Steps stay under the implausible-jump guard, as a walk does.
    final updates = await _run([_at(600, 0), _at(450, 0), _at(300, 0)]);

    expect(
      updates.map((u) => u.metresToDestination),
      [closeTo(600, 1e-9), closeTo(450, 1e-9), closeTo(300, 1e-9)],
    );
    expect(updates.last.metresWalked, closeTo(300, 1e-9));
  });

  test('walking in circles adds metres walked without closing distance',
      () async {
    // A 40 m square, ending where it began: 160 m walked, no ground made up.
    final updates = await _run([
      _at(600, 0),
      _at(600, 40),
      _at(640, 40),
      _at(640, 0),
      _at(600, 0),
    ]);

    expect(updates.last.metresWalked, closeTo(160, 1e-6));
    expect(
      updates.last.metresToDestination,
      closeTo(updates.first.metresToDestination, 1e-9),
    );
  });

  test('a teleported fix is rejected for both figures', () async {
    final updates = await _run([
      _at(600, 0),
      // 500 m in one step — past the implausible-jump guard.
      _at(100, 0),
    ]);

    expect(updates.last.metresWalked, 0);
    expect(updates.last.metresToDestination, closeTo(600, 1e-9));
  });

  test('jitter below the distance filter is not counted as walking', () async {
    final updates = await _run([_at(600, 0), _at(602, 0)]);

    expect(updates.last.metresWalked, 0);
    // The position itself is still honest, so the bar may nudge.
    expect(updates.last.metresToDestination, closeTo(602, 1e-9));
  });
}
