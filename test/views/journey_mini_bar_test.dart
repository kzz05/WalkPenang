// Regression cover for the red screen a minimised journey used to produce.
//
// The bar is mounted by MaterialApp.builder, which is *above* the Navigator:
// its context therefore has no Overlay and no Navigator over it. The end
// button carried a tooltip and opened its dialog with its own context, so the
// first frame the bar drew threw "No Overlay widget found. RawTooltip widgets
// require an Overlay" and took the whole app down with it.
//
// The unit tests for JourneySession could not have caught this — the fault was
// entirely in where the widget is mounted. So this pumps it the way main.dart
// does, builder and all.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:walkpenang/controllers/journey_completion_controller.dart';
import 'package:walkpenang/controllers/journey_session.dart';
import 'package:walkpenang/models/walking_route_summary.dart';
import 'package:walkpenang/views/widgets/journey_mini_bar.dart';
import '../support/fake_journey_dependencies.dart';

const _summary = WalkingRouteSummary(
  destinationName: 'Chew Jetty',
  areaLabel: 'George Town Heritage Zone',
  distanceKm: 1.1,
  estimatedDuration: Duration(minutes: 14),
  rewardPoints: 12,
  rewardBadgeLabel: 'progress towards your next badge',
  destinationId: 'test-chew-jetty',
  destinationLatitude: 5.4141,
  destinationLongitude: 100.3421,
);

JourneyCompletionController _journey() => JourneyCompletionController(
      routeSummary: _summary,
      userId: 'tourist_001',
      rewardService: FakeRewardService(),
      checkInRepository: NoopCheckInRepository(),
      arrivalVerificationService: const FakeArrivalVerificationService(),
    );

/// The app exactly as main.dart assembles it: the bar above the navigator.
Widget _app() => MaterialApp(
      navigatorKey: JourneySession.navigatorKey,
      builder: (context, child) => JourneyOverlayHost(child: child!),
      home: const Scaffold(body: Center(child: Text('Home'))),
    );

void main() {
  final session = JourneySession.instance;

  /// A live journey keeps a one-second Timer.periodic running, and the widget
  /// tester fails a test that ends with a timer still pending — so every test
  /// releases the session inside its own body, not from a tearDown, which runs
  /// after that check. The tearDown is only a backstop for a failed test.
  Future<void> release(WidgetTester tester) async {
    session.end();
    await tester.pump();
  }

  tearDown(session.end);

  testWidgets('a minimised journey draws its bar without an Overlay above it',
      (tester) async {
    await tester.pumpWidget(_app());
    session.adopt(_journey());
    session.minimize();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Chew Jetty'), findsOneWidget);
    // Still the app underneath — the bar shrinks the routes rather than
    // covering them.
    expect(find.text('Home'), findsOneWidget);

    await release(tester);
  });

  testWidgets('the bar is not drawn while the journey is on screen',
      (tester) async {
    await tester.pumpWidget(_app());
    session.adopt(_journey());
    await tester.pump();

    expect(find.textContaining('Chew Jetty'), findsNothing);

    await release(tester);
  });

  testWidgets('ending from the bar opens its confirmation and keeps the '
      'journey when answered No', (tester) async {
    await tester.pumpWidget(_app());
    session.adopt(_journey());
    session.minimize();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // showDialog needs a Navigator, which the bar's own context does not have
    // either — same fault, one tap further along.
    expect(tester.takeException(), isNull);
    expect(find.text('End Journey?'), findsOneWidget);

    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();

    expect(session.isActive, isTrue);

    await release(tester);
  });

  testWidgets('answering Yes ends the journey and takes the bar with it',
      (tester) async {
    await tester.pumpWidget(_app());
    session.adopt(_journey());
    session.minimize();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, End Journey'));
    await tester.pumpAndSettle();

    expect(session.isActive, isFalse);
    expect(find.textContaining('Chew Jetty'), findsNothing);
  });
}
