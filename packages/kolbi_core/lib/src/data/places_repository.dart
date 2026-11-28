import '../models/place_models.dart';
import '../network/api_client.dart';

/// `POST /v1/places/search` (SPEC-PLACE-001 design.md D1). Results are returned, never cached or stored.
class PlacesRepository {
  PlacesRepository(this._api);

  final ApiClient _api;

  /// [near] is sent only for "근처" requests; the server rounds it before it reaches Kakao (REQ-017).
  Future<PlaceSearchResult> search(
    String query, {
    ({double lat, double lng})? near,
  }) async => PlaceSearchResult.fromJson(
    await _api.post('/v1/places/search', {
      'query': query,
      if (near != null) 'near': {'lat': near.lat, 'lng': near.lng},
    }) as Map<String, dynamic>,
  );
}
