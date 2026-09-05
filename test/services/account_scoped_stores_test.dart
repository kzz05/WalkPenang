// Favourites and grey pins belong to a tourist, not to a phone.
//
// They used to live in SharedPreferences, which is device-wide, and that broke
// twice in a row: logging out deleted them, and once that was fixed, signing
// into a second Google account on the same phone showed the first account's
// saves. Both stores now write under users/{uid}, where the rest of the
// tourist's data already lives.
//
// Runs against an in-memory Firestore, so no live project is needed.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkpenang/models/favorite_place.dart';
import 'package:walkpenang/services/favorites_store.dart';
import 'package:walkpenang/services/routed_places_store.dart';

FavoritePlace _favourite(String id, {String name = 'Chew Jetty'}) =>
    FavoritePlace(
      id: id,
      name: name,
      category: 'attraction',
      savedAt: DateTime(2026, 9, 5),
      latitude: 5.4141,
      longitude: 100.3421,
    );

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() => firestore = FakeFirebaseFirestore());

  FirestoreFavoritesStore favouritesFor(String uid, {FavoritesStore? legacy}) =>
      FirestoreFavoritesStore(
        firestore: firestore,
        currentUserId: () => uid,
        legacyStore: legacy ?? InMemoryFavoritesStore(),
      );

  FirestoreRoutedPlacesStore routedFor(String uid, {RoutedPlacesStore? legacy}) =>
      FirestoreRoutedPlacesStore(
        firestore: firestore,
        currentUserId: () => uid,
        legacyStore: legacy ?? InMemoryRoutedPlacesStore(),
      );

  group('favourites belong to one account', () {
    test('what one tourist saves, another does not see', () async {
      await favouritesFor('tourist_a').save(<FavoritePlace>[
        _favourite('chew-jetty'),
        _favourite('kek-lok-si', name: 'Kek Lok Si Temple'),
      ]);

      expect(await favouritesFor('tourist_a').load(), hasLength(2));
      // The reported bug: signing into a second Google account on the same
      // phone showed the first account's favourites.
      expect(await favouritesFor('tourist_b').load(), isEmpty);
    });

    test('a save survives a reload', () async {
      await favouritesFor('tourist_a')
          .save(<FavoritePlace>[_favourite('chew-jetty')]);

      final loaded = await favouritesFor('tourist_a').load();

      expect(loaded.single.id, 'chew-jetty');
      expect(loaded.single.name, 'Chew Jetty');
      expect(loaded.single.latitude, 5.4141);
    });

    test('signed out, it reads empty and drops writes rather than throwing',
        () async {
      final store = favouritesFor('');

      await store.save(<FavoritePlace>[_favourite('chew-jetty')]);

      expect(await store.load(), isEmpty);
    });

    test('a document with no places field reads as empty', () async {
      await firestore
          .collection('users')
          .doc('tourist_a')
          .collection('app_data')
          .doc('favorites')
          .set(<String, dynamic>{'somethingElse': 42});

      expect(await favouritesFor('tourist_a').load(), isEmpty);
    });
  });

  group('routed places belong to one account', () {
    test('what one tourist walks, another does not see greyed', () async {
      await routedFor('tourist_a').save(<String>['chew-jetty', 'fort']);

      expect(await routedFor('tourist_a').load(), <String>['chew-jetty', 'fort']);
      expect(await routedFor('tourist_b').load(), isEmpty);
    });

    test('signed out, it reads empty and drops writes', () async {
      final store = routedFor('');

      await store.save(<String>['chew-jetty']);

      expect(await store.load(), isEmpty);
    });
  });

  group('the device-wide data already on the phone', () {
    test('moves to the first account that signs in, and only that one',
        () async {
      final legacyFavourites =
          InMemoryFavoritesStore(<FavoritePlace>[_favourite('chew-jetty')]);

      final adopted = await favouritesFor('tourist_a', legacy: legacyFavourites)
          .load();

      expect(adopted.single.id, 'chew-jetty', reason: 'the tourist keeps what '
          'was on the phone');
      // Read back from Firestore, not from the migration's return value.
      expect(await favouritesFor('tourist_a').load(), hasLength(1));
      // Cleared, so the next account cannot inherit it too — which is the
      // whole point of moving it.
      expect(legacyFavourites.places, isEmpty);
      expect(
        await favouritesFor('tourist_b', legacy: legacyFavourites).load(),
        isEmpty,
      );
    });

    test('routed ids move the same way', () async {
      final legacyRouted = InMemoryRoutedPlacesStore(<String>['chew-jetty']);

      expect(
        await routedFor('tourist_a', legacy: legacyRouted).load(),
        <String>['chew-jetty'],
      );
      expect(legacyRouted.placeIds, isEmpty);
      expect(await routedFor('tourist_b', legacy: legacyRouted).load(), isEmpty);
    });

    test('an account with its own document is never overwritten by the phone',
        () async {
      await favouritesFor('tourist_a')
          .save(<FavoritePlace>[_favourite('kek-lok-si')]);
      final legacy =
          InMemoryFavoritesStore(<FavoritePlace>[_favourite('chew-jetty')]);

      final loaded = await favouritesFor('tourist_a', legacy: legacy).load();

      expect(loaded.single.id, 'kek-lok-si');
      expect(legacy.places, hasLength(1), reason: 'nothing was migrated, so '
          'the local copy is left alone');
    });

    test('nothing on the phone migrates to an empty list, not an error',
        () async {
      expect(
        await favouritesFor('tourist_a', legacy: InMemoryFavoritesStore()).load(),
        isEmpty,
      );
    });
  });
}
