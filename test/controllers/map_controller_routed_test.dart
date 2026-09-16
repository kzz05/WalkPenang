// UC-M04: a place the tourist has already got a route to is remembered — in
// memory so MapView can grey out its pin and card, and on disk so the grey
// survives closing the app.
import 'package:flutter_test/flutter_test.dart';
import 'package:walkpenang/constants/map_constants.dart';
import 'package:walkpenang/controllers/map_controller.dart';
import 'package:walkpenang/services/routed_places_store.dart';

/// Persistence is fire-and-forget, so the write lands a microtask after the
/// call that triggered it returns.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late InMemoryRoutedPlacesStore store;
  late MapController controller;

  setUp(() {
    store = InMemoryRoutedPlacesStore();
    controller = MapController(routedPlacesStore: store);
  });
  tearDown(() => controller.dispose());

  group('in-memory behaviour', () {
    test('a place is not routed until it is marked', () {
      expect(controller.isPlaceRouted('place-a'), isFalse);
    });

    test('marking a place routed notifies listeners once', () {
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.markPlaceRouted('place-a');
      expect(controller.isPlaceRouted('place-a'), isTrue);
      expect(notifications, 1);

      // Re-marking is not new information: switching mode tabs and coming
      // back must not churn the marker set or redraw every pin.
      controller.markPlaceRouted('place-a');
      expect(notifications, 1);
    });

    test('routed places are tracked independently', () {
      controller.markPlaceRouted('place-a');

      expect(controller.isPlaceRouted('place-a'), isTrue);
      expect(controller.isPlaceRouted('place-b'), isFalse);
    });
  });

  group('persistence', () {
    test('marking a place writes it to the store', () async {
      controller.markPlaceRouted('place-a');
      await _settle();

      expect(store.placeIds, <String>['place-a']);
    });

    test('re-marking the same place does not rewrite the store', () async {
      controller.markPlaceRouted('place-a');
      await _settle();
      final int writesAfterFirst = store.saveCount;

      controller.markPlaceRouted('place-a');
      await _settle();

      expect(store.saveCount, writesAfterFirst);
    });

    test('a saved place is grey again in the next session', () async {
      final revived = MapController(
        routedPlacesStore: InMemoryRoutedPlacesStore(<String>['place-a']),
      );
      addTearDown(revived.dispose);

      expect(revived.isPlaceRouted('place-a'), isFalse);
      await revived.restoreRoutedPlaces();

      expect(revived.isPlaceRouted('place-a'), isTrue);
      expect(revived.isPlaceRouted('place-b'), isFalse);
    });

    test('a route resolved during the restore read is not lost', () async {
      final revived = MapController(
        routedPlacesStore: InMemoryRoutedPlacesStore(<String>['place-a']),
      );
      addTearDown(revived.dispose);

      // Restore is in flight; the tourist's current route resolves first.
      final Future<void> restoring = revived.restoreRoutedPlaces();
      revived.markPlaceRouted('place-b');
      await restoring;

      expect(revived.isPlaceRouted('place-a'), isTrue);
      expect(revived.isPlaceRouted('place-b'), isTrue);
    });

    test('clearing forgets every place, on disk too', () async {
      controller.markPlaceRouted('place-a');
      controller.markPlaceRouted('place-b');
      await _settle();

      controller.clearRoutedPlaces();
      await _settle();

      expect(controller.isPlaceRouted('place-a'), isFalse);
      expect(store.placeIds, isEmpty);
    });
  });

  group('growth cap', () {
    test('past the cap the oldest marks are dropped, newest kept', () async {
      const int cap = MapConstants.maxRememberedRoutedPlaces;
      const int excess = 5;

      for (var i = 0; i < cap + excess; i++) {
        controller.markPlaceRouted('place-$i');
      }
      await _settle();

      expect(store.placeIds, hasLength(cap));
      // The first `excess` marks are the oldest, so they are what goes.
      expect(controller.isPlaceRouted('place-0'), isFalse);
      expect(controller.isPlaceRouted('place-${excess - 1}'), isFalse);
      expect(controller.isPlaceRouted('place-$excess'), isTrue);
      expect(controller.isPlaceRouted('place-${cap + excess - 1}'), isTrue);
    });
  });
}
