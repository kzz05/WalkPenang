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
    this.minutesRemaining,
    this.carbonSavedKg,
    this.caloriesBurned,
    this.isCompleting = false,
  });

  /// Progress fraction for the elapsed-time card's bar, clamped to 0..1.
  /// 0 (never a fabricated partial fill) whenever [kmCovered] is unknown.
  double get progressFraction {
    final covered = kmCovered;
    if (covered == null || plannedDistanceKm <= 0) return 0.0;
    return (covered / plannedDistanceKm).clamp(0.0, 1.0);
  }
}
