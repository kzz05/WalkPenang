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

  /// Sends the journey to the mini bar and the tourist back to whatever else
  /// they wanted to do. Null where there is nowhere to minimise to — the debug
  /// flow, which is the journey screens and nothing else.
  final VoidCallback? onMinimize;

  const ActiveWalkingView({
    super.key,
    required this.data,
    this.onBack,
    this.onOpenNavigation,
    this.onCompleteJourney,
    this.onMinimize,
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
              _Header(onBack: onBack, onMinimize: onMinimize),
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

class _Header extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback? onMinimize;

  const _Header({required this.onBack, this.onMinimize});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        WpBackButton(onBack: onBack),
        // The pill takes what is left between the two 40dp controls rather
        // than its natural width: "JOURNEY ACTIVE" at a large system font is
        // wider than a 320dp screen has to spare.
        Flexible(
          child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: const BoxDecoration(
            color: AppColors.successTint,
            borderRadius: AppRadius.mdAll,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'JOURNEY ACTIVE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.mono.copyWith(
                    fontSize: 11,
                    letterSpacing: 1,
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          ),
        ),
        // Balances the back button when there is nowhere to minimise to, so
        // the JOURNEY ACTIVE pill stays centred either way.
        if (onMinimize == null)
          const SizedBox(width: 40)
        else
          Tooltip(
            message: 'Keep walking, use the app',
            child: InkWell(
              onTap: onMinimize,
              customBorder: const CircleBorder(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.outline),
                ),
                child: const Icon(
                  Icons.keyboard_arrow_down,
                  size: 22,
                  color: AppColors.onPrimary,
                ),
              ),
            ),
          ),
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
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
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
              color: AppColors.muted,
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
              Flexible(
                child: WpMonoLabel(
                  data.destinationName,
                  size: 10,
                  color: AppColors.muted,
                  // "Cheong Fatt Tze - The Blue Mansion" is 135dp wider than a
                  // 360dp screen leaves here.
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Container(height: 4, color: AppColors.placeholder),
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
                      color: AppColors.muted)),
              Text(
                '${data.plannedDistanceKm.toStringAsFixed(1)} KM',
                style: AppType.mono.copyWith(
                    fontSize: 9,
                    letterSpacing: 0.8,
                    color: AppColors.muted),
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
                  dotColor: AppColors.primary,
                  value: data.kmCovered?.toStringAsFixed(1),
                  label: 'KM COVERED',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  dotColor: AppColors.primary,
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
                  dotColor: AppColors.carbon,
                  value: data.carbonSavedKg?.toStringAsFixed(2),
                  // Estimate, not an accrual: the figure is the planned
                  // route's saving, snapshotted at journey start, so the
                  // label must not read as an amount already achieved.
                  label: 'EST. KG CO₂ SAVED',
                  background: AppColors.successTint,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  dotColor: AppColors.calories,
                  value: data.caloriesBurned?.round().toString(),
                  label: 'KCAL BURNED',
                  background: AppColors.warningTint,
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
    this.background = AppColors.card,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
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
                AppType.mono.copyWith(fontSize: 10, color: AppColors.muted),
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
          background: AppColors.backgroundDeep,
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
