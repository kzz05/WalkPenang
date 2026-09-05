import 'package:flutter/material.dart';

import '../models/journey_completed_ui_data.dart';
import '../models/journey_reward_ui_state.dart';
import '../theme/app_theme.dart';
import 'widgets/wp_components.dart';

/// Screen 05 · Journey Completed (UC-W05) v2 — badge summary confirmation,
/// journey stats, and Back to Explore / View Journey actions.
///
/// Presentation only. All data arrives via [data]; every user action is
/// reported through a callback. This widget never calls the Reward Module,
/// touches Firestore, or resolves badge data itself — the reward card
/// renders exactly whatever [JourneyCompletedUiData.reward] it's given,
/// defaulting to [JourneyRewardUiState.unavailable] so nothing is ever
/// fabricated.
class JourneyCompletedView extends StatelessWidget {
  final JourneyCompletedUiData data;
  final VoidCallback? onBack;
  final VoidCallback? onReturnHome;
  final VoidCallback? onViewRewards;
  final VoidCallback? onRetryReward;

  const JourneyCompletedView({
    super.key,
    required this.data,
    this.onBack,
    this.onReturnHome,
    this.onViewRewards,
    this.onRetryReward,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          // Scrolls only when it has to. Everything used to be pinned except
          // the middle, which meant that once the header and the two footer
          // buttons were taller than the screen — a large system font on a
          // short phone — there was nothing left for Expanded to give and the
          // column overflowed. Now the whole screen scrolls when it does not
          // fit, and keeps its pinned-footer look when it does.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(data: data, onBack: onBack),
                      const SizedBox(height: 24),
                      _Content(data: data, onRetryReward: onRetryReward),
                      // Holds the footer at the bottom while there is room to
                      // spare, and collapses to nothing once there is not.
                      const Spacer(),
                      const SizedBox(height: 24),
                      _Footer(
                        onReturnHome: onReturnHome,
                        onViewRewards: onViewRewards,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Presentational unit conversions for this screen. Colours and radii come
/// from [AppColors]/[AppRadius] like every other module.
class _Conversions {
  const _Conversions._();

  /// Derived from the Figma sample (0.50 kg CO2 -> "60 phone charges"),
  /// i.e. 120 charges per kg — applied to the real, already-calculated
  /// carbon figure, not a reward value.
  static const phoneChargesPerKg = 120.0;
}

class _Header extends StatelessWidget {
  final JourneyCompletedUiData data;
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
            // Flexible for the same reason as Active Walking's pill: at a
            // large system font the label is wider than the row has left.
            Flexible(
              child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: const BoxDecoration(
                  color: AppColors.primary, borderRadius: AppRadius.mdAll),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('★',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.onPrimary)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'JOURNEY COMPLETE',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.mono.copyWith(
                          fontSize: 10,
                          letterSpacing: 0.8,
                          color: AppColors.onPrimary),
                    ),
                  ),
                ],
              ),
            ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Well done, Explorer!',
          style: AppType.display.copyWith(fontSize: 26),
        ),
        const SizedBox(height: 6),
        WpMonoLabel(
          '${data.destinationName} · ${data.destinationAreaLabel}',
          size: 10,
        ),
      ],
    );
  }
}

class _Content extends StatelessWidget {
  final JourneyCompletedUiData data;
  final VoidCallback? onRetryReward;

  const _Content({required this.data, required this.onRetryReward});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RewardCard(reward: data.reward, onRetry: onRetryReward),
        const SizedBox(height: 20),
        const WpMonoLabel('journey summary'),
        const SizedBox(height: 12),
        _SummaryGrid(data: data),
        if (data.carbonSavedKg != null) ...[
          const SizedBox(height: 14),
          _CarbonContextCard(carbonSavedKg: data.carbonSavedKg!),
        ],
      ],
    );
  }
}

/// Renders [JourneyCompletedUiData.reward] as-is — no defaults beyond what
/// [JourneyRewardUiState] itself defines, and no points/badge text in any
/// state other than [JourneyRewardUiStatus.success].
class _RewardCard extends StatelessWidget {
  final JourneyRewardUiState reward;
  final VoidCallback? onRetry;

  const _RewardCard({required this.reward, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return switch (reward.status) {
      JourneyRewardUiStatus.unavailable => const _NeutralCard(
          icon: Icons.lock_outline,
          title: 'Rewards unavailable',
          subtitle: "This journey's reward hasn't been processed yet.",
        ),
      JourneyRewardUiStatus.pending => const _NeutralCard(
          icon: null,
          title: 'Calculating your reward…',
          subtitle: 'This usually only takes a moment.',
          showSpinner: true,
        ),
      JourneyRewardUiStatus.success => _SuccessCard(reward: reward),
      JourneyRewardUiStatus.error => _ErrorCard(
          message: reward.errorMessage ??
              'Unable to process this journey\'s reward.',
          onRetry: onRetry,
        ),
    };
  }
}

class _NeutralCard extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String subtitle;
  final bool showSpinner;

  const _NeutralCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.showSpinner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.backgroundDeep,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          if (showSpinner)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.4, color: AppColors.muted),
            )
          else
            Icon(icon, size: 24, color: AppColors.muted),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.heading.copyWith(fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: AppType.body
                        .copyWith(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.dangerTint,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline,
              size: 24, color: AppColors.danger),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reward error',
                  style: AppType.heading
                      .copyWith(fontSize: 14, color: AppColors.danger),
                ),
                const SizedBox(height: 2),
                Text(message,
                    style: AppType.body.copyWith(
                        fontSize: 12, color: AppColors.muted)),
                if (onRetry != null) ...[
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: onRetry,
                    child: Text(
                      'Retry',
                      style: AppType.body.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessCard extends StatelessWidget {
  final JourneyRewardUiState reward;

  const _SuccessCard({required this.reward});

  @override
  Widget build(BuildContext context) {
    final hasNewBadges = reward.newlyEarnedBadgeNames.isNotEmpty;
    final alreadyAwarded = reward.alreadyAwarded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  alreadyAwarded
                      ? 'Reward already recorded'
                      : '+${reward.pointsAwarded} WalkPoints',
                  style: AppType.heading.copyWith(fontSize: 18),
                ),
              ),
              if (hasNewBadges && !alreadyAwarded)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: const BoxDecoration(
                      color: AppColors.card, borderRadius: AppRadius.mdAll),
                  child: Text(
                    'NEW',
                    style:
                        AppType.mono.copyWith(fontSize: 9, letterSpacing: 0.8),
                  ),
                ),
            ],
          ),
          if (alreadyAwarded) ...[
            const SizedBox(height: 4),
            Text(
              'This journey already earned ${reward.pointsAwarded} points — no new '
              'reward for completing it again.',
              style: AppType.body
                  .copyWith(fontSize: 12, color: AppColors.muted),
            ),
          ],
          if (hasNewBadges) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final name in reward.newlyEarnedBadgeNames)
                  WpChip(name, background: AppColors.card),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final JourneyCompletedUiData data;

  const _SummaryGrid({required this.data});

  static String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes)}:${two(d.inSeconds.remainder(60))}';
  }

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
                  value: data.completedDistanceKm?.toStringAsFixed(1),
                  label: 'KM WALKED',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  dotColor: AppColors.primary,
                  value: data.journeyDuration == null
                      ? null
                      : _formatDuration(data.journeyDuration!),
                  label: 'DURATION',
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
                  label: 'KG CO₂ SAVED',
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
              color: AppColors.cardShadow, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          const SizedBox(height: 8),
          Text(value ?? '—',
              style: AppType.body
                  .copyWith(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(label,
              style: AppType.mono
                  .copyWith(fontSize: 10, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _CarbonContextCard extends StatelessWidget {
  final double carbonSavedKg;

  const _CarbonContextCard({required this.carbonSavedKg});

  @override
  Widget build(BuildContext context) {
    final charges = (carbonSavedKg * _Conversions.phoneChargesPerKg).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
          color: AppColors.successTint,
          borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: AppColors.carbon, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'By walking instead of driving, you saved ${carbonSavedKg.toStringAsFixed(2)} kg '
              'CO₂ — equivalent to charging a phone $charges times.',
              style: AppType.body
                  .copyWith(fontSize: 12, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final VoidCallback? onReturnHome;
  final VoidCallback? onViewRewards;

  const _Footer({required this.onReturnHome, required this.onViewRewards});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PillButton(
            label: 'Back to Explore',
            background: AppColors.primary,
            onPressed: onReturnHome),
        const SizedBox(height: 10),
        _PillButton(
            label: 'View Journey',
            background: AppColors.backgroundDeep,
            onPressed: onViewRewards),
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final Color background;
  final VoidCallback? onPressed;

  const _PillButton(
      {required this.label, required this.background, required this.onPressed});

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
          child: Center(
            child: Text(
              label,
              style: AppType.body.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.onPrimary.withValues(alpha: enabled ? 1 : 0.4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
