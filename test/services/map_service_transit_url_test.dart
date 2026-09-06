// UC-M05, public transport: the Google Maps hand-off URL.
//
// The bus mode is the one mode WalkPenang does not navigate itself, so the
// only thing standing between the tourist and a wrong destination is this
// URL. It is built from the selected place's own coordinates and asks Google
// Maps for transit directions specifically — a `travelmode` that silently
// went back to walking would send someone on a two-hour walk.

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:walkpenang/services/map_service.dart';

void main() {
  final service = MapService();

  // Only the Directions API request below reads MAPS_API_KEY; the app URL
  // under test carries no key at all. Loaded with a stub so the last test
  // does not have to reach for a real .env.
  setUpAll(() => dotenv.testLoad(mergeWith: {'MAPS_API_KEY': 'test-key'}));

  test('asks Google Maps for transit directions, and to start navigating', () {
    final url = service.buildTransitDirectionsAppUrl(
      const LatLng(5.3992, 100.2735),
    );

    expect(url.host, 'www.google.com');
    expect(url.path, '/maps/dir/');
    expect(url.queryParameters['api'], '1');
    expect(url.queryParameters['travelmode'], 'transit');
    expect(url.queryParameters['dir_action'], 'navigate');
  });

  test('sends the given destination as lat,lng — nothing hardcoded', () {
    final kekLokSi = service.buildTransitDirectionsAppUrl(
      const LatLng(5.3992, 100.2735),
    );
    final chewJetty = service.buildTransitDirectionsAppUrl(
      const LatLng(5.4141, 100.3421),
    );

    expect(kekLokSi.queryParameters['destination'], '5.3992,100.2735');
    expect(chewJetty.queryParameters['destination'], '5.4141,100.3421');

    // The comma is the separator Google's URL scheme expects, so it has to
    // survive percent-encoding as a literal in the query string.
    expect(kekLokSi.toString(), contains('destination=5.3992%2C100.2735'));
  });

  test('omits the origin, so Google Maps starts from the live location', () {
    final url = service.buildTransitDirectionsAppUrl(
      const LatLng(5.3992, 100.2735),
    );

    expect(url.queryParameters.containsKey('origin'), isFalse);
  });

  test('carries no API key — this is a public URL scheme, not an API call', () {
    final url = service.buildTransitDirectionsAppUrl(
      const LatLng(5.3992, 100.2735),
    );

    expect(url.queryParameters.containsKey('key'), isFalse);
  });

  test('the Directions API request is untouched by the hand-off', () {
    // Regression guard: the in-app route calculation still asks the
    // Directions API for `mode=transit`, which is a different vocabulary and
    // a different endpoint from the app URL above.
    final api = service.buildDirectionsRequest(
      origin: const LatLng(5.4141, 100.3288),
      destination: const LatLng(5.3992, 100.2735),
      mode: 'transit',
    );

    expect(api.host, 'maps.googleapis.com');
    expect(api.queryParameters['mode'], 'transit');
    expect(api.queryParameters['origin'], '5.4141,100.3288');
  });
}
