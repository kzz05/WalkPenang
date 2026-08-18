import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../constants/travel_mode.dart';
import '../controllers/navigation_controller.dart';
import '../models/place_model.dart';
import '../models/route_result.dart';
import '../models/route_step.dart';
import '../models/transit_details.dart';
import '../theme/app_theme.dart';
import '../utils/duration_format.dart';
import '../widgets/map/zoom_controls.dart';

/// UC-M05: live turn-by-turn navigation for the tourist's chosen travel
/// [mode] (walk, drive, or transit), rendered entirely on WalkPenang's own
/// map — no hand-off to an external app. Pushed from [RouteSummaryView]
/// with the [RouteResult] already fetched for UC-M04.
class NavigationView extends StatefulWidget {
  final RouteResult route;
  final PlaceModel destination;
  final LatLng origin;
  final TravelMode mode;

  const NavigationView({
    super.key,
    required this.route,
    required this.destination,
    required this.origin,
    required this.mode,
  });

  @override
  State<NavigationView> createState() => _NavigationViewState();
}

class _NavigationViewState extends State<NavigationView> {
  late final NavigationController _controller = NavigationController(
    route: widget.route,
    destination: widget.destination,
    initialPosition: widget.origin,
  );
  GoogleMapController? _mapController;
  BitmapDescriptor? _navigationArrowIcon;

  /// Whether the camera should keep re-centring on the tourist. Turned off
  /// the moment they drag the map to look around, and back on when they tap
  /// the recentre button — otherwise every GPS update would fight a manual
  /// pan and snap the map straight back.
  bool _isFollowingUser = true;

  /// True only while this widget's own [_followCamera] animation is in
  /// flight, so [_onCameraMoveStarted] can tell "we moved the camera" apart
  /// from "the tourist dragged the map" — both fire the same callback.
  bool _isProgrammaticCameraMove = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _loadNavigationArrowIcon();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  /// Keeps the camera centred on the tourist as they walk, mirroring a
  /// dedicated turn-by-turn app without ever leaving WalkPenang — unless
  /// they've manually panned away, in which case following is paused until
  /// they tap the recentre button.
  void _onControllerChanged() {
    if (_isFollowingUser) {
      _followCamera(_controller.currentPosition);
    }
    setState(() {});
  }

  Future<void> _followCamera(LatLng target) async {
    _isProgrammaticCameraMove = true;
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(target, _navigationZoom),
    );
    _isProgrammaticCameraMove = false;
  }

  /// Walking benefits from a close-in zoom to read street-level turns;
  /// driving and transit cover more ground per screen, so they pull back a
  /// little to keep upcoming manoeuvres/stops in view.
  double get _navigationZoom {
    switch (widget.mode) {
      case TravelMode.walking:
        return 18;
      case TravelMode.driving:
        return 16;
      case TravelMode.transit:
        return 15;
    }
  }

  void _onCameraMoveStarted() {
    if (!_isProgrammaticCameraMove && _isFollowingUser) {
      setState(() => _isFollowingUser = false);
    }
  }

  /// Snaps the camera back to the tourist and resumes auto-follow.
  void _recentreOnUser() {
    setState(() => _isFollowingUser = true);
    _followCamera(_controller.currentPosition);
  }

  /// Draws the navigation puck once at startup, rather than shipping it as
  /// an image asset — [NavigationController.currentHeading] then rotates
  /// this single bitmap through [Marker.rotation]. Sized and coloured to
  /// match Google Maps' own "blue dot" location puck rather than the
  /// oversized chevron this replaced.
  Future<void> _loadNavigationArrowIcon() async {
    // Drawn at 3x and then scaled back down via BitmapDescriptor.bytes'
    // width/height, so the puck stays crisp on high-DPI screens without
    // rendering huge on the map.
    const double targetSize = 26;
    const double exportScale = 3;
    const double canvasSize = targetSize * exportScale;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      const Rect.fromLTWH(0, 0, canvasSize, canvasSize),
    );
    const center = Offset(canvasSize / 2, canvasSize / 2);
    const navigationBlue = Color(0xFF4285F4); // Google Maps' location blue

    canvas.drawCircle(
      center,
      canvasSize / 2 - exportScale,
      Paint()..color = navigationBlue,
    );
    canvas.drawCircle(
      center,
      canvasSize / 2 - exportScale,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = exportScale * 1.5,
    );

    // Small white chevron pointing "up" — Marker.rotation handles pointing
    // it towards the tourist's actual course over ground.
    final arrow = Path()
      ..moveTo(center.dx, canvasSize * 0.28)
      ..lineTo(canvasSize * 0.68, canvasSize * 0.68)
      ..lineTo(center.dx, canvasSize * 0.54)
      ..lineTo(canvasSize * 0.32, canvasSize * 0.68)
      ..close();
    canvas.drawPath(arrow, Paint()..color = Colors.white);

    final image = await recorder.endRecording().toImage(
      canvasSize.toInt(),
      canvasSize.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (!mounted || bytes == null) return;

    setState(() {
      _navigationArrowIcon = BitmapDescriptor.bytes(
        bytes.buffer.asUint8List(),
        width: targetSize,
        height: targetSize,
      );
    });
  }

  /// UC-M05 A2: exits before arriving — pop straight back to the map screen
  /// with no GPS check-in or points, per constraint C2.
  void _exitNavigation() {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final destLatLng = LatLng(
      widget.destination.latitude,
      widget.destination.longitude,
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.origin,
              zoom: _navigationZoom,
            ),
            onMapCreated: (controller) => setState(() => _mapController = controller),
            onCameraMoveStarted: _onCameraMoveStarted,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            polylines: {
              Polyline(
                polylineId: const PolylineId('route'),
                points: widget.route.polylinePoints,
                color: AppColors.primary,
                width: 6,
              ),
            },
            markers: {
              Marker(
                markerId: MarkerId(widget.destination.placeId),
                position: destLatLng,
              ),
              // UC-M05: a Google Maps-style location puck standing in for
              // the plain "blue dot" — rotates to the tourist's live GPS
              // course over ground and moves with every location update.
              if (_navigationArrowIcon != null)
                Marker(
                  markerId: const MarkerId('navigation_arrow'),
                  position: _controller.currentPosition,
                  icon: _navigationArrowIcon!,
                  anchor: const Offset(0.5, 0.5),
                  rotation: _controller.currentHeading,
                  flat: true,
                ),
            },
          ),
          Positioned(
            right: 12,
            bottom: 170,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _RecentreButton(
                  isFollowing: _isFollowingUser,
                  onPressed: _recentreOnUser,
                ),
                const SizedBox(height: 12),
                ZoomControls(mapController: _mapController),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _InstructionBanner(
                    controller: _controller,
                    onExit: _exitNavigation,
                  ),
                  const Spacer(),
                  if (_controller.hasArrived)
                    _ArrivedCard(
                      destinationName: widget.destination.name,
                      onDone: _exitNavigation,
                    )
                  else
                    _ProgressBar(controller: _controller),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Recentres the camera on the tourist and resumes auto-follow after a
/// manual pan — filled blue while following (matches Google Maps' own
/// location-button states), outlined once the tourist has panned away.
class _RecentreButton extends StatelessWidget {
  final bool isFollowing;
  final VoidCallback onPressed;

  const _RecentreButton({required this.isFollowing, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isFollowing ? const Color(0xFF4285F4) : Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            Icons.navigation,
            color: isFollowing ? Colors.white : AppColors.onPrimary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// UC-M05 step 4: current manoeuvre + distance to it (or, for a `TRANSIT`
/// step, the bus/train to board), plus the exit control.
class _InstructionBanner extends StatelessWidget {
  final NavigationController controller;
  final VoidCallback onExit;

  const _InstructionBanner({required this.controller, required this.onExit});

  @override
  Widget build(BuildContext context) {
    final step = controller.currentStep;
    final transit = step?.transitDetails;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.smAll,
      ),
      child: Row(
        children: [
          Icon(
            transit != null ? _vehicleIcon(transit.vehicleType) : _maneuverIcon(step?.maneuver),
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: transit != null
                ? _TransitStepText(transit: transit)
                : _ManeuverStepText(step: step, controller: controller),
          ),
          IconButton(
            onPressed: onExit,
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  IconData _maneuverIcon(String? maneuver) {
    switch (maneuver) {
      case 'turn-left':
        return Icons.turn_left;
      case 'turn-right':
        return Icons.turn_right;
      case 'turn-sharp-left':
        return Icons.turn_sharp_left;
      case 'turn-sharp-right':
        return Icons.turn_sharp_right;
      case 'turn-slight-left':
        return Icons.turn_slight_left;
      case 'turn-slight-right':
        return Icons.turn_slight_right;
      case 'uturn-left':
      case 'uturn-right':
        return Icons.u_turn_left;
      case 'roundabout-left':
      case 'roundabout-right':
        return Icons.roundabout_left;
      case 'merge':
      case 'fork-left':
      case 'fork-right':
        return Icons.merge;
      default:
        return Icons.straight;
    }
  }

  IconData _vehicleIcon(String vehicleType) {
    switch (vehicleType) {
      case 'BUS':
      case 'INTERCITY_BUS':
      case 'TROLLEYBUS':
        return Icons.directions_bus;
      case 'SUBWAY':
      case 'HEAVY_RAIL':
      case 'RAIL':
      case 'COMMUTER_TRAIN':
      case 'HIGH_SPEED_TRAIN':
        return Icons.train;
      case 'TRAM':
      case 'CABLE_CAR':
      case 'GONDOLA_LIFT':
      case 'FUNICULAR':
        return Icons.tram;
      case 'FERRY':
        return Icons.directions_boat;
      default:
        return Icons.directions_bus;
    }
  }
}

/// Distance to the next manoeuvre + the turn-by-turn instruction text —
/// UC-M05's walking/driving instruction content.
class _ManeuverStepText extends StatelessWidget {
  final RouteStep? step;
  final NavigationController controller;

  const _ManeuverStepText({required this.step, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          step == null
              ? 'Head towards your destination'
              : '${controller.distanceToNextStepMeters.round()} m',
          style: AppType.stat.copyWith(color: Colors.white, fontSize: 20),
        ),
        if (step != null) ...[
          const SizedBox(height: 2),
          Text(
            step!.instruction,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppType.body.copyWith(color: AppColors.onSurfaceMuted),
          ),
        ],
      ],
    );
  }
}

/// UC-M05 transit navigation: which line to board, where to get off, and
/// when it departs — the bus/train equivalent of a turn instruction.
class _TransitStepText extends StatelessWidget {
  final TransitDetails transit;

  const _TransitStepText({required this.transit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Board ${transit.lineName}',
          style: AppType.stat.copyWith(color: Colors.white, fontSize: 20),
        ),
        const SizedBox(height: 2),
        Text(
          '${transit.departureStopName} → ${transit.arrivalStopName} · '
          '${transit.numStops} stop${transit.numStops == 1 ? '' : 's'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppType.body.copyWith(color: AppColors.onSurfaceMuted),
        ),
        if (transit.departureTimeText.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            'Departs ${transit.departureTimeText}',
            style: AppType.mono.copyWith(
              color: AppColors.onSurfaceMuted,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}

/// Live remaining distance/time, reading straight off [NavigationController]
/// rather than the static UC-M04 summary.
class _ProgressBar extends StatelessWidget {
  final NavigationController controller;
  const _ProgressBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final distanceKm = controller.remainingDistanceMeters / 1000;
    final minutes = (controller.remainingDurationSeconds / 60).ceil();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.smAll,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StatBlock(label: 'remaining', value: '${distanceKm.toStringAsFixed(1)} km'),
          _StatBlock(label: 'eta', value: formatEtaMinutes(minutes)),
        ],
      ),
    );
  }
}

/// UC-M05 step 7: shown once the tourist is within the check-in threshold
/// of the destination — arrival itself, not the check-in, is this module's
/// job (constraint C2 leaves check-in and points to Walking & Carbon).
class _ArrivedCard extends StatelessWidget {
  final String destinationName;
  final VoidCallback onDone;

  const _ArrivedCard({required this.destinationName, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.smAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'You\'ve arrived at $destinationName',
            style: AppType.heading.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
              ),
              child: Text('Done', style: AppType.button),
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
        Text(label, style: AppType.mono.copyWith(color: AppColors.onSurfaceMuted)),
        const SizedBox(height: 4),
        Text(value, style: AppType.stat.copyWith(color: Colors.white)),
      ],
    );
  }
}
