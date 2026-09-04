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
import 'package:flutter_test/flutter_test.dart';

import 'package:walkpenang/controllers/journal_controller.dart';
import '../support/in_memory_reward_data.dart';
import 'package:walkpenang/dao/journal_dao.dart';
import 'package:walkpenang/models/journal_entry_model.dart';
import 'package:walkpenang/models/transport_mode.dart';
import 'package:walkpenang/utils/reward_constants.dart';

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
