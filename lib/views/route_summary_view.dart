import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../constants/map_style.dart';
import '../models/transport_mode.dart';
import '../controllers/route_summary_controller.dart';
import '../models/place_model.dart';
import '../models/route_result.dart';
import '../models/route_step.dart';
import '../models/walking_route_summary.dart';
import '../controllers/walking_controller.dart';
import '../services/profile_store.dart';
import '../theme/app_theme.dart';
import '../utils/distance_format.dart';
import '../utils/duration_format.dart';
import '../utils/place_marker_icon.dart';
import '../widgets/map/zoom_controls.dart';
import 'navigation_view.dart';
import 'pre_walk_summary_view.dart';

/// Screen for UC-M04 (distance/time compared across travel modes) and the
/// hand-off into UC-M05 (in-app turn-by-turn navigation), both extending
/// UC-M06 (Request Map Service).
class RouteSummaryView extends StatefulWidget {
  final PlaceModel destination;
  final LatLng origin;

  /// UC-M04 steps 3-4: fired once, as soon as any travel mode comes back with
  /// a usable route. [MapPanel] uses it to grey out the pin and card for a
  /// place the tourist has now priced up, so the map they return to shows
  /// which options they have already checked.
  ///
  /// A callback rather than a pop result: the route resolves while the
  /// tourist is still on this screen, and they may leave it by navigating
  /// onward rather than by popping back.
  final VoidCallback? onRouteReady;

  const RouteSummaryView({
    super.key,
    required this.destination,
    required this.origin,
    this.onRouteReady,
  });

  @override
  State<RouteSummaryView> createState() => _RouteSummaryViewState();
}

class _RouteSummaryViewState extends State<RouteSummaryView> {
  late final RouteSummaryController _controller = RouteSummaryController(
    destination: widget.destination,
  );
  GoogleMapController? _mapController;
  BitmapDescriptor? _originIcon;
  BitmapDescriptor? _destinationIcon;

  /// The route the camera was last framed around. Re-framing only when this
  /// changes stops the map fighting a tourist who has panned to inspect part
  /// of the route.
  TransportMode? _framedMode;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _controller.calculateRoute(widget.origin);
    _loadMarkerIcons();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadMarkerIcons() async {
    final origin = await buildOriginDotIcon();
    final destination = await buildDestinationPinIcon();
    if (!mounted) return;
    setState(() {
      _originIcon = origin;
      _destinationIcon = destination;
    });
  }

  /// Guards [RouteSummaryView.onRouteReady] so it fires once per screen — the
  /// tourist switching between mode tabs afterwards is not new information.
  bool _reportedRouteReady = false;

  void _onControllerChanged() {
    _frameRouteIfNeeded();
    _reportRouteReadyOnce();
    if (mounted) setState(() {});
  }

  void _reportRouteReadyOnce() {
    final report = widget.onRouteReady;
    if (_reportedRouteReady || report == null || _controller.isLoading) return;
    // UC-M04 A1: a mode that returned nothing does not count — the place is
    // only "routed" once at least one mode actually produced a route.
    final hasUsableRoute = _controller.routesByMode.values.any(
      (route) => route.routeFound,
    );
    if (!hasUsableRoute) return;
    _reportedRouteReady = true;
    report();
  }

  /// UC-M04 step 5: frames the whole route rather than dropping the tourist at
  /// a fixed zoom over their own position, so the first thing they see is how
  /// far the destination actually is.
  void _frameRouteIfNeeded() {
    final route = _controller.route;
    if (_mapController == null || route == null || !route.routeFound) return;
    if (_framedMode == _controller.selectedMode) return;

    _framedMode = _controller.selectedMode;
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(_boundsFor(route), 56),
    );
  }

  /// Bounding box covering the route line plus both endpoints — the polyline
  /// alone can leave a marker just off screen when the route starts by
  /// doubling back.
  LatLngBounds _boundsFor(RouteResult route) {
    final points = <LatLng>[
      widget.origin,
      LatLng(widget.destination.latitude, widget.destination.longitude),
      ...route.polylinePoints,
    ];

    var minLat = points.first.latitude, maxLat = points.first.latitude;
    var minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  /// UC-M05 step 1: pushes the in-app turn-by-turn view for whichever mode is
  /// selected, reusing the route already fetched for UC-M04 rather than
  /// re-requesting it.
  /// UC-W01 -> UC-W05: starts a recorded walking journey to this place.
  ///
  /// This is the seam the Walking module documented on WalkingRouteSummary
  /// and never had connected: until now that module ran on
  /// WalkingRouteSummary.demo, so every journey was to Fort Cornwallis
  /// regardless of the pin the tourist actually tapped.
  ///
  /// Offered for walking only. Driving and public transport earn no points
  /// and save no carbon (FR-W01), so there is nothing to record — those
  /// modes keep Navigate alone.
  Future<void> _startJourney(BuildContext context) async {
    final route = _controller.route;
    if (route == null || !route.routeFound) return;

    final navigator = Navigator.of(context);

    // The walking module needs the tourist's body weight for its calorie
    // estimate (US-W04). Loaded here rather than threaded down from HomeView
    // through MapPanel and the pin tap; a null profile is handled by
    // PreWalkSummaryView, which shows its missing-weight prompt instead of a
    // misleading figure.
    final profile = await ProfileStore().load();
    if (!mounted) return;

    final walkingController = WalkingController()
      ..setUserProfile(profile)
      // Load-bearing: WalkingController gates carbon savings and the calorie
      // estimate on its own selected mode, and both return their "not
      // applicable" values (0.0 and null) while it is unset. Without this the
      // Pre-Walk Summary would show 0 kg CO2 saved and the missing-weight
      // prompt on a perfectly valid walk.
      ..selectMode(_controller.selectedMode)
      ..setRouteSummary(
        WalkingRouteSummary.fromDestination(
          destinationId: widget.destination.placeId,
          destinationName: widget.destination.name,
          areaLabel: widget.destination.address ?? 'Penang',
          destinationLatitude: widget.destination.latitude,
          destinationLongitude: widget.destination.longitude,
          distanceKm: route.distanceKm,
          estimatedDuration: Duration(minutes: route.durationMinutes),
          transportMode: _controller.selectedMode,
          // Already resolved by the nearby search behind this pin — the
          // Journey Preview's cover image costs no further Places call.
          destinationPhotoUrl: widget.destination.photoUrl,
        ),
      );

    navigator.push(
      MaterialPageRoute(
        builder: (_) => PreWalkSummaryView(
          controller: walkingController,
          // UC-M05 from inside a journey: the Active Walking screen's "Open
          // Navigation" opens WalkPenang's own turn-by-turn view rather than
          // handing the tourist to the Google Maps app. The route and place
          // are already here, so the Walking screens only forward a callback
          // and never see a map type.
          onOpenNavigation: (navContext) {
            Navigator.of(navContext).push(
              MaterialPageRoute(
                builder: (_) => NavigationView(
                  route: route,
                  destination: widget.destination,
                  // Where the route was calculated from, not where the
                  // tourist is now — NavigationController uses this only as
                  // the opening camera target and snaps to live GPS on its
                  // first fix.
                  origin: widget.origin,
                  mode: _controller.selectedMode,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _startNavigation(BuildContext context) async {
    final navigator = Navigator.of(context);
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => NavigationView(
          route: _controller.route!,
          destination: widget.destination,
          origin: widget.origin,
          mode: _controller.selectedMode,
        ),
      ),
    );
    // Leaving navigation from here returns the tourist to the map, not to
    // this summary — the route they were reviewing is behind them. That
    // used to be NavigationView popping twice, which broke the journey flow
    // that pushes it from two screens deeper; the decision belongs here, at
    // the push site, instead.
    if (mounted) navigator.pop();
  }

  /// UC-M05's full instruction list, available before setting off rather than
  /// only one turn at a time once navigation has started.
  void _showAllSteps(List<RouteStep> steps) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
      ),
      builder: (_) => _StepsSheet(steps: steps),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _CircleBackButton(onPressed: () => Navigator.of(context).pop()),
                      const SizedBox(width: 10),
                      Expanded(child: _DestinationChip(place: widget.destination)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ModeTabs(controller: _controller),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 220),
              alignment: Alignment.bottomCenter,
              child: _buildSummaryCard(),
            ),
          ),
        ],
      ),
    );
  }

  /// UC-M04 step 5: shows the selected mode's route as a polyline once the
  /// Directions API response has been decoded.
  Widget _buildMap() {
    final route = _controller.route;
    final destLatLng = LatLng(
      widget.destination.latitude,
      widget.destination.longitude,
    );
    final hasRoute = route != null && route.routeFound;

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: widget.origin, zoom: 14),
          style: MapStyles.warm,
          onMapCreated: (controller) {
            setState(() => _mapController = controller);
            _frameRouteIfNeeded();
          },
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          mapToolbarEnabled: false,
          // Leaves room for the mode tabs above and the summary card below,
          // so a framed route never lands underneath either of them.
          padding: const EdgeInsets.only(top: 140, bottom: 260),
          polylines: hasRoute
              ? {
                  Polyline(
                    polylineId: const PolylineId('route_casing'),
                    points: route.polylinePoints,
                    color: AppColors.routeCasing.withValues(alpha: 0.45),
                    width: 12,
                    startCap: Cap.roundCap,
                    endCap: Cap.roundCap,
                    jointType: JointType.round,
                    zIndex: 0,
                  ),
                  Polyline(
                    polylineId: const PolylineId('route'),
                    points: route.polylinePoints,
                    color: AppColors.primary,
                    width: 7,
                    startCap: Cap.roundCap,
                    endCap: Cap.roundCap,
                    jointType: JointType.round,
                    zIndex: 1,
                  ),
                }
              : const {},
          markers: {
            Marker(
              markerId: const MarkerId('origin'),
              position: widget.origin,
              icon: _originIcon ?? BitmapDescriptor.defaultMarker,
              anchor: const Offset(0.5, 0.5),
            ),
            Marker(
              markerId: MarkerId(widget.destination.placeId),
              position: destLatLng,
              icon: _destinationIcon ?? BitmapDescriptor.defaultMarker,
              anchor: const Offset(0.5, 0.94),
            ),
          },
        ),
        Positioned(
          right: 12,
          bottom: 272,
          child: ZoomControls(mapController: _mapController),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    if (_controller.isLoading) return const _LoadingCard();

    // UC-M04 A1 / A2: no route found and lost connection both land here — the
    // controller has already picked the right message for either case.
    if (_controller.errorMessage != null && _controller.route == null) {
      return _ErrorCard(
        message: _controller.errorMessage!,
        onBack: () => Navigator.of(context).pop(),
      );
    }

    final route = _controller.route;
    if (route == null) return const SizedBox.shrink();

    return _SummaryCard(
      destination: widget.destination,
      route: route,
      mode: _controller.selectedMode,
      errorMessage: _controller.errorMessage,
      onCancel: () => Navigator.of(context).pop(),
      onNavigate: route.routeFound ? () => _startNavigation(context) : null,
      // UC-W01: walking only. Driving and public transport earn no points and
      // save no carbon (FR-W01), so there is no journey to record and those
      // modes keep Navigate alone.
      onStartJourney:
          route.routeFound && _controller.selectedMode == TransportMode.walking
              ? () => _startJourney(context)
              : null,
      onShowSteps:
          route.steps.isEmpty ? null : () => _showAllSteps(route.steps),
    );
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

/// Names the destination at the top of the screen, so the tourist can tell at
/// a glance which pin they tapped without reading the summary card.
class _DestinationChip extends StatelessWidget {
  final PlaceModel place;
  const _DestinationChip({required this.place});

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
          Icon(
            place.category == 'food' ? Icons.restaurant : Icons.photo_camera,
            size: 16,
            color: place.category == 'food'
                ? AppColors.foodPin
                : AppColors.attractionPin,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              place.name,
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

/// UC-M04 mode comparison: Walk / Drive / Bus tabs, each showing its own ETA
/// and distance so the tourist can pick a mode before tapping "Navigate".
/// Every mode was fetched together, so switching is instant — A4's "no loading
/// state" requirement.
class _ModeTabs extends StatelessWidget {
  final RouteSummaryController controller;
  const _ModeTabs({required this.controller});

  @override
  Widget build(BuildContext context) {
    final fastest = _fastestMode;

    return Row(
      children: [
        for (final mode in TransportMode.values)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: mode == TransportMode.values.last ? 0 : 8,
              ),
              child: _ModeTab(
                mode: mode,
                route: controller.routesByMode[mode],
                isLoading: controller.isLoading,
                isSelected: controller.selectedMode == mode,
                isFastest: mode == fastest,
                onTap: () => controller.selectMode(mode),
              ),
            ),
          ),
      ],
    );
  }

  /// Three ETAs side by side still leave the tourist doing the comparison
  /// themselves; marking the quickest does it for them. Suppressed when only
  /// one mode came back with a route, where "fastest" would be meaningless.
  TransportMode? get _fastestMode {
    final routed = controller.routesByMode.entries
        .where((entry) => entry.value.routeFound)
        .toList();
    if (routed.length < 2) return null;

    routed.sort(
      (a, b) => a.value.durationMinutes.compareTo(b.value.durationMinutes),
    );
    return routed.first.key;
  }
}

class _ModeTab extends StatelessWidget {
  final TransportMode mode;
  final RouteResult? route;
  final bool isLoading;
  final bool isSelected;
  final bool isFastest;
  final VoidCallback onTap;

  const _ModeTab({
    required this.mode,
    required this.route,
    required this.isLoading,
    required this.isSelected,
    required this.isFastest,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // UC-M04 A1: a mode with no route still gets a tab, showing "--" rather
    // than disappearing — the tourist can see it was checked.
    final hasRoute = route != null && route!.routeFound;
    final foreground = isSelected ? AppColors.onPrimary : AppColors.muted;

    return Material(
      color: isSelected ? AppColors.primary : Colors.white,
      borderRadius: AppRadius.smAll,
      elevation: isSelected ? 3 : 1,
      shadowColor: const Color(0x33000000),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(_icon, size: 20, color: foreground),
                  if (isFastest && !isLoading)
                    Positioned(
                      top: -4,
                      right: -10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          borderRadius: AppRadius.mdAll,
                        ),
                        child: Text(
                          'FAST',
                          style: AppType.mono.copyWith(
                            color: Colors.white,
                            fontSize: 7,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                isLoading
                    ? '···'
                    : hasRoute
                        ? formatEtaMinutes(route!.durationMinutes)
                        : '--',
                style: AppType.button.copyWith(color: foreground, fontSize: 13),
              ),
              const SizedBox(height: 1),
              Text(
                mode.shortLabel.toUpperCase(),
                style: AppType.mono.copyWith(
                  color: isSelected
                      ? AppColors.onPrimary.withValues(alpha: 0.7)
                      : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData get _icon {
    switch (mode) {
      case TransportMode.walking:
        return Icons.directions_walk;
      case TransportMode.driving:
        return Icons.directions_car;
      case TransportMode.publicTransport:
        return Icons.directions_bus;
    }
  }
}

/// UC-M04 step 5: the route summary itself — distance, travel time, and the
/// clock time the tourist would arrive if they left now.
class _SummaryCard extends StatelessWidget {
  final PlaceModel destination;
  final RouteResult route;
  final TransportMode mode;
  final String? errorMessage;
  final VoidCallback onCancel;
  final VoidCallback? onNavigate;

  /// Starts a recorded walking journey (UC-W01 -> UC-W05). Null for the modes
  /// that record nothing, which is what hides the button.
  final VoidCallback? onStartJourney;
  final VoidCallback? onShowSteps;

  const _SummaryCard({
    required this.destination,
    required this.route,
    required this.mode,
    required this.errorMessage,
    required this.onCancel,
    required this.onNavigate,
    required this.onStartJourney,
    required this.onShowSteps,
  });

  @override
  Widget build(BuildContext context) {
    final arrival = DateTime.now().add(Duration(minutes: route.durationMinutes));

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            destination.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.heading.copyWith(color: Colors.white),
          ),
          if (destination.address != null) ...[
            const SizedBox(height: 2),
            Text(
              destination.address!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.body.copyWith(
                color: AppColors.onSurfaceMuted,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (route.routeFound)
            Row(
              children: [
                Expanded(
                  child: _StatBlock(
                    label: '${mode.shortLabel.toLowerCase()} time',
                    value: formatEtaMinutes(route.durationMinutes),
                  ),
                ),
                Expanded(
                  child: _StatBlock(
                    label: 'distance',
                    value: formatDistanceKm(route.distanceKm),
                  ),
                ),
                Expanded(
                  child: _StatBlock(
                    label: 'arrive',
                    value: formatClockTime(arrival),
                  ),
                ),
              ],
            ),
          if (onShowSteps != null) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onShowSteps,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.list_alt, size: 18, color: AppColors.primary),
              label: Text(
                'View all ${route.steps.length} steps',
                style: AppType.body.copyWith(
                  color: AppColors.primary,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          // UC-M04 A1: shown inline when the selected mode has no route but
          // the others still do, so the tabs stay usable.
          if (errorMessage != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorMessage!,
                    style: AppType.body.copyWith(
                      color: AppColors.primary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          // The app's core loop: walk there, check in, earn points. Given its
          // own full-width row above Cancel/Navigate because it is the primary
          // action, and because a third chip in that row would leave all three
          // cramped.
          if (onStartJourney != null) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onStartJourney,
                // The loudest control on the card: the deep sand reads as a
                // step up from the surface it sits on, where an AppColors
                // .primary fill would be the same sand as the card and leave
                // all three actions looking alike.
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDeep,
                  foregroundColor: AppColors.onPrimary,
                  disabledBackgroundColor: AppColors.placeholder,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.mdAll,
                  ),
                ),
                child: Text('Start Journey', style: AppType.button),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              // UC-M04 A3: cancel just returns to the map, no side effects —
              // and reads as the quietest of the three, since it is the one
              // action that does nothing.
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.onSurfaceMuted),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.mdAll,
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: AppType.button.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // UC-M05 step 1: hands the fetched route off to in-app
              // turn-by-turn navigation instead of an external app. Filled,
              // but in the pale ground tone rather than the deep sand, so it
              // sits clearly below Start Journey and clearly above Cancel.
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: onNavigate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.3),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.mdAll,
                    ),
                  ),
                  icon: const Icon(Icons.navigation, size: 18, color: AppColors.onPrimary),
                  label: Text('Navigate', style: AppType.button),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// UC-M04 step 2-3: while all three modes are still in flight. Shows the shape
/// of the card that's coming rather than a bare spinner, so the layout doesn't
/// jump once the results land.
class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Comparing walk, drive and bus routes…',
              style: AppType.body.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// UC-M04 A1 / A2 when no mode returned a route at all.
class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onBack;

  const _ErrorCard({required this.message, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: AppType.body.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onBack,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.onSurfaceMuted),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
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

/// The black sheet every bottom card on this screen sits in — one place for
/// the radius, padding and shadow so loading, error and summary states all
/// share a silhouette.
class _CardShell extends StatelessWidget {
  final Widget child;
  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
        boxShadow: [
          BoxShadow(color: Color(0x40000000), blurRadius: 20, offset: Offset(0, -4)),
        ],
      ),
      child: child,
    );
  }
}

/// The full turn-by-turn list for the selected mode, so a tourist can read the
/// whole route through before committing to it.
class _StepsSheet extends StatelessWidget {
  final List<RouteStep> steps;

  const _StepsSheet({required this.steps});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text('Directions', style: AppType.heading),
                ),
                Text('${steps.length} steps', style: AppType.mono),
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemCount: steps.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 20, color: AppColors.outline),
              itemBuilder: (context, index) => _StepRow(step: steps[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final RouteStep step;
  const _StepRow({required this.step});

  @override
  Widget build(BuildContext context) {
    final transit = step.transitDetails;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            transit != null
                ? vehicleIcon(transit.vehicleType)
                : maneuverIcon(step.maneuver),
            size: 19,
            color: AppColors.onPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transit != null
                    ? 'Board ${transit.lineName} · ${transit.numStops} stop'
                        '${transit.numStops == 1 ? '' : 's'}'
                    : step.instruction,
                style: AppType.body.copyWith(fontSize: 14),
              ),
              if (transit != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${transit.departureStopName} → ${transit.arrivalStopName}',
                  style: AppType.body.copyWith(
                    color: AppColors.muted,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 3),
              Text(
                formatDistanceMeters(step.distanceMeters),
                style: AppType.mono,
              ),
            ],
          ),
        ),
      ],
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
        Text(
          value,
          style: AppType.stat.copyWith(color: Colors.white, fontSize: 21),
        ),
      ],
    );
  }
}
