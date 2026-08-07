// Unit tests for US-W03 — Carbon Savings Calculation, WalkingController
// integration: mode-gating and exposing the calculated value for reuse.

import 'package:flutter_test/flutter_test.dart';

import 'package:walkpenang/controllers/walking_controller.dart';
import 'package:walkpenang/models/transport_mode.dart';
import 'package:walkpenang/models/walking_route_summary.dart';

void main() {
  group('WalkingController.calculateCarbonSavings', () {
    test('returns 0.0 when no transport mode is selected', () {
      final controller = WalkingController();
      expect(controller.calculateCarbonSavings(2.4), 0.0);
    });

    test('returns 0.0 when a non-walking mode is selected', () {
      final controller = WalkingController()..selectMode(TransportMode.driving);
      expect(controller.calculateCarbonSavings(2.4), 0.0);
    });

    test('calculates carbon savings when Walking is selected', () {
      final controller = WalkingController()..selectMode(TransportMode.walking);
      expect(controller.calculateCarbonSavings(2.4), closeTo(0.504, 1e-9));
    });

    test(
        'returns 0.0 for a negative/NaN/infinite distance even when '
        'walking is selected', () {
      final controller = WalkingController()..selectMode(TransportMode.walking);
      expect(controller.calculateCarbonSavings(-1), 0.0);
      expect(controller.calculateCarbonSavings(double.nan), 0.0);
      expect(controller.calculateCarbonSavings(double.infinity), 0.0);
    });
  });

  group('WalkingController.carbonSavedKg', () {
    test('is 0.0 when route data is unavailable', () {
      final controller = WalkingController()..selectMode(TransportMode.walking);
      expect(controller.carbonSavedKg, 0.0);
    });

    test('reflects the current route summary once Walking is selected', () {
      final controller = WalkingController()
        ..selectMode(TransportMode.walking)
        ..setRouteSummary(WalkingRouteSummary.demo);
      expect(controller.carbonSavedKg, closeTo(0.504, 1e-9));
    });
  });
}
