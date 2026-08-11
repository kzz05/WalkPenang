import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../constants/map_constants.dart';
import '../constants/map_error_messages.dart';
import '../models/gps_location.dart';
import '../models/place_model.dart';
import '../services/boundary_validator_service.dart';
import '../services/location_service.dart';
import '../services/map_service.dart';
import '../services/places_service.dart';

/// Drives [MapView] — UC-007 (nearby pins), UC-008 (live location), and
/// UC-009 (boundary validation) all meet here.
class MapController extends ChangeNotifier {
  MapController({
    LocationService? locationService,
    BoundaryValidatorService? boundaryValidatorService,
    PlacesService? placesService,
  }) : _locationService = locationService ?? LocationService(),
       _boundaryValidatorService =
           boundaryValidatorService ?? BoundaryValidatorService(),
       _placesService = placesService ?? PlacesService(MapService());

  final LocationService _locationService;
  final BoundaryValidatorService _boundaryValidatorService;
  final PlacesService _placesService;

  StreamSubscription<GpsLocation>? _locationSubscription;

  GpsLocation? currentLocation;
  List<PlaceModel> nearbyPlaces = [];
  bool isLoading = false;
  String? errorMessage;
  double searchRadiusKm = MapConstants.defaultSearchRadiusKm;
  bool isWithinPenang = true;

  /// UC-007 step 5: centre the map on the live fix once one exists, and on
  /// George Town before the first fix arrives.
  LatLng get cameraCenter => currentLocation != null
      ? LatLng(currentLocation!.latitude, currentLocation!.longitude)
      : MapConstants.georgeTownCenter;

  /// UC-007 constraint C2 / UC-009 step 3: fed straight into
  /// `GoogleMap.cameraTargetBounds` so panning can't leave Penang.
  LatLngBounds get boundaryConstraint => _boundaryValidatorService.panningBounds;

  /// UC-007 steps 2-6, UC-008 steps 2-7, UC-009 steps 1-3 — run once when
  /// the map screen opens.
  Future<void> loadMap() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      // Must stay inside the try: requestPermission throws
      // PermissionRequestInProgressException if a dialog is already open —
      // e.g. the tourist backs out of the map and re-enters before answering.
      // Outside it, that throw left isLoading true forever and the loading
      // scrim covered the screen with no way back.
      final granted = await _locationService.requestLocationPermission();
      if (!granted) {
        errorMessage = MapErrorMessages.locationPermissionDenied;
        return;
      }

      final location = await _locationService.getCurrentLocation();
      _applyLocation(location);
      _startLocationUpdates();
      await renderNearbyPins();
    } on Exception {
      errorMessage = MapErrorMessages.locationTimeout;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _startLocationUpdates() {
    _locationSubscription?.cancel();
    _locationSubscription = _locationService.startLocationUpdates().listen(
      _applyLocation,
    );
  }

  /// UC-008 steps 4-6 / UC-009 steps 1-2: updates the marker and re-checks
  /// the Penang boundary on every fix, not just the first one.
  void _applyLocation(GpsLocation location) {
    final isFirstFix = currentLocation == null;
    final previousError = errorMessage;
    final wasWithinPenang = isWithinPenang;

    currentLocation = location;
    isWithinPenang = _boundaryValidatorService.validateUserLocation(location);

    if (!_locationService.checkSignalAccuracy(location)) {
      errorMessage = MapErrorMessages.weakGpsSignal;
    } else if (!isWithinPenang) {
      errorMessage = MapErrorMessages.outsidePenangUser;
    } else {
      errorMessage = null;
    }

    // Only notify when something the UI actually renders has changed. The
    // position stream fires on every 5 m of movement, and MapView rebuilds
    // the GoogleMap platform view on each notification — notifying
    // unconditionally floods the platform channel and hangs the app. The
    // live position marker is drawn natively by myLocationEnabled, so a new
    // fix on its own needs no rebuild; the first fix still notifies so the
    // camera can centre once.
    if (isFirstFix ||
        errorMessage != previousError ||
        isWithinPenang != wasWithinPenang) {
      notifyListeners();
    }
  }

  /// UC-007 step 4 / A2: (re)loads nearby pins for the current centre and
  /// radius — also the retry path when a tourist widens the search radius.
  Future<void> renderNearbyPins() async {
    try {
      final results = await _placesService.fetchNearbyPlaces(
        center: cameraCenter,
        radiusKm: searchRadiusKm,
      );
      nearbyPlaces = results;
      if (results.isEmpty) errorMessage = MapErrorMessages.noPlacesFound;
    } catch (_) {
      errorMessage = MapErrorMessages.mapLoadFailed;
    }
    notifyListeners();
  }

  /// UC-007 constraint C1: the 1 / 2 / 5 km radius chips.
  Future<void> setSearchRadius(double radiusKm) async {
    searchRadiusKm = radiusKm;
    notifyListeners();
    await renderNearbyPins();
  }

  /// UC-009 steps 4-6 / A2: validates a tapped pin before it's allowed to
  /// become the route-summary destination.
  bool validateDestination(PlaceModel place) {
    final destination = LatLng(place.latitude, place.longitude);
    final isValid = _boundaryValidatorService.validateDestination(destination);
    errorMessage = isValid ? null : MapErrorMessages.outsidePenangDestination;
    notifyListeners();
    return isValid;
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }
}
