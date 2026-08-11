// Widget tests for US-W04 — Calorie Expenditure Calculation: the
// Pre-Walk Summary screen's missing/invalid body-weight state.
//
// Builds PreWalkSummaryView directly against a WalkingController seeded in
// memory — no Firebase involved, matching how WalkingController's other
// tests avoid ProfileStore/Firestore.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:walkpenang/controllers/walking_controller.dart';
import 'package:walkpenang/models/transport_mode.dart';
import 'package:walkpenang/models/user_profile.dart';
import 'package:walkpenang/models/walking_route_summary.dart';
import 'package:walkpenang/views/pre_walk_summary_view.dart';

UserProfile _profileWithWeight(double weightKg) => UserProfile(
      nickname: 'Test User',
      weightKg: weightKg,
      heightCm: 170,
      units: 'metric',
    );

void main() {
  testWidgets(
      'shows the missing-weight prompt and no misleading kcal value when '
      "the profile's body weight is invalid", (tester) async {
    final controller = WalkingController()
      ..selectMode(TransportMode.walking)
      ..setRouteSummary(WalkingRouteSummary.demo)
      ..setUserProfile(_profileWithWeight(0));

    await tester.pumpWidget(MaterialApp(
      home: PreWalkSummaryView(controller: controller),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Add'), findsOneWidget);
    expect(find.text('TAP TO ADD'), findsOneWidget);
    // The standard-example calorie value must never appear for invalid data.
    expect(find.text('140'), findsNothing);
    expect(find.text('KCAL BURNED'), findsNothing);
  });

  testWidgets('shows the calculated kcal value when body weight is valid',
      (tester) async {
    final controller = WalkingController()
      ..selectMode(TransportMode.walking)
      ..setRouteSummary(WalkingRouteSummary.demo)
      ..setUserProfile(_profileWithWeight(65));

    await tester.pumpWidget(MaterialApp(
      home: PreWalkSummaryView(controller: controller),
    ));
    await tester.pumpAndSettle();

    expect(find.text('140'), findsOneWidget);
    expect(find.text('KCAL BURNED'), findsOneWidget);
    expect(find.text('Add'), findsNothing);
  });

  testWidgets(
      'tapping the missing-weight prompt navigates via the existing Edit '
      'Profile route', (tester) async {
    final controller = WalkingController()
      ..selectMode(TransportMode.walking)
      ..setRouteSummary(WalkingRouteSummary.demo)
      ..setUserProfile(_profileWithWeight(-1));

    final pushedRoutes = <Route<dynamic>>[];
    final observer = _RecordingNavigatorObserver(pushedRoutes);

    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [observer],
      home: PreWalkSummaryView(controller: controller),
    ));
    await tester.pumpAndSettle();

    final promptTile = find.ancestor(
      of: find.text('Add'),
      matching: find.byType(InkWell),
    );
    expect(promptTile, findsOneWidget);

    // Deliberately not settling/pumping further after the tap: the pushed
    // route's builder (EditProfileView, which touches ProfileStore/
    // FirebaseAuth) must not run in this Firebase-free test — only that
    // the existing Edit Profile navigation contract (a route that resolves
    // to a UserProfile) was used.
    await tester.tap(promptTile);

    expect(pushedRoutes, isNotEmpty);
    expect(pushedRoutes.last, isA<MaterialPageRoute<UserProfile>>());
  });
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  _RecordingNavigatorObserver(this.pushedRoutes);

  final List<Route<dynamic>> pushedRoutes;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
  }
}
