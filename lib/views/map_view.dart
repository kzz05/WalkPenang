import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../constants/map_constants.dart';
import '../constants/map_style.dart';
import '../controllers/map_controller.dart';
import '../models/place_model.dart';
import '../theme/app_theme.dart';
import '../utils/distance_format.dart';
import '../utils/location_puck_icon.dart';
import '../utils/place_marker_icon.dart';
import '../widgets/map/map_action_button.dart';
import '../widgets/map/zoom_controls.dart';
import 'route_summary_view.dart';

/// Screen for UC-007 (nearby pins), UC-008 (live location), and UC-009
/// (Penang boundary). Tapping a pin hands off to [RouteSummaryView] for
/// UC-M04 / UC-M05.
class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  late final MapController _controller = MapController();
  GoogleMapController? _mapController;
  bool _hasCenteredOnUser = false;

  /// Height of the results strip, shared by the strip itself and by whatever
  /// has to sit clear of it.
  static const double _resultsStripHeight = 152;

  /// Standing in for the built-in `myLocationEnabled` blue dot, which
  /// google_maps_flutter gives no control over — this custom marker is what
  /// lets the puck carry a compass-heading direction indicator. Loaded once;
  /// [Marker.rotation] then does the work on every heading update.
  BitmapDescriptor? _locationPuckIcon;

  /// One bitmap per pin variant, drawn once at startup rather than per marker
  /// — a 20-result search would otherwise rasterise 20 near-identical images
  /// on every refresh.
  final Map<(PlaceCategoryPin, bool), BitmapDescriptor> _pinIcons = {};

  /// Tracked from [GoogleMap.onCameraMove] so compass-mode rotation can spin
  /// the map around wherever it's currently centred/zoomed, instead of jumping
  /// back to some other target every time the heading updates.
  CameraPosition? _lastCameraPosition;

  /// Controls the results strip, so tapping a pin can scroll its card into
  /// view and vice versa.
  final PageController _resultsPageController = PageController(
    viewportFraction: 0.78,
  );

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _controller.loadMap();
    _loadMarkerIcons();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _resultsPageController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadMarkerIcons() async {
    final puck = await buildLocationPuckIcon(withAccuracyCone: true);
    final icons = <(PlaceCategoryPin, bool), BitmapDescriptor>{};
    for (final category in PlaceCategoryPin.values) {
      for (final selected in [false, true]) {
        icons[(category, selected)] = await buildPlacePinIcon(
          category: category,
          selected: selected,
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _locationPuckIcon = puck;
      _pinIcons.addAll(icons);
    });
  }

  /// UC-008 step 6: the first time a GPS fix lands, glide the camera to it
  /// once — after that the tourist is free to pan without the map fighting
  /// back on every location update. Also drives compass-mode rotation: once
  /// [MapController.isCompassModeEnabled] is on, every throttled heading
  /// update spins the camera to match without moving its target or zoom.
  void _onControllerChanged() {
    final location = _controller.currentLocation;
    if (!_hasCenteredOnUser && location != null && _mapController != null) {
      _hasCenteredOnUser = true;
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(location.latitude, location.longitude),
          MapConstants.defaultZoom,
        ),
      );
    }

    final heading = _controller.compassHeading;
    if (_controller.isCompassModeEnabled &&
        heading != null &&
        _mapController != null) {
      final base = _lastCameraPosition;
      // A short animation rather than a jump: the heading only updates every
      // few degrees, and stepping the camera straight there reads as a stutter.
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: base?.target ??
                (location != null
                    ? LatLng(location.latitude, location.longitude)
                    : MapConstants.georgeTownCenter),
            zoom: base?.zoom ?? MapConstants.defaultZoom,
            tilt: base?.tilt ?? 0,
            bearing: heading,
          ),
        ),
        duration: const Duration(milliseconds: 260),
      );
    }
  }

  /// Recentres on the tourist without leaving compass mode fighting a stale
  /// target — replaces the built-in `myLocationButtonEnabled` button, which
  /// only exists alongside the native blue dot this screen no longer uses.
  void _recentreOnUser() {
    final location = _controller.currentLocation;
    if (location == null || _mapController == null) return;
    _controller.resetSearchToCurrentLocation();
    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(location.latitude, location.longitude),
        MapConstants.defaultZoom,
      ),
    );
  }

  /// Picking a place out without committing to it: highlight its pin, bring
  /// its card to the front of the strip, and glide the map to it.
  void _highlightPlace(PlaceModel place, {bool scrollStrip = true}) {
    _controller.selectPlace(place);

    if (scrollStrip && _resultsPageController.hasClients) {
      final index = _controller.nearbyPlaces.indexWhere(
        (candidate) => candidate.placeId == place.placeId,
      );
      if (index >= 0) {
        _resultsPageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    }

    _mapController?.animateCamera(
      CameraUpdate.newLatLng(LatLng(place.latitude, place.longitude)),
      duration: const Duration(milliseconds: 320),
    );
  }

  /// UC-009 steps 4-6 / A2 -> UC-M04 step 1: validates the chosen pin, then
  /// hands off to the route summary screen.
  void _openRouteSummary(PlaceModel place) {
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final hasResults = _controller.nearbyPlaces.isNotEmpty;

          return Stack(
            children: [
              Positioned.fill(child: _buildMap(hasResults)),
              _buildTopOverlay(),
              Positioned(
                right: 12,
                bottom: (hasResults ? _resultsStripHeight : 0) + 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_controller.isCompassAvailable) ...[
                      MapActionButton(
                        icon: Icons.explore,
                        isActive: _controller.isCompassModeEnabled,
                        tooltip: 'Rotate map with compass',
                        onPressed: _controller.toggleCompassMode,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_controller.currentLocation != null) ...[
                      MapActionButton(
                        icon: Icons.my_location,
                        tooltip: 'Centre on my location',
                        onPressed: _recentreOnUser,
                      ),
                      const SizedBox(height: 12),
                    ],
                    ZoomControls(mapController: _mapController),
                  ],
                ),
              ),
              // UC-007 step 4, re-run on demand: once the tourist has panned
              // away from where the pins were fetched, the pins on screen no
              // longer answer "what's around here?" — this is the one control
              // that makes them answer it again.
              AnimatedPositioned(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOut,
                left: 0,
                right: 0,
                bottom: _controller.canSearchThisArea
                    ? (hasResults ? _resultsStripHeight : 0) + 20
                    : -80,
                child: Center(
                  child: MapActionButton(
                    icon: Icons.refresh,
                    label: 'Search this area',
                    tooltip: 'Find places where the map is centred',
                    onPressed: _controller.searchThisArea,
                  ),
                ),
              ),
              if (hasResults)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _ResultsStrip(
                    height: _resultsStripHeight,
                    controller: _resultsPageController,
                    places: _controller.nearbyPlaces,
                    selectedPlaceId: _controller.selectedPlaceId,
                    distanceOf: _controller.distanceToPlaceMeters,
                    onPageChanged: (place) =>
                        _highlightPlace(place, scrollStrip: false),
                    onRoute: _openRouteSummary,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopOverlay() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _CircleBackButton(onPressed: () => Navigator.of(context).pop()),
                const SizedBox(width: 10),
                Expanded(
                  child: _HeaderChip(
                    isLoading: _controller.isLoading,
                    resultCount: _controller.nearbyPlaces.length,
                    radiusKm: _controller.searchRadiusKm,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _RadiusChips(controller: _controller),
            if (_controller.errorMessage != null) ...[
              const SizedBox(height: 10),
              _MessageBanner(
                message: _controller.errorMessage!,
                actionLabel: _controller.messageActionLabel,
                onAction: _controller.runMessageAction,
                onDismiss: _controller.dismissMessage,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMap(bool hasResults) {
    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: MapConstants.georgeTownCenter,
        zoom: MapConstants.defaultZoom,
      ),
      style: MapStyles.warm,
      onMapCreated: (controller) {
        setState(() => _mapController = controller);
        _onControllerChanged();
      },
      onCameraMove: (position) {
        _lastCameraPosition = position;
        _controller.updateMapCentre(position.target);
      },
      onTap: (_) => _controller.selectPlace(null),
      // The custom puck marker below replaces the built-in blue dot so it can
      // carry a compass-heading direction indicator, which myLocationEnabled
      // has no way to control.
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: true,
      // Compass mode drives rotation itself; leaving the two-finger rotate
      // gesture on at the same time would just fight it on every heading
      // update.
      rotateGesturesEnabled: !_controller.isCompassModeEnabled,
      zoomControlsEnabled: false,
      cameraTargetBounds: CameraTargetBounds(_controller.boundaryConstraint),
      minMaxZoomPreference: const MinMaxZoomPreference(10, 19),
      // Keeps the camera target — and Google's own attribution — clear of the
      // overlays stacked at the top and bottom of the screen.
      padding: EdgeInsets.only(
        top: 120,
        bottom: hasResults ? _resultsStripHeight : 0,
      ),
      markers: _buildMarkers(),
    );
  }

  Set<Marker> _buildMarkers() {
    final markers = _controller.nearbyPlaces.map((place) {
      final isSelected = place.placeId == _controller.selectedPlaceId;
      final icon = _pinIcons[(pinCategoryFor(place.category), isSelected)];

      return Marker(
        markerId: MarkerId(place.placeId),
        position: LatLng(place.latitude, place.longitude),
        icon: icon ?? BitmapDescriptor.defaultMarker,
        anchor: const Offset(0.5, 0.94),
        // Tapping a pin selects it rather than jumping straight to the route
        // screen — UC-007 step 7 is "view details", and the card that scrolls
        // into view carries the "Route" action for the step after that.
        onTap: () => _highlightPlace(place),
        zIndexInt: isSelected ? 3 : 2,
      );
    }).toSet();

    // UC-008: stands in for the built-in blue dot, rotated to the tourist's
    // live compass heading (falls back to pointing "up"/north until the first
    // sensor reading lands).
    final location = _controller.currentLocation;
    if (location != null && _locationPuckIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(location.latitude, location.longitude),
          icon: _locationPuckIcon!,
          anchor: const Offset(0.5, 0.5),
          rotation: _controller.compassHeading ?? 0,
          flat: true,
          zIndexInt: 1,
        ),
      );
    }

    return markers;
  }
}

/// Floating back control, replacing the app bar so the map can run full-bleed
/// behind the overlays.
class _CircleBackButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _CircleBackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: const Color(0x33000000),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.all(11),
          child: Icon(Icons.arrow_back, color: AppColors.onPrimary, size: 22),
        ),
      ),
    );
  }
}

/// Says what the map is currently showing — and, while UC-007 step 4 is still
/// in flight, that it's working on it. Replaces the full-screen dark spinner,
/// which blocked the map the tourist had already been given.
class _HeaderChip extends StatelessWidget {
  final bool isLoading;
  final int resultCount;
  final double radiusKm;

  const _HeaderChip({
    required this.isLoading,
    required this.resultCount,
    required this.radiusKm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.mdAll,
        boxShadow: [
          BoxShadow(color: Color(0x26000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          if (isLoading)
            const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          else
            const Icon(Icons.place_outlined, size: 17, color: AppColors.primary),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              isLoading
                  ? 'Finding places nearby…'
                  : '$resultCount place${resultCount == 1 ? '' : 's'} within '
                      '${radiusKm.toStringAsFixed(0)} km',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.body.copyWith(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// UC-007 A2 / UC-008 A2 / UC-009 A1-A2 — one banner, whichever message the
/// controller currently has queued, dismissible so it can't sit in the way of
/// the map after it's been read.
///
/// Where the alternative flow ends in an instruction ("enable it in your
/// device settings", "try increasing your search radius"), the banner carries
/// the button that does it — a tourist standing on a street corner shouldn't
/// have to go hunting through Android settings to act on an error message.
class _MessageBanner extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback onAction;
  final VoidCallback onDismiss;

  const _MessageBanner({
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.smAll,
        boxShadow: [
          BoxShadow(color: Color(0x26000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  style: AppType.body.copyWith(color: Colors.white, fontSize: 13),
                ),
                if (actionLabel != null) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.mdAll,
                      ),
                    ),
                    child: Text(
                      actionLabel!,
                      style: AppType.button.copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            tooltip: 'Dismiss',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, color: AppColors.onSurfaceMuted, size: 18),
          ),
        ],
      ),
    );
  }
}

/// UC-007 constraint C1: the 1 / 2 / 5 km radius chips, drawn from the app's
/// own tokens rather than Material's stock [ChoiceChip] so they match the
/// floating controls around them.
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
            child: _RadiusChip(
              label: '${radius.toStringAsFixed(0)} km',
              isSelected: controller.searchRadiusKm == radius,
              onTap: () => controller.setSearchRadius(radius),
            ),
          ),
      ],
    );
  }
}

class _RadiusChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _RadiusChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.primary : Colors.white,
      borderRadius: AppRadius.mdAll,
      elevation: 2,
      shadowColor: const Color(0x33000000),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            label,
            style: AppType.monoValue.copyWith(
              color: isSelected ? AppColors.onPrimary : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// UC-007 step 7: the swipeable strip of results under the map. Swiping a card
/// highlights its pin and glides the map to it, so browsing the list and
/// browsing the map are the same gesture.
class _ResultsStrip extends StatelessWidget {
  final double height;
  final PageController controller;
  final List<PlaceModel> places;
  final String? selectedPlaceId;
  final double Function(PlaceModel) distanceOf;
  final ValueChanged<PlaceModel> onPageChanged;
  final ValueChanged<PlaceModel> onRoute;

  const _ResultsStrip({
    required this.height,
    required this.controller,
    required this.places,
    required this.selectedPlaceId,
    required this.distanceOf,
    required this.onPageChanged,
    required this.onRoute,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: PageView.builder(
        controller: controller,
        padEnds: false,
        onPageChanged: (index) => onPageChanged(places[index]),
        itemCount: places.length,
        itemBuilder: (context, index) {
          final place = places[index];
          return Padding(
            padding: EdgeInsets.fromLTRB(12, 8, index == places.length - 1 ? 12 : 0, 16),
            child: _PlaceCard(
              place: place,
              distanceMeters: distanceOf(place),
              isSelected: place.placeId == selectedPlaceId,
              onRoute: () => onRoute(place),
            ),
          );
        },
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final PlaceModel place;
  final double distanceMeters;
  final bool isSelected;
  final VoidCallback onRoute;

  const _PlaceCard({
    required this.place,
    required this.distanceMeters,
    required this.isSelected,
    required this.onRoute,
  });

  @override
  Widget build(BuildContext context) {
    final isFood = place.category == 'food';
    final accent = isFood
        ? AppColors.foodPin
        : place.category == 'attraction'
            ? AppColors.attractionPin
            : AppColors.otherPin;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.smAll,
        border: Border.all(
          color: isSelected ? accent : Colors.transparent,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x2B000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isFood ? Icons.restaurant : Icons.photo_camera,
                  size: 13,
                  color: accent,
                ),
                const SizedBox(width: 6),
                Text(
                  isFood ? 'FOOD' : 'ATTRACTION',
                  style: AppType.mono.copyWith(color: accent),
                ),
                const Spacer(),
                if (place.isOpenNow)
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'OPEN',
                        style: AppType.mono.copyWith(color: AppColors.success),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              place.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppType.body.copyWith(fontSize: 15),
            ),
            const Spacer(),
            Row(
              children: [
                if (place.rating != null) ...[
                  const Icon(Icons.star_rounded, size: 15, color: AppColors.primary),
                  const SizedBox(width: 3),
                  Text(
                    place.rating!.toStringAsFixed(1),
                    style: AppType.monoValue,
                  ),
                  const SizedBox(width: 10),
                ],
                if (distanceMeters.isFinite)
                  Text(
                    formatDistanceMeters(distanceMeters),
                    style: AppType.monoValue.copyWith(color: AppColors.muted),
                  ),
                const Spacer(),
                // UC-M04 step 1: the one action that leaves this screen.
                TextButton(
                  onPressed: onRoute,
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.mdAll,
                    ),
                  ),
                  child: Text(
                    'Route',
                    style: AppType.button.copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
