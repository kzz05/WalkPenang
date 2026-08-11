import 'package:flutter/foundation.dart';

import 'journey_reward_ui_state.dart';

/// Presentation-only data for `JourneyCompletedView` (Figma "05 · Journey
/// Completed (UC-W05) v2").
///
/// Every value arrives via the constructor. [completedDistanceKm] is never
/// backed by a route's planned distance — it is null whenever the actual
/// completed distance isn't available, and the view renders that as an
/// honest "not available" state rather than substituting the planned value.
@immutable
class JourneyCompletedUiData {
  final String destinationName;
  final String destinationAreaLabel;

  /// Actual walked distance, only once known. Never the planned distance.
  final double? completedDistanceKm;

  final Duration? journeyDuration;
  final double? carbonSavedKg;
  final double? caloriesBurned;

  /// Defaults to [JourneyRewardUiState.unavailable] — the safe production
  /// default until a real Reward Module result is supplied.
  final JourneyRewardUiState reward;

  const JourneyCompletedUiData({
    required this.destinationName,
    required this.destinationAreaLabel,
    this.completedDistanceKm,
    this.journeyDuration,
    this.carbonSavedKg,
    this.caloriesBurned,
    this.reward = const JourneyRewardUiState.unavailable(),
  });
}
