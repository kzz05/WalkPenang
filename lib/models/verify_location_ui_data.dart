import 'package:flutter/foundation.dart';

/// Which of the three Figma "Verify Location" (UC-W06) card states to show.
/// 04a = checking, 04b = verified, 04c = blocked (too far, or a GPS/
/// permission problem — see [VerifyBlockReason]).
enum VerifyLocationPhase { checking, verified, blocked }

/// Why verification is blocked, when [VerifyLocationPhase.blocked].
enum VerifyBlockReason {
  tooFar,
  gpsDisabled,
  permissionDenied,
  permissionDeniedForever,
  weakSignal,
}

/// Presentation-only data for `VerifyLocationView`.
///
/// Every value arrives via the constructor — the view performs no GPS
/// reads, permission checks, or distance calculations itself. The 100 m
/// radius is passed in as [radiusMeters] rather than hard-coded in the
/// widget, so the widget never scatters that business constant itself.
@immutable
class VerifyLocationUiData {
  final VerifyLocationPhase phase;
  final String destinationName;
  final double radiusMeters;

  /// Known once a GPS reading exists; null while still acquiring one, or
  /// when [blockReason] means no distance was ever measured (e.g. GPS
  /// disabled before a reading was possible).
  final double? currentDistanceMeters;

  /// Required, and only meaningful, when [phase] is
  /// [VerifyLocationPhase.blocked].
  final VerifyBlockReason? blockReason;

  /// The destination the [radiusMeters] zone is drawn around, so the screen
  /// can show the real place on a map instead of an abstract ring. Optional:
  /// a caller with no coordinates to hand (the widget tests, and any screen
  /// state reached before a destination exists) still gets the illustrated
  /// fallback.
  final double? destinationLatitude;
  final double? destinationLongitude;

  /// Where the last GPS reading put the tourist — the same fix
  /// [currentDistanceMeters] was measured from, never a second one. Null
  /// while no fix has landed, or when the reading failed.
  final double? userLatitude;
  final double? userLongitude;

  const VerifyLocationUiData({
    required this.phase,
    required this.destinationName,
    required this.radiusMeters,
    this.currentDistanceMeters,
    this.blockReason,
    this.destinationLatitude,
    this.destinationLongitude,
    this.userLatitude,
    this.userLongitude,
  }) : assert(
          phase != VerifyLocationPhase.blocked || blockReason != null,
          'blockReason is required when phase is VerifyLocationPhase.blocked',
        );

  /// Whether there is a destination to centre a map on. The user marker is
  /// drawn on top only when [hasUserPosition] as well — a map of the
  /// destination and its radius is still worth showing while the fix is
  /// being acquired, or after one failed.
  bool get hasDestinationPosition =>
      destinationLatitude != null && destinationLongitude != null;

  bool get hasUserPosition => userLatitude != null && userLongitude != null;
}
