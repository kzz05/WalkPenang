import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../constants/map_constants.dart';
import '../controllers/map_controller.dart';
import '../controllers/walking_controller.dart';
import '../models/lat_lng.dart';
import '../models/lat_lng_mapbox.dart';
import '../models/place_model.dart';
import '../models/transport_mode.dart';
import '../models/user_profile.dart';
import '../models/walking_route_summary.dart';
import '../services/favorites_store.dart';
import '../services/firestore_favorites_store.dart';
import '../services/map_service.dart';
import '../services/route_service.dart';
import '../theme/app_theme.dart';
import '../utils/reward_constants.dart';
import 'pre_walk_summary_view.dart';
import 'route_summary_view.dart';

/// Height of [_NearbyPlacesSheet]. Named because the Mapbox logo and
/// attribution have to be lifted clear of it — see [_applyMapOrnaments].
const double _nearbyPlacesSheetHeight = 132;

/// Screen for UC-007 (nearby pins), UC-008 (live location), and UC-009
/// (Penang boundary). Tapping a pin hands off to [RouteSummaryView] for
/// UC-M04 / UC-M05.
class MapView extends StatelessWidget {
  const MapView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Map & GPS', style: AppType.heading),
        iconTheme: const IconThemeData(color: AppColors.onPrimary),
      ),
      body: const MapPanel(),
    );
  }
}

/// The map itself, with no Scaffold of its own — pins (UC-007), live location
/// (UC-008) and the Penang boundary (UC-009). It owns its [MapController], so
/// it can be dropped into any parent. HomeView embeds it directly rather than
/// pushing a route, which is why this is split out from [MapView].
class MapPanel extends StatefulWidget {
  const MapPanel({super.key, this.profile});

  /// The signed-in tourist, passed straight through to the Walking module
  /// when a journey starts (US-W04 needs body weight for calories).
  ///
  /// Nullable because [MapView] and the debug entry points build the panel
  /// without one; the Proceed action is hidden when it is absent rather than
  /// pushing a screen that would show an empty calorie estimate.
  final UserProfile? profile;

  @override
  State<MapPanel> createState() => _MapPanelState();
}

class _MapPanelState extends State<MapPanel> {
  late final MapController _controller = MapController();
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pinManager;
  bool _hasCenteredOnUser = false;
  bool _puckEnabled = false;

  /// Pin sprites, decoded once and reused for every annotation. Mapbox wants
  /// raw bytes per annotation, so without this cache every pin refetch would
  /// re-read the same two PNGs off the asset bundle.
  final Map<String, Uint8List> _pinSprites = {};

  /// What [_syncPins] last drew. Mapbox annotations are imperative — unlike
  /// the old declarative `markers:` set there's no diffing for free, so this
  /// is how we tell "same places, no work to do" from "genuinely new results".
  List<String> _renderedPlaceIds = const [];

  /// Maps an annotation back to the place it was created for, so a tap can
  /// find its [PlaceModel]. Mapbox hands the tapped [PointAnnotation] to the
  /// callback and nothing else.
  final Map<String, PlaceModel> _placesByAnnotationId = {};

  /// The reverse lookup, so favouriting can replace one stop's marker without
  /// redrawing the layer.
  final Map<String, PointAnnotation> _annotationsByPlaceId = {};

  /// The stop the tourist has tapped, or null when the card is dismissed.
  PlaceModel? _selectedStop;

  /// Saved place ids. Uses [FavoritesStore] directly rather than
  /// [FavoritesController], which is typed to the Discovery module's `Place`;
  /// the store works on ids alone, so the map writes to the very same
  /// users/{uid}/favorites collection the Discovery favourites screen reads.
  final FavoritesStore _favorites = FirestoreFavoritesStore();
  Set<String> _favoriteIds = <String>{};

  /// Guards the Proceed button while the walking route is being calculated.
  bool _isPreparingJourney = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _controller.loadMap();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final ids = await _favorites.loadIds();
    if (!mounted) return;
    setState(() => _favoriteIds = ids);
    // Saved places fetched before the ids arrived are still wearing the plain
    // marker, so force a redraw once we know which are gold.
    _renderedPlaceIds = const [];
    _syncPins();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  /// UC-008 step 6: the first time a GPS fix lands, glide the camera to it
  /// once — after that the tourist is free to pan without the map fighting
  /// back on every location update.
  void _onControllerChanged() {
    final map = _mapboxMap;
    final location = _controller.currentLocation;

    if (!_hasCenteredOnUser && location != null && map != null) {
      _hasCenteredOnUser = true;
      map.flyTo(
        CameraOptions(
          center: LatLng(location.latitude, location.longitude).toPoint,
          zoom: MapConstants.defaultZoom,
          pitch: MapConstants.gamifiedPitchDegrees,
        ),
        MapAnimationOptions(duration: 1200),
      );
    }

    // Permission is granted asynchronously inside loadMap(), so the puck
    // usually can't be switched on until after the map was created.
    _applyLocationPuck();
    _syncPins();
  }

  /// Called once the platform view exists. Everything that used to be a
  /// `GoogleMap` constructor argument is an imperative call on [MapboxMap]
  /// instead, which is why it all lands here rather than in [build].
  Future<void> _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;

    // UC-007 constraint C2 / UC-009 step 3: replaces cameraTargetBounds.
    await map.setBounds(
      CameraBoundsOptions(
        bounds: _controller.boundaryConstraint.toCoordinateBounds(),
        minZoom: MapConstants.minZoom,
        maxZoom: MapConstants.maxZoom,
      ),
    );

    // The tilt is the look. Letting a two-finger drag flatten it back to a
    // top-down view would undo that on the first accidental gesture, so the
    // pitch gesture is off and the pitch is set by us alone.
    await map.gestures.updateSettings(
      GesturesSettings(pitchEnabled: false, rotateEnabled: false),
    );

    await _applyMapOrnaments();
    await _applyLocationPuck();

    _pinManager = await map.annotations.createPointAnnotationManager();
    _pinManager!.tapEvents(onTap: _onAnnotationTapped);

    // A GPS fix and the pin results can both land before the platform view
    // finishes creating, in which case _onControllerChanged found a null map
    // and skipped. Retry both here so whichever arrives first still wins.
    _onControllerChanged();
  }

  /// Mapbox draws its own scale bar, logo and attribution over the map.
  ///
  /// The scale bar goes: it defaults to imperial units, which is wrong for
  /// Malaysia, and it sits exactly where the radius chips do.
  ///
  /// The logo and attribution must **stay** — Mapbox's terms require both to
  /// be visible — but by default they sit at the bottom, behind the nearby
  /// places sheet. Lifting them clear of it keeps the map compliant rather
  /// than merely looking compliant.
  ///
  /// The margin is in the same logical pixels the sheet's height is measured
  /// in — no devicePixelRatio conversion. Scaling by density lifts the logo
  /// into the middle of the map on any device denser than 1x, where it both
  /// looks wrong and swallows taps meant for a stop.
  Future<void> _applyMapOrnaments() async {
    final map = _mapboxMap;
    if (map == null || !mounted) return;

    const clearance = _nearbyPlacesSheetHeight + 8;

    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await map.logo.updateSettings(LogoSettings(marginBottom: clearance));
    await map.attribution.updateSettings(
      AttributionSettings(marginBottom: clearance),
    );
  }

  /// UC-008 step 6: the live position marker, replacing `myLocationEnabled`.
  /// Still gated on the permission actually being granted — switching the
  /// puck on before the OS grants it makes the native SDK throw, exactly as
  /// the Google SDK did.
  Future<void> _applyLocationPuck() async {
    final map = _mapboxMap;
    if (map == null || _puckEnabled || !_controller.hasLocationPermission) {
      return;
    }
    _puckEnabled = true;

    await map.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        puckBearingEnabled: true,
        pulsingEnabled: true,
        pulsingColor: AppColors.primaryDeep.toARGB32(),
      ),
    );
  }

  /// UC-009 steps 4-6 / A2 -> UC-M04 step 1: validates the tapped pin, then
  /// hands off to the route summary screen.
  void _onAnnotationTapped(PointAnnotation annotation) {
    final place = _placesByAnnotationId[annotation.id];
    if (place != null) _onPlaceSelected(place);
  }

  /// Which marker a place gets: saved places are gold so they stand out from
  /// the rest at a glance, which is the whole point of saving one.
  String _assetFor(PlaceModel place) {
    if (_favoriteIds.contains(place.placeId)) {
      return 'assets/images/stop_favourite.png';
    }
    return place.category == 'food'
        ? 'assets/images/stop_food.png'
        : 'assets/images/stop_attraction.png';
  }

  Future<Uint8List> _sprite(String asset) async {
    final cached = _pinSprites[asset];
    if (cached != null) return cached;

    final bytes = (await rootBundle.load(asset)).buffer.asUint8List();
    _pinSprites[asset] = bytes;
    return bytes;
  }

  /// UC-007 step 6: draws one pin per result. Replaces the old `_buildMarkers`
  /// set — annotations are managed imperatively, so this clears and redraws
  /// rather than returning a value for the widget to render.
  ///
  /// Guarded on the place-id list because the controller notifies for reasons
  /// that have nothing to do with the pins (a boundary change, an error
  /// banner). Redrawing every annotation on each of those would churn the
  /// platform channel for no visible change.
  Future<void> _syncPins() async {
    final manager = _pinManager;
    if (manager == null) return;

    final places = _controller.nearbyPlaces;
    final ids = places.map((p) => p.placeId).toList();
    if (_listEquals(ids, _renderedPlaceIds)) return;
    _renderedPlaceIds = ids;

    await manager.deleteAll();
    _placesByAnnotationId.clear();
    _annotationsByPlaceId.clear();

    // Every marker has just been deleted, so a card left open would describe
    // a stop that is no longer on the map. This happens on its own: walking
    // half the search radius refetches the pins underneath an open card.
    final selected = _selectedStop;
    if (selected != null && !ids.contains(selected.placeId)) {
      setState(() => _selectedStop = null);
    }

    if (places.isEmpty) return;

    final options = <PointAnnotationOptions>[];
    for (final place in places) {
      options.add(
        PointAnnotationOptions(
          geometry: LatLng(place.latitude, place.longitude).toPoint,
          image: await _sprite(_assetFor(place)),
          iconSize: 0.9,
          iconAnchor: IconAnchor.BOTTOM,
        ),
      );
    }

    final created = await manager.createMulti(options);
    for (var i = 0; i < created.length; i++) {
      final annotation = created[i];
      if (annotation == null) continue;
      _placesByAnnotationId[annotation.id] = places[i];
      _annotationsByPlaceId[places[i].placeId] = annotation;
    }
  }

  /// Toggles a saved place and recolours just that stop.
  ///
  /// Deletes and recreates the annotation rather than setting
  /// `annotation.image` and calling `update()`. The SDK registers an
  /// annotation's image under an internal name when the annotation is created
  /// and does not re-register it on update, so the obvious version silently
  /// leaves the old sprite in place while every other piece of state says
  /// "saved".
  Future<void> _toggleFavorite(PlaceModel place) async {
    final wasSaved = _favoriteIds.contains(place.placeId);
    final next = Set<String>.of(_favoriteIds);
    if (wasSaved) {
      next.remove(place.placeId);
    } else {
      next.add(place.placeId);
    }
    setState(() => _favoriteIds = next);

    // One id, never the whole set: this screen's snapshot was loaded at init
    // and the Discovery feed writes to the same store, so a bulk save here
    // would delete anything saved over there since.
    await (wasSaved
        ? _favorites.removeId(place.placeId)
        : _favorites.addId(place.placeId));

    final manager = _pinManager;
    final old = _annotationsByPlaceId[place.placeId];
    if (manager == null || old == null) return;

    await manager.delete(old);
    _placesByAnnotationId.remove(old.id);

    final replacement = await manager.create(
      PointAnnotationOptions(
        geometry: LatLng(place.latitude, place.longitude).toPoint,
        image: await _sprite(_assetFor(place)),
        iconSize: 0.9,
        iconAnchor: IconAnchor.BOTTOM,
      ),
    );
    _annotationsByPlaceId[place.placeId] = replacement;
    _placesByAnnotationId[replacement.id] = place;
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// UC-009 steps 4-6 / A2: a tapped stop is validated against the Penang
  /// boundary, then raises its card. Selection no longer navigates straight
  /// to the route screen — the tourist chooses what to do with the place
  /// first (save it, see the route, or set off).
  void _onPlaceSelected(PlaceModel place) {
    if (!_controller.validateDestination(place)) return;
    setState(() => _selectedStop = place);

    // Lean the camera in. This is what makes a stop feel like somewhere you
    // walk up to rather than a row in a list.
    _mapboxMap?.flyTo(
      CameraOptions(
        center: LatLng(place.latitude, place.longitude).toPoint,
        zoom: 17,
        pitch: 60,
      ),
      MapAnimationOptions(duration: 700),
    );
  }

  /// UC-M04: the existing route summary, unchanged — distance, time, and the
  /// Navigate deep link (UC-M05).
  void _showRoute(PlaceModel place) {
    final origin = _controller.currentLocation;
    if (origin == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RouteSummaryView(
          destination: place,
          origin: LatLng(origin.latitude, origin.longitude),
        ),
      ),
    );
  }

  /// Hands the selected place to the Walking & Carbon module.
  ///
  /// This fills the integration contract [WalkingRouteSummary] documents on
  /// `destinationId` and its coordinates: "once that module supplies a real
  /// destination, this should be its PlaceModel.placeId, not a
  /// Walking-invented ID". Until now that module seeded a hardcoded
  /// WalkingRouteSummary.demo.
  ///
  /// The route is calculated here rather than in the Walking module because
  /// distance and duration are Map & GPS's to supply (FR-M03); carbon and
  /// calories are computed on top of them over there.
  Future<void> _proceed(PlaceModel place) async {
    final profile = widget.profile;
    final origin = _controller.currentLocation;
    if (profile == null || origin == null || _isPreparingJourney) return;

    setState(() => _isPreparingJourney = true);
    try {
      final route = await RouteService(MapService()).calculateWalkingRoute(
        origin: LatLng(origin.latitude, origin.longitude),
        destination: LatLng(place.latitude, place.longitude),
      );
      if (!mounted) return;

      if (!route.routeFound) {
        _controller.showRouteUnavailable();
        return;
      }

      final walking = WalkingController()
        // "Walk here" *is* the mode selection (UC-W01), so preselect it.
        // Without this, _selectedMode stays null and WalkingController gates
        // off every walking-only benefit: the preview would promise points
        // while reporting 0.00 kg CO2 saved and no calorie estimate.
        ..selectMode(TransportMode.walking)
        ..setUserProfile(profile)
        ..setRouteSummary(
          WalkingRouteSummary(
            destinationName: place.name,
            areaLabel: place.address ?? 'Penang',
            distanceKm: route.distanceKm,
            estimatedDuration: Duration(minutes: route.durationMinutes),
            // The points this journey would earn if walked, from the same
            // formula the Reward module applies on arrival, so the promise
            // and the award cannot disagree.
            rewardPoints: RewardPoints.forCheckInKm(
              distanceKm: route.distanceKm,
              transportMode: TransportMode.walking,
            ),
            rewardBadgeLabel: 'your next walking badge',
            destinationId: place.placeId,
            destinationLatitude: place.latitude,
            destinationLongitude: place.longitude,
          ),
        );

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PreWalkSummaryView(controller: walking),
        ),
      );
    } finally {
      if (mounted) setState(() => _isPreparingJourney = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Stack(
          children: [
            MapWidget(
              // Keyed so Flutter reuses the one platform view across rebuilds
              // instead of tearing down and recreating the map.
              key: const ValueKey('walkpenang_map'),
              styleUri: MapConstants.gamifiedStyleUri,
              viewport: CameraViewportState(
                center: MapConstants.georgeTownCenter.toPoint,
                zoom: MapConstants.defaultZoom,
                pitch: MapConstants.gamifiedPitchDegrees,
              ),
              onMapCreated: _onMapCreated,
            ),
            const _MapVignette(),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Column(
                children: [
                  if (_controller.errorMessage != null)
                    _ErrorBanner(message: _controller.errorMessage!),
                  const SizedBox(height: 8),
                  _RadiusChips(controller: _controller),
                ],
              ),
            ),
            if (_controller.isLoading)
              const ColoredBox(
                color: AppColors.scrim,
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                ),
              ),
            if (_controller.nearbyPlaces.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _selectedStop != null
                    ? _StopCard(
                        place: _selectedStop!,
                        isFavorite:
                            _favoriteIds.contains(_selectedStop!.placeId),
                        isPreparing: _isPreparingJourney,
                        canProceed: widget.profile != null,
                        onFavorite: () => _toggleFavorite(_selectedStop!),
                        onRoute: () => _showRoute(_selectedStop!),
                        onProceed: () => _proceed(_selectedStop!),
                        onClose: () => setState(() => _selectedStop = null),
                      )
                    : _NearbyPlacesSheet(
                        places: _controller.nearbyPlaces,
                        onSelected: _onPlaceSelected,
                      ),
              ),
          ],
        );
      },
    );
  }

}

/// Darkens the screen edges so the centre of the map reads as the focal
/// point. Cheap, purely decorative, and does a surprising amount of the
/// game-screen feel on its own. [IgnorePointer] so it never eats a pan or a
/// pin tap.
class _MapVignette extends StatelessWidget {
  const _MapVignette();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            radius: 0.9,
            colors: [Color(0x00000000), Color(0x26000000)],
            stops: [0.55, 1.0],
          ),
        ),
        child: SizedBox.expand(),
      ),
    );
  }
}

/// UC-007 constraint C1 / UC-009 A1 / UC-008 A2 — one banner, whichever
/// message the controller currently has queued.
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.dangerTint,
        borderRadius: AppRadius.smAll,
      ),
      child: Text(
        message,
        style: AppType.body.copyWith(color: AppColors.danger, fontSize: 13),
      ),
    );
  }
}

/// UC-007 constraint C1: the 1 / 2 / 5 km radius chips.
class _RadiusChips extends StatelessWidget {
  final MapController controller;
  const _RadiusChips({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final radius in MapConstants.radiusOptions)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Builder(
              builder: (context) {
                final isSelected = controller.searchRadiusKm == radius;
                return ChoiceChip(
                  label: Text('${radius.toStringAsFixed(0)} km'),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.card,
                  // Set explicitly rather than left to the chip theme: passing
                  // labelStyle at all overrides the theme's
                  // secondaryLabelStyle, which is what would otherwise flip
                  // the label to white on the indigo fill. Without this the
                  // selected chip is dark ink on saturated indigo.
                  labelStyle: isSelected
                      ? AppType.monoValue
                          .copyWith(color: AppColors.onPrimaryFill)
                      : AppType.monoValue,
                  checkmarkColor: AppColors.onPrimaryFill,
                  onSelected: (_) => controller.setSearchRadius(radius),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// What a tapped stop offers. Replaces the old behaviour of jumping straight
/// to the route screen, so the tourist decides what the place is *for* before
/// committing to walking to it.
///
/// It occupies the same slot as [_NearbyPlacesSheet] rather than covering it:
/// two stacked sheets would bury the Mapbox attribution that
/// [_MapPanelState._applyMapOrnaments] just lifted clear, and the carousel is
/// no use while a specific place is being considered.
class _StopCard extends StatelessWidget {
  const _StopCard({
    required this.place,
    required this.isFavorite,
    required this.isPreparing,
    required this.canProceed,
    required this.onFavorite,
    required this.onRoute,
    required this.onProceed,
    required this.onClose,
  });

  final PlaceModel place;
  final bool isFavorite;
  final bool isPreparing;
  final bool canProceed;
  final VoidCallback onFavorite;
  final VoidCallback onRoute;
  final VoidCallback onProceed;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sm)),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                place.category == 'food' ? 'FOOD' : 'ATTRACTION',
                style: AppType.mono,
              ),
              const Spacer(),
              InkWell(
                onTap: onClose,
                child: const Icon(Icons.close, size: 20,
                    color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            place.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.heading,
          ),
          Text(
            place.rating != null
                ? '★ ${place.rating!.toStringAsFixed(1)}'
                : (place.isOpenNow ? 'Open now' : ' '),
            style: AppType.monoValue,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CardAction(
                  icon: isFavorite ? Icons.star : Icons.star_border,
                  label: isFavorite ? 'Saved' : 'Save',
                  emphasised: isFavorite,
                  onTap: onFavorite,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CardAction(
                  icon: Icons.route_outlined,
                  label: 'Route',
                  onTap: onRoute,
                ),
              ),
            ],
          ),
          if (canProceed) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isPreparing ? null : onProceed,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimaryFill,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: const StadiumBorder(),
                ),
                child: isPreparing
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onPrimaryFill,
                        ),
                      )
                    : Text(
                        'Walk here',
                        style: AppType.body
                            .copyWith(color: AppColors.onPrimaryFill),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.emphasised = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: emphasised ? AppColors.secondaryWash : AppColors.background,
          borderRadius: AppRadius.mdAll,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: emphasised ? AppColors.secondaryInk : AppColors.onPrimary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: emphasised
                  ? AppType.monoValue.copyWith(color: AppColors.secondaryInk)
                  : AppType.monoValue,
            ),
          ],
        ),
      ),
    );
  }
}

/// UC-007 step 7: the scrollable strip of results under the map, an
/// alternative to tapping pins directly.
class _NearbyPlacesSheet extends StatelessWidget {
  final List<PlaceModel> places;
  final ValueChanged<PlaceModel> onSelected;

  const _NearbyPlacesSheet({required this.places, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _nearbyPlacesSheetHeight,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sm)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: places.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final place = places[index];
          return _PlaceCard(place: place, onTap: () => onSelected(place));
        },
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final PlaceModel place;
  final VoidCallback onTap;

  const _PlaceCard({required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: AppRadius.smAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.smAll,
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                place.category == 'food' ? 'FOOD' : 'ATTRACTION',
                style: AppType.mono,
              ),
              const SizedBox(height: 4),
              Text(
                place.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppType.body.copyWith(fontSize: 14),
              ),
              const Spacer(),
              Text(
                place.rating != null
                    ? '★ ${place.rating!.toStringAsFixed(1)}'
                    : place.isOpenNow
                        ? 'Open now'
                        : ' ',
                style: AppType.monoValue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
