import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;

import 'package:walkpenang/theme/app_theme.dart';

/// Categories as they appear in the mockups: short label on the chips,
/// long label in the filter sheet, uppercase on the card badge.
enum PlaceCategory {
  food('Food', 'Food & Dining', 'FOOD', AppColors.badgeFood),
  heritage(
      'Heritage', 'Heritage Sites', 'HERITAGE', AppColors.badgeHeritage),
  nature('Nature', 'Nature & Parks', 'NATURE', AppColors.badgeNature),
  museum('Museums', 'Museums', 'MUSEUM', AppColors.badgeMuseum),
  shopping('Shopping', 'Shopping', 'SHOPPING', AppColors.badgeShopping);

  const PlaceCategory(this.chipLabel, this.sheetLabel, this.badge, this.color);

  final String chipLabel;
  final String sheetLabel;
  final String badge;
  final Color color;
}

enum DietaryPreference {
  halal('Halal'),
  vegetarian('Vegetarian'),
  vegan('Vegan'),
  noPork('No pork'),
  noBeef('No beef');

  const DietaryPreference(this.label);

  final String label;
}

enum PriceLevel {
  budget(1, 'Budget'),
  moderate(2, 'Moderate'),
  premium(3, 'Premium');

  const PriceLevel(this.value, this.label);

  final int value;
  final String label;
}

enum SortOption {
  relevance('Relevance'),
  distance('Nearest first'),
  rating('Top rated'),
  priceLowToHigh('Price: low to high');

  const SortOption(this.label);

  final String label;
}

/// Opening hours for one place (T-FD03.2).
///
/// [closesAtHour] may be smaller than [opensAtHour] for places that trade past
/// midnight — 18:00 to 02:00, for example.
@immutable
class OpeningHours {
  const OpeningHours({required this.opensAtHour, required this.closesAtHour});

  final int opensAtHour;
  final int closesAtHour;

  bool isOpenAt(DateTime time) {
    final int hour = time.hour;
    if (closesAtHour > opensAtHour) {
      return hour >= opensAtHour && hour < closesAtHour;
    }
    // Wraps past midnight.
    return hour >= opensAtHour || hour < closesAtHour;
  }

  String get displayRange =>
      '${_format(opensAtHour)} - ${_format(closesAtHour)}';

  static String _format(int hour24) {
    final int normalized = hour24 % 24;
    final int hour12 = normalized % 12 == 0 ? 12 : normalized % 12;
    final String suffix = normalized < 12 ? 'AM' : 'PM';
    return '$hour12:00 $suffix';
  }
}

/// Contact details shown on the detail screen (T-FD03.1).
///
/// Every field is optional — real listings routinely lack a phone or website,
/// and the UI must cope rather than render an empty row.
@immutable
class ContactInfo {
  const ContactInfo({this.phone, this.website});

  final String? phone;
  final String? website;

  bool get isEmpty => (phone?.isEmpty ?? true) && (website?.isEmpty ?? true);
  bool get hasPhone => phone != null && phone!.isNotEmpty;
  bool get hasWebsite => website != null && website!.isNotEmpty;
}

/// A typical spend range, e.g. "RM 8 - RM 25 per person" (T-FD03.1).
@immutable
class PriceRange {
  const PriceRange({
    required this.minRm,
    required this.maxRm,
    this.unit = 'per person',
  });

  final int minRm;
  final int maxRm;
  final String unit;

  String get display => 'RM $minRm - RM $maxRm $unit';
}

@immutable
class Place {
  const Place({
    required this.id,
    required this.name,
    required this.category,
    required this.priceLevel,
    required this.distanceKm,
    required this.rating,
    required this.reviewCount,
    required this.address,
    this.photoUrls = const <String>[],
    this.hours,
    this.contact = const ContactInfo(),
    this.priceRange,
    this.dietaryTags = const <DietaryPreference>{},
    this.description = '',
  });

  final String id;
  final String name;
  final PlaceCategory category;

  /// Gallery for the detail carousel. May be empty — the UI shows a
  /// placeholder rather than a broken carousel (T-FD03.3).
  final List<String> photoUrls;

  final PriceLevel priceLevel;
  final double distanceKm;
  final double rating;
  final int reviewCount;
  final String address;

  /// Null when the listing has no published hours (T-FD03.3).
  final OpeningHours? hours;

  final ContactInfo contact;

  /// Null when the listing has no published price range (T-FD03.3).
  final PriceRange? priceRange;

  final Set<DietaryPreference> dietaryTags;
  final String description;

  /// First photo, used for the grid card. Empty string when there are none,
  /// which CachedNetworkImage turns into its errorWidget.
  String get imageUrl => photoUrls.isEmpty ? '' : photoUrls.first;

  bool get hasPhotos => photoUrls.isNotEmpty;
  bool get hasHours => hours != null;
  bool get hasDescription => description.trim().isNotEmpty;

  /// False when hours are unknown — callers should show "Hours not available"
  /// rather than claiming the place is closed.
  bool isOpenAt(DateTime time) => hours?.isOpenAt(time) ?? false;

  String get searchableText =>
      '$name ${category.sheetLabel} $description $address'.toLowerCase();

  String get distanceLabel => '${distanceKm.toStringAsFixed(1)} km';

  String get reviewCountLabel => formatCount(reviewCount);

  /// '2,340' — thousands separators without pulling in intl.
  static String formatCount(int value) {
    final String digits = value.toString();
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  /// Firestore document fields for the 'places' collection. The doc id
  /// itself carries [id], so it isn't repeated in the map.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category.name,
      'photoUrls': photoUrls,
      'priceLevel': priceLevel.name,
      'distanceKm': distanceKm,
      'rating': rating,
      'reviewCount': reviewCount,
      'address': address,
      'opensAtHour': hours?.opensAtHour,
      'closesAtHour': hours?.closesAtHour,
      'phone': contact.phone,
      'website': contact.website,
      'priceMinRm': priceRange?.minRm,
      'priceMaxRm': priceRange?.maxRm,
      'priceUnit': priceRange?.unit,
      'dietaryTags': dietaryTags.map((DietaryPreference d) => d.name).toList(),
      'description': description,
    };
  }

  /// Defensive parsing: an unrecognized enum name or a missing field falls
  /// back to a sane default rather than throwing, so one bad document
  /// doesn't take down the whole feed.
  factory Place.fromMap(String id, Map<String, dynamic> map) {
    final int? opensAtHour = (map['opensAtHour'] as num?)?.toInt();
    final int? closesAtHour = (map['closesAtHour'] as num?)?.toInt();
    final int? minRm = (map['priceMinRm'] as num?)?.toInt();
    final int? maxRm = (map['priceMaxRm'] as num?)?.toInt();

    return Place(
      id: id,
      name: map['name'] as String? ?? '',
      category: _categoryByName(map['category'] as String?),
      photoUrls: (map['photoUrls'] as List<dynamic>?)
          ?.map((dynamic e) => e as String)
          .toList() ??
          const <String>[],
      priceLevel: _priceLevelByName(map['priceLevel'] as String?),
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0.0,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      address: map['address'] as String? ?? '',
      hours: opensAtHour != null && closesAtHour != null
          ? OpeningHours(opensAtHour: opensAtHour, closesAtHour: closesAtHour)
          : null,
      contact: ContactInfo(
        phone: map['phone'] as String?,
        website: map['website'] as String?,
      ),
      priceRange: minRm != null && maxRm != null
          ? PriceRange(
        minRm: minRm,
        maxRm: maxRm,
        unit: map['priceUnit'] as String? ?? 'per person',
      )
          : null,
      dietaryTags: (map['dietaryTags'] as List<dynamic>?)
          ?.map((dynamic e) => _dietaryByName(e as String))
          .whereType<DietaryPreference>()
          .toSet() ??
          const <DietaryPreference>{},
      description: map['description'] as String? ?? '',
    );
  }

  static PlaceCategory _categoryByName(String? name) {
    return PlaceCategory.values.firstWhere(
          (PlaceCategory c) => c.name == name,
      orElse: () => PlaceCategory.food,
    );
  }

  static PriceLevel _priceLevelByName(String? name) {
    return PriceLevel.values.firstWhere(
          (PriceLevel p) => p.name == name,
      orElse: () => PriceLevel.moderate,
    );
  }

  static DietaryPreference? _dietaryByName(String name) {
    for (final DietaryPreference d in DietaryPreference.values) {
      if (d.name == name) return d;
    }
    return null;
  }

  Place copyWith({double? rating, int? reviewCount}) {
    return Place(
      id: id,
      name: name,
      category: category,
      photoUrls: photoUrls,
      priceLevel: priceLevel,
      distanceKm: distanceKm,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      address: address,
      hours: hours,
      contact: contact,
      priceRange: priceRange,
      dietaryTags: dietaryTags,
      description: description,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Place && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Place($id, $name)';
}