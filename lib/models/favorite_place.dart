import 'package:flutter/foundation.dart';

import 'package:walkpenang/models/place.dart';
import 'package:walkpenang/models/place_model.dart';

/// One saved place, as it is stored on disk and rendered in the Favorites list.
///
/// Deliberately a small snapshot rather than a whole [Place]: favourites are
/// saved from two different screens (the Discovery grid, which has [Place]s,
/// and the Home map carousel, which has [PlaceModel]s) and must survive an app
/// restart with no feed loaded. Storing just what the list tile needs keeps one
/// shape for both sources and makes the persisted payload stable.
///
/// The Favorites list count is `favorites.length` of these — never a separate
/// id set — so the header can never disagree with the rows.
@immutable
class FavoritePlace {
  const FavoritePlace({
    required this.id,
    required this.name,
    required this.category,
    required this.savedAt,
    this.latitude,
    this.longitude,
    this.photoUrl,
    this.rating,
    this.address,
  });

  /// Google place id — the same string in [Place.id] and [PlaceModel.placeId],
  /// which is what makes favouriting work identically on every screen.
  final String id;
  final String name;

  /// Raw category token. 'food' | 'heritage' | 'nature' | 'museum' |
  /// 'shopping' (from [Place]) or 'food' | 'attraction' | 'other' (from
  /// [PlaceModel]). Kept as a string so both taxonomies round-trip.
  final String category;

  final DateTime savedAt;

  /// Only the map carousel supplies these today; [Place] carries no
  /// coordinates yet (that is Tier 2). Null when saved from the grid.
  final double? latitude;
  final double? longitude;

  final String? photoUrl;
  final double? rating;
  final String? address;

  String get categoryLabel {
    switch (category) {
      case 'food':
        return 'Food';
      case 'heritage':
        return 'Heritage';
      case 'nature':
        return 'Nature';
      case 'museum':
        return 'Museum';
      case 'shopping':
        return 'Shopping';
      case 'attraction':
        return 'Attraction';
      default:
        return 'Place';
    }
  }

  factory FavoritePlace.fromPlace(Place place, {DateTime? savedAt}) {
    return FavoritePlace(
      id: place.id,
      name: place.name,
      category: place.category.name,
      savedAt: savedAt ?? DateTime.now(),
      // Carried so a place saved from the Discovery grid is pinned on the map
      // too, not only one saved from the map's own carousel.
      latitude: place.latitude,
      longitude: place.longitude,
      photoUrl: place.photoUrls.isEmpty ? null : place.photoUrls.first,
      rating: place.rating,
      address: place.address,
    );
  }

  factory FavoritePlace.fromPlaceModel(PlaceModel place, {DateTime? savedAt}) {
    return FavoritePlace(
      id: place.placeId,
      name: place.name,
      category: place.category,
      savedAt: savedAt ?? DateTime.now(),
      latitude: place.latitude,
      longitude: place.longitude,
      rating: place.rating,
      address: place.address,
      photoUrl: place.photoUrl,
    );
  }

  /// A map pin for this favourite, so it can be shown wherever it is rather
  /// than only when a nearby search happens to return it.
  ///
  /// Null when the favourite has no coordinates: a listing that arrived
  /// without a location, or one saved before favourites started recording
  /// where they are — those backfill by being re-toggled. The caller drops the
  /// nulls rather than guessing a position, because a pin in the wrong place
  /// is worse than no pin.
  PlaceModel? toPlaceModel() {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) return null;

    return PlaceModel(
      placeId: id,
      name: name,
      // PlaceModel's own taxonomy is 'food' | 'attraction' | 'other', and
      // pinCategoryFor already falls back to `other` for the Discovery
      // tokens ('heritage', 'nature', ...) that do not appear in it.
      category: category,
      latitude: lat,
      longitude: lng,
      rating: rating,
      address: address,
      photoUrl: photoUrl,
      // Not stored with a favourite, and a stale "open now" would be a lie —
      // the card reads it as closed/unknown rather than claiming otherwise.
      isOpenNow: false,
    );
  }

  /// A minimal [Place] for opening the detail screen when the full object
  /// isn't in memory (e.g. a favourite tapped straight after a restart). The
  /// detail screen re-fetches reviews and rating live and guards every
  /// optional field, so the gaps here are cosmetic until it loads.
  Place toPlace() {
    return Place(
      id: id,
      name: name,
      category: _categoryEnum(category),
      latitude: latitude,
      longitude: longitude,
      priceLevel: PriceLevel.moderate,
      distanceKm: 0,
      rating: rating ?? 0,
      reviewCount: 0,
      address: address ?? '',
      photoUrls: photoUrl == null ? const <String>[] : <String>[photoUrl!],
    );
  }

  static PlaceCategory _categoryEnum(String token) {
    switch (token) {
      case 'heritage':
      case 'attraction':
        return PlaceCategory.heritage;
      case 'nature':
        return PlaceCategory.nature;
      case 'museum':
        return PlaceCategory.museum;
      case 'shopping':
      case 'other':
        return PlaceCategory.shopping;
      case 'food':
      default:
        return PlaceCategory.food;
    }
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'category': category,
      'savedAt': savedAt.toIso8601String(),
      'lat': latitude,
      'lng': longitude,
      'photoUrl': photoUrl,
      'rating': rating,
      'address': address,
    };
  }

  factory FavoritePlace.fromJson(Map<String, dynamic> json) {
    return FavoritePlace(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? 'food',
      savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      latitude: (json['lat'] as num?)?.toDouble(),
      longitude: (json['lng'] as num?)?.toDouble(),
      photoUrl: json['photoUrl'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      address: json['address'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is FavoritePlace && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
