// ---------------------------------------------------------------------------
// reward_dao_test.dart
// Module 5 — Reward & Achievement
// Use Case : UC500 Earn points from activities
// FR       : FR-R01 Points Award System
// Task     : T-R01.5 Unit tests for repeated check-in cases
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// Runs against an in-memory Firestore, so no live Firebase project is needed.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:test/test.dart';
import 'package:walkpenang/dao/reward_dao.dart';
import 'package:walkpenang/models/check_in_result.dart';
import 'package:walkpenang/utils/reward_constants.dart';

CheckInResult checkIn({
  String checkInId = 'chk_001',
  String userId = 'tourist_001',
  double distanceKm = 1.3,
}) {
  return CheckInResult(
    checkInId: checkInId,
    userId: userId,
    destinationId: 'kek_lok_si',
    distanceKm: distanceKm,
    carbonSavedKg: 0.26,
    caloriesBurned: 78.0,
    checkInTime: DateTime(2026, 8, 6, 9, 30),
  );
}

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreRewardDao dao;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    dao = FirestoreRewardDao(firestore: firestore);
  });

  Future<Map<String, dynamic>> userDoc(String userId) async {
    final snapshot = await firestore
        .collection(RewardConstants.usersCollection)
        .doc(userId)
        .get();
    return snapshot.data() ?? <String, dynamic>{};
  }

  group('Awarding for a check-in', () {
    test('creates the cumulative fields on the first check-in', () async {
      final awarded =
          await dao.awardForCheckIn(result: checkIn(), points: 23);

      expect(awarded, isTrue);
      final data = await userDoc('tourist_001');
      expect(data[RewardConstants.totalPointsField], 23);
      expect(data[RewardConstants.totalCheckInsField], 1);
      expect(data[RewardConstants.totalDistanceMetresField], 1300);
      expect(data[RewardConstants.totalCarbonSavedKgField], closeTo(0.26, 1e-9));
      expect(data[RewardConstants.totalCaloriesBurnedField], closeTo(78.0, 1e-9));
    });

    test('adds to existing totals rather than replacing them', () async {
      await dao.awardForCheckIn(
        result: checkIn(checkInId: 'chk_001', distanceKm: 1.3),
        points: 23,
      );
      await dao.awardForCheckIn(
        result: checkIn(checkInId: 'chk_002', distanceKm: 2.9),
        points: 39,
      );

      final data = await userDoc('tourist_001');
      expect(data[RewardConstants.totalPointsField], 62);
      expect(data[RewardConstants.totalCheckInsField], 2);
      expect(data[RewardConstants.totalDistanceMetresField], 4200);
    });

    test('leaves the profile fields written by Module 1 untouched', () async {
      await firestore
          .collection(RewardConstants.usersCollection)
          .doc('tourist_001')
          .set({'nickname': 'Ali', 'weightKg': 62.0});

      await dao.awardForCheckIn(result: checkIn(), points: 23);

      final data = await userDoc('tourist_001');
      expect(data['nickname'], 'Ali');
      expect(data['weightKg'], 62.0);
      expect(data[RewardConstants.totalPointsField], 23);
    });

    test('writes one ledger entry keyed by the check-in ID', () async {
      await dao.awardForCheckIn(result: checkIn(), points: 23);

      final ledger = await firestore
          .collection(RewardConstants.pointsLedgerCollection)
          .get();
      expect(ledger.docs, hasLength(1));
      expect(ledger.docs.single.id, 'chk_001');
      expect(
        ledger.docs.single.data()[RewardConstants.ledgerPointsAwardedField],
        23,
      );
    });

    test('stamps the check-in document as processed', () async {
      await dao.awardForCheckIn(result: checkIn(), points: 23);

      final snapshot = await firestore
          .collection(RewardConstants.checkInsCollection)
          .doc('chk_001')
          .get();
      expect(
        snapshot.data()?[RewardConstants.checkInRewardProcessedField],
        isTrue,
      );
    });
  });

  group('Repeated check-in cases (T-R01.5)', () {
    test('the same check-in submitted twice awards points only once',
        () async {
      final first =
          await dao.awardForCheckIn(result: checkIn(), points: 23);
      final second =
          await dao.awardForCheckIn(result: checkIn(), points: 23);

      expect(first, isTrue);
      expect(second, isFalse, reason: 'the retry must not award again');

      final data = await userDoc('tourist_001');
      expect(data[RewardConstants.totalPointsField], 23);
      expect(data[RewardConstants.totalCheckInsField], 1);
      expect(data[RewardConstants.totalDistanceMetresField], 1300);
    });

    test('a retry appends no second ledger entry', () async {
      await dao.awardForCheckIn(result: checkIn(), points: 23);
      await dao.awardForCheckIn(result: checkIn(), points: 23);

      final ledger = await firestore
          .collection(RewardConstants.pointsLedgerCollection)
          .get();
      expect(ledger.docs, hasLength(1));
    });

    test('the rewardProcessed flag alone blocks a re-award', () async {
      // The ledger entry is gone but Module 4's check-in document still says
      // the check-in was rewarded, so the second guard has to hold.
      await firestore
          .collection(RewardConstants.checkInsCollection)
          .doc('chk_001')
          .set({RewardConstants.checkInRewardProcessedField: true});

      final awarded =
          await dao.awardForCheckIn(result: checkIn(), points: 23);

      expect(awarded, isFalse);
      expect(await userDoc('tourist_001'), isEmpty);
    });

    test('a different check-in for the same tourist is still awarded',
        () async {
      await dao.awardForCheckIn(result: checkIn(checkInId: 'chk_001'), points: 23);
      final awarded = await dao.awardForCheckIn(
        result: checkIn(checkInId: 'chk_002'),
        points: 23,
      );

      expect(awarded, isTrue);
      final data = await userDoc('tourist_001');
      expect(data[RewardConstants.totalCheckInsField], 2);
    });
  });

  group('isCheckInRewarded', () {
    test('is false for a check-in that has never been rewarded', () async {
      expect(await dao.isCheckInRewarded('chk_999'), isFalse);
    });

    test('is true once the check-in has been awarded', () async {
      await dao.awardForCheckIn(result: checkIn(), points: 23);
      expect(await dao.isCheckInRewarded('chk_001'), isTrue);
    });
  });

  group('fetchRewardSummary', () {
    test('a tourist who has never checked in reads as the empty state',
        () async {
      final stats = await dao.fetchRewardSummary('tourist_404');
      expect(stats.totalPoints, 0);
      expect(stats.totalCheckIns, 0);
      expect(stats.hasCheckIns, isFalse);
    });

    test('reads back the totals written by an award', () async {
      await dao.awardForCheckIn(result: checkIn(), points: 23);

      final stats = await dao.fetchRewardSummary('tourist_001');
      expect(stats.totalPoints, 23);
      expect(stats.totalCheckIns, 1);
      expect(stats.totalDistanceMetres, 1300);
      expect(stats.totalDistanceKm, 1.3);
    });
  });
}
