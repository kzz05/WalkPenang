import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// Thrown when a Google Maps API call fails outright (UC-M06 A1).
class MapServiceException implements Exception {
  final String message;
  MapServiceException(this.message);

  @override
  String toString() => message;
}

/// Map Service Sub Module (UC-M06). The single place that talks to Google's
/// HTTP APIs — Route Calculation (UC-M04) builds its requests here rather
/// than calling `http` directly; UC-M05's in-app navigation reuses whatever
/// route UC-M04 already fetched instead of calling this service again.
class MapService {
  static String get _apiKey => dotenv.env['MAPS_API_KEY'] ?? '';

  /// UC-M06 steps 3-4 / A1: sends a GET request and decodes the JSON body.
  Future<Map<String, dynamic>> sendAPIRequest(Uri uri) async {
    try {
      final response =
          await http.get(uri).timeout(const Duration(seconds: 10));
      return handleAPIResponse(response);
    } on MapServiceException {
      rethrow;
    } catch (e) {
      return handleAPIError(e);
    }
  }

  /// The New Places API only accepts POST — this is the request/response
  /// path [PlacesService] calls into.
  Future<Map<String, dynamic>> sendPlacesRequest(
    Uri uri,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
          .post(uri, headers: placesNearbyHeaders, body: jsonEncode(body))
          .timeout(const Duration(seconds: 10));
      return handleAPIResponse(response);
    } on MapServiceException {
      rethrow;
    } catch (e) {
      return handleAPIError(e);
    }
  }

  /// UC-M06 step 4 / A2: a non-200 response is an outright failure (A1); a
  /// 200 whose body isn't a JSON object is treated as the empty-response
  /// case (A2) so callers only need one empty-state check.
  Map<String, dynamic> handleAPIResponse(http.Response response) {
    if (response.statusCode != 200) {
      throw MapServiceException(
        'Google Maps API returned status ${response.statusCode}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return {};
    return decoded;
  }

  /// UC-M06 A1: normalises anything thrown while sending the request (no
  /// connection, timeout, malformed JSON) into one exception type.
  Never handleAPIError(Object error) {
    throw MapServiceException('Unable to reach Google Maps API: $error');
  }

  /// UC-M04: Directions API request for the given travel mode (`walking`,
  /// `driving`, or `transit` — see `TransportMode.apiValue`).
  Uri buildDirectionsRequest({
    required LatLng origin,
    required LatLng destination,
    required String mode,
  }) {
    final params = {
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'mode': mode,
      'key': _apiKey,
    };
    // Transit schedules depend on when the trip starts; Google recommends
    // an explicit departure_time for accurate results rather than relying
    // on its undocumented "now" default.
    if (mode == 'transit') {
      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      params['departure_time'] = '$nowSeconds';
    }
    return Uri.https('maps.googleapis.com', '/maps/api/directions/json', params);
  }

  /// UC-007: base endpoint for a Places API (New) `searchNearby` call. The
  /// actual search parameters go in the POST body built by [PlacesService].
  /// UC-M06 / UC-M05: the Google Maps walking deep link. Still used by the
  /// Walking & Carbon module's journey flow, which hands the tourist off to
  /// the Google Maps app; the Map module's own UC-M05 now navigates in-app
  /// via NavigationView instead.
  Uri buildDeepLinkRequest(LatLng destination) {
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${destination.latitude},${destination.longitude}',
      'travelmode': 'walking',
    });
  }

  Uri buildPlacesNearbyRequest() =>
      Uri.https('places.googleapis.com', '/v1/places:searchNearby');

  /// UC-007: media URL for a photo resource name returned by
  /// [buildPlacesNearbyRequest] (e.g. "places/xyz/photos/abc"). Same Places
  /// Photo (New) endpoint the Discovery module already uses
  /// (GooglePlacesService.photoUrl), keyed with this module's own
  /// MAPS_API_KEY — the key that just fetched the place — rather than
  /// reaching across modules for a second key that may not be configured.
  /// The endpoint 302-redirects to the image, which CachedNetworkImage
  /// follows natively.
  String buildPlacePhotoUrl(String photoName, {int maxWidthPx = 800}) {
    return 'https://places.googleapis.com/v1/$photoName/media'
        '?maxWidthPx=$maxWidthPx&key=$_apiKey';
  }

  /// Field mask keeps the response to only what [PlaceModel.fromJson] reads
  /// — the New Places API bills partly by field mask size, so an
  /// unnecessarily wide mask isn't just slower, it costs more.
  Map<String, String> get placesNearbyHeaders => {
    'Content-Type': 'application/json',
    'X-Goog-Api-Key': _apiKey,
    'X-Goog-FieldMask':
        'places.id,places.displayName,places.formattedAddress,'
        'places.location,places.rating,places.types,'
        'places.currentOpeningHours.openNow,places.photos',
  };
}
