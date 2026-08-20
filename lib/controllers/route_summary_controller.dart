import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../constants/map_error_messages.dart';
import '../constants/travel_mode.dart';
import '../models/place_model.dart';
import '../models/route_result.dart';
import '../services/map_service.dart';
import '../services/route_service.dart';

/// Drives [RouteSummaryView] — UC-M04 (distance/time, compared across every
/// travel mode), which extends UC-M06 (Request Map Service). "Navigate"
/// hands the already-fetched route for the selected mode off to
/// [NavigationController] for UC-M05's in-app turn-by-turn navigation.
class RouteSummaryController extends ChangeNotifier {
  RouteSummaryController({required this.destination, RouteService? routeService})
    : _routeService = routeService ?? RouteService(MapService());

  final PlaceModel destination;
  final RouteService _routeService;

  /// Every mode's result, fetched together in [calculateRoute] so switching
  /// the tab in [RouteSummaryView] is instant — no re-fetch per tap.
  final Map<TravelMode, RouteResult> routesByMode = {};
  final Map<TravelMode, bool> _networkFailedByMode = {};

  TravelMode selectedMode = TravelMode.walking;
  bool isLoading = false;
  String? errorMessage;

  RouteResult? get route => routesByMode[selectedMode];

  /// UC-M04 steps 2-5 / A1-A2: fetches distance/time for every travel mode
  /// in parallel, so the route summary can show a Walk / Drive / Bus
  /// comparison the way Google Maps does, triggered as soon as a tourist
  /// taps a pin.
  Future<void> calculateRoute(LatLng origin) async {
    isLoading = true;
    errorMessage = null;
    routesByMode.clear();
    _networkFailedByMode.clear();
    notifyListeners();

    final destLatLng = LatLng(destination.latitude, destination.longitude);
    final results = await Future.wait(
      TravelMode.values.map((mode) => _fetchMode(mode, origin, destLatLng)),
    );

    for (final result in results) {
      routesByMode[result.mode] = result.route;
      _networkFailedByMode[result.mode] = result.networkFailed;
    }
    _refreshErrorMessageForSelectedMode();

    isLoading = false;
    notifyListeners();
  }

  Future<_ModeFetchResult> _fetchMode(
    TravelMode mode,
    LatLng origin,
    LatLng destLatLng,
  ) async {
    try {
      final result = await _routeService.calculateRoute(
        origin: origin,
        destination: destLatLng,
        mode: mode,
      );
      return _ModeFetchResult(mode: mode, route: result, networkFailed: false);
    } on MapServiceException {
      return _ModeFetchResult(
        mode: mode,
        route: RouteResult.notFound(),
        networkFailed: true,
      );
    }
  }

  /// UC-M04 mode comparison: switches which mode's ETA/route/polyline the
  /// summary and map show — every mode was already fetched together in
  /// [calculateRoute], so this is instant.
  void selectMode(TravelMode mode) {
    if (selectedMode == mode) return;
    selectedMode = mode;
    _refreshErrorMessageForSelectedMode();
    notifyListeners();
  }

  void _refreshErrorMessageForSelectedMode() {
    final result = routesByMode[selectedMode];
    if (result == null || result.routeFound) {
      errorMessage = null;
      return;
    }
    errorMessage = (_networkFailedByMode[selectedMode] ?? false)
        ? MapErrorMessages.networkLostDuringRoute
        : MapErrorMessages.noRouteFound;
  }
}

class _ModeFetchResult {
  final TravelMode mode;
  final RouteResult route;
  final bool networkFailed;

  _ModeFetchResult({
    required this.mode,
    required this.route,
    required this.networkFailed,
  });
}
