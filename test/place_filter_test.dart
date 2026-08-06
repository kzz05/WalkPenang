import 'package:flutter_test/flutter_test.dart';

import 'package:walk_penang/models/place.dart';
import 'package:walk_penang/models/search_filters.dart';
import 'package:walk_penang/services/place_filter.dart';

/// T-FD01.3 — keyword queries, zero-result states, filter reset.
void main() {
  final List<Place> fixtures = <Place>[
    const Place(
      id: 'a',
      name: 'Nasi Kandar Line Clear',
      category: 'Street Food',
      imageUrl: '',
      priceLevel: PriceLevel.budget,
      distanceKm: 0.8,
      rating: 4.3,
      dietaryTags: <DietaryPreference>{
        DietaryPreference.halal,
        DietaryPreference.noPork,
      },
      description: 'Late-night nasi kandar off Penang Road.',
    ),
    const Place(
      id: 'b',
      name: 'China House',
      category: 'Cafe',
      imageUrl: '',
      priceLevel: PriceLevel.moderate,
      distanceKm: 1.1,
      rating: 4.4,
      dietaryTags: <DietaryPreference>{DietaryPreference.vegetarian},
      description: 'Shophouse cafe with a long cake counter.',
    ),
    const Place(
      id: 'c',
      name: 'Kebaya Dining Room',
      category: 'Cafe',
      imageUrl: '',
      priceLevel: PriceLevel.premium,
      distanceKm: 14.0,
      rating: 4.8,
      description: 'Tasting-menu Nyonya cooking.',
    ),
  ];

  group('keyword search', () {
    test('empty keyword returns everything', () {
      final List<Place> result =
      applyFilters(fixtures, const SearchFilters());
      expect(result, hasLength(3));
    });

    test('matches on name, case-insensitively', () {
      final List<Place> result =
      applyFilters(fixtures, const SearchFilters(keyword: 'china'));
      expect(result.single.id, 'b');
    });

    test('matches on description as well as name', () {
      final List<Place> result =
      applyFilters(fixtures, const SearchFilters(keyword: 'shophouse'));
      expect(result.single.id, 'b');
    });

    test('all terms must match, not just one', () {
      // "nasi" alone hits place a; "nasi sushi" should hit nothing.
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
      applyFilters(fixtures, const SearchFilters(keyword: '  kebaya  '));
      expect(result.single.id, 'c');
    });
  });

  group('zero-result states', () {
    test('unmatched keyword yields an empty list, not an error', () {
      final List<Place> result = applyFilters(
        fixtures,
        const SearchFilters(keyword: 'zzzzz'),
      );
      expect(result, isEmpty);
    });

    test('impossible filter combination yields empty', () {
      // Premium price but within 1km — nothing in the fixture satisfies both.
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

  group('dietary, price and distance', () {
    test('dietary filter is AND, not OR', () {
      final List<Place> halal = applyFilters(
        fixtures,
        const SearchFilters(dietary: <DietaryPreference>{
          DietaryPreference.halal,
          DietaryPreference.noPork,
        }),
      );
      expect(halal.single.id, 'a');
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
      applyFilters(fixtures, const SearchFilters(maxDistanceKm: 2.0));
      expect(result.map((Place p) => p.id), <String>['a', 'b']);
    });

    test('category filter with no chips selected shows everything', () {
      final List<Place> result = applyFilters(
        fixtures,
        const SearchFilters(categories: <String>{}),
      );
      expect(result, hasLength(3));
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
      expect(result.first.id, 'c');
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
        keyword: 'cafe',
        categories: <String>{'Cafe'},
        dietary: <DietaryPreference>{DietaryPreference.vegetarian},
        maxDistanceKm: 2,
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
        keyword: 'cafe',
        categories: <String>{'Cafe', 'Heritage'},
        dietary: <DietaryPreference>{DietaryPreference.vegetarian},
      );
      // 1 keyword + 2 categories + 1 dietary
      expect(filters.activeCount, 4);
      expect(const SearchFilters().activeCount, 0);
    });

    test('equal filters compare equal, so no redundant refetch is triggered',
            () {
          const SearchFilters a = SearchFilters(
            keyword: 'nasi',
            categories: <String>{'Cafe', 'Heritage'},
          );
          const SearchFilters b = SearchFilters(
            keyword: 'nasi',
            // Same set, different insertion order.
            categories: <String>{'Heritage', 'Cafe'},
          );
          expect(a, b);
          expect(a.hashCode, b.hashCode);
        });
  });
}
