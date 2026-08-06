// ---------------------------------------------------------------------------
// reward_model_test.dart
// Module 5 — Reward & Achievement
// Use Case : UC500 Earn points from activities
// FR       : FR-R01 Points Award System
// Task     : T-R01.5 Unit tests for points calculation
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// The points formula is a pure function, so these tests need no Flutter
// binding and no Firebase project.

import 'package:test/test.dart';
import 'package:walkpenang/models/check_in_result.dart';
import 'package:walkpenang/models/reward_model.dart';
import 'package:walkpenang/utils/reward_constants.dart';

void main() {
  group('Points formula — 10 per check-in plus 1 per 0.1 km (UC500 C1)', () {
    test('a check-in with no distance still earns the flat award', () {
      expect(RewardPoints.forCheckIn(distanceMetres: 0), 10);
    });

    test('distance below 0.1 km earns no bonus', () {
      expect(RewardPoints.forCheckIn(distanceMetres: 99), 10);
    });

    test('exactly 0.1 km earns the first bonus point', () {
      expect(RewardPoints.forCheckIn(distanceMetres: 100), 11);
    });

    test('the bonus rounds down between boundaries', () {
      expect(RewardPoints.forCheckIn(distanceMetres: 199), 11);
      expect(RewardPoints.forCheckIn(distanceMetres: 200), 12);
    });

    test('1 km earns 10 bonus points', () {
      expect(RewardPoints.forCheckIn(distanceMetres: 1000), 20);
    });

    test('a corrupt negative distance cannot subtract from the balance', () {
      expect(RewardPoints.forCheckIn(distanceMetres: -500), 10);
    });
  });

  group('Points formula — floating point representative values', () {
    // These are the values that expose the naive (distanceKm * 10).floor()
    // implementation: 1.3 is held in binary as 1.2999999999999998, so the
    // naive form floors to 12 bonus points instead of 13.
    test('1.3 km awards 13 bonus points, not 12', () {
      expect(RewardPoints.forCheckInKm(distanceKm: 1.3), 10 + 13);
    });

    test('2.9 km awards 29 bonus points, not 28', () {
      expect(RewardPoints.forCheckInKm(distanceKm: 2.9), 10 + 29);
    });

    test('other decimal kilometre values land on the right boundary', () {
      expect(RewardPoints.forCheckInKm(distanceKm: 0.1), 11);
      expect(RewardPoints.forCheckInKm(distanceKm: 0.3), 13);
      expect(RewardPoints.forCheckInKm(distanceKm: 0.7), 17);
      expect(RewardPoints.forCheckInKm(distanceKm: 5.6), 66);
    });

    test('kilometres convert to whole metres without losing a metre', () {
      expect(RewardConstants.metresFromKm(1.3), 1300);
      expect(RewardConstants.metresFromKm(2.9), 2900);
      expect(RewardConstants.metresFromKm(0.0), 0);
    });

    test('the kilometre and metre entry points agree', () {
      expect(
        RewardPoints.forCheckInKm(distanceKm: 3.4),
        RewardPoints.forCheckIn(distanceMetres: 3400),
      );
    });
  });

  group('CheckInResult carries Module 4 values through unchanged', () {
    final result = CheckInResult(
      checkInId: 'chk_001',
      userId: 'tourist_001',
      destinationId: 'kek_lok_si',
      distanceKm: 1.3,
      carbonSavedKg: 0.26,
      caloriesBurned: 78.0,
      checkInTime: DateTime(2026, 8, 6, 9, 30),
    );

    test('exposes distance in whole metres for the formula', () {
      expect(result.distanceMetres, 1300);
    });

    test('a round trip through a map preserves every field', () {
      final restored = CheckInResult.fromMap(result.toMap());
      expect(restored.checkInId, result.checkInId);
      expect(restored.userId, result.userId);
      expect(restored.destinationId, result.destinationId);
      expect(restored.distanceKm, result.distanceKm);
      expect(restored.carbonSavedKg, result.carbonSavedKg);
      expect(restored.caloriesBurned, result.caloriesBurned);
      expect(restored.checkInTime, result.checkInTime);
    });
  });

  group('Cumulative totals', () {
    test('a tourist with no check-ins has zero totals', () {
      const stats = RewardModel.empty('tourist_001');
      expect(stats.totalPoints, 0);
      expect(stats.totalCheckIns, 0);
      expect(stats.totalDistanceMetres, 0);
      expect(stats.totalCarbonSavedKg, 0.0);
      expect(stats.totalCaloriesBurned, 0.0);
      expect(stats.hasCheckIns, isFalse);
    });

    test('a tourist document with no reward fields reads as the empty state',
        () {
      // Module 1 creates the tourist document before Module 5 has written
      // anything to it, so the missing fields must not crash the dashboard.
      final stats = RewardModel.fromMap('tourist_001', {
        'nickname': 'Ali',
        'weightKg': 62.0,
      });
      expect(stats.totalPoints, 0);
      expect(stats.totalCheckIns, 0);
      expect(stats.hasCheckIns, isFalse);
    });

    test('distance is stored in metres and displayed in kilometres', () {
      const stats = RewardModel(
        userId: 'tourist_001',
        totalDistanceMetres: 10500,
      );
      expect(stats.totalDistanceKm, 10.5);
    });

    test('a round trip through a map preserves the totals', () {
      const stats = RewardModel(
        userId: 'tourist_001',
        totalPoints: 143,
        totalCheckIns: 7,
        totalDistanceMetres: 12400,
        totalCarbonSavedKg: 2.48,
        totalCaloriesBurned: 744.0,
      );
      final restored = RewardModel.fromMap('tourist_001', stats.toMap());
      expect(restored.totalPoints, 143);
      expect(restored.totalCheckIns, 7);
      expect(restored.totalDistanceMetres, 12400);
      expect(restored.totalCarbonSavedKg, 2.48);
      expect(restored.totalCaloriesBurned, 744.0);
    });
  });
}
