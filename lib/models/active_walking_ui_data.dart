import 'package:flutter/foundation.dart';

/// Presentation-only data for `ActiveWalkingView` (Figma "03 · Active
/// Walking Journey (UC-W05) v2").
///
/// Every value arrives via the constructor — nothing in the view fetches
/// GPS data, computes distance, or reads Firestore. Fields that can't be
/// honestly known without a live tracking source are nullable; the view
/// renders an explicit "not available" state for a null field rather than
/// a fabricated or zeroed number.
@immutable
class ActiveWalkingUiData {
  final String destinationName;
  final Duration elapsedTime;

  /// The route's planned distance — known once a route exists. Never
  /// presented as distance actually walked.
  final double plannedDistanceKm;

  /// Distance covered so far, if a live-tracking source supplies one. Null
  /// when unavailable — rendered as "Not available", never as 0 or a
  /// fabricated figure.
  final double? kmCovered;

  /// Straight-line metres to the destination on the journey's first fix,
  /// and on the latest one. Both null until a tracking source supplies a
  /// fix, which is why the bar reads empty rather than partially filled
  /// before the journey has a position.
  final double? initialMetresToDestination;
  final double? metresToDestination;

  final int? minutesRemaining;
  final double? carbonSavedKg;
  final double? caloriesBurned;

  /// True while a Complete Journey attempt is in flight — disables both
  /// footer buttons and shows a loading indicator on Complete Journey.
  final bool isCompleting;

  const ActiveWalkingUiData({
    required this.destinationName,
    required this.elapsedTime,
    required this.plannedDistanceKm,
    this.kmCovered,
    this.initialMetresToDestination,
    this.metresToDestination,
    this.minutesRemaining,
    this.carbonSavedKg,
    this.caloriesBurned,
    this.isCompleting = false,
  });

  /// Progress fraction for the elapsed-time card's bar, clamped to 0..1.
  ///
  /// How much closer the tourist is to the destination — *not* how far they
  /// have walked. Those two came apart badly in the field: someone who had
  /// wandered 0.5 km around a 0.6 km route saw a nearly full bar while still
  /// standing 817 m from the destination, because this used to read
  /// [kmCovered] / [plannedDistanceKm]. Cumulative movement only ever grows,
  /// so the bar could never fall back when they walked the wrong way.
  ///
  /// Both distances are straight-line metres to the destination measured the
  /// same way, so the journey opens at 0 (current == initial) rather than at
  /// some fraction of a route distance measured along a different path.
  ///
  /// 0 (never a fabricated partial fill) while no fix has arrived. This bar
  /// does not complete the journey — arrival is still verified separately
  /// against [MapConstants.checkInThresholdMeters].
  double get progressFraction {
    final start = initialMetresToDestination;
    final current = metresToDestination;
    if (start == null || current == null) return 0.0;
    // Starting on top of the destination leaves nothing to divide by; there
    // is no distance to close, so the answer is simply whether they are
    // still there.
    if (start <= 0) return current <= 0 ? 1.0 : 0.0;
    return ((start - current) / start).clamp(0.0, 1.0);
  }
}
