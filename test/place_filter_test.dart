import 'package:flutter_test/flutter_test.dart';

import 'package:walkpenang/models/place.dart';
import 'package:walkpenang/models/search_filters.dart';
import 'package:walkpenang/services/place_filter.dart';

/// T-FD01.3 — keyword queries, zero-result states, filter reset.
void main() {
  const OpeningHours dayHours = OpeningHours(opensAtHour: 8, closesAtHour: 19);
  const OpeningHours eveningHours =
  OpeningHours(opensAtHour: 18, closesAtHour: 23);

  final List<Place> fixtures = <Place>[
    const Place(
      id: 'a',
      name: 'Nasi Kandar Line Clear',
      category: PlaceCategory.food,
      priceLevel: PriceLevel.budget,
      distanceKm: 0.3,
      rating: 4.5,
      reviewCount: 1820,
      address: '177 Jalan Penang, George Town',
      hours: eveningHours,
      dietaryTags: <DietaryPreference>{
        DietaryPreference.halal,
        DietaryPreference.noPork,
      },
      description: 'Late-night nasi kandar off Penang Road.',
    ),
    const Place(
      id: 'b',
      name: 'Fort Cornwallis',
      category: PlaceCategory.heritage,
      priceLevel: PriceLevel.moderate,
      distanceKm: 0.7,
      rating: 4.7,
      reviewCount: 2340,
      address: 'Jalan Light, George Town',
      hours: dayHours,
      description: 'Star-shaped colonial fort on the waterfront.',
    ),
    const Place(
      id: 'c',
      name: 'Tropical Spice Garden',
      category: PlaceCategory.nature,
      priceLevel: PriceLevel.premium,
      distanceKm: 14.0,
      rating: 4.4,
      reviewCount: 1120,
      address: 'Jalan Teluk Bahang',
      hours: dayHours,
      dietaryTags: <DietaryPreference>{
        DietaryPreference.vegetarian,
        DietaryPreference.vegan,
      },
      description: 'Terraced jungle garden with a cooking school.',
    ),
  ];

  /// Midday, so day-hours places are open and evening-only ones are not.
  final DateTime noon = DateTime(2026, 8, 7, 12);

  group('keyword search', () {
    test('empty keyword returns everything', () {
      expect(applyFilters(fixtures, const SearchFilters()), hasLength(3));
    });

    test('matches on name, case-insensitively', () {
      final List<Place> result =
      applyFilters(fixtures, const SearchFilters(keyword: 'cornwallis'));
      expect(result.single.id, 'b');
    });

    test('matches on description and address too', () {
      expect(
        applyFilters(fixtures, const SearchFilters(keyword: 'jungle'))
            .single
            .id,
        'c',
      );
      expect(
        applyFilters(fixtures, const SearchFilters(keyword: 'teluk'))
            .single
            .id,
        'c',
      );
    });

    test('all terms must match, not just one', () {
      expect(
        applyFilters(fixtures, const SearchFilters(keyword: 'nasi')),
        hasLength(1),
      );
      expect(
        applyFilters(fixtures, const SearchFilters(keyword: 'nasi sushi')),
        isEmpty,
      );
    });

    test('surrounding whitespace is ignored', () {
      final List<Place> result =
      applyFilters(fixtures, const SearchFilters(keyword: '  fort  '));
      expect(result.single.id, 'b');
    });
  });

  group('zero-result states', () {
    test('unmatched keyword yields an empty list, not an error', () {
      expect(
        applyFilters(fixtures, const SearchFilters(keyword: 'zzzzz')),
        isEmpty,
      );
    });

    test('impossible filter combination yields empty', () {
      final List<Place> result = applyFilters(
        fixtures,
        const SearchFilters(
          minPriceLevel: PriceLevel.premium,
          maxDistanceKm: 1.0,
        ),
      );
      expect(result, isEmpty);
    });

    test('conflicting dietary tags yield empty', () {
      final List<Place> result = applyFilters(
        fixtures,
        const SearchFilters(
          dietary: <DietaryPreference>{
            DietaryPreference.halal,
            DietaryPreference.vegan,
          },
        ),
      );
      expect(result, isEmpty);
    });
  });

  group('category, dietary, price, distance', () {
    test('no categories selected means All', () {
      expect(applyFilters(fixtures, const SearchFilters()), hasLength(3));
    });

    test('single category narrows correctly', () {
      final List<Place> result = applyFilters(
        fixtures,
        const SearchFilters(categories: <PlaceCategory>{PlaceCategory.food}),
      );
      expect(result.single.id, 'a');
    });

    test('multiple categories are an OR', () {
      final List<Place> result = applyFilters(
        fixtures,
        const SearchFilters(categories: <PlaceCategory>{
          PlaceCategory.food,
          PlaceCategory.nature,
        }),
      );
      expect(result.map((Place p) => p.id), containsAll(<String>['a', 'c']));
      expect(result, hasLength(2));
    });

    test('dietary filter is AND, not OR', () {
      final List<Place> result = applyFilters(
        fixtures,
        const SearchFilters(dietary: <DietaryPreference>{
          DietaryPreference.vegetarian,
          DietaryPreference.vegan,
        }),
      );
      expect(result.single.id, 'c');
    });

    test('price range is inclusive at both ends', () {
      final List<Place> result = applyFilters(
        fixtures,
        const SearchFilters(
          minPriceLevel: PriceLevel.moderate,
          maxPriceLevel: PriceLevel.premium,
        ),
      );
      expect(result.map((Place p) => p.id), containsAll(<String>['b', 'c']));
      expect(result.map((Place p) => p.id), isNot(contains('a')));
    });

    test('distance filter excludes anything further out', () {
      final List<Place> result =
      applyFilters(fixtures, const SearchFilters(maxDistanceKm: 1.0));
      expect(result.map((Place p) => p.id), <String>['a', 'b']);
    });
  });

  group('open now', () {
    test('excludes places closed at the given time', () {
      final List<Place> result = applyFilters(
        fixtures,
        const SearchFilters(openNowOnly: true),
        now: noon,
      );
      // The evening-only nasi kandar drops out at midday.
      expect(result.map((Place p) => p.id), <String>['b', 'c']);
    });

    test('includes everything when the toggle is off', () {
      final List<Place> result =
      applyFilters(fixtures, const SearchFilters(), now: noon);
      expect(result, hasLength(3));
    });

    test('a place with no published hours is excluded by open-now', () {
      const Place unknown = Place(
        id: 'd',
        name: 'Mystery Stall',
        category: PlaceCategory.food,
        priceLevel: PriceLevel.budget,
        distanceKm: 0.5,
        rating: 4.0,
        reviewCount: 12,
        address: 'Lebuh Chulia',
      );

      final List<Place> result = applyFilters(
        <Place>[unknown],
        const SearchFilters(openNowOnly: true),
        now: noon,
      );
      expect(result, isEmpty);

      // But it still shows when the toggle is off.
      expect(
        applyFilters(<Place>[unknown], const SearchFilters(), now: noon),
        hasLength(1),
      );
    });
  });

  group('sorting', () {
    test('nearest first', () {
      final List<Place> result = applyFilters(
        fixtures,
        const SearchFilters(sortBy: SortOption.distance),
      );
      expect(result.map((Place p) => p.id), <String>['a', 'b', 'c']);
    });

    test('top rated first', () {
      final List<Place> result = applyFilters(
        fixtures,
        const SearchFilters(sortBy: SortOption.rating),
      );
      expect(result.first.id, 'b');
    });

    test('price low to high', () {
      final List<Place> result = applyFilters(
        fixtures,
        const SearchFilters(sortBy: SortOption.priceLowToHigh),
      );
      expect(result.map((Place p) => p.id), <String>['a', 'b', 'c']);
    });
  });

  group('filter reset', () {
    test('cleared() restores the default state', () {
      const SearchFilters busy = SearchFilters(
        keyword: 'fort',
        categories: <PlaceCategory>{PlaceCategory.heritage},
        dietary: <DietaryPreference>{DietaryPreference.vegetarian},
        maxDistanceKm: 2,
        openNowOnly: true,
        sortBy: SortOption.rating,
      );

      expect(busy.isEmpty, isFalse);
      expect(busy.cleared(), const SearchFilters());
      expect(busy.cleared().isEmpty, isTrue);
    });

    test('reset brings back every result', () {
      const SearchFilters narrow = SearchFilters(keyword: 'zzzzz');
      expect(applyFilters(fixtures, narrow), isEmpty);
      expect(applyFilters(fixtures, narrow.cleared()), hasLength(3));
    });

    test('activeCount reflects how many filters are narrowing results', () {
      const SearchFilters filters = SearchFilters(
        keyword: 'fort',
        categories: <PlaceCategory>{
          PlaceCategory.heritage,
          PlaceCategory.museum,
        },
        dietary: <DietaryPreference>{DietaryPreference.vegetarian},
        openNowOnly: true,
      );
      // 1 keyword + 2 categories + 1 dietary + 1 open-now
      expect(filters.activeCount, 5);
      expect(const SearchFilters().activeCount, 0);
    });

    test('equal filters compare equal, so no redundant refetch fires', () {
      const SearchFilters a = SearchFilters(
        keyword: 'nasi',
        categories: <PlaceCategory>{PlaceCategory.food, PlaceCategory.nature},
      );
      const SearchFilters b = SearchFilters(
        keyword: 'nasi',
        // Same set, different insertion order.
        categories: <PlaceCategory>{PlaceCategory.nature, PlaceCategory.food},
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('display helpers', () {
    test('review counts get thousands separators', () {
      expect(fixtures[1].reviewCountLabel, '2,340');
    });

    test('distance label is one decimal place', () {
      expect(fixtures[0].distanceLabel, '0.3 km');
    });

    test('opening hours render as a 12-hour range', () {
      expect(dayHours.displayRange, '8:00 AM - 7:00 PM');
    });
  });
}