import 'package:flutter/material.dart';

import '../models/active_walking_ui_data.dart';
import '../theme/app_theme.dart';
import 'widgets/wp_components.dart';

/// Screen 03 · Active Walking Journey (UC-W05) v2 — elapsed time, live
/// stats, Open Navigation and Complete Journey actions.
///
/// Presentation only. All data arrives via [data]; every user action is
/// reported through a callback. This widget never performs GPS reads,
/// Firestore writes, reward processing, or navigation side effects itself —
/// callers own that behaviour and pass the resulting data/state back in.
class ActiveWalkingView extends StatelessWidget {
  final ActiveWalkingUiData data;
  final VoidCallback? onBack;
  final VoidCallback? onOpenNavigation;
  final VoidCallback? onCompleteJourney;

  const ActiveWalkingView({
    super.key,
    required this.data,
    this.onBack,
    this.onOpenNavigation,
    this.onCompleteJourney,
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
              _Header(onBack: onBack),
              const SizedBox(height: 32),
              Expanded(
                child: SingleChildScrollView(
                  child: _Content(data: data),
                ),
              ),
              const SizedBox(height: 24),
              _Footer(
                data: data,
                onOpenNavigation: onOpenNavigation,
                onCompleteJourney: onCompleteJourney,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Page-local design constants — values this frame needs that the shared
/// token set (`AppColors`/`AppType`/`AppRadius`) doesn't define, following
/// the same per-screen `_Palette` pattern as `walking_view.dart` and
/// `pre_walk_summary_view.dart`.
class _Palette {
  const _Palette._();

  static const heroRadius = 20.0;
  static const tileRadius = 16.0;
  static const cardShadow = Color(0x0F000000);

  static const statusActiveBg = Color(0xFFF0F7F2);
  static const statusActiveText = Color(0xFF4A7C59);

  static const secondaryButtonBg = Color(0xFFFAEBDC);

  static const co2TileBg = Color(0xFFF0F7F2);
  static const kcalTileBg = Color(0xFFFFF5EE);

  static const distanceDot = AppColors.primary;
  static const co2Dot = Color(0xFF3E8E5A);
  static const kcalDot = Color(0xFFE0713C);

  static const labelMuted = Color(0x73111111);
  static const trackBg = Color(0x1A111111);
}

class _Header extends StatelessWidget {
  final VoidCallback? onBack;

  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
            child: const Icon(
              Icons.chevron_left,
              size: 20,
              color: AppColors.onPrimary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: const BoxDecoration(
            color: _Palette.statusActiveBg,
            borderRadius: AppRadius.mdAll,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: _Palette.statusActiveText,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'JOURNEY ACTIVE',
                style: AppType.mono.copyWith(
                  fontSize: 11,
                  letterSpacing: 1,
                  color: _Palette.statusActiveText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 32),
      ],
    );
  }
}

class _Content extends StatelessWidget {
  final ActiveWalkingUiData data;

  const _Content({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ElapsedTimeCard(data: data),
        const SizedBox(height: 14),
        _LiveStatsGrid(data: data),
      ],
    );
  }
}

class _ElapsedTimeCard extends StatelessWidget {
  final ActiveWalkingUiData data;

  const _ElapsedTimeCard({required this.data});

  static String _formatElapsed(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:'
        '${two(d.inSeconds.remainder(60))}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_Palette.heroRadius),
        boxShadow: const [
          BoxShadow(
            color: _Palette.cardShadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'ELAPSED TIME',
            style: AppType.mono.copyWith(
              fontSize: 10,
              letterSpacing: 1.2,
              color: const Color(0x73111111),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatElapsed(data.elapsedTime),
            style: AppType.body.copyWith(
              fontSize: 44,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.muted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              WpMonoLabel(data.destinationName,
                  size: 10, color: const Color(0x8C111111)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Container(height: 4, color: _Palette.trackBg),
                    Container(
                      height: 4,
                      width: constraints.maxWidth * data.progressFraction,
                      color: AppColors.primary,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0 KM',
                  style: AppType.mono.copyWith(
                      fontSize: 9,
                      letterSpacing: 0.8,
                      color: _Palette.labelMuted)),
              Text(
                '${data.plannedDistanceKm.toStringAsFixed(1)} KM',
                style: AppType.mono.copyWith(
                    fontSize: 9,
                    letterSpacing: 0.8,
                    color: _Palette.labelMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveStatsGrid extends StatelessWidget {
  final ActiveWalkingUiData data;

  const _LiveStatsGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatTile(
                  dotColor: _Palette.distanceDot,
                  value: data.kmCovered?.toStringAsFixed(1),
                  label: 'KM COVERED',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  dotColor: _Palette.distanceDot,
                  value: data.minutesRemaining?.toString(),
                  label: 'MIN REMAINING',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatTile(
                  dotColor: _Palette.co2Dot,
                  value: data.carbonSavedKg?.toStringAsFixed(2),
                  label: 'KG CO₂ SAVED',
                  background: _Palette.co2TileBg,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  dotColor: _Palette.kcalDot,
                  value: data.caloriesBurned?.round().toString(),
                  label: 'KCAL BURNED',
                  background: _Palette.kcalTileBg,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One live-stat tile. [value] is null whenever the figure genuinely isn't
/// available — rendered as "—", never as a fabricated 0 or placeholder
/// number.
class _StatTile extends StatelessWidget {
  final Color dotColor;
  final String? value;
  final String label;
  final Color background;

  const _StatTile({
    required this.dotColor,
    required this.value,
    required this.label,
    this.background = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(_Palette.tileRadius),
        boxShadow: const [
          BoxShadow(
            color: _Palette.cardShadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(height: 8),
          Text(
            value ?? '—',
            style: AppType.body
                .copyWith(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style:
                AppType.mono.copyWith(fontSize: 10, color: _Palette.labelMuted),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final ActiveWalkingUiData data;
  final VoidCallback? onOpenNavigation;
  final VoidCallback? onCompleteJourney;

  const _Footer({
    required this.data,
    required this.onOpenNavigation,
    required this.onCompleteJourney,
  });

  @override
  Widget build(BuildContext context) {
    final busy = data.isCompleting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PillButton(
          label: 'Open Navigation',
          background: _Palette.secondaryButtonBg,
          onPressed: busy ? null : onOpenNavigation,
        ),
        const SizedBox(height: 10),
        _PillButton(
          label: 'Complete Journey',
          background: AppColors.primary,
          onPressed: busy ? null : onCompleteJourney,
          loading: busy,
        ),
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final Color background;
  final VoidCallback? onPressed;
  final bool loading;

  const _PillButton({
    required this.label,
    required this.background,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Material(
      color: enabled || loading ? background : AppColors.placeholder,
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation(AppColors.onPrimary),
                    ),
                  )
                : Text(
                    label,
                    style: AppType.body.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onPrimary
                          .withValues(alpha: enabled ? 1 : 0.4),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
