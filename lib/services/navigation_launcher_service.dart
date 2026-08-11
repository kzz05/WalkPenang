import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'map_service.dart';

/// Navigation Launcher Sub Module (UC-M05).
class NavigationLauncherService {
  NavigationLauncherService(this._mapService);
  final MapService _mapService;

  static final Uri _playStoreMapsUri = Uri.parse(
    'https://play.google.com/store/apps/details?id=com.google.android.apps.maps',
  );

  /// UC-M05 step 2: destination-only deep link — Google Maps fills in the
  /// origin from the device's own current location.
  Uri buildNavigationDeepLink(LatLng destination) =>
      _mapService.buildDeepLinkRequest(destination);

  /// UC-M05 step 3: whether any app on the device can handle a `geo:` intent
  /// — in practice, whether Google (or another) Maps app is installed.
  /// Requires the `geo` scheme `<queries>` entry in AndroidManifest.xml.
  Future<bool> isGoogleMapsInstalled(LatLng destination) {
    final geoUri = Uri.parse('geo:${destination.latitude},${destination.longitude}');
    return canLaunchUrl(geoUri);
  }

  /// UC-M05 steps 3-4 / A3: opens the deep link in Google Maps (or the
  /// browser, if it isn't installed). Returns false only if the launch
  /// itself failed to fire (A3) — `canLaunchUrl` can't reliably tell "no
  /// app installed" apart from "user declined" across platforms, so the
  /// Play Store redirect (A1) is a separate, explicit call the UI makes
  /// after checking `GoogleMapsInstallCheck` or catching this failure.
  Future<bool> launchGoogleMapsNavigation(Uri deepLink) {
    return launchUrl(deepLink, mode: LaunchMode.externalApplication);
  }

  /// UC-M05 A1: Google Maps isn't installed — send the tourist to install it.
  Future<bool> redirectToPlayStore() {
    return launchUrl(_playStoreMapsUri, mode: LaunchMode.externalApplication);
  }

  /// UC-M05 A2: tourist left navigation before arriving. Deliberately a
  /// no-op — GPS check-in and points are the Walking & Carbon module's
  /// call to make on confirmed arrival, not this one's (constraint C2).
  void handleNavigationExit({required bool arrived}) {}
}
