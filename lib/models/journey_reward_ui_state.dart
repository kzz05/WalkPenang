import 'package:flutter/foundation.dart';

/// Stable, Walking-owned presentation contract for how a completed
/// journey's reward result renders on the Journey Completed screen.
///
/// This is deliberately *not* the Reward & Achievement Module's domain
/// model (`RewardService`/`RewardOutcome`/`CheckInResult`/`BadgeModel`,
/// owned by Tang Khuan Zhi on `Reward-and-Achievement-Module`) — it exists
/// to isolate the Journey Completed UI from that module's domain types and
/// Firestore implementation, so this screen can be built, previewed and
/// tested before the branches merge, and so it doesn't need to change shape
/// once they do.
///
/// Future integration (out of scope here): once the branches merge, a
/// controller/adapter converts a real `RewardOutcome` into a
/// [JourneyRewardUiState.success] by mapping:
///   RewardOutcome.pointsAwarded        -> pointsAwarded
///   RewardOutcome.newlyEarnedBadgeIds  -> resolved via BadgeCatalogue.byId(...)
///                                          .name -> newlyEarnedBadgeNames
///   RewardOutcome.alreadyAwarded       -> alreadyAwarded
/// `JourneyCompletedView` never calls `RewardService`, touches Firestore, or
/// resolves badge IDs itself — it only ever renders whatever
/// [JourneyRewardUiState] it's given.
enum JourneyRewardUiStatus {
  /// No reward result exists yet and none is expected imminently — the
  /// production default. Nothing is shown as earned.
  unavailable,

  /// Reward processing has been triggered but hasn't returned a result yet.
  pending,

  /// A resolved, successful reward outcome — safe to render
  /// [JourneyRewardUiState.pointsAwarded]/[JourneyRewardUiState.newlyEarnedBadgeNames].
  /// A success can carry zero newly-earned badges; it does not imply one.
  success,

  /// Reward processing was attempted and failed.
  error,
}

/// The result to render on the Journey Completed screen's reward card.
///
/// Construct via the named constructors only, so a caller can never build a
/// [success] state with a missing points value, and can never fabricate one
/// by accident — the default constructor is private.
@immutable
class JourneyRewardUiState {
  final JourneyRewardUiStatus status;
  final int? pointsAwarded;
  final List<String> newlyEarnedBadgeNames;

  /// True when this journey's reward had already been recorded previously —
  /// the screen must not present it as newly earned when this is true, even
  /// though [pointsAwarded] still reports the original award.
  final bool alreadyAwarded;

  final String? errorMessage;

  const JourneyRewardUiState._({
    required this.status,
    this.pointsAwarded,
    this.newlyEarnedBadgeNames = const [],
    this.alreadyAwarded = false,
    this.errorMessage,
  });

  /// The safe production default until a real reward result is supplied.
  const JourneyRewardUiState.unavailable()
      : this._(status: JourneyRewardUiStatus.unavailable);

  /// Reward processing has been triggered; no result back yet.
  const JourneyRewardUiState.pending()
      : this._(status: JourneyRewardUiStatus.pending);

  /// A resolved reward outcome. [pointsAwarded] and [newlyEarnedBadgeNames]
  /// must come from a real, already-computed result via the future
  /// integration layer — this constructor performs no calculation and
  /// resolves no badge data itself.
  const JourneyRewardUiState.success({
    required int pointsAwarded,
    List<String> newlyEarnedBadgeNames = const [],
    bool alreadyAwarded = false,
  }) : this._(
          status: JourneyRewardUiStatus.success,
          pointsAwarded: pointsAwarded,
          newlyEarnedBadgeNames: newlyEarnedBadgeNames,
          alreadyAwarded: alreadyAwarded,
        );

  /// Reward processing failed. [message] is optional user-facing detail.
  const JourneyRewardUiState.error([String? message])
      : this._(status: JourneyRewardUiStatus.error, errorMessage: message);
}
