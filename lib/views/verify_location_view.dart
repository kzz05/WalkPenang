import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/verify_location_ui_data.dart';
import '../theme/app_theme.dart';

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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(data: data, onBack: onBack),
              const SizedBox(height: 32),
              Expanded(
                child: SingleChildScrollView(
                  child: _Content(data: data),
                ),
              ),
              const SizedBox(height: 24),
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

class _Palette {
  const _Palette._();

  static const cardRadius = 20.0;
  static const cardShadow = Color(0x0F000000);
  static const mapCardBg = Color(0xFFE7E1D6);

  static const checkingColor = AppColors.primary;
  static const verifiedColor = Color(0xFF3E8E5A);
  static const blockedColor = Color(0xFFC0392B);

  static const verifiedCardBg = Color(0xFFE7F3EA);
  static const blockedCardBg = Color(0xFFFBEAEA);

  static const labelMuted = Color(0x73111111);
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
            InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.chevron_left,
                    size: 20, color: AppColors.onPrimary),
              ),
            ),
            const SizedBox(width: 10),
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
        const SizedBox(height: 10),
        Text(
          _stateLabel(data),
          style: AppType.mono.copyWith(
              fontSize: 10, letterSpacing: 1.2, color: _Palette.labelMuted),
        ),
      ],
    );
  }
}

class _Content extends StatelessWidget {
  final VerifyLocationUiData data;

  const _Content({required this.data});

  Color get _ringColor => switch (data.phase) {
        VerifyLocationPhase.checking => _Palette.checkingColor,
        VerifyLocationPhase.verified => _Palette.verifiedColor,
        VerifyLocationPhase.blocked => _Palette.blockedColor,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RadiusZoneCard(ringColor: _ringColor, radiusMeters: data.radiusMeters),
        const SizedBox(height: 14),
        switch (data.phase) {
          VerifyLocationPhase.checking => _CheckingCard(data: data),
          VerifyLocationPhase.verified => _VerifiedCard(data: data),
          VerifyLocationPhase.blocked => _BlockedCard(data: data),
        },
        if (data.phase == VerifyLocationPhase.blocked &&
            data.blockReason == VerifyBlockReason.tooFar) ...[
          const SizedBox(height: 14),
          _DistanceCheckCard(data: data),
        ],
      ],
    );
  }
}

/// The "100 M RADIUS ZONE" map placeholder card, shared by all three states
/// with only the ring colour changing.
class _RadiusZoneCard extends StatelessWidget {
  final Color ringColor;
  final double radiusMeters;

  const _RadiusZoneCard({required this.ringColor, required this.radiusMeters});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: _Palette.mapCardBg,
        borderRadius: BorderRadius.circular(_Palette.cardRadius),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _DashedRadiusRing(color: ringColor, size: 110),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: const BoxDecoration(
                color: Colors.white, borderRadius: AppRadius.mdAll),
            child: Text(
              '${radiusMeters.round()} M RADIUS ZONE',
              style: AppType.mono.copyWith(fontSize: 10, letterSpacing: 0.8),
            ),
          ),
        ],
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
      background: Colors.white,
      children: [
        const SizedBox(
          width: 44,
          height: 44,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation(_Palette.checkingColor),
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
              fontSize: 11, letterSpacing: 1, color: _Palette.labelMuted),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: const BoxDecoration(
              color: _Palette.checkingColor, borderRadius: AppRadius.mdAll),
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
      background: _Palette.verifiedCardBg,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
              color: _Palette.verifiedColor, shape: BoxShape.circle),
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
              fontSize: 11, letterSpacing: 0.8, color: _Palette.verifiedColor),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.mdAll,
            border: Border.all(
                color: _Palette.verifiedColor.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check, size: 14, color: _Palette.verifiedColor),
              const SizedBox(width: 6),
              Text(
                'LOCATION VERIFIED',
                style: AppType.mono.copyWith(
                    fontSize: 10,
                    letterSpacing: 0.8,
                    color: _Palette.verifiedColor),
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
      background: _Palette.blockedCardBg,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
              color: _Palette.blockedColor, shape: BoxShape.circle),
          child: const Icon(Icons.priority_high, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 16),
        Text(copy.headline,
            textAlign: TextAlign.center,
            style: AppType.heading.copyWith(fontSize: 18)),
        if (data.blockReason == VerifyBlockReason.tooFar &&
            distance != null) ...[
          const SizedBox(height: 8),
          Text(
            'YOU ARE ${distance.round()} M FROM DESTINATION',
            style: AppType.mono.copyWith(
                fontSize: 11, letterSpacing: 0.8, color: _Palette.blockedColor),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          copy.message,
          textAlign: TextAlign.center,
          style: AppType.body
              .copyWith(fontSize: 13, color: const Color(0xB3111111)),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(_Palette.cardRadius),
        boxShadow: const [
          BoxShadow(
              color: _Palette.cardShadow, blurRadius: 8, offset: Offset(0, 2)),
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: _Palette.cardShadow, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          _DistanceRow(
            label: 'CURRENT DISTANCE',
            value: distance == null ? '—' : '${distance.round()} m',
            valueColor: _Palette.blockedColor,
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
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.mono.copyWith(
                  fontSize: 11, letterSpacing: 0.6, color: _Palette.labelMuted),
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
                fontSize: 10, letterSpacing: 0.8, color: _Palette.labelMuted),
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
              background: const Color(0xFFFAEBDC),
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
