// ---------------------------------------------------------------------------
// leaderboard_test.dart
// Module 5 — Reward & Achievement
// Use Case : UC540 Compare standing against other tourists
// FR       : FR-R06 Leaderboard
// Task     : T-R06.1 Ranking, tie and standing rules
// Owner    : Tang Khuan Zhi (2414351)
// ---------------------------------------------------------------------------
//
// Three layers, all without a live Firebase project: the ranking rules are
// pure Dart, the DAO runs against an in-memory Firestore, and the controller
// runs against the in-memory doubles.
//
// flutter_test rather than the plain test package, because
// LeaderboardController extends ChangeNotifier to drive the screen.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkpenang/controllers/leaderboard_controller.dart';
import 'package:walkpenang/dao/in_memory_reward_data.dart';
import 'package:walkpenang/dao/leaderboard_dao.dart';
import 'package:walkpenang/dao/reward_dao.dart';
import 'package:walkpenang/models/check_in_result.dart';
import 'package:walkpenang/models/leaderboard_entry_model.dart';
import 'package:walkpenang/models/reward_model.dart';
import 'package:walkpenang/utils/reward_constants.dart';

LeaderboardEntryModel entry({
  required String userId,
  String? name,
  required int points,
  int checkIns = 5,
  int metres = 5000,
}) {
  return LeaderboardEntryModel(
    userId: userId,
    displayName: name ?? userId,
    totalPoints: points,
    totalCheckIns: checkIns,
    totalDistanceMetres: metres,
  );
}

void main() {
  group('Ranking (LeaderboardRanking)', () {
    test('orders highest points first', () {
      final ranked = LeaderboardRanking.rank([
        entry(userId: 'b', points: 120),
        entry(userId: 'a', points: 380),
        entry(userId: 'c', points: 45),
      ]);

      expect(ranked.map((r) => r.entry.userId), ['a', 'b', 'c']);
      expect(ranked.map((r) => r.rank), [1, 2, 3]);
      expect(ranked.first.isLeader, isTrue);
      expect(ranked.first.entry.totalPoints, 380);
    });

    test('ties share a rank and the next position skips', () {
      // Standard competition ranking: two tourists on 150 both hold 2nd, and
      // the tourist below them is 4th — not 3rd. Splitting the tie would have
      // the board claim one of them out-walked the other on identical points.
      final ranked = LeaderboardRanking.rank([
        entry(userId: 'top', points: 400),
        entry(userId: 'tied_one', points: 150, metres: 9000),
        entry(userId: 'tied_two', points: 150, metres: 9000),
        entry(userId: 'last', points: 90),
      ]);

      expect(ranked.map((r) => r.rank), [1, 2, 2, 4]);
    });

    test('a tie is ordered by distance, then name, then user id', () {
      final ranked = LeaderboardRanking.rank([
        entry(userId: 'z_short', name: 'Aisha', points: 150, metres: 4000),
        entry(userId: 'a_long', name: 'Zara', points: 150, metres: 9000),
      ]);

      // Both hold 1st — the tie is on points. Distance only decides which of
      // the two is drawn first.
      expect(ranked.map((r) => r.rank), [1, 1]);
      expect(ranked.first.entry.displayName, 'Zara');

      final byName = LeaderboardRanking.rank([
        entry(userId: 'u2', name: 'Zara', points: 150, metres: 9000),
        entry(userId: 'u1', name: 'Aisha', points: 150, metres: 9000),
      ]);
      expect(byName.first.entry.displayName, 'Aisha');
    });

    test('an empty board ranks to an empty list rather than throwing', () {
      expect(LeaderboardRanking.rank(const []), isEmpty);
    });

    test('only the top three are podium places', () {
      final ranked = LeaderboardRanking.rank([
        for (var i = 0; i < 5; i++) entry(userId: 'u$i', points: 500 - i * 10),
      ]);

      expect(ranked.where((r) => r.isPodium).length, 3);
    });
  });

  group('LeaderboardEntryModel', () {
    test('a blank name reads as the default walker, not an empty row', () {
      final parsed = LeaderboardEntryModel.fromMap('u1', {
        LeaderboardFields.displayName: '   ',
        LeaderboardFields.totalPoints: 40,
      });

      expect(parsed.displayName, kDefaultWalkerName);
      expect(parsed.initials, 'W');
    });

    test('a document with no reward fields reads as zeroes', () {
      // A row written by an older build must render, not crash the board.
      final parsed = LeaderboardEntryModel.fromMap('u1', const {});

      expect(parsed.totalPoints, 0);
      expect(parsed.totalCheckIns, 0);
      expect(parsed.totalDistanceMetres, 0);
      expect(parsed.hasPoints, isFalse);
    });

    test('initials take the first letter of the first two words', () {
      expect(entry(userId: 'u', name: 'Khuan Zhi', points: 1).initials, 'KZ');
      expect(entry(userId: 'u', name: 'Mei', points: 1).initials, 'M');
      expect(
        entry(userId: 'u', name: 'Tang Khuan Zhi', points: 1).initials,
        'TK',
      );
    });

    test('an empty photo url normalises to null', () {
      // So every widget downstream tests for null alone rather than for both.
      final parsed = LeaderboardEntryModel.fromMap('u1', {
        LeaderboardFields.photoUrl: '',
      });

      expect(parsed.photoUrl, isNull);
    });
  });

  group('FirestoreLeaderboardDao', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreLeaderboardDao dao;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      dao = FirestoreLeaderboardDao(firestore: firestore);
    });

    Future<void> seedTourist(
      String userId, {
      String nickname = 'Mei Ling',
      String? photoUrl,
    }) async {
      await firestore
          .collection(RewardConstants.usersCollection)
          .doc(userId)
          .set({
        RewardConstants.profileNicknameField: nickname,
        if (photoUrl != null) RewardConstants.profilePhotoUrlField: photoUrl,
      });
    }

    RewardModel stats({int points = 194, int metres = 12400}) => RewardModel(
          userId: 'tourist_001',
          totalPoints: points,
          totalCheckIns: 7,
          totalDistanceMetres: metres,
        );

    test('publishing mirrors the totals and the profile name', () async {
      await seedTourist('tourist_001', photoUrl: 'https://example/a.jpg');

      await dao.publishEntry(userId: 'tourist_001', stats: stats());

      final published = await dao.fetchEntry('tourist_001');
      expect(published, isNotNull);
      expect(published!.displayName, 'Mei Ling');
      expect(published.photoUrl, 'https://example/a.jpg');
      expect(published.totalPoints, 194);
      expect(published.totalCheckIns, 7);
      expect(published.totalDistanceMetres, 12400);
    });

    test('publishing twice updates the row rather than adding one', () async {
      await seedTourist('tourist_001');

      await dao.publishEntry(userId: 'tourist_001', stats: stats(points: 194));
      await dao.publishEntry(userId: 'tourist_001', stats: stats(points: 240));

      final board = await dao.fetchTopEntries();
      expect(board, hasLength(1));
      expect(board.single.totalPoints, 240);
    });

    test('a tourist with no points is not published', () async {
      // Being on the board is something a check-in earns. Publishing zeroes
      // would enrol somebody who has not walked into a public list of names.
      await seedTourist('tourist_001');

      await dao.publishEntry(
        userId: 'tourist_001',
        stats: const RewardModel.empty('tourist_001'),
      );

      expect(await dao.fetchTopEntries(), isEmpty);
      expect(await dao.fetchEntry('tourist_001'), isNull);
    });

    test('a tourist with no nickname publishes as the default walker',
        () async {
      await firestore
          .collection(RewardConstants.usersCollection)
          .doc('tourist_001')
          .set({'email': 'nobody@example.com'});

      await dao.publishEntry(userId: 'tourist_001', stats: stats());

      expect((await dao.fetchEntry('tourist_001'))!.displayName,
          kDefaultWalkerName);
    });

    test('reads back highest first, capped at the limit', () async {
      for (final row in [
        ('u1', 120),
        ('u2', 380),
        ('u3', 45),
        ('u4', 260),
      ]) {
        await seedTourist(row.$1, nickname: row.$1);
        await dao.publishEntry(
          userId: row.$1,
          stats: RewardModel(userId: row.$1, totalPoints: row.$2),
        );
      }

      final top = await dao.fetchTopEntries(limit: 3);
      expect(top.map((e) => e.totalPoints), [380, 260, 120]);
    });

    test('a tourist who has never published has no row', () async {
      expect(await dao.fetchEntry('nobody'), isNull);
    });

    test('an empty user id neither publishes nor reads', () async {
      await dao.publishEntry(userId: '', stats: stats());

      expect(await dao.fetchEntry(''), isNull);
      expect(await dao.fetchTopEntries(), isEmpty);
    });
  });

  group('LeaderboardController', () {
    LeaderboardController controllerFor(
      String userId, {
      List<LeaderboardEntryModel>? board,
      int limit = RewardConstants.leaderboardPageSize,
    }) {
      return LeaderboardController(
        userId: userId,
        leaderboardDao: InMemoryLeaderboardDao(
          entries: board ?? DemoRewardData.standings,
        ),
        limit: limit,
      );
    }

    test('loads the demo board with the leader first', () async {
      final controller = controllerFor(DemoRewardData.userId);
      await controller.load();

      expect(controller.isLoading, isFalse);
      expect(controller.error, isNull);
      expect(controller.leader!.entry.displayName, 'Mei Ling');
      expect(controller.leader!.entry.totalPoints, 512);
      expect(controller.podium, hasLength(3));
    });

    test('finds the signed-in tourist and the gap to the rank above',
        () async {
      final controller = controllerFor(DemoRewardData.userId);
      await controller.load();

      // The demo tourist sits 4th on 194 points, 11 behind Siti on 205.
      expect(controller.currentUserEntry!.rank, 4);
      expect(controller.pointsToNextRank, 11);
      expect(controller.isCurrentUserOffBoard, isFalse);
    });

    test('the leader is quoted no gap to close', () async {
      final controller = controllerFor('demo_mei_ling');
      await controller.load();

      expect(controller.currentUserEntry!.isLeader, isTrue);
      expect(controller.pointsToNextRank, isNull);
    });

    test('the gap skips past anyone level with the tourist', () async {
      // Two tourists tied on 150 both hold 2nd. The lower of them is not
      // "0 points behind" the other — the gap that means anything is to the
      // next tourist actually ahead.
      final controller = controllerFor('demo_priya');
      await controller.load();

      expect(controller.currentUserEntry!.rank, 5);
      expect(controller.pointsToNextRank, 194 - 150);
    });

    test('a tourist below the fetched page still gets their own standing',
        () async {
      final controller = controllerFor('demo_wong', limit: 3);
      await controller.load();

      expect(controller.entries, hasLength(3));
      expect(controller.isCurrentUserOffBoard, isTrue);
      expect(controller.currentUserEntry!.entry.displayName, 'Wong Jia Hui');
      // Ranked one past the page rather than given a position the client
      // cannot know without counting everyone ahead.
      expect(controller.currentUserEntry!.rank, 4);
      // And no gap is quoted, because the tourist above them was never read.
      expect(controller.pointsToNextRank, isNull);
    });

    test('a tourist with no row has no standing', () async {
      final controller = controllerFor('never_walked');
      await controller.load();

      expect(controller.currentUserEntry, isNull);
      expect(controller.isCurrentUserOffBoard, isFalse);
      expect(controller.entries, isNotEmpty);
    });

    test('an empty board is empty, not an error', () async {
      final controller = controllerFor('tourist_001', board: const []);
      await controller.load();

      expect(controller.isEmpty, isTrue);
      expect(controller.error, isNull);
      expect(controller.leader, isNull);
      expect(controller.podium, isEmpty);
    });

    test('a failed read surfaces rather than showing an empty board',
        () async {
      // An empty board here would tell the tourist that nobody has walked
      // anywhere, which is a lie the screen cannot walk back.
      final controller = LeaderboardController(
        userId: 'tourist_001',
        leaderboardDao: _FailingLeaderboardDao(),
      );
      await controller.load();

      expect(controller.error, isNotNull);
      expect(controller.isEmpty, isFalse);
      expect(controller.entries, isEmpty);
    });

    test('opening the board publishes the tourist onto it', () async {
      // A tourist who earned points before this screen existed has no row.
      // Opening the leaderboard enrols them, so no backfill script is needed.
      final rewardDao = InMemoryRewardDao(
        initial: const RewardModel(
          userId: 'tourist_001',
          totalPoints: 88,
          totalCheckIns: 4,
          totalDistanceMetres: 4800,
        ),
      );
      final leaderboardDao = InMemoryLeaderboardDao(
        entries: [entry(userId: 'someone_else', points: 300)],
      );

      final controller = LeaderboardController(
        userId: 'tourist_001',
        leaderboardDao: leaderboardDao,
        rewardDao: rewardDao,
      );
      await controller.load();

      expect(controller.currentUserEntry, isNotNull);
      expect(controller.currentUserEntry!.entry.totalPoints, 88);
      expect(controller.currentUserEntry!.rank, 2);
    });

    test('a publish failure still renders the board', () async {
      // Publishing is a courtesy write on derived data; it must not be able
      // to take the whole screen down with it.
      final controller = LeaderboardController(
        userId: 'tourist_001',
        leaderboardDao: InMemoryLeaderboardDao(
          entries: DemoRewardData.standings,
        ),
        rewardDao: _FailingRewardDao(),
      );
      await controller.load();

      expect(controller.error, isNull);
      expect(controller.entries, isNotEmpty);
    });
  });
}

/// Fails every read, to prove the screen shows a retry rather than an empty
/// board when Firestore denies the query.
class _FailingLeaderboardDao implements LeaderboardDao {
  @override
  Future<List<LeaderboardEntryModel>> fetchTopEntries({int limit = 50}) =>
      Future.error(StateError('permission-denied'));

  @override
  Future<LeaderboardEntryModel?> fetchEntry(String userId) =>
      Future.error(StateError('permission-denied'));

  @override
  Future<void> publishEntry({
    required String userId,
    required RewardModel stats,
  }) async {}
}

/// Fails the totals read that publishing depends on.
class _FailingRewardDao implements RewardDao {
  @override
  Future<RewardModel> fetchRewardSummary(String userId) =>
      Future.error(StateError('offline'));

  @override
  Future<bool> isCheckInRewarded(String checkInId) async => false;

  @override
  Future<bool> awardForCheckIn({
    required CheckInResult result,
    required int points,
  }) =>
      throw UnimplementedError();
}
