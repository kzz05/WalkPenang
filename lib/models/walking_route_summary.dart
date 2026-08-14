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

  /// Stable destination identifier, handed straight through to
  /// [CheckInResult.destinationId] on journey completion (US-W05) — never
  /// derived from [destinationName], since a display label can change
  /// without the place it refers to changing. Map & GPS integration
  /// contract: once that module supplies a real destination, this should be
  /// its [PlaceModel.placeId]/[Place.id], not a Walking-invented ID.
  final String destinationId;

  /// The destination's coordinates, needed to verify arrival (UC-W06)
  /// against [MapConstants.checkInThresholdMeters] via
  /// LocationService.distanceMeters(). Map & GPS integration contract: once
  /// that module supplies a real destination, these come from its selected
  /// place, not a Walking-invented value.
  final double destinationLatitude;
  final double destinationLongitude;

  const WalkingRouteSummary({
    required this.destinationName,
    required this.areaLabel,
    required this.distanceKm,
    required this.estimatedDuration,
    required this.rewardPoints,
    required this.rewardBadgeLabel,
    required this.destinationId,
    required this.destinationLatitude,
    required this.destinationLongitude,
  });

  /// Whether this route has a usable distance/duration — checked before
  /// starting a journey so a bad calculation from upstream is caught.
  bool get isValid => distanceKm > 0 && estimatedDuration > Duration.zero;

  /// Sprint 1 fallback used only until Map & GPS provides a real route —
  /// the Fort Cornwallis walk from the "02 · Pre-Walk Summary v2" Figma
  /// prototype. Coordinates are Fort Cornwallis's real public location in
  /// George Town, so US-W05/UC-W06 arrival verification behaves sensibly
  /// even while this fallback is still in use.
  static const demo = WalkingRouteSummary(
    destinationName: 'Fort Cornwallis',
    areaLabel: 'George Town Heritage Zone',
    distanceKm: 2.4,
    estimatedDuration: Duration(minutes: 32),
    rewardPoints: 15,
    rewardBadgeLabel: 'a heritage badge for Fort Cornwallis',
    destinationId: 'demo-fort-cornwallis',
    destinationLatitude: 5.4229,
    destinationLongitude: 100.3402,
  );
}

/// Walking-only environmental/health benefits derived from a route's
/// distance (and, for calories, the walker's body weight). Kept separate
/// from [WalkingRouteSummary] since Map & GPS only supplies
/// distance/duration — carbon savings and calories are Walking module
/// calculations on top of that.
@immutable
class WalkingBenefits {
  const WalkingBenefits._();

  /// Average passenger-car emission factor (kg CO2/km) offset by walking.
  static const _co2PerKm = 0.21;

  /// Calorie-burn factor (kcal per km per kg of body weight) — US-W04's
  /// calculation constant: caloriesBurned = distanceKm * bodyWeightKg * 0.9.
  static const _calorieFactorPerKgKm = 0.9;

  /// Carbon saved for [distanceKm] of walking, in kg CO2 — 0.0 for a
  /// distance that's zero, negative, or non-finite (NaN/infinite).
  static double calculateCarbonSavingsKg(double distanceKm) {
    if (!distanceKm.isFinite || distanceKm <= 0) return 0.0;
    return distanceKm * _co2PerKm;
  }

  /// Calories burned walking [distanceKm] at [bodyWeightKg] — 0.0 if either
  /// input is zero, negative, or non-finite (NaN/infinite). Callers that
  /// need to distinguish "genuinely zero" from "not available" (e.g. a
  /// missing profile weight) should check their inputs before calling this
  /// — see [WalkingController.caloriesBurned].
  static double calculateCaloriesBurned(
      double distanceKm, double bodyWeightKg) {
    if (!distanceKm.isFinite || distanceKm <= 0) return 0.0;
    if (!bodyWeightKg.isFinite || bodyWeightKg <= 0) return 0.0;
    return distanceKm * bodyWeightKg * _calorieFactorPerKgKm;
  }
}
