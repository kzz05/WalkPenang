import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
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
import '../services/routed_places_store.dart';
import '../utils/angle_utils.dart';

/// What the tourist can actually *do* about the message currently on screen.
///
/// Every alternative flow in UC-007/UC-008/UC-009 ends in a sentence telling
/// the tourist to go and fix something; pairing each with the button that does
/// it turns "Please enable it in your device settings" from an instruction
/// into one tap.
enum MapMessageAction {
  none,

  /// Device GPS is off — jump to the system location screen.
  openLocationSettings,

  /// Permission was refused for good — jump to this app's settings page.
  openAppSettings,

  /// Nothing found at this radius — offer the next one up.
  widenRadius,

  /// A network or timeout failure worth simply trying again.
  retry,
}

/// Drives [MapView] — UC-007 (nearby pins), UC-008 (live location), and
/// UC-009 (boundary validation) all meet here.
class MapController extends ChangeNotifier {
  MapController({
    LocationService? locationService,
    BoundaryValidatorService? boundaryValidatorService,
    PlacesService? placesService,
    CompassService? compassService,
    RoutedPlacesStore? routedPlacesStore,
  })  : _locationService = locationService ?? LocationService(),
        _boundaryValidatorService =
            boundaryValidatorService ?? BoundaryValidatorService(),
        _placesService = placesService ?? PlacesService(MapService()),
        _compassService = compassService ?? CompassService(),
        _routedPlacesStore =
            routedPlacesStore ?? const SharedPrefsRoutedPlacesStore();

  final LocationService _locationService;
  final BoundaryValidatorService _boundaryValidatorService;
  final PlacesService _placesService;
  final CompassService _compassService;
  final RoutedPlacesStore _routedPlacesStore;

  StreamSubscription<GpsLocation>? _locationSubscription;
  StreamSubscription<double?>? _compassSubscription;

  GpsLocation? currentLocation;
  List<PlaceModel> nearbyPlaces = [];

  /// Saved places pinned regardless of the current search, set by the map
  /// screen from the app-wide favourites (see [setFavouritePlaces]).
  List<PlaceModel> favouritePlaces = const [];

  /// Everything the map draws a place pin for, and everything the results
  /// strip can scroll to: the current search, plus any favourite that search
  /// did not already return.
  ///
  /// Favourites come last rather than being merged by distance. The strip is
  /// ordered nearest-first as an answer to "where could I walk right now",
  /// and a saved place three kilometres away is not competing for that slot —
  /// it is there so the tourist can reach it at all without hunting for it
  /// with the radius chips.
  List<PlaceModel> get visiblePlaces {
    if (favouritePlaces.isEmpty) return nearbyPlaces;

    final nearbyIds = nearbyPlaces.map((place) => place.placeId).toSet();
    return [
      ...nearbyPlaces,
      // The nearby copy wins on a tie: it came from a live search, so its
      // rating and opening hours are current, while a favourite's are a
      // snapshot from whenever it was saved.
      ...favouritePlaces.where((place) => !nearbyIds.contains(place.placeId)),
    ];
  }

  /// Replaces the always-on favourite pins.
  ///
  /// Takes plain [PlaceModel]s rather than the Discovery module's
  /// FavoritePlace, so this module keeps knowing nothing about how favourites
  /// are stored or which screens can save one.
  void setFavouritePlaces(List<PlaceModel> places) {
    final unchanged = places.length == favouritePlaces.length &&
        List.generate(places.length, (i) => i).every(
          (i) => places[i].placeId == favouritePlaces[i].placeId,
        );
    if (unchanged) return;

    favouritePlaces = List.unmodifiable(places);
    notifyListeners();
  }
  bool isLoading = false;
  double searchRadiusKm = MapConstants.defaultSearchRadiusKm;
  bool isWithinPenang = true;

  /// The pin the tourist most recently picked out, either by tapping it on the
  /// map or by scrolling to its card. Drawn larger than the rest so the map
  /// and the results strip always agree on what's selected.
  String? selectedPlaceId;

  /// UC-M04: places the tourist has already got a working route to. Their pin
  /// and card go grey, so a tourist working through a busy search can see at a
  /// glance which options they have already priced up.
  ///
  /// Restored from [RoutedPlacesStore] on startup and written back on every
  /// change, so the grey survives closing the app. A plain `Set` literal is a
  /// LinkedHashSet, so iteration order is insertion order — which is what lets
  /// [_trimToCap] drop the *oldest* marks rather than arbitrary ones.
  final Set<String> _routedPlaceIds = <String>{};

  bool _disposed = false;

  bool isPlaceRouted(String placeId) => _routedPlaceIds.contains(placeId);

  /// Messages are split by source so they can't overwrite each other: a GPS
  /// tick arriving a second after "No places found nearby" used to wipe that
  /// message off the screen before the tourist had read it.
  String? _gpsMessage;
  String? _contentMessage;
  MapMessageAction _gpsAction = MapMessageAction.none;
  MapMessageAction _contentAction = MapMessageAction.none;

  /// Where the last search was centred, and where the camera is now — the two
  /// together are what decide whether "Search this area" is worth offering.
  LatLng? _resultsCentre;
  LatLng? _mapCentre;
  bool _canSearchThisArea = false;

  /// Set only by [searchThisArea]. Until the tourist explicitly searches
  /// somewhere else, every search — including a radius change — is centred on
  /// where they actually are, not on wherever the camera happens to have
  /// drifted to.
  LatLng? _customSearchCentre;

  /// Centre the last pin fetch actually used, and whether one is in flight.
  /// These drive [_shouldRefetchPins] only — "Search this area" keys off the
  /// *camera* drifting, this keys off the *tourist* walking, so the two
  /// affordances answer different questions and both are kept.
  LatLng? _lastPinFetchCenter;
  bool _isFetchingPins = false;

  /// UC-007 A2 / UC-008 A2 / UC-009 A1-A2 — whichever message currently
  /// matters most. A GPS problem outranks a content one, because nothing else
  /// on the screen can be trusted while the position is wrong.
  String? get errorMessage => _gpsMessage ?? _contentMessage;

  /// The action offered alongside [errorMessage], from the same source.
  MapMessageAction get messageAction =>
      _gpsMessage != null ? _gpsAction : _contentAction;

  /// True once the tourist has panned far enough from the last search that the
  /// pins on screen no longer describe what they're looking at — the moment
  /// Google Maps itself offers "Search this area".
  bool get canSearchThisArea => _canSearchThisArea;

  /// The tourist's live facing direction from the device magnetometer, degrees
  /// clockwise from true north — null until the first sensor reading lands (or
  /// permanently, on a device with no compass).
  double? compassHeading;

  /// Whether the map camera should keep rotating to match [compassHeading]
  /// ("compass mode" — the two-finger rotate gesture is disabled while this is
  /// on, since it would otherwise fight the auto-rotation on every sensor
  /// update). Off by default: a north-up map is the more familiar default for
  /// browsing nearby pins.
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

  /// UC-007 steps 2-6, UC-008 steps 2-7, UC-009 steps 1-3 — run once when the
  /// map screen opens.
  Future<void> loadMap() async {
    isLoading = true;
    _setGpsMessage(null);
    _setContentMessage(null);
    notifyListeners();

    try {
      // Must stay inside the try: requestLocationPermission throws
      // PermissionRequestInProgressException if a dialog is already open —
      // e.g. the tourist backs out of the map and re-enters before answering.
      // Outside it, that throw left isLoading true forever and the loading
      // scrim covered the screen with no way back. The `finally` below is
      // what clears the scrim, so the early return here is safe.
      final availability = await _locationService.requestLocationPermission();
      if (availability != LocationAvailability.granted) {
        _applyUnavailableLocation(availability);
        return;
      }

      final location = await _locationService.getCurrentLocation();
      _applyLocation(location);
      _startLocationUpdates();
      _startCompassUpdates();
      await renderNearbyPins();
    } on Exception {
      _setGpsMessage(MapErrorMessages.locationTimeout, MapMessageAction.retry);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// UC-008 A1: each way of being blocked gets the message *and* the button
  /// that resolves it.
  void _applyUnavailableLocation(LocationAvailability availability) {
    switch (availability) {
      case LocationAvailability.serviceDisabled:
        _setGpsMessage(
          MapErrorMessages.gpsDisabled,
          MapMessageAction.openLocationSettings,
        );
      case LocationAvailability.permissionDeniedForever:
        _setGpsMessage(
          MapErrorMessages.locationPermissionDenied,
          MapMessageAction.openAppSettings,
        );
      case LocationAvailability.permissionDenied:
        // Still askable, so the button re-runs the request rather than sending
        // the tourist off into system settings for no reason.
        _setGpsMessage(
          MapErrorMessages.locationPermissionDenied,
          MapMessageAction.retry,
        );
      case LocationAvailability.granted:
        _setGpsMessage(null);
    }
  }

  void _setGpsMessage(
    String? message, [
    MapMessageAction action = MapMessageAction.none,
  ]) {
    _gpsMessage = message;
    _gpsAction = message == null ? MapMessageAction.none : action;
  }

  void _setContentMessage(
    String? message, [
    MapMessageAction action = MapMessageAction.none,
  ]) {
    _contentMessage = message;
    _contentAction = message == null ? MapMessageAction.none : action;
  }

  void _startLocationUpdates() {
    _locationSubscription?.cancel();
    _locationSubscription = _locationService.startMapUpdates().listen(
      _applyLocation,
      onError: (Object _) {
        _setGpsMessage(MapErrorMessages.locationTimeout, MapMessageAction.retry);
        notifyListeners();
      },
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
    final normalised = normaliseDegrees(heading);
    final previous = compassHeading;
    if (previous != null &&
        angleDifference(previous, normalised) <
            MapConstants.compassHeadingChangeThresholdDegrees) {
      return;
    }
    compassHeading = normalised;
    notifyListeners();
  }

  /// Toggled by the compass-mode button on [MapView]. Turning it off leaves
  /// [compassHeading] (and the puck's own rotation) updating as normal — only
  /// the camera's auto-rotation and the manual rotate gesture lock stop.
  void toggleCompassMode() {
    isCompassModeEnabled = !isCompassModeEnabled;
    notifyListeners();
  }

  /// UC-008 steps 4-6 / UC-009 steps 1-2: updates the marker and re-checks the
  /// Penang boundary on every fix, not just the first one.
  void _applyLocation(GpsLocation location) {
    final isFirstFix = currentLocation == null;
    final previousError = errorMessage;
    final wasWithinPenang = isWithinPenang;
    final previousLocation = currentLocation;

    currentLocation = location;
    isWithinPenang = _boundaryValidatorService.validateUserLocation(location);

    if (!_locationService.checkSignalAccuracy(location)) {
      _setGpsMessage(MapErrorMessages.weakGpsSignal);
    } else if (!isWithinPenang) {
      _setGpsMessage(MapErrorMessages.outsidePenangUser);
    } else {
      _setGpsMessage(null);
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
    // An explicit "Search this area" outranks this: once the tourist has
    // pinned the search somewhere else, walking must not drag the results
    // back to wherever they happen to be standing.
    if (_customSearchCentre != null) return false;

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
    final centre = _customSearchCentre ?? cameraCenter;
    _isFetchingPins = true;
    try {
      final results = await _placesService.fetchNearbyPlaces(
        center: centre,
        radiusKm: searchRadiusKm,
      );
      _resultsCentre = centre;
      _canSearchThisArea = false;
      // Nearest first: the results strip is a "where could I walk right now"
      // list, and the Places API returns them in its own relevance order.
      results.sort(
        (a, b) => distanceToPlaceMeters(a).compareTo(distanceToPlaceMeters(b)),
      );
      nearbyPlaces = results;
      selectedPlaceId = null;
      _setContentMessage(
        results.isEmpty ? MapErrorMessages.noPlacesFound : null,
        MapMessageAction.widenRadius,
      );
    } catch (_) {
      _setContentMessage(MapErrorMessages.mapLoadFailed, MapMessageAction.retry);
    } finally {
      // Recorded even when the call failed, so a tourist standing still after
      // a network error doesn't retry on every single GPS tick. The radius
      // chips and "Search this area" remain the manual retry paths.
      _lastPinFetchCenter = centre;
      _isFetchingPins = false;
    }
    notifyListeners();
  }

  /// Fed from [GoogleMap.onCameraMove]. Notifies only when the "Search this
  /// area" affordance actually appears or disappears — the camera callback runs
  /// on every frame of a drag, and rebuilding the screen that often for a
  /// boolean that rarely flips would undo the work spent keeping the map
  /// smooth.
  void updateMapCentre(LatLng centre) {
    _mapCentre = centre;
    final origin = _resultsCentre;
    if (origin == null) return;

    final drifted = Geolocator.distanceBetween(
          origin.latitude,
          origin.longitude,
          centre.latitude,
          centre.longitude,
        ) >
        MapConstants.searchThisAreaThresholdMeters;

    if (drifted != _canSearchThisArea) {
      _canSearchThisArea = drifted;
      notifyListeners();
    }
  }

  /// Re-runs UC-007 step 4 around wherever the tourist has panned to, so they
  /// can scout a neighbourhood before walking over to it.
  Future<void> searchThisArea() async {
    _customSearchCentre = _mapCentre;
    isLoading = true;
    notifyListeners();
    await renderNearbyPins();
    isLoading = false;
    notifyListeners();
  }

  /// Hands searching back to the tourist's own position — paired with the
  /// recentre button, so "take me back to me" also means "show me what's
  /// around me" rather than leaving stale pins from another neighbourhood.
  void resetSearchToCurrentLocation() {
    if (_customSearchCentre == null) return;
    _customSearchCentre = null;
    notifyListeners();
  }

  /// Straight-line metres from the tourist to [place] — shown on each result
  /// card so "2 km radius" turns into something concrete. Falls back to
  /// [double.infinity] before the first fix so sorting stays stable.
  double distanceToPlaceMeters(PlaceModel place) {
    final location = currentLocation;
    if (location == null) return double.infinity;
    return Geolocator.distanceBetween(
      location.latitude,
      location.longitude,
      place.latitude,
      place.longitude,
    );
  }

  /// UC-007 constraint C1: the 1 / 2 / 5 km radius chips.
  Future<void> setSearchRadius(double radiusKm) async {
    if (searchRadiusKm == radiusKm) return;
    searchRadiusKm = radiusKm;
    isLoading = true;
    notifyListeners();
    await renderNearbyPins();
    isLoading = false;
    notifyListeners();
  }

  /// Highlights a pin without leaving the map — the intermediate step between
  /// "there's something over there" and committing to a route for it.
  void selectPlace(PlaceModel? place) {
    if (selectedPlaceId == place?.placeId) return;
    selectedPlaceId = place?.placeId;
    notifyListeners();
  }

  /// Reads the persisted "already routed" ids. Call once at startup, alongside
  /// [loadMap] — deliberately separate from it, because the grey pins do not
  /// depend on a location permission and should still be right on a map the
  /// tourist opened with GPS switched off.
  Future<void> restoreRoutedPlaces() async {
    final List<String> saved;
    try {
      saved = await _routedPlacesStore.load();
    } catch (error) {
      // Best-effort, like the write: an unreadable preferences store costs the
      // tourist their grey pins, and must not throw out of app startup.
      debugPrint('Failed to restore routed places: $error');
      return;
    }
    if (_disposed || saved.isEmpty) return;
    // Union rather than replace: a route can resolve while this read is still
    // in flight, and that fresher mark must not be dropped on the floor.
    _routedPlaceIds.addAll(saved);
    _trimToCap();
    notifyListeners();
  }

  /// UC-M05: called once a walking journey to [placeId] has actually
  /// completed — GPS arrival verified — which is the point the place stops
  /// being "somewhere I might go" and becomes "somewhere I have been".
  ///
  /// Deliberately not called merely because a route was previewed, and not
  /// called for a journey that was started and then ended early: neither of
  /// those means the tourist actually went there.
  void markPlaceRouted(String placeId) {
    if (!_routedPlaceIds.add(placeId)) return;
    _trimToCap();
    notifyListeners();
    _persistRoutedPlaces();
  }

  /// Forgets every "already routed" place, on disk as well as in memory — the
  /// way out of a map where so much has gone grey it stops being useful.
  void clearRoutedPlaces() {
    if (_routedPlaceIds.isEmpty) return;
    _routedPlaceIds.clear();
    notifyListeners();
    _persistRoutedPlaces();
  }

  void _trimToCap() {
    final int excess =
        _routedPlaceIds.length - MapConstants.maxRememberedRoutedPlaces;
    if (excess <= 0) return;
    // Insertion-ordered, so the leading entries are the oldest marks.
    _routedPlaceIds.removeAll(_routedPlaceIds.take(excess).toList());
  }

  /// Fire-and-forget, matching [FavoritesController]: in-memory state is
  /// already correct and is what draws the pins, and the next mark rewrites
  /// the whole list anyway — so a failed write must not block or unwind the UI.
  Future<void> _persistRoutedPlaces() async {
    try {
      await _routedPlacesStore.save(_routedPlaceIds.toList(growable: false));
    } catch (error) {
      debugPrint('Failed to persist routed places: $error');
    }
  }

  /// Runs whatever [messageAction] currently offers, so the tourist fixes the
  /// problem from the banner instead of hunting for the right settings screen.
  Future<void> runMessageAction() async {
    switch (messageAction) {
      case MapMessageAction.openLocationSettings:
        await _locationService.openLocationSettings();
      case MapMessageAction.openAppSettings:
        await _locationService.openAppSettings();
      case MapMessageAction.widenRadius:
        await setSearchRadius(MapConstants.radiusOptions.last);
      case MapMessageAction.retry:
        await loadMap();
      case MapMessageAction.none:
        break;
    }
  }

  /// Label for [messageAction] — kept next to the behaviour so the wording and
  /// what the button does can't drift apart. Null means "offer no button".
  String? get messageActionLabel {
    switch (messageAction) {
      case MapMessageAction.openLocationSettings:
        return 'Turn on GPS';
      case MapMessageAction.openAppSettings:
        return 'Open settings';
      case MapMessageAction.widenRadius:
        return searchRadiusKm == MapConstants.radiusOptions.last
            ? null
            : 'Search ${MapConstants.radiusOptions.last.toStringAsFixed(0)} km';
      case MapMessageAction.retry:
        return 'Try again';
      case MapMessageAction.none:
        return null;
    }
  }

  /// Lets the tourist clear a message they've read, rather than waiting for
  /// the next GPS tick to decide for them.
  void dismissMessage() {
    _setGpsMessage(null);
    _setContentMessage(null);
    notifyListeners();
  }

  /// UC-009 steps 4-6 / A2: validates a tapped pin before it's allowed to
  /// become the route-summary destination.
  bool validateDestination(PlaceModel place) {
    final destination = LatLng(place.latitude, place.longitude);
    final isValid = _boundaryValidatorService.validateDestination(destination);
    _setContentMessage(
      isValid ? null : MapErrorMessages.outsidePenangDestination,
    );
    notifyListeners();
    return isValid;
  }

  @override
  void dispose() {
    _disposed = true;
    _locationSubscription?.cancel();
    _compassSubscription?.cancel();
    super.dispose();
  }
}
