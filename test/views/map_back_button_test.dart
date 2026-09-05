// Regression cover for the black screen the home map could produce.
//
// The floating back control was gated on Navigator.of(context).canPop(), which
// answers a question about the whole stack rather than about this route: it
// turned true the moment Settings or Edit Profile was pushed *over* the home
// map. The map rebuilds about once a second (every GPS fix), so the button
// appeared; nothing necessarily rebuilt it after the pop, so it could stay;
// and pressing it popped HomeView itself, the first route, leaving an empty
// navigator and a black screen.
//
// The screen is pumped with no platform plugins available, so location fails
// and the map settles into its message-banner state — the map's overlays are
// what these tests are about, and they render either way.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkpenang/views/map_view.dart';

/// Long enough for loadMap to fall through to its message state and for the
/// marker bitmaps to finish rasterising.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testWidgets('the home map offers no back button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MapPanel())),
    );
    await _settle(tester);

    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('opening a screen over the home map does not grow one',
      (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    MaterialApp app() => MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(body: MapPanel()),
        );

    await tester.pumpWidget(app());
    await _settle(tester);

    // What the account menu does.
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Settings')),
      ),
    );
    await _settle(tester);

    // The map is still being rebuilt underneath while Settings is open —
    // every GPS fix does this on a real device, and it is the rebuild that
    // used to bake the back button in.
    await tester.pumpWidget(app());
    await _settle(tester);

    navigator.currentState!.pop();
    await _settle(tester);

    expect(
      find.byIcon(Icons.arrow_back),
      findsNothing,
      reason: 'a back button here pops the first route and blacks the app out',
    );
  });

  testWidgets('a map pushed as its own screen keeps its back button',
      (tester) async {
    final navigator = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('Home')),
      ),
    );

    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: MapPanel()),
      ),
    );
    await _settle(tester);

    // Here the control leads somewhere: there is a route underneath to go
    // back to, which is the case the gate exists for.
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await _settle(tester);

    expect(find.text('Home'), findsOneWidget);
  });
}
