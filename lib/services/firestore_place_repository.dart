import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:walkpenang/models/place.dart';
import 'package:walkpenang/models/rating_summary.dart';
import 'package:walkpenang/models/review.dart';
import 'package:walkpenang/models/search_filters.dart';
import 'package:walkpenang/services/place_filter.dart';
import 'package:walkpenang/services/place_repository.dart';

/// Real backend for the Discovery module: places and their photos live in
/// the 'places' Firestore collection (seeded by tool/seed_places.dart),
/// reviews live in 'reviews'.
///
/// Filtering/sorting still happens client-side over the full place set —
/// there are only a few dozen documents, so a composite Firestore query
/// buys nothing but index-management pain. This mirrors MockPlaceRepository
/// on purpose, so DiscoveryController didn't need to change.
class FirestorePlaceRepository implements PlaceRepository {
  FirestorePlaceRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Reviews submitted this session, newest first, keyed by place — folded
  /// into the rating shown in the UI without waiting on a Firestore round
  /// trip (T-FD05.2, same behavior as MockPlaceRepository).
  final Map<String, List<Review>> _submitted = <String, List<Review>>{};

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
    final List<Review> mine = _submitted[placeId] ?? const <Review>[];
    final int remaining = limit - mine.length;
    if (remaining <= 0) return mine.take(limit).toList();

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _db
        .collection('reviews')
        .where('placeId', isEqualTo: placeId)
        .orderBy('createdAt', descending: true)
        .limit(remaining)
        .get()
        .timeout(
      kRequestTimeout,
      onTimeout: () => throw const ApiTimeoutException(),
    );

    final List<Review> seeded = snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
        Review.fromMap(doc.id, doc.data()))
        .toList();

    return <Review>[...mine, ...seeded];
  }

  @override
  Future<Review> submitReview({
    required String placeId,
    required int rating,
    required String body,
    required String authorName,
    int photoCount = 0,
  }) async {
    final Review draft = Review(
      id: '',
      placeId: placeId,
      authorName: authorName,
      rating: rating,
      body: body,
      createdAt: DateTime.now(),
      photoCount: photoCount,
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
      authorName: authorName,
      rating: rating,
      body: body,
      createdAt: draft.createdAt,
      photoCount: photoCount,
    );

    _submitted.putIfAbsent(placeId, () => <Review>[]).insert(0, saved);
    return saved;
  }
}
