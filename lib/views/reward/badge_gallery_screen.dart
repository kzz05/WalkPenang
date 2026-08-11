// ---------------------------------------------------------------------------
// badge_gallery_screen.dart
// Module 5 — Reward & Achievement
// Use Case : UC510 Unlock badges
// FR       : FR-R05 Badge Gallery
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// Every badge that exists, unlocked ones distinguishable from locked ones.
//
// Shows the full set rather than only what the tourist holds: the locked
// badges are what tell them the milestone exists and how far off it is, which
// is the point of the gallery.
//
// Takes the controller the dashboard already loaded rather than creating its
// own, so opening the gallery costs no further reads.

import 'package:flutter/material.dart';

import '../../controllers/reward_controller.dart';
import '../../models/badge_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/reward/badge_card.dart';
import '../widgets/wp_components.dart';
import 'badge_detail_screen.dart';

class BadgeGalleryScreen extends StatelessWidget {
  final RewardController controller;

  const BadgeGalleryScreen({super.key, required this.controller});

  Future<void> _openBadge(BuildContext context, BadgeModel badge) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BadgeDetailScreen(badge: badge, controller: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final definitions = controller.definitions;

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        WpBackBar(onBack: () => Navigator.of(context).pop()),
                        const SizedBox(height: 24),
                        Text('Badges', style: AppType.display),
                        const SizedBox(height: 8),
                        WpMonoLabel(
                          '${controller.unlockedBadgeCount} of '
                          '${definitions.length} unlocked',
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      // Tall enough for the emblem, the name, and either the
                      // earned pill or the progress bar plus its caption.
                      childAspectRatio: 0.78,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final badge = definitions[index];
                        return BadgeCard(
                          badge: badge,
                          unlocked: controller.hasEarned(badge.id),
                          dateEarned:
                              controller.earnedBadge(badge.id)?.dateEarned,
                          progress: controller.progressTowards(badge),
                          remainingLabel: controller.remainingLabel(badge),
                          onTap: () => _openBadge(context, badge),
                        );
                      },
                      childCount: definitions.length,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
