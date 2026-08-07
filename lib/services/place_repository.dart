import 'dart:async';
import 'dart:math';

import 'package:walkpenang/models/place.dart';
import 'package:walkpenang/models/search_filter.dart';
import 'package:walkpenang/services/place_filter.dart';

/// How long a request may run before it's abandoned (T-FD02.3).
const Duration kRequestTimeout = Duration(seconds: 10);

/// One page of results plus the cursor state the feed needs.
class PlacePage {
  const PlacePage({
    required this.items,
    required this.page,
    required this.hasMore,
  });

  final List<Place> items;
  final int page;
  final bool hasMore;
}

/// Thrown when the backend doesn't answer in [kRequestTimeout].
class ApiTimeoutException implements Exception {
  const ApiTimeoutException([
    this.message = 'Taking too long to load. Check your connection.',
  ]);

  final String message;

  @override
  String toString() => message;
}

/// Thrown for any other backend failure.
class ApiFailureException implements Exception {
  const ApiFailureException([
    this.message = "Couldn't load places. Try again.",
  ]);

  final String message;

  @override
  String toString() => message;
}

abstract class PlaceRepository {
  /// [page] is zero-based.
  Future<PlacePage> fetchPlaces({
    required SearchFilters filters,
    required int page,
    int pageSize,
  });
}

/// Stands in for the real API until the backend is ready. Filtering happens
/// server-side in production, so this mirrors that: it filters the full set,
/// then slices out the requested page.
class MockPlaceRepository implements PlaceRepository {
  MockPlaceRepository({
    this.latency = const Duration(milliseconds: 600),
    this.failureRate = 0.0,
    Random? random,
  }) : _random = random ?? Random();

  final Duration latency;

  /// 0.0–1.0. Bump it to 0.3 to eyeball the error state without unplugging
  /// anything.
  final double failureRate;
  final Random _random;

  @override
  Future<PlacePage> fetchPlaces({
    required SearchFilters filters,
    required int page,
    int pageSize = 10,
  }) {
    final Future<PlacePage> request =
    Future<PlacePage>.delayed(latency, () {
      if (failureRate > 0 && _random.nextDouble() < failureRate) {
        throw const ApiFailureException();
      }

      final List<Place> all = applyFilters(_seed, filters);
      final int start = page * pageSize;

      if (start >= all.length) {
        return PlacePage(items: const <Place>[], page: page, hasMore: false);
      }

      final int end = min(start + pageSize, all.length);
      return PlacePage(
        items: all.sublist(start, end),
        page: page,
        hasMore: end < all.length,
      );
    });

    return request.timeout(
      kRequestTimeout,
      onTimeout: () => throw const ApiTimeoutException(),
    );
  }
}

/// Sample Penang data. Image URLs point at a placeholder service so the
/// caching and error paths are exercised for real.
final List<Place> _seed = <Place>[
  Place(
    id: 'p01',
    name: 'Nasi Kandar Line Clear',
    category: 'Street Food',
    imageUrl: 'https://picsum.photos/seed/lineclear/600/400',
    priceLevel: PriceLevel.budget,
    distanceKm: 0.8,
    rating: 4.3,
    dietaryTags: const <DietaryPreference>{
      DietaryPreference.halal,
      DietaryPreference.noPork,
    },
    description: 'Late-night nasi kandar institution off Penang Road.',
  ),
  Place(
    id: 'p02',
    name: 'Khoo Kongsi Clan House',
    category: 'Heritage',
    imageUrl: 'https://picsum.photos/seed/khookongsi/600/400',
    priceLevel: PriceLevel.budget,
    distanceKm: 1.4,
    rating: 4.6,
    description: 'Ornate clan temple at the heart of the George Town core.',
  ),
  Place(
    id: 'p03',
    name: 'China House',
    category: 'Cafe',
    imageUrl: 'https://picsum.photos/seed/chinahouse/600/400',
    priceLevel: PriceLevel.moderate,
    distanceKm: 1.1,
    rating: 4.4,
    dietaryTags: const <DietaryPreference>{DietaryPreference.vegetarian},
    description: 'Long shophouse cafe known for its cake counter.',
  ),
  Place(
    id: 'p04',
    name: 'Penang Hill Funicular',
    category: 'Nature',
    imageUrl: 'https://picsum.photos/seed/penanghill/600/400',
    priceLevel: PriceLevel.moderate,
    distanceKm: 7.2,
    rating: 4.5,
    description: 'Steep railway up to cooler air and a view over the strait.',
  ),
  Place(
    id: 'p05',
    name: 'Chulia Street Night Hawkers',
    category: 'Night Market',
    imageUrl: 'https://picsum.photos/seed/chulia/600/400',
    priceLevel: PriceLevel.budget,
    distanceKm: 0.6,
    rating: 4.2,
    dietaryTags: const <DietaryPreference>{DietaryPreference.noBeef},
    description: 'Char kway teow and wan tan mee from dusk onwards.',
  ),
  Place(
    id: 'p06',
    name: 'Pinang Peranakan Mansion',
    category: 'Museum',
    imageUrl: 'https://picsum.photos/seed/peranakan/600/400',
    priceLevel: PriceLevel.moderate,
    distanceKm: 1.0,
    rating: 4.5,
    description: 'Baba-Nyonya antiques inside a restored green mansion.',
  ),
  Place(
    id: 'p07',
    name: 'Woodpecker Bakery',
    category: 'Cafe',
    imageUrl: 'https://picsum.photos/seed/woodpecker/600/400',
    priceLevel: PriceLevel.moderate,
    distanceKm: 2.3,
    rating: 4.1,
    dietaryTags: const <DietaryPreference>{
      DietaryPreference.vegetarian,
      DietaryPreference.vegan,
      DietaryPreference.halal,
      DietaryPreference.noPork,
      DietaryPreference.noBeef,
    },
    description: 'Sourdough and plant-based bakes near Gurney.',
  ),
  Place(
    id: 'p08',
    name: 'Kek Lok Si Temple',
    category: 'Heritage',
    imageUrl: 'https://picsum.photos/seed/keklokdsi/600/400',
    priceLevel: PriceLevel.budget,
    distanceKm: 6.8,
    rating: 4.7,
    dietaryTags: const <DietaryPreference>{DietaryPreference.vegetarian},
    description: 'Hillside temple complex above Air Itam.',
  ),
  Place(
    id: 'p09',
    name: 'Gurney Drive Hawker Centre',
    category: 'Street Food',
    imageUrl: 'https://picsum.photos/seed/gurney/600/400',
    priceLevel: PriceLevel.budget,
    distanceKm: 3.9,
    rating: 4.0,
    dietaryTags: const <DietaryPreference>{DietaryPreference.halal},
    description: 'Seafront hawker stalls with rojak and laksa.',
  ),
  Place(
    id: 'p10',
    name: 'Batu Ferringhi Beach',
    category: 'Nature',
    imageUrl: 'https://picsum.photos/seed/ferringhi/600/400',
    priceLevel: PriceLevel.budget,
    distanceKm: 13.5,
    rating: 3.9,
    description: 'Long north-coast beach strip with an evening market.',
  ),
  Place(
    id: 'p11',
    name: 'Hin Bus Depot',
    category: 'Heritage',
    imageUrl: 'https://picsum.photos/seed/hinbus/600/400',
    priceLevel: PriceLevel.moderate,
    distanceKm: 1.7,
    rating: 4.3,
    dietaryTags: const <DietaryPreference>{DietaryPreference.vegetarian},
    description: 'Former bus depot turned art space and Sunday market.',
  ),
  Place(
    id: 'p12',
    name: 'Kebaya Dining Room',
    category: 'Cafe',
    imageUrl: 'https://picsum.photos/seed/kebaya/600/400',
    priceLevel: PriceLevel.premium,
    distanceKm: 1.2,
    rating: 4.8,
    description: 'Tasting-menu Nyonya cooking in a heritage shophouse.',
  ),
  Place(
    id: 'p13',
    name: 'Air Itam Market',
    category: 'Night Market',
    imageUrl: 'https://picsum.photos/seed/airitam/600/400',
    priceLevel: PriceLevel.budget,
    distanceKm: 5.4,
    rating: 4.1,
    dietaryTags: const <DietaryPreference>{DietaryPreference.noBeef},
    description: 'Asam laksa stall crowd from mid-morning.',
  ),
  Place(
    id: 'p14',
    name: 'Penang State Museum',
    category: 'Museum',
    imageUrl: 'https://picsum.photos/seed/statemuseum/600/400',
    priceLevel: PriceLevel.budget,
    distanceKm: 1.3,
    rating: 4.0,
    description: 'Colonial-era building tracing the island settlement story.',
  ),
  Place(
    id: 'p15',
    name: 'Tropical Spice Garden',
    category: 'Nature',
    imageUrl: 'https://picsum.photos/seed/spicegarden/600/400',
    priceLevel: PriceLevel.moderate,
    distanceKm: 11.2,
    rating: 4.4,
    dietaryTags: const <DietaryPreference>{
      DietaryPreference.vegetarian,
      DietaryPreference.vegan,
    },
    description: 'Terraced jungle garden with a cooking school.',
  ),
];