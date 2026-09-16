// Bug 2 — a new route must never silently replace an active journey.
//
// The fault: MapPanel._openRouteSummary pushed RouteSummaryView the moment
// Route was tapped. A tourist walking to Chew Jetty who minimised the journey
// and tapped Route on Kek Lok Si lost the first walk without being asked —
// JourneySession.start() simply disposed the old controller underneath them.
//
// These tests drive the gate that now stands in front of that push. They call
// it the way the map does, from a real widget with a real Navigator, so the
// dialog it opens is the dialog the tourist sees.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:walkpenang/controllers/journey_completion_controller.dart';
import 'package:walkpenang/controllers/journey_session.dart';
import 'package:walkpenang/controllers/reward_service.dart';
import 'package:walkpenang/models/check_in_result.dart';
import 'package:walkpenang/models/walking_route_summary.dart';
import 'package:walkpenang/services/check_in_repository.dart';
import 'package:walkpenang/views/journey_flow_view.dart';
import 'package:walkpenang/views/widgets/journey_replacement_dialog.dart';
import '../support/fake_journey_dependencies.dart';

const _chewJettyId = 'test-chew-jetty';
const _kekLokSiId = 'test-kek-lok-si';

WalkingRouteSummary _summary({
  String destinationId = _chewJettyId,
  String destinationName = 'Chew Jetty',
}) =>
    WalkingRouteSummary(
      destinationName: destinationName,
      areaLabel: 'George Town Heritage Zone',
      distanceKm: 1.1,
      estimatedDuration: const Duration(minutes: 14),
      rewardPoints: 12,
      rewardBadgeLabel: 'progress towards your next badge',
      destinationId: destinationId,
      destinationLatitude: 5.4141,
      destinationLongitude: 100.3421,
    );

/// Counts every reward request, so "no points were awarded" can be asserted
/// as a number rather than inferred.
class _CountingRewardService implements RewardService {
  int callCount = 0;

  @override
  Future<RewardOutcome> onCheckInVerified(CheckInResult result) async {
    callCount++;
    return const RewardOutcome(pointsAwarded: 0);
  }
}

/// Keeps every check-in it is handed, so "nothing was saved" is likewise a
/// count and not an assumption.
class _RecordingCheckInRepository implements CheckInRepository {
  final List<CheckInResult> saved = [];
  int _counter = 0;

  @override
  String newCheckInId() => 'test-checkin-${_counter++}';

  @override
  Future<void> saveCheckIn(CheckInResult result) async => saved.add(result);
}

void main() {
  final session = JourneySession.instance;

  late _CountingRewardService rewards;
  late _RecordingCheckInRepository checkIns;

  setUp(() {
    rewards = _CountingRewardService();
    checkIns = _RecordingCheckInRepository();
  });

  JourneyCompletionController controllerFor(WalkingRouteSummary summary) =>
      JourneyCompletionController(
        routeSummary: summary,
        userId: 'tourist_001',
        rewardService: rewards,
        checkInRepository: checkIns,
        arrivalVerificationService: const FakeArrivalVerificationService(),
      );

  /// The app as main.dart assembles it — the gate reaches the journey screens
  /// through [JourneySession.navigatorKey], so the key has to be on the real
  /// navigator or "resume the current journey" has nowhere to push.
  ///
  /// [gateResults] collects what the gate returned on each tap of Route, which
  /// is what MapPanel uses to decide whether to push RouteSummaryView. A push
  /// that must not happen shows up here as a `false`.
  Widget app({
    required String destinationId,
    required List<bool> gateResults,
  }) =>
      MaterialApp(
        navigatorKey: JourneySession.navigatorKey,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  gateResults.add(
                    await confirmRouteOverActiveJourney(
                      context,
                      destinationId: destinationId,
                    ),
                  );
                },
                child: const Text('Route'),
              ),
            ),
          ),
        ),
      );

  /// A live journey keeps a one-second periodic timer running, and the tester
  /// fails any test that ends with a timer pending — so each test releases the
  /// session in its own body. The tearDown is only a backstop for a failure.
  Future<void> release(WidgetTester tester) async {
    session.abandon();
    await tester.pump();
  }

  tearDown(session.abandon);

  group('no journey running', () {
    testWidgets('Route opens normally, with nothing to ask about',
        (tester) async {
      final results = <bool>[];
      await tester.pumpWidget(
        app(destinationId: _kekLokSiId, gateResults: results),
      );

      await tester.tap(find.text('Route'));
      await tester.pumpAndSettle();

      expect(results, [true], reason: 'the route screen should be pushed');
      expect(find.text('Start a new journey?'), findsNothing);
      expect(session.isActive, isFalse);
    });
  });

  group('a different destination while a journey is running', () {
    testWidgets('asks before replacing it, naming the journey at risk',
        (tester) async {
      final results = <bool>[];
      await tester.pumpWidget(
        app(destinationId: _kekLokSiId, gateResults: results),
      );
      session.adopt(controllerFor(_summary()));
      session.minimize();
      await tester.pump();

      await tester.tap(find.text('Route'));
      await tester.pumpAndSettle();

      expect(find.text('Start a new journey?'), findsOneWidget);
      expect(
        find.textContaining('You already have an active journey to Chew Jetty'),
        findsOneWidget,
      );
      expect(find.textContaining('without awarding points'), findsOneWidget);
      expect(find.text('Keep Current Journey'), findsOneWidget);
      expect(find.text('End & Start New Journey'), findsOneWidget);
      // Still undecided: nothing may happen while the dialog is up.
      expect(results, isEmpty);

      await tester.tap(find.text('Keep Current Journey'));
      await tester.pumpAndSettle();
      await release(tester);
    });

    testWidgets('Keep Current Journey changes nothing and does not route',
        (tester) async {
      final results = <bool>[];
      await tester.pumpWidget(
        app(destinationId: _kekLokSiId, gateResults: results),
      );
      final journey = controllerFor(_summary());
      session.adopt(journey);
      session.minimize();
      await tester.pump();

      await tester.tap(find.text('Route'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep Current Journey'));
      await tester.pumpAndSettle();

      expect(results, [false], reason: 'the new route must not be pushed');
      expect(session.isActive, isTrue);
      expect(session.controller, same(journey),
          reason: 'the exact same controller, so KM covered, calories and '
              'elapsed time are all untouched');
      expect(journey.isCancelled, isFalse);
      expect(session.isMinimized, isTrue, reason: 'the mini bar stays');

      await release(tester);
    });

    testWidgets('End & Start New Journey clears the old one, then routes',
        (tester) async {
      final results = <bool>[];
      await tester.pumpWidget(
        app(destinationId: _kekLokSiId, gateResults: results),
      );
      final journey = controllerFor(_summary());
      session.adopt(journey);
      session.minimize();
      await tester.pump();

      await tester.tap(find.text('Route'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('End & Start New Journey'));
      await tester.pumpAndSettle();

      expect(results, [true]);
      // Cleared *before* the caller was told it may route, so the new route
      // never opens over a session still holding the old walk.
      expect(session.isActive, isFalse);
      expect(session.controller, isNull);
      expect(session.isMinimized, isFalse);
      expect(journey.isCancelled, isTrue,
          reason: 'cancelled, not merely disposed');
    });

    testWidgets('the abandoned journey is not completed, saved or rewarded',
        (tester) async {
      final results = <bool>[];
      var completedFired = 0;
      await tester.pumpWidget(
        app(destinationId: _kekLokSiId, gateResults: results),
      );
      final journey = controllerFor(_summary());
      session.adopt(journey, onJourneyCompleted: () => completedFired++);
      session.minimize();
      await tester.pump();

      await tester.tap(find.text('Route'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('End & Start New Journey'));
      await tester.pumpAndSettle();

      expect(checkIns.saved, isEmpty, reason: 'no check-in for a walk given up');
      expect(rewards.callCount, 0, reason: 'no points, no badge progress');
      expect(completedFired, 0,
          reason: 'the old destination must not be marked as reached');
      expect(journey.isCompleted, isFalse);
    });
  });

  group('the destination already being walked to', () {
    testWidgets('never warns and never starts a second journey to it',
        (tester) async {
      final results = <bool>[];
      await tester.pumpWidget(
        app(destinationId: _chewJettyId, gateResults: results),
      );
      final journey = controllerFor(_summary());
      session.adopt(journey);
      session.minimize();
      await tester.pump();

      await tester.tap(find.text('Route'));
      await tester.pumpAndSettle();

      expect(find.text('Start a new journey?'), findsNothing,
          reason: 'nothing is being replaced, so there is nothing to warn '
              'about');
      expect(results, [false], reason: 'no duplicate route screen');
      expect(session.isActive, isTrue);
      expect(session.controller, same(journey));
      expect(journey.isCancelled, isFalse);

      // Resumed rather than restarted: the same journey comes back on screen,
      // exactly as tapping the mini bar does.
      expect(find.byType(JourneyFlowView), findsOneWidget);
      expect(session.isMinimized, isFalse);
      // Active Walking upper-cases the destination through WpMonoLabel.
      expect(find.textContaining('CHEW JETTY'), findsWidgets);

      await release(tester);
    });
  });
}
