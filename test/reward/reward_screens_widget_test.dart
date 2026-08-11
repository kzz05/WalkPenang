// ---------------------------------------------------------------------------
// reward_screens_widget_test.dart
// Module 5 — Reward & Achievement
// Use Case : UC530 View statistics dashboard, UC510 Unlock badges
// FR       : FR-R04 Statistics Dashboard, FR-R05 Badge Gallery
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// Smoke tests for the Reward screens, driven by the in-memory DAOs so no
// Firebase project or signed-in tourist is needed.
//
// These exist mainly to catch layout overflow: the badge tiles carry a
// variable-length caption, and a RenderFlex overflow only shows up when the
// widgets are actually laid out, never in flutter analyze.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkpenang/controllers/reward_controller.dart';
import 'package:walkpenang/dao/in_memory_reward_data.dart';
import 'package:walkpenang/models/badge_model.dart';
import 'package:walkpenang/views/reward/badge_detail_screen.dart';
import 'package:walkpenang/views/reward/badge_gallery_screen.dart';
import 'package:walkpenang/views/reward/stats_dashboard_screen.dart';
import 'package:walkpenang/widgets/reward/stat_summary_card.dart';

RewardController demoController() => RewardController(
      userId: DemoRewardData.userId,
      rewardDao: DemoRewardData.rewardDao(),
      badgeDao: DemoRewardData.badgeDao(),
      isDemo: true,
    );

RewardController emptyController() => RewardController(
      userId: 'tourist_001',
      rewardDao: InMemoryRewardDao(),
      badgeDao: InMemoryBadgeDao(),
    );

Future<void> pump(WidgetTester tester, Widget screen) async {
  // A representative phone. Fixing the size makes an overflow deterministic
  // rather than dependent on the default 800x600 test window.
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('dashboard shows the totals and the badge set', (tester) async {
    await pump(tester, StatsDashboardScreen(controller: demoController()));

    expect(find.text('Rewards'), findsOneWidget);
    expect(find.text('194'), findsOneWidget); // total points
    expect(find.text('12.4'), findsOneWidget); // distance in km
    expect(find.textContaining('2 OF 3 UNLOCKED'), findsOneWidget);

    // Demo data must always be labelled as such on screen.
    expect(find.text('DEMO DATA'), findsOneWidget);

    for (final badge in BadgeCatalogue.all) {
      expect(find.text(badge.name), findsWidgets, reason: badge.name);
    }
  });

  testWidgets('dashboard renders the empty state without overflowing',
      (tester) async {
    await pump(tester, StatsDashboardScreen(controller: emptyController()));

    expect(
      find.descendant(
        of: find.byType(PointsBalanceCard),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );
    expect(find.text('FROM 0 CHECK-INS'), findsOneWidget);
    expect(find.textContaining('0 OF 3 UNLOCKED'), findsOneWidget);
    expect(find.textContaining('TO GO'), findsWidgets);
  });

  testWidgets('gallery distinguishes locked from unlocked', (tester) async {
    final controller = demoController();
    await controller.load();

    await pump(tester, BadgeGalleryScreen(controller: controller));

    expect(find.text('Badges'), findsOneWidget);
    // Explorer and Trailblazer are held, so exactly one progress bar is left.
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('detail shows the milestone and the tourist position',
      (tester) async {
    final controller = demoController();
    await controller.load();

    await pump(
      tester,
      BadgeDetailScreen(
        badge: BadgeCatalogue.penangWanderer,
        controller: controller,
      ),
    );

    expect(find.text('Penang Wanderer'), findsOneWidget);
    expect(find.text('LOCKED'), findsOneWidget);
    expect(find.text('50 km'), findsOneWidget); // milestone
    expect(find.text('12.4 km'), findsOneWidget); // your total
    expect(find.text('37.6 km to go'), findsOneWidget);
  });

  testWidgets('an unlocked badge shows its earned date, not progress',
      (tester) async {
    final controller = demoController();
    await controller.load();

    await pump(
      tester,
      BadgeDetailScreen(
        badge: BadgeCatalogue.explorer,
        controller: controller,
      ),
    );

    expect(find.text('EARNED 19 JUL 2026'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('simulating a check-in updates the dashboard live',
      (tester) async {
    await pump(tester, StatsDashboardScreen(controller: demoController()));

    // 2.1 km at 10 + 21 points takes the balance from 194 to 225.
    await tester.tap(find.text('SIMULATE A CHECK-IN'));
    await tester.pumpAndSettle();

    expect(find.text('225'), findsOneWidget);
    expect(find.textContaining('+31 points'), findsOneWidget);
  });

  testWidgets('repeat is disabled until there is a check-in to repeat',
      (tester) async {
    await pump(tester, StatsDashboardScreen(controller: demoController()));

    OutlinedButton repeatButton() => tester.widget<OutlinedButton>(
          find.ancestor(
            of: find.text('REPEAT LAST CHECK-IN'),
            matching: find.byType(OutlinedButton),
          ),
        );

    expect(repeatButton().onPressed, isNull);

    await tester.tap(find.text('SIMULATE A CHECK-IN'));
    await tester.pumpAndSettle();

    expect(repeatButton().onPressed, isNotNull);
  });

  testWidgets('repeating a check-in awards nothing a second time (T-R01.5)',
      (tester) async {
    await pump(tester, StatsDashboardScreen(controller: demoController()));

    await tester.tap(find.text('SIMULATE A CHECK-IN'));
    await tester.pumpAndSettle();
    expect(find.text('225'), findsOneWidget);

    // Let the first confirmation clear, then bring the repeat button into
    // view — it sits below the fold on a phone-sized screen.
    await tester.pump(const Duration(seconds: 4));
    await tester.ensureVisible(find.text('REPEAT LAST CHECK-IN'));
    await tester.pumpAndSettle();

    // The same checkInId again — the retry Module 4 would make after a
    // dropped response. The guard must leave the balance where it is.
    await tester.tap(find.text('REPEAT LAST CHECK-IN'));
    await tester.pumpAndSettle();

    expect(find.text('225'), findsOneWidget);
    expect(find.textContaining('already counted'), findsOneWidget);
    expect(find.text('FROM 8 CHECK-INS'), findsOneWidget);
  });
}
