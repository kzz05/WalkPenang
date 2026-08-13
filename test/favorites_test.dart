import 'package:flutter_test/flutter_test.dart';

import 'package:walkpenang/controllers/favorites_controller.dart';
import 'package:walkpenang/models/place.dart';
import 'package:walkpenang/services/favorites_store.dart';

/// T-FD04.3 — favouriting toggle states, empty list, persistent storage sync.
void main() {
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
      final Place place = makePlace('p1');

      expect(favorites.isFavorite(place), isFalse);

      expect(favorites.toggle(place), isTrue);
      expect(favorites.isFavorite(place), isTrue);
      expect(favorites.count, 1);

      expect(favorites.toggle(place), isFalse);
      expect(favorites.isFavorite(place), isFalse);
      expect(favorites.count, 0);
    });

    test('adding the same place twice does not duplicate', () {
      final FavoritesController favorites =
      FavoritesController(store: InMemoryFavoritesStore());
      final Place place = makePlace('p1');

      favorites.add(place);
      favorites.add(place);

      expect(favorites.count, 1);
    });

    test('removing something never saved is a no-op', () {
      final FavoritesController favorites =
      FavoritesController(store: InMemoryFavoritesStore());

      favorites.remove(makePlace('ghost'));

      expect(favorites.count, 0);
    });

    test('newest saved comes first', () {
      final FavoritesController favorites =
      FavoritesController(store: InMemoryFavoritesStore());

      favorites.add(makePlace('p1'));
      favorites.add(makePlace('p2'));

      expect(favorites.places.first.id, 'p2');
      expect(favorites.places.last.id, 'p1');
    });

    test('listeners fire on every change', () {
      final FavoritesController favorites =
      FavoritesController(store: InMemoryFavoritesStore());
      int notifications = 0;
      favorites.addListener(() => notifications++);

      favorites.add(makePlace('p1'));
      favorites.remove(makePlace('p1'));

      expect(notifications, 2);
    });

    test('a no-op change does not notify', () {
      final FavoritesController favorites =
      FavoritesController(store: InMemoryFavoritesStore());
      favorites.add(makePlace('p1'));

      int notifications = 0;
      favorites.addListener(() => notifications++);

      // Already saved, so nothing should change.
      favorites.add(makePlace('p1'));

      expect(notifications, 0);
    });
  });

  group('empty state', () {
    test('a fresh controller is empty', () {
      final FavoritesController favorites =
      FavoritesController(store: InMemoryFavoritesStore());

      expect(favorites.count, 0);
      expect(favorites.places, isEmpty);
    });

    test('clear empties everything', () {
      final FavoritesController favorites =
      FavoritesController(store: InMemoryFavoritesStore());
      favorites.add(makePlace('p1'));
      favorites.add(makePlace('p2'));

      favorites.clear();

      expect(favorites.count, 0);
      expect(favorites.places, isEmpty);
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
    test('saving writes the id to the store', () async {
      final InMemoryFavoritesStore store = InMemoryFavoritesStore();
      final FavoritesController favorites =
      FavoritesController(store: store);

      favorites.add(makePlace('p1'));
      // The write is fire-and-forget, so let the microtask queue drain.
      await Future<void>.delayed(Duration.zero);

      expect(store.ids, <String>{'p1'});
    });

    test('removing writes the shortened set', () async {
      final InMemoryFavoritesStore store = InMemoryFavoritesStore();
      final FavoritesController favorites =
      FavoritesController(store: store);

      favorites.add(makePlace('p1'));
      favorites.add(makePlace('p2'));
      await Future<void>.delayed(Duration.zero);
      expect(store.ids, <String>{'p1', 'p2'});

      favorites.remove(makePlace('p1'));
      await Future<void>.delayed(Duration.zero);

      expect(store.ids, <String>{'p2'});
    });

    test('load restores ids saved in a previous session', () async {
      final InMemoryFavoritesStore store =
      InMemoryFavoritesStore(<String>{'p1', 'p2'});
      final FavoritesController favorites =
      FavoritesController(store: store);

      expect(favorites.count, 0);
      await favorites.load();

      // Counted immediately, even before the Place objects arrive.
      expect(favorites.count, 2);
      expect(favorites.isLoaded, isTrue);
      expect(favorites.isFavorite(makePlace('p1')), isTrue);
    });

    test('hydrate attaches Place objects to restored ids', () async {
      final InMemoryFavoritesStore store =
      InMemoryFavoritesStore(<String>{'p1'});
      final FavoritesController favorites =
      FavoritesController(store: store);
      await favorites.load();

      // Restored but not yet renderable.
      expect(favorites.places, isEmpty);
      expect(favorites.count, 1);

      favorites.hydrate(<Place>[makePlace('p1'), makePlace('p9')]);

      expect(favorites.places.single.id, 'p1');
      expect(favorites.count, 1);
    });

    test('hydrate ignores places that were never saved', () async {
      final InMemoryFavoritesStore store =
      InMemoryFavoritesStore(<String>{'p1'});
      final FavoritesController favorites =
      FavoritesController(store: store);
      await favorites.load();

      favorites.hydrate(<Place>[makePlace('p7'), makePlace('p8')]);

      expect(favorites.places, isEmpty);
      expect(favorites.count, 1);
    });

    test('a restored id can be un-favourited before it is hydrated', () async {
      final InMemoryFavoritesStore store =
      InMemoryFavoritesStore(<String>{'p1'});
      final FavoritesController favorites =
      FavoritesController(store: store);
      await favorites.load();

      favorites.remove(makePlace('p1'));
      await Future<void>.delayed(Duration.zero);

      expect(favorites.count, 0);
      expect(store.ids, isEmpty);
    });

    test('state survives a simulated restart', () async {
      final InMemoryFavoritesStore store = InMemoryFavoritesStore();

      final FavoritesController first = FavoritesController(store: store);
      first.add(makePlace('p1'));
      first.add(makePlace('p2'));
      await Future<void>.delayed(Duration.zero);
      first.dispose();

      // New controller, same store — as if the app had been relaunched.
      final FavoritesController second = FavoritesController(store: store);
      await second.load();

      expect(second.count, 2);
      expect(second.isFavorite(makePlace('p1')), isTrue);
      expect(second.isFavorite(makePlace('p2')), isTrue);
    });
  });
}