// Widget tests for ActiveWalkingView (Figma "03 · Active Walking Journey").
//
// Presentation only — no GPS, no Firestore, no real timers. Every case pumps
// the view directly against an in-memory ActiveWalkingUiData.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:walkpenang/models/active_walking_ui_data.dart';
import 'package:walkpenang/views/active_walking_view.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(MaterialApp(home: child));
}

void main() {
  testWidgets('normal state shows destination, elapsed time and live stats',
      (tester) async {
    await _pump(
      tester,
      const ActiveWalkingView(
        data: ActiveWalkingUiData(
          destinationName: 'Fort Cornwallis',
          elapsedTime: Duration(minutes: 14, seconds: 32),
          plannedDistanceKm: 2.4,
          kmCovered: 1.1,
          minutesRemaining: 18,
          carbonSavedKg: 0.23,
          caloriesBurned: 64,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The destination caption renders through WpMonoLabel, which uppercases
    // its text (matching the Figma "FORT CORNWALLIS" mono caption style).
    expect(find.text('FORT CORNWALLIS'), findsOneWidget);
    expect(find.text('00:14:32'), findsOneWidget);
    expect(find.text('1.1'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
    expect(find.text('0.23'), findsOneWidget);
    expect(find.text('64'), findsOneWidget);
    expect(find.text('Open Navigation'), findsOneWidget);
    expect(find.text('Complete Journey'), findsOneWidget);
  });

  testWidgets('live data unavailable renders honest placeholders, not zeros',
      (tester) async {
    await _pump(
      tester,
      const ActiveWalkingView(
        data: ActiveWalkingUiData(
          destinationName: 'Fort Cornwallis',
          elapsedTime: Duration(minutes: 3, seconds: 5),
          plannedDistanceKm: 2.4,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // KM COVERED / MIN REMAINING / CO2 / KCAL all null -> four "—" tiles.
    expect(find.text('—'), findsNWidgets(4));
    expect(find.text('0.0'), findsNothing);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('Complete Journey shows a loading state and disables actions',
      (tester) async {
    var completeTapped = false;
    await _pump(
      tester,
      ActiveWalkingView(
        data: const ActiveWalkingUiData(
          destinationName: 'Fort Cornwallis',
          elapsedTime: Duration(minutes: 32),
          plannedDistanceKm: 2.4,
          kmCovered: 2.4,
          isCompleting: true,
        ),
        onCompleteJourney: () => completeTapped = true,
        onOpenNavigation: () {},
      ),
    );
    // isCompleting shows an indeterminate CircularProgressIndicator — pump a
    // few frames rather than pumpAndSettle, which would never settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Complete Journey'), findsNothing);

    await tester.tap(find.text('Open Navigation'), warnIfMissed: false);
    await tester.pump();
    expect(completeTapped, isFalse);
  });

  testWidgets('does not overflow at a narrow common Android width',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(
      tester,
      const ActiveWalkingView(
        data: ActiveWalkingUiData(
          destinationName: 'Fort Cornwallis',
          elapsedTime: Duration(minutes: 14, seconds: 32),
          plannedDistanceKm: 2.4,
          kmCovered: 1.1,
          minutesRemaining: 18,
          carbonSavedKg: 0.23,
          caloriesBurned: 64,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
