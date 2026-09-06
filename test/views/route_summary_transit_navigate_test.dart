// UC-M05, public transport: what "Navigate" does once the Bus tab is selected.
//
// WalkPenang navigates a walk and a drive itself, from the polyline it already
// fetched. A bus trip it cannot: the route is "walk, wait, board, ride,
// alight, walk", and the waiting depends on a live timetable the app does not
// hold. So Bus hands off to Google Maps instead.
//
// The hand-off is external navigation and nothing more. The tests below pin
// both halves of that: the URL really does ask for transit directions to the
// place the tourist picked, and — the half that would be expensive to get
// wrong — no journey, check-in, or reward machinery is touched on the way out,
// since only a walked journey earns any of it (FR-W01).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:walkpenang/controllers/journey_session.dart';
import 'package:walkpenang/models/place_model.dart';
import 'package:walkpenang/models/route_result.dart';
import 'package:walkpenang/models/transport_mode.dart';
import 'package:walkpenang/services/map_service.dart';
import 'package:walkpenang/services/route_service.dart';
import 'package:walkpenang/views/navigation_view.dart';
import 'package:walkpenang/views/route_summary_view.dart';

/// A route for every mode except those named in [modesWithoutRoute], which
/// come back as UC-M04 A1 — the mode was checked and Google had nothing.
class _FakeRouteService extends RouteService {
  _FakeRouteService({this.modesWithoutRoute = const {}}) : super(MapService());

  final Set<TransportMode> modesWithoutRoute;

  @override
  Future<RouteResult> calculateRoute({
    required LatLng origin,
    required LatLng destination,
    required TransportMode mode,
  }) async {
    if (modesWithoutRoute.contains(mode)) return RouteResult.notFound();

    return RouteResult(
      distanceKm: 1.4,
      durationMinutes: mode == TransportMode.publicTransport ? 12 : 18,
      polylinePoints: const [LatLng(5.4141, 100.3288), LatLng(5.3992, 100.2735)],
    );
  }
}

/// Deliberately not the coordinates the origin or the polyline use, so a URL
/// built from anything other than the selected place fails the assertions.
final _destination = PlaceModel(
  placeId: 'ChIJ_test_kek_lok_si',
  name: 'Kek Lok Si Temple',
  category: 'attraction',
  latitude: 5.3992,
  longitude: 100.2735,
  address: '1000 Jalan Balik Pulau',
);

const _origin = LatLng(5.4141, 100.3288);

/// Records what the screen tried to open, standing in for the Google Maps app.
class _RecordingLauncher {
  _RecordingLauncher({this.result = true, this.throws = false});

  final bool result;
  final bool throws;
  final List<Uri> launched = [];

  Future<bool> call(Uri url) async {
    launched.add(url);
    if (throws) throw Exception('no activity found to handle Intent');
    return result;
  }
}

Future<void> _pumpSummary(
  WidgetTester tester,
  _RecordingLauncher launcher, {
  Set<TransportMode> modesWithoutRoute = const {},
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: RouteSummaryView(
        destination: _destination,
        origin: _origin,
        routeService: _FakeRouteService(modesWithoutRoute: modesWithoutRoute),
        launchExternalMap: launcher.call,
      ),
    ),
  );

  // Long enough for the three parallel route futures to settle and for the
  // marker bitmaps to finish rasterising.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Taps the mode tab by the label a tourist reads, so a renamed tab is caught
/// here rather than silently leaving these tests on the walking mode.
Future<void> _selectMode(WidgetTester tester, String tabLabel) async {
  await tester.tap(find.text(tabLabel));
  await tester.pump();
}

/// Whether the Navigate button is tappable, read off the button itself rather
/// than inferred from what a tap does — a disabled button swallows the tap
/// silently, which is indistinguishable from a handler that did nothing.
bool _navigateEnabled(WidgetTester tester) {
  final button = tester.widget<ElevatedButton>(
    find.ancestor(
      of: find.text('Navigate'),
      matching: find.byType(ElevatedButton),
    ),
  );
  return button.onPressed != null;
}

Future<void> _tapNavigate(WidgetTester tester) async {
  await tester.tap(find.text('Navigate'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(() {
    // Every test asserts against this, so start each one from a clean slate
    // rather than trusting the previous test to have left one.
    expect(JourneySession.instance.isActive, isFalse);
  });

  testWidgets('Bus + Navigate opens Google Maps on transit directions',
      (tester) async {
    final launcher = _RecordingLauncher();
    await _pumpSummary(tester, launcher);

    await _selectMode(tester, 'BUS');
    await _tapNavigate(tester);

    expect(launcher.launched, hasLength(1));
    final url = launcher.launched.single;

    expect(url.host, 'www.google.com');
    expect(url.path, '/maps/dir/');
    expect(url.queryParameters['travelmode'], 'transit');
    expect(url.queryParameters['dir_action'], 'navigate');
  });

  testWidgets('the destination is the selected place, not a fixed one',
      (tester) async {
    final launcher = _RecordingLauncher();
    await _pumpSummary(tester, launcher);

    await _selectMode(tester, 'BUS');
    await _tapNavigate(tester);

    expect(
      launcher.launched.single.queryParameters['destination'],
      '${_destination.latitude},${_destination.longitude}',
    );
    // The origin is left out on purpose: Google Maps then starts from the
    // device's live location rather than from where this route was fetched.
    expect(launcher.launched.single.queryParameters['origin'], isNull);
  });

  testWidgets('the tourist stays on the route summary, with nothing recorded',
      (tester) async {
    final launcher = _RecordingLauncher();
    await _pumpSummary(tester, launcher);

    await _selectMode(tester, 'BUS');
    await _tapNavigate(tester);

    // No journey: no JourneySession, and therefore no JourneyCompletion
    // controller, no check-in write, no points, no badges, no calories.
    expect(JourneySession.instance.isActive, isFalse);
    expect(JourneySession.instance.controller, isNull);

    // No in-app navigation either, and the summary is still underneath so
    // Android Back returns to it.
    expect(find.byType(NavigationView), findsNothing);
    expect(find.byType(RouteSummaryView), findsOneWidget);
    expect(find.text('Navigate'), findsOneWidget);
  });

  testWidgets('Bus offers no Start Journey button at all', (tester) async {
    final launcher = _RecordingLauncher();
    await _pumpSummary(tester, launcher);

    expect(find.text('Start Journey'), findsOneWidget); // walking, the default

    await _selectMode(tester, 'BUS');
    await tester.pump();

    expect(find.text('Start Journey'), findsNothing);
  });

  testWidgets('a launch that fails explains itself instead of throwing',
      (tester) async {
    final launcher = _RecordingLauncher(result: false);
    await _pumpSummary(tester, launcher);

    await _selectMode(tester, 'BUS');
    await _tapNavigate(tester);

    expect(find.text('Unable to open Google Maps.'), findsOneWidget);
    expect(find.byType(RouteSummaryView), findsOneWidget);
    expect(JourneySession.instance.isActive, isFalse);
  });

  testWidgets('a launcher that throws is caught, not surfaced to the tourist',
      (tester) async {
    final launcher = _RecordingLauncher(throws: true);
    await _pumpSummary(tester, launcher);

    await _selectMode(tester, 'BUS');
    await _tapNavigate(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Unable to open Google Maps.'), findsOneWidget);
    expect(find.byType(RouteSummaryView), findsOneWidget);
  });

  group('when our own Directions request found no route for the mode', () {
    testWidgets('Bus keeps Navigate enabled — Google Maps routes it, not us',
        (tester) async {
      final launcher = _RecordingLauncher();
      await _pumpSummary(
        tester,
        launcher,
        modesWithoutRoute: {TransportMode.publicTransport},
      );

      await _selectMode(tester, 'BUS');
      await tester.pump();

      expect(_navigateEnabled(tester), isTrue);
    });

    testWidgets('and tapping it still opens Google Maps transit directions',
        (tester) async {
      final launcher = _RecordingLauncher();
      await _pumpSummary(
        tester,
        launcher,
        modesWithoutRoute: {TransportMode.publicTransport},
      );

      await _selectMode(tester, 'BUS');
      await _tapNavigate(tester);

      final url = launcher.launched.single;
      expect(url.queryParameters['travelmode'], 'transit');
      expect(
        url.queryParameters['destination'],
        '${_destination.latitude},${_destination.longitude}',
      );
      // Still only external navigation, even on this path.
      expect(JourneySession.instance.isActive, isFalse);
      expect(find.byType(NavigationView), findsNothing);
    });

    testWidgets('Bus still offers no Start Journey', (tester) async {
      final launcher = _RecordingLauncher();
      await _pumpSummary(
        tester,
        launcher,
        modesWithoutRoute: {TransportMode.publicTransport},
      );

      await _selectMode(tester, 'BUS');
      await tester.pump();

      expect(find.text('Start Journey'), findsNothing);
    });

    testWidgets('Walk leaves Navigate disabled, as before', (tester) async {
      final launcher = _RecordingLauncher();
      await _pumpSummary(
        tester,
        launcher,
        modesWithoutRoute: {TransportMode.walking},
      );

      await _selectMode(tester, 'WALK');
      await tester.pump();

      expect(_navigateEnabled(tester), isFalse);
      // Nor is there a journey to start without a route to walk.
      expect(find.text('Start Journey'), findsNothing);
    });

    testWidgets('Drive leaves Navigate disabled, as before', (tester) async {
      final launcher = _RecordingLauncher();
      await _pumpSummary(
        tester,
        launcher,
        modesWithoutRoute: {TransportMode.driving},
      );

      await _selectMode(tester, 'DRIVE');
      await tester.pump();

      expect(_navigateEnabled(tester), isFalse);
    });
  });

  testWidgets('Walk + Navigate still opens in-app navigation', (tester) async {
    final launcher = _RecordingLauncher();
    await _pumpSummary(tester, launcher);

    // Walking is already the default mode; tapped anyway so the test reads
    // as the deliberate walking case.
    await _selectMode(tester, 'WALK');
    await _tapNavigate(tester);

    expect(find.byType(NavigationView), findsOneWidget);
    expect(launcher.launched, isEmpty);
  });

  testWidgets('Drive + Navigate still opens in-app navigation', (tester) async {
    final launcher = _RecordingLauncher();
    await _pumpSummary(tester, launcher);

    await _selectMode(tester, 'DRIVE');
    await _tapNavigate(tester);

    expect(find.byType(NavigationView), findsOneWidget);
    expect(launcher.launched, isEmpty);
  });
}
