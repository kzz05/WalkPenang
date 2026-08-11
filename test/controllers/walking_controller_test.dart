// Unit tests for US-W03 — Carbon Savings Calculation — and US-W04 —
// Calorie Expenditure Calculation, WalkingController integration:
// mode-gating and exposing the calculated values for reuse.

import 'package:flutter_test/flutter_test.dart';

import 'package:walkpenang/controllers/walking_controller.dart';
import 'package:walkpenang/models/transport_mode.dart';
import 'package:walkpenang/models/user_profile.dart';
import 'package:walkpenang/models/walking_route_summary.dart';

UserProfile _profileWithWeight(double weightKg) => UserProfile(
      nickname: 'Test User',
      weightKg: weightKg,
      heightCm: 170,
      units: 'metric',
    );

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

  group('WalkingController.caloriesBurned', () {
    test('calculates calories when Walking is selected with a valid profile',
        () {
      final controller = WalkingController()
        ..selectMode(TransportMode.walking)
        ..setRouteSummary(WalkingRouteSummary.demo)
        ..setUserProfile(_profileWithWeight(65));
      expect(controller.caloriesBurned, closeTo(140.4, 1e-9));
    });

    test('is null when Driving is selected, even with a valid profile', () {
      final controller = WalkingController()
        ..selectMode(TransportMode.driving)
        ..setRouteSummary(WalkingRouteSummary.demo)
        ..setUserProfile(_profileWithWeight(65));
      expect(controller.caloriesBurned, isNull);
    });

    test(
        'is null when Public Transport is selected, even with a valid '
        'profile', () {
      final controller = WalkingController()
        ..selectMode(TransportMode.publicTransport)
        ..setRouteSummary(WalkingRouteSummary.demo)
        ..setUserProfile(_profileWithWeight(65));
      expect(controller.caloriesBurned, isNull);
    });

    test('is null when no transport mode is selected', () {
      final controller = WalkingController()
        ..setRouteSummary(WalkingRouteSummary.demo)
        ..setUserProfile(_profileWithWeight(65));
      expect(controller.caloriesBurned, isNull);
    });

    test('is null when the profile has never been set', () {
      final controller = WalkingController()
        ..selectMode(TransportMode.walking)
        ..setRouteSummary(WalkingRouteSummary.demo);
      expect(controller.caloriesBurned, isNull);
    });

    test('is null when the profile weight is zero/negative/NaN/infinite', () {
      for (final weight in [0.0, -65.0, double.nan, double.infinity]) {
        final controller = WalkingController()
          ..selectMode(TransportMode.walking)
          ..setRouteSummary(WalkingRouteSummary.demo)
          ..setUserProfile(_profileWithWeight(weight));
        expect(controller.caloriesBurned, isNull, reason: 'weight=$weight');
      }
    });

    test('is null when there is no route summary', () {
      final controller = WalkingController()
        ..selectMode(TransportMode.walking)
        ..setUserProfile(_profileWithWeight(65));
      expect(controller.caloriesBurned, isNull);
    });

    test('recomputes after setUserProfile is called again (profile refresh)',
        () {
      final controller = WalkingController()
        ..selectMode(TransportMode.walking)
        ..setRouteSummary(WalkingRouteSummary.demo)
        ..setUserProfile(_profileWithWeight(0));
      expect(controller.caloriesBurned, isNull);

      controller.setUserProfile(_profileWithWeight(65));
      expect(controller.caloriesBurned, closeTo(140.4, 1e-9));
    });
  });
}
