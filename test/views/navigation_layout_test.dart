// Where the navigation screen's two overlays sit.
//
// The instruction banner belongs at the top and the remaining arrive/time
// left/distance bar at the bottom, with the map readable between them. That
// arrangement was briefly lost to a Column with two flex children: a Spacer
// took half the free space and a loose Flexible left the other half unspent,
// which collected below the bar and stranded it in the middle of the screen.
//
// Position is not something the overflow sweep can see — a layout can be
// perfectly free of overflow and still put things in the wrong place — so it
// is asserted here directly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:walkpenang/models/place_model.dart';
import 'package:walkpenang/models/route_result.dart';
import 'package:walkpenang/models/route_step.dart';
import 'package:walkpenang/models/transport_mode.dart';
import 'package:walkpenang/views/navigation_view.dart';

final _destination = PlaceModel(
  placeId: 'test-chew-jetty',
  name: 'Chew Jetty',
  category: 'attraction',
  latitude: 5.4141,
  longitude: 100.3421,
);

RouteResult _route() => RouteResult(
      distanceKm: 0.94,
      durationMinutes: 14,
      polylinePoints: const [LatLng(5.4141, 100.3288), LatLng(5.4141, 100.3421)],
      steps: [
        RouteStep(
          instruction: 'Turn right to stay on Pesara King Edward',
          maneuver: 'turn-right',
          distanceMeters: 320,
          durationSeconds: 260,
          startLocation: const LatLng(5.4141, 100.3288),
          endLocation: const LatLng(5.4141, 100.3421),
          polylinePoints: const [LatLng(5.4141, 100.3288)],
        ),
      ],
    );

Future<void> _pumpNavigation(WidgetTester tester, {double textScale = 1.0}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(
        home: NavigationView(
          route: _route(),
          destination: _destination,
          origin: const LatLng(5.4141, 100.3288),
          mode: TransportMode.walking,
        ),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  for (final scale in <double>[1.0, 1.3, 1.6]) {
    testWidgets('the remaining-distance bar sits at the bottom @${scale}x',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pumpNavigation(tester, textScale: scale);

      final screenHeight = tester.getSize(find.byType(MaterialApp)).height;
      // The bar carries all three figures, so any of them locates it.
      final bar = tester.getRect(find.text('distance'));

      expect(
        bar.bottom,
        greaterThan(screenHeight * 0.8),
        reason: 'the bar belongs against the bottom edge, not adrift in the '
            'middle of the map',
      );
    });
  }

  testWidgets('the instruction banner stays at the top', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpNavigation(tester);

    final screenHeight = tester.getSize(find.byType(MaterialApp)).height;
    final banner = tester.getRect(
      find.text('Turn right to stay on Pesara King Edward'),
    );

    expect(banner.top, lessThan(screenHeight * 0.25));
  });
}
