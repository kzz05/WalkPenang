import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:walkpenang/models/place.dart';
import 'package:walkpenang/models/rating_summary.dart';
import 'package:walkpenang/models/review.dart';
import 'package:walkpenang/models/search_filters.dart';
import 'package:walkpenang/services/place_filter.dart';
import 'package:walkpenang/models/public_profile.dart';
import 'package:walkpenang/services/place_repository.dart';
import 'package:walkpenang/services/review_author.dart';

/// Real backend for the Discovery module: places and their photos live in
/// the 'places' Firestore collection (seeded by tool/seed_places.dart),
/// reviews live in 'reviews'.
///
/// Filtering/sorting still happens client-side over the full place set —
/// there are only a few dozen documents, so a composite Firestore query
/// buys nothing but index-management pain. This mirrors MockPlaceRepository
/// on purpose, so DiscoveryController didn't need to change.
class FirestorePlaceRepository implements PlaceRepository {
  FirestorePlaceRepository({
    FirebaseFirestore? firestore,
    ReviewAuthorResolver? authorResolver,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _authorResolver = authorResolver ?? ReviewAuthorResolver();

  final FirebaseFirestore _db;
  final ReviewAuthorResolver _authorResolver;

  /// Reviews submitted this session, newest first, keyed by place — folded
  /// into the rating shown in the UI without waiting on a Firestore round
  /// trip (T-FD05.2, same behavior as MockPlaceRepository).
  final Map<String, List<Review>> _submitted = <String, List<Review>>{};

  /// Whose reviews are in [_submitted]. This repository outlives a sign-out:
  /// it belongs to _DiscoveryModuleViewState, so switching accounts without
  /// popping the Discovery screen used to leave the previous tourist's
  /// just-written review pinned to the top of the list for the new one.
  String _cachedFor = '';

  /// Drops the session cache when the signed-in tourist changes.
  void _syncCacheOwner(String uid) {
    if (_cachedFor == uid) return;
    _submitted.clear();
    _cachedFor = uid;
  }

  Future<List<Place>>? _allPlacesFuture;

  Future<List<Place>> _loadAllPlaces() {
    return _allPlacesFuture ??= _db
        .collection('places')
        .get()
        .then((QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
        Place.fromMap(doc.id, doc.data()))
        .toList())
        .timeout(
      kRequestTimeout,
      onTimeout: () => throw const ApiTimeoutException(),
    )
        .catchError((Object error) {
      _allPlacesFuture = null;
      if (error is ApiTimeoutException) throw error;
      throw const ApiFailureException();
    });
  }

  @override
  RatingSummary ratingFor(Place place) {
    // Runs before fetchReviews on a freshly opened place (it seeds the
    // detail screen's initial average), so it has to notice an account
    // switch too — otherwise the previous tourist's rating is folded in.
    _syncCacheOwner(_authorResolver.currentUid);

    final RatingSummary seeded = RatingSummary(
      average: place.rating,
      count: place.reviewCount,
    );
    final List<Review> mine = _submitted[place.id] ?? const <Review>[];
    if (mine.isEmpty) return seeded;
    return seeded.withReviews(mine.map((Review r) => r.rating));
  }

  @override
  Future<PlacePage> fetchPlaces({
    required SearchFilters filters,
    required int page,
    int pageSize = 10,
  }) async {
    final List<Place> all = applyFilters(await _loadAllPlaces(), filters);
    final int start = page * pageSize;

    if (start >= all.length) {
      return PlacePage(
        items: const <Place>[],
        page: page,
        hasMore: false,
        totalCount: all.length,
      );
    }

    final int end = start + pageSize < all.length ? start + pageSize : all.length;
    return PlacePage(
      items: all.sublist(start, end),
      page: page,
      hasMore: end < all.length,
      totalCount: all.length,
    );
  }

  @override
  Future<List<Review>> fetchReviews(String placeId, {int limit = 3}) async {
    _syncCacheOwner(_authorResolver.currentUid);

    final List<Review> mine = _submitted[placeId] ?? const <Review>[];
    final int remaining = limit - mine.length;
    if (remaining <= 0) return mine.take(limit).toList();

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _db
        .collection('reviews')
        .where('placeId', isEqualTo: placeId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get()
        .timeout(
      kRequestTimeout,
      onTimeout: () => throw const ApiTimeoutException(),
    );

    final List<Review> seeded = snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
        Review.fromMap(doc.id, doc.data()))
        .toList();

    // A review submitted this session is in both lists — it is in _submitted
    // and it is now a document the query returns. Reviews compare by id, so
    // keep the session copy and drop the echo.
    final Set<String> seen = mine.map((Review r) => r.id).toSet();
    return <Review>[
      ...mine,
      ...seeded.where((Review r) => seen.add(r.id)),
    ].take(limit).toList();
  }

  @override
  Future<ReviewAuthor> currentAuthor() => _authorResolver.resolve();

  /// Firestore caps a `whereIn` at 30 values. A review page is 3 by default, so
  /// this never chunks in practice — it is here so a caller that widens the
  /// page size later does not silently start throwing.
  static const int _whereInLimit = 30;

  @override
  Future<Map<String, PublicProfile>> fetchAuthorProfiles(
    Iterable<String> userIds,
  ) async {
    final List<String> ids =
        userIds.where((String id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return const <String, PublicProfile>{};

    final Map<String, PublicProfile> resolved = <String, PublicProfile>{};

    for (int start = 0; start < ids.length; start += _whereInLimit) {
      final List<String> chunk = ids.sublist(
        start,
        start + _whereInLimit < ids.length ? start + _whereInLimit : ids.length,
      );

      // Deliberately not wrapped in the ApiTimeout/ApiFailure translation the
      // other reads use. A missing or slow profile lookup must never fail the
      // review list — the caller falls back to the name stored on the review,
      // which is exactly what it used to show anyway.
      try {
        final QuerySnapshot<Map<String, dynamic>> snapshot = await _db
            .collection('public_profiles')
            .where(FieldPath.documentId, whereIn: chunk)
            .get()
            .timeout(kRequestTimeout);

        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in snapshot.docs) {
          resolved[doc.id] = PublicProfile.fromMap(doc.id, doc.data());
        }
      } catch (_) {
        // Leave this chunk unresolved; the fallback covers it.
      }
    }

    return resolved;
  }

  @override
  Future<Review> submitReview({
    required String placeId,
    required int rating,
    required String body,
    int photoCount = 0,
  }) async {
    final ReviewAuthor author = await _authorResolver.resolve();
    if (!author.isSignedIn) {
      // The rule rejects an unowned review anyway; failing here turns a raw
      // permission-denied into the message the modal already knows how to show.
      throw const ApiFailureException('Sign in to write a review.');
    }
    _syncCacheOwner(author.uid);

    final Review draft = Review(
      id: '',
      placeId: placeId,
      authorName: author.displayName,
      rating: rating,
      body: body,
      createdAt: DateTime.now(),
      photoCount: photoCount,
      userId: author.uid,
    );

    final DocumentReference<Map<String, dynamic>> ref = await _db
        .collection('reviews')
        .add(draft.toMap())
        .timeout(
      kRequestTimeout,
      onTimeout: () => throw const ApiTimeoutException('Review not sent. Try again.'),
    );

    final Review saved = Review(
      id: ref.id,
      placeId: placeId,
      authorName: author.displayName,
      rating: rating,
      body: body,
      createdAt: draft.createdAt,
      photoCount: photoCount,
      userId: author.uid,
    );

    _submitted.putIfAbsent(placeId, () => <Review>[]).insert(0, saved);
    return saved;
  }
}
