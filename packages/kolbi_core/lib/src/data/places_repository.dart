import '../models/place_models.dart';
import '../network/api_client.dart';

/// `POST /v1/places/search` (SPEC-PLACE-001 design.md D1). Results are returned, never cached or stored.
double _round(double value) => (value * 1000).round() / 1000;

class PlacesRepository {
  PlacesRepository(this._api);

  final ApiClient _api;

  /// [near] is sent only for "근처" requests, rounded here to 3 decimals (about 100 m) and again by the server
  /// before it reaches Kakao (REQ-017, sync audit 1 I2).
  Future<PlaceSearchResult> search(
    String query, {
    ({double lat, double lng})? near,
  }) async => PlaceSearchResult.fromJson(
    await _api.post('/v1/places/search', {
      'query': query,
      if (near != null)
        'near': {'lat': _round(near.lat), 'lng': _round(near.lng)},
    }) as Map<String, dynamic>,
  );
}
