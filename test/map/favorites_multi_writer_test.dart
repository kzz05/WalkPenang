// Two screens write favourites from independently-loaded snapshots: the map
// (MapPanel._favoriteIds) and the Discovery feed (FavoritesController). Both
// share one FavoritesStore.
//
// The bug these guard: FavoritesStore.saveIds replaces the whole set, so a
// writer holding a stale snapshot deleted whatever the other had saved since.
// addId/removeId touch one id and cannot.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:walkpenang/services/favorites_store.dart';
import 'package:walkpenang/services/firestore_favorites_store.dart';

void main() {
  group('single-id writes do not clobber another writer', () {
    late FakeFirebaseFirestore db;

    /// Two stores over one backend — the map's and Discovery's.
    FirestoreFavoritesStore screen() => FirestoreFavoritesStore(
          firestore: db,
          currentUid: () => 'uid-1',
          fallback: InMemoryFavoritesStore(),
        );

    setUp(() => db = FakeFirebaseFirestore());

    test('saving on one screen keeps what the other saved', () async {
      final discovery = screen();
      final map = screen();

      // Both load an empty set, as they would at startup.
      expect(await discovery.loadIds(), isEmpty);
      expect(await map.loadIds(), isEmpty);

      await discovery.addId('p-discovery');
      // The map's snapshot predates that save and knows nothing about it.
      await map.addId('p-map');

      expect(await map.loadIds(), <String>{'p-discovery', 'p-map'});
    });

    test('unsaving removes only the id asked for', () async {
      final store = screen();
      await store.addId('p01');
      await store.addId('p02');

      await store.removeId('p01');

      expect(await store.loadIds(), <String>{'p02'});
    });

    test('adding the same id twice is idempotent', () async {
      final store = screen();
      await store.addId('p01');
      await store.addId('p01');
      expect(await store.loadIds(), <String>{'p01'});
    });

    test('saveIds still replaces wholesale — the documented behaviour', () async {
      // Kept for clear() and migrateLocalFavorites, which own the whole set.
      // This test exists so the clobber is a decision, not a surprise.
      final store = screen();
      await store.addId('p01');
      await store.addId('p02');

      await store.saveIds(<String>{'p02'});

      expect(await store.loadIds(), <String>{'p02'});
    });
  });

  group('SharedPrefs store honours the same contract', () {
    test('addId and removeId affect one id', () async {
      final store = InMemoryFavoritesStore(<String>{'p01'});
      await store.addId('p02');
      expect(store.ids, <String>{'p01', 'p02'});

      await store.removeId('p01');
      expect(store.ids, <String>{'p02'});
    });
  });
}
