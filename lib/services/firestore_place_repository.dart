import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:walkpenang/models/place.dart';
import 'package:walkpenang/models/rating_summary.dart';
import 'package:walkpenang/models/review.dart';
import 'package:walkpenang/models/search_filters.dart';
import 'package:walkpenang/services/current_uid.dart';
import 'package:walkpenang/services/place_repository.dart';

/// Adds WalkPenang's own ratings and reviews to a place catalogue that comes
/// from somewhere else.
///
/// **Firestore deliberately stores no place content.** Names, addresses,
/// coordinates, opening hours and photos all belong to the Google Places /
/// OSM response and are fetched live — Firestore holds only the place *id*
/// plus what WalkPenang's own users produce against it. Two reasons:
///
///  1. Google Maps Platform Terms 3.2.3(b) permits caching a place id
///     indefinitely but caps the accompanying content at 30 days. Storing ids
///     only sidesteps that entirely, where a full catalogue copy would breach
///     it.
///  2. Place details go stale; an id does not. This is the same reasoning
///     already written into [FavoritesStore], which has always stored ids
///     alone.
///
/// So this is a decorator, not a replacement: [_catalogue] answers "what
/// places are there", and this class answers "what do WalkPenang's tourists
/// think of them".
///
/// Firestore shape:
/// ```
/// places/{placeId}                     ratingSum, ratingCount, reviewCount
/// places/{placeId}/reviews/{reviewId}  authorUid, authorName, rating, body
/// ```
/// `places/{placeId}` carries aggregates only — no name, no coordinates —
/// so a document is meaningless without the live API lookup, by design.
class FirestorePlaceRepository implements PlaceRepository {
  FirestorePlaceRepository({
    required PlaceRepository catalogue,
    FirebaseFirestore? firestore,
    CurrentUid? currentUid,
    this.timeout = kRequestTimeout,
  })  : _catalogue = catalogue,
        _db = firestore ?? FirebaseFirestore.instance,
        _currentUid = currentUid ?? firebaseCurrentUid;

  /// Supplies the places themselves. Today that is [MockPlaceRepository]; when
  /// Discovery moves onto live Places results, only this changes.
  final PlaceRepository _catalogue;

  final FirebaseFirestore _db;
  final CurrentUid _currentUid;
  final Duration timeout;

  /// Aggregates read this session, so the feed doesn't re-read one document
  /// per card on every rebuild. Cleared when a review is submitted.
  final Map<String, RatingSummary> _ratings = <String, RatingSummary>{};

  CollectionReference<Map<String, dynamic>> get _places =>
      _db.collection('places');

  CollectionReference<Map<String, dynamic>> _reviewsOf(String placeId) =>
      _places.doc(placeId).collection('reviews');

  /// Catalogue passes straight through — Firestore has no say in which places
  /// exist. Ratings are overlaid by [primeRatings] / [ratingFor].
  @override
  Future<PlacePage> fetchPlaces({
    required SearchFilters filters,
    required int page,
    int pageSize = 10,
  }) async {
    final result = await _catalogue.fetchPlaces(
      filters: filters,
      page: page,
      pageSize: pageSize,
    );
    await primeRatings(result.items);
    return result;
  }

  /// Fetches the WalkPenang aggregate for a page of places in one round trip.
  ///
  /// Called with a page (10 by default), which stays inside Firestore's limit
  /// of 30 values for a `whereIn` query. Failures are swallowed on purpose:
  /// a missing rating should show the catalogue's own value, not break the
  /// feed.
  Future<void> primeRatings(List<Place> places) async {
    final missing = places
        .map((p) => p.id)
        .where((id) => !_ratings.containsKey(id))
        .toList();
    if (missing.isEmpty) return;

    try {
      for (var i = 0; i < missing.length; i += 30) {
        final chunk = missing.sublist(
          i,
          i + 30 < missing.length ? i + 30 : missing.length,
        );
        final snapshot = await _places
            .where(FieldPath.documentId, whereIn: chunk)
            .get()
            .timeout(timeout);

        for (final doc in snapshot.docs) {
          _ratings[doc.id] = _summaryFrom(doc.data());
        }
        // Places nobody has reviewed have no document at all; record that so
        // we don't re-query them for the rest of the session.
        for (final id in chunk) {
          _ratings.putIfAbsent(id, () => const RatingSummary(average: 0, count: 0));
        }
      }
    } on Exception {
      // Offline or permission-denied: fall through to catalogue ratings.
    }
  }

  RatingSummary _summaryFrom(Map<String, dynamic> data) {
    final sum = (data['ratingSum'] as num?)?.toDouble() ?? 0;
    final count = (data['ratingCount'] as num?)?.toInt() ?? 0;
    if (count == 0) return const RatingSummary(average: 0, count: 0);
    return RatingSummary(average: sum / count, count: count);
  }

  /// WalkPenang's own score where tourists have rated the place, and the
  /// catalogue's where they haven't — a place with no reviews yet should show
  /// the API's rating rather than a bare zero.
  @override
  RatingSummary ratingFor(Place place) {
    final mine = _ratings[place.id];
    if (mine == null || mine.count == 0) {
      return RatingSummary(average: place.rating, count: place.reviewCount);
    }
    return mine;
  }

  @override
  Future<List<Review>> fetchReviews(String placeId, {int limit = 3}) {
    final Future<List<Review>> request = _reviewsOf(placeId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get()
        .then(
          (snapshot) => snapshot.docs
              .map((doc) => reviewFromFirestore(doc.id, placeId, doc.data()))
              .whereType<Review>()
              .toList(),
        )
        .catchError((Object _) => throw const ApiFailureException());

    return request.timeout(
      timeout,
      onTimeout: () => throw const ApiTimeoutException(),
    );
  }

  /// Writes the review and folds it into the place's aggregate atomically.
  ///
  /// A transaction rather than two writes: the review document and the running
  /// ratingSum/ratingCount must not drift apart, or the average shown stops
  /// matching the reviews listed underneath it. The aggregate is denormalised
  /// because Firestore cannot average a subcollection server-side, and reading
  /// every review to compute a mean would cost one read per review per card.
  @override
  Future<Review> submitReview({
    required String placeId,
    required int rating,
    required String body,
    required String authorName,
    int photoCount = 0,
  }) {
    final createdAt = DateTime.now();
    final uid = _currentUid();

    final Future<Review> request = _db.runTransaction<Review>((tx) async {
      final placeRef = _places.doc(placeId);
      final reviewRef = _reviewsOf(placeId).doc();
      final snapshot = await tx.get(placeRef);
      final data = snapshot.data() ?? <String, dynamic>{};

      tx.set(reviewRef, <String, dynamic>{
        'authorUid': uid,
        'authorName': authorName,
        'rating': rating,
        'body': body,
        'photoCount': photoCount,
        'createdAt': Timestamp.fromDate(createdAt),
      });

      tx.set(placeRef, <String, dynamic>{
        'ratingSum': ((data['ratingSum'] as num?)?.toDouble() ?? 0) + rating,
        'ratingCount': ((data['ratingCount'] as num?)?.toInt() ?? 0) + 1,
        'reviewCount': ((data['reviewCount'] as num?)?.toInt() ?? 0) + 1,
        'updatedAt': Timestamp.fromDate(createdAt),
      }, SetOptions(merge: true));

      return Review(
        id: reviewRef.id,
        placeId: placeId,
        authorName: authorName,
        rating: rating,
        body: body,
        createdAt: createdAt,
        photoCount: photoCount,
      );
    }).then((review) {
      _ratings.remove(placeId); // Re-read on next prime.
      return review;
    }).catchError(
      (Object _) =>
          throw const ApiFailureException('Review not sent. Try again.'),
    );

    return request.timeout(
      timeout,
      onTimeout: () => throw const ApiTimeoutException(),
    );
  }
}

Review? reviewFromFirestore(
  String id,
  String placeId,
  Map<String, dynamic> data,
) {
  final body = data['body'] as String?;
  if (body == null) return null;
  return Review(
    id: id,
    placeId: placeId,
    authorName: data['authorName'] as String? ?? 'Anonymous',
    rating: (data['rating'] as num?)?.toInt() ?? 0,
    body: body,
    createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    photoCount: (data['photoCount'] as num?)?.toInt() ?? 0,
  );
}
