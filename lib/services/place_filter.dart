import 'package:walkpenang/models/place.dart';
import 'package:walkpenang/models/search_filter.dart';

/// T-FD01.2 — applies every active filter, then sorts.
///
/// Pure function: same input always gives the same output, no widgets, no
/// network, no clock. That is what makes T-FD01.3 a set of fast unit tests.
List<Place> applyFilters(List<Place> places, SearchFilters filters) {
  final String query = filters.keyword.trim().toLowerCase();

  final List<Place> matches = places.where((Place place) {
    if (!_matchesKeyword(place, query)) return false;
    if (!_matchesCategory(place, filters)) return false;
    if (!_matchesDietary(place, filters)) return false;
    if (!_matchesPrice(place, filters)) return false;
    if (!_matchesDistance(place, filters)) return false;
    return true;
  }).toList();

  return sortPlaces(matches, filters);
}

bool _matchesKeyword(Place place, String query) {
  if (query.isEmpty) return true;
  // Every whitespace-separated term must appear, so "nasi kandar" doesn't
  // match a place that only mentions "nasi".
  return query
      .split(RegExp(r'\s+'))
      .every((String term) => place.searchableText.contains(term));
}

bool _matchesCategory(Place place, SearchFilters filters) {
  // No chips selected means "show everything", not "show nothing".
  if (filters.categories.isEmpty) return true;
  return filters.categories.contains(place.category);
}

bool _matchesDietary(Place place, SearchFilters filters) {
  if (filters.dietary.isEmpty) return true;
  // AND, not OR: picking Halal + Vegetarian means it must satisfy both.
  return place.dietaryTags.containsAll(filters.dietary);
}

bool _matchesPrice(Place place, SearchFilters filters) {
  final int level = place.priceLevel.value;
  return level >= filters.minPriceLevel.value &&
      level <= filters.maxPriceLevel.value;
}

bool _matchesDistance(Place place, SearchFilters filters) {
  return place.distanceKm <= filters.maxDistanceKm;
}

/// Sorting is split out so it can be tested and reused independently of the
/// narrowing step.
List<Place> sortPlaces(List<Place> places, SearchFilters filters) {
  final List<Place> sorted = List<Place>.of(places);

  switch (filters.sortBy) {
    case SortOption.relevance:
    // With a keyword, a name match outranks a description match; ties fall
    // back to rating. Without one, the backend's own order is the relevance.
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