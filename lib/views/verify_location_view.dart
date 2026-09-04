import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/verify_location_ui_data.dart';
import '../theme/app_theme.dart';
import '../widgets/map/verification_radius_map.dart';
import 'widgets/wp_components.dart';

/// Screens 04a/04b/04c · Proximity Verification (UC-W06) v2 — one
/// state-driven screen for "Checking", "Verified", and "blocked" (too far,
/// or a GPS/permission problem), matching how the Figma frames share one
/// "Verify Location" header/radius-ring layout and differ only in the card
/// and footer beneath it.
///
/// Presentation only. All data arrives via [data]; every user action is
/// reported through a callback. This widget never reads GPS, calculates
/// distance, or checks permissions itself.
class VerifyLocationView extends StatelessWidget {
  final VerifyLocationUiData data;
  final VoidCallback? onBack;
  final VoidCallback? onCompleteJourney;
  final VoidCallback? onRetry;
  final VoidCallback? onContinueWalking;

  const VerifyLocationView({
    super.key,
    required this.data,
    this.onBack,
    this.onCompleteJourney,
    this.onRetry,
    this.onContinueWalking,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        // Tightened from 24/32/24 so the too-far state — the tallest of
        // the three — fits a normal phone without scrolling: the tourist
        // has to be able to read the distance rows and reach Try Again /
        // Continue Walking without a swipe.
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(data: data, onBack: onBack),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  child: _Content(data: data),
                ),
              ),
              const SizedBox(height: 14),
              _Footer(
                data: data,
                onCompleteJourney: onCompleteJourney,
                onRetry: onRetry,
                onContinueWalking: onContinueWalking,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _stateLabel(VerifyLocationUiData data) => switch (data.phase) {
      VerifyLocationPhase.checking => 'STATE · CHECKING',
      VerifyLocationPhase.verified => 'STATE · VERIFIED',
      VerifyLocationPhase.blocked => switch (data.blockReason!) {
          VerifyBlockReason.tooFar => 'STATE · TOO FAR FROM DESTINATION',
          VerifyBlockReason.gpsDisabled => 'STATE · GPS DISABLED',
          VerifyBlockReason.permissionDenied => 'STATE · PERMISSION DENIED',
          VerifyBlockReason.permissionDeniedForever =>
            'STATE · PERMISSION PERMANENTLY DENIED',
          VerifyBlockReason.weakSignal => 'STATE · WEAK GPS SIGNAL',
        },
    };

class _Header extends StatelessWidget {
  final VerifyLocationUiData data;
  final VoidCallback? onBack;

  const _Header({required this.data, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            WpBackButton(onBack: onBack),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Verify Location',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.heading
                    .copyWith(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _stateLabel(data),
          style: AppType.mono.copyWith(
              fontSize: 10, letterSpacing: 1.2, color: AppColors.muted),
        ),
      ],
    );
  }
}

class _Content extends StatelessWidget {
  final VerifyLocationUiData data;

  const _Content({required this.data});

  Color get _ringColor => switch (data.phase) {
        VerifyLocationPhase.checking => AppColors.primary,
        VerifyLocationPhase.verified => AppColors.success,
        VerifyLocationPhase.blocked => AppColors.danger,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RadiusZoneCard(ringColor: _ringColor, data: data),
        const SizedBox(height: 10),
        switch (data.phase) {
          VerifyLocationPhase.checking => _CheckingCard(data: data),
          VerifyLocationPhase.verified => _VerifiedCard(data: data),
          VerifyLocationPhase.blocked => _BlockedCard(data: data),
        },
        if (data.phase == VerifyLocationPhase.blocked &&
            data.blockReason == VerifyBlockReason.tooFar) ...[
          const SizedBox(height: 10),
          _DistanceCheckCard(data: data),
        ],
      ],
    );
  }
}

/// The "100 M RADIUS ZONE" card, shared by all three states with only the
/// accent colour changing.
///
/// Shows the real thing wherever the flow has coordinates: the destination,
/// the check-in radius drawn around it, and the tourist's own fix, on the
/// app's existing [GoogleMap]. The abstract dashed ring below is the fallback
/// for a caller with no coordinates to hand — it is still an honest
/// illustration of the radius, and a map of nowhere would not be.
class _RadiusZoneCard extends StatelessWidget {
  final Color ringColor;
  final VerifyLocationUiData data;

  const _RadiusZoneCard({required this.ringColor, required this.data});

  @override
  Widget build(BuildContext context) {
    // Enough to keep the destination pin, the tourist's pin and the whole
    // radius circle framed together (VerificationRadiusMap fits all three
    // to these bounds), while giving the cards below it room on screen.
    const height = 148.0;

    if (data.hasDestinationPosition) {
      return Stack(
        alignment: Alignment.bottomCenter,
        children: [
          VerificationRadiusMap(
            destination: LatLng(
              data.destinationLatitude!,
              data.destinationLongitude!,
            ),
            userPosition: data.hasUserPosition
                ? LatLng(data.userLatitude!, data.userLongitude!)
                : null,
            radiusMeters: data.radiusMeters,
            accentColor: ringColor,
            height: height,
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _RadiusZoneChip(radiusMeters: data.radiusMeters),
          ),
        ],
      );
    }

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.backgroundDeep,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _DashedRadiusRing(color: ringColor, size: 92),
          const SizedBox(height: 10),
          _RadiusZoneChip(radiusMeters: data.radiusMeters),
        ],
      ),
    );
  }
}

/// The "100 M RADIUS ZONE" caption, on both the map and the illustrated
/// fallback so the card reads the same either way.
class _RadiusZoneChip extends StatelessWidget {
  final double radiusMeters;

  const _RadiusZoneChip({required this.radiusMeters});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 2),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.mdAll,
        boxShadow: [
          BoxShadow(
              color: AppColors.cardShadow, blurRadius: 6, offset: Offset(0, 1)),
        ],
      ),
      child: Text(
        '${radiusMeters.round()} M RADIUS ZONE',
        style: AppType.mono.copyWith(fontSize: 10, letterSpacing: 0.8),
      ),
    );
  }
}

/// A dashed circle with a solid centre dot — no image asset, drawn with
/// `CustomPainter` so no new dependency is needed.
class _DashedRadiusRing extends StatelessWidget {
  final Color color;
  final double size;

  const _DashedRadiusRing({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DashedRingPainter(color: color),
        child: Center(
          child: Container(
            width: size * 0.31,
            height: size * 0.31,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Center(
              child: Container(
                width: size * 0.09,
                height: size * 0.09,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  final Color color;

  _DashedRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final center = Offset(radius, radius);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    const dashCount = 24;
    const dashSweep = (2 * math.pi) / dashCount;
    const dashOn = dashSweep * 0.6;

    for (var i = 0; i < dashCount; i++) {
      final start = i * dashSweep;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 1),
        start,
        dashOn,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _CheckingCard extends StatelessWidget {
  final VerifyLocationUiData data;

  const _CheckingCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return _StateCard(
      background: AppColors.card,
      children: [
        const SizedBox(
          width: 44,
          height: 44,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Checking your location…',
          textAlign: TextAlign.center,
          style: AppType.heading.copyWith(fontSize: 18),
        ),
        const SizedBox(height: 12),
        Text(
          'GPS SIGNAL ACQUIRING',
          style: AppType.mono.copyWith(
              fontSize: 11, letterSpacing: 1, color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: const BoxDecoration(
              color: AppColors.primary, borderRadius: AppRadius.mdAll),
          child: Text(
            '${data.destinationName.toUpperCase()} · ${data.radiusMeters.round()} M ZONE',
            style: AppType.mono.copyWith(
                fontSize: 10, letterSpacing: 0.8, color: AppColors.onPrimary),
          ),
        ),
      ],
    );
  }
}

class _VerifiedCard extends StatelessWidget {
  final VerifyLocationUiData data;

  const _VerifiedCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final distance = data.currentDistanceMeters;

    return _StateCard(
      background: AppColors.successTint,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
              color: AppColors.success, shape: BoxShape.circle),
          child: const Icon(Icons.check, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 16),
        Text("You're here!",
            textAlign: TextAlign.center,
            style: AppType.heading.copyWith(fontSize: 18)),
        const SizedBox(height: 8),
        Text(
          distance == null
              ? 'WITHIN DESTINATION RANGE'
              : 'WITHIN ${distance.round()} M OF DESTINATION',
          style: AppType.mono.copyWith(
              fontSize: 11, letterSpacing: 0.8, color: AppColors.success),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: AppRadius.mdAll,
            border: Border.all(
                color: AppColors.success.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check, size: 14, color: AppColors.success),
              const SizedBox(width: 6),
              Text(
                'LOCATION VERIFIED',
                style: AppType.mono.copyWith(
                    fontSize: 10,
                    letterSpacing: 0.8,
                    color: AppColors.success),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BlockedCard extends StatelessWidget {
  final VerifyLocationUiData data;

  const _BlockedCard({required this.data});

  ({String headline, String message}) get _copy => switch (data.blockReason!) {
        VerifyBlockReason.tooFar => (
            headline: 'Too far away',
            message: 'Move to within ${data.radiusMeters.round()} metres of '
                '${data.destinationName} to verify your arrival.',
          ),
        VerifyBlockReason.gpsDisabled => (
            headline: 'GPS is off',
            message: 'Please enable GPS to verify your destination.',
          ),
        VerifyBlockReason.permissionDenied => (
            headline: 'Permission needed',
            message:
                'Location permission is required to verify your destination.',
          ),
        VerifyBlockReason.permissionDeniedForever => (
            headline: 'Permission needed',
            message:
                'Location permission must be enabled from your device settings '
                'to verify your destination.',
          ),
        VerifyBlockReason.weakSignal => (
            headline: 'Weak signal',
            message: 'GPS signal is too weak. Please wait and try again.',
          ),
      };

  @override
  Widget build(BuildContext context) {
    final copy = _copy;
    final distance = data.currentDistanceMeters;

    return _StateCard(
      background: AppColors.dangerTint,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
              color: AppColors.danger, shape: BoxShape.circle),
          child: const Icon(Icons.priority_high, color: Colors.white, size: 22),
        ),
        const SizedBox(height: 10),
        Text(copy.headline,
            textAlign: TextAlign.center,
            style: AppType.heading.copyWith(fontSize: 18)),
        if (data.blockReason == VerifyBlockReason.tooFar &&
            distance != null) ...[
          const SizedBox(height: 6),
          Text(
            'YOU ARE ${distance.round()} M FROM DESTINATION',
            style: AppType.mono.copyWith(
                fontSize: 11, letterSpacing: 0.8, color: AppColors.danger),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          copy.message,
          textAlign: TextAlign.center,
          style: AppType.body
              .copyWith(fontSize: 13, height: 1.3, color: AppColors.muted),
        ),
      ],
    );
  }
}

class _StateCard extends StatelessWidget {
  final Color background;
  final List<Widget> children;

  const _StateCard({required this.background, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        boxShadow: const [
          BoxShadow(
              color: AppColors.cardShadow, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// "CURRENT DISTANCE" / "REQUIRED DISTANCE" comparison rows — only shown
/// for the too-far reason, where there are real numbers to compare.
class _DistanceCheckCard extends StatelessWidget {
  final VerifyLocationUiData data;

  const _DistanceCheckCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final distance = data.currentDistanceMeters;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: AppColors.cardShadow, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          _DistanceRow(
            label: 'CURRENT DISTANCE',
            value: distance == null ? '—' : '${distance.round()} m',
            valueColor: AppColors.danger,
          ),
          const Divider(height: 1, color: AppColors.outline),
          _DistanceRow(
            label: 'REQUIRED DISTANCE',
            value: '≤ ${data.radiusMeters.round()} m',
          ),
        ],
      ),
    );
  }
}

class _DistanceRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DistanceRow(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.mono.copyWith(
                  fontSize: 11, letterSpacing: 0.6, color: AppColors.muted),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: AppType.body.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final VerifyLocationUiData data;
  final VoidCallback? onCompleteJourney;
  final VoidCallback? onRetry;
  final VoidCallback? onContinueWalking;

  const _Footer({
    required this.data,
    required this.onCompleteJourney,
    required this.onRetry,
    required this.onContinueWalking,
  });

  @override
  Widget build(BuildContext context) {
    switch (data.phase) {
      case VerifyLocationPhase.checking:
        return Center(
          child: Text(
            'COMPLETION THRESHOLD · ${data.radiusMeters.round()} M',
            style: AppType.mono.copyWith(
                fontSize: 10, letterSpacing: 0.8, color: AppColors.muted),
          ),
        );
      case VerifyLocationPhase.verified:
        return _PillButton(
          label: 'Complete Journey',
          background: AppColors.primary,
          onPressed: onCompleteJourney,
          showArrow: true,
        );
      case VerifyLocationPhase.blocked:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PillButton(
                label: 'Try Again',
                background: AppColors.primary,
                onPressed: onRetry),
            const SizedBox(height: 10),
            _PillButton(
              label: 'Continue Walking',
              background: AppColors.backgroundDeep,
              onPressed: onContinueWalking,
            ),
          ],
        );
    }
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final Color background;
  final VoidCallback? onPressed;
  final bool showArrow;

  const _PillButton({
    required this.label,
    required this.background,
    required this.onPressed,
    this.showArrow = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Material(
      color: enabled ? background : AppColors.placeholder,
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onPrimary
                        .withValues(alpha: enabled ? 1 : 0.4),
                  ),
                ),
              ),
              if (showArrow && enabled) ...[
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward,
                    size: 18, color: AppColors.onPrimary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
