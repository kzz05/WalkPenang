// ---------------------------------------------------------------------------
// message_state.dart
// Module 5 — Reward & Achievement
// ---------------------------------------------------------------------------
//
// The centred title/body/action block the reward screens show instead of a
// list: a failed read, a signed-out tourist, and one with nothing recorded
// yet. Those three must not look alike — one is a problem to retry, one needs
// a sign-in, and one is a normal starting point.
//
// Extracted from stats_dashboard_screen so the walking journal shows the same
// three states the same way rather than growing its own near-copy.

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../views/widgets/wp_components.dart';

class RewardMessageState extends StatelessWidget {
  final String title;
  final String body;

  /// Raw diagnostic text, shown in debug builds only.
  final String? detail;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? secondary;

  const RewardMessageState({
    required this.title,
    required this.body,
    this.detail,
    this.actionLabel,
    this.onAction,
    this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, textAlign: TextAlign.center, style: AppType.heading),
            const SizedBox(height: 10),
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(color: AppColors.muted),
            ),
            if (detail != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: AppRadius.smAll,
                  border: Border.all(color: AppColors.outline),
                ),
                child: SelectableText(
                  detail!,
                  style: AppType.monoValue.copyWith(
                    fontSize: 11,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              WpPrimaryButton(label: actionLabel!, onPressed: onAction!),
            ],
            if (secondary != null) ...[
              const SizedBox(height: 12),
              secondary!,
            ],
          ],
        ),
      ),
    );
  }
}
