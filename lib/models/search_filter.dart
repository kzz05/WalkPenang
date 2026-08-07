import 'package:flutter/foundation.dart';

import 'package:walkpenang/models/place.dart';

/// Widest distance the slider allows. Doubles as "no distance filter".
const double kMaxDistanceKm = 25.0;

/// An immutable snapshot of everything the user is filtering by.
///
/// Immutability is what makes T-FD01.3 easy: a filter run is a pure function
/// of this object, so tests never need to pump a widget.
@immutable
class SearchFilters {
  const SearchFilters({
    this.keyword = '',
    this.categories = const <String>{},
    this.dietary = const <DietaryPreference>{},
    this.minPriceLevel = PriceLevel.budget,
    this.maxPriceLevel = PriceLevel.premium,
    this.maxDistanceKm = kMaxDistanceKm,
    this.sortBy = SortOption.relevance,
  });

  final String keyword;
  final Set<String> categories;
  final Set<DietaryPreference> dietary;
  final PriceLevel minPriceLevel;
  final PriceLevel maxPriceLevel;
  final double maxDistanceKm;
  final SortOption sortBy;

  /// True when nothing is narrowing the results down.
  bool get isEmpty =>
      keyword.isEmpty &&
          categories.isEmpty &&
          dietary.isEmpty &&
          minPriceLevel == PriceLevel.budget &&
          maxPriceLevel == PriceLevel.premium &&
          maxDistanceKm >= kMaxDistanceKm &&
          sortBy == SortOption.relevance;

  /// How many filters to show on the "Filters (n)" badge. Sort isn't counted —
  /// it reorders results rather than removing any.
  int get activeCount {
    int count = 0;
    if (keyword.isNotEmpty) count++;
    count += categories.length;
    count += dietary.length;
    if (minPriceLevel != PriceLevel.budget ||
        maxPriceLevel != PriceLevel.premium) {
      count++;
    }
    if (maxDistanceKm < kMaxDistanceKm) count++;
    return count;
  }

  SearchFilters copyWith({
    String? keyword,
    Set<String>? categories,
    Set<DietaryPreference>? dietary,
    PriceLevel? minPriceLevel,
    PriceLevel? maxPriceLevel,
    double? maxDistanceKm,
    SortOption? sortBy,
  }) {
    return SearchFilters(
      keyword: keyword ?? this.keyword,
      categories: categories ?? this.categories,
      dietary: dietary ?? this.dietary,
      minPriceLevel: minPriceLevel ?? this.minPriceLevel,
      maxPriceLevel: maxPriceLevel ?? this.maxPriceLevel,
      maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  /// Full reset, used by the "Clear filters" action (T-FD01.3).
  SearchFilters cleared() => const SearchFilters();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchFilters &&
        other.keyword == keyword &&
        setEquals(other.categories, categories) &&
        setEquals(other.dietary, dietary) &&
        other.minPriceLevel == minPriceLevel &&
        other.maxPriceLevel == maxPriceLevel &&
        other.maxDistanceKm == maxDistanceKm &&
        other.sortBy == sortBy;
  }

  @override
  int get hashCode => Object.hash(
    keyword,
    Object.hashAllUnordered(categories),
    Object.hashAllUnordered(dietary),
    minPriceLevel,
    maxPriceLevel,
    maxDistanceKm,
    sortBy,
  );

  @override
  String toString() => 'SearchFilters(keyword: "$keyword", '
      'categories: $categories, dietary: $dietary, '
      'price: ${minPriceLevel.label}-${maxPriceLevel.label}, '
      'maxDistance: ${maxDistanceKm}km, sort: ${sortBy.label})';
}