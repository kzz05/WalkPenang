import 'dart:async';
import 'dart:math';

import 'package:walkpenang/models/place.dart';
import 'package:walkpenang/models/review.dart';
import 'package:walkpenang/models/search_filters.dart';
import 'package:walkpenang/services/place_filter.dart';

const Duration kRequestTimeout = Duration(seconds: 10);

class PlacePage {
  const PlacePage({
    required this.items,
    required this.page,
    required this.hasMore,
    required this.totalCount,
  });

  final List<Place> items;
  final int page;
  final bool hasMore;

  /// Drives the "Nearby you (12 places)" header.
  final int totalCount;
}

class ApiTimeoutException implements Exception {
  const ApiTimeoutException([
    this.message = 'Taking too long to load. Check your connection.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class ApiFailureException implements Exception {
  const ApiFailureException([
    this.message = "Couldn't load places. Try again.",
  ]);

  final String message;

  @override
  String toString() => message;
}

abstract class PlaceRepository {
  Future<PlacePage> fetchPlaces({
    required SearchFilters filters,
    required int page,
    int pageSize,
  });

  Future<List<Review>> fetchReviews(String placeId, {int limit});

  Future<Review> submitReview({
    required String placeId,
    required int rating,
    required String body,
    required String authorName,
    int photoCount,
  });
}

/// Stands in for the real API. Filtering happens server-side in production,
/// so this mirrors that: filter the whole set, then slice out the page.
class MockPlaceRepository implements PlaceRepository {
  MockPlaceRepository({
    this.latency = const Duration(milliseconds: 600),
    this.failureRate = 0.0,
    Random? random,
  }) : _random = random ?? Random();

  final Duration latency;

  /// 0.0–1.0. Set to 0.4 to demo the error state without unplugging wifi.
  final double failureRate;
  final Random _random;

  /// Reviews submitted this session, newest first, keyed by place.
  final Map<String, List<Review>> _submitted = <String, List<Review>>{};

  @override
  Future<PlacePage> fetchPlaces({
    required SearchFilters filters,
    required int page,
    int pageSize = 10,
  }) {
    final Future<PlacePage> request = Future<PlacePage>.delayed(latency, () {
      if (failureRate > 0 && _random.nextDouble() < failureRate) {
        throw const ApiFailureException();
      }

      final List<Place> all = applyFilters(_seed, filters);
      final int start = page * pageSize;

      if (start >= all.length) {
        return PlacePage(
          items: const <Place>[],
          page: page,
          hasMore: false,
          totalCount: all.length,
        );
      }

      final int end = min(start + pageSize, all.length);
      return PlacePage(
        items: all.sublist(start, end),
        page: page,
        hasMore: end < all.length,
        totalCount: all.length,
      );
    });

    return request.timeout(
      kRequestTimeout,
      onTimeout: () => throw const ApiTimeoutException(),
    );
  }

  @override
  Future<List<Review>> fetchReviews(String placeId, {int limit = 3}) {
    final Future<List<Review>> request =
    Future<List<Review>>.delayed(latency, () {
      if (failureRate > 0 && _random.nextDouble() < failureRate) {
        throw const ApiFailureException();
      }
      final List<Review> mine = _submitted[placeId] ?? const <Review>[];
      final List<Review> seeded = _seedReviews
          .where((Review review) => review.placeId == placeId)
          .toList();
      return <Review>[...mine, ...seeded].take(limit).toList();
    });

    return request.timeout(
      kRequestTimeout,
      onTimeout: () => throw const ApiTimeoutException(),
    );
  }

  @override
  Future<Review> submitReview({
    required String placeId,
    required int rating,
    required String body,
    required String authorName,
    int photoCount = 0,
  }) {
    final Future<Review> request = Future<Review>.delayed(latency, () {
      if (failureRate > 0 && _random.nextDouble() < failureRate) {
        throw const ApiFailureException('Review not sent. Try again.');
      }

      final Review review = Review(
        id: 'r-${DateTime.now().microsecondsSinceEpoch}',
        placeId: placeId,
        authorName: authorName,
        rating: rating,
        body: body,
        createdAt: DateTime.now(),
        photoCount: photoCount,
      );

      _submitted.putIfAbsent(placeId, () => <Review>[]).insert(0, review);
      return review;
    });

    return request.timeout(
      kRequestTimeout,
      onTimeout: () => throw const ApiTimeoutException(),
    );
  }
}

const OpeningHours _dayHours = OpeningHours(opensAtHour: 8, closesAtHour: 19);
const OpeningHours _lateHours = OpeningHours(opensAtHour: 11, closesAtHour: 23);
const OpeningHours _morningHours =
OpeningHours(opensAtHour: 7, closesAtHour: 16);

/// Sample Penang data. Image URLs point at a placeholder service so the
/// caching and error paths get exercised for real.
final List<Place> _seed = <Place>[
  const Place(
    id: 'p01',
    name: 'Nasi Kandar Line Clear',
    category: PlaceCategory.food,
    imageUrl: 'https://picsum.photos/seed/lineclear/600/400',
    priceLevel: PriceLevel.budget,
    distanceKm: 0.3,
    rating: 4.5,
    reviewCount: 1820,
    address: '177 Jalan Penang, George Town, 10000 Penang',
    hours: _lateHours,
    dietaryTags: <DietaryPreference>{
      DietaryPreference.halal,
      DietaryPreference.noPork,
    },
    description: 'Late-night nasi kandar institution down a narrow alley.',
  ),
  const Place(
    id: 'p02',
    name: 'Fort Cornwallis',
    category: PlaceCategory.heritage,
    imageUrl: 'https://picsum.photos/seed/cornwallis/600/400',
    priceLevel: PriceLevel.budget,
    distanceKm: 0.7,
    rating: 4.7,
    reviewCount: 2340,
    address: 'Jalan Light, George Town, 10200 Penang',
    hours: _dayHours,
    description:
    'Star-shaped colonial fort on the waterfront, the largest intact '
        'fort in Malaysia.',
  ),
  const Place(
    id: 'p03',
    name: 'Penang Hill',
    category: PlaceCategory.nature,
    imageUrl: 'https://picsum.photos/seed/penanghill/600/400',
    priceLevel: PriceLevel.moderate,
    distanceKm: 1.2,
    rating: 4.6,
    reviewCount: 3105,
    address: 'Jalan Stesen Bukit Bendera, Air Itam, 11300 Penang',
    hours: _morningHours,
    description: 'Funicular railway up to cooler air and a view of the strait.',
  ),
  const Place(
    id: 'p04',
    name: 'Kek Lok Si Temple',
    category: PlaceCategory.heritage,
    imageUrl: 'https://picsum.photos/seed/keklokdsi/600/400',
    priceLevel: PriceLevel.budget,
    distanceKm: 2.1,
    rating: 4.8,
    reviewCount: 4210,
    address: 'Jalan Balik Pulau, Air Itam, 11500 Penang',
    hours: _dayHours,
    dietaryTags: <DietaryPreference>{DietaryPreference.vegetarian},
    description: 'Hillside temple complex with a towering Guanyin statue.',
  ),
  const Place(
    id: 'p05',
    name: 'China House',
    category: PlaceCategory.food,
    imageUrl: 'https://picsum.photos/seed/chinahouse/600/400',
    priceLevel: PriceLevel.moderate,
    distanceKm: 0.9,
    rating: 4.4,
    reviewCount: 1560,
    address: '153 Lebuh Pantai, George Town, 10300 Penang',
    hours: _lateHours,
    dietaryTags: <DietaryPreference>{DietaryPreference.vegetarian},
    description: 'Long shophouse cafe known for its cake counter.',
  ),
  const Place(
    id: 'p06',
    name: 'Pinang Peranakan Mansion',
    category: PlaceCategory.museum,
    imageUrl: 'https://picsum.photos/seed/peranakan/600/400',
    priceLevel: PriceLevel.moderate,
    distanceKm: 1.0,
    rating: 4.5,
    reviewCount: 1980,
    address: '29 Church Street, George Town, 10200 Penang',
    hours: _dayHours,
    description: 'Baba-Nyonya antiques inside a restored emerald mansion.',
  ),
  const Place(
    id: 'p07',
    name: 'Gurney Plaza',
    category: PlaceCategory.shopping,
    imageUrl: 'https://picsum.photos/seed/gurneyplaza/600/400',
    priceLevel: PriceLevel.moderate,
    distanceKm: 3.9,
    rating: 4.2,
    reviewCount: 2870,
    address: '170 Persiaran Gurney, 10250 Penang',
    hours: _lateHours,
    dietaryTags: <DietaryPreference>{DietaryPreference.halal},
    description: 'Seafront mall with a food court on the top floor.',
  ),
  const Place(
    id: 'p08',
    name: 'Chulia Street Night Hawkers',
    category: PlaceCategory.food,
    imageUrl: 'https://picsum.photos/seed/chulia/600/400',
    priceLevel: PriceLevel.budget,
    distanceKm: 0.6,
    rating: 4.3,
    reviewCount: 940,
    address: 'Lebuh Chulia, George Town, 10200 Penang',
    hours: _lateHours,
    dietaryTags: <DietaryPreference>{DietaryPreference.noBeef},
    description: 'Char kway teow and wan tan mee from dusk onwards.',
  ),
  const Place(
    id: 'p09',
    name: 'Khoo Kongsi Clan House',
    category: PlaceCategory.heritage,
    imageUrl: 'https://picsum.photos/seed/khookongsi/600/400',
    priceLevel: PriceLevel.budget,
    distanceKm: 1.4,
    rating: 4.6,
    reviewCount: 1730,
    address: '18 Cannon Square, George Town, 10200 Penang',
    hours: _dayHours,
    description: 'Ornate clan temple at the heart of the George Town core.',
  ),
  const Place(
    id: 'p10',
    name: 'Tropical Spice Garden',
    category: PlaceCategory.nature,
    imageUrl: 'https://picsum.photos/seed/spicegarden/600/400',
    priceLevel: PriceLevel.moderate,
    distanceKm: 11.2,
    rating: 4.4,
    reviewCount: 1120,
    address: 'Lot 595 Jalan Teluk Bahang, 11100 Penang',
    hours: _dayHours,
    dietaryTags: <DietaryPreference>{
      DietaryPreference.vegetarian,
      DietaryPreference.vegan,
    },
    description: 'Terraced jungle garden with a cooking school.',
  ),
  const Place(
    id: 'p11',
    name: 'Penang State Museum',
    category: PlaceCategory.museum,
    imageUrl: 'https://picsum.photos/seed/statemuseum/600/400',
    priceLevel: PriceLevel.budget,
    distanceKm: 1.3,
    rating: 4.0,
    reviewCount: 680,
    address: 'Lebuh Farquhar, George Town, 10200 Penang',
    hours: _dayHours,
    description: 'Colonial-era building tracing the island settlement story.',
  ),
  const Place(
    id: 'p12',
    name: 'Hin Bus Depot',
    category: PlaceCategory.shopping,
    imageUrl: 'https://picsum.photos/seed/hinbus/600/400',
    priceLevel: PriceLevel.moderate,
    distanceKm: 1.7,
    rating: 4.3,
    reviewCount: 1440,
    address: '31A Jalan Gurdwara, George Town, 10300 Penang',
    hours: _dayHours,
    dietaryTags: <DietaryPreference>{DietaryPreference.vegetarian},
    description: 'Former bus depot turned art space and Sunday market.',
  ),
];

final List<Review> _seedReviews = <Review>[
  Review(
    id: 'rv01',
    placeId: 'p02',
    authorName: 'Maya R',
    rating: 5,
    body: 'Beautiful historic fort with amazing sea views. A must visit in '
        'George Town.',
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
  ),
  Review(
    id: 'rv02',
    placeId: 'p02',
    authorName: 'Tan K',
    rating: 4,
    body: 'Great spot for photos at sunset. Can get crowded on weekends.',
    createdAt: DateTime.now().subtract(const Duration(days: 9)),
  ),
  Review(
    id: 'rv03',
    placeId: 'p02',
    authorName: 'Arif H',
    rating: 5,
    body: 'The cannon and the lighthouse are worth the entry fee. Bring water, '
        'there is very little shade.',
    createdAt: DateTime.now().subtract(const Duration(days: 21)),
  ),
  Review(
    id: 'rv04',
    placeId: 'p01',
    authorName: 'Siti N',
    rating: 5,
    body: 'Best nasi kandar on the island. Go late and order the ayam goreng.',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
  ),
  Review(
    id: 'rv05',
    placeId: 'p01',
    authorName: 'James L',
    rating: 4,
    body: 'Queue moves fast even when it looks long. Cash only.',
    createdAt: DateTime.now().subtract(const Duration(days: 12)),
  ),
  Review(
    id: 'rv06',
    placeId: 'p03',
    authorName: 'Wei Ming',
    rating: 5,
    body: 'Take the funicular early to skip the queue. Much cooler at the top.',
    createdAt: DateTime.now().subtract(const Duration(days: 5)),
  ),
  Review(
    id: 'rv07',
    placeId: 'p04',
    authorName: 'Priya S',
    rating: 5,
    body: 'Stunning during Chinese New Year when the whole temple is lit up.',
    createdAt: DateTime.now().subtract(const Duration(days: 30)),
  ),
];
