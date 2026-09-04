// Cover for the collapsible route summary card (UC-M04 step 5 / A3).
//
// The card sits over a full-bleed map and used to be permanently expanded, so
// a tourist could not look at the route it had just drawn. It now collapses to
// its handle on a downward swipe and comes back on an upward one.
//
// These are the first widget tests to reach RouteSummaryView at all: the view
// took its RouteService from RouteSummaryController's default, which meant a
// live Directions call. The optional routeService parameter is what makes the
// screen reachable here, and closes the gap the comment in
// test/integration/map_to_walking_test.dart describes.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:walkpenang/models/place_model.dart';
import 'package:walkpenang/models/route_result.dart';
import 'package:walkpenang/models/transport_mode.dart';
import 'package:walkpenang/services/map_service.dart';
import 'package:walkpenang/services/route_service.dart';
import 'package:walkpenang/views/route_summary_view.dart';

/// Returns the same walkable route for every mode, so the card lands in its
/// summary state with Start Journey, Cancel and Navigate all present.
class _FakeRouteService extends RouteService {
  _FakeRouteService() : super(MapService());

  @override
  Future<RouteResult> calculateRoute({
    required LatLng origin,
    required LatLng destination,
    required TransportMode mode,
  }) async {
    return RouteResult(
      distanceKm: 1.4,
      durationMinutes: 18,
      polylinePoints: const [LatLng(5.4141, 100.3288), LatLng(5.4200, 100.3300)],
    );
  }
}

final _destination = PlaceModel(
  placeId: 'test_place',
  name: 'Kek Lok Si Temple',
  category: 'heritage',
  latitude: 5.3992,
  longitude: 100.2735,
  address: '1000 Jalan Balik Pulau',
);

const _origin = LatLng(5.4141, 100.3288);

Future<void> pumpSummary(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(
        home: RouteSummaryView(
          destination: _destination,
          origin: _origin,
          routeService: _FakeRouteService(),
        ),
      ),
    ),
  );

  // Long enough for the three parallel route futures to settle and for the
  // marker bitmaps to finish rasterising.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// The grab strip, which is what a tourist drags. Found by its pill rather
/// than by a key, so the test breaks if the affordance disappears.
Finder handleFinder() => find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.constraints?.maxWidth == 44 &&
          widget.constraints?.maxHeight == 4,
    );

void main() {
  testWidgets('the card starts expanded, with every action reachable',
      (tester) async {
    await pumpSummary(tester);

    // Also on the destination chip at the top of the screen, hence findsWidgets.
    expect(find.text('Kek Lok Si Temple'), findsWidgets);
    expect(find.text('Start Journey'), findsOneWidget);
    expect(find.text('Navigate'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(handleFinder(), findsOneWidget);
  });

  testWidgets('swiping the handle down collapses the card to its summary line',
      (tester) async {
    await pumpSummary(tester);

    await tester.fling(handleFinder(), const Offset(0, 240), 800, warnIfMissed: false);
    await tester.pumpAndSettle();

    // The actions are gone — collapsing is for looking at the map, and
    // proceeding is an expanded-state action.
    expect(find.text('Start Journey'), findsNothing);
    expect(find.text('Navigate'), findsNothing);
    expect(find.text('Cancel'), findsNothing);

    // The destination and the way back are not.
    // Also on the destination chip at the top of the screen, hence findsWidgets.
    expect(find.text('Kek Lok Si Temple'), findsWidgets);
    expect(handleFinder(), findsOneWidget);
    // The ETA and distance replace the address, so the collapsed strip still
    // says something worth reading. Matched on the separator because the bare
    // ETA also appears on all three mode tabs.
    expect(find.textContaining('18 min  ·'), findsOneWidget);
    expect(find.textContaining('1.4 km'), findsOneWidget);
  });

  testWidgets('swiping the handle back up restores the actions',
      (tester) async {
    await pumpSummary(tester);

    await tester.fling(handleFinder(), const Offset(0, 240), 800, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Navigate'), findsNothing);

    await tester.fling(handleFinder(), const Offset(0, -240), 800, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Start Journey'), findsOneWidget);
    expect(find.text('Navigate'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('tapping the handle toggles the card both ways', (tester) async {
    await pumpSummary(tester);

    await tester.tap(handleFinder(), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Navigate'), findsNothing);

    await tester.tap(handleFinder(), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Navigate'), findsOneWidget);
  });

  // The card had no scroll view and no overflow cover at all. 320 x 1.6 is the
  // corner that matters: Android's narrowest supported width at its largest
  // non-accessibility font setting.
  group('does not overflow', () {
    const sizes = [Size(320, 640), Size(360, 800), Size(412, 915)];
    const scales = [1.0, 1.3, 1.6];

    for (final size in sizes) {
      for (final scale in scales) {
        final label = '${size.width.toInt()}x${size.height.toInt()} @${scale}x';

        testWidgets('in either card state at $label', (tester) async {
          final overflows = <String>[];
          final previous = FlutterError.onError;
          FlutterError.onError = (details) {
            final dump = details.toString();
            if (!dump.contains('overflowed')) {
              previous?.call(details);
              return;
            }
            overflows.add(details.exceptionAsString().split('\n').first);
          };

          await pumpSummary(tester, size: size, textScale: scale);

          // Collapsed as well as expanded — the handle carries its own text.
          await tester.tap(handleFinder(), warnIfMissed: false);
          await tester.pumpAndSettle();

          FlutterError.onError = previous;
          expect(overflows, isEmpty, reason: overflows.join('\n'));
        });
      }
    }
  });
}
