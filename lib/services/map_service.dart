import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/lat_lng.dart';

/// Thrown when a Google Maps API call fails outright (UC-M06 A1).
class MapServiceException implements Exception {
  final String message;
  MapServiceException(this.message);

  @override
  String toString() => message;
}

/// Map Service Sub Module (UC-M06). The single place that talks to Google's
/// HTTP APIs — Route Calculation (UC-M04) and Navigation Launcher (UC-M05)
/// both build their requests here rather than calling `http` directly.
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

  /// UC-M04: Directions API request, walking mode.
  Uri buildDirectionsRequest({
    required LatLng origin,
    required LatLng destination,
  }) {
    return Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'mode': 'walking',
      'key': _apiKey,
    });
  }

  /// UC-M05: Google Maps walking-navigation deep link. Destination only —
  /// Google Maps fills in the origin from the device's own location.
  Uri buildDeepLinkRequest(LatLng destination) {
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${destination.latitude},${destination.longitude}',
      'travelmode': 'walking',
    });
  }

  /// UC-007: base endpoint for a Places API (New) `searchNearby` call. The
  /// actual search parameters go in the POST body built by [PlacesService].
  Uri buildPlacesNearbyRequest() =>
      Uri.https('places.googleapis.com', '/v1/places:searchNearby');

  /// Field mask keeps the response to only what [PlaceModel.fromJson] reads
  /// — the New Places API bills partly by field mask size, so an
  /// unnecessarily wide mask isn't just slower, it costs more.
  Map<String, String> get placesNearbyHeaders => {
    'Content-Type': 'application/json',
    'X-Goog-Api-Key': _apiKey,
    'X-Goog-FieldMask':
        'places.id,places.displayName,places.formattedAddress,'
        'places.location,places.rating,places.types,'
        'places.currentOpeningHours.openNow',
  };
}
