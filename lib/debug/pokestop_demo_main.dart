// Interactive prototype of the "Pokestop" map flow, for review before any of
// it is committed to the real screens.
//
//     flutter run -t lib/debug/pokestop_demo_main.dart
//
// What it demonstrates, end to end:
//   tap a stop -> card rises -> Favourite / Details / Navigate / Proceed
//   favouriting recolours that stop so it stands out on the map
//   Proceed shows the handoff into the Walking & Carbon module
//
// The one deliberate departure from the written flow: the interactive objects
// are MARKERS, not buildings. Mapbox's 3D buildings come from generic OSM
// footprints in the vector tile — they carry a height and a shape and no
// identity at all, so there is no key to join a building to a place. Half the
// curated Penang set has no building to attach to either: Chulia Street
// hawkers are a street, Fort Cornwallis is a fort, street art is a wall, and
// one shophouse routinely holds several businesses. Pokemon GO works the same
// way for the same reason — its stops are separate objects and the buildings
// are scenery.
//
// Nothing here writes to Firestore. Favourites are in-memory for the length of
// the demo, so it can be run and re-run without touching real data.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../constants/map_constants.dart';
import '../controllers/map_controller.dart';
import '../models/lat_lng.dart';
import '../models/lat_lng_mapbox.dart';
import '../models/place_model.dart';
import '../models/transport_mode.dart';
import '../theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // No Firebase: nothing in this prototype reads or writes Firestore.
  await dotenv.load(fileName: '.env');
  MapboxOptions.setAccessToken(dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '');
  runApp(
    MaterialApp(
      title: 'WalkPenang — stop flow prototype',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const PokestopDemo(),
    ),
  );
}

class PokestopDemo extends StatefulWidget {
  const PokestopDemo({super.key});

  @override
  State<PokestopDemo> createState() => _PokestopDemoState();
}

class _PokestopDemoState extends State<PokestopDemo> {
  late final MapController _controller = MapController();
  MapboxMap? _map;
  PointAnnotationManager? _stops;

  final Map<String, PlaceModel> _placeByAnnotation = {};
  final Map<String, PointAnnotation> _annotationByPlace = {};
  final Map<String, Uint8List> _sprites = {};

  /// In-memory only — the real thing goes to users/{uid}/favorites.
  final Set<String> _favourites = {};

  PlaceModel? _selected;
  bool _hasCentred = false;
  List<String> _rendered = const [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _controller.loadMap();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    final map = _map;
    final fix = _controller.currentLocation;
    if (!_hasCentred && fix != null && map != null) {
      _hasCentred = true;
      map.flyTo(
        CameraOptions(
          center: LatLng(fix.latitude, fix.longitude).toPoint,
          zoom: MapConstants.defaultZoom,
          pitch: MapConstants.gamifiedPitchDegrees,
        ),
        MapAnimationOptions(duration: 1200),
      );
    }
    _syncStops();
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    await map.setBounds(
      CameraBoundsOptions(
        bounds: _controller.boundaryConstraint.toCoordinateBounds(),
        minZoom: MapConstants.minZoom,
        maxZoom: MapConstants.maxZoom,
      ),
    );
    await map.gestures.updateSettings(
      GesturesSettings(pitchEnabled: false, rotateEnabled: false),
    );
    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    if (_controller.hasLocationPermission) {
      await map.location.updateSettings(
        LocationComponentSettings(enabled: true, puckBearingEnabled: true),
      );
    }
    _stops = await map.annotations.createPointAnnotationManager();
    _stops!.tapEvents(onTap: _onStopTapped);
    _onChanged();
  }

  Future<Uint8List> _sprite(String asset) async {
    final cached = _sprites[asset];
    if (cached != null) return cached;
    final bytes = (await rootBundle.load(asset)).buffer.asUint8List();
    _sprites[asset] = bytes;
    return bytes;
  }

  String _assetFor(PlaceModel place) {
    if (_favourites.contains(place.placeId)) {
      return 'assets/images/stop_favourite.png';
    }
    return place.category == 'food'
        ? 'assets/images/stop_food.png'
        : 'assets/images/stop_attraction.png';
  }

  Future<void> _syncStops() async {
    final manager = _stops;
    if (manager == null) return;

    final places = _controller.nearbyPlaces;
    final ids = places.map((p) => p.placeId).toList();
    if (ids.length == _rendered.length &&
        ids.every(_rendered.contains)) {
      return;
    }
    _rendered = ids;

    await manager.deleteAll();
    _placeByAnnotation.clear();
    _annotationByPlace.clear();
    if (places.isEmpty) return;

    final options = <PointAnnotationOptions>[];
    for (final place in places) {
      options.add(
        PointAnnotationOptions(
          geometry: LatLng(place.latitude, place.longitude).toPoint,
          image: await _sprite(_assetFor(place)),
          iconSize: 0.9,
          iconAnchor: IconAnchor.BOTTOM,
        ),
      );
    }

    final created = await manager.createMulti(options);
    for (var i = 0; i < created.length; i++) {
      final annotation = created[i];
      if (annotation == null) continue;
      _placeByAnnotation[annotation.id] = places[i];
      _annotationByPlace[places[i].placeId] = annotation;
    }
  }

  void _onStopTapped(PointAnnotation annotation) {
    final place = _placeByAnnotation[annotation.id];
    if (place == null) return;
    setState(() => _selected = place);

    // Lean the camera towards the stop, which is what gives the "walk up to
    // it" feel rather than the card just appearing.
    _map?.flyTo(
      CameraOptions(
        center: LatLng(place.latitude, place.longitude).toPoint,
        zoom: 17,
        pitch: 60,
      ),
      MapAnimationOptions(duration: 700),
    );
  }

  /// Recolours just this stop, by replacing the single annotation.
  ///
  /// The obvious version — mutate `annotation.image` and call
  /// `manager.update()` — silently does nothing: the SDK registers an
  /// annotation's image under an internal name when the annotation is created
  /// and does not re-register it on update, so the marker keeps its original
  /// sprite while every other piece of state says "saved". Deleting and
  /// recreating forces the new image through.
  ///
  /// Still only one marker's worth of work, which is the point: on a building
  /// this would mean driving feature-state against tile-local building ids
  /// that are neither stable across zoom levels nor unique when a footprint
  /// straddles a tile boundary.
  Future<void> _toggleFavourite(PlaceModel place) async {
    setState(() {
      if (!_favourites.remove(place.placeId)) _favourites.add(place.placeId);
    });

    final manager = _stops;
    final old = _annotationByPlace[place.placeId];
    if (manager == null || old == null) return;

    await manager.delete(old);
    _placeByAnnotation.remove(old.id);

    final replacement = await manager.create(
      PointAnnotationOptions(
        geometry: LatLng(place.latitude, place.longitude).toPoint,
        image: await _sprite(_assetFor(place)),
        iconSize: 0.9,
        iconAnchor: IconAnchor.BOTTOM,
      ),
    );
    _annotationByPlace[place.placeId] = replacement;
    _placeByAnnotation[replacement.id] = place;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Stack(
          children: [
            MapWidget(
              key: const ValueKey('pokestop_demo_map'),
              styleUri: MapConstants.gamifiedStyleUri,
              viewport: CameraViewportState(
                center: MapConstants.georgeTownCenter.toPoint,
                zoom: MapConstants.defaultZoom,
                pitch: MapConstants.gamifiedPitchDegrees,
              ),
              onMapCreated: _onMapCreated,
            ),
            const _Vignette(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: _Banner(
                    text: _controller.errorMessage ??
                        'Tap a stop — ${_controller.nearbyPlaces.length} nearby'
                            '   ·   ${_favourites.length} saved',
                    isError: _controller.errorMessage != null,
                  ),
                ),
              ),
            ),
            if (_controller.isLoading)
              const ColoredBox(
                color: AppColors.scrim,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
            if (_selected != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: _StopCard(
                  place: _selected!,
                  isFavourite: _favourites.contains(_selected!.placeId),
                  onFavourite: () => _toggleFavourite(_selected!),
                  onDetails: () => _showDetails(_selected!),
                  onProceed: () => _showProceed(_selected!),
                  onClose: () => setState(() => _selected = null),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDetails(PlaceModel place) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sm)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DETAILS', style: AppType.mono),
            const SizedBox(height: 6),
            Text(place.name, style: AppType.heading),
            const SizedBox(height: 12),
            Text(
              'In the real flow this opens the Food & Attraction module\n'
              '(PlaceDetailView) — photos, description, opening hours,\n'
              'reviews and ratings from Firestore.',
              style: AppType.body,
            ),
            const SizedBox(height: 16),
            Text(
              place.rating != null
                  ? '★ ${place.rating!.toStringAsFixed(1)}  ·  ${place.address ?? ''}'
                  : place.address ?? '',
              style: AppType.monoValue,
            ),
          ],
        ),
      ),
    );
  }

  void _showProceed(PlaceModel place) {
    var mode = TransportMode.walking;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sm)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('→ WALKING & CARBON MODULE', style: AppType.mono),
              const SizedBox(height: 6),
              Text('Destination set', style: AppType.heading),
              const SizedBox(height: 4),
              Text(place.name, style: AppType.body),
              const SizedBox(height: 18),
              Text('TRANSPORT MODE', style: AppType.mono),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final option in TransportMode.values)
                    ChoiceChip(
                      label: Text(option.label),
                      selected: option == mode,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.background,
                      labelStyle: AppType.monoValue,
                      onSelected: (_) => setSheetState(() => mode = option),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _RewardNotice(mode: mode),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                  ),
                  child: Text('Start journey', style: AppType.body),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Spells out the consequence of the selected mode, in the design system's
/// success / warning tints rather than a bare sentence.
class _RewardNotice extends StatelessWidget {
  const _RewardNotice({required this.mode});

  final TransportMode mode;

  @override
  Widget build(BuildContext context) {
    final earns = mode.earnsPoints;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: earns ? AppColors.successTint : AppColors.warningTint,
        borderRadius: AppRadius.smAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            earns ? Icons.check_circle_outline : Icons.info_outline,
            size: 18,
            color: earns ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              earns
                  ? 'GPS check-in on arrival. Earns points towards your badges.'
                  : 'No points, no check-in and no carbon saving for a '
                      '${mode.label.toLowerCase()} journey. Those are for '
                      'walking — the route is still shown.',
              style: AppType.body.copyWith(
                fontSize: 13,
                color: earns ? AppColors.success : AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.isError});
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isError ? AppColors.dangerTint : AppColors.card,
        borderRadius: AppRadius.smAll,
      ),
      child: Text(
        text,
        style: AppType.body.copyWith(
          fontSize: 13,
          color: isError ? AppColors.danger : AppColors.onPrimary,
        ),
      ),
    );
  }
}

class _StopCard extends StatelessWidget {
  const _StopCard({
    required this.place,
    required this.isFavourite,
    required this.onFavourite,
    required this.onDetails,
    required this.onProceed,
    required this.onClose,
  });

  final PlaceModel place;
  final bool isFavourite;
  final VoidCallback onFavourite;
  final VoidCallback onDetails;
  final VoidCallback onProceed;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: AppRadius.smAll,
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  place.category == 'food' ? 'FOOD' : 'ATTRACTION',
                  style: AppType.mono,
                ),
                const Spacer(),
                InkWell(
                  onTap: onClose,
                  child: const Icon(Icons.close, size: 20,
                      color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(place.name, style: AppType.heading),
            const SizedBox(height: 4),
            Text(
              place.rating != null
                  ? '★ ${place.rating!.toStringAsFixed(1)}'
                  : (place.isOpenNow ? 'Open now' : ''),
              style: AppType.monoValue,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _Action(
                  icon: isFavourite ? Icons.star : Icons.star_border,
                  label: isFavourite ? 'Saved' : 'Favourite',
                  onTap: onFavourite,
                  emphasised: isFavourite,
                ),
                const SizedBox(width: 8),
                _Action(
                  icon: Icons.info_outline,
                  label: 'Details',
                  onTap: onDetails,
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onProceed,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                ),
                child: Text('Proceed', style: AppType.body),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.emphasised = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: emphasised ? AppColors.primary : AppColors.background,
            borderRadius: AppRadius.mdAll,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: AppColors.onPrimary),
              const SizedBox(width: 6),
              Text(label, style: AppType.monoValue),
            ],
          ),
        ),
      ),
    );
  }
}

class _Vignette extends StatelessWidget {
  const _Vignette();

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
