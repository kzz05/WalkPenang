import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:walkpenang/services/place_repository.dart';

/// Fixed search center for the app: George Town, Penang.
const double kPenangCenterLat = 5.4141;
const double kPenangCenterLng = 100.3288;
const double kPenangSearchRadiusMeters = 15000;

const String _kFieldMask = 'places.id,places.displayName,'
    'places.formattedAddress,places.location,places.rating,'
    'places.userRatingCount,places.priceLevel,places.priceRange,'
    'places.regularOpeningHours,places.internationalPhoneNumber,'
    'places.websiteUri,places.photos,places.types,places.primaryType,'
    'places.servesVegetarianFood,places.editorialSummary';

class GooglePlacesSearchResult {
  const GooglePlacesSearchResult({required this.places, this.nextPageToken});

  final List<Map<String, dynamic>> places;
  final String? nextPageToken;
}

/// Thin wrapper around Places API (New) — the only Google-specific code in
/// the app. Everything else talks to [Map]s / [Place] so a future API
/// version swap stays contained here.
class GooglePlacesService {
  GooglePlacesService({http.Client? client}) : _client = client ?? http.Client();

  static const String _baseUrl = 'https://places.googleapis.com/v1';

  final http.Client _client;

  String get _apiKey => dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '';

  Map<String, String> get _headers => <String, String>{
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,
        'X-Goog-FieldMask': _kFieldMask,
      };

  Map<String, dynamic> get _locationBias => <String, dynamic>{
        'circle': <String, dynamic>{
          'center': <String, double>{
            'latitude': kPenangCenterLat,
            'longitude': kPenangCenterLng,
          },
          'radius': kPenangSearchRadiusMeters,
        },
      };

  /// Places around Penang matching [includedTypes]. Nearby Search (New)
  /// caps out at 20 results and has no pagination token.
  Future<List<Map<String, dynamic>>> searchNearby({
    required List<String> includedTypes,
    int maxResultCount = 20,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'includedTypes': includedTypes,
      'maxResultCount': maxResultCount,
      'locationRestriction': <String, dynamic>{'circle': _locationBias['circle']},
    };

    final Map<String, dynamic> json = await _post('places:searchNearby', body);
    return (json['places'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
  }

  /// Text search around Penang, e.g. for the search bar. Supports paging
  /// through [pageToken] chaining (T-FD-google: up to 20 results per call).
  Future<GooglePlacesSearchResult> searchText({
    required String textQuery,
    String? includedType,
    String? pageToken,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'textQuery': textQuery,
      'locationBias': _locationBias,
      if (includedType != null) 'includedType': includedType,
      if (pageToken != null) 'pageToken': pageToken,
    };

    final Map<String, dynamic> json = await _post('places:searchText', body);
    return GooglePlacesSearchResult(
      places: (json['places'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          const <Map<String, dynamic>>[],
      nextPageToken: json['nextPageToken'] as String?,
    );
  }

  /// Up to 5 of Google's own reviews for a place, via Place Details (New).
  Future<List<Map<String, dynamic>>> getReviews(String placeId) async {
    final http.Response response = await _client
        .get(
          Uri.parse('$_baseUrl/places/$placeId'),
          headers: <String, String>{
            'X-Goog-Api-Key': _apiKey,
            'X-Goog-FieldMask': 'id,reviews',
          },
        )
        .timeout(
          kRequestTimeout,
          onTimeout: () => throw const ApiTimeoutException(),
        );

    if (response.statusCode != 200) {
      throw const ApiFailureException();
    }

    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;
    return (json['reviews'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
  }

  /// Media URL for a photo resource name (e.g. "places/xyz/photos/abc").
  /// The Places Photo (New) endpoint 302-redirects to the actual image,
  /// which CachedNetworkImage follows natively.
  String photoUrl(String photoName, {int maxWidthPx = 800}) {
    return '$_baseUrl/$photoName/media'
        '?maxWidthPx=$maxWidthPx&key=$_apiKey';
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final http.Response response = await _client
        .post(
          Uri.parse('$_baseUrl/$path'),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(
          kRequestTimeout,
          onTimeout: () => throw const ApiTimeoutException(),
        );

    if (response.statusCode != 200) {
      throw const ApiFailureException();
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
