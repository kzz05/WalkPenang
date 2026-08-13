// ---------------------------------------------------------------------------
// badge_card.dart
// Module 5 — Reward & Achievement
// Use Case : UC510 Unlock badges
// FR       : FR-R05 Badge Gallery
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// One tile in the badge gallery grid: the emblem, the badge name, and either
// the date it was earned or how far the tourist still has to go.
//
// FR-R05 requires locked and unlocked badges to be visually distinguishable.
// Three things carry that here, not one: the emblem is greyscaled and faded,
// the card loses its coloured border, and the caption changes from a date to
// a remaining-progress bar. Colour alone would not survive a greyscale
// screenshot or a colour-blind reader.

import 'package:flutter/material.dart';

import '../../models/badge_model.dart';
import '../../theme/app_theme.dart';
import 'badge_emblem.dart';

class BadgeCard extends StatelessWidget {
  final BadgeModel badge;

  /// Whether the tourist holds this badge.
  final bool unlocked;

  /// When it was earned. Null while [unlocked] is false.
  final DateTime? dateEarned;

  /// How far towards the threshold, 0..1. Only shown while locked.
  final double progress;

  /// Caption for a locked badge, e.g. "2 check-ins to go".
  final String remainingLabel;

  final VoidCallback? onTap;

  const BadgeCard({
    super.key,
    required this.badge,
    required this.unlocked,
    required this.progress,
    required this.remainingLabel,
    this.dateEarned,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hue = Color(badge.hue);

    return Material(
      color: AppColors.card,
      borderRadius: AppRadius.smAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.smAll,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
          decoration: BoxDecoration(
            borderRadius: AppRadius.smAll,
            border: Border.all(
              color: unlocked ? hue : AppColors.outline,
              width: unlocked ? 1.6 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BadgeEmblem(
                badge: badge,
                size: 72,
                locked: !unlocked,
                showRibbon: false,
              ),
              const SizedBox(height: 12),
              Text(
                badge.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.heading.copyWith(
                  fontSize: 15,
                  color: unlocked ? AppColors.onPrimary : AppColors.muted,
                ),
              ),
              const SizedBox(height: 6),
              if (unlocked)
                WpBadgeStateLabel(
                  text: dateEarned == null
                      ? 'unlocked'
                      : 'earned ${formatBadgeDate(dateEarned!)}',
                  color: hue,
                )
              else ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: AppColors.placeholder,
                    valueColor: AlwaysStoppedAnimation(hue),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  remainingLabel.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.mono,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The small tinted status pill under an unlocked badge.
class WpBadgeStateLabel extends StatelessWidget {
  final String text;
  final Color color;

  const WpBadgeStateLabel({
    super.key,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: AppRadius.mdAll,
      ),
      child: Text(
        text.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppType.mono.copyWith(color: color),
      ),
    );
  }
}

/// Dates are formatted here rather than with the intl package, which the
/// project does not depend on. Day-month-year matches the rest of the app.
String formatBadgeDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
