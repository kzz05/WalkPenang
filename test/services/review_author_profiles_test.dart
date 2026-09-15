// ---------------------------------------------------------------------------
// review_author_profiles_test.dart
// Reviews — live author name and photo
// ---------------------------------------------------------------------------
//
// A review stores the name its author had when they wrote it. Rename yourself
// from "White Shark" to "White Big Shark" and every past review kept saying
// "White Shark", because the stored string was what got rendered.
//
// The fix reads `public_profiles/{uid}` at display time. These tests pin the
// two halves of that: the resolve returns CURRENT data, and the fallback still
// covers everyone it has to — Google reviewers, legacy reviews with no uid, and
// authors whose projection has not been written yet.
//
// Note on why the projection exists at all: users/{uid} is owner-only in
// firestore.rules and carries email, phone, weight and height, so it can never
// be the source for someone else's name.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkpenang/models/public_profile.dart';
import 'package:walkpenang/services/firestore_place_repository.dart';
import 'package:walkpenang/services/review_author.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestorePlaceRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = FirestorePlaceRepository(
      firestore: firestore,
      authorResolver: _StubAuthorResolver(
        const ReviewAuthor(uid: 'uid-a', displayName: 'ignored here'),
      ),
    );
  });

  Future<void> seedProfile(
    String uid, {
    required String displayName,
    String? photoUrl,
  }) {
    return firestore
        .collection('public_profiles')
        .doc(uid)
        .set(<String, dynamic>{
      'displayName': displayName,
      'photoUrl': photoUrl,
    });
  }

  group('resolving author profiles', () {
    test('returns the current name, not the one stored on the review',
        () async {
      // The tourist has since renamed themselves.
      await seedProfile('uid-a', displayName: 'White Big Shark');

      final Map<String, PublicProfile> resolved =
          await repository.fetchAuthorProfiles(<String>['uid-a']);

      expect(resolved['uid-a']!.displayName, 'White Big Shark');
    });

    test('returns the current photo', () async {
      await seedProfile(
        'uid-a',
        displayName: 'White Big Shark',
        photoUrl: 'https://example.com/new.jpg',
      );

      final Map<String, PublicProfile> resolved =
          await repository.fetchAuthorProfiles(<String>['uid-a']);

      expect(resolved['uid-a']!.photoUrl, 'https://example.com/new.jpg');
    });

    test('resolves several authors in one call', () async {
      await seedProfile('uid-a', displayName: 'White Big Shark');
      await seedProfile('uid-b', displayName: 'Tang Yue Hann');

      final Map<String, PublicProfile> resolved =
          await repository.fetchAuthorProfiles(<String>['uid-a', 'uid-b']);

      expect(resolved, hasLength(2));
      expect(resolved['uid-b']!.displayName, 'Tang Yue Hann');
    });

    test('an author with no projection is simply absent', () async {
      // Not an error and not a placeholder row — the caller falls back to the
      // name stored on the review, which is what it used to show anyway.
      final Map<String, PublicProfile> resolved =
          await repository.fetchAuthorProfiles(<String>['never-synced']);

      expect(resolved, isEmpty);
    });

    test('empty and blank ids are dropped before querying', () async {
      // Google-sourced reviews have userId == ''. Passing one through would
      // make Firestore reject the whole whereIn query and lose the real
      // authors along with it.
      final Map<String, PublicProfile> resolved =
          await repository.fetchAuthorProfiles(<String>['', '']);

      expect(resolved, isEmpty);
    });

    test('duplicate ids are queried once', () async {
      await seedProfile('uid-a', displayName: 'White Big Shark');

      final Map<String, PublicProfile> resolved = await repository
          .fetchAuthorProfiles(<String>['uid-a', 'uid-a', 'uid-a']);

      expect(resolved, hasLength(1));
    });

    test('a blank stored name falls back to the shared default', () async {
      await seedProfile('uid-a', displayName: '   ');

      final Map<String, PublicProfile> resolved =
          await repository.fetchAuthorProfiles(<String>['uid-a']);

      expect(resolved['uid-a']!.displayName, PublicProfile.defaultName);
    });
  });

  group('PublicProfile parsing', () {
    test('a blank photoUrl becomes null rather than an empty string', () {
      final PublicProfile profile = PublicProfile.fromMap(
        'uid-a',
        const <String, dynamic>{
          'displayName': 'White Big Shark',
          'photoUrl': '',
        },
      );

      // ProfileAvatar branches on null to decide whether to show initials; an
      // empty string would send it to CachedNetworkImage with no URL.
      expect(profile.photoUrl, isNull);
    });

    test('a malformed document does not throw', () {
      final PublicProfile profile =
          PublicProfile.fromMap('uid-a', const <String, dynamic>{});

      expect(profile.displayName, PublicProfile.defaultName);
      expect(profile.photoUrl, isNull);
    });

    test('initials match the ones Review derives, so the fallback avatar '
        'does not change character when a projection appears', () {
      expect(
        PublicProfile.fromMap(
          'uid-a',
          const <String, dynamic>{'displayName': 'Ong Song Wei'},
        ).initials,
        'OW',
      );
      expect(
        PublicProfile.fromMap(
          'uid-a',
          const <String, dynamic>{'displayName': 'Maya'},
        ).initials,
        'M',
      );
    });
  });
}

/// Answers with a fixed author, so no Firebase app is needed.
class _StubAuthorResolver implements ReviewAuthorResolver {
  _StubAuthorResolver(this.author);

  final ReviewAuthor author;

  @override
  String get currentUid => author.uid;

  @override
  Future<ReviewAuthor> resolve() async => author;
}
