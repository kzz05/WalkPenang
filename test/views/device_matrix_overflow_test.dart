// Every journey-flow screen, swept across the phones and font sizes the app
// has to survive on (NFR-06: Android 8.0 and above, any device).
//
// The individual view tests each check one screen at 360x640 and the default
// font size. That is the middle of the range, and the overflows this project
// has actually shipped were all found in a corner of it: the Journey Preview
// hero at the largest system font, the stat tiles at 2.0x, the badge strip
// once the catalogue grew. Samsung phones ship above 1.0x out of the box, so
// the default scale is not where a real device sits.
//
// 2.0x is Android's accessibility range rather than its normal one. Text is
// allowed to wrap and cards are allowed to grow there — what is never allowed
// is a RenderFlex that overflows, because that is a black-and-yellow stripe
// across a screen the tourist is trying to use.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:walkpenang/controllers/journey_completion_controller.dart';
import 'package:walkpenang/controllers/journey_session.dart';
import 'package:walkpenang/controllers/walking_controller.dart';
import 'package:walkpenang/models/active_walking_ui_data.dart';
import 'package:walkpenang/models/journey_completed_ui_data.dart';
import 'package:walkpenang/models/journey_reward_ui_state.dart';
import 'package:walkpenang/models/place_model.dart';
import 'package:walkpenang/models/route_result.dart';
import 'package:walkpenang/models/route_step.dart';
import 'package:walkpenang/models/transit_details.dart';
import 'package:walkpenang/models/transport_mode.dart';
import 'package:walkpenang/models/user_profile.dart';
import 'package:walkpenang/models/verify_location_ui_data.dart';
import 'package:walkpenang/models/walking_route_summary.dart';
import 'package:walkpenang/views/active_walking_view.dart';
import 'package:walkpenang/views/journey_completed_view.dart';
import 'package:walkpenang/views/navigation_view.dart';
import 'package:walkpenang/views/pre_walk_summary_view.dart';
import 'package:walkpenang/views/verify_location_view.dart';
import 'package:walkpenang/views/widgets/journey_mini_bar.dart';
import '../support/fake_journey_dependencies.dart';

/// The longest destination name in the seeded data, which is what found the
/// Journey Preview overflow on an SM-A176B. A screen that survives this
/// survives the Places API's real output.
const _longName = 'Cheong Fatt Tze - The Blue Mansion';
const _longArea = 'George Town UNESCO World Heritage Site, Penang';

/// 320 is the narrowest Android width still worth supporting; 412 a large
/// modern phone. 1.6 is Android's largest non-accessibility font setting, 2.0
/// reaches into the accessibility range.
const _sizes = <Size>[Size(320, 640), Size(360, 800), Size(412, 915)];
const _scales = <double>[1.0, 1.3, 1.6, 2.0];

const _activeData = ActiveWalkingUiData(
  destinationName: _longName,
  elapsedTime: Duration(hours: 1, minutes: 14, seconds: 32),
  plannedDistanceKm: 12.4,
  kmCovered: 11.1,
  minutesRemaining: 118,
  carbonSavedKg: 2.23,
  caloriesBurned: 640,
);

UserProfile _profile() => UserProfile(
      nickname: 'Tourist',
      weightKg: 65,
      heightCm: 170,
      units: 'metric',
    );

const _summary = WalkingRouteSummary(
  destinationName: _longName,
  areaLabel: _longArea,
  distanceKm: 12.4,
  estimatedDuration: Duration(hours: 2, minutes: 34),
  rewardPoints: 148,
  rewardBadgeLabel: 'progress towards your next badge',
  destinationId: 'test-blue-mansion',
  destinationLatitude: 5.4213,
  destinationLongitude: 100.3352,
);

final _destination = PlaceModel(
  placeId: 'test-blue-mansion',
  name: _longName,
  category: 'attraction',
  latitude: 5.4213,
  longitude: 100.3352,
  address: _longArea,
);

/// A transit route, because a TRANSIT step's banner carries the most text on
/// any navigation screen: the line, both stop names and the stop count.
RouteResult _transitRoute() => RouteResult(
      distanceKm: 12.4,
      durationMinutes: 154,
      polylinePoints: const [LatLng(5.4141, 100.3288), LatLng(5.4213, 100.3352)],
      steps: [
        RouteStep(
          instruction: 'Walk to Pengkalan Weld / Jetty bus terminal',
          maneuver: 'turn-right',
          distanceMeters: 320,
          durationSeconds: 260,
          startLocation: const LatLng(5.4141, 100.3288),
          endLocation: const LatLng(5.4160, 100.3300),
          polylinePoints: const [LatLng(5.4141, 100.3288)],
        ),
        RouteStep(
          instruction: 'Bus towards Balik Pulau',
          maneuver: '',
          distanceMeters: 11800,
          durationSeconds: 8400,
          startLocation: const LatLng(5.4160, 100.3300),
          endLocation: const LatLng(5.4213, 100.3352),
          polylinePoints: const [LatLng(5.4160, 100.3300)],
          travelMode: 'TRANSIT',
          transitDetails: TransitDetails(
            lineName: 'Rapid Penang 502 — Weld Quay to Balik Pulau',
            vehicleType: 'BUS',
            headsign: 'Balik Pulau',
            departureStopName: 'Pengkalan Weld (Jetty Bus Terminal)',
            arrivalStopName: 'Cheong Fatt Tze - The Blue Mansion',
            numStops: 14,
            departureTimeText: '3:45 pm',
            arrivalTimeText: '4:58 pm',
          ),
        ),
      ],
    );

JourneyCompletionController _journey() => JourneyCompletionController(
      routeSummary: _summary,
      userId: 'tourist_001',
      rewardService: FakeRewardService(),
      checkInRepository: NoopCheckInRepository(),
      arrivalVerificationService: const FakeArrivalVerificationService(),
    );

/// Pumps [build] at every size/scale and fails with the widget and line of any
/// RenderFlex that overflowed.
void sweep(String description, Widget Function() build) {
  for (final size in _sizes) {
    for (final scale in _scales) {
      final label = '${size.width.toInt()}dp @${scale}x';

      testWidgets('$description does not overflow at $label', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final overflows = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (details) {
          final dump = details.toString();
          if (!dump.contains('overflowed')) {
            previous?.call(details);
            return;
          }
          final where = dump
              .split('\n')
              .firstWhere((line) => line.contains('.dart:'), orElse: () => '?');
          overflows.add('${details.exceptionAsString().split('\n').first}  @ '
              '${where.trim()}');
        };

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: MaterialApp(home: build()),
          ),
        );
        // Indeterminate spinners never settle, so pump in steps instead.
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }

        FlutterError.onError = previous;
        expect(overflows, isEmpty, reason: overflows.join('\n'));
      });
    }
  }
}

void main() {
  sweep(
    'Active Walking',
    () => ActiveWalkingView(
      data: _activeData,
      onBack: () {},
      onOpenNavigation: () {},
      onCompleteJourney: () {},
      // The minimise control shares the header row with the back button and
      // the JOURNEY ACTIVE pill — three things in one Row is exactly the
      // shape that overflows once the font grows.
      onMinimize: () {},
    ),
  );

  sweep(
    'Verify Location (checking)',
    () => const VerifyLocationView(
      data: VerifyLocationUiData(
        phase: VerifyLocationPhase.checking,
        destinationName: _longName,
        radiusMeters: 100,
      ),
    ),
  );

  sweep(
    'Verify Location (too far)',
    () => const VerifyLocationView(
      data: VerifyLocationUiData(
        phase: VerifyLocationPhase.blocked,
        blockReason: VerifyBlockReason.tooFar,
        destinationName: _longName,
        radiusMeters: 100,
        currentDistanceMeters: 1240,
      ),
    ),
  );

  sweep(
    'Journey Completed',
    () => const JourneyCompletedView(
      data: JourneyCompletedUiData(
        destinationName: _longName,
        destinationAreaLabel: _longArea,
        completedDistanceKm: 12.4,
        journeyDuration: Duration(hours: 2, minutes: 33, seconds: 12),
        carbonSavedKg: 2.50,
        caloriesBurned: 1400,
        reward: JourneyRewardUiState.success(
          pointsAwarded: 148,
          newlyEarnedBadgeNames: <String>['Penang Wanderer'],
        ),
      ),
    ),
  );

  sweep(
    'Journey Preview',
    () => PreWalkSummaryView(
      controller: WalkingController()
        ..selectMode(TransportMode.walking)
        ..setRouteSummary(_summary)
        ..setUserProfile(_profile()),
    ),
  );

  // The instruction banner and the arrive/time/distance bar are the densest
  // rows in the app, and a transit leg fills them with the longest text the
  // Directions API can return.
  sweep(
    'Navigation (transit)',
    () => NavigationView(
      route: _transitRoute(),
      destination: _destination,
      origin: const LatLng(5.4141, 100.3288),
      mode: TransportMode.publicTransport,
      onCompleteJourney: () {},
    ),
  );

  // The mini bar is a single Row of text and two icons under every screen in
  // the app, so it is the one piece of layout that has to hold at every size
  // at once. Pumped through its host, the way main.dart mounts it.
  group('minimised journey bar', () {
    final session = JourneySession.instance;
    tearDown(session.end);

    for (final size in _sizes) {
      for (final scale in _scales) {
        final label = '${size.width.toInt()}dp @${scale}x';

        testWidgets('does not overflow at $label', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final overflows = <String>[];
          final previous = FlutterError.onError;
          FlutterError.onError = (details) {
            if (!details.toString().contains('overflowed')) {
              previous?.call(details);
              return;
            }
            overflows.add(details.exceptionAsString().split('\n').first);
          };

          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: MaterialApp(
                navigatorKey: JourneySession.navigatorKey,
                builder: (context, child) => JourneyOverlayHost(child: child!),
                home: const Scaffold(body: Center(child: Text('Home'))),
              ),
            ),
          );
          session.adopt(_journey());
          session.minimize();
          await tester.pump();

          FlutterError.onError = previous;
          expect(overflows, isEmpty, reason: overflows.join('\n'));

          session.end();
          await tester.pump();
        });
      }
    }
  });
}
