import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:walkpenang/controllers/discovery_controller.dart';
import 'package:walkpenang/models/place.dart';
import 'package:walkpenang/models/search_filter.dart';
import 'package:walkpenang/views/discovery_feed_screen.dart';
import 'package:walkpenang/services/place_repository.dart';
import 'package:walkpenang/views/widgets/place_card.dart';

/// T-FD02.3 — feed rendering, offline image fallback, API timeout errors.
///
/// Note on images: flutter_test blocks real HTTP, so every CachedNetworkImage
/// falls through to its errorWidget. That's convenient — it means these tests
/// exercise the offline fallback path by default.
void main() {
  /// Fake repository with no real latency, so tests stay fast and predictable.
  late _FakeRepository repository;

  Place makePlace(int index) => Place(
    id: 'p$index',
    name: 'Place $index',
    category: 'Cafe',
    imageUrl: 'https://example.com/$index.jpg',
    priceLevel: PriceLevel.budget,
    distanceKm: index.toDouble(),
    rating: 4.0,
    description: 'Description $index',
  );

  Future<void> pumpFeed(
      WidgetTester tester,
      DiscoveryController controller,
      ) async {
    await tester.pumpWidget(
      MaterialApp(home: DiscoveryFeedScreen(controller: controller)),
    );
    // One pump runs the post-frame loadInitial, the next settles the result.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  setUp(() {
    repository = _FakeRepository();
  });

  group('feed rendering', () {
    testWidgets('renders a card per place', (WidgetTester tester) async {
      // ListView.builder only creates visible rows, so the default 800x600
      // surface fits two cards. Give it room for all three.
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      repository.pages = <List<Place>>[
        <Place>[makePlace(1), makePlace(2), makePlace(3)],
      ];
      final DiscoveryController controller =
      DiscoveryController(repository: repository, pageSize: 3);
      addTearDown(controller.dispose);

      await pumpFeed(tester, controller);

      expect(find.byType(PlaceCard), findsNWidgets(3));
      expect(find.text('Place 1'), findsOneWidget);
    });

    testWidgets('shows a spinner before the first page arrives',
            (WidgetTester tester) async {
          repository.pages = <List<Place>>[
            <Place>[makePlace(1)],
          ];
          repository.latency = const Duration(seconds: 1);
          final DiscoveryController controller =
          DiscoveryController(repository: repository);
          addTearDown(controller.dispose);

          await tester.pumpWidget(
            MaterialApp(home: DiscoveryFeedScreen(controller: controller)),
          );
          await tester.pump();

          expect(find.byType(CircularProgressIndicator), findsWidgets);

          await tester.pump(const Duration(seconds: 1));
          expect(find.byType(PlaceCard), findsOneWidget);
        });

    testWidgets('falls back gracefully when images cannot load',
            (WidgetTester tester) async {
          // No network in tests, so the errorWidget renders. The card must still
          // lay out and show its text rather than throwing.
          repository.pages = <List<Place>>[
            <Place>[makePlace(1)],
          ];
          final DiscoveryController controller =
          DiscoveryController(repository: repository);
          addTearDown(controller.dispose);

          await pumpFeed(tester, controller);
          await tester.pump(const Duration(milliseconds: 300));

          expect(tester.takeException(), isNull);
          expect(find.text('Place 1'), findsOneWidget);
        });
  });

  group('zero-result state', () {
    testWidgets('shows the empty state with a clear-filters action',
            (WidgetTester tester) async {
          repository.pages = <List<Place>>[<Place>[]];
          final DiscoveryController controller =
          DiscoveryController(repository: repository);
          addTearDown(controller.dispose);

          await pumpFeed(tester, controller);

          expect(find.text('No matches'), findsOneWidget);
          expect(find.byType(PlaceCard), findsNothing);
          expect(find.widgetWithText(FilledButton, 'Clear filters'), findsWidgets);
        });
  });

  group('API errors', () {
    testWidgets('timeout shows the error state with a retry',
            (WidgetTester tester) async {
          repository.error = const ApiTimeoutException();
          final DiscoveryController controller =
          DiscoveryController(repository: repository);
          addTearDown(controller.dispose);

          await pumpFeed(tester, controller);

          expect(find.text('Feed unavailable'), findsOneWidget);
          expect(find.text('Try again'), findsOneWidget);
        });

    testWidgets('retry refetches and recovers', (WidgetTester tester) async {
      repository.error = const ApiFailureException();
      final DiscoveryController controller =
      DiscoveryController(repository: repository);
      addTearDown(controller.dispose);

      await pumpFeed(tester, controller);
      expect(find.text('Feed unavailable'), findsOneWidget);

      // Backend comes back up.
      repository.error = null;
      repository.pages = <List<Place>>[
        <Place>[makePlace(1)],
      ];

      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(PlaceCard), findsOneWidget);
    });

    test('a failed load-more keeps the pages already on screen', () async {
      repository.pages = <List<Place>>[
        <Place>[makePlace(1), makePlace(2)],
        // A second page, so hasMore stays true and loadMore actually fetches.
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
        // Backend accidentally repeats an item across page boundaries.
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

      await controller.updateFilters(const SearchFilters(keyword: 'cafe'));

      expect(controller.places, hasLength(2));
      expect(repository.lastFilters?.keyword, 'cafe');
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
}

/// Scriptable stand-in for the API: hand it pages, or an error to throw.
class _FakeRepository implements PlaceRepository {
  List<List<Place>> pages = <List<Place>>[];
  Exception? error;
  Duration latency = Duration.zero;
  int callCount = 0;
  SearchFilters? lastFilters;

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

    if (page >= pages.length) {
      return PlacePage(items: const <Place>[], page: page, hasMore: false);
    }

    return PlacePage(
      items: pages[page],
      page: page,
      hasMore: page + 1 < pages.length,
    );
  }
}