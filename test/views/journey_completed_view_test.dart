// Widget tests for JourneyCompletedView (Figma "05 · Journey Completed").
//
// Presentation only — no RewardService calls, no Firestore. Every case pumps
// the view directly against an in-memory JourneyCompletedUiData, and the
// reward card is driven entirely by an injected JourneyRewardUiState.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:walkpenang/models/journey_completed_ui_data.dart';
import 'package:walkpenang/models/journey_reward_ui_state.dart';
import 'package:walkpenang/views/journey_completed_view.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(MaterialApp(home: child));
}

const _destination = 'Fort Cornwallis';
const _area = 'George Town Heritage Zone';

void main() {
  testWidgets(
      'default reward state (constructor default) is unavailable with no fabricated values',
      (tester) async {
    await _pump(
      tester,
      const JourneyCompletedView(
        data: JourneyCompletedUiData(
          destinationName: _destination,
          destinationAreaLabel: _area,
          completedDistanceKm: 2.4,
          journeyDuration: Duration(minutes: 33, seconds: 12),
          carbonSavedKg: 0.50,
          caloriesBurned: 140,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rewards unavailable'), findsOneWidget);
    expect(find.textContaining('WalkPoints'), findsNothing);
    expect(find.text('Heritage Badge Earned'), findsNothing);
    expect(find.text('+15 WALKPOINTS'), findsNothing);
    expect(find.text('NEW'), findsNothing);
  });

  testWidgets('pending reward shows a loading state, no numbers',
      (tester) async {
    await _pump(
      tester,
      const JourneyCompletedView(
        data: JourneyCompletedUiData(
          destinationName: _destination,
          destinationAreaLabel: _area,
          reward: JourneyRewardUiState.pending(),
        ),
      ),
    );
    // Indeterminate spinner in the pending card — pump, don't settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Calculating your reward…'), findsOneWidget);
    expect(find.textContaining('WalkPoints'), findsNothing);
  });

  testWidgets(
      'success with an injected badge shows the injected points and badge name',
      (tester) async {
    await _pump(
      tester,
      const JourneyCompletedView(
        data: JourneyCompletedUiData(
          destinationName: _destination,
          destinationAreaLabel: _area,
          reward: JourneyRewardUiState.success(
            pointsAwarded: 15,
            newlyEarnedBadgeNames: ['Explorer'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('+15 WalkPoints'), findsOneWidget);
    expect(find.text('Explorer'), findsOneWidget);
    expect(find.text('NEW'), findsOneWidget);
    // The real badge system's own copy must never appear from this UI layer.
    expect(find.text('Heritage Badge Earned'), findsNothing);
  });

  testWidgets(
      'success with no newly earned badge shows points but no badge section',
      (tester) async {
    await _pump(
      tester,
      const JourneyCompletedView(
        data: JourneyCompletedUiData(
          destinationName: _destination,
          destinationAreaLabel: _area,
          reward: JourneyRewardUiState.success(pointsAwarded: 13),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('+13 WalkPoints'), findsOneWidget);
    expect(find.text('NEW'), findsNothing);
  });

  testWidgets('alreadyAwarded success is not presented as newly earned',
      (tester) async {
    await _pump(
      tester,
      const JourneyCompletedView(
        data: JourneyCompletedUiData(
          destinationName: _destination,
          destinationAreaLabel: _area,
          reward: JourneyRewardUiState.success(
            pointsAwarded: 13,
            alreadyAwarded: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reward already recorded'), findsOneWidget);
    expect(find.text('+13 WalkPoints'), findsNothing);
    expect(find.text('NEW'), findsNothing);
  });

  testWidgets(
      'error state shows the injected message and retry callback, no fabricated values',
      (tester) async {
    var retried = false;
    await _pump(
      tester,
      JourneyCompletedView(
        data: const JourneyCompletedUiData(
          destinationName: _destination,
          destinationAreaLabel: _area,
          reward:
              JourneyRewardUiState.error('Could not reach the reward service.'),
        ),
        onRetryReward: () => retried = true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not reach the reward service.'), findsOneWidget);
    expect(find.textContaining('WalkPoints'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(retried, isTrue);
  });

  testWidgets('unavailable state contains no fabricated reward values',
      (tester) async {
    await _pump(
      tester,
      const JourneyCompletedView(
        data: JourneyCompletedUiData(
          destinationName: _destination,
          destinationAreaLabel: _area,
          reward: JourneyRewardUiState.unavailable(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('WalkPoints'), findsNothing);
    expect(find.textContaining('Heritage'), findsNothing);
    expect(find.text('NEW'), findsNothing);
  });

  testWidgets(
      'nullable completed distance renders as an honest placeholder, not planned distance',
      (tester) async {
    await _pump(
      tester,
      const JourneyCompletedView(
        data: JourneyCompletedUiData(
          destinationName: _destination,
          destinationAreaLabel: _area,
          // completedDistanceKm intentionally omitted.
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('KM WALKED'), findsOneWidget);
    expect(find.text('—'), findsWidgets);
  });

  testWidgets('does not overflow at a narrow common Android width',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(
      tester,
      const JourneyCompletedView(
        data: JourneyCompletedUiData(
          destinationName: _destination,
          destinationAreaLabel: _area,
          completedDistanceKm: 2.4,
          journeyDuration: Duration(minutes: 33, seconds: 12),
          carbonSavedKg: 0.50,
          caloriesBurned: 140,
          reward: JourneyRewardUiState.success(
            pointsAwarded: 15,
            newlyEarnedBadgeNames: ['Explorer', 'Trailblazer'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
