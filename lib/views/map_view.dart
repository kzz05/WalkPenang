import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../constants/map_constants.dart';
import '../controllers/map_controller.dart';
import '../models/place_model.dart';
import '../theme/app_theme.dart';
import '../utils/location_puck_icon.dart';
import '../widgets/map/zoom_controls.dart';
import 'route_summary_view.dart';

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
  /// Dropped into the top overlay row, to the right of the radius chips.
  ///
  /// HomeView passes its account button here so the button and the chips
  /// share one row over the map, instead of the button living in a bar of its
  /// own above it. Null for [MapView], which has an AppBar already.
  final Widget? topBarTrailing;

  const MapPanel({super.key, this.topBarTrailing});

  @override
  State<MapPanel> createState() => _MapPanelState();
}

class _MapPanelState extends State<MapPanel> {
  late final MapController _controller = MapController();
  GoogleMapController? _mapController;
  bool _hasCenteredOnUser = false;

  /// Standing in for the built-in `myLocationEnabled` blue dot, which
  /// google_maps_flutter gives no control over — this custom marker is what
  /// lets the puck carry a compass-heading direction indicator. Loaded once;
  /// [Marker.rotation] then does the work on every heading update.
  BitmapDescriptor? _locationPuckIcon;

  /// Tracked from [GoogleMap.onCameraMove] so compass-mode rotation can spin
  /// the map around wherever it's currently centred/zoomed, instead of
  /// jumping back to some other target every time the heading updates.
  CameraPosition? _lastCameraPosition;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _controller.loadMap();
    _loadLocationPuckIcon();
  }

  Future<void> _loadLocationPuckIcon() async {
    final icon = await buildLocationPuckIcon(withAccuracyCone: true);
    if (!mounted) return;
    setState(() => _locationPuckIcon = icon);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  /// UC-008 step 6: the first time a GPS fix lands, glide the camera to it
  /// once — after that the tourist is free to pan without the map fighting
  /// back on every location update.
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

    // Compass mode: spin the camera to match the heading without moving its
    // target or zoom, so the tourist keeps whatever they had panned to.
    final heading = _controller.compassHeading;
    if (_controller.isCompassModeEnabled &&
        heading != null &&
        _mapController != null) {
      final base = _lastCameraPosition;
      _mapController!.moveCamera(
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
      );
    }
  }

  /// Recentres on the tourist without leaving compass mode fighting a stale
  /// target — replaces the built-in `myLocationButtonEnabled` button, which
  /// only exists alongside the native blue dot this screen no longer uses.
  void _recentreOnUser() {
    final location = _controller.currentLocation;
    if (location == null || _mapController == null) return;
    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(location.latitude, location.longitude),
        MapConstants.defaultZoom,
      ),
    );
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
            GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: MapConstants.georgeTownCenter,
                zoom: MapConstants.defaultZoom,
              ),
              onMapCreated: (controller) {
                // Deliberately not wrapped in setState: rebuilding the
                // platform view from its own creation callback is what the
                // rebuild-storm fix removed. The AnimatedBuilder above
                // rebuilds on the next controller notification anyway, which
                // is when ZoomControls picks the instance up.
                _mapController = controller;
                // A fix can land before the platform view finishes creating,
                // in which case _onControllerChanged saw a null _mapController
                // and skipped centring. Retry here so the camera still
                // reaches the tourist whichever of the two arrives first.
                _onControllerChanged();
              },
              onCameraMove: (position) => _lastCameraPosition = position,
              // The custom puck marker in _buildMarkers replaces the built-in
              // blue dot so it can carry a compass-heading direction
              // indicator, which myLocationEnabled has no way to control.
              // hasLocationPermission still gates it: without the permission
              // there is no fix to draw a puck for.
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              compassEnabled: true,
              // Compass mode drives rotation itself; leaving the two-finger
              // rotate gesture on at the same time would just fight it on
              // every heading update.
              rotateGesturesEnabled: !_controller.isCompassModeEnabled,
              zoomControlsEnabled: false,
              cameraTargetBounds: CameraTargetBounds(
                _controller.boundaryConstraint,
              ),
              minMaxZoomPreference: const MinMaxZoomPreference(10, 19),
              markers: _buildMarkers(),
            ),
            Positioned(
              right: 12,
              bottom: (_controller.nearbyPlaces.isNotEmpty ? 132 : 0) + 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_controller.isCompassAvailable)
                    _CompassModeButton(
                      isEnabled: _controller.isCompassModeEnabled,
                      onPressed: _controller.toggleCompassMode,
                    ),
                  if (_controller.currentLocation != null) ...[
                    const SizedBox(height: 12),
                    _RecentreButton(onPressed: _recentreOnUser),
                  ],
                  const SizedBox(height: 12),
                  ZoomControls(mapController: _mapController),
                ],
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Column(
                children: [
                  if (_controller.errorMessage != null)
                    _ErrorBanner(message: _controller.errorMessage!),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Scrollable so three chips plus the trailing button
                      // cannot overflow on a narrow phone — the chips give way
                      // rather than the button being pushed off screen.
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: _RadiusChips(controller: _controller),
                        ),
                      ),
                      if (widget.topBarTrailing != null) ...[
                        const SizedBox(width: 8),
                        widget.topBarTrailing!,
                      ],
                    ],
                  ),
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

  Set<Marker> _buildMarkers() {
    final markers = _controller.nearbyPlaces.map((place) {
      return Marker(
        markerId: MarkerId(place.placeId),
        position: LatLng(place.latitude, place.longitude),
        infoWindow: InfoWindow(
          title: place.name,
          snippet: place.address,
          onTap: () => _onPlaceSelected(place),
        ),
        icon: place.category == 'food'
            ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange)
            : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      );
    }).toSet();

    // UC-008: stands in for the built-in blue dot, rotated to the tourist's
    // live compass heading (falls back to pointing "up"/north until the
    // first sensor reading lands).
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

/// Toggles [MapController.isCompassModeEnabled] — filled while the map is
/// following the tourist's compass heading, outlined while north-up.
/// Mirrors [_RecentreButton]'s filled/outlined convention from the
/// navigation screen.
class _CompassModeButton extends StatelessWidget {
  final bool isEnabled;
  final VoidCallback onPressed;

  const _CompassModeButton({required this.isEnabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isEnabled ? const Color(0xFF4285F4) : Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            Icons.explore,
            color: isEnabled ? Colors.white : AppColors.onPrimary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// Recentres the camera on the tourist's live location — replaces the
/// built-in `myLocationButtonEnabled` button now that the map draws its own
/// puck marker instead of the native blue dot.
class _RecentreButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _RecentreButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Icon(Icons.my_location, color: AppColors.onPrimary, size: 22),
        ),
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
      height: 132,
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
