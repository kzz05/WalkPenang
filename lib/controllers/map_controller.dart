import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../constants/map_constants.dart';
import '../constants/map_error_messages.dart';
import '../models/gps_location.dart';
import '../models/place_model.dart';
import '../services/boundary_validator_service.dart';
import '../services/compass_service.dart';
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
    CompassService? compassService,
  })  : _locationService = locationService ?? LocationService(),
        _boundaryValidatorService =
            boundaryValidatorService ?? BoundaryValidatorService(),
        _placesService = placesService ?? PlacesService(MapService()),
        _compassService = compassService ?? CompassService();

  final LocationService _locationService;
  final BoundaryValidatorService _boundaryValidatorService;
  final PlacesService _placesService;
  final CompassService _compassService;

  StreamSubscription<GpsLocation>? _locationSubscription;
  StreamSubscription<double?>? _compassSubscription;

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

  /// The tourist's live facing direction from the device magnetometer,
  /// degrees clockwise from true north — null until the first sensor
  /// reading lands (or permanently, on a device with no compass).
  double? compassHeading;

  /// Whether the map camera should keep rotating to match [compassHeading]
  /// ("compass mode" — the two-finger rotate gesture is disabled while this
  /// is on, since it would otherwise fight the auto-rotation on every
  /// sensor update). Off by default: a north-up map is the more familiar
  /// default for browsing nearby pins.
  bool isCompassModeEnabled = false;

  bool get isCompassAvailable => _compassService.isCompassAvailable;

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
      final granted = await _locationService.requestLocationPermission();
      hasLocationPermission = granted;
      if (!granted) {
        errorMessage = MapErrorMessages.locationPermissionDenied;
        return;
      }

      final location = await _locationService.getCurrentLocation();
      _applyLocation(location);
      _startLocationUpdates();
      _startCompassUpdates();
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

  void _startCompassUpdates() {
    if (!_compassService.isCompassAvailable) return;
    _compassSubscription?.cancel();
    _compassSubscription = _compassService.headingStream.listen(
      _applyCompassHeading,
    );
  }

  /// UC-008: feeds both the map's compass-follow rotation and the location
  /// puck's direction indicator. Raw magnetometer readings are noisy, so a
  /// reading is dropped unless it moves the heading by at least
  /// [MapConstants.compassHeadingChangeThresholdDegrees] — redrawing on every
  /// sample would look jittery and cost battery for no visible benefit.
  void _applyCompassHeading(double? heading) {
    if (heading == null) return;
    final previous = compassHeading;
    if (previous != null &&
        _angleDifference(previous, heading) <
            MapConstants.compassHeadingChangeThresholdDegrees) {
      return;
    }
    compassHeading = heading;
    notifyListeners();
  }

  double _angleDifference(double a, double b) {
    final diff = (a - b).abs() % 360;
    return diff > 180 ? 360 - diff : diff;
  }

  /// Toggled by the compass-mode button on [MapView]. Turning it off leaves
  /// [compassHeading] (and the puck's own rotation) updating as normal —
  /// only the camera's auto-rotation and the manual rotate gesture lock stop.
  void toggleCompassMode() {
    isCompassModeEnabled = !isCompassModeEnabled;
    notifyListeners();
  }

  /// UC-008 steps 4-6 / UC-009 steps 1-2: updates the marker and re-checks
  /// the Penang boundary on every fix, not just the first one.
  void _applyLocation(GpsLocation location) {
    final isFirstFix = currentLocation == null;
    final previousError = errorMessage;
    final wasWithinPenang = isWithinPenang;
    final previousLocation = currentLocation;

    currentLocation = location;
    isWithinPenang = _boundaryValidatorService.validateUserLocation(location);

    if (!_locationService.checkSignalAccuracy(location)) {
      errorMessage = MapErrorMessages.weakGpsSignal;
    } else if (!isWithinPenang) {
      errorMessage = MapErrorMessages.outsidePenangUser;
    } else {
      errorMessage = null;
    }

    // Only notify when something the UI actually renders has changed. MapView
    // rebuilds the GoogleMap platform view on each notification, and on an
    // emulator mock fixes arrive far faster than the 5 m distanceFilter would
    // suggest — notifying unconditionally saturates the platform channel and
    // hangs the app.
    //
    // The live position marker used to be drawn natively by myLocationEnabled,
    // so a new fix needed no rebuild at all. It is now a custom puck marker
    // (so it can carry a compass-heading indicator), which Flutter must
    // redraw — hence the movement check below, without which the puck would
    // sit frozen at the first fix while the tourist walked away from it.
    // Sub-threshold jitter is still swallowed, mirroring how
    // [_applyCompassHeading] ignores sub-threshold rotation.
    final movedFar = previousLocation != null &&
        _locationService.distanceMeters(
              startLatitude: previousLocation.latitude,
              startLongitude: previousLocation.longitude,
              endLatitude: location.latitude,
              endLongitude: location.longitude,
            ) >=
            MapConstants.locationUpdateDistanceFilterMeters;

    if (isFirstFix ||
        movedFar ||
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
    _compassSubscription?.cancel();
    super.dispose();
  }
}
