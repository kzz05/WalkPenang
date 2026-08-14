import 'package:flutter/material.dart';

import '../controllers/walking_controller.dart';
import '../models/user_profile.dart';
import '../models/walking_route_summary.dart';
import '../theme/app_theme.dart';
import 'edit_profile_view.dart';
import 'journey_flow_view.dart';
import 'widgets/wp_components.dart';

/// Screen 02 · Pre-Walk Summary (UC-W02) v2 — destination hero, walking
/// route stats, reward note, and the Start Journey CTA.
///
/// Reads its data from the [WalkingController] passed in by
/// [WalkingView] — the same controller instance, not a copy — so it stays
/// bound to whatever route Map & GPS eventually supplies via
/// [WalkingController.setRouteSummary].
class PreWalkSummaryView extends StatefulWidget {
  final WalkingController controller;

  const PreWalkSummaryView({super.key, required this.controller});

  @override
  State<PreWalkSummaryView> createState() => _PreWalkSummaryViewState();
}

class _PreWalkSummaryViewState extends State<PreWalkSummaryView> {
  bool get _isStarting =>
      widget.controller.journeyStartStatus == JourneyStartStatus.loading;

  Future<void> _handleStartJourney() async {
    await widget.controller.startJourney();
    if (!mounted) return;

    final controller = widget.controller;
    if (controller.journeyStartStatus == JourneyStartStatus.success) {
      controller.acknowledgeJourneyStart();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => JourneyFlowView(walkingController: controller),
        ),
      );
    } else if (controller.journeyStartError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(controller.journeyStartError!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) {
              final summary = widget.controller.routeSummary;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(onBack: () => Navigator.of(context).pop()),
                  const SizedBox(height: 32),
                  Expanded(
                    child: summary == null
                        ? const _MissingRouteData()
                        : SingleChildScrollView(
                            child: _SummaryContent(
                              summary: summary,
                              controller: widget.controller,
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),
                  _StartJourneyButton(
                    enabled: summary != null && !_isStarting,
                    loading: _isStarting,
                    onPressed: _handleStartJourney,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Back button and the "Journey Preview" title.
class _Header extends StatelessWidget {
  final VoidCallback onBack;

  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
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
        const SizedBox(width: 10),
        Text(
          'Journey Preview',
          style: AppType.heading.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Shown instead of the summary when Map & GPS hasn't (or couldn't)
/// supply route data — covers both "never set" and validation failure,
/// since [WalkingController.startJourney] clears the summary in neither
/// case but this guards the display itself for T-W02.3's "missing route
/// data" requirement.
class _MissingRouteData extends StatelessWidget {
  const _MissingRouteData();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.location_off_outlined,
            size: 40,
            color: AppColors.muted,
          ),
          const SizedBox(height: 16),
          Text(
            'Route details unavailable',
            style: AppType.heading.copyWith(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "We couldn't load this walking route. Go back and choose a "
            'destination again.',
            style: AppType.body.copyWith(fontSize: 13, color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Hero card, stats grid, and reward note — the summary body once route
/// data is available.
class _SummaryContent extends StatelessWidget {
  final WalkingRouteSummary summary;
  final WalkingController controller;

  const _SummaryContent({required this.summary, required this.controller});

  /// Sends the user to the existing Edit Profile screen and, if they save
  /// changes, refreshes [controller]'s profile the same way [HomeView]
  /// refreshes its own — so [WalkingController.caloriesBurned] recomputes
  /// with the updated weight once we're back on this screen.
  Future<void> _openEditProfile(BuildContext context) async {
    final profile = controller.userProfile;
    if (profile == null) return;

    final updated = await Navigator.of(context).push<UserProfile>(
      MaterialPageRoute(
        builder: (_) => EditProfileView(profile: profile),
      ),
    );
    if (updated != null) {
      controller.setUserProfile(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final carbonSavedKg = controller.calculateCarbonSavings(summary.distanceKm);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DestinationHero(summary: summary),
        const SizedBox(height: 14),
        _StatsGrid(
          summary: summary,
          carbonSavedKg: carbonSavedKg,
          caloriesBurned: controller.caloriesBurned,
          onUpdateWeight: () => _openEditProfile(context),
        ),
        const SizedBox(height: 14),
        _RewardNote(summary: summary),
      ],
    );
  }
}

/// The destination card — "WALKING ROUTE" chip, name, and area label.
class _DestinationHero extends StatelessWidget {
  final WalkingRouteSummary summary;

  const _DestinationHero({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 160,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: const BoxDecoration(
              color: AppColors.card,
              borderRadius: AppRadius.mdAll,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.onPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const WpMonoLabel('WALKING ROUTE', size: 9),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            summary.destinationName,
            style: AppType.body.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          WpMonoLabel(summary.areaLabel, size: 10),
        ],
      ),
    );
  }
}

/// The 2×2 distance / duration / CO2 / calories tiles.
class _StatsGrid extends StatelessWidget {
  final WalkingRouteSummary summary;
  final double carbonSavedKg;

  /// Null when the calorie estimate isn't available (US-W04) — the KCAL
  /// tile prompts the user to update their profile instead of showing a
  /// number.
  final double? caloriesBurned;
  final VoidCallback onUpdateWeight;

  const _StatsGrid({
    required this.summary,
    required this.carbonSavedKg,
    required this.caloriesBurned,
    required this.onUpdateWeight,
  });

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
                  value: summary.distanceKm.toStringAsFixed(1),
                  label: 'KM DISTANCE',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  dotColor: AppColors.primary,
                  value: '${summary.estimatedDuration.inMinutes}',
                  label: 'MIN ESTIMATED',
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
                  value: carbonSavedKg.toStringAsFixed(2),
                  label: 'KG CO₂ SAVED',
                  background: AppColors.successTint,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: caloriesBurned == null
                    ? _StatTile(
                        dotColor: AppColors.calories,
                        value: 'Add',
                        label: 'TAP TO ADD',
                        background: AppColors.warningTint,
                        onTap: onUpdateWeight,
                      )
                    : _StatTile(
                        dotColor: AppColors.calories,
                        value: '${caloriesBurned!.round()}',
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

class _StatTile extends StatelessWidget {
  final Color dotColor;
  final String value;
  final String label;
  final Color background;

  /// When set, the tile becomes tappable — used by the KCAL tile's missing
  /// body-weight prompt (US-W04) to jump to Edit Profile.
  final VoidCallback? onTap;

  const _StatTile({
    required this.dotColor,
    required this.value,
    required this.label,
    this.background = AppColors.card,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: AppType.body.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppType.mono.copyWith(fontSize: 10, color: AppColors.muted),
        ),
      ],
    );

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            boxShadow: const [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: content,
        ),
      ),
    );
  }
}

/// The WalkPoints reward callout.
class _RewardNote extends StatelessWidget {
  final WalkingRouteSummary summary;

  const _RewardNote({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.backgroundDeep,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.primaryDeep),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '★',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.star,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Complete this walk to earn ${summary.rewardPoints} WalkPoints '
              'and unlock ${summary.rewardBadgeLabel}.',
              style: AppType.body.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width "Start Journey" CTA — shows a spinner while the action is
/// processing and disables while loading or when route data is missing.
class _StartJourneyButton extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  const _StartJourneyButton({
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled || loading ? AppColors.primary : AppColors.placeholder,
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        onTap: enabled ? onPressed : null,
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
                    'Start Journey',
                    style: AppType.body.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onPrimary.withValues(
                        alpha: enabled ? 1 : 0.4,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
