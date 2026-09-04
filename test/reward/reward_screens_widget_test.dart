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
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkpenang/controllers/reward_controller.dart';
import 'package:walkpenang/dao/in_memory_reward_data.dart';
import 'package:walkpenang/models/badge_model.dart';
import 'package:walkpenang/views/reward/badge_detail_screen.dart';
import 'package:walkpenang/views/reward/badge_gallery_screen.dart';
import 'package:walkpenang/views/reward/stats_dashboard_screen.dart';
import 'package:walkpenang/widgets/reward/badge_card.dart';
import 'package:walkpenang/widgets/reward/badge_emblem.dart';
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

Future<void> pump(
  WidgetTester tester,
  Widget screen, {
  // Samsung phones ship with the system font scaled above 1.0 out of the box,
  // so a tile that only fits at 1.0 is broken on a real device.
  double textScale = 1.0,
}) async {
  // A representative phone. Fixing the size makes an overflow deterministic
  // rather than dependent on the default 800x600 test window.
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Scrolls a demo control into view and returns its finder.
///
/// The demo buttons sit at the bottom of the dashboard's scrolling list,
/// below the fold on a phone-sized screen — and a list child that has not
/// been scrolled to has not been built, so it cannot be found, let alone
/// tapped. Every test that drives one has to scroll to it first.
Future<Finder> revealControl(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.scrollUntilVisible(finder, 200);
  await tester.pumpAndSettle();
  return finder;
}

void main() {
  testWidgets('dashboard shows the totals and the badge set', (tester) async {
    await pump(tester, StatsDashboardScreen(controller: demoController()));

    expect(find.text('Rewards'), findsOneWidget);
    expect(find.text('194'), findsOneWidget); // total points
    expect(find.text('12.4'), findsOneWidget); // distance in km
    // Derived from the catalogue rather than typed in, so adding a badge
    // does not fail this test for the wrong reason.
    expect(
      find.textContaining('3 OF ${BadgeCatalogue.all.length} UNLOCKED'),
      findsOneWidget,
    );

    // Demo data must always be labelled as such on screen.
    expect(find.text('DEMO DATA'), findsOneWidget);

    for (final badge in BadgeCatalogue.all) {
      expect(find.text(badge.name), findsWidgets, reason: badge.name);
    }
  });

  // The strip once divided a single Row between every badge in the catalogue,
  // which left each emblem roughly 1dp wide. SizedBox enforces a constraint
  // that tight rather than overflowing, so no RenderFlex error was thrown and
  // the test above still passed while the artwork rendered as a sliver. This
  // asserts the geometry those tests cannot see.
  testWidgets('dashboard badge emblems keep their size and aspect',
      (tester) async {
    await pump(tester, StatsDashboardScreen(controller: demoController()));

    final emblems = find.descendant(
      of: find.byType(BadgeCard),
      matching: find.byType(BadgeEmblem),
    );
    expect(emblems, findsWidgets);

    for (var i = 0; i < tester.widgetList(emblems).length; i++) {
      final size = tester.getSize(emblems.at(i));
      expect(
        size.width,
        greaterThan(60),
        reason: 'emblem $i is squeezed: $size',
      );
      // The artwork is authored in a 120 x 140 box; anything else means it
      // was scaled per-axis instead of letterboxed.
      expect(
        size.width / size.height,
        closeTo(120 / 140, 0.01),
        reason: 'emblem $i is distorted: $size',
      );
    }
  });

  // "2.61" ellipsised to "2…" reads as a different number rather than as
  // truncated text, so a stat tile must never clip its value. Three tiles
  // across a phone is tight at a 1.0 font scale and tighter above it, which
  // is where this last broke.
  testWidgets('stat tile values are never clipped, even at a large font scale',
      (tester) async {
    for (final scale in [1.0, 1.3]) {
      await pump(
        tester,
        StatsDashboardScreen(controller: demoController()),
        textScale: scale,
      );

      // The demo totals: 12.4 km, 2.61 kg saved, 744 kcal.
      for (final value in ['12.4', '2.61', '744']) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.byType(StatSummaryCard),
            matching: find.text(value),
          ),
        );
        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason: '$value is clipped at a ${scale}x font scale',
        );
      }
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
    expect(
      find.textContaining('0 OF ${BadgeCatalogue.all.length} UNLOCKED'),
      findsOneWidget,
    );
    expect(find.textContaining('TO GO'), findsWidgets);
  });

  testWidgets('gallery distinguishes locked from unlocked', (tester) async {
    final controller = demoController();
    await controller.load();

    await pump(tester, BadgeGalleryScreen(controller: controller));

    expect(find.text('Badges'), findsOneWidget);

    // Every locked tile carries a progress bar and no unlocked tile does,
    // which is one of the three signals FR-R05 uses to tell them apart.
    //
    // Counted against the tiles the grid actually built rather than against
    // the catalogue: the gallery scrolls, so off-screen tiles do not exist
    // yet and a hard-coded total would fail as the catalogue grows.
    final tiles = tester.widgetList<BadgeCard>(find.byType(BadgeCard));
    final lockedOnScreen = tiles.where((tile) => !tile.unlocked).length;

    expect(tiles, isNotEmpty);
    expect(lockedOnScreen, greaterThan(0));
    expect(
      find.byType(LinearProgressIndicator),
      findsNWidgets(lockedOnScreen),
    );
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
    await tester.tap(await revealControl(tester, 'SIMULATE A CHECK-IN'));
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

    await revealControl(tester, 'REPEAT LAST CHECK-IN');
    expect(repeatButton().onPressed, isNull);

    await tester.tap(await revealControl(tester, 'SIMULATE A CHECK-IN'));
    await tester.pumpAndSettle();

    await revealControl(tester, 'REPEAT LAST CHECK-IN');
    expect(repeatButton().onPressed, isNotNull);
  });

  testWidgets('repeating a check-in awards nothing a second time (T-R01.5)',
      (tester) async {
    await pump(tester, StatsDashboardScreen(controller: demoController()));

    await tester.tap(await revealControl(tester, 'SIMULATE A CHECK-IN'));
    await tester.pumpAndSettle();
    expect(find.text('225'), findsOneWidget);

    // Let the first confirmation clear, then bring the repeat button into
    // view — it sits below the fold on a phone-sized screen.
    await tester.pump(const Duration(seconds: 4));
    await revealControl(tester, 'REPEAT LAST CHECK-IN');

    // The same checkInId again — the retry Module 4 would make after a
    // dropped response. The guard must leave the balance where it is.
    await tester.tap(find.text('REPEAT LAST CHECK-IN'));
    await tester.pumpAndSettle();

    expect(find.text('225'), findsOneWidget);
    expect(find.textContaining('already counted'), findsOneWidget);
    expect(find.text('FROM 8 CHECK-INS'), findsOneWidget);
  });
}
