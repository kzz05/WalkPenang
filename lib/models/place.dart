import 'dart:math' as math;

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
    this.latitude,
    this.longitude,
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

  /// Where this place is. Null only when a listing arrived without a location
  /// — every Places API result carries one, so in practice this is null only
  /// for the hand-built [Place]s in tests and for a favourite reconstructed
  /// from a pre-coordinate save.
  ///
  /// [distanceKm] was derived from these and then they were dropped, which is
  /// why a place favourited from the Discovery grid could not be pinned on the
  /// map: the position was known at parse time and thrown away.
  final double? latitude;
  final double? longitude;

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

  /// Maps a Places API (New) place resource (searchNearby/searchText result)
  /// into a [Place]. [photoUrlBuilder] turns a photo resource name like
  /// "places/xyz/photos/abc" into a loadable image URL — kept as a callback
  /// rather than a direct GooglePlacesService dependency so this model stays
  /// free of API/HTTP concerns.
  ///
  /// [originLat]/[originLng] are used to compute [distanceKm] since Places
  /// API (New) doesn't return distance directly.
  factory Place.fromGooglePlace(
    Map<String, dynamic> json, {
    required String Function(String photoName) photoUrlBuilder,
    required double originLat,
    required double originLng,
  }) {
    final Map<String, dynamic>? location =
        json['location'] as Map<String, dynamic>?;
    final double? placeLat = (location?['latitude'] as num?)?.toDouble();
    final double? placeLng = (location?['longitude'] as num?)?.toDouble();
    // Distance still falls back to the origin, so a listing with no location
    // reads as 0 km away rather than as an error.
    final double lat = placeLat ?? originLat;
    final double lng = placeLng ?? originLng;

    final List<String> types = (json['types'] as List<dynamic>?)
            ?.map((dynamic e) => e as String)
            .toList() ??
        const <String>[];
    final String primaryType = json['primaryType'] as String? ?? '';

    final List<dynamic> photos = json['photos'] as List<dynamic>? ?? const [];

    return Place(
      id: json['id'] as String? ?? '',
      name: (json['displayName'] as Map<String, dynamic>?)?['text']
              as String? ??
          '',
      category: _categoryFromGoogleTypes(<String>[primaryType, ...types]),
      photoUrls: photos
          .map((dynamic photo) => photoUrlBuilder(
              (photo as Map<String, dynamic>)['name'] as String))
          .toList(),
      priceLevel: _priceLevelFromGoogle(json['priceLevel'] as String?),
      distanceKm: _haversineKm(originLat, originLng, lat, lng),
      // The parsed position, not the origin-fallback the distance uses: a
      // listing with no location of its own must stay unpinned rather than be
      // drawn on top of the tourist.
      latitude: placeLat,
      longitude: placeLng,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (json['userRatingCount'] as num?)?.toInt() ?? 0,
      address: json['formattedAddress'] as String? ?? '',
      hours: _hoursFromGoogle(
          json['regularOpeningHours'] as Map<String, dynamic>?),
      contact: ContactInfo(
        phone: json['internationalPhoneNumber'] as String?,
        website: json['websiteUri'] as String?,
      ),
      priceRange: _priceRangeFromGoogle(json['priceRange'] as Map<String, dynamic>?),
      dietaryTags: json['servesVegetarianFood'] == true
          ? const <DietaryPreference>{DietaryPreference.vegetarian}
          : const <DietaryPreference>{},
      description: (json['editorialSummary']
              as Map<String, dynamic>?)?['text'] as String? ??
          '',
    );
  }

  static PlaceCategory _categoryFromGoogleTypes(List<String> types) {
    const Map<PlaceCategory, List<String>> byType = {
      PlaceCategory.food: [
        'restaurant', 'food', 'cafe', 'bakery', 'bar', 'meal_takeaway',
        'meal_delivery',
      ],
      PlaceCategory.museum: ['museum'],
      PlaceCategory.nature: [
        'park', 'natural_feature', 'hiking_area', 'national_park',
        'botanical_garden',
      ],
      PlaceCategory.heritage: [
        'tourist_attraction', 'place_of_worship', 'hindu_temple', 'church',
        'mosque', 'historical_landmark', 'cultural_landmark',
      ],
      PlaceCategory.shopping: [
        'shopping_mall', 'store', 'clothing_store', 'shoe_store',
        'jewelry_store', 'department_store',
      ],
    };

    for (final String type in types) {
      for (final MapEntry<PlaceCategory, List<String>> entry in byType.entries) {
        if (entry.value.contains(type)) return entry.key;
      }
    }
    return PlaceCategory.food;
  }

  static PriceLevel _priceLevelFromGoogle(String? level) {
    switch (level) {
      case 'PRICE_LEVEL_FREE':
      case 'PRICE_LEVEL_INEXPENSIVE':
        return PriceLevel.budget;
      case 'PRICE_LEVEL_EXPENSIVE':
      case 'PRICE_LEVEL_VERY_EXPENSIVE':
        return PriceLevel.premium;
      case 'PRICE_LEVEL_MODERATE':
      default:
        return PriceLevel.moderate;
    }
  }

  static PriceRange? _priceRangeFromGoogle(Map<String, dynamic>? priceRange) {
    if (priceRange == null) return null;
    final Map<String, dynamic>? start =
        priceRange['startPrice'] as Map<String, dynamic>?;
    final Map<String, dynamic>? end =
        priceRange['endPrice'] as Map<String, dynamic>?;
    if (start?['currencyCode'] != 'MYR' || end?['currencyCode'] != 'MYR') {
      return null;
    }
    final int? minRm = int.tryParse('${start?['units'] ?? ''}');
    final int? maxRm = int.tryParse('${end?['units'] ?? ''}');
    if (minRm == null || maxRm == null) return null;
    return PriceRange(minRm: minRm, maxRm: maxRm);
  }

  /// Picks today's opening period if published, else the first one, and
  /// rounds to the hour — [OpeningHours] only stores hour granularity.
  static OpeningHours? _hoursFromGoogle(Map<String, dynamic>? regularHours) {
    final List<dynamic>? periods = regularHours?['periods'] as List<dynamic>?;
    if (periods == null || periods.isEmpty) return null;

    final int today = DateTime.now().weekday % 7; // Google: 0=Sunday
    Map<String, dynamic> period = (periods.first as Map<String, dynamic>);
    for (final dynamic candidate in periods) {
      final Map<String, dynamic> map = candidate as Map<String, dynamic>;
      final int? openDay = (map['open'] as Map<String, dynamic>?)?['day'] as int?;
      if (openDay == today) {
        period = map;
        break;
      }
    }

    final Map<String, dynamic>? open = period['open'] as Map<String, dynamic>?;
    final Map<String, dynamic>? close = period['close'] as Map<String, dynamic>?;
    final int? opensAtHour = open?['hour'] as int?;
    final int? closesAtHour = close?['hour'] as int?;
    if (opensAtHour == null || closesAtHour == null) return null;

    return OpeningHours(opensAtHour: opensAtHour, closesAtHour: closesAtHour);
  }

  static double _haversineKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadiusKm = 6371;
    final double dLat = _degToRad(lat2 - lat1);
    final double dLng = _degToRad(lng2 - lng1);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180);

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