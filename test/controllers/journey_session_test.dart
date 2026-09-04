// Walking & Carbon Module — the app-wide journey handle.
//
// JourneySession is what lets a journey be minimised: it owns the controller
// so JourneyFlowView's route can be popped and re-pushed underneath it. These
// tests cover the ownership rules, which is the part that can silently go
// wrong — a session left active after a journey ends would leave the mini bar
// advertising a walk that is over, and a controller dropped without disposal
// would leave its elapsed timer and position stream running forever.
//
// start() is not exercised here: it reaches for FirebaseAuth and Firestore to
// build the real journey. adopt() is the seam for a controller built from
// fakes, which is what the tests below hand it.

import 'package:flutter_test/flutter_test.dart';

import 'package:walkpenang/controllers/journey_completion_controller.dart';
import 'package:walkpenang/controllers/journey_session.dart';
import 'package:walkpenang/models/walking_route_summary.dart';
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

JourneyCompletionController _controller() => JourneyCompletionController(
      routeSummary: _summary,
      userId: 'tourist_001',
      rewardService: FakeRewardService(),
      checkInRepository: NoopCheckInRepository(),
      arrivalVerificationService: FakeArrivalVerificationService(),
    );

void main() {
  // minimize() reaches for the app's navigator through a GlobalKey, and
  // GlobalKey.currentState needs a binding even when — as here — there is no
  // navigator for it to find.
  TestWidgetsFlutterBinding.ensureInitialized();

  final session = JourneySession.instance;

  // A singleton outlives one test, so every test leaves it empty for the next.
  tearDown(session.end);

  test('no journey until one is adopted', () {
    expect(session.isActive, isFalse);
    expect(session.controller, isNull);
    expect(session.isMinimized, isFalse);
  });

  test('minimize and markExpanded move the bar in and out of view', () {
    session.adopt(_controller());

    expect(session.isMinimized, isFalse, reason: 'starts on its own screen');

    session.minimize();
    expect(session.isMinimized, isTrue);
    expect(session.isActive, isTrue, reason: 'minimised is still walking');

    // What JourneyFlowView calls as it mounts, so the bar and the journey
    // screen can never both be showing the same journey.
    session.markExpanded();
    expect(session.isMinimized, isFalse);
  });

  test('end releases the journey and disposes its controller', () {
    final controller = _controller();
    session.adopt(controller);

    session.end();

    expect(session.isActive, isFalse);
    expect(session.controller, isNull);
    // Disposed: a ChangeNotifier that has been disposed throws when anything
    // tries to listen to it again. Without this the elapsed timer and the
    // position stream would outlive the journey.
    expect(() => controller.addListener(() {}), throwsFlutterError);
  });

  test('end is safe to call twice — the completed screen and the mini bar '
      'can both reach it', () {
    session.adopt(_controller());

    session.end();

    expect(session.end, returnsNormally);
    expect(session.isActive, isFalse);
  });

  test('adopting a second journey disposes the first', () {
    final first = _controller();
    session.adopt(first);

    final second = _controller();
    session.adopt(second);

    expect(session.controller, same(second));
    expect(() => first.addListener(() {}), throwsFlutterError);
  });

  test('minimize on an empty session does nothing', () {
    session.minimize();

    expect(session.isMinimized, isFalse);
    expect(session.isActive, isFalse);
  });
}
