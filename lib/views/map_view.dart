import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../constants/map_constants.dart';
import '../controllers/map_controller.dart';
import '../models/lat_lng.dart';
import '../models/lat_lng_mapbox.dart';
import '../models/place_model.dart';
import '../theme/app_theme.dart';
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
  const MapPanel({super.key});

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

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _controller.loadMap();
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
  /// than merely looking compliant. Margins are in physical pixels, hence
  /// the devicePixelRatio conversion from the sheet's logical height.
  Future<void> _applyMapOrnaments() async {
    final map = _mapboxMap;
    if (map == null || !mounted) return;

    final density = MediaQuery.of(context).devicePixelRatio;
    final clearance = (_nearbyPlacesSheetHeight + 8) * density;

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

  Future<Uint8List> _sprite(String category) async {
    final asset = category == 'food'
        ? 'assets/images/pin_food.png'
        : 'assets/images/pin_attraction.png';
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
    if (places.isEmpty) return;

    final options = <PointAnnotationOptions>[];
    for (final place in places) {
      options.add(
        PointAnnotationOptions(
          geometry: LatLng(place.latitude, place.longitude).toPoint,
          image: await _sprite(place.category),
          iconSize: 1.0,
          iconAnchor: IconAnchor.BOTTOM,
        ),
      );
    }

    final created = await manager.createMulti(options);
    for (var i = 0; i < created.length; i++) {
      final annotation = created[i];
      if (annotation != null) _placesByAnnotationId[annotation.id] = places[i];
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// UC-009 steps 4-6 / A2 -> UC-M04 step 1: validates the tapped pin, then
  /// hands off to the route summary screen.
  void _onPlaceSelected(PlaceModel place) {
    if (!_controller.validateDestination(place)) return;

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
                child: _NearbyPlacesSheet(
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
            child: ChoiceChip(
              label: Text('${radius.toStringAsFixed(0)} km'),
              selected: controller.searchRadiusKm == radius,
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.card,
              labelStyle: AppType.monoValue,
              onSelected: (_) => controller.setSearchRadius(radius),
            ),
          ),
      ],
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
