import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../theme/app_theme.dart';
import '../../utils/location_puck_icon.dart';

/// The small embedded map on the Verify Location screen (UC-W06): the
/// destination, the check-in radius drawn around it, and the tourist's last
/// GPS fix, framed so all three are visible at once.
///
/// Presentation only, and deliberately so — it takes the coordinates and the
/// radius the verification flow already resolved and draws them. It reads no
/// GPS, measures no distance and decides nothing about arrival; that stays
/// with ArrivalVerificationService and JourneyCompletionController, which is
/// the whole reason this is a widget rather than a second GPS implementation.
///
/// Reuses the app's existing map furniture: [GoogleMap] exactly as the map,
/// route summary and navigation screens configure it, and
/// [buildLocationPuckIcon] so the tourist's dot matches the one those screens
/// already show.
class VerificationRadiusMap extends StatefulWidget {
  /// The place being verified against — the centre of the radius circle.
  final LatLng destination;

  /// The tourist's last known fix, or null while none has landed (or after a
  /// reading failed). The map still shows the destination and its radius.
  final LatLng? userPosition;

  /// The check-in threshold, passed in rather than read from
  /// [MapConstants.checkInThresholdMeters] here, so this widget never
  /// restates a business constant it does not own.
  final double radiusMeters;

  /// Tints the radius circle to the verification state — the ring colour the
  /// illustrated version of this card used to carry.
  final Color accentColor;

  final double height;

  const VerificationRadiusMap({
    super.key,
    required this.destination,
    required this.radiusMeters,
    required this.accentColor,
    this.userPosition,
    this.height = 180,
  });

  @override
  State<VerificationRadiusMap> createState() => _VerificationRadiusMapState();
}

class _VerificationRadiusMapState extends State<VerificationRadiusMap> {
  GoogleMapController? _mapController;
  BitmapDescriptor? _userPuckIcon;

  /// Inset, in logical pixels, kept between the framed content and the card's
  /// edges so the radius circle never sits flush against them.
  static const _framingPaddingPx = 36.0;

  @override
  void initState() {
    super.initState();
    _loadUserPuckIcon();
  }

  @override
  void didUpdateWidget(covariant VerificationRadiusMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A retry, or simply a closer fix, moves the tourist — refit so they and
    // the destination stay framed together rather than one drifting off the
    // card.
    if (oldWidget.userPosition != widget.userPosition ||
        oldWidget.destination != widget.destination ||
        oldWidget.radiusMeters != widget.radiusMeters) {
      _fitToVerificationBounds();
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadUserPuckIcon() async {
    final icon = await buildLocationPuckIcon();
    if (!mounted) return;
    setState(() => _userPuckIcon = icon);
  }

  /// Metres covered per degree of latitude — good enough for framing a
  /// 100-metre circle, and it keeps this widget free of any distance
  /// calculation that could be mistaken for the verification one.
  static const _metresPerDegreeLatitude = 111320.0;

  double _metresPerDegreeLongitude(double latitude) =>
      _metresPerDegreeLatitude * math.cos(latitude * math.pi / 180).abs();

  /// The box that has to be visible: the radius circle around the
  /// destination, extended to include the tourist when they are standing
  /// outside it.
  LatLngBounds _verificationBounds() {
    final latPadding = widget.radiusMeters / _metresPerDegreeLatitude;
    final lngPadding = widget.radiusMeters /
        math.max(_metresPerDegreeLongitude(widget.destination.latitude), 1);

    var south = widget.destination.latitude - latPadding;
    var north = widget.destination.latitude + latPadding;
    var west = widget.destination.longitude - lngPadding;
    var east = widget.destination.longitude + lngPadding;

    final user = widget.userPosition;
    if (user != null) {
      south = math.min(south, user.latitude);
      north = math.max(north, user.latitude);
      west = math.min(west, user.longitude);
      east = math.max(east, user.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
  }

  /// A zoom that shows [_verificationBounds] before the camera animation
  /// lands, so the first painted frame is already in the right neighbourhood
  /// rather than a continent-wide view that then rushes in.
  double _initialZoom() {
    final bounds = _verificationBounds();
    final spanMetres = math.max(
      (bounds.northeast.latitude - bounds.southwest.latitude) *
          _metresPerDegreeLatitude,
      (bounds.northeast.longitude - bounds.southwest.longitude) *
          _metresPerDegreeLongitude(widget.destination.latitude),
    );
    if (spanMetres <= 0) return 16;

    // Web-Mercator ground resolution at zoom 0, the standard 156543.03 m/px
    // at the equator, scaled for latitude — inverted for the zoom that fits
    // spanMetres across a card roughly 320 logical pixels wide.
    const groundResolutionAtZeroZoom = 156543.03392;
    final metresPerPixel = spanMetres / 320;
    final zoom = math.log(groundResolutionAtZeroZoom *
                math.cos(widget.destination.latitude * math.pi / 180).abs() /
                metresPerPixel) /
            math.ln2 -
        // A little breathing room, so the circle is not flush to the edges.
        0.4;
    return zoom.clamp(12.0, 18.0);
  }

  /// Frames the destination, its radius and the tourist together.
  ///
  /// Deferred by a frame: `newLatLngBounds` needs the platform view to have
  /// been laid out, and calling it straight out of `onMapCreated` is the
  /// classic way to get an "map size can't be 0" failure on Android.
  void _fitToVerificationBounds() {
    final controller = _mapController;
    if (controller == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          _verificationBounds(),
          _framingPaddingPx,
        ),
      );
    });
  }

  Set<Marker> _buildMarkers() {
    final user = widget.userPosition;

    return {
      Marker(
        markerId: const MarkerId('verify_destination'),
        position: widget.destination,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ),
      if (user != null)
        Marker(
          markerId: const MarkerId('verify_user'),
          position: user,
          // The same puck the map and navigation screens draw, so the
          // tourist's dot reads identically everywhere. Falls back to the
          // stock azure pin for the frame or two before the bitmap is ready.
          icon: _userPuckIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          anchor: _userPuckIcon == null
              ? const Offset(0.5, 1)
              : const Offset(0.5, 0.5),
          flat: _userPuckIcon != null,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: widget.destination,
            zoom: _initialZoom(),
          ),
          onMapCreated: (controller) {
            _mapController = controller;
            _fitToVerificationBounds();
          },
          circles: {
            // NFR-02's check-in zone, drawn rather than described. The
            // radius is whatever the flow verified against — this widget
            // never picks the number.
            Circle(
              circleId: const CircleId('check_in_radius'),
              center: widget.destination,
              radius: widget.radiusMeters,
              strokeWidth: 2,
              strokeColor: widget.accentColor,
              fillColor: widget.accentColor.withValues(alpha: 0.16),
            ),
          },
          markers: _buildMarkers(),
          // A preview, not a map to explore: every gesture is off so the card
          // cannot swallow the scroll of the screen it sits in, and the
          // framing stays the one that shows the verification.
          zoomGesturesEnabled: false,
          scrollGesturesEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          liteModeEnabled: false,
        ),
      ),
    );
  }
}
