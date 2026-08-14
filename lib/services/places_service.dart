import '../models/lat_lng.dart';
import '../models/place_model.dart';
import 'map_service.dart';

/// Fetches nearby food and attraction pins for UC-007 via the Places API
/// (New) `searchNearby` endpoint. Not one of the six named sub modules in
/// the design doc — split out here so [MapService] stays focused on the
/// HTTP plumbing shared with Directions and the navigation deep link.
class PlacesService {
  PlacesService(this._mapService);
  final MapService _mapService;

  /// Constraint C1 (UC-007): pins are limited to food establishments and
  /// tourist attractions.
  static const _includedTypes = [
    'restaurant',
    'cafe',
    'tourist_attraction',
    'museum',
    'park',
  ];

  /// UC-007 step 4 / A2: returns an empty list rather than throwing when
  /// nothing is nearby — the caller shows [MapErrorMessages.noPlacesFound].
  Future<List<PlaceModel>> fetchNearbyPlaces({
    required LatLng center,
    required double radiusKm,
  }) async {
    final uri = _mapService.buildPlacesNearbyRequest();
    final body = {
      'includedTypes': _includedTypes,
      'maxResultCount': 20,
      'locationRestriction': {
        'circle': {
          'center': {
            'latitude': center.latitude,
            'longitude': center.longitude,
          },
          'radius': radiusKm * 1000,
        },
      },
    };

    final json = await _mapService.sendPlacesRequest(uri, body);
    final places = json['places'] as List<dynamic>?;
    if (places == null) return [];

    return places.cast<Map<String, dynamic>>().map(PlaceModel.fromJson).toList();
  }
}
