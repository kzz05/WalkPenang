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

  // --- Slow walking (regression) --------------------------------------------
  //
  // KM COVERED and KCAL BURNED sat at zero for the whole of a slow walk. Each
  // fix was measured against the one before it, so a stream delivering a metre
  // or two at a time never produced a step that reached the 5 m filter — and
  // because the reference point moved anyway, the metres already walked were
  // thrown away with it. Distance is now measured from the last *counted*
  // position, so sub-threshold fixes accumulate instead of cancelling out.

  test('consecutive sub-threshold steps accumulate once they pass the filter',
      () async {
    // Three 2 m shuffles: nothing counts until the third, which stands 6 m
    // from where the counting started.
    final updates = await _run([
      _at(600, 0),
      _at(598, 0),
      _at(596, 0),
      _at(594, 0),
    ]);

    expect(
      updates.map((u) => u.metresWalked),
      [0, 0, 0, closeTo(6, 1e-9)],
    );
  });

  test('a slow walk covers the same ground as a fast one', () async {
    // 60 m in 2 m fixes against 60 m in 20 m fixes: the tile must not depend
    // on how often the phone happens to report.
    final slow = await _run([for (var x = 600; x >= 540; x -= 2) _at(x.toDouble(), 0)]);
    final fast = await _run([for (var x = 600; x >= 540; x -= 20) _at(x.toDouble(), 0)]);

    expect(slow.last.metresWalked, closeTo(60, 1e-6));
    expect(fast.last.metresWalked, closeTo(60, 1e-6));
  });

  test('a long slow walk is counted in full, not in whole-threshold chunks',
      () async {
    // 1.5 m per fix, 200 fixes: 300 m walked, and every metre of it counted —
    // rounding each accepted step down to the filter would lose a fifth of it.
    final updates =
        await _run([for (var i = 0; i <= 200; i++) _at(600 - i * 1.5, 0)]);

    expect(updates.last.metresWalked, closeTo(300, 1e-6));
  });

  test('stationary jitter never accumulates, however long it goes on',
      () async {
    // 400 fixes wobbling inside a 3 m box around one spot — a tourist sitting
    // at a kopitiam, not walking. Measuring fix-to-fix would have added
    // hundreds of metres; measuring from the anchor adds none, because the
    // wobble never leaves the ball.
    final jitter = <double>[0, 1.4, -1.2, 0.9, -1.5, 1.1, -0.6, 1.3];
    final updates = await _run([
      for (var i = 0; i < 400; i++)
        _at(600 + jitter[i % jitter.length], jitter[(i + 3) % jitter.length]),
    ]);

    expect(updates.last.metresWalked, 0);
  });

  test('a teleport still adds nothing, and walking resumes after it', () async {
    // The jump is rejected, but the tourist is genuinely somewhere else now —
    // so the 20 m they walk from the new position is still theirs.
    final updates = await _run([
      _at(600, 0),
      _at(100, 0), // 500 m in one fix
      _at(80, 0),
    ]);

    expect(updates[1].metresWalked, 0);
    expect(updates.last.metresWalked, closeTo(20, 1e-9));
  });
}
