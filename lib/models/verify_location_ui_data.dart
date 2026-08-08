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

  const VerifyLocationUiData({
    required this.phase,
    required this.destinationName,
    required this.radiusMeters,
    this.currentDistanceMeters,
    this.blockReason,
  }) : assert(
          phase != VerifyLocationPhase.blocked || blockReason != null,
          'blockReason is required when phase is VerifyLocationPhase.blocked',
        );
}
