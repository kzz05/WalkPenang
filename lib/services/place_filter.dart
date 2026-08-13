import 'package:walkpenang/models/place.dart';
import 'package:walkpenang/models/search_filters.dart';

/// T-FD01.2 — applies every active filter, then sorts.
///
/// Pure function: same input always gives the same output. No widgets, no
/// network. [now] is injected rather than read from the clock so the
/// open-now filter is testable.
List<Place> applyFilters(
    List<Place> places,
    SearchFilters filters, {
      DateTime? now,
    }) {
  final String query = filters.keyword.trim().toLowerCase();
  final DateTime clock = now ?? DateTime.now();

  final List<Place> matches = places.where((Place place) {
    if (!_matchesKeyword(place, query)) return false;
    if (!_matchesCategory(place, filters)) return false;
    if (!_matchesDietary(place, filters)) return false;
    if (!_matchesPrice(place, filters)) return false;
    if (place.distanceKm > filters.maxDistanceKm) return false;
    if (filters.openNowOnly && !place.isOpenAt(clock)) return false;
    return true;
  }).toList();

  return sortPlaces(matches, filters);
}

bool _matchesKeyword(Place place, String query) {
  if (query.isEmpty) return true;
  // Every term must appear, so "nasi kandar" doesn't match a place that
  // only mentions "nasi".
  return query
      .split(RegExp(r'\s+'))
      .every((String term) => place.searchableText.contains(term));
}

bool _matchesCategory(Place place, SearchFilters filters) {
  // No chips selected means "All", not "nothing".
  if (filters.categories.isEmpty) return true;
  return filters.categories.contains(place.category);
}

bool _matchesDietary(Place place, SearchFilters filters) {
  if (filters.dietary.isEmpty) return true;
  // AND, not OR: Halal + Vegetarian must both be satisfied.
  return place.dietaryTags.containsAll(filters.dietary);
}

bool _matchesPrice(Place place, SearchFilters filters) {
  final int level = place.priceLevel.value;
  return level >= filters.minPriceLevel.value &&
      level <= filters.maxPriceLevel.value;
}

List<Place> sortPlaces(List<Place> places, SearchFilters filters) {
  final List<Place> sorted = List<Place>.of(places);

  switch (filters.sortBy) {
    case SortOption.relevance:
    // With a keyword, a name match outranks a description match; ties break
    // on rating. Without one, the backend's own order is the relevance.
      if (filters.keyword.trim().isEmpty) return sorted;
      final String query = filters.keyword.trim().toLowerCase();
      sorted.sort((Place a, Place b) {
        final int score = _relevanceScore(b, query) - _relevanceScore(a, query);
        if (score != 0) return score;
        return b.rating.compareTo(a.rating);
      });
    case SortOption.distance:
      sorted.sort((Place a, Place b) => a.distanceKm.compareTo(b.distanceKm));
    case SortOption.rating:
      sorted.sort((Place a, Place b) => b.rating.compareTo(a.rating));
    case SortOption.priceLowToHigh:
      sorted.sort((Place a, Place b) {
        final int byPrice = a.priceLevel.value.compareTo(b.priceLevel.value);
        return byPrice != 0 ? byPrice : a.distanceKm.compareTo(b.distanceKm);
      });
  }

  return sorted;
}

int _relevanceScore(Place place, String query) {
  final String name = place.name.toLowerCase();
  if (name == query) return 3;
  if (name.startsWith(query)) return 2;
  if (name.contains(query)) return 1;
  return 0;
}
