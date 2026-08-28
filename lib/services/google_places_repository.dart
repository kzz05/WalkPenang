import 'dart:async';

import 'package:walkpenang/models/place.dart';
import 'package:walkpenang/models/rating_summary.dart';
import 'package:walkpenang/models/review.dart';
import 'package:walkpenang/models/search_filters.dart';
import 'package:walkpenang/services/firestore_place_repository.dart';
import 'package:walkpenang/services/google_places_service.dart';
import 'package:walkpenang/services/place_filter.dart';
import 'package:walkpenang/services/place_repository.dart';

/// Must be valid Places API (New) "Table A" included types — Table B types
/// like `place_of_worship`/`natural_feature` are response-only and get
/// rejected with INVALID_ARGUMENT if sent as a filter.
const Map<PlaceCategory, List<String>> _kIncludedTypesByCategory = {
  PlaceCategory.food: ['restaurant', 'cafe', 'bakery', 'bar'],
  PlaceCategory.heritage: [
    'tourist_attraction', 'historical_landmark', 'cultural_landmark',
    'church', 'mosque', 'hindu_temple',
  ],
  PlaceCategory.nature: ['park', 'national_park', 'botanical_garden'],
  PlaceCategory.museum: ['museum'],
  PlaceCategory.shopping: ['shopping_mall'],
};

/// Real place catalog for the Discovery module, sourced live from Places API
/// (New). Reviews/ratings/favorites stay in Firestore — Google doesn't let
/// the app write custom reviews back — so those calls delegate to an inner
/// [FirestorePlaceRepository], keyed by Google's place id.
class GooglePlacesRepository implements PlaceRepository {
  GooglePlacesRepository({GooglePlacesService? service})
      : _service = service ?? GooglePlacesService(),
        _firestore = FirestorePlaceRepository();

  final GooglePlacesService _service;
  final FirestorePlaceRepository _firestore;

  /// One fetch per (keyword, categories) combination — the two filters that
  /// actually change what Google returns. Mirrors
  /// FirestorePlaceRepository's single-future-cache pattern.
  final Map<String, Future<List<Place>>> _cache = <String, Future<List<Place>>>{};

  @override
  RatingSummary ratingFor(Place place) => _firestore.ratingFor(place);

  /// App-submitted reviews (Firestore) come first — they're what the
  /// current user just wrote — topped up with Google's own reviews for the
  /// place so the list isn't empty before anyone's reviewed it in-app.
  @override
  Future<List<Review>> fetchReviews(String placeId, {int limit = 3}) async {
    final List<Review> appReviews =
        await _firestore.fetchReviews(placeId, limit: limit);
    final int remaining = limit - appReviews.length;
    if (remaining <= 0) return appReviews;

    try {
      final List<Map<String, dynamic>> raw = await _service.getReviews(placeId);
      final List<Review> googleReviews = raw
          .map((Map<String, dynamic> json) =>
              Review.fromGooglePlace(placeId, json))
          .take(remaining)
          .toList();
      return <Review>[...appReviews, ...googleReviews];
    } on ApiTimeoutException {
      return appReviews;
    } on ApiFailureException {
      return appReviews;
    }
  }

  @override
  Future<Review> submitReview({
    required String placeId,
    required int rating,
    required String body,
    required String authorName,
    int photoCount = 0,
  }) =>
      _firestore.submitReview(
        placeId: placeId,
        rating: rating,
        body: body,
        authorName: authorName,
        photoCount: photoCount,
      );

  @override
  Future<PlacePage> fetchPlaces({
    required SearchFilters filters,
    required int page,
    int pageSize = 10,
  }) async {
    final List<Place> all =
        applyFilters(await _loadPlaces(filters), filters);
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

  Future<List<Place>> _loadPlaces(SearchFilters filters) {
    final String keyword = filters.keyword.trim();
    final String signature = '$keyword|${filters.categories.map((c) => c.name).join(',')}';

    return _cache.putIfAbsent(signature, () async {
      try {
        final List<Map<String, dynamic>> raw = keyword.isNotEmpty
            ? await _searchTextAll(keyword, filters.categories)
            : await _searchNearbyAll(filters.categories);

        return raw
            .map((Map<String, dynamic> json) => Place.fromGooglePlace(
                  json,
                  photoUrlBuilder: _service.photoUrl,
                  originLat: kPenangCenterLat,
                  originLng: kPenangCenterLng,
                ))
            .toList();
      } catch (error) {
        _cache.remove(signature);
        if (error is ApiTimeoutException || error is ApiFailureException) {
          rethrow;
        }
        throw const ApiFailureException();
      }
    });
  }

  /// Chains up to 3 pages (~60 results) via [GooglePlacesService.searchText]'s
  /// page token so there's enough to paginate locally.
  Future<List<Map<String, dynamic>>> _searchTextAll(
    String keyword,
    Set<PlaceCategory> categories,
  ) async {
    final String? includedType = categories.length == 1
        ? _kIncludedTypesByCategory[categories.first]?.first
        : null;

    final List<Map<String, dynamic>> results = <Map<String, dynamic>>[];
    String? pageToken;

    for (int i = 0; i < 3; i++) {
      final GooglePlacesSearchResult result = await _service.searchText(
        textQuery: keyword,
        includedType: includedType,
        pageToken: pageToken,
      );
      results.addAll(result.places);
      pageToken = result.nextPageToken;
      if (pageToken == null) break;
    }

    return results;
  }

  /// One Nearby Search per category, run in parallel and merged by place id.
  ///
  /// Nearby Search (New) caps out at 20 results *total*, no matter how many
  /// included types are in one request — cramming every category into a
  /// single call meant "All" silently lost most food/heritage/nature places
  /// to whichever type Google ranked as more prominent (usually shopping
  /// malls). Querying each category separately gives each a full 20-result
  /// budget instead of fighting over one.
  Future<List<Map<String, dynamic>>> _searchNearbyAll(
    Set<PlaceCategory> categories,
  ) async {
    final List<PlaceCategory> targets =
        categories.isEmpty ? PlaceCategory.values : categories.toList();

    final List<List<Map<String, dynamic>>> batches = await Future.wait(
      targets.map((PlaceCategory category) => _service.searchNearby(
            includedTypes: _kIncludedTypesByCategory[category]!,
          )),
    );

    final Map<String, Map<String, dynamic>> byId = <String, Map<String, dynamic>>{};
    for (final List<Map<String, dynamic>> batch in batches) {
      for (final Map<String, dynamic> place in batch) {
        final String? id = place['id'] as String?;
        if (id != null) byId[id] = place;
      }
    }
    return byId.values.toList();
  }
}
