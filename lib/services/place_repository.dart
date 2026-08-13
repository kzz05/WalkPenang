import 'dart:async';
import 'dart:math';

import 'package:walkpenang/models/place.dart';
import 'package:walkpenang/models/rating_summary.dart';
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

  /// T-FD05.2 — the place's rating after any reviews submitted this session
  /// have been folded in.
  RatingSummary ratingFor(Place place);
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

/// Trades past midnight — exercises the wrapping branch of isOpenAt.
const OpeningHours _nightHours = OpeningHours(opensAtHour: 18, closesAtHour: 2);

/// Three photos each so the detail carousel has something to page through.
List<String> _photos(String seed) => <String>[
  'https://picsum.photos/seed/$seed/600/400',
  'https://picsum.photos/seed/${seed}b/600/400',
  'https://picsum.photos/seed/${seed}c/600/400',
];

/// Sample Penang data. Image URLs point at a placeholder service so the
/// caching and error paths get exercised for real.
final List<Place> _seed = <Place>[
  Place(
    id: 'p01',
    name: 'Nasi Kandar Line Clear',
    category: PlaceCategory.food,
    photoUrls: _photos('lineclear'),
    priceLevel: PriceLevel.budget,
    distanceKm: 0.3,
    rating: 4.5,
    reviewCount: 1820,
    address: '177 Jalan Penang, George Town, 10000 Penang',
    hours: _nightHours,
    contact: const ContactInfo(phone: '+60 4-261 4849'),
    priceRange: const PriceRange(minRm: 8, maxRm: 20),
    dietaryTags: const <DietaryPreference>{
      DietaryPreference.halal,
      DietaryPreference.noPork,
    },
    description: 'Late-night nasi kandar institution down a narrow alley.',
  ),
  Place(
    id: 'p02',
    name: 'Fort Cornwallis',
    category: PlaceCategory.heritage,
    photoUrls: _photos('cornwallis'),
    priceLevel: PriceLevel.budget,
    distanceKm: 0.7,
    rating: 4.7,
    reviewCount: 2340,
    address: 'Jalan Light, George Town, 10200 Penang',
    hours: _dayHours,
    contact: const ContactInfo(
      phone: '+60 4-263 9855',
      website: 'https://www.penangmuseum.gov.my',
    ),
    priceRange: const PriceRange(minRm: 20, maxRm: 40, unit: 'entry'),
    description:
    'Star-shaped colonial fort on the waterfront, the largest intact '
        'fort in Malaysia.',
  ),
  Place(
    id: 'p03',
    name: 'Penang Hill',
    category: PlaceCategory.nature,
    photoUrls: _photos('penanghill'),
    priceLevel: PriceLevel.moderate,
    distanceKm: 1.2,
    rating: 4.6,
    reviewCount: 3105,
    address: 'Jalan Stesen Bukit Bendera, Air Itam, 11300 Penang',
    hours: _morningHours,
    contact: const ContactInfo(
      phone: '+60 4-828 8880',
      website: 'https://www.penanghill.gov.my',
    ),
    priceRange: const PriceRange(minRm: 30, maxRm: 80, unit: 'return ticket'),
    description: 'Funicular railway up to cooler air and a view of the strait.',
  ),
  Place(
    id: 'p04',
    name: 'Kek Lok Si Temple',
    category: PlaceCategory.heritage,
    photoUrls: _photos('keklokdsi'),
    priceLevel: PriceLevel.budget,
    distanceKm: 2.1,
    rating: 4.8,
    reviewCount: 4210,
    address: 'Jalan Balik Pulau, Air Itam, 11500 Penang',
    hours: _dayHours,
    contact: const ContactInfo(phone: '+60 4-828 3317'),
    dietaryTags: const <DietaryPreference>{DietaryPreference.vegetarian},
    description: 'Hillside temple complex with a towering Guanyin statue.',
  ),
  Place(
    id: 'p05',
    name: 'China House',
    category: PlaceCategory.food,
    photoUrls: _photos('chinahouse'),
    priceLevel: PriceLevel.moderate,
    distanceKm: 0.9,
    rating: 4.4,
    reviewCount: 1560,
    address: '153 Lebuh Pantai, George Town, 10300 Penang',
    hours: _lateHours,
    contact: const ContactInfo(
      phone: '+60 4-263 7299',
      website: 'https://www.chinahouse.com.my',
    ),
    priceRange: const PriceRange(minRm: 25, maxRm: 70),
    dietaryTags: const <DietaryPreference>{DietaryPreference.vegetarian},
    description: 'Long shophouse cafe known for its cake counter.',
  ),
  Place(
    id: 'p06',
    name: 'Pinang Peranakan Mansion',
    category: PlaceCategory.museum,
    photoUrls: _photos('peranakan'),
    priceLevel: PriceLevel.moderate,
    distanceKm: 1.0,
    rating: 4.5,
    reviewCount: 1980,
    address: '29 Church Street, George Town, 10200 Penang',
    hours: _dayHours,
    contact: const ContactInfo(phone: '+60 4-264 2929'),
    priceRange: const PriceRange(minRm: 25, maxRm: 25, unit: 'entry'),
    description: 'Baba-Nyonya antiques inside a restored emerald mansion.',
  ),
  Place(
    id: 'p07',
    name: 'Gurney Plaza',
    category: PlaceCategory.shopping,
    photoUrls: _photos('gurneyplaza'),
    priceLevel: PriceLevel.moderate,
    distanceKm: 3.9,
    rating: 4.2,
    reviewCount: 2870,
    address: '170 Persiaran Gurney, 10250 Penang',
    hours: _lateHours,
    contact: const ContactInfo(website: 'https://www.gurneyplaza.com.my'),
    dietaryTags: const <DietaryPreference>{DietaryPreference.halal},
    description: 'Seafront mall with a food court on the top floor.',
  ),
  // No hours, no contact, no price range — exercises the T-FD03.3 paths.
  Place(
    id: 'p08',
    name: 'Chulia Street Night Hawkers',
    category: PlaceCategory.food,
    photoUrls: _photos('chulia'),
    priceLevel: PriceLevel.budget,
    distanceKm: 0.6,
    rating: 4.3,
    reviewCount: 940,
    address: 'Lebuh Chulia, George Town, 10200 Penang',
    dietaryTags: const <DietaryPreference>{DietaryPreference.noBeef},
    description: 'Char kway teow and wan tan mee from dusk onwards.',
  ),
  Place(
    id: 'p09',
    name: 'Khoo Kongsi Clan House',
    category: PlaceCategory.heritage,
    photoUrls: _photos('khookongsi'),
    priceLevel: PriceLevel.budget,
    distanceKm: 1.4,
    rating: 4.6,
    reviewCount: 1730,
    address: '18 Cannon Square, George Town, 10200 Penang',
    hours: _dayHours,
    contact: const ContactInfo(phone: '+60 4-261 4609'),
    priceRange: const PriceRange(minRm: 15, maxRm: 15, unit: 'entry'),
    description: 'Ornate clan temple at the heart of the George Town core.',
  ),
  Place(
    id: 'p10',
    name: 'Tropical Spice Garden',
    category: PlaceCategory.nature,
    photoUrls: _photos('spicegarden'),
    priceLevel: PriceLevel.moderate,
    distanceKm: 11.2,
    rating: 4.4,
    reviewCount: 1120,
    address: 'Lot 595 Jalan Teluk Bahang, 11100 Penang',
    hours: _dayHours,
    contact: const ContactInfo(
      phone: '+60 4-881 1797',
      website: 'https://tropicalspicegarden.com',
    ),
    priceRange: const PriceRange(minRm: 28, maxRm: 28, unit: 'entry'),
    dietaryTags: const <DietaryPreference>{
      DietaryPreference.vegetarian,
      DietaryPreference.vegan,
    },
    description: 'Terraced jungle garden with a cooking school.',
  ),
  Place(
    id: 'p11',
    name: 'Penang State Museum',
    category: PlaceCategory.museum,
    photoUrls: _photos('statemuseum'),
    priceLevel: PriceLevel.budget,
    distanceKm: 1.3,
    rating: 4.0,
    reviewCount: 680,
    address: 'Lebuh Farquhar, George Town, 10200 Penang',
    hours: _dayHours,
    contact: const ContactInfo(phone: '+60 4-226 1461'),
    priceRange: const PriceRange(minRm: 1, maxRm: 1, unit: 'entry'),
    description: 'Colonial-era building tracing the island settlement story.',
  ),
  // No photos at all — the grid card and carousel must fall back cleanly.
  const Place(
    id: 'p12',
    name: 'Hin Bus Depot',
    category: PlaceCategory.shopping,
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