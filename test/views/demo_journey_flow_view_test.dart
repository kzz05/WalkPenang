// Widget test for the interactive lecturer demo (US-W05).
//
// No Firebase.initializeApp() call happens anywhere in this test file — if
// DemoJourneyFlowView (or anything it builds) touched FirebaseAuth,
// FirebaseFirestore, or the real RewardController, this test would throw
// immediately rather than pass. A passing run is therefore itself proof the
// demo flow never reaches real Firestore or the real Reward Module, on top
// of fake_journey_dependencies.dart's fakes doing nothing real by design.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:walkpenang/debug/demo_journey_flow_view.dart';

void main() {
  testWidgets(
      'the demo flow reaches Journey Completed with a reward result, using '
      'only fake dependencies', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: DemoJourneyFlowView()),
    );
    await tester.pumpAndSettle();

    // Active Walking (Screen 03).
    expect(find.text('Complete Journey'), findsOneWidget);
    await tester.tap(find.text('Complete Journey'));
    await tester.pump();

    // Verify Location — checking (04a), then the fake's 2s delay resolves.
    expect(find.text('Checking your location…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Verify Location — verified (04b).
    expect(find.text("You're here!"), findsOneWidget);
    await tester.tap(find.text('Complete Journey'));
    await tester.pump();

    // Journey Completed — reward pending, then the fake's 800ms delay
    // resolves to a success outcome with a badge.
    expect(find.text('Calculating your reward…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(find.text('+15 WalkPoints'), findsOneWidget);
    expect(find.text('Explorer'), findsOneWidget);
  });
}
