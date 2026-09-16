// ---------------------------------------------------------------------------
// badge_detail_screen.dart
// Module 5 — Reward & Achievement
// Use Case : UC510 Unlock badges
// FR       : FR-R05 Badge Gallery
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// One badge at full size: how it is earned, and either when the tourist
// earned it or how much of the milestone is left.
//
// The threshold shown is read off the badge definition, never written into
// this screen as prose. A badge whose threshold changes in Firestore updates
// here with no code change.

import 'package:flutter/material.dart';

import '../../controllers/reward_controller.dart';
import '../../models/badge_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/reward_constants.dart';
import '../../widgets/reward/badge_card.dart';
import '../../widgets/reward/badge_emblem.dart';
import '../widgets/wp_components.dart';

class BadgeDetailScreen extends StatelessWidget {
  final BadgeModel badge;
  final RewardController controller;

  const BadgeDetailScreen({
    super.key,
    required this.badge,
    required this.controller,
  });

  /// Drops the decimal on a whole-number milestone, so 10 km reads as "10 km"
  /// and not "10.0 km", while a half-kilometre threshold keeps its digit.
  static String _trim(double value) =>
      value.toStringAsFixed(value % 1 == 0 ? 0 : 1);

  /// The milestone in the unit the tourist reads it in.
  String get _thresholdLabel {
    switch (badge.criterion) {
      case BadgeCriterion.totalCheckIns:
        return '${badge.threshold} check-ins';
      case BadgeCriterion.cumulativeDistance:
        return '${_trim(badge.thresholdKm)} km';
      case BadgeCriterion.totalPoints:
        return '${badge.threshold} points';
      case BadgeCriterion.carbonSaved:
        return '${_trim(badge.thresholdKg)} kg CO2';
    }
  }

  /// Where the tourist currently stands against this badge's criterion.
  String _progressLabel(RewardController controller) {
    final stats = controller.stats;
    switch (badge.criterion) {
      case BadgeCriterion.totalCheckIns:
        return '${stats.totalCheckIns} check-ins';
      case BadgeCriterion.cumulativeDistance:
        return '${RewardConstants.kmFromMetres(stats.totalDistanceMetres).toStringAsFixed(1)} km';
      case BadgeCriterion.totalPoints:
        return '${stats.totalPoints} points';
      case BadgeCriterion.carbonSaved:
        return '${stats.totalCarbonSavedKg.toStringAsFixed(2)} kg CO2';
    }
  }

  /// How the criterion itself is named on the detail rows.
  String get _criterionLabel {
    switch (badge.criterion) {
      case BadgeCriterion.totalCheckIns:
        return 'Total check-ins';
      case BadgeCriterion.cumulativeDistance:
        return 'Cumulative distance';
      case BadgeCriterion.totalPoints:
        return 'Points balance';
      case BadgeCriterion.carbonSaved:
        return 'Carbon saved';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hue = Color(badge.hue);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final unlocked = controller.hasEarned(badge.id);
            final earned = controller.earnedBadge(badge.id);

            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: [
                WpBackBar(onBack: () => Navigator.of(context).pop()),
                const SizedBox(height: 24),

                Center(
                  child: BadgeEmblem(
                    badge: badge,
                    size: 180,
                    locked: !unlocked,
                  ),
                ),
                const SizedBox(height: 28),

                Text(
                  badge.name,
                  textAlign: TextAlign.center,
                  style: AppType.display.copyWith(fontSize: 28),
                ),
                const SizedBox(height: 10),
                Center(
                  child: unlocked
                      ? WpBadgeStateLabel(
                          text: earned == null
                              ? 'unlocked'
                              : 'earned ${formatBadgeDate(earned.dateEarned)}',
                          color: hue,
                        )
                      : const WpChip('locked', uppercase: true),
                ),
                const SizedBox(height: 24),

                Text(
                  badge.description,
                  textAlign: TextAlign.center,
                  style: AppType.body.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 28),

                if (!unlocked) ...[
                  const WpMonoLabel('progress'),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: controller.progressTowards(badge),
                      minHeight: 8,
                      backgroundColor: AppColors.placeholder,
                      valueColor: AlwaysStoppedAnimation(hue),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    controller.remainingLabel(badge),
                    style: AppType.body.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 20),
                ],

                WpDetailRow(label: 'criterion', value: _criterionLabel),
                WpDetailRow(label: 'milestone', value: _thresholdLabel),
                WpDetailRow(
                  label: 'your total',
                  value: _progressLabel(controller),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
