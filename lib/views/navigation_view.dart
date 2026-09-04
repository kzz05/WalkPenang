import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../constants/map_constants.dart';
import '../constants/map_style.dart';
import '../models/transport_mode.dart';
import '../controllers/navigation_controller.dart';
import '../models/place_model.dart';
import '../models/route_result.dart';
import '../models/route_step.dart';
import '../models/transit_details.dart';
import '../theme/app_theme.dart';
import '../utils/angle_utils.dart';
import '../utils/distance_format.dart';
import '../utils/duration_format.dart';
import '../utils/location_puck_icon.dart';
import '../utils/place_marker_icon.dart';
import '../widgets/map/map_action_button.dart';
import '../widgets/map/zoom_controls.dart';

/// UC-M05: live turn-by-turn navigation for the tourist's chosen travel
/// [mode] (walk, drive, or transit), rendered entirely on WalkPenang's own
/// map — no hand-off to an external app. Pushed from [RouteSummaryView] with
/// the [RouteResult] already fetched for UC-M04.
class NavigationView extends StatefulWidget {
  final RouteResult route;
  final PlaceModel destination;
  final LatLng origin;
  final TransportMode mode;

  /// Finishes the journey this navigation belongs to, straight from the
  /// arrival card. Supplied by route_summary_view when navigation was opened
  /// from inside a walking journey; null when it was opened from the route
  /// summary alone, where there is no journey to complete and the card keeps
  /// its plain "Done".
  final VoidCallback? onCompleteJourney;

  const NavigationView({
    super.key,
    required this.route,
    required this.destination,
    required this.origin,
    required this.mode,
    this.onCompleteJourney,
  });

  @override
  State<NavigationView> createState() => _NavigationViewState();
}

class _NavigationViewState extends State<NavigationView>
    with SingleTickerProviderStateMixin {
  late final NavigationController _controller = NavigationController(
    route: widget.route,
    destination: widget.destination,
    initialPosition: widget.origin,
  );

  GoogleMapController? _mapController;
  BitmapDescriptor? _puckIcon;
  BitmapDescriptor? _destinationIcon;

  // ── Between-fix interpolation ───────────────────────────────────────────
  //
  // GPS delivers a discrete fix roughly once a second; drawing the puck only
  // on those would make it teleport in one-second hops. [_glide] drives it
  // from where it was last drawn to the newest fix, so the marker and the
  // camera move continuously the way a dedicated navigation app does.

  late final AnimationController _glide = AnimationController(
    vsync: this,
    duration: MapConstants.maxNavigationInterpolation,
  )..addListener(_onGlideTick);

  /// Where the puck is drawn right now — an interpolated frame, not a fix.
  late LatLng _renderedPosition = widget.origin;
  double _renderedHeading = 0;

  /// The interpolated frame, published separately from [State.setState].
  ///
  /// Only the map layer listens to this, so the 25-a-second frames repaint the
  /// markers and nothing else. The instruction banner and the progress bar
  /// change once per *GPS fix*, and rebuilding them at frame rate would spend
  /// a great deal of trigonometry re-deriving numbers that hadn't moved.
  late final ValueNotifier<_PuckFrame> _puckFrame = ValueNotifier(
    _PuckFrame(widget.origin, 0),
  );

  /// The endpoints [_glide] interpolates between.
  late LatLng _glideFrom = widget.origin;
  late LatLng _glideTo = widget.origin;
  double _glideHeadingFrom = 0;
  double _glideHeadingTo = 0;

  /// Throttles how often an interpolated frame is pushed across the platform
  /// channel — see [MapConstants.navigationRenderInterval].
  DateTime _lastRenderAt = DateTime.fromMillisecondsSinceEpoch(0);

  // ── Camera follow state ─────────────────────────────────────────────────

  /// Whether the camera should keep re-centring on the tourist. Turned off
  /// the moment they drag the map to look around, and back on when they tap
  /// the recentre button — otherwise every position update would fight a
  /// manual pan and snap the map straight back.
  bool _isFollowingUser = true;

  /// Set from raw pointer events on the map. This — rather than
  /// [GoogleMap.onCameraMoveStarted] alone — is what tells a genuine pan
  /// apart from the camera moves this screen issues itself: the plugin fires
  /// the same callback for both, and gives no reason code to distinguish
  /// them, so the only reliable signal is whether a finger is on the map.
  bool _isUserTouchingMap = false;

  /// The tourist's own zoom level, tracked so a pinch-zoom survives the next
  /// position update instead of being reset to [_navigationZoom].
  double _followZoom = 0;

  /// The route lines, cached rather than rebuilt on every interpolated frame.
  /// Only the "already travelled" line ever changes, and only when the tourist
  /// crosses into a new step — rebuilding a few thousand [LatLng]s 25 times a
  /// second to produce an identical set would cost more than the map does.
  Set<Polyline> _polylines = const {};
  int _polylinesForStepIndex = -1;

  @override
  void initState() {
    super.initState();
    _followZoom = _navigationZoom;
    _renderedHeading = _controller.currentHeading;
    _glideHeadingFrom = _renderedHeading;
    _glideHeadingTo = _renderedHeading;
    _puckFrame.value = _PuckFrame(_renderedPosition, _renderedHeading);
    _controller.addListener(_onControllerChanged);
    _rebuildPolylines();
    _loadMarkerIcons();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _glide.dispose();
    _puckFrame.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  /// Draws the puck and destination pin once at startup rather than shipping
  /// them as image assets — [Marker.rotation] then does all the per-frame
  /// work on the one puck bitmap.
  Future<void> _loadMarkerIcons() async {
    final puck = await buildNavigationPuckIcon();
    final destination = await buildDestinationPinIcon();
    if (!mounted) return;
    setState(() {
      _puckIcon = puck;
      _destinationIcon = destination;
    });
  }

  /// A new GPS fix (or compass reading) landed: restart the glide from
  /// wherever the puck is currently drawn towards the new position, over
  /// roughly the interval the next fix is expected in.
  void _onControllerChanged() {
    if (!mounted) return;

    _glideFrom = _renderedPosition;
    _glideTo = _controller.currentPosition;
    _glideHeadingFrom = _renderedHeading;
    _glideHeadingTo = _controller.currentHeading;

    _glide
      ..duration = _interpolationDuration
      ..forward(from: 0);

    if (_controller.currentStepIndex != _polylinesForStepIndex) {
      _rebuildPolylines();
    }

    if (_controller.justArrived) {
      _controller.acknowledgeArrival();
      HapticFeedback.mediumImpact();
    }

    setState(() {});
  }

  /// Sized from the actual gap between the last two fixes so the puck reaches
  /// a position just as the next one arrives — clamped at both ends so a
  /// burst of fixes doesn't make it stutter and a long GPS gap doesn't leave
  /// it crawling half a minute behind the tourist.
  Duration get _interpolationDuration {
    final interval = _controller.fixInterval;
    if (interval < MapConstants.minNavigationInterpolation) {
      return MapConstants.minNavigationInterpolation;
    }
    if (interval > MapConstants.maxNavigationInterpolation) {
      return MapConstants.maxNavigationInterpolation;
    }
    return interval;
  }

  /// One interpolated frame: advance the drawn position/heading and, while
  /// following, carry the camera with it. Throttled so this costs ~25 platform
  /// calls a second instead of 60.
  void _onGlideTick() {
    if (!mounted) return;
    final now = DateTime.now();
    // The last frame always renders, throttle or not — dropping it would leave
    // the puck a few metres short of the fix it was heading for.
    final isFinalFrame = _glide.value >= 1.0 || !_glide.isAnimating;
    if (!isFinalFrame &&
        now.difference(_lastRenderAt) < MapConstants.navigationRenderInterval) {
      return;
    }
    _lastRenderAt = now;

    final t = _glide.value;
    // Position moves at a constant rate — the tourist does — while the
    // heading eases, so a sharp turn reads as a swing rather than a snap.
    _renderedPosition = lerpLatLng(_glideFrom, _glideTo, t);
    _renderedHeading = lerpDegrees(
      _glideHeadingFrom,
      _glideHeadingTo,
      Curves.easeOutCubic.transform(t),
    );
    _puckFrame.value = _PuckFrame(_renderedPosition, _renderedHeading);

    if (_isFollowingUser && !_isUserTouchingMap) {
      // moveCamera, not animateCamera: the position handed over is already an
      // interpolated frame, so asking the platform to animate towards it as
      // well would layer a second easing curve on top and make the map swim.
      _mapController?.moveCamera(
        CameraUpdate.newCameraPosition(_followCameraPosition),
      );
    }
  }

  CameraPosition get _followCameraPosition => CameraPosition(
    target: _renderedPosition,
    zoom: _followZoom,
    // Heading-up rather than north-up: "turn left" is only easy to act on
    // when left on screen is left in real life.
    bearing: _renderedHeading,
    tilt: MapConstants.navigationCameraTilt,
  );

  /// Walking benefits from a close-in zoom to read street-level turns;
  /// driving and transit cover more ground per screen, so they pull back a
  /// little to keep upcoming manoeuvres/stops in view.
  double get _navigationZoom {
    switch (widget.mode) {
      case TransportMode.walking:
        return 18.5;
      case TransportMode.driving:
        return 17;
      case TransportMode.publicTransport:
        return 16;
    }
  }

  /// Decides, per camera frame, whether the tourist is *zooming* (which
  /// following can happily absorb) or *panning away* (which it can't).
  ///
  /// Both gestures fire the same callbacks, so the tell is the camera target:
  /// a pinch keeps it near the puck, a drag carries it off. Treating a zoom as
  /// a pan — which is what a naive "any gesture stops following" rule does —
  /// means the map abandons the tourist every time they look a little closer.
  void _onCameraMove(CameraPosition position) {
    if (!_isUserTouchingMap) return;

    // Their zoom, kept for the follow camera to reuse.
    _followZoom = position.zoom;
    if (!_isFollowingUser) return;

    final drift = Geolocator.distanceBetween(
      position.target.latitude,
      position.target.longitude,
      _renderedPosition.latitude,
      _renderedPosition.longitude,
    );
    if (drift > _panBreakThresholdMeters(position)) {
      setState(() => _isFollowingUser = false);
    }
  }

  /// The drift budget expressed on screen rather than on the ground: roughly
  /// [_panBreakThresholdPixels] of movement, whatever the zoom happens to be.
  /// A fixed metre threshold would be untouchable at street zoom and trigger
  /// on a stray finger at city zoom.
  static const double _panBreakThresholdPixels = 110;

  double _panBreakThresholdMeters(CameraPosition position) {
    final metresPerPixel = 156543.03392 *
        math.cos(position.target.latitude * math.pi / 180) /
        math.pow(2, position.zoom);
    return _panBreakThresholdPixels * metresPerPixel;
  }

  /// The +/- controls drive the follow camera's own zoom rather than the map
  /// directly, so a tap isn't undone by the next position frame.
  void _zoomBy(double levels) {
    final zoom = (_followZoom + levels).clamp(3.0, 20.0);
    setState(() => _followZoom = zoom);

    if (_isFollowingUser) {
      _mapController?.moveCamera(
        CameraUpdate.newCameraPosition(_followCameraPosition),
      );
    } else {
      _mapController?.animateCamera(
        CameraUpdate.zoomTo(zoom),
        duration: const Duration(milliseconds: 220),
      );
    }
  }

  /// Snaps the camera back to the tourist and resumes auto-follow, resetting
  /// the zoom to the mode's default in case they'd zoomed far out.
  void _recentreOnUser() {
    setState(() {
      _isFollowingUser = true;
      _followZoom = _navigationZoom;
    });
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(_followCameraPosition),
      duration: const Duration(milliseconds: 400),
    );
  }

  /// UC-M05 A1: exits before arriving — pop straight back to the map screen
  /// with no GPS check-in or points, per constraint C2.
  /// Pops this screen and nothing else.
  ///
  /// It used to pop twice, which suited the only stack it originally had —
  /// map, route summary, navigation — where leaving navigation meant
  /// returning to the map. It is now also pushed from inside a walking
  /// journey (map, route summary, pre-walk, journey flow, navigation), where
  /// the second pop tore JourneyFlowView off the stack and dumped the tourist
  /// back on the pre-walk screen mid-journey, with no way to complete it.
  ///
  /// A screen dismissing its own parent is the bug; whoever pushed this one
  /// decides what should happen afterwards. RouteSummaryView still pops
  /// itself when navigation returns, so the map flow is unchanged. This also
  /// makes the exit button behave exactly like the Android back gesture,
  /// which only ever popped once.
  void _exitNavigation() {
    Navigator.of(context).pop();
  }

  /// The exit control sits within reach of a thumb holding the phone, so it
  /// asks first. Arriving skips the question: at that point there is nothing
  /// left to lose.
  ///
  /// What it asks depends on whether a journey is running, because the two
  /// cases lose completely different things and the wording has to say which.
  /// Inside a journey this closes the directions and nothing else — the walk,
  /// its timer and its check-in all carry on, and directions reopen from the
  /// walking screen. The dialog used to say "End navigation?" and "no check-in
  /// will be recorded" in both cases, which described ending the *journey*:
  /// tourists read it as the walk being thrown away and stayed on a screen
  /// they wanted to leave.
  Future<void> _confirmExit() async {
    if (_controller.hasArrived) {
      _exitNavigation();
      return;
    }

    final inJourney = widget.onCompleteJourney != null;

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(inJourney ? 'Close directions?' : 'Stop navigation?'),
        content: Text(
          inJourney
              ? 'Your journey to ${widget.destination.name} keeps running — '
                  'the timer, your distance and your check-in are all '
                  'unaffected. You can reopen directions at any time.'
              : 'You will stop navigating to ${widget.destination.name} and '
                  'go back to the map. No journey is being recorded, so '
                  'nothing is lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              inJourney ? 'Stay in directions' : 'Keep going',
              style: AppType.button.copyWith(fontSize: 14),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              inJourney ? 'Close directions' : 'Stop navigation',
              style: AppType.button.copyWith(
                fontSize: 14,
                // Only destructive outside a journey, where it is the route
                // itself being given up. Colouring the in-journey action as a
                // warning is what made it read as "end the walk".
                color: inJourney ? null : AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldExit ?? false) _exitNavigation();
  }

  @override
  Widget build(BuildContext context) {
    final destLatLng = LatLng(
      widget.destination.latitude,
      widget.destination.longitude,
    );
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Scaffold(
      backgroundColor: const Color(0xFF14171A),
      body: Stack(
        children: [
          // Raw pointer events are the only dependable "the tourist is
          // touching the map" signal — the map's own callbacks can't tell a
          // finger apart from this screen's follow-camera updates.
          Listener(
            onPointerDown: (_) => _isUserTouchingMap = true,
            onPointerUp: (_) => _isUserTouchingMap = false,
            onPointerCancel: (_) => _isUserTouchingMap = false,
            child: ValueListenableBuilder<_PuckFrame>(
              valueListenable: _puckFrame,
              builder: (context, frame, _) => GoogleMap(
              initialCameraPosition: CameraPosition(
                target: widget.origin,
                zoom: _navigationZoom,
                tilt: MapConstants.navigationCameraTilt,
              ),
              style: MapStyles.night,
              onMapCreated: (controller) =>
                  setState(() => _mapController = controller),
              onCameraMove: _onCameraMove,
              // Shifting the camera target down-screen leaves most of the map
              // showing the road *ahead* rather than the road already walked.
              padding: EdgeInsets.only(
                top: screenHeight *
                    (2 * MapConstants.navigationPuckScreenAnchor - 1),
                bottom: 24,
              ),
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              polylines: _polylines,
              markers: _buildMarkers(destLatLng, frame),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 190,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                MapActionButton(
                  icon: Icons.navigation,
                  isActive: _isFollowingUser,
                  label: _isFollowingUser ? null : 'Re-centre',
                  tooltip: 'Follow my position',
                  onPressed: _recentreOnUser,
                ),
                const SizedBox(height: 12),
                ZoomControls(
                  mapController: _mapController,
                  isDark: true,
                  onZoomBy: _zoomBy,
                ),
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
                    onExit: _confirmExit,
                  ),
                  if (_controller.errorMessage != null) ...[
                    const SizedBox(height: 8),
                    _GpsWarningBanner(message: _controller.errorMessage!),
                  ],
                  const Spacer(),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    child: _controller.hasArrived
                        ? _ArrivedCard(
                            key: const ValueKey('arrived'),
                            destinationName: widget.destination.name,
                            onDone: _exitNavigation,
                            onCompleteJourney: widget.onCompleteJourney,
                          )
                        : _ProgressBar(
                            key: const ValueKey('progress'),
                            controller: _controller,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The route drawn as three stacked lines: a dark casing for contrast
  /// against the night map, the live route in the brand terracotta, and the
  /// already-covered stretch dimmed on top so progress is readable from the
  /// map alone.
  void _rebuildPolylines() {
    _polylinesForStepIndex = _controller.currentStepIndex;
    final travelled = _controller.travelledPolyline;

    _polylines = {
      Polyline(
        polylineId: const PolylineId('route_casing'),
        points: widget.route.polylinePoints,
        color: AppColors.routeCasing,
        width: 14,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        zIndex: 0,
      ),
      Polyline(
        polylineId: const PolylineId('route'),
        points: widget.route.polylinePoints,
        color: AppColors.primary,
        width: 9,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        zIndex: 1,
      ),
      if (travelled.isNotEmpty)
        Polyline(
          polylineId: const PolylineId('route_travelled'),
          points: travelled,
          color: AppColors.primary.withValues(alpha: 0.28),
          width: 9,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
          zIndex: 2,
        ),
    };
  }


  Set<Marker> _buildMarkers(LatLng destination, _PuckFrame frame) {
    return {
      Marker(
        markerId: MarkerId(widget.destination.placeId),
        position: destination,
        icon: _destinationIcon ?? BitmapDescriptor.defaultMarker,
        anchor: const Offset(0.5, 0.94),
      ),
      // UC-M05 step 4: the location puck, drawn at the interpolated position
      // and rotated to the tourist's live heading, so it glides with them
      // rather than hopping from fix to fix.
      if (_puckIcon != null)
        Marker(
          markerId: const MarkerId('navigation_puck'),
          position: frame.position,
          icon: _puckIcon!,
          anchor: const Offset(0.5, 0.5),
          // `flat` pins the marker to the map, so this rotation is measured
          // against the map's north — pointing the arrow along the tourist's
          // real-world heading. While the camera is bearing-locked to that
          // same heading it lands pointing straight up the screen; once they
          // pan away it keeps pointing the true way instead of lying.
          rotation: frame.heading,
          flat: true,
          zIndexInt: 2,
        ),
    };
  }
}

/// UC-M05 step 4: the current manoeuvre and how far to it (or, for a
/// `TRANSIT` step, which bus/train to board), with the manoeuvre after it
/// previewed underneath and the exit control on the right.
class _InstructionBanner extends StatelessWidget {
  final NavigationController controller;
  final VoidCallback onExit;

  const _InstructionBanner({required this.controller, required this.onExit});

  @override
  Widget build(BuildContext context) {
    final step = controller.currentStep;
    final transit = step?.transitDetails;
    final next = controller.nextStep;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x59000000), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  transit != null
                      ? vehicleIcon(transit.vehicleType)
                      : maneuverIcon(step?.maneuver),
                  color: AppColors.onPrimary,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: transit != null
                    ? _TransitStepText(transit: transit)
                    : _ManeuverStepText(step: step, controller: controller),
              ),
              IconButton(
                onPressed: onExit,
                tooltip: 'Exit navigation',
                icon: const Icon(Icons.close, color: AppColors.onSurfaceMuted),
              ),
            ],
          ),
          if (step != null) ...[
            const Divider(height: 18, thickness: 1, color: Color(0x1FFFFFFF)),
            Row(
              children: [
                Text(
                  next == null ? 'LAST' : 'THEN',
                  style: AppType.mono.copyWith(color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                if (next != null) ...[
                  Icon(
                    next.transitDetails != null
                        ? vehicleIcon(next.transitDetails!.vehicleType)
                        : maneuverIcon(next.maneuver),
                    color: AppColors.onSurfaceMuted,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    next == null
                        ? 'Final stretch to your destination'
                        : next.transitDetails != null
                            ? 'Board ${next.transitDetails!.lineName}'
                            : next.instruction,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body.copyWith(
                      color: AppColors.onSurfaceMuted,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // "Where am I in the route?" — the one question a single
                // turn instruction can never answer on its own.
                Text(
                  '${controller.currentStepIndex + 1}/'
                  '${controller.route.steps.length}',
                  style: AppType.mono.copyWith(color: AppColors.onSurfaceMuted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// UC-008 A1/A3 while navigating — the GPS stream dropping out mid-route is
/// worth saying out loud, since the puck would otherwise silently freeze.
class _GpsWarningBanner extends StatelessWidget {
  final String message;
  const _GpsWarningBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.warning,
        borderRadius: AppRadius.smAll,
      ),
      child: Row(
        children: [
          const Icon(Icons.gps_off, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppType.body.copyWith(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Distance to the next manoeuvre plus the instruction text — UC-M05's
/// walking/driving instruction content.
class _ManeuverStepText extends StatelessWidget {
  final RouteStep? step;
  final NavigationController controller;

  const _ManeuverStepText({required this.step, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (step == null) {
      return Text(
        'Head towards your destination',
        style: AppType.heading.copyWith(color: Colors.white),
      );
    }

    final metresToTurn = controller.distanceToNextStepMeters;
    // Close enough that a distance is no longer the useful thing to read —
    // the tourist is at the corner, and "In 8 m" is slower to act on than the
    // one word that means "this one, here".
    final isImminent = metresToTurn <= _imminentManoeuvreMeters;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isImminent ? 'Now' : 'In ${formatDistanceMeters(metresToTurn)}',
          style: AppType.stat.copyWith(
            color: isImminent ? AppColors.primary : Colors.white,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          step!.instruction,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppType.body.copyWith(color: AppColors.onSurfaceMuted),
        ),
      ],
    );
  }
}

/// Within this many metres of a manoeuvre, the banner swaps its countdown for
/// "Now". Matched to the step-advance radius in [NavigationService] so the
/// wording changes just before the instruction itself does.
const double _imminentManoeuvreMeters = 20;

/// UC-M05 transit navigation: which line to board, where to get off, and when
/// it departs — the bus/train equivalent of a turn instruction.
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
          style: AppType.stat.copyWith(color: Colors.white, fontSize: 22),
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
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.18),
              borderRadius: AppRadius.mdAll,
            ),
            child: Text(
              'Departs ${transit.departureTimeText}',
              style: AppType.mono.copyWith(color: AppColors.primary, fontSize: 11),
            ),
          ),
        ],
      ],
    );
  }
}

/// Live remaining distance/time and arrival clock, reading straight off
/// [NavigationController] rather than the static UC-M04 summary.
class _ProgressBar extends StatelessWidget {
  final NavigationController controller;

  const _ProgressBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final minutes = (controller.remainingDurationSeconds / 60).ceil();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x59000000), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: controller.routeProgress),
              duration: const Duration(milliseconds: 500),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: const Color(0x1FFFFFFF),
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _StatBlock(
                  label: 'arrive',
                  value: formatClockTime(controller.estimatedArrivalTime),
                ),
              ),
              Expanded(
                child: _StatBlock(
                  label: 'time left',
                  value: formatEtaMinutes(minutes),
                ),
              ),
              Expanded(
                child: _StatBlock(
                  label: 'distance',
                  value: formatDistanceMeters(controller.remainingDistanceMeters),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// UC-M05 step 8 / A2: shown once the tourist is within the check-in threshold
/// of the destination — arrival itself, not the check-in, is this module's job
/// (constraint C2 leaves check-in and points to Walking & Carbon).
class _ArrivedCard extends StatelessWidget {
  final String destinationName;
  final VoidCallback onDone;

  /// When a journey is running, arriving *is* completing it — the tourist has
  /// just been told they are there, and sending them back to the walking
  /// screen to say so again reads as the app not having noticed. This runs the
  /// UC-W06 check itself; only a check that fails puts a screen in their way.
  final VoidCallback? onCompleteJourney;

  const _ArrivedCard({
    super.key,
    required this.destinationName,
    required this.onDone,
    this.onCompleteJourney,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x59000000), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You have arrived',
                      style: AppType.heading.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      destinationName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.body.copyWith(
                        color: AppColors.onSurfaceMuted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onCompleteJourney ?? onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
              ),
              child: Text(
                onCompleteJourney == null ? 'Done' : 'Complete Journey',
                style: AppType.button,
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
        Text(label, style: AppType.mono.copyWith(color: AppColors.onSurfaceMuted)),
        const SizedBox(height: 4),
        Text(value, style: AppType.stat.copyWith(color: Colors.white, fontSize: 20)),
      ],
    );
  }
}

/// Directions API `maneuver` values mapped onto Material turn icons. Shared by
/// the current-step banner and its "then …" preview row.
IconData maneuverIcon(String? maneuver) {
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
    case 'ramp-left':
    case 'ramp-right':
      return Icons.ramp_right;
    default:
      return Icons.straight;
  }
}

/// Directions API `transit_details.line.vehicle.type` mapped onto Material
/// vehicle icons (UC-M05 A5).
IconData vehicleIcon(String vehicleType) {
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

/// One interpolated frame of the location puck. A value type so the
/// [ValueNotifier] driving the map layer can skip repaints when a frame lands
/// on exactly the same position and heading as the last one.
@immutable
class _PuckFrame {
  const _PuckFrame(this.position, this.heading);

  final LatLng position;
  final double heading;

  @override
  bool operator ==(Object other) =>
      other is _PuckFrame &&
      other.position == position &&
      other.heading == heading;

  @override
  int get hashCode => Object.hash(position, heading);
}
