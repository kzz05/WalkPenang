import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/transport_mode.dart';
import '../controllers/route_summary_controller.dart';
import '../models/place_model.dart';
import '../models/route_result.dart';
import '../theme/app_theme.dart';
import '../utils/duration_format.dart';
import '../widgets/map/zoom_controls.dart';
import 'navigation_view.dart';

/// Screen for UC-M04 (distance/time) and UC-M05 (in-app turn-by-turn
/// navigation), both extending UC-M06 (Request Map Service).
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
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _controller.calculateRoute(widget.origin);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// UC-M05 step 2: pushes the in-app turn-by-turn view for whichever mode
  /// is selected, reusing the route already fetched for UC-M04 rather than
  /// re-requesting it.
  void _startNavigation(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NavigationView(
          route: _controller.route!,
          destination: widget.destination,
          origin: widget.origin,
          mode: _controller.selectedMode,
        ),
      ),
    );
  }

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
  Widget _buildMap() {
    final route = _controller.route;
    final destLatLng = LatLng(
      widget.destination.latitude,
      widget.destination.longitude,
    );

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: widget.origin, zoom: 14),
          onMapCreated: (controller) => setState(() => _mapController = controller),
          zoomControlsEnabled: false,
          polylines: route != null && route.routeFound
              ? {
                  Polyline(
                    polylineId: const PolylineId('route'),
                    points: route.polylinePoints,
                    color: AppColors.primary,
                    width: 5,
                  ),
                }
              : {},
          markers: {
            Marker(markerId: const MarkerId('origin'), position: widget.origin),
            Marker(
              markerId: MarkerId(widget.destination.placeId),
              position: destLatLng,
            ),
          },
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: ZoomControls(mapController: _mapController),
        ),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: _ModeTabs(controller: _controller),
        ),
      ],
    );
  }

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
                label: '${_controller.selectedMode.shortLabel.toLowerCase()} time',
                value: formatEtaMinutes(route.durationMinutes),
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
              // UC-M05 step 1: hands the fetched route off to in-app
              // turn-by-turn navigation instead of an external app.
              Expanded(
                child: ElevatedButton(
                  onPressed: route.routeFound
                      ? () => _startNavigation(context)
                      : null,
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
          // UC-M04 A1: shown here (rather than the full error card) when a
          // `notFound` result still carries a non-null route.
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

/// UC-M04 mode comparison: Walk / Drive / Bus tabs, each showing its own
/// ETA so the tourist can pick a mode before tapping "Navigate" — mirrors
/// Google Maps' own mode-comparison strip.
class _ModeTabs extends StatelessWidget {
  final RouteSummaryController controller;
  const _ModeTabs({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final mode in TransportMode.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_modeIcon(mode), size: 16, color: AppColors.onPrimary),
                    const SizedBox(width: 6),
                    Text(_modeLabel(mode)),
                  ],
                ),
                selected: controller.selectedMode == mode,
                selectedColor: AppColors.primary,
                backgroundColor: Colors.white,
                labelStyle: AppType.monoValue,
                onSelected: (_) => controller.selectMode(mode),
              ),
            ),
        ],
      ),
    );
  }

  IconData _modeIcon(TransportMode mode) {
    switch (mode) {
      case TransportMode.walking:
        return Icons.directions_walk;
      case TransportMode.driving:
        return Icons.directions_car;
      case TransportMode.publicTransport:
        return Icons.directions_bus;
    }
  }

  /// shortLabel, not label: three chips share one row, and "Public
  /// Transport · 12 min" does not fit. The long form belongs to the Walking
  /// module's full-width mode cards.
  String _modeLabel(TransportMode mode) {
    final RouteResult? route = controller.routesByMode[mode];
    if (route == null) return mode.shortLabel;
    if (!route.routeFound) return '${mode.shortLabel} · --';
    return '${mode.shortLabel} · ${formatEtaMinutes(route.durationMinutes)}';
  }
}
