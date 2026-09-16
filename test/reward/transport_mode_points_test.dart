// Only a walked journey earns check-in points.
//
// FR-W01 (Transport Mode Selection) is the governing requirement: walking
// related carbon, calorie, check-in and reward features are enabled only when
// Walking is selected. FR-R01 defines the award itself, not the gate.
//
// Pure Dart — RewardPoints and TransportMode both avoid Flutter and Firestore
// deliberately, so this needs no binding and no Firebase project.
import 'package:test/test.dart';

import 'package:walkpenang/models/check_in_result.dart';
import 'package:walkpenang/models/transport_mode.dart';
import 'package:walkpenang/utils/reward_constants.dart';

void main() {
  group('RewardPoints.forCheckIn — transport mode', () {
    test('walking earns the flat award plus the distance bonus', () {
      expect(
        RewardPoints.forCheckIn(
          distanceMetres: 1300,
          transportMode: TransportMode.walking,
        ),
        RewardConstants.pointsPerCheckIn + 13,
      );
    });

    test('driving earns nothing, however far', () {
      expect(
        RewardPoints.forCheckIn(
          distanceMetres: 50000,
          transportMode: TransportMode.driving,
        ),
        0,
      );
    });

    test('public transport earns nothing', () {
      expect(
        RewardPoints.forCheckIn(
          distanceMetres: 5000,
          transportMode: TransportMode.publicTransport,
        ),
        0,
      );
    });

    test('a driven journey never beats a walked one', () {
      // The exploit this rule exists to close: covering more ground by car
      // than someone could on foot must not out-earn them.
      final drove = RewardPoints.forCheckIn(
        distanceMetres: 40000,
        transportMode: TransportMode.driving,
      );
      final walked = RewardPoints.forCheckIn(
        distanceMetres: 800,
        transportMode: TransportMode.walking,
      );
      expect(drove, lessThan(walked));
    });

    test('defaults to walking, so existing callers are unaffected', () {
      expect(
        RewardPoints.forCheckIn(distanceMetres: 2000),
        RewardPoints.forCheckIn(
          distanceMetres: 2000,
          transportMode: TransportMode.walking,
        ),
      );
    });

    test('the flat award is still withheld for a zero-distance drive', () {
      // Guards against "return the flat 10 and only scale the bonus" creeping
      // back in — a car journey earns nothing at all, not a participation fee.
      expect(
        RewardPoints.forCheckIn(
          distanceMetres: 0,
          transportMode: TransportMode.driving,
        ),
        0,
      );
    });
  });

  group('TransportMode.fromId', () {
    test('round-trips every mode through its stored name', () {
      for (final mode in TransportMode.values) {
        expect(TransportMode.fromId(mode.name), mode);
      }
    });

    test('a missing field reads as walking', () {
      // Check-ins written before transport modes existed carry no field, and
      // every one of those journeys was a walk. Reading them as anything else
      // would retroactively strip points from history.
      expect(TransportMode.fromId(null), TransportMode.walking);
    });

    test('an unrecognised value reads as walking', () {
      // Generous on purpose — which is precisely why firestore.rules restricts
      // the field to known ids on write. Without that rule this fallback would
      // be a way to mint points with an arbitrary string.
      expect(TransportMode.fromId('helicopter'), TransportMode.walking);
    });
  });

  group('CheckInResult', () {
    CheckInResult resultWith(TransportMode mode) => CheckInResult(
          checkInId: 'c1',
          userId: 'u1',
          destinationId: 'd1',
          distanceKm: 1.5,
          carbonSavedKg: 0.3,
          caloriesBurned: 60,
          checkInTime: DateTime(2026, 8, 14),
          transportMode: mode,
        );

    test('exposes whether the journey qualifies', () {
      expect(resultWith(TransportMode.walking).earnsPoints, isTrue);
      expect(resultWith(TransportMode.driving).earnsPoints, isFalse);
    });

    test('persists the mode by name', () {
      expect(
        resultWith(TransportMode.publicTransport).toMap()['transportMode'],
        'publicTransport',
      );
    });

    test('reads back a document written without a mode as walking', () {
      final legacy = CheckInResult.fromMap(<String, dynamic>{
        'checkInId': 'c1',
        'userId': 'u1',
        'destinationId': 'd1',
        'distanceKm': 1.0,
        'carbonSavedKg': 0.2,
        'caloriesBurned': 40.0,
        'checkInTime': DateTime(2026, 1, 1),
      });
      expect(legacy.transportMode, TransportMode.walking);
      expect(legacy.earnsPoints, isTrue);
    });
  });
}
