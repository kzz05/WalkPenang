import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../constants/map_error_messages.dart';
import '../models/place_model.dart';
import '../models/route_result.dart';
import '../services/map_service.dart';
import '../services/route_service.dart';

/// Drives [RouteSummaryView] — UC-M04 (distance/time), which extends UC-M06
/// (Request Map Service). "Navigate" hands the already-fetched [route] off
/// to [NavigationController] for UC-M05's in-app turn-by-turn navigation.
class RouteSummaryController extends ChangeNotifier {
  RouteSummaryController({required this.destination, RouteService? routeService})
    : _routeService = routeService ?? RouteService(MapService());

  final PlaceModel destination;
  final RouteService _routeService;

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
}
