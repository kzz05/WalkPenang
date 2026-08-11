// ---------------------------------------------------------------------------
// badge_unlock_notification.dart
// Module 5 — Reward & Achievement
// Use Case : UC510 Unlock badges
// FR       : FR-R02 Badge Milestone System
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// The in-app confirmation message shown when a check-in crosses a milestone.
//
// A confirmation message, not a notification: FCM push is out of scope. The
// filename is the one fixed in the module file list.
//
// Handles a list rather than one badge, because a single long check-in can
// cross two thresholds at once and UC510 awards both — showing one dialog per
// badge would make the tourist dismiss the same thing twice.

import 'package:flutter/material.dart';

import '../../models/badge_model.dart';
import '../../theme/app_theme.dart';
import '../../views/widgets/wp_components.dart';
import 'badge_emblem.dart';

Future<void> showBadgeUnlockConfirmation(
  BuildContext context,
  List<BadgeModel> badges,
) {
  if (badges.isEmpty) return Future.value();

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            WpMonoLabel(
              badges.length == 1 ? 'badge unlocked' : 'badges unlocked',
              align: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final badge in badges)
                  BadgeEmblem(badge: badge, size: 104),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              badges.length == 1
                  ? badges.single.description
                  : 'You crossed ${badges.length} milestones with one '
                      'check-in.',
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 22),
            WpPrimaryButton(
              label: 'nice',
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}
