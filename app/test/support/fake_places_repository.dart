import 'dart:async';

import 'package:kolbi_core/kolbi_core.dart';

/// One request the fake received.
typedef PlaceSearchCall = ({String query, ({double lat, double lng})? near});

/// The acceptance.md "kakaoFour" answer: two callable places, one without a number, one emergency number.
const kakaoFour = PlaceSearchResult(
  source: PlaceSearchSource.kakao,
  places: [
    Place(
      id: 'k1',
      name: '라 파스타',
      category: '양식',
      address: '서울 강남구 테헤란로 12',
      distanceM: 350,
      phone: '02-111-0000',
      phoneNumber: '+8221110000',
      phoneCheck: PlacePhoneCheck.ok,
    ),
    Place(
      id: 'k2',
      name: '파스타 하우스',
      category: '양식',
      address: '서울 강남구 역삼로 7',
      distanceM: 600,
      phone: '02-222-0000',
      phoneNumber: '+8222220000',
      phoneCheck: PlacePhoneCheck.ok,
    ),
    Place(
      id: 'k3',
      name: '봉골레 키친',
      category: '양식',
      address: '서울 강남구 봉은사로 3',
      distanceM: 900,
    ),
    Place(
      id: 'k4',
      name: '응급 파스타',
      category: '양식',
      address: '서울 강남구 논현로 9',
      distanceM: 1200,
      phone: '119',
      phoneCheck: PlacePhoneCheck.blocked,
    ),
  ],
);

/// A fake `POST /v1/places/search`: a fixed answer or error, an optional hold, and every call recorded.
class FakePlacesRepository extends PlacesRepository {
  FakePlacesRepository({this.result = kakaoFour})
    : super(ApiClient(baseUrl: 'http://fake.invalid', token: ''));

  PlaceSearchResult result;

  /// When set, `search` throws this after recording the call.
  Object? error;

  /// When set, `search` waits for it after recording the call.
  Completer<void>? hold;

  final searchCalls = <PlaceSearchCall>[];

  List<String> get queries => [for (final call in searchCalls) call.query];

  @override
  Future<PlaceSearchResult> search(
    String query, {
    ({double lat, double lng})? near,
  }) async {
    searchCalls.add((query: query, near: near));
    if (error case final error?) throw error;
    await hold?.future;
    return result;
  }
}
