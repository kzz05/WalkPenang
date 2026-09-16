// Regression cover for the data a logout used to take with it.
//
// ProfileStore.clear() called prefs.clear(), which empties the whole
// SharedPreferences store rather than this store's own key. Logging out
// therefore also deleted the tourist's favourites and the "already routed"
// places behind the grey map pins, and both came back empty on the next login
// — the app reading as though it had forgotten every walk ever taken.
//
// The keys are asserted by their literal strings on purpose. Importing the
// stores would make this test agree with whatever they happen to say; the
// point is that clear() must not touch anything it does not own, including
// keys written by modules this one has never heard of.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walkpenang/services/profile_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // clear() never reaches Firestore, but the constructor resolves the live
  // instance when none is injected — which needs a Firebase app that a unit
  // test has no reason to start.
  ProfileStore store() => ProfileStore(firestore: FakeFirebaseFirestore());

  const profileKey = 'user_profile';
  const favouritesKey = 'walkpenang.favorites.v2';
  const routedKey = 'walkpenang.map.routed_place_ids.v1';

  test('logout forgets the profile and nothing else', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      profileKey: '{"nickname":"Tourist"}',
      favouritesKey: '[{"id":"chew-jetty","name":"Chew Jetty"}]',
      routedKey: <String>['kek-lok-si', 'fort-cornwallis'],
      'some.other.module.setting': true,
    });

    await store().clear();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(profileKey), isNull, reason: 'the cached profile is '
        'what logging out is for');
    expect(prefs.getString(favouritesKey), isNotNull);
    expect(prefs.getStringList(routedKey), <String>['kek-lok-si',
        'fort-cornwallis']);
    expect(prefs.getBool('some.other.module.setting'), isTrue);
  });

  test('clearing twice is harmless', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      profileKey: '{"nickname":"Tourist"}',
      favouritesKey: '[]',
    });

    await store().clear();
    await store().clear();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(profileKey), isNull);
    expect(prefs.getString(favouritesKey), isNotNull);
  });
}
