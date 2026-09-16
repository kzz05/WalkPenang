/// A single nearby place pin (UC-007). Parsed from a Places API (New)
/// `searchNearby` result — see PlacesService.fetchNearbyPlaces.
class PlaceModel {
  final String placeId;
  final String name;
  final String category; // 'food' | 'attraction' | 'other'
  final double latitude;
  final double longitude;
  final double? rating;
  final String? address;
  final bool isOpenNow;

  /// A loadable URL for this place's primary (first) Google photo, or null
  /// when the listing has none. Carried so the Walking module's Journey
  /// Preview can show a destination cover image without issuing a second
  /// Places request of its own — the nearby search that produced this pin
  /// already returned the photo reference.
  final String? photoUrl;

  PlaceModel({
    required this.placeId,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.rating,
    this.address,
    this.isOpenNow = false,
    this.photoUrl,
  });

  /// `json` is one entry from the New Places API's `places[]` array, e.g.:
  /// ```json
  /// {
  ///   "id": "ChIJ...",
  ///   "displayName": { "text": "Kek Lok Si Temple" },
  ///   "formattedAddress": "...",
  ///   "location": { "latitude": 5.399, "longitude": 100.274 },
  ///   "rating": 4.5,
  ///   "types": ["tourist_attraction"],
  ///   "currentOpeningHours": { "openNow": true },
  ///   "photos": [ { "name": "places/ChIJ.../photos/AXQ..." } ]
  /// }
  /// ```
  ///
  /// [photoUrlBuilder] turns a photo resource name into a loadable media URL
  /// — a callback rather than a MapService dependency so this model stays
  /// free of API-key/HTTP concerns, matching how the Discovery module's
  /// [Place.fromGooglePlace] handles the same field. Omitted (or returning
  /// null) leaves [photoUrl] null and the UI falls back to a placeholder.
  factory PlaceModel.fromJson(
    Map<String, dynamic> json, {
    String Function(String photoName)? photoUrlBuilder,
  }) {
    final location = json['location'] as Map<String, dynamic>? ?? const {};
    final displayName = json['displayName'] as Map<String, dynamic>?;
    final openingHours = json['currentOpeningHours'] as Map<String, dynamic>?;
    final types = (json['types'] as List<dynamic>?)?.cast<String>() ?? const [];
    final photos = json['photos'] as List<dynamic>? ?? const [];
    final photoName = photos.isEmpty
        ? null
        : (photos.first as Map<String, dynamic>)['name'] as String?;

    return PlaceModel(
      placeId: json['id'] as String? ?? '',
      name: displayName?['text'] as String? ?? 'Unknown place',
      category: _categoryFromTypes(types),
      latitude: (location['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (location['longitude'] as num?)?.toDouble() ?? 0.0,
      rating: (json['rating'] as num?)?.toDouble(),
      address: json['formattedAddress'] as String?,
      isOpenNow: openingHours?['openNow'] as bool? ?? false,
      photoUrl: photoName == null || photoUrlBuilder == null
          ? null
          : photoUrlBuilder(photoName),
    );
  }

  static String _categoryFromTypes(List<String> types) {
    const foodTypes = {'restaurant', 'cafe', 'food', 'bakery', 'bar'};
    const attractionTypes = {
      'tourist_attraction',
      'museum',
      'park',
      'place_of_worship',
      'art_gallery',
    };

    if (types.any(foodTypes.contains)) return 'food';
    if (types.any(attractionTypes.contains)) return 'attraction';
    return 'other';
  }
}
