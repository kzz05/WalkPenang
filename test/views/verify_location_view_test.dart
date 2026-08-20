// Widget tests for VerifyLocationView (Figma "04a/04b/04c · Proximity
// Verification (UC-W06)").
//
// Presentation only — no GPS reads, no permission checks, no distance math.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:walkpenang/models/verify_location_ui_data.dart';
import 'package:walkpenang/views/verify_location_view.dart';
import 'package:walkpenang/views/widgets/wp_components.dart';
import 'package:walkpenang/widgets/map/verification_radius_map.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(MaterialApp(home: child));
}

void main() {
  testWidgets('checking state shows a loading indicator and no action buttons',
      (tester) async {
    await _pump(
      tester,
      const VerifyLocationView(
        data: VerifyLocationUiData(
          phase: VerifyLocationPhase.checking,
          destinationName: 'Fort Cornwallis',
          radiusMeters: 100,
        ),
      ),
    );
    // Indeterminate spinner — pump, don't settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Checking your location…'), findsOneWidget);
    expect(find.text('Complete Journey'), findsNothing);
    expect(find.text('Try Again'), findsNothing);
  });

  testWidgets(
      'verified (destination-proximity) state shows distance and Complete Journey',
      (tester) async {
    var completed = false;
    await _pump(
      tester,
      VerifyLocationView(
        data: const VerifyLocationUiData(
          phase: VerifyLocationPhase.verified,
          destinationName: 'Fort Cornwallis',
          radiusMeters: 100,
          currentDistanceMeters: 42,
        ),
        onCompleteJourney: () => completed = true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("You're here!"), findsOneWidget);
    expect(find.text('WITHIN 42 M OF DESTINATION'), findsOneWidget);
    expect(find.text('Complete Journey'), findsOneWidget);

    await tester.tap(find.text('Complete Journey'));
    await tester.pump();
    expect(completed, isTrue);
  });

  testWidgets('too-far state shows distance comparison and retry actions',
      (tester) async {
    await _pump(
      tester,
      const VerifyLocationView(
        data: VerifyLocationUiData(
          phase: VerifyLocationPhase.blocked,
          destinationName: 'Fort Cornwallis',
          radiusMeters: 100,
          currentDistanceMeters: 260,
          blockReason: VerifyBlockReason.tooFar,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Too far away'), findsOneWidget);
    expect(find.text('YOU ARE 260 M FROM DESTINATION'), findsOneWidget);
    expect(find.text('260 m'), findsOneWidget);
    expect(find.text('≤ 100 m'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
    expect(find.text('Continue Walking'), findsOneWidget);
  });

  testWidgets(
      'GPS-disabled (GPS/error) state shows the required message and no distance card',
      (tester) async {
    await _pump(
      tester,
      const VerifyLocationView(
        data: VerifyLocationUiData(
          phase: VerifyLocationPhase.blocked,
          destinationName: 'Fort Cornwallis',
          radiusMeters: 100,
          blockReason: VerifyBlockReason.gpsDisabled,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GPS is off'), findsOneWidget);
    expect(
      find.text('Please enable GPS to verify your destination.'),
      findsOneWidget,
    );
    expect(find.text('CURRENT DISTANCE'), findsNothing);
  });

  testWidgets('permission-denied state shows the required message',
      (tester) async {
    await _pump(
      tester,
      const VerifyLocationView(
        data: VerifyLocationUiData(
          phase: VerifyLocationPhase.blocked,
          destinationName: 'Fort Cornwallis',
          radiusMeters: 100,
          blockReason: VerifyBlockReason.permissionDenied,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Location permission is required to verify your destination.'),
      findsOneWidget,
    );
  });

  group('radius zone card', () {
    // Fort Cornwallis and a fix a little north-east of it.
    const destinationLat = 5.4206;
    const destinationLng = 100.3436;

    VerifyLocationUiData verifiedWithMap() => const VerifyLocationUiData(
          phase: VerifyLocationPhase.verified,
          destinationName: 'Fort Cornwallis',
          radiusMeters: 100,
          currentDistanceMeters: 42,
          destinationLatitude: destinationLat,
          destinationLongitude: destinationLng,
          userLatitude: 5.4210,
          userLongitude: 100.3440,
        );

    testWidgets('shows the embedded map, not the illustration, once the flow '
        'has coordinates', (tester) async {
      await _pump(tester, VerifyLocationView(data: verifiedWithMap()));
      await tester.pump();

      expect(find.byType(VerificationRadiusMap), findsOneWidget);
      // The caption survives the swap — it labels the zone either way.
      expect(find.text('100 M RADIUS ZONE'), findsOneWidget);
    });

    testWidgets('draws the destination, the tourist and the radius circle',
        (tester) async {
      await _pump(tester, VerifyLocationView(data: verifiedWithMap()));
      await tester.pump();

      final map = tester.widget<GoogleMap>(find.byType(GoogleMap));

      final circle = map.circles.single;
      expect(circle.center, const LatLng(destinationLat, destinationLng));
      // The zone drawn is the threshold the flow verified against — the
      // widget must not invent a radius of its own.
      expect(circle.radius, 100);

      expect(
        map.markers.map((marker) => marker.position),
        containsAll(const [
          LatLng(destinationLat, destinationLng),
          LatLng(5.4210, 100.3440),
        ]),
      );
    });

    testWidgets('keeps the verification result below the map', (tester) async {
      await _pump(tester, VerifyLocationView(data: verifiedWithMap()));
      await tester.pump();

      // The map is a visual addition to the existing flow, not a replacement
      // for its status card.
      expect(find.text("You're here!"), findsOneWidget);
      expect(find.text('WITHIN 42 M OF DESTINATION'), findsOneWidget);
      expect(find.text('LOCATION VERIFIED'), findsOneWidget);
    });

    testWidgets('still maps the destination when no fix has landed',
        (tester) async {
      await _pump(
        tester,
        const VerifyLocationView(
          data: VerifyLocationUiData(
            phase: VerifyLocationPhase.blocked,
            destinationName: 'Fort Cornwallis',
            radiusMeters: 100,
            blockReason: VerifyBlockReason.gpsDisabled,
            destinationLatitude: destinationLat,
            destinationLongitude: destinationLng,
          ),
        ),
      );
      await tester.pump();

      final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(map.circles, hasLength(1));
      // Destination only: there is no fix to plot the tourist from, and one
      // must never be guessed.
      expect(map.markers, hasLength(1));
      expect(
        map.markers.single.position,
        const LatLng(destinationLat, destinationLng),
      );
    });

    testWidgets('falls back to the illustrated ring with no coordinates',
        (tester) async {
      await _pump(
        tester,
        const VerifyLocationView(
          data: VerifyLocationUiData(
            phase: VerifyLocationPhase.checking,
            destinationName: 'Fort Cornwallis',
            radiusMeters: 100,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(VerificationRadiusMap), findsNothing);
      expect(find.text('100 M RADIUS ZONE'), findsOneWidget);
    });
  });

  testWidgets('the header uses the shared back control and reports taps',
      (tester) async {
    var wentBack = false;
    await _pump(
      tester,
      VerifyLocationView(
        data: const VerifyLocationUiData(
          phase: VerifyLocationPhase.checking,
          destinationName: 'Fort Cornwallis',
          radiusMeters: 100,
        ),
        onBack: () => wentBack = true,
      ),
    );
    await tester.pump();

    expect(find.byType(WpBackButton), findsOneWidget);
    await tester.tap(find.byType(WpBackButton));
    await tester.pump();
    expect(wentBack, isTrue);
  });

  testWidgets(
      'does not overflow at a narrow common Android width (too-far state)',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(
      tester,
      const VerifyLocationView(
        data: VerifyLocationUiData(
          phase: VerifyLocationPhase.blocked,
          destinationName: 'Fort Cornwallis',
          radiusMeters: 100,
          currentDistanceMeters: 260,
          blockReason: VerifyBlockReason.tooFar,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
