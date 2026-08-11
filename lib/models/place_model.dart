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

  PlaceModel({
    required this.placeId,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.rating,
    this.address,
    this.isOpenNow = false,
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
  ///   "currentOpeningHours": { "openNow": true }
  /// }
  /// ```
  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>? ?? const {};
    final displayName = json['displayName'] as Map<String, dynamic>?;
    final openingHours = json['currentOpeningHours'] as Map<String, dynamic>?;
    final types = (json['types'] as List<dynamic>?)?.cast<String>() ?? const [];

    return PlaceModel(
      placeId: json['id'] as String? ?? '',
      name: displayName?['text'] as String? ?? 'Unknown place',
      category: _categoryFromTypes(types),
      latitude: (location['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (location['longitude'] as num?)?.toDouble() ?? 0.0,
      rating: (json['rating'] as num?)?.toDouble(),
      address: json['formattedAddress'] as String?,
      isOpenNow: openingHours?['openNow'] as bool? ?? false,
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
