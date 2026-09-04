// ---------------------------------------------------------------------------
// profile_store_test.dart
// Module 1 — User Authentication & Profile (regression found from Module 5)
// Use Case : UC540 Leaderboard / UC520 Statistics dashboard
// FR       : FR-R06 Leaderboard, FR-R05 Statistics dashboard
// ---------------------------------------------------------------------------
//
// users/{uid} is shared: Module 1 writes the profile fields into it and the
// reward module merges the tourist's cumulative totals into the same document.
// ProfileStore.save() used a bare set(), a full replace, so editing a nickname
// deleted every total the tourist had earned -- zeroing the statistics
// dashboard and their leaderboard row.
//
// Runs against an in-memory Firestore, so no live Firebase project is needed.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkpenang/models/user_profile.dart';
import 'package:walkpenang/services/profile_store.dart';
import 'package:walkpenang/utils/reward_constants.dart';

UserProfile profile({String nickname = 'Yue Hann'}) {
  return UserProfile(
    nickname: nickname,
    weightKg: 62.0,
    heightCm: 170.0,
    units: 'metric',
    email: 'tourist@example.com',
  );
}

void main() {
  late FakeFirebaseFirestore firestore;
  late ProfileStore store;

  const uid = 'tourist_001';

  /// A tourist who has already walked: the reward module has merged their
  /// totals into users/{uid} alongside the profile Module 1 wrote there.
  Future<void> seedEarnedTotals() {
    return firestore.collection('users').doc(uid).set({
      'nickname': 'Old Name',
      'weightKg': 62.0,
      'heightCm': 170.0,
      'units': 'metric',
      RewardConstants.totalPointsField: 340,
      RewardConstants.totalCheckInsField: 7,
      RewardConstants.totalDistanceMetresField: 17000.0,
      RewardConstants.totalCarbonSavedKgField: 3.4,
      RewardConstants.totalCaloriesBurnedField: 1020.0,
    });
  }

  Future<Map<String, dynamic>> readUser() async {
    final doc = await firestore.collection('users').doc(uid).get();
    return doc.data()!;
  }

  setUp(() {
    firestore = FakeFirebaseFirestore();
    store = ProfileStore(firestore: firestore);
  });

  group('saveToCloud', () {
    test('keeps the reward totals a profile edit does not carry', () async {
      await seedEarnedTotals();

      await store.saveToCloud(uid, profile(nickname: 'Yue Hann'));

      final user = await readUser();
      expect(user['nickname'], 'Yue Hann', reason: 'the edit must still land');
      expect(user[RewardConstants.totalPointsField], 340);
      expect(user[RewardConstants.totalCheckInsField], 7);
      expect(user[RewardConstants.totalDistanceMetresField], 17000.0);
      expect(user[RewardConstants.totalCarbonSavedKgField], 3.4);
      expect(user[RewardConstants.totalCaloriesBurnedField], 1020.0);
    });

    test('writes every profile field on a tourist with no document yet',
        () async {
      await store.saveToCloud(uid, profile());

      final user = await readUser();
      expect(user['nickname'], 'Yue Hann');
      expect(user['weightKg'], 62.0);
      expect(user['heightCm'], 170.0);
      expect(user['units'], 'metric');
      expect(user['email'], 'tourist@example.com');
    });

    test('a second edit does not resurrect a total the reward module cleared',
        () async {
      await seedEarnedTotals();
      await store.saveToCloud(uid, profile(nickname: 'First'));

      // The reward module is the owner of these fields; a profile save must
      // report whatever it last wrote, not a value cached from an earlier save.
      await firestore.collection('users').doc(uid).update({
        RewardConstants.totalPointsField: 500,
      });
      await store.saveToCloud(uid, profile(nickname: 'Second'));

      final user = await readUser();
      expect(user['nickname'], 'Second');
      expect(user[RewardConstants.totalPointsField], 500);
    });
  });
}
