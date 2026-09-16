import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkpenang/models/review.dart';
import 'package:walkpenang/services/firestore_place_repository.dart';
import 'package:walkpenang/services/review_author.dart';

/// Reviews used to look like they followed the device: sign in as a second
/// account on the same phone and the first account's review was sitting there
/// presented as yours. Two causes — the submission modal hardcoded the author
/// name to the literal 'You', and review documents carried no owner at all.
///
/// Reviews are public by design, so the fix is not to hide other tourists'
/// reviews. It is that each one is attributed to whoever actually wrote it,
/// and only your own reads as yours.
void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() => firestore = FakeFirebaseFirestore());

  /// The uid/display name are injected rather than read from FirebaseAuth, so
  /// these run against an in-memory Firestore with no Firebase app and no auth
  /// mocking — the same seam FirestoreFavoritesStore uses in
  /// account_scoped_stores_test.dart.
  FirestorePlaceRepository repositoryFor(ReviewAuthor author) =>
      FirestorePlaceRepository(
        firestore: firestore,
        authorResolver: _StubAuthorResolver(author),
      );

  const ReviewAuthor touristA =
      ReviewAuthor(uid: 'uid-a', displayName: 'Ong Song Wei');
  const ReviewAuthor touristB =
      ReviewAuthor(uid: 'uid-b', displayName: 'Tang Yue Hann');

  group('review attribution', () {
    test('a submitted review is stamped with its writer', () async {
      await repositoryFor(touristA).submitReview(
        placeId: 'p1',
        rating: 5,
        body: 'Best char kway teow in Penang.',
      );

      final Map<String, dynamic> stored =
          (await firestore.collection('reviews').get()).docs.single.data();

      expect(stored['userId'], 'uid-a');
      expect(stored['authorName'], 'Ong Song Wei');
      expect(stored['placeId'], 'p1');
    });

    test('a second account on the same device sees the review as someone '
        "else's, under the real author's name", () async {
      await repositoryFor(touristA).submitReview(
        placeId: 'p1',
        rating: 5,
        body: 'Written by the first account to use this phone.',
      );

      // A different tourist signs in — a fresh repository, as a real app
      // restart or a re-entered Discovery screen would build.
      final List<Review> seenByB =
          await repositoryFor(touristB).fetchReviews('p1');

      expect(seenByB, hasLength(1));
      expect(seenByB.single.authorName, 'Ong Song Wei');
      expect(seenByB.single.isMine('uid-b'), isFalse,
          reason: 'B did not write this and must not be shown as its author');
      expect(seenByB.single.isMine('uid-a'), isTrue);
    });

    test('your own review still reads as yours', () async {
      final FirestorePlaceRepository repository = repositoryFor(touristA);
      await repository.submitReview(
        placeId: 'p1',
        rating: 4,
        body: 'Busy at night but worth the wait.',
      );

      final List<Review> mine = await repository.fetchReviews('p1');
      expect(mine.single.isMine('uid-a'), isTrue);
    });

    test('switching account drops the previous tourist’s session cache',
        () async {
      // One long-lived repository, as _DiscoveryModuleViewState holds: it
      // survives a sign-out that does not pop the Discovery screen.
      final _MutableAuthorResolver resolver =
          _MutableAuthorResolver(touristA);
      final FirestorePlaceRepository repository = FirestorePlaceRepository(
        firestore: firestore,
        authorResolver: resolver,
      );

      await repository.submitReview(
        placeId: 'p1',
        rating: 5,
        body: 'Pinned to the top of the list for whoever looks next.',
      );

      resolver.author = touristB;
      final List<Review> seenByB = await repository.fetchReviews('p1');

      // Still visible — reviews are public — but as A's, read back from
      // Firestore rather than served from B's session cache.
      expect(seenByB.single.isMine('uid-b'), isFalse);
      expect(seenByB.single.authorName, 'Ong Song Wei');
    });

    test('a signed-out tourist cannot publish a review', () async {
      expect(
        () => repositoryFor(ReviewAuthor.signedOut).submitReview(
          placeId: 'p1',
          rating: 5,
          body: 'Should never reach Firestore.',
        ),
        throwsA(isA<Exception>()),
      );
      expect((await firestore.collection('reviews').get()).docs, isEmpty);
    });

    test('a legacy review written as "You" reads back as Anonymous', () async {
      // Exactly what the old submission modal wrote: a display name of 'You'
      // and no owner. Left in place rather than backfilled.
      await firestore.collection('reviews').add(<String, dynamic>{
        'placeId': 'p1',
        'authorName': 'You',
        'rating': 4,
        'body': 'Written before reviews had an owner.',
        'createdAt': DateTime(2026, 8, 1).toIso8601String(),
        'photoCount': 0,
      });

      final List<Review> seen = await repositoryFor(touristB).fetchReviews('p1');

      expect(seen.single.authorName, 'Anonymous');
      expect(seen.single.isMine('uid-b'), isFalse);
    });
  });

  group('display name precedence', () {
    test('profile nickname wins', () {
      expect(
        ReviewAuthorResolver.resolveDisplayName(
          nickname: 'Yue Hann',
          email: 'ianwong@example.com',
          authDisplayName: 'Ian Wong',
        ),
        'Yue Hann',
      );
    });

    test('falls back to the email prefix when the nickname is blank', () {
      expect(
        ReviewAuthorResolver.resolveDisplayName(
          nickname: '   ',
          email: 'ianwong@example.com',
        ),
        'ianwong',
      );
    });

    test('falls back to the auth display name, then Anonymous', () {
      expect(
        ReviewAuthorResolver.resolveDisplayName(authDisplayName: 'Ian Wong'),
        'Ian Wong',
      );
      expect(ReviewAuthorResolver.resolveDisplayName(), 'Anonymous');
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

/// Same, but the account can change mid-test — a sign-out and sign-in while
/// one repository instance stays alive.
class _MutableAuthorResolver implements ReviewAuthorResolver {
  _MutableAuthorResolver(this.author);

  ReviewAuthor author;

  @override
  String get currentUid => author.uid;

  @override
  Future<ReviewAuthor> resolve() async => author;
}
