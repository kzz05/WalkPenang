// Unit tests for US-W03 — Carbon Savings Calculation.
//
// Covers WalkingBenefits.calculateCarbonSavingsKg: carbonSavedKg =
// distanceKm * 0.21, with 0.0 returned for zero/negative/NaN/infinite
// distance.

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
}
