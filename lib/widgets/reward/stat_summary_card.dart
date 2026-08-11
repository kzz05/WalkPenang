// ---------------------------------------------------------------------------
// stat_summary_card.dart
// Module 5 — Reward & Achievement
// Use Case : UC530 View statistics dashboard
// FR       : FR-R04 Statistics Dashboard
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// The tiles the statistics dashboard is built from.
//
// None of these values are calculated here or anywhere in Module 5. Distance,
// carbon and calories are produced per check-in by Module 4 and only
// accumulated; this widget formats what it is handed.

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../views/widgets/wp_components.dart';

/// The headline points balance, given its own full-width card because
/// FR-R01 makes it the tourist's primary reward feedback.
class PointsBalanceCard extends StatelessWidget {
  final int totalPoints;
  final int totalCheckIns;

  const PointsBalanceCard({
    super.key,
    required this.totalPoints,
    required this.totalCheckIns,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.smAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WpMonoLabel(
            'total points',
            color: AppColors.onSurfaceMuted,
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$totalPoints',
                style: AppType.display.copyWith(
                  color: Colors.white,
                  fontSize: 44,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'pts',
                style: AppType.body.copyWith(color: AppColors.onSurfaceMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          WpMonoLabel(
            totalCheckIns == 1
                ? 'from 1 check-in'
                : 'from $totalCheckIns check-ins',
            color: AppColors.onSurfaceMuted,
          ),
        ],
      ),
    );
  }
}

/// One secondary metric — distance, carbon or calories.
class StatSummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;

  const StatSummaryCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.smAll,
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.muted),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.stat.copyWith(fontSize: 22),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: AppType.mono.copyWith(fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          WpMonoLabel(label),
        ],
      ),
    );
  }
}
