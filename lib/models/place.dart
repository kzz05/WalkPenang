import 'package:flutter/foundation.dart';

/// Dietary preferences a place can satisfy (T-FD01.2).
enum DietaryPreference {
  halal('Halal'),
  vegetarian('Vegetarian'),
  vegan('Vegan'),
  noPork('No pork'),
  noBeef('No beef');

  const DietaryPreference(this.label);

  final String label;
}

/// Coarse price bands. Kept as an enum rather than a raw number so the UI and
/// the filter logic can't disagree about what "cheap" means.
enum PriceLevel {
  budget(1, 'Budget'),
  moderate(2, 'Moderate'),
  premium(3, 'Premium');

  const PriceLevel(this.value, this.label);

  final int value;
  final String label;

  /// 'RM', 'RMRM', 'RMRMRM' — for compact display on cards.
  String get symbol => List<String>.filled(value, 'RM').join();
}

/// How the filtered results are ordered (T-FD01.2).
enum SortOption {
  relevance('Relevance'),
  distance('Nearest first'),
  rating('Top rated'),
  priceLowToHigh('Price: low to high');

  const SortOption(this.label);

  final String label;
}

/// A single food spot or attraction in the discovery feed.
@immutable
class Place {
  const Place({
    required this.id,
    required this.name,
    required this.category,
    required this.imageUrl,
    required this.priceLevel,
    required this.distanceKm,
    required this.rating,
    this.dietaryTags = const <DietaryPreference>{},
    this.description = '',
  });

  final String id;
  final String name;

  /// Matches the chip labels in [kDiscoveryCategories].
  final String category;
  final String imageUrl;
  final PriceLevel priceLevel;
  final double distanceKm;
  final double rating;
  final Set<DietaryPreference> dietaryTags;
  final String description;

  /// Everything the keyword search looks through, lowercased once.
  String get searchableText =>
      '$name $category $description'.toLowerCase();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Place && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Place($id, $name)';
}