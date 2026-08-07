import 'package:flutter/foundation.dart';

/// A walking route's destination and distance/time, as the Map & GPS
/// module will eventually supply it for the Pre-Walk Summary screen.
///
/// Map & GPS integration contract: once that module is ready, it should
/// construct a [WalkingRouteSummary] from its calculated route — a
/// resolved destination name + area label, the on-foot distance in
/// kilometres, and the estimated walking time — and hand it to
/// [WalkingController.setRouteSummary]. Nothing in this class or the
/// screens that read it assumes any particular map provider.
@immutable
class WalkingRouteSummary {
  final String destinationName;
  final String areaLabel;
  final double distanceKm;
  final Duration estimatedDuration;
  final int rewardPoints;
  final String rewardBadgeLabel;

  const WalkingRouteSummary({
    required this.destinationName,
    required this.areaLabel,
    required this.distanceKm,
    required this.estimatedDuration,
    required this.rewardPoints,
    required this.rewardBadgeLabel,
  });

  /// Whether this route has a usable distance/duration — checked before
  /// starting a journey so a bad calculation from upstream is caught.
  bool get isValid => distanceKm > 0 && estimatedDuration > Duration.zero;

  /// Sprint 1 fallback used only until Map & GPS provides a real route —
  /// the Fort Cornwallis walk from the "02 · Pre-Walk Summary v2" Figma
  /// prototype.
  static const demo = WalkingRouteSummary(
    destinationName: 'Fort Cornwallis',
    areaLabel: 'George Town Heritage Zone',
    distanceKm: 2.4,
    estimatedDuration: Duration(minutes: 32),
    rewardPoints: 15,
    rewardBadgeLabel: 'a heritage badge for Fort Cornwallis',
  );
}

/// Walking-only environmental/health benefits derived from a route's
/// distance. Kept separate from [WalkingRouteSummary] since Map & GPS only
/// supplies distance/duration — carbon savings and calories are Walking
/// module calculations on top of that.
@immutable
class WalkingBenefits {
  final double carbonSavingsKg;
  final int calories;

  const WalkingBenefits({
    required this.carbonSavingsKg,
    required this.calories,
  });

  /// Average passenger-car emission factor (kg CO2/km) offset by walking.
  static const _co2PerKm = 0.21;

  /// Average brisk-walking calorie burn rate (kcal/km) for an adult.
  static const _kcalPerKm = 58.3;

  /// Carbon saved for [distanceKm] of walking, in kg CO2 — 0.0 for a
  /// distance that's zero, negative, or non-finite (NaN/infinite).
  static double calculateCarbonSavingsKg(double distanceKm) {
    if (!distanceKm.isFinite || distanceKm <= 0) return 0.0;
    return distanceKm * _co2PerKm;
  }

  factory WalkingBenefits.fromDistanceKm(double distanceKm) {
    return WalkingBenefits(
      carbonSavingsKg: calculateCarbonSavingsKg(distanceKm),
      calories: (distanceKm * _kcalPerKm).round(),
    );
  }
}
