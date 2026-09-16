// ---------------------------------------------------------------------------
// leaderboard_backfill_parity_test.dart
// Module 5 — Reward & Achievement
// Use Case : UC540 View leaderboard
// ---------------------------------------------------------------------------
//
// tool/backfill_leaderboard/backfill_leaderboard.js writes leaderboard rows for
// tourists who earned points before anything mirrored them onto the board. It
// is a Node script using the Admin SDK — it has to be, because
// firestore.rules only allows a client to write its own row (`isOwner`) — so
// it cannot import the Dart constants and hardcodes the field names instead.
//
// That is the drift risk this file exists to catch: rename a field in Dart and
// the script keeps writing the old name, producing rows the app silently reads
// as zeroes. These tests assert the names the script hardcodes are still the
// names the app writes and reads.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkpenang/dao/leaderboard_dao.dart';
import 'package:walkpenang/models/leaderboard_entry_model.dart';
import 'package:walkpenang/models/reward_model.dart';
import 'package:walkpenang/utils/reward_constants.dart';

/// Copied verbatim from the constants at the top of
/// tool/backfill_leaderboard/backfill_leaderboard.js. If a test here fails,
/// fix the script — do not relax the expectation.
const Map<String, String> _scriptConstants = <String, String>{
  'USERS_COLLECTION': 'users',
  'LEADERBOARD_COLLECTION': 'leaderboard',
  'DISPLAY_NAME_FIELD': 'displayName',
  'NICKNAME_FIELD': 'nickname',
  'PHOTO_URL_FIELD': 'photoUrl',
  'TOTAL_POINTS_FIELD': 'totalPoints',
  'TOTAL_CHECK_INS_FIELD': 'totalCheckIns',
  'TOTAL_DISTANCE_METRES_FIELD': 'totalDistanceMetres',
  'UPDATED_AT_FIELD': 'updatedAt',
  'DEFAULT_WALKER_NAME': 'Walker',
};

void main() {
  group('the backfill script uses the names the app uses', () {
    test('collections', () {
      expect(_scriptConstants['USERS_COLLECTION'],
          RewardConstants.usersCollection);
      expect(_scriptConstants['LEADERBOARD_COLLECTION'],
          RewardConstants.leaderboardCollection);
    });

    test('fields it reads off users/{uid}', () {
      expect(_scriptConstants['NICKNAME_FIELD'],
          RewardConstants.profileNicknameField);
      expect(_scriptConstants['PHOTO_URL_FIELD'],
          RewardConstants.profilePhotoUrlField);
      expect(_scriptConstants['TOTAL_POINTS_FIELD'],
          RewardConstants.totalPointsField);
      expect(_scriptConstants['TOTAL_CHECK_INS_FIELD'],
          RewardConstants.totalCheckInsField);
      expect(_scriptConstants['TOTAL_DISTANCE_METRES_FIELD'],
          RewardConstants.totalDistanceMetresField);
    });

    test('fields it writes onto leaderboard/{uid}', () {
      expect(_scriptConstants['DISPLAY_NAME_FIELD'],
          LeaderboardFields.displayName);
      expect(_scriptConstants['PHOTO_URL_FIELD'], LeaderboardFields.photoUrl);
      expect(
          _scriptConstants['TOTAL_POINTS_FIELD'], LeaderboardFields.totalPoints);
      expect(_scriptConstants['TOTAL_CHECK_INS_FIELD'],
          LeaderboardFields.totalCheckIns);
      expect(_scriptConstants['TOTAL_DISTANCE_METRES_FIELD'],
          LeaderboardFields.totalDistanceMetres);
      expect(_scriptConstants['UPDATED_AT_FIELD'], LeaderboardFields.updatedAt);
    });

    test('the blank-nickname fallback', () {
      expect(_scriptConstants['DEFAULT_WALKER_NAME'], kDefaultWalkerName);
    });
  });

  group('a backfilled row matches one the app would publish', () {
    late FakeFirebaseFirestore firestore;

    setUp(() => firestore = FakeFirebaseFirestore());

    /// Writes the row exactly as the Node script does, from the same source
    /// document, so the two shapes can be compared field by field.
    Future<Map<String, dynamic>> backfillRowFor(String uid) async {
      final Map<String, dynamic> data =
          (await firestore.collection('users').doc(uid).get()).data() ??
              <String, dynamic>{};

      int readInt(String field) => (data[field] as num?)?.toInt() ?? 0;
      final String nickname =
          (data[RewardConstants.profileNicknameField] as String? ?? '').trim();
      final String photo =
          (data[RewardConstants.profilePhotoUrlField] as String? ?? '').trim();

      return <String, dynamic>{
        LeaderboardFields.displayName:
            nickname.isEmpty ? kDefaultWalkerName : nickname,
        LeaderboardFields.photoUrl: photo.isEmpty ? null : photo,
        LeaderboardFields.totalPoints:
            readInt(RewardConstants.totalPointsField),
        LeaderboardFields.totalCheckIns:
            readInt(RewardConstants.totalCheckInsField),
        LeaderboardFields.totalDistanceMetres:
            readInt(RewardConstants.totalDistanceMetresField),
      };
    }

    Future<Map<String, dynamic>> publishedRowFor(String uid) async {
      final RewardModel stats = RewardModel.fromMap(
        uid,
        (await firestore.collection('users').doc(uid).get()).data() ??
            <String, dynamic>{},
      );
      await FirestoreLeaderboardDao(firestore: firestore)
          .publishEntry(userId: uid, stats: stats);

      final Map<String, dynamic> written =
          (await firestore.collection('leaderboard').doc(uid).get()).data()!;
      // serverTimestamp is written by both and is not comparable.
      return Map<String, dynamic>.from(written)
        ..remove(LeaderboardFields.updatedAt);
    }

    test('for a tourist with a full profile', () async {
      await firestore.collection('users').doc('uid-a').set(<String, dynamic>{
        RewardConstants.profileNicknameField: 'Ong Song Wei',
        RewardConstants.profilePhotoUrlField: 'https://example.com/a.jpg',
        RewardConstants.totalPointsField: 66,
        RewardConstants.totalCheckInsField: 4,
        RewardConstants.totalDistanceMetresField: 5200,
      });

      expect(await backfillRowFor('uid-a'), await publishedRowFor('uid-a'));
    });

    test('for a tourist with no nickname and no photo', () async {
      await firestore.collection('users').doc('uid-b').set(<String, dynamic>{
        RewardConstants.profileNicknameField: '   ',
        RewardConstants.totalPointsField: 66,
      });

      final Map<String, dynamic> row = await backfillRowFor('uid-b');
      expect(row, await publishedRowFor('uid-b'));
      // The exact case the six stranded users are in: points, nothing else.
      expect(row[LeaderboardFields.displayName], kDefaultWalkerName);
      expect(row[LeaderboardFields.photoUrl], isNull);
      expect(row[LeaderboardFields.totalCheckIns], 0);
    });
  });
}
