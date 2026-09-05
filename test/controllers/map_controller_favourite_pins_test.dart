// UC-007 + Discovery favourites: a saved place is pinned wherever it is, not
// only when the nearby search happens to reach it.
//
// The tourist has already decided they want to go there, so making them widen
// the radius or pan the map until a search catches it was work with no
// decision in it. These tests cover the merge rule the map draws from.

import 'package:flutter_test/flutter_test.dart';
import 'package:walkpenang/controllers/map_controller.dart';
import 'package:walkpenang/models/favorite_place.dart';
import 'package:walkpenang/models/place_model.dart';
import 'package:walkpenang/services/routed_places_store.dart';

PlaceModel _place(String id, {String name = 'Somewhere'}) => PlaceModel(
      placeId: id,
      name: name,
      category: 'attraction',
      latitude: 5.4141,
      longitude: 100.3288,
    );

void main() {
  late MapController controller;

  setUp(() {
    controller = MapController(routedPlacesStore: InMemoryRoutedPlacesStore());
  });
  tearDown(() => controller.dispose());

  group('visiblePlaces', () {
    test('is just the search results when nothing is favourited', () {
      controller.nearbyPlaces = [_place('a'), _place('b')];

      expect(
        controller.visiblePlaces.map((p) => p.placeId),
        <String>['a', 'b'],
      );
    });

    test('appends a favourite the search did not reach', () {
      controller.nearbyPlaces = [_place('a')];
      controller.setFavouritePlaces([_place('far', name: 'Kek Lok Si')]);

      expect(
        controller.visiblePlaces.map((p) => p.placeId),
        <String>['a', 'far'],
        reason: 'nearest-first search order is not disturbed by a saved place '
            'that may be kilometres away',
      );
    });

    test('a favourite already in the results is not pinned twice', () {
      // The nearby copy wins: it is live, so its rating and opening hours are
      // current, while the favourite's are a snapshot from when it was saved.
      final nearby = _place('a', name: 'From the live search');
      controller.nearbyPlaces = [nearby];
      controller.setFavouritePlaces([_place('a', name: 'From the snapshot')]);

      expect(controller.visiblePlaces, hasLength(1));
      expect(controller.visiblePlaces.single.name, 'From the live search');
    });

    test('favourites still show when the search found nothing', () {
      controller.nearbyPlaces = [];
      controller.setFavouritePlaces([_place('far')]);

      expect(controller.visiblePlaces.map((p) => p.placeId), <String>['far']);
    });
  });

  group('setFavouritePlaces', () {
    test('notifies when the set changes', () {
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.setFavouritePlaces([_place('a')]);
      expect(notifications, 1);

      controller.setFavouritePlaces([_place('a'), _place('b')]);
      expect(notifications, 2);
    });

    test('does not notify when the same favourites come round again', () {
      controller.setFavouritePlaces([_place('a')]);

      var notifications = 0;
      controller.addListener(() => notifications++);
      // Every favourites change re-runs this, including ones that touch a
      // place with no coordinates. Redrawing every marker for an unchanged
      // set would undo the work spent keeping the map smooth.
      controller.setFavouritePlaces([_place('a')]);

      expect(notifications, 0);
    });
  });

  group('FavoritePlace.toPlaceModel', () {
    test('carries the fields a pin and its card need', () {
      final favourite = FavoritePlace(
        id: 'chew-jetty',
        name: 'Chew Jetty',
        category: 'attraction',
        savedAt: DateTime(2026, 9, 5),
        latitude: 5.4141,
        longitude: 100.3421,
        rating: 4.1,
        address: 'Pengkalan Weld',
        photoUrl: 'https://example.com/photo.jpg',
      );

      final place = favourite.toPlaceModel()!;

      expect(place.placeId, 'chew-jetty');
      expect(place.name, 'Chew Jetty');
      expect(place.latitude, 5.4141);
      expect(place.longitude, 100.3421);
      expect(place.rating, 4.1);
      expect(place.address, 'Pengkalan Weld');
      expect(place.photoUrl, 'https://example.com/photo.jpg');
      // Never stored with a favourite; claiming "open now" from a snapshot
      // would be a guess the card presents as fact.
      expect(place.isOpenNow, isFalse);
    });

    test('is null for a favourite saved without coordinates', () {
      // What the Discovery grid produces today — Place carries no position,
      // so there is nowhere to put a pin and guessing one is worse than none.
      final fromGrid = FavoritePlace(
        id: 'from-the-grid',
        name: 'Somewhere',
        category: 'heritage',
        savedAt: DateTime(2026, 9, 5),
      );

      expect(fromGrid.toPlaceModel(), isNull);
    });
  });
}
