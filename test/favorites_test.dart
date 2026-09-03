import 'package:flutter_test/flutter_test.dart';

import 'package:walkpenang/controllers/favorites_controller.dart';
import 'package:walkpenang/models/favorite_place.dart';
import 'package:walkpenang/models/place.dart';
import 'package:walkpenang/services/favorites_store.dart';

/// T-FD04.3 — favouriting toggle states, empty list, persistent storage sync.
void main() {
  FavoritePlace makeFav(String id, {DateTime? savedAt}) => FavoritePlace(
        id: id,
        name: 'Place $id',
        category: 'food',
        savedAt: savedAt ?? DateTime.now(),
        photoUrl: 'https://example.com/$id.jpg',
        rating: 4.0,
      );

  Place makePlace(String id) => Place(
        id: id,
        name: 'Place $id',
        category: PlaceCategory.food,
        photoUrls: const <String>['https://example.com/x.jpg'],
        priceLevel: PriceLevel.budget,
        distanceKm: 1.0,
        rating: 4.0,
        reviewCount: 10,
        address: 'Address $id',
      );

  group('toggle states', () {
    test('toggle adds then removes', () {
      final FavoritesController favorites =
          FavoritesController(store: InMemoryFavoritesStore());
      final FavoritePlace place = makeFav('p1');

      expect(favorites.isFavorite('p1'), isFalse);

      expect(favorites.toggle(place), isTrue);
      expect(favorites.isFavorite('p1'), isTrue);
      expect(favorites.count, 1);

      expect(favorites.toggle(place), isFalse);
      expect(favorites.isFavorite('p1'), isFalse);
      expect(favorites.count, 0);
    });

    test('adding the same place twice does not duplicate', () {
      final FavoritesController favorites =
          FavoritesController(store: InMemoryFavoritesStore());

      favorites.add(makeFav('p1'));
      favorites.add(makeFav('p1'));

      expect(favorites.count, 1);
    });

    test('removing something never saved is a no-op', () {
      final FavoritesController favorites =
          FavoritesController(store: InMemoryFavoritesStore());

      favorites.remove('ghost');

      expect(favorites.count, 0);
    });

    test('newest saved comes first', () {
      final FavoritesController favorites =
          FavoritesController(store: InMemoryFavoritesStore());

      favorites.add(makeFav('p1'));
      favorites.add(makeFav('p2'));

      expect(favorites.favorites.first.id, 'p2');
      expect(favorites.favorites.last.id, 'p1');
    });

    test('count always equals the number of rows the list renders', () async {
      // The header-vs-list desync bug: count must never exceed favorites.length.
      final InMemoryFavoritesStore store = InMemoryFavoritesStore(<FavoritePlace>[
        makeFav('a'),
        makeFav('b'),
        makeFav('c'),
      ]);
      final FavoritesController favorites = FavoritesController(store: store);
      await favorites.load();

      expect(favorites.count, favorites.favorites.length);

      favorites.add(makeFav('d'));
      favorites.remove('a');

      expect(favorites.count, favorites.favorites.length);
    });

    test('listeners fire on every change', () {
      final FavoritesController favorites =
          FavoritesController(store: InMemoryFavoritesStore());
      int notifications = 0;
      favorites.addListener(() => notifications++);

      favorites.add(makeFav('p1'));
      favorites.remove('p1');

      expect(notifications, 2);
    });

    test('a no-op change does not notify', () {
      final FavoritesController favorites =
          FavoritesController(store: InMemoryFavoritesStore());
      favorites.add(makeFav('p1'));

      int notifications = 0;
      favorites.addListener(() => notifications++);

      favorites.add(makeFav('p1'));

      expect(notifications, 0);
    });
  });

  group('empty state', () {
    test('a fresh controller is empty', () {
      final FavoritesController favorites =
          FavoritesController(store: InMemoryFavoritesStore());

      expect(favorites.count, 0);
      expect(favorites.favorites, isEmpty);
    });

    test('clear empties everything', () {
      final FavoritesController favorites =
          FavoritesController(store: InMemoryFavoritesStore());
      favorites.add(makeFav('p1'));
      favorites.add(makeFav('p2'));

      favorites.clear();

      expect(favorites.count, 0);
      expect(favorites.favorites, isEmpty);
    });

    test('clearing an already-empty list does not notify', () {
      final FavoritesController favorites =
          FavoritesController(store: InMemoryFavoritesStore());
      int notifications = 0;
      favorites.addListener(() => notifications++);

      favorites.clear();

      expect(notifications, 0);
    });
  });

  group('persistent storage synchronisation', () {
    test('saving writes the place to the store', () async {
      final InMemoryFavoritesStore store = InMemoryFavoritesStore();
      final FavoritesController favorites = FavoritesController(store: store);

      favorites.add(makeFav('p1'));
      await Future<void>.delayed(Duration.zero);

      expect(store.places.map((f) => f.id), <String>['p1']);
    });

    test('removing writes the shortened set', () async {
      final InMemoryFavoritesStore store = InMemoryFavoritesStore();
      final FavoritesController favorites = FavoritesController(store: store);

      favorites.add(makeFav('p1'));
      favorites.add(makeFav('p2'));
      await Future<void>.delayed(Duration.zero);
      expect(store.places.map((f) => f.id).toSet(), <String>{'p1', 'p2'});

      favorites.remove('p1');
      await Future<void>.delayed(Duration.zero);

      expect(store.places.map((f) => f.id), <String>['p2']);
    });

    test('load restores places saved in a previous session', () async {
      final InMemoryFavoritesStore store = InMemoryFavoritesStore(<FavoritePlace>[
        makeFav('p1', savedAt: DateTime(2026, 1, 1)),
        makeFav('p2', savedAt: DateTime(2026, 2, 1)),
      ]);
      final FavoritesController favorites = FavoritesController(store: store);

      expect(favorites.count, 0);
      await favorites.load();

      expect(favorites.count, 2);
      expect(favorites.isLoaded, isTrue);
      expect(favorites.isFavorite('p1'), isTrue);
      // Newest first.
      expect(favorites.favorites.first.id, 'p2');
    });

    test('a restored place can be un-favourited', () async {
      final InMemoryFavoritesStore store =
          InMemoryFavoritesStore(<FavoritePlace>[makeFav('p1')]);
      final FavoritesController favorites = FavoritesController(store: store);
      await favorites.load();

      favorites.remove('p1');
      await Future<void>.delayed(Duration.zero);

      expect(favorites.count, 0);
      expect(store.places, isEmpty);
    });

    test('state survives a simulated restart', () async {
      final InMemoryFavoritesStore store = InMemoryFavoritesStore();

      final FavoritesController first = FavoritesController(store: store);
      first.add(makeFav('p1'));
      first.add(makeFav('p2'));
      await Future<void>.delayed(Duration.zero);
      first.dispose();

      final FavoritesController second = FavoritesController(store: store);
      await second.load();

      expect(second.count, 2);
      expect(second.isFavorite('p1'), isTrue);
      expect(second.isFavorite('p2'), isTrue);
    });

    test('FavoritePlace round-trips through JSON', () {
      final FavoritePlace original = FavoritePlace(
        id: 'ChIJabc',
        name: 'Kek Lok Si',
        category: 'heritage',
        savedAt: DateTime(2026, 3, 4, 5, 6, 7),
        latitude: 5.399,
        longitude: 100.274,
        photoUrl: 'https://example.com/p.jpg',
        rating: 4.8,
        address: 'Air Itam',
      );

      final FavoritePlace restored =
          FavoritePlace.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.category, original.category);
      expect(restored.savedAt, original.savedAt);
      expect(restored.latitude, original.latitude);
      expect(restored.longitude, original.longitude);
      expect(restored.photoUrl, original.photoUrl);
      expect(restored.rating, original.rating);
      expect(restored.address, original.address);
    });
  });

  group('detail hand-off', () {
    test('rememberPlaces lets the favorites list resolve a full Place',
        () async {
      final FavoritesController favorites =
          FavoritesController(store: InMemoryFavoritesStore());

      expect(favorites.fullPlace('p1'), isNull);

      favorites.rememberPlaces(<Place>[makePlace('p1')]);

      expect(favorites.fullPlace('p1')?.name, 'Place p1');
      // Doesn't create a favourite.
      expect(favorites.count, 0);
    });

    test('FavoritePlace.toPlace produces a usable stand-in', () {
      final Place place = makeFav('p1').toPlace();

      expect(place.id, 'p1');
      expect(place.category, PlaceCategory.food);
      expect(place.rating, 4.0);
    });
  });
}
