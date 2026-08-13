import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:walkpenang/controllers/discovery_controller.dart';
import 'package:walkpenang/controllers/favorites_controller.dart';
import 'package:walkpenang/models/place.dart';
import 'package:walkpenang/models/rating_summary.dart';
import 'package:walkpenang/models/review.dart';
import 'package:walkpenang/models/search_filters.dart';
import 'package:walkpenang/services/favorites_store.dart';
import 'package:walkpenang/services/place_repository.dart';
import 'package:walkpenang/theme/discovery_theme.dart';
import 'package:walkpenang/views/discovery_feed_view.dart';
import 'package:walkpenang/views/widgets/place_grid_card.dart';

/// T-FD02.3 — feed rendering, offline image fallback, API timeout errors,
/// plus the favourites flow.
///
/// Note on images: flutter_test blocks real HTTP, so every CachedNetworkImage
/// falls through to its errorWidget. Convenient — these tests exercise the
/// offline fallback path by default.
void main() {
  late _FakeRepository repository;

  Place makePlace(int index) => Place(
    id: 'p$index',
    name: 'Place $index',
    category: PlaceCategory.food,
    photoUrls: <String>['https://example.com/$index.jpg'],
    priceLevel: PriceLevel.budget,
    distanceKm: index.toDouble(),
    rating: 4.0,
    reviewCount: 100 + index,
    address: 'Address $index',
    hours: const OpeningHours(opensAtHour: 0, closesAtHour: 24),
    description: 'Description $index',
  );

  Future<void> pumpFeed(
      WidgetTester tester,
      DiscoveryController controller,
      FavoritesController favorites,
      ) async {
    // The default test surface is 800x600 — landscape, and short. The feed is
    // a 2-column grid at childAspectRatio 0.82 built lazily, so on that surface
    // only the first row is ever constructed and any assertion past the second
    // card fails against a grid that is in fact laying out correctly. Pin a
    // portrait phone instead: the shape this screen is designed for.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: discoveryTheme,
        home: DiscoveryFeedView(
          controller: controller,
          favorites: favorites,
          repository: repository,
        ),
      ),
    );
    // One pump runs the post-frame loadInitial, the next settles the result.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  FavoritesController makeFavorites() =>
      FavoritesController(store: InMemoryFavoritesStore());

  setUp(() {
    repository = _FakeRepository();
  });

  group('feed rendering', () {
    testWidgets('renders a grid card per place', (WidgetTester tester) async {
      repository.pages = <List<Place>>[
        <Place>[makePlace(1), makePlace(2), makePlace(3)],
      ];
      final DiscoveryController controller =
      DiscoveryController(repository: repository, pageSize: 3);
      final FavoritesController favorites = makeFavorites();
      addTearDown(controller.dispose);

      await pumpFeed(tester, controller, favorites);

      expect(find.byType(PlaceGridCard), findsNWidgets(3));
      expect(find.text('Place 1'), findsOneWidget);
    });

    testWidgets('shows the nearby count header', (WidgetTester tester) async {
      repository.pages = <List<Place>>[
        <Place>[makePlace(1), makePlace(2)],
      ];
      repository.totalCount = 12;
      final DiscoveryController controller =
      DiscoveryController(repository: repository, pageSize: 2);
      final FavoritesController favorites = makeFavorites();
      addTearDown(controller.dispose);

      await pumpFeed(tester, controller, favorites);

      expect(find.text('Nearby you (12 places)'), findsOneWidget);
    });

    testWidgets('falls back gracefully when images cannot load',
            (WidgetTester tester) async {
          repository.pages = <List<Place>>[
            <Place>[makePlace(1)],
          ];
          final DiscoveryController controller =
          DiscoveryController(repository: repository);
          final FavoritesController favorites = makeFavorites();
          addTearDown(controller.dispose);

          await pumpFeed(tester, controller, favorites);
          await tester.pump(const Duration(milliseconds: 300));

          expect(tester.takeException(), isNull);
          expect(find.text('Place 1'), findsOneWidget);
        });

    testWidgets('a place with no photos still renders',
            (WidgetTester tester) async {
          repository.pages = <List<Place>>[
            <Place>[
              const Place(
                id: 'nophoto',
                name: 'No Photo Place',
                category: PlaceCategory.shopping,
                priceLevel: PriceLevel.budget,
                distanceKm: 1.0,
                rating: 4.0,
                reviewCount: 10,
                address: 'Somewhere',
              ),
            ],
          ];
          final DiscoveryController controller =
          DiscoveryController(repository: repository);
          final FavoritesController favorites = makeFavorites();
          addTearDown(controller.dispose);

          await pumpFeed(tester, controller, favorites);

          expect(tester.takeException(), isNull);
          expect(find.text('No Photo Place'), findsOneWidget);
        });
  });

  group('zero-result state', () {
    testWidgets('shows the empty state with a clear-filters action',
            (WidgetTester tester) async {
          repository.pages = <List<Place>>[<Place>[]];
          final DiscoveryController controller =
          DiscoveryController(repository: repository);
          final FavoritesController favorites = makeFavorites();
          addTearDown(controller.dispose);

          await pumpFeed(tester, controller, favorites);

          expect(find.text('No matches'), findsOneWidget);
          expect(find.byType(PlaceGridCard), findsNothing);
          expect(find.text('Clear filters'), findsOneWidget);
        });
  });

  group('API errors', () {
    testWidgets('timeout shows the error state with a retry',
            (WidgetTester tester) async {
          repository.error = const ApiTimeoutException();
          final DiscoveryController controller =
          DiscoveryController(repository: repository);
          final FavoritesController favorites = makeFavorites();
          addTearDown(controller.dispose);

          await pumpFeed(tester, controller, favorites);

          expect(find.text('Feed unavailable'), findsOneWidget);
          expect(find.text('Try again'), findsOneWidget);
        });

    testWidgets('retry refetches and recovers', (WidgetTester tester) async {
      repository.error = const ApiFailureException();
      final DiscoveryController controller =
      DiscoveryController(repository: repository);
      final FavoritesController favorites = makeFavorites();
      addTearDown(controller.dispose);

      await pumpFeed(tester, controller, favorites);
      expect(find.text('Feed unavailable'), findsOneWidget);

      repository.error = null;
      repository.pages = <List<Place>>[
        <Place>[makePlace(1)],
      ];

      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(PlaceGridCard), findsOneWidget);
    });

    test('a failed load-more keeps the pages already on screen', () async {
      // Two pages, so hasMore is true after the first load. With a single page
      // the controller correctly refuses to load more and returns before it
      // ever reaches the repository — the injected error would never be
      // thrown and errorMessage would stay null.
      repository.pages = <List<Place>>[
        <Place>[makePlace(1), makePlace(2)],
        <Place>[makePlace(3), makePlace(4)],
      ];
      final DiscoveryController controller =
      DiscoveryController(repository: repository, pageSize: 2);
      addTearDown(controller.dispose);

      await controller.loadInitial();
      expect(controller.places, hasLength(2));

      repository.error = const ApiTimeoutException();
      await controller.loadMore();

      expect(controller.places, hasLength(2));
      expect(controller.status, FeedStatus.ready);
      expect(controller.errorMessage, isNotNull);
    });
  });

  group('pagination', () {
    test('loadMore appends the next page', () async {
      repository.pages = <List<Place>>[
        <Place>[makePlace(1), makePlace(2)],
        <Place>[makePlace(3), makePlace(4)],
      ];
      final DiscoveryController controller =
      DiscoveryController(repository: repository, pageSize: 2);
      addTearDown(controller.dispose);

      await controller.loadInitial();
      expect(controller.places, hasLength(2));

      await controller.loadMore();
      expect(controller.places, hasLength(4));
      expect(controller.places.last.id, 'p4');
    });

    test('stops fetching once the last page is reached', () async {
      repository.pages = <List<Place>>[
        <Place>[makePlace(1)],
      ];
      final DiscoveryController controller =
      DiscoveryController(repository: repository, pageSize: 1);
      addTearDown(controller.dispose);

      await controller.loadInitial();
      expect(controller.hasMore, isFalse);

      final int callsBefore = repository.callCount;
      await controller.loadMore();
      expect(repository.callCount, callsBefore);
    });

    test('never adds the same place twice', () async {
      repository.pages = <List<Place>>[
        <Place>[makePlace(1), makePlace(2)],
        <Place>[makePlace(2), makePlace(3)],
      ];
      final DiscoveryController controller =
      DiscoveryController(repository: repository, pageSize: 2);
      addTearDown(controller.dispose);

      await controller.loadInitial();
      await controller.loadMore();

      expect(controller.places.map((Place p) => p.id).toSet(), hasLength(3));
    });

    test('refresh resets to page zero', () async {
      repository.pages = <List<Place>>[
        <Place>[makePlace(1), makePlace(2)],
        <Place>[makePlace(3), makePlace(4)],
      ];
      final DiscoveryController controller =
      DiscoveryController(repository: repository, pageSize: 2);
      addTearDown(controller.dispose);

      await controller.loadInitial();
      await controller.loadMore();
      expect(controller.places, hasLength(4));

      await controller.refresh();
      expect(controller.places, hasLength(2));
    });

    test('changing filters resets the cursor', () async {
      repository.pages = <List<Place>>[
        <Place>[makePlace(1), makePlace(2)],
        <Place>[makePlace(3), makePlace(4)],
      ];
      final DiscoveryController controller =
      DiscoveryController(repository: repository, pageSize: 2);
      addTearDown(controller.dispose);

      await controller.loadInitial();
      await controller.loadMore();

      await controller.updateFilters(
        const SearchFilters(categories: <PlaceCategory>{PlaceCategory.nature}),
      );

      expect(controller.places, hasLength(2));
      expect(
        repository.lastFilters?.categories,
        contains(PlaceCategory.nature),
      );
    });

    test('identical filters do not trigger a refetch', () async {
      repository.pages = <List<Place>>[
        <Place>[makePlace(1)],
      ];
      final DiscoveryController controller =
      DiscoveryController(repository: repository);
      addTearDown(controller.dispose);

      await controller.loadInitial();
      final int callsBefore = repository.callCount;

      await controller.updateFilters(const SearchFilters());

      expect(repository.callCount, callsBefore);
    });
  });

  group('favourites from the feed', () {
    testWidgets('tapping the heart on a card saves it',
            (WidgetTester tester) async {
          repository.pages = <List<Place>>[
            <Place>[makePlace(1)],
          ];
          final DiscoveryController controller =
          DiscoveryController(repository: repository);
          final FavoritesController favorites = makeFavorites();
          addTearDown(controller.dispose);

          await pumpFeed(tester, controller, favorites);

          await tester.tap(find.byIcon(Icons.favorite_border_rounded).first);
          await tester.pump();

          expect(favorites.count, 1);
          expect(find.text('Added to Favorites'), findsOneWidget);
        });
  });

  group('reviews', () {
    test('submitting returns a review attached to the place', () async {
      final Review review = await repository.submitReview(
        placeId: 'p1',
        rating: 4,
        body: 'Solid spot, would come back.',
        authorName: 'You',
      );

      expect(review.placeId, 'p1');
      expect(review.rating, 4);
      expect(review.initials, 'Y');
    });

    test('submitted reviews come back at the top of the list', () async {
      await repository.submitReview(
        placeId: 'p1',
        rating: 5,
        body: 'Excellent, go at sunset.',
        authorName: 'Ong Song Wei',
      );

      final List<Review> reviews = await repository.fetchReviews('p1');
      expect(reviews.first.authorName, 'Ong Song Wei');
      expect(reviews.first.initials, 'OW');
    });
  });
}

/// Scriptable stand-in for the API: hand it pages, or an error to throw.
class _FakeRepository implements PlaceRepository {
  List<List<Place>> pages = <List<Place>>[];
  Exception? error;
  Duration latency = Duration.zero;
  int callCount = 0;
  int? totalCount;
  SearchFilters? lastFilters;

  final Map<String, List<Review>> _reviews = <String, List<Review>>{};

  @override
  Future<PlacePage> fetchPlaces({
    required SearchFilters filters,
    required int page,
    int pageSize = 10,
  }) async {
    callCount++;
    lastFilters = filters;

    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }

    if (error != null) throw error!;

    final int total = totalCount ??
        pages.fold<int>(0, (int sum, List<Place> p) => sum + p.length);

    if (page >= pages.length) {
      return PlacePage(
        items: const <Place>[],
        page: page,
        hasMore: false,
        totalCount: total,
      );
    }

    return PlacePage(
      items: pages[page],
      page: page,
      hasMore: page + 1 < pages.length,
      totalCount: total,
    );
  }

  @override
  Future<List<Review>> fetchReviews(String placeId, {int limit = 3}) async {
    if (error != null) throw error!;
    return (_reviews[placeId] ?? const <Review>[]).take(limit).toList();
  }

  @override
  Future<Review> submitReview({
    required String placeId,
    required int rating,
    required String body,
    required String authorName,
    int photoCount = 0,
  }) async {
    if (error != null) throw error!;

    final Review review = Review(
      id: 'r-${DateTime.now().microsecondsSinceEpoch}',
      placeId: placeId,
      authorName: authorName,
      rating: rating,
      body: body,
      createdAt: DateTime.now(),
      photoCount: photoCount,
    );

    _reviews.putIfAbsent(placeId, () => <Review>[]).insert(0, review);
    return review;
  }

  @override
  RatingSummary ratingFor(Place place) {
    final RatingSummary seeded = RatingSummary(
      average: place.rating,
      count: place.reviewCount,
    );
    final List<Review> mine = _reviews[place.id] ?? const <Review>[];
    if (mine.isEmpty) return seeded;
    return seeded.withReviews(mine.map((Review r) => r.rating));
  }
}