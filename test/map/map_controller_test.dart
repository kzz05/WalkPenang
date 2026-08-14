// T-M01.3 — map rendering and empty state handling across different radii
// T-M02.3 — live location updates while the map screen is open
//
// Covers UC-M01 (nearby pins), UC-M02 (live GPS) and the parts of UC-M03 the
// controller owns. Every dependency of MapController is injected, so none of
// this needs a device, a Mapbox token or a network call — the fakes below
// subclass the real services and override only what is exercised.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:walkpenang/constants/map_error_messages.dart';
import 'package:walkpenang/controllers/map_controller.dart';
import 'package:walkpenang/models/gps_location.dart';
import 'package:walkpenang/models/lat_lng.dart';
import 'package:walkpenang/models/place_model.dart';
import 'package:walkpenang/services/location_service.dart';
import 'package:walkpenang/services/map_service.dart';
import 'package:walkpenang/services/places_service.dart';

GpsLocation fix({
  double lat = 5.4141,
  double lng = 100.3288,
  double accuracy = 8,
}) =>
    GpsLocation(
      latitude: lat,
      longitude: lng,
      accuracyMeters: accuracy,
      timestamp: DateTime(2026, 8, 15),
    );

PlaceModel place(String id, {String category = 'food'}) => PlaceModel(
      placeId: id,
      name: 'Place $id',
      category: category,
      latitude: 5.4150,
      longitude: 100.3300,
    );

class _FakeLocationService extends LocationService {
  /// Mutable rather than constructor-injected: most tests build the
  /// controller first and then change one of these to drive a branch.
  LocationAccessStatus access = LocationAccessStatus.granted;
  bool accurate = true;
  bool throwOnFix = false;

  final StreamController<GpsLocation> updates =
      StreamController<GpsLocation>.broadcast();

  /// Metres reported by [distanceMeters]; the refetch decision is what is
  /// under test, not the great-circle maths Geolocator already provides.
  double metresMoved = 0;

  @override
  Future<LocationAccessStatus> requestLocationAccess() async => access;

  @override
  Future<GpsLocation> getCurrentLocation() async {
    if (throwOnFix) throw TimeoutException('no lock');
    return fix();
  }

  @override
  Stream<GpsLocation> startLocationUpdates() => updates.stream;

  @override
  bool checkSignalAccuracy(GpsLocation location) => accurate;

  @override
  double distanceMeters({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) =>
      metresMoved;
}

class _FakePlacesService extends PlacesService {
  _FakePlacesService([this.results = const <PlaceModel>[]])
      : super(MapService());

  List<PlaceModel> results;
  Object? error;
  int calls = 0;
  double? lastRadiusKm;

  @override
  Future<List<PlaceModel>> fetchNearbyPlaces({
    required LatLng center,
    required double radiusKm,
  }) async {
    calls++;
    lastRadiusKm = radiusKm;
    if (error != null) throw error!;
    return results;
  }
}

void main() {
  late _FakeLocationService location;
  late _FakePlacesService places;

  MapController build() => MapController(
        locationService: location,
        placesService: places,
      );

  setUp(() {
    location = _FakeLocationService();
    places = _FakePlacesService(<PlaceModel>[place('p1'), place('p2')]);
  });

  tearDown(() => location.updates.close());

  group('T-M01.3 — rendering and empty state', () {
    test('a successful load renders the returned pins', () async {
      final controller = build();
      await controller.loadMap();

      expect(controller.nearbyPlaces, hasLength(2));
      expect(controller.errorMessage, isNull);
      expect(controller.isLoading, isFalse);
    });

    test('an empty result shows the empty state, not an error', () async {
      places.results = const <PlaceModel>[];
      final controller = build();
      await controller.loadMap();

      // UC-M01 A2: "no places nearby" is a normal outcome the tourist can act
      // on by widening the radius, not a failure.
      expect(controller.errorMessage, MapErrorMessages.noPlacesFound);
      expect(controller.nearbyPlaces, isEmpty);
    });

    test('a Places failure shows the load-failed message', () async {
      places.error = Exception('network');
      final controller = build();
      await controller.loadMap();

      expect(controller.errorMessage, MapErrorMessages.mapLoadFailed);
    });

    test('each radius chip refetches with that radius', () async {
      final controller = build();
      await controller.loadMap();
      final afterLoad = places.calls;

      await controller.setSearchRadius(1);
      expect(places.lastRadiusKm, 1);
      await controller.setSearchRadius(5);
      expect(places.lastRadiusKm, 5);

      expect(controller.searchRadiusKm, 5);
      expect(places.calls, afterLoad + 2);
    });

    test('widening the radius is the retry path after a failure', () async {
      places.error = Exception('network');
      final controller = build();
      await controller.loadMap();
      expect(controller.errorMessage, MapErrorMessages.mapLoadFailed);

      places.error = null;
      await controller.setSearchRadius(5);

      expect(controller.errorMessage, isNull);
      expect(controller.nearbyPlaces, hasLength(2));
    });
  });

  group('T-M02.3 — live location updates', () {
    test('GPS switched off is reported differently from permission denied',
        () async {
      // The whole point of splitting LocationAccessStatus: telling a tourist
      // whose GPS is off to change a permission sends them to the wrong
      // settings screen.
      location.access = LocationAccessStatus.serviceDisabled;
      final disabled = build();
      await disabled.loadMap();
      expect(disabled.errorMessage, MapErrorMessages.gpsDisabled);
      expect(disabled.hasLocationPermission, isFalse);

      location.access = LocationAccessStatus.permissionDenied;
      final denied = build();
      await denied.loadMap();
      expect(denied.errorMessage, MapErrorMessages.locationPermissionDenied);
      expect(denied.hasLocationPermission, isFalse);
    });

    test('a fix that never arrives surfaces the timeout message', () async {
      location.throwOnFix = true;
      final controller = build();
      await controller.loadMap();

      expect(controller.errorMessage, MapErrorMessages.locationTimeout);
      // isLoading must clear even on the failure path, or the scrim covers
      // the screen with no way back.
      expect(controller.isLoading, isFalse);
    });

    test('the camera centres on George Town until the first fix', () {
      final controller = build();
      expect(controller.cameraCenter.latitude, closeTo(5.4141, 0.0001));
    });

    test('streamed fixes update the current location', () async {
      final controller = build();
      await controller.loadMap();

      location.updates.add(fix(lat: 5.4200, lng: 100.3400));
      await Future<void>.delayed(Duration.zero);

      expect(controller.currentLocation!.latitude, 5.4200);
      expect(controller.cameraCenter.latitude, 5.4200);
    });

    test('a weak fix is flagged but still used', () async {
      final controller = build();
      await controller.loadMap();

      location.accurate = false;
      location.updates.add(fix(accuracy: 90));
      await Future<void>.delayed(Duration.zero);

      // UC-M02 A2: shown with a warning rather than discarded.
      expect(controller.errorMessage, MapErrorMessages.weakGpsSignal);
      expect(controller.currentLocation, isNotNull);
    });

    test('leaving Penang is reported and coming back clears it', () async {
      final controller = build();
      await controller.loadMap();
      expect(controller.isWithinPenang, isTrue);

      location.updates.add(fix(lat: 3.1390, lng: 101.6869)); // Kuala Lumpur
      await Future<void>.delayed(Duration.zero);
      expect(controller.isWithinPenang, isFalse);
      expect(controller.errorMessage, MapErrorMessages.outsidePenangUser);

      location.updates.add(fix());
      await Future<void>.delayed(Duration.zero);
      expect(controller.isWithinPenang, isTrue);
      expect(controller.errorMessage, isNull);
    });

    test('walking far enough refetches the pins', () async {
      final controller = build();
      await controller.loadMap();
      final afterLoad = places.calls;

      // Half the 2 km default radius is the threshold, so 1.5 km is past it.
      location.metresMoved = 1500;
      location.updates.add(fix(lat: 5.4300));
      await Future<void>.delayed(Duration.zero);

      expect(places.calls, greaterThan(afterLoad));
    });

    test('a short stroll does not refetch', () async {
      final controller = build();
      await controller.loadMap();
      final afterLoad = places.calls;

      // A Places call every few metres would bill for nothing.
      location.metresMoved = 20;
      location.updates.add(fix(lat: 5.4142));
      await Future<void>.delayed(Duration.zero);

      expect(places.calls, afterLoad);
    });

    test('the position stream does not notify on every fix', () async {
      // MapView rebuilds on notification; notifying per 5 m of movement
      // floods the platform channel. The live marker is drawn natively, so a
      // fix that changes nothing the UI renders must stay silent.
      final controller = build();
      await controller.loadMap();

      var notifications = 0;
      controller.addListener(() => notifications++);

      location.metresMoved = 5;
      location.updates.add(fix(lat: 5.41411));
      location.updates.add(fix(lat: 5.41412));
      await Future<void>.delayed(Duration.zero);

      expect(notifications, 0);
    });

    test('updates stop once the controller is disposed', () async {
      final controller = build();
      await controller.loadMap();
      final before = controller.currentLocation!.latitude;

      controller.dispose();
      location.updates.add(fix(lat: 5.4999));
      await Future<void>.delayed(Duration.zero);

      expect(controller.currentLocation!.latitude, before);
    });
  });

  group('destination validation (UC-M03)', () {
    test('a Penang destination is accepted', () async {
      final controller = build();
      expect(controller.validateDestination(place('p1')), isTrue);
      expect(controller.errorMessage, isNull);
    });

    test('tapping a valid stop does not wipe a GPS warning', () async {
      // errorMessage is one field written by validateDestination,
      // renderNearbyPins and _applyLocation. An unconditional clear on a
      // valid tap silently retired a weak-signal warning the tourist still
      // needed.
      final controller = build();
      await controller.loadMap();

      location.accurate = false;
      location.updates.add(fix(accuracy: 90));
      await Future<void>.delayed(Duration.zero);
      expect(controller.errorMessage, MapErrorMessages.weakGpsSignal);

      expect(controller.validateDestination(place('p1')), isTrue);
      expect(controller.errorMessage, MapErrorMessages.weakGpsSignal);
    });

    test('a valid tap does clear a previous out-of-boundary rejection',
        () async {
      final controller = build();
      final farAway = PlaceModel(
        placeId: 'kl',
        name: 'Petronas Towers',
        category: 'heritage',
        latitude: 3.1578,
        longitude: 101.7117,
      );

      controller.validateDestination(farAway);
      expect(controller.errorMessage,
          MapErrorMessages.outsidePenangDestination);

      controller.validateDestination(place('p1'));
      expect(controller.errorMessage, isNull);
    });

    test('a destination outside Penang is rejected with a message', () async {
      final controller = build();
      final farAway = PlaceModel(
        placeId: 'kl',
        name: 'Petronas Towers',
        category: 'heritage',
        latitude: 3.1578,
        longitude: 101.7117,
      );

      expect(controller.validateDestination(farAway), isFalse);
      expect(controller.errorMessage,
          MapErrorMessages.outsidePenangDestination);
    });
  });
}
