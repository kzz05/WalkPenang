// ---------------------------------------------------------------------------
// points_notification.dart
// Module 5 — Reward & Achievement
// Use Case : UC500 Earn points from activities
// FR       : FR-R01 Points Award System
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// The in-app confirmation message shown after a check-in is rewarded.
//
// A confirmation message, not a notification: FCM push is out of scope, so
// this is surfaced inside the app while the tourist is looking at it. The
// filename is the one fixed in the module file list.

import 'package:flutter/material.dart';

import '../../controllers/reward_service.dart';
import '../../theme/app_theme.dart';

/// Confirms what a check-in earned.
///
/// A repeated check-in is reported honestly rather than silently: awarding is
/// idempotent, so the tourist is told the points were already counted instead
/// of being shown a second award that never happened.
void showPointsConfirmation(BuildContext context, RewardOutcome outcome) {
  final message = outcome.alreadyAwarded
      ? 'This check-in was already counted — no extra points.'
      : 'Check-in complete. +${outcome.pointsAwarded} points.';

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              outcome.alreadyAwarded
                  ? Icons.info_outline
                  : Icons.stars_rounded,
              size: 18,
              color: AppColors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AppType.body.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
}
