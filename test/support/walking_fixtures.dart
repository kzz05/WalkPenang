// ---------------------------------------------------------------------------
// walking_fixtures.dart — test support
// Module 4 — Walking & Carbon
// ---------------------------------------------------------------------------
//
// The Fort Cornwallis walk from the "02 · Pre-Walk Summary v2" Figma
// prototype. It used to live on the model as WalkingRouteSummary.demo; it is
// a fixture, not a route the app can produce, so it belongs to the tests that
// need a known journey rather than to lib/. Real journeys start from a tapped
// place via WalkingRouteSummary.fromDestination.
//
// Coordinates are Fort Cornwallis's real public location in George Town, so
// US-W05/UC-W06 arrival verification behaves sensibly against it.

import 'package:walkpenang/models/walking_route_summary.dart';

const demoRouteSummary = WalkingRouteSummary(
  destinationName: 'Fort Cornwallis',
  areaLabel: 'George Town Heritage Zone',
  distanceKm: 2.4,
  estimatedDuration: Duration(minutes: 32),
  rewardPoints: 15,
  rewardBadgeLabel: 'a heritage badge for Fort Cornwallis',
  destinationId: 'demo-fort-cornwallis',
  destinationLatitude: 5.4229,
  destinationLongitude: 100.3402,
);
