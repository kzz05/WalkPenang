import 'package:flutter/foundation.dart';

import '../utils/reward_constants.dart';
import 'transport_mode.dart';

/// A journey's destination and distance/time, as supplied by the Map & GPS
/// module for the Pre-Walk Summary screen.
///
/// Map & GPS integration contract — **now satisfied**: that module builds one
/// of these from a tapped place and its calculated route via
/// [WalkingRouteSummary.fromDestination], and hands it to
/// [WalkingController.setRouteSummary]. Nothing in this class or the screens
/// that read it assumes any particular map provider, which is why the factory
/// takes plain values rather than PlaceModel/RouteResult.
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

  /// How the tourist intends to travel (UC-W01 / UC-M04). Carried through to
  /// [CheckInResult.transportMode] on completion, because only a walk earns
  /// points and carbon (FR-W01) — the reward module cannot tell a walk from a
  /// drive after the fact unless the journey records it.
  final TransportMode transportMode;

  /// A loadable image URL for the destination's primary photo, or null when
  /// the place has none (or came from a flow that carries no photo). Display
  /// only — the Journey Preview's cover image (US-W02), which falls back to a
  /// placeholder when this is null. Deliberately a plain URL string rather
  /// than a photo reference or a Places model, so this class keeps its
  /// promise to assume no particular map/place provider.
  final String? destinationPhotoUrl;

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
    this.transportMode = TransportMode.walking,
    this.destinationPhotoUrl,
  });

  /// Builds a summary from a destination the Map & GPS module resolved — the
  /// integration contract described above, finally satisfied.
  ///
  /// Takes plain values rather than that module's `PlaceModel` and
  /// `RouteResult` on purpose: `RouteResult` imports google_maps_flutter, and
  /// this class promises to assume no particular map provider. The caller
  /// (route_summary_view) already holds both objects and does the unpacking,
  /// so the coupling stays on the map side of the seam where it belongs.
  factory WalkingRouteSummary.fromDestination({
    required String destinationId,
    required String destinationName,
    required String areaLabel,
    required double destinationLatitude,
    required double destinationLongitude,
    required double distanceKm,
    required Duration estimatedDuration,
    TransportMode transportMode = TransportMode.walking,
    String? destinationPhotoUrl,
  }) {
    return WalkingRouteSummary(
      destinationId: destinationId,
      destinationName: destinationName,
      areaLabel: areaLabel,
      distanceKm: distanceKm,
      estimatedDuration: estimatedDuration,
      destinationLatitude: destinationLatitude,
      destinationLongitude: destinationLongitude,
      transportMode: transportMode,
      destinationPhotoUrl: destinationPhotoUrl,
      // The real award for this distance, not a fixed number: the pre-walk
      // screen promises "earn N WalkPoints", and N has to be the figure the
      // reward module will actually grant on check-in.
      rewardPoints: RewardPoints.forCheckInKm(distanceKm: distanceKm),
      // Deliberately not "a heritage badge for <place>". Every badge in this
      // app is a cumulative milestone — Explorer at 5 check-ins, Trailblazer
      // at 10 km, Penang Wanderer at 50 km (see RewardConstants) — so there
      // is no per-place or per-category badge to promise, and naming one
      // would be a promise the reward module cannot keep.
      rewardBadgeLabel: 'progress towards your next badge',
    );
  }

  /// Whether this route has a usable distance/duration — checked before
  /// starting a journey so a bad calculation from upstream is caught.
  bool get isValid => distanceKm > 0 && estimatedDuration > Duration.zero;

  /// Debug-only fixture, kept for lib/debug/demo_journey_flow_view.dart and
  /// the widget tests — the Fort Cornwallis walk from the "02 · Pre-Walk
  /// Summary v2" Figma prototype. The real path no longer uses it: journeys
  /// now start from a tapped place via [WalkingRouteSummary.fromDestination].
  /// Coordinates are Fort Cornwallis's real public location in George Town,
  /// so US-W05/UC-W06 arrival verification behaves sensibly in the debug
  /// flow.
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
