// Widget tests for the "View Journey" action on Journey Completed (UC-W05).
//
// "View Journey" used to open the statistics dashboard — the general rewards
// screen, which is not this journey. It now opens JournalDetailScreen for the
// exact journey that was just completed, which is the same screen
// WalkingJournalScreen opens for a historical entry.
//
// Driven through DemoJourneyFlowView, which builds the real ActiveWalkingView,
// VerifyLocationView and JourneyCompletedView over a real
// JourneyCompletionController and mirrors JourneyFlowView's navigation. As in
// demo_journey_flow_view_test.dart, no Firebase.initializeApp() call happens
// here: a passing run is itself proof this path never reaches real Firestore
// or the real Reward Module.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:walkpenang/views/reward/journal_detail_screen.dart';
import 'package:walkpenang/views/reward/stats_dashboard_screen.dart';
import 'package:walkpenang/views/widgets/wp_components.dart';

import '../support/demo_journey_flow_view.dart';

/// Taps a footer action on the Journey Completed screen.
///
/// The screen scrolls when its content is taller than the viewport, which it
/// is at the default 800x600 test surface, so the footer has to be brought
/// into view before it can be tapped.
Future<void> _tapFooterAction(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Taps the detail screen's own drawn back control — the gesture a tourist
/// actually makes. Not pageBack(), which looks for a Material BackButton that
/// this screen (like every other WalkPenang screen) does not use.
Future<void> _backOutOfDetail(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(JournalDetailScreen),
      matching: find.byType(WpBackButton),
    ),
  );
  await tester.pumpAndSettle();
}

/// Walks the flow from Active Walking to a completed journey with its reward
/// resolved, so each test starts on the Journey Completed screen.
Future<void> _completeJourney(WidgetTester tester) async {
  await tester.tap(find.text('Complete Journey'));
  await tester.pump();

  // The fake arrival service's 2s delay, then the verified card.
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Complete Journey'));
  await tester.pump();

  // The fake reward service's 800ms delay.
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('View Journey opens the detail page for the completed journey',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DemoJourneyFlowView()));
    await tester.pumpAndSettle();
    await _completeJourney(tester);

    expect(find.text('+15 WalkPoints'), findsOneWidget);

    await _tapFooterAction(tester, 'View Journey');

    // The shared detail screen, not a second journey-detail UI.
    expect(find.byType(JournalDetailScreen), findsOneWidget);
    // Emphatically not the general rewards dashboard it used to open.
    expect(find.byType(StatsDashboardScreen), findsNothing);
  });

  testWidgets('the detail page shows this journey, not a generic summary',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DemoJourneyFlowView()));
    await tester.pumpAndSettle();
    await _completeJourney(tester);

    await _tapFooterAction(tester, 'View Journey');

    final detail = tester.widget<JournalDetailScreen>(
      find.byType(JournalDetailScreen),
    );

    // demoRouteSummary's destination, walked just now, with the points the
    // fake reward service actually awarded for it.
    expect(detail.entry.destinationName, 'Fort Cornwallis');
    expect(detail.entry.destinationId, 'demo-fort-cornwallis');
    expect(detail.entry.pointsAwarded, 15);
    expect(find.text('Fort Cornwallis'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('it opens the check-in that was created, by its own ID',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DemoJourneyFlowView()));
    await tester.pumpAndSettle();
    await _completeJourney(tester);

    await _tapFooterAction(tester, 'View Journey');

    final detail = tester.widget<JournalDetailScreen>(
      find.byType(JournalDetailScreen),
    );

    // NoopCheckInRepository mints 'demo-checkin-0' for the first — and, since
    // nothing here creates a second, only — check-in of this journey. A
    // duplicate save or a re-award would have had to mint another ID.
    expect(detail.entry.checkInId, 'demo-checkin-0');
  });

  testWidgets('opening it again reopens the same journey record',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DemoJourneyFlowView()));
    await tester.pumpAndSettle();
    await _completeJourney(tester);

    await _tapFooterAction(tester, 'View Journey');
    final first = tester
        .widget<JournalDetailScreen>(find.byType(JournalDetailScreen))
        .entry;

    await _backOutOfDetail(tester);

    await _tapFooterAction(tester, 'View Journey');
    final second = tester
        .widget<JournalDetailScreen>(find.byType(JournalDetailScreen))
        .entry;

    // Same journey, same identity, same award — opening the detail screen
    // neither writes a new check-in nor earns anything a second time.
    expect(second.checkInId, first.checkInId);
    expect(second.pointsAwarded, first.pointsAwarded);
    expect(second.checkInTime, first.checkInTime);
  });

  testWidgets('back from the detail page returns to Journey Completed',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DemoJourneyFlowView()));
    await tester.pumpAndSettle();
    await _completeJourney(tester);

    await _tapFooterAction(tester, 'View Journey');
    expect(find.byType(JournalDetailScreen), findsOneWidget);

    await _backOutOfDetail(tester);

    // Back on the completed screen, with the journey's result intact and the
    // action still offered.
    expect(find.byType(JournalDetailScreen), findsNothing);
    expect(find.text('JOURNEY COMPLETE'), findsOneWidget);
    expect(find.text('+15 WalkPoints'), findsOneWidget);
    expect(find.text('Back to Explore'), findsOneWidget);
    expect(find.text('View Journey'), findsOneWidget);
  });

  testWidgets('Back to Explore still leaves the journey flow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DemoJourneyFlowView()),
              ),
              child: const Text('start'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();
    await _completeJourney(tester);

    await _tapFooterAction(tester, 'Back to Explore');

    // Unchanged: the journey flow is popped and the tourist is back where
    // they started, with no detail page anywhere on the stack.
    expect(find.text('start'), findsOneWidget);
    expect(find.text('JOURNEY COMPLETE'), findsNothing);
    expect(find.byType(JournalDetailScreen), findsNothing);
  });

  testWidgets('View Journey is inert when the journey has no record',
      (tester) async {
    // A signed-out tourist: no check-in is created, so there is no journey to
    // open. The action must not fall back to the rewards dashboard.
    await tester.pumpWidget(
      const MaterialApp(home: DemoJourneyFlowView(userId: '')),
    );
    await tester.pumpAndSettle();
    await _completeJourney(tester);

    expect(
      find.text('Sign in to record points and badges for this journey.'),
      findsOneWidget,
    );

    await _tapFooterAction(tester, 'View Journey');

    expect(find.byType(JournalDetailScreen), findsNothing);
    expect(find.byType(StatsDashboardScreen), findsNothing);
    expect(find.text('JOURNEY COMPLETE'), findsOneWidget);
  });
}
