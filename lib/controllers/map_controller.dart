import 'dart:async';

import 'package:flutter/foundation.dart';

import '../constants/map_constants.dart';
import '../constants/map_error_messages.dart';
import '../models/gps_location.dart';
import '../models/lat_lng.dart';
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
  })  : _locationService = locationService ?? LocationService(),
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

  /// Gates `GoogleMap.myLocationEnabled`. Switching that on before the OS has
  /// actually granted the permission makes the Android SDK raise a
  /// SecurityException, so the map must not ask for the blue dot until this
  /// is true.
  bool hasLocationPermission = false;

  /// Centre the last pin fetch actually used, so [_applyLocation] can tell how
  /// far the tourist has walked since — null until the first fetch.
  LatLng? _lastPinFetchCenter;
  bool _isFetchingPins = false;

  /// UC-007 step 5: centre the map on the live fix once one exists, and on
  /// George Town before the first fix arrives.
  LatLng get cameraCenter => currentLocation != null
      ? LatLng(currentLocation!.latitude, currentLocation!.longitude)
      : MapConstants.georgeTownCenter;

  /// UC-007 constraint C2 / UC-009 step 3: fed straight into
  /// `GoogleMap.cameraTargetBounds` so panning can't leave Penang.
  LatLngBounds get boundaryConstraint =>
      _boundaryValidatorService.panningBounds;

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
      final access = await _locationService.requestLocationAccess();
      hasLocationPermission = access == LocationAccessStatus.granted;
      if (!hasLocationPermission) {
        // UC-M02 A1 vs UC-M01 A1: the tourist has to do something different
        // about each, so they get different messages. Telling someone whose
        // GPS is switched off to change a permission they already granted
        // sends them to the wrong settings screen.
        errorMessage = access == LocationAccessStatus.serviceDisabled
            ? MapErrorMessages.gpsDisabled
            : MapErrorMessages.locationPermissionDenied;
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

    // Pins used to be fetched once and never again, so they stayed pinned to
    // wherever the very first fix landed even after the tourist walked well
    // out of range of them. Refetch once the walk exceeds half the current
    // search radius — far enough that the old pins are genuinely stale, but
    // not so eager that a slow stroll bills a Places call every few metres.
    if (_shouldRefetchPins()) unawaited(renderNearbyPins());
  }

  bool _shouldRefetchPins() {
    final lastCenter = _lastPinFetchCenter;
    final location = currentLocation;
    if (lastCenter == null || location == null || _isFetchingPins) return false;

    final metresMoved = _locationService.distanceMeters(
      startLatitude: lastCenter.latitude,
      startLongitude: lastCenter.longitude,
      endLatitude: location.latitude,
      endLongitude: location.longitude,
    );
    return metresMoved > searchRadiusKm * 1000 / 2;
  }

  /// UC-007 step 4 / A2: (re)loads nearby pins for the current centre and
  /// radius — also the retry path when a tourist widens the search radius.
  Future<void> renderNearbyPins() async {
    // Captured once up front: the position stream can move cameraCenter
    // mid-flight, and the centre recorded below has to be the one the results
    // actually belong to.
    final center = cameraCenter;
    _isFetchingPins = true;
    try {
      final results = await _placesService.fetchNearbyPlaces(
        center: center,
        radiusKm: searchRadiusKm,
      );
      nearbyPlaces = results;

      // Clear only the two messages this method owns. A successful refetch
      // must retire a stale "unable to load" banner — otherwise widening the
      // radius after a network error shows pins and the failure notice at the
      // same time — but must not wipe a weak-signal or outside-Penang warning
      // that _applyLocation set, since both share this one field.
      if (errorMessage == MapErrorMessages.mapLoadFailed ||
          errorMessage == MapErrorMessages.noPlacesFound) {
        errorMessage = null;
      }
      if (results.isEmpty) errorMessage = MapErrorMessages.noPlacesFound;
    } catch (_) {
      errorMessage = MapErrorMessages.mapLoadFailed;
    } finally {
      // Recorded even when the call failed, so a tourist standing still after
      // a network error doesn't retry on every single GPS tick. The radius
      // chips remain the manual retry path.
      _lastPinFetchCenter = center;
      _isFetchingPins = false;
    }
    notifyListeners();
  }

  /// UC-M04 A1: no walkable route to the place the tourist just chose.
  ///
  /// Surfaced on the map's own banner rather than by pushing the route screen
  /// only to show an error on it.
  void showRouteUnavailable() {
    errorMessage = MapErrorMessages.noWalkableRoute;
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
