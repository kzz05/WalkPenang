// Firestore-backed ratings, reviews and favourites for the Food & Attraction
// module.
//
// The point under test throughout: Firestore stores place *ids* and
// WalkPenang's own user-generated data, never place content. Nothing here
// asserts on a name, address or coordinate, because none of those are written.
//
// Runs against fake_cloud_firestore, so no live project, no network and no
// credentials — same approach as the Module 5 DAO tests.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:walkpenang/models/place.dart';
import 'package:walkpenang/models/rating_summary.dart';
import 'package:walkpenang/models/review.dart';
import 'package:walkpenang/models/search_filters.dart';
import 'package:walkpenang/services/favorites_store.dart';
import 'package:walkpenang/services/firestore_favorites_store.dart';
import 'package:walkpenang/services/firestore_place_repository.dart';
import 'package:walkpenang/services/place_repository.dart';

Place place(String id, {double rating = 4.0, int reviewCount = 100}) => Place(
      id: id,
      name: 'Place $id',
      category: PlaceCategory.food,
      priceLevel: PriceLevel.budget,
      distanceKm: 1,
      rating: rating,
      reviewCount: reviewCount,
      address: 'George Town',
    );

/// Stands in for whatever supplies the catalogue — today the mock, later a
/// Places-backed repository. Only fetchPlaces is exercised.
class _StubCatalogue implements PlaceRepository {
  _StubCatalogue(this.places);
  final List<Place> places;
  int fetchCount = 0;

  @override
  Future<PlacePage> fetchPlaces({
    required SearchFilters filters,
    required int page,
    int pageSize = 10,
  }) async {
    fetchCount++;
    return PlacePage(
      items: places,
      page: page,
      hasMore: false,
      totalCount: places.length,
    );
  }

  @override
  Future<List<Review>> fetchReviews(String placeId, {int limit = 3}) async => [];

  @override
  Future<Review> submitReview({
    required String placeId,
    required int rating,
    required String body,
    required String authorName,
    int photoCount = 0,
  }) async =>
      throw UnimplementedError();

  @override
  RatingSummary ratingFor(Place p) =>
      RatingSummary(average: p.rating, count: p.reviewCount);
}

void main() {
  group('FirestorePlaceRepository', () {
    late FakeFirebaseFirestore db;
    late _StubCatalogue catalogue;
    late FirestorePlaceRepository repository;

    setUp(() {
      db = FakeFirebaseFirestore();
      catalogue = _StubCatalogue([place('p01'), place('p02')]);
      repository = FirestorePlaceRepository(
        catalogue: catalogue,
        firestore: db,
        currentUid: () => 'uid-1',
      );
    });

    test('the catalogue decides which places exist, not Firestore', () async {
      // Nothing seeded in Firestore at all, yet both places come back: the
      // catalogue is the source of truth for existence.
      final page = await repository.fetchPlaces(
        filters: const SearchFilters(),
        page: 0,
      );

      expect(page.items.map((p) => p.id), <String>['p01', 'p02']);
      expect(catalogue.fetchCount, 1);
    });

    test('a place nobody has reviewed keeps the catalogue rating', () async {
      final page = await repository.fetchPlaces(
        filters: const SearchFilters(),
        page: 0,
      );

      final summary = repository.ratingFor(page.items.first);
      expect(summary.average, 4.0);
      expect(summary.count, 100);
    });

    test('WalkPenang reviews override the catalogue rating', () async {
      await db.collection('places').doc('p01').set(<String, dynamic>{
        'ratingSum': 9,
        'ratingCount': 2,
        'reviewCount': 2,
      });

      final page = await repository.fetchPlaces(
        filters: const SearchFilters(),
        page: 0,
      );

      final summary = repository.ratingFor(page.items.first);
      expect(summary.average, 4.5);
      expect(summary.count, 2);
      // p02 has no document, so it must fall back rather than read as 0 stars.
      expect(repository.ratingFor(page.items[1]).average, 4.0);
    });

    test('submitting a review writes it and folds it into the aggregate',
        () async {
      await repository.submitReview(
        placeId: 'p01',
        rating: 5,
        body: 'Outstanding char kway teow.',
        authorName: 'Wei Ming',
      );

      final aggregate =
          (await db.collection('places').doc('p01').get()).data()!;
      expect(aggregate['ratingSum'], 5);
      expect(aggregate['ratingCount'], 1);
      expect(aggregate['reviewCount'], 1);

      final reviews =
          await db.collection('places').doc('p01').collection('reviews').get();
      expect(reviews.docs, hasLength(1));
      expect(reviews.docs.first.data()['authorUid'], 'uid-1');
      expect(reviews.docs.first.data()['rating'], 5);
    });

    test('a second review accumulates rather than replacing', () async {
      await repository.submitReview(
        placeId: 'p01', rating: 5, body: 'a', authorName: 'A');
      await repository.submitReview(
        placeId: 'p01', rating: 3, body: 'b', authorName: 'B');

      final aggregate =
          (await db.collection('places').doc('p01').get()).data()!;
      expect(aggregate['ratingSum'], 8);
      expect(aggregate['ratingCount'], 2);

      await repository.fetchPlaces(filters: const SearchFilters(), page: 0);
      expect(repository.ratingFor(place('p01')).average, 4.0);
    });

    test('stores no place content — only the id and our own aggregates',
        () async {
      await repository.submitReview(
        placeId: 'p01', rating: 4, body: 'Good', authorName: 'A');

      final stored =
          (await db.collection('places').doc('p01').get()).data()!;
      // The guard against a future change quietly reintroducing a catalogue
      // copy, which is what Google Maps Platform Terms 3.2.3(b) forbids.
      for (final banned in ['name', 'address', 'latitude', 'longitude',
          'photoUrls', 'description', 'category']) {
        expect(stored.containsKey(banned), isFalse,
            reason: '$banned is place content and must not be stored');
      }
    });
  });

  group('FirestoreFavoritesStore', () {
    late FakeFirebaseFirestore db;
    late InMemoryFavoritesStore local;

    setUp(() {
      db = FakeFirebaseFirestore();
      local = InMemoryFavoritesStore();
    });

    FirestoreFavoritesStore storeFor(String? uid) => FirestoreFavoritesStore(
          firestore: db,
          currentUid: () => uid,
          fallback: local,
        );

    test('signed in: saves one document per place id', () async {
      final store = storeFor('uid-1');
      await store.saveIds(<String>{'p01', 'p02'});

      final docs = await db
          .collection('users')
          .doc('uid-1')
          .collection('favorites')
          .get();
      expect(docs.docs.map((d) => d.id).toSet(), <String>{'p01', 'p02'});
      expect(await store.loadIds(), <String>{'p01', 'p02'});
    });

    test('removing a favourite deletes only that document', () async {
      final store = storeFor('uid-1');
      await store.saveIds(<String>{'p01', 'p02'});
      await store.saveIds(<String>{'p02'});

      expect(await store.loadIds(), <String>{'p02'});
    });

    test('signed out: falls back to the local store', () async {
      final store = storeFor(null);
      await store.saveIds(<String>{'p03'});

      expect(local.ids, <String>{'p03'});
      expect(await store.loadIds(), <String>{'p03'});
      final docs = await db.collectionGroup('favorites').get();
      expect(docs.docs, isEmpty);
    });

    test('signing in merges local favourites rather than dropping them',
        () async {
      await local.saveIds(<String>{'p-local'});
      await db
          .collection('users')
          .doc('uid-1')
          .collection('favorites')
          .doc('p-cloud')
          .set(<String, dynamic>{});

      final store = storeFor('uid-1');
      await store.migrateLocalFavorites();

      expect(await store.loadIds(), <String>{'p-local', 'p-cloud'});
    });
  });
}
