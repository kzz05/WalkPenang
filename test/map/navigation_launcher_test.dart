// T-M05.3 — navigation launch and exit flow
//
// UC-M05 / FR-M04. Covers what can be asserted without a device: the deep
// link that gets constructed, and the deliberate no-op on early exit.
//
// launchGoogleMapsNavigation and isGoogleMapsInstalled are not exercised here
// because both go straight to url_launcher's platform channel, which needs a
// real device or an integration test. What they are *given* is this file's
// concern; whether Android honours it is T-M05.3's manual pass on hardware.
import 'package:flutter_test/flutter_test.dart';

import 'package:walkpenang/models/lat_lng.dart';
import 'package:walkpenang/services/map_service.dart';
import 'package:walkpenang/services/navigation_launcher_service.dart';

void main() {
  final service = NavigationLauncherService(MapService());

  // Fort Cornwallis.
  const destination = LatLng(5.4206, 100.3428);

  group('deep link construction', () {
    test('targets the Google Maps universal directions URL', () {
      final uri = service.buildNavigationDeepLink(destination);

      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/dir/');
      expect(uri.queryParameters['api'], '1');
    });

    test('requests walking mode, not driving', () {
      // The whole app is about walking; a deep link that opened driving
      // directions would quietly undo that at the last step.
      final uri = service.buildNavigationDeepLink(destination);
      expect(uri.queryParameters['travelmode'], 'walking');
    });

    test('carries the destination as "lat,lng" in that order', () {
      final uri = service.buildNavigationDeepLink(destination);
      expect(uri.queryParameters['destination'], '5.4206,100.3428');
    });

    test('omits the origin so Google Maps uses the live device location', () {
      // UC-M05 constraint C1: sending a stale origin would route the tourist
      // from wherever they were when the card was opened.
      final uri = service.buildNavigationDeepLink(destination);
      expect(uri.queryParameters.containsKey('origin'), isFalse);
    });

    test('does not leak the API key into a user-visible link', () {
      final uri = service.buildNavigationDeepLink(destination);
      expect(uri.queryParameters.containsKey('key'), isFalse);
      expect(uri.toString().toLowerCase(), isNot(contains('aiza')));
    });

    test('a southern-hemisphere or negative coordinate survives formatting',
        () {
      final uri =
          service.buildNavigationDeepLink(const LatLng(-33.8688, 151.2093));
      expect(uri.queryParameters['destination'], '-33.8688,151.2093');
    });

    test('distinct destinations produce distinct links', () {
      final fort = service.buildNavigationDeepLink(destination);
      final hill = service.buildNavigationDeepLink(
        const LatLng(5.4239, 100.2760),
      );
      expect(fort, isNot(equals(hill)));
    });
  });

  group('UC-M05 A2 — leaving navigation early', () {
    test('exiting before arrival does nothing at all', () {
      // Constraint C2: awarding points is the Walking & Carbon module's call
      // on a verified arrival. This module must not short-circuit that, so
      // the handler is intentionally empty and this test exists to keep it
      // that way rather than to assert behaviour.
      expect(() => service.handleNavigationExit(arrived: false),
          returnsNormally);
      expect(
          () => service.handleNavigationExit(arrived: true), returnsNormally);
    });
  });
}
