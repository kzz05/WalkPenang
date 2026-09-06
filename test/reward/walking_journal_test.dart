// Tests for the walking journal (UC520 / FR-R03).
//
// The journal reads Module 4's check_ins rather than a collection of its own,
// which means it inherits records written before the fields it needs existed.
// Those are real journeys the tourist walked, so the rule throughout is that
// a missing field degrades to an honest placeholder and never drops the row
// or fabricates a figure.
//
// No Firebase project: the controller takes the DAO as its abstraction, and
// the DAO itself runs against fake_cloud_firestore — the same in-memory
// Firestore reward_dao_test uses.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:walkpenang/controllers/journal_controller.dart';
import '../support/in_memory_reward_data.dart';
import 'package:walkpenang/dao/journal_dao.dart';
import 'package:walkpenang/models/journal_entry_model.dart';
import 'package:walkpenang/models/transport_mode.dart';
import 'package:walkpenang/utils/reward_constants.dart';
import 'package:walkpenang/views/reward/walking_journal_screen.dart';

/// Always fails, for the error-state test.
class _FailingJournalDao implements JournalDao {
  @override
  Future<List<JournalEntryModel>> fetchEntries(
    String userId, {
    int limit = 50,
  }) async {
    throw StateError('missing index');
  }
}

void main() {
  group('JournalEntryModel.fromMap', () {
    test('reads a complete check-in', () {
      final entry = JournalEntryModel.fromMap('doc-1', {
        'checkInId': 'doc-1',
        'destinationName': 'Chew Jetty',
        'destinationId': 'ChIJ50W1D43DSjARlPqYV1MqscE',
        'checkInTime': DateTime(2026, 8, 21, 10, 30),
        'distanceKm': 1.282,
        'pointsAwarded': 22,
        'carbonSavedKg': 0.269,
        'caloriesBurned': 57.7,
        'transportMode': 'walking',
      });

      expect(entry.displayName, 'Chew Jetty');
      expect(entry.pointsAwarded, 22);
      expect(entry.distanceKm, closeTo(1.282, 1e-9));
      expect(entry.transportMode, TransportMode.walking);
      expect(entry.isIncomplete, isFalse);
    });

    test('survives a record written before names and points were stored', () {
      // Exactly the shape of the check-ins already in Firestore: no
      // destinationName, no pointsAwarded.
      final entry = JournalEntryModel.fromMap('doc-2', {
        'checkInId': 'doc-2',
        'destinationId': 'ChIJ-cCMa5LDSjARF1sg9FiPauc',
        'checkInTime': DateTime(2026, 8, 20, 23, 24),
        'distanceKm': 1.165,
        'carbonSavedKg': 0.24465,
        'caloriesBurned': 52.425,
        'transportMode': 'walking',
      });

      expect(entry.isIncomplete, isTrue);
      // Never blank, and never the raw Places id.
      expect(entry.displayName, 'Unknown place');
      expect(entry.displayName, isNot(contains('ChIJ')));
      expect(entry.pointsAwarded, 0);
      // The figures that *were* recorded still come through — the row is
      // incomplete, not discarded.
      expect(entry.distanceKm, closeTo(1.165, 1e-9));
      expect(entry.carbonSavedKg, closeTo(0.24465, 1e-9));
    });

    test('an unknown transport mode reads as walking, not as a crash', () {
      final entry = JournalEntryModel.fromMap('doc-3', {
        'checkInTime': DateTime(2026, 8, 21),
        'transportMode': 'teleport',
      });

      expect(entry.transportMode, TransportMode.walking);
    });
  });

  group('relativeDate', () {
    final now = DateTime(2026, 8, 21, 12, 00);

    JournalEntryModel at(DateTime when) => JournalEntryModel(
          checkInId: 'x',
          destinationName: 'Chew Jetty',
          destinationId: 'x',
          checkInTime: when,
          distanceKm: 1,
          pointsAwarded: 20,
          carbonSavedKg: 0.21,
          caloriesBurned: 60,
        );

    test('reads by day boundary, not by elapsed hours', () {
      // 23:50 last night is "Yesterday" even though it is under 13 hours ago.
      expect(at(DateTime(2026, 8, 20, 23, 50)).relativeDate(now), 'Yesterday');
      expect(at(DateTime(2026, 8, 21, 0, 5)).relativeDate(now), 'Today');
      expect(at(DateTime(2026, 8, 18)).relativeDate(now), '3 days ago');
      expect(at(DateTime(2026, 8, 1)).relativeDate(now), '1/8/2026');
    });
  });

  group('JournalController', () {
    test('loads entries newest first', () async {
      final controller = JournalController(
        userId: DemoRewardData.userId,
        journalDao: DemoRewardData.journalDao(),
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.isLoading, isFalse);
      expect(controller.error, isNull);
      expect(controller.entries, hasLength(7));
      expect(controller.entries.first.destinationName, 'Kek Lok Si Temple');
      expect(controller.entries.last.destinationName, 'Fort Cornwallis');
    });

    test('surfaces a failure instead of reporting an empty journal', () async {
      final controller = JournalController(
        userId: 'tourist_001',
        journalDao: _FailingJournalDao(),
      );
      addTearDown(controller.dispose);

      await controller.load();

      // isEmpty must stay false — telling a tourist they have walked nowhere
      // because a query failed is a lie the screen cannot walk back.
      expect(controller.error, isNotNull);
      expect(controller.isEmpty, isFalse);
      expect(controller.entries, isEmpty);
    });

    test('a signed-out tourist reads nothing rather than everything', () async {
      final firestore = FakeFirebaseFirestore();
      // A check-in belonging to somebody else, to prove the empty result is a
      // short-circuit and not just an empty collection.
      await firestore.collection(RewardConstants.checkInsCollection).add({
        'userId': 'someone_else',
        'checkInTime': Timestamp.fromDate(DateTime(2026, 8, 21)),
        'distanceKm': 2.0,
      });

      final controller = JournalController(
        userId: '',
        journalDao: FirestoreJournalDao(firestore: firestore),
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.entries, isEmpty);
      expect(controller.error, isNull);
    });
  });

  group('FirestoreJournalDao', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreJournalDao dao;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      dao = FirestoreJournalDao(firestore: firestore);
    });

    Future<void> addCheckIn(
      String id,
      String userId,
      DateTime at, {
      String? name,
    }) {
      return firestore
          .collection(RewardConstants.checkInsCollection)
          .doc(id)
          .set({
        'checkInId': id,
        'userId': userId,
        'destinationId': 'place-$id',
        if (name != null) 'destinationName': name,
        'checkInTime': Timestamp.fromDate(at),
        'distanceKm': 1.5,
        'pointsAwarded': 25,
        'carbonSavedKg': 0.315,
        'caloriesBurned': 90.0,
        'transportMode': 'walking',
      });
    }

    test('returns only this tourist, newest first', () async {
      await addCheckIn('a', 'me', DateTime(2026, 8, 10), name: 'Penang Hill');
      await addCheckIn('b', 'me', DateTime(2026, 8, 20), name: 'Chew Jetty');
      await addCheckIn('c', 'someone_else', DateTime(2026, 8, 21), name: 'Nope');

      final entries = await dao.fetchEntries('me');

      expect(entries.map((e) => e.destinationName),
          ['Chew Jetty', 'Penang Hill']);
    });

    test('converts the Firestore Timestamp at the DAO edge', () async {
      final when = DateTime(2026, 8, 20, 23, 24);
      await addCheckIn('a', 'me', when, name: 'Chew Jetty');

      final entry = (await dao.fetchEntries('me')).single;

      // A Timestamp reaching the model would blow up its `as DateTime?` cast,
      // so this is the guard on that conversion staying put.
      expect(entry.checkInTime, when);
    });

    test('a tourist with no journeys gets an empty list, not an error',
        () async {
      await addCheckIn('a', 'someone_else', DateTime(2026, 8, 21));

      expect(await dao.fetchEntries('me'), isEmpty);
    });
  });

  group('JournalController filter (UC520)', () {
    // Pinned, so the day boundary is a fact of the test rather than of the
    // moment it happens to run.
    final now = DateTime(2026, 9, 6, 14, 30);

    JournalEntryModel at(String name, DateTime when) => JournalEntryModel(
          checkInId: 'id-${when.microsecondsSinceEpoch}',
          destinationName: name,
          destinationId: 'place-$name',
          checkInTime: when,
          distanceKm: 1.2,
          pointsAwarded: 22,
          carbonSavedKg: 0.252,
          caloriesBurned: 72,
        );

    JournalController controllerFor(List<JournalEntryModel> entries) {
      final controller = JournalController(
        userId: 'tourist_001',
        journalDao: InMemoryJournalDao(entries: entries),
        now: () => now,
      );
      addTearDown(controller.dispose);
      return controller;
    }

    test('defaults to All', () async {
      final controller = controllerFor([at('Chew Jetty', now)]);
      await controller.load();

      expect(controller.filter, JournalFilter.all);
    });

    test('All shows every loaded journey', () async {
      final controller = JournalController(
        userId: DemoRewardData.userId,
        journalDao: DemoRewardData.journalDao(),
        now: () => now,
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.visibleEntries, hasLength(7));
      expect(controller.visibleEntries, controller.entries);
    });

    test('Today shows only journeys from the current local day', () async {
      final controller = controllerFor([
        at('Chew Jetty', DateTime(2026, 9, 6, 9, 15)),
        at('Penang Hill', DateTime(2026, 9, 5, 9, 15)),
        at('Fort Cornwallis', DateTime(2026, 8, 28, 9, 15)),
      ]);
      await controller.load();

      controller.setFilter(JournalFilter.today);

      expect(
        controller.visibleEntries.map((e) => e.destinationName),
        ['Chew Jetty'],
      );
      // The full journal is untouched — the filter is a view over it, not a
      // reload of it.
      expect(controller.entries, hasLength(3));
    });

    test('reads by calendar day, not by the last 24 hours', () async {
      final controller = controllerFor([
        at('Just after midnight', DateTime(2026, 9, 6, 0, 5)),
        at('Late last night', DateTime(2026, 9, 5, 23, 50)),
      ]);
      await controller.load();

      controller.setFilter(JournalFilter.today);

      // 23:50 last night is under 15 hours old and still excluded, while
      // 00:05 this morning is included. A rolling 24-hour window would get
      // both of these the wrong way round.
      expect(
        controller.visibleEntries.map((e) => e.destinationName),
        ['Just after midnight'],
      );
    });

    test('filtering keeps the newest-first order', () async {
      final controller = controllerFor([
        at('Morning walk', DateTime(2026, 9, 6, 8, 00)),
        at('Yesterday', DateTime(2026, 9, 5, 12, 00)),
        at('Evening walk', DateTime(2026, 9, 6, 19, 00)),
        at('Midday walk', DateTime(2026, 9, 6, 12, 00)),
      ]);
      await controller.load();

      controller.setFilter(JournalFilter.today);

      expect(
        controller.visibleEntries.map((e) => e.destinationName),
        ['Evening walk', 'Midday walk', 'Morning walk'],
      );
    });

    test('setFilter notifies, and only on a real change', () async {
      final controller = controllerFor([at('Chew Jetty', now)]);
      await controller.load();

      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.setFilter(JournalFilter.today);
      expect(notifications, 1);

      // Tapping the pill that is already selected rebuilds nothing.
      controller.setFilter(JournalFilter.today);
      expect(notifications, 1);

      controller.setFilter(JournalFilter.all);
      expect(notifications, 2);
    });

    test('nothing today does not make the journal empty', () async {
      final controller = controllerFor([
        at('Penang Hill', DateTime(2026, 9, 5, 9, 15)),
      ]);
      await controller.load();

      controller.setFilter(JournalFilter.today);

      expect(controller.visibleEntries, isEmpty);
      // isEmpty describes the journal, not the slice. Conflating them would
      // tell a tourist with a week of walking that they have walked nothing.
      expect(controller.isEmpty, isFalse);
      expect(controller.entries, hasLength(1));
    });
  });

  group('WalkingJournalScreen filter pills', () {
    // The real clock here, so the screen's controller and the tiles' own
    // relativeDate agree on which day it is. The exact day boundary is pinned
    // by the controller tests above.
    final today = DateTime.now();
    final older = today.subtract(const Duration(days: 4));

    JournalEntryModel at(String name, DateTime when) => JournalEntryModel(
          checkInId: 'id-$name',
          destinationName: name,
          destinationId: 'place-$name',
          checkInTime: when,
          distanceKm: 1.2,
          pointsAwarded: 22,
          carbonSavedKg: 0.252,
          caloriesBurned: 72,
        );

    Future<void> pumpJournal(
      WidgetTester tester,
      List<JournalEntryModel> entries,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WalkingJournalScreen(
            controller: JournalController(
              userId: 'tourist_001',
              journalDao: InMemoryJournalDao(entries: entries),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('tapping Today narrows the list to today', (tester) async {
      await pumpJournal(tester, [
        at('Chew Jetty', today),
        at('Fort Cornwallis', older),
      ]);

      expect(find.text('Chew Jetty'), findsOneWidget);
      expect(find.text('Fort Cornwallis'), findsOneWidget);

      await tester.tap(find.byKey(const Key('journalFilter_today')));
      await tester.pumpAndSettle();

      expect(find.text('Chew Jetty'), findsOneWidget);
      expect(find.text('Fort Cornwallis'), findsNothing);
    });

    testWidgets('a day with no journeys says so, and offers the way back',
        (tester) async {
      await pumpJournal(tester, [at('Fort Cornwallis', older)]);

      await tester.tap(find.byKey(const Key('journalFilter_today')));
      await tester.pumpAndSettle();

      // Not "No journeys yet" — this tourist does have a journal.
      expect(find.text('No journeys today'), findsOneWidget);
      expect(find.text('No journeys yet'), findsNothing);
      expect(find.text('Fort Cornwallis'), findsNothing);

      // WpPrimaryButton uppercases its label, the same way the retry action
      // on the error state renders as "RETRY".
      await tester.tap(find.text('SHOW ALL JOURNEYS'));
      await tester.pumpAndSettle();

      expect(find.text('No journeys today'), findsNothing);
      expect(find.text('Fort Cornwallis'), findsOneWidget);
    });

    testWidgets('a tourist with nothing at all gets no filter to press',
        (tester) async {
      await pumpJournal(tester, const <JournalEntryModel>[]);

      expect(find.text('No journeys yet'), findsOneWidget);
      expect(find.byKey(const Key('journalFilter_today')), findsNothing);
    });
  });

  group('demo journal reconciles with the demo dashboard', () {
    // in_memory_reward_data promises its numbers survive a tutor checking them
    // against the award rule. These pin that promise for the journal, so the
    // seven journeys cannot drift away from the totals shown on the dashboard.
    test('sums to DemoRewardData.stats', () {
      final entries = DemoRewardData.entries;
      final stats = DemoRewardData.stats;

      expect(entries, hasLength(stats.totalCheckIns));

      final metres = entries
          .map((e) => RewardConstants.metresFromKm(e.distanceKm))
          .reduce((a, b) => a + b);
      expect(metres, stats.totalDistanceMetres);

      final points =
          entries.map((e) => e.pointsAwarded).reduce((a, b) => a + b);
      expect(points, stats.totalPoints);

      final carbon =
          entries.map((e) => e.carbonSavedKg).reduce((a, b) => a + b);
      expect(carbon, closeTo(stats.totalCarbonSavedKg, 0.01));

      final calories =
          entries.map((e) => e.caloriesBurned).reduce((a, b) => a + b);
      expect(calories, closeTo(stats.totalCaloriesBurned, 0.01));
    });

    test('each award matches the real points formula', () {
      for (final entry in DemoRewardData.entries) {
        expect(
          entry.pointsAwarded,
          RewardPoints.forCheckIn(
            distanceMetres: RewardConstants.metresFromKm(entry.distanceKm),
            transportMode: entry.transportMode,
          ),
          reason: entry.destinationName,
        );
      }
    });
  });
}
