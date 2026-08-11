import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../constants/map_constants.dart';
import '../controllers/map_controller.dart';
import '../models/place_model.dart';
import '../theme/app_theme.dart';
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
  const MapPanel({super.key});

  @override
  State<MapPanel> createState() => _MapPanelState();
}

class _MapPanelState extends State<MapPanel> {
  late final MapController _controller = MapController();
  GoogleMapController? _mapController;
  bool _hasCenteredOnUser = false;

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
              onMapCreated: (controller) => _mapController = controller,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              cameraTargetBounds: CameraTargetBounds(
                _controller.boundaryConstraint,
              ),
              minMaxZoomPreference: const MinMaxZoomPreference(10, 19),
              markers: _buildMarkers(),
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
                  _RadiusChips(controller: _controller),
                ],
              ),
            ),
            if (_controller.isLoading)
              const ColoredBox(
                color: Color(0x66000000),
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
    return _controller.nearbyPlaces.map((place) {
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
        color: AppColors.surface,
        borderRadius: AppRadius.smAll,
      ),
      child: Text(
        message,
        style: AppType.body.copyWith(color: Colors.white, fontSize: 13),
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
              backgroundColor: Colors.white,
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
      color: Colors.white,
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
