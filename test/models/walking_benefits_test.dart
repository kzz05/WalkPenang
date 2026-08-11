// Unit tests for US-W03 — Carbon Savings Calculation — and US-W04 —
// Calorie Expenditure Calculation.
//
// Covers WalkingBenefits.calculateCarbonSavingsKg: carbonSavedKg =
// distanceKm * 0.21, with 0.0 returned for zero/negative/NaN/infinite
// distance.
//
// Covers WalkingBenefits.calculateCaloriesBurned: caloriesBurned =
// distanceKm * bodyWeightKg * 0.9, with 0.0 returned for zero/negative/
// NaN/infinite distance or body weight.

import 'package:flutter_test/flutter_test.dart';

import 'package:walkpenang/models/walking_route_summary.dart';

void main() {
  group('WalkingBenefits.calculateCarbonSavingsKg', () {
    test('0 km produces 0.00 kg CO2', () {
      final result = WalkingBenefits.calculateCarbonSavingsKg(0);
      expect(result, 0.0);
      expect(result.toStringAsFixed(2), '0.00');
    });

    test('1 km produces 0.21 kg CO2', () {
      final result = WalkingBenefits.calculateCarbonSavingsKg(1);
      expect(result, closeTo(0.21, 1e-9));
      expect(result.toStringAsFixed(2), '0.21');
    });

    test('2.4 km calculates 0.504 kg CO2 and displays 0.50', () {
      final result = WalkingBenefits.calculateCarbonSavingsKg(2.4);
      expect(result, closeTo(0.504, 1e-9));
      expect(result.toStringAsFixed(2), '0.50');
    });

    test('5 km produces 1.05 kg CO2', () {
      final result = WalkingBenefits.calculateCarbonSavingsKg(5);
      expect(result, closeTo(1.05, 1e-9));
      expect(result.toStringAsFixed(2), '1.05');
    });

    test('10 km produces 2.10 kg CO2', () {
      final result = WalkingBenefits.calculateCarbonSavingsKg(10);
      expect(result, closeTo(2.10, 1e-9));
      expect(result.toStringAsFixed(2), '2.10');
    });

    test('negative distance produces 0.00 kg CO2', () {
      final result = WalkingBenefits.calculateCarbonSavingsKg(-5);
      expect(result, 0.0);
      expect(result.toStringAsFixed(2), '0.00');
    });

    test('NaN produces 0.00 kg CO2', () {
      final result = WalkingBenefits.calculateCarbonSavingsKg(double.nan);
      expect(result, 0.0);
      expect(result.toStringAsFixed(2), '0.00');
    });

    test('infinite distance produces 0.00 kg CO2', () {
      final result = WalkingBenefits.calculateCarbonSavingsKg(double.infinity);
      expect(result, 0.0);
      expect(result.toStringAsFixed(2), '0.00');
    });
  });

  group('WalkingBenefits.calculateCaloriesBurned', () {
    test('2.4 km at 65 kg calculates 140.4 kcal, displays 140', () {
      final result = WalkingBenefits.calculateCaloriesBurned(2.4, 65);
      expect(result, closeTo(140.4, 1e-9));
      expect(result.round(), 140);
    });

    test('1 km at 70 kg calculates 63 kcal', () {
      final result = WalkingBenefits.calculateCaloriesBurned(1, 70);
      expect(result, closeTo(63.0, 1e-9));
      expect(result.round(), 63);
    });

    test('decimal distance and decimal body weight', () {
      final result = WalkingBenefits.calculateCaloriesBurned(3.7, 58.5);
      expect(result, closeTo(3.7 * 58.5 * 0.9, 1e-9));
    });

    test('zero distance produces 0.0 kcal', () {
      expect(WalkingBenefits.calculateCaloriesBurned(0, 65), 0.0);
    });

    test('negative distance produces 0.0 kcal', () {
      expect(WalkingBenefits.calculateCaloriesBurned(-2.4, 65), 0.0);
    });

    test('NaN distance produces 0.0 kcal', () {
      expect(WalkingBenefits.calculateCaloriesBurned(double.nan, 65), 0.0);
    });

    test('infinite distance produces 0.0 kcal', () {
      expect(
        WalkingBenefits.calculateCaloriesBurned(double.infinity, 65),
        0.0,
      );
    });

    test('zero body weight produces 0.0 kcal', () {
      expect(WalkingBenefits.calculateCaloriesBurned(2.4, 0), 0.0);
    });

    test('negative body weight produces 0.0 kcal', () {
      expect(WalkingBenefits.calculateCaloriesBurned(2.4, -65), 0.0);
    });

    test('NaN body weight produces 0.0 kcal', () {
      expect(
        WalkingBenefits.calculateCaloriesBurned(2.4, double.nan),
        0.0,
      );
    });

    test('infinite body weight produces 0.0 kcal', () {
      expect(
        WalkingBenefits.calculateCaloriesBurned(2.4, double.infinity),
        0.0,
      );
    });
  });
}
