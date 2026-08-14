import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../constants/map_constants.dart';
import '../controllers/route_summary_controller.dart';
import '../models/lat_lng.dart';
import '../models/lat_lng_mapbox.dart';
import '../models/place_model.dart';
import '../theme/app_theme.dart';

/// Screen for UC-M04 (distance/time) and UC-M05 (launch navigation), both
/// extending UC-M06 (Request Map Service).
class RouteSummaryView extends StatefulWidget {
  final PlaceModel destination;
  final LatLng origin;

  const RouteSummaryView({
    super.key,
    required this.destination,
    required this.origin,
  });

  @override
  State<RouteSummaryView> createState() => _RouteSummaryViewState();
}

class _RouteSummaryViewState extends State<RouteSummaryView> {
  late final RouteSummaryController _controller = RouteSummaryController(
    destination: widget.destination,
  );

  MapboxMap? _mapboxMap;
  PolylineAnnotationManager? _polylineManager;
  PointAnnotationManager? _pinManager;

  /// The route is fetched once and never changes for this screen, so the
  /// annotations only ever need drawing once — but both the controller
  /// listener and onMapCreated can reach [_drawRoute], hence the guard.
  bool _hasDrawnRoute = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onRouteChanged);
    _controller.calculateRoute(widget.origin);
  }

  @override
  void dispose() {
    _controller.removeListener(_onRouteChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onRouteChanged() => _drawRoute();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Route Summary', style: AppType.heading),
        iconTheme: const IconThemeData(color: AppColors.onPrimary),
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Column(
            children: [
              Expanded(child: _buildMap()),
              _buildSummaryCard(context),
            ],
          );
        },
      ),
    );
  }

  /// UC-M04 step 5: shows the walking route as a polyline once the
  /// Directions API response has been decoded.
  ///
  /// The same Studio style and tilt as the map screen, so moving between the
  /// two doesn't feel like moving between two different apps.
  Widget _buildMap() {
    return MapWidget(
      key: const ValueKey('walkpenang_route_map'),
      styleUri: MapConstants.gamifiedStyleUri,
      viewport: CameraViewportState(
        center: widget.origin.toPoint,
        zoom: MapConstants.defaultZoom,
        pitch: MapConstants.gamifiedPitchDegrees,
      ),
      onMapCreated: _onMapCreated,
    );
  }

  /// Annotations can only be created once the platform view exists, and the
  /// Directions response may land either side of that — so both this and the
  /// controller listener call [_drawRoute], and whichever is second wins.
  Future<void> _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;
    await map.gestures.updateSettings(
      GesturesSettings(pitchEnabled: false, rotateEnabled: false),
    );
    _polylineManager = await map.annotations.createPolylineAnnotationManager();
    _pinManager = await map.annotations.createPointAnnotationManager();
    await _drawRoute();
  }

  Future<void> _drawRoute() async {
    final polylineManager = _polylineManager;
    final pinManager = _pinManager;
    final route = _controller.route;
    if (polylineManager == null || pinManager == null || _hasDrawnRoute) return;
    if (route == null || !route.routeFound) return;
    _hasDrawnRoute = true;

    await polylineManager.create(
      PolylineAnnotationOptions(
        geometry: LineString(
          coordinates: [
            for (final point in route.polylinePoints) point.toPoint.coordinates,
          ],
        ),
        // primaryDeep, not primary — primary is the building fill in the
        // Studio style, and the route line would disappear into it.
        lineColor: AppColors.primaryDeep.toARGB32(),
        lineWidth: 6.0,
        lineJoin: LineJoin.ROUND,
      ),
    );

    await pinManager.createMulti([
      PointAnnotationOptions(
        geometry: widget.origin.toPoint,
        image: await _sprite('assets/images/pin_origin.png'),
        iconAnchor: IconAnchor.BOTTOM,
      ),
      PointAnnotationOptions(
        geometry: LatLng(
          widget.destination.latitude,
          widget.destination.longitude,
        ).toPoint,
        image: await _sprite('assets/images/pin_destination.png'),
        iconAnchor: IconAnchor.BOTTOM,
      ),
    ]);

    await _mapboxMap?.flyTo(
      CameraOptions(
        center: widget.origin.toPoint,
        zoom: MapConstants.defaultZoom,
        pitch: MapConstants.gamifiedPitchDegrees,
      ),
      MapAnimationOptions(duration: 800),
    );
  }

  Future<Uint8List> _sprite(String asset) async =>
      (await rootBundle.load(asset)).buffer.asUint8List();

  Widget _buildSummaryCard(BuildContext context) {
    if (_controller.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    // UC-M04 A1 / A2: no route found and lost connection both land here —
    // the controller has already picked the right message for either case.
    if (_controller.errorMessage != null && _controller.route == null) {
      return _buildErrorCard(context, _controller.errorMessage!);
    }

    final route = _controller.route;
    if (route == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.destination.name,
            style: AppType.heading.copyWith(color: AppColors.onSurface),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatBlock(
                label: 'distance',
                value: '${route.distanceKm.toStringAsFixed(1)} km',
              ),
              const SizedBox(width: 24),
              _StatBlock(
                label: 'walking time',
                value: '${route.durationMinutes} min',
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // UC-M04 A3: cancel just returns to the map, no side effects.
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.mdAll,
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: AppType.button.copyWith(color: AppColors.onSurface),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // UC-M05 step 1.
              Expanded(
                child: ElevatedButton(
                  onPressed: _controller.launchNavigation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.mdAll,
                    ),
                  ),
                  child: Text('Navigate', style: AppType.button),
                ),
              ),
            ],
          ),
          // UC-M05 A1 / A3: navigation-launch failures surface here, next to
          // the button that triggered them, instead of replacing the card.
          if (_controller.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _controller.errorMessage!,
              style: AppType.body.copyWith(
                color: AppColors.primary,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      // A failure reads as an error panel rather than the sand emphasis fill,
      // matching how every other module surfaces one.
      decoration: const BoxDecoration(
        color: AppColors.dangerTint,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: AppType.body.copyWith(color: AppColors.danger)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.danger),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.mdAll,
                ),
              ),
              child: Text(
                'Back to map',
                style: AppType.button.copyWith(color: AppColors.danger),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;

  const _StatBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppType.mono.copyWith(color: AppColors.onSurfaceMuted),
        ),
        const SizedBox(height: 4),
        Text(value, style: AppType.stat.copyWith(color: AppColors.onSurface)),
      ],
    );
  }
}
