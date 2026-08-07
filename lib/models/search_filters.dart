import 'package:flutter/foundation.dart';

import 'package:walkpenang/models/place.dart';

const double kMaxDistanceKm = 25.0;

/// Immutable snapshot of everything the user is filtering by.
///
/// Pure data, so T-FD01.3 can test filtering without pumping a widget.
@immutable
class SearchFilters {
  const SearchFilters({
    this.keyword = '',
    this.categories = const <PlaceCategory>{},
    this.dietary = const <DietaryPreference>{},
    this.minPriceLevel = PriceLevel.budget,
    this.maxPriceLevel = PriceLevel.premium,
    this.maxDistanceKm = kMaxDistanceKm,
    this.openNowOnly = false,
    this.sortBy = SortOption.relevance,
  });

  final String keyword;

  /// Empty means "All" — the first chip in the mockup.
  final Set<PlaceCategory> categories;
  final Set<DietaryPreference> dietary;
  final PriceLevel minPriceLevel;
  final PriceLevel maxPriceLevel;
  final double maxDistanceKm;
  final bool openNowOnly;
  final SortOption sortBy;

  bool get isEmpty =>
      keyword.isEmpty &&
          categories.isEmpty &&
          dietary.isEmpty &&
          minPriceLevel == PriceLevel.budget &&
          maxPriceLevel == PriceLevel.premium &&
          maxDistanceKm >= kMaxDistanceKm &&
          !openNowOnly &&
          sortBy == SortOption.relevance;

  /// Drives the badge on the filter button. Sort isn't counted — it reorders
  /// results rather than removing any.
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
    if (openNowOnly) count++;
    return count;
  }

  SearchFilters copyWith({
    String? keyword,
    Set<PlaceCategory>? categories,
    Set<DietaryPreference>? dietary,
    PriceLevel? minPriceLevel,
    PriceLevel? maxPriceLevel,
    double? maxDistanceKm,
    bool? openNowOnly,
    SortOption? sortBy,
  }) {
    return SearchFilters(
      keyword: keyword ?? this.keyword,
      categories: categories ?? this.categories,
      dietary: dietary ?? this.dietary,
      minPriceLevel: minPriceLevel ?? this.minPriceLevel,
      maxPriceLevel: maxPriceLevel ?? this.maxPriceLevel,
      maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
      openNowOnly: openNowOnly ?? this.openNowOnly,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  /// Full reset, used by "Clear filters" (T-FD01.3).
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
        other.openNowOnly == openNowOnly &&
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
    openNowOnly,
    sortBy,
  );

  @override
  String toString() => 'SearchFilters(keyword: "$keyword", '
      'categories: $categories, dietary: $dietary, '
      'price: ${minPriceLevel.label}-${maxPriceLevel.label}, '
      'maxDistance: ${maxDistanceKm}km, openNow: $openNowOnly, '
      'sort: ${sortBy.label})';
}
