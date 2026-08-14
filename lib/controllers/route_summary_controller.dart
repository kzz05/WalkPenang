import 'package:flutter/foundation.dart';

import '../constants/map_error_messages.dart';
import '../models/lat_lng.dart';
import '../models/place_model.dart';
import '../models/route_result.dart';
import '../services/map_service.dart';
import '../services/navigation_launcher_service.dart';
import '../services/route_service.dart';

/// Drives [RouteSummaryView] — UC-M04 (distance/time) and UC-M05 (launch
/// navigation), both of which extend UC-M06 (Request Map Service).
class RouteSummaryController extends ChangeNotifier {
  RouteSummaryController({
    required this.destination,
    RouteService? routeService,
    NavigationLauncherService? navigationLauncherService,
  }) : _routeService = routeService ?? RouteService(MapService()),
       _navigationLauncherService =
           navigationLauncherService ?? NavigationLauncherService(MapService());

  final PlaceModel destination;
  final RouteService _routeService;
  final NavigationLauncherService _navigationLauncherService;

  RouteResult? route;
  bool isLoading = false;
  String? errorMessage;

  /// UC-M04 steps 2-5 / A1-A2: fetches distance/time for the route summary
  /// card, triggered as soon as a tourist taps a pin.
  Future<void> calculateRoute(LatLng origin) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await _routeService.calculateWalkingRoute(
        origin: origin,
        destination: LatLng(destination.latitude, destination.longitude),
      );
      if (!result.routeFound) {
        errorMessage = MapErrorMessages.noWalkableRoute;
      }
      route = result;
    } catch (_) {
      errorMessage = MapErrorMessages.networkLostDuringRoute;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// UC-M05 steps 1-4 / A1 / A3: taps "Navigate" on the route summary card.
  Future<void> launchNavigation() async {
    final destLatLng = LatLng(destination.latitude, destination.longitude);
    final deepLink = _navigationLauncherService.buildNavigationDeepLink(
      destLatLng,
    );

    final mapsInstalled = await _navigationLauncherService
        .isGoogleMapsInstalled(destLatLng);
    if (!mapsInstalled) {
      await _navigationLauncherService.redirectToPlayStore();
      return;
    }

    final launched = await _navigationLauncherService
        .launchGoogleMapsNavigation(deepLink);
    if (!launched) {
      errorMessage = MapErrorMessages.navigationLaunchFailed;
      notifyListeners();
    }
  }
}
