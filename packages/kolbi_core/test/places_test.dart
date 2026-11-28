// SPEC-PLACE-001: place models, the first search term, the places repository and representative numbers.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kolbi_core/kolbi_core.dart';
import 'package:test/test.dart';

IntakeResult missingNumber({
  String? targetName,
  bool blocked = false,
  String? placeQuery,
}) => IntakeResult(
  draft: PlanDraft(goal: '예약', targetName: targetName, numberBlocked: blocked),
  missing: const ['phoneNumber'],
  placeQuery: placeQuery,
);

void main() {
  // AC-010 / REQ-010 (design.md D6)
  test('place search start vectors', () {
    const vectors = [
      ('강남역 근처 파스타집, 금요일 7시 2명 예약해 줘', '강남역 파스타집', false),
      ('근처 약국 오늘 몇 시까지 하는지 물어봐 줘', '약국', true),
      ('내일 치과 예약 바꿔 줘', '치과', false),
      ('내 주변 세탁소 문의해 줘', '세탁소', true),
      ('가까운 꽃집에 장미 있는지 알아봐 줘', '꽃집', true),
      ('해 줘', '', false),
      // 0.2.0 (design.md D6 shared table; server/src/domain/placeQuery.test.ts pins the same keywords).
      ('근처 치과 내일 오전 예약해 줘', '치과', true),
      ('근처 미용실 토요일 오후 3시반에 예약해 줘', '미용실', true),
      ('다음 주 수요일 저녁에 근처 고깃집 4명 예약해 줘', '고깃집', true),
      ('지금 근처 약국 몇 시까지 하는지 물어봐 줘', '약국', true),
      ('12월 24일 저녁 강남역 이탈리안 레스토랑 예약해 줘', '강남역 이탈리안 레스토랑', false),
      ('주말 아침에 동네 빵집 몇 시에 여는지 물어봐 줘', '동네 빵집', false),
    ];
    for (final (text, keyword, nearby) in vectors) {
      final start = placeSearchStartFor(text, missingNumber());
      expect(start, isNotNull, reason: text);
      expect(start!.keyword, keyword, reason: text);
      expect(start.nearby, nearby, reason: text);
      expect(start.requestText, text);
    }

    final named = placeSearchStartFor(
      '라 파스타에 금요일 예약해 줘',
      missingNumber(targetName: '라 파스타'),
    )!;
    expect((named.keyword, named.nearby), ('라 파스타', false));
    expect(named.draft.targetName, '라 파스타');
    expect(
      placeSearchStartFor('근처 약국', missingNumber(targetName: '근처 약국'))!.keyword,
      '약국',
    );

    // A number was found, or it was an emergency number: the plan card opens instead.
    final withNumber = IntakeResult(
      draft: const PlanDraft(goal: '예약', phoneNumber: '+8221110000'),
    );
    expect(placeSearchStartFor('라 파스타 02-111-0000 예약', withNumber), isNull);
    expect(
      placeSearchStartFor('119에 전화해 줘', missingNumber(blocked: true)),
      isNull,
    );
    expect(
      placeSearchStartFor('해 줘', IntakeResult(draft: PlanDraft.blank('해 줘'))),
      isNull,
    );

    // Capped at 30 characters.
    final long = placeSearchStartFor('${'가' * 40} 예약해 줘', missingNumber())!;
    expect(long.keyword.length, 30);
  });

  // AC-010 / REQ-010, REQ-023 (design.md D6, D10)
  test('place search start prefers the intake placeQuery', () {
    const text = '근처 치과 내일 오전 예약해 줘';
    final served = placeSearchStartFor(
      text,
      missingNumber(placeQuery: '치과의원'),
    )!;
    expect((served.keyword, served.nearby), ('치과의원', true));
    expect(
      placeSearchStartFor(text, missingNumber(placeQuery: '  '))!.keyword,
      '치과',
    );
    expect(
      placeSearchStartFor(text, missingNumber(placeQuery: '가' * 40))!.keyword,
      '가' * 30,
    );

    IntakeResult parse(Object? placeQuery) => IntakeResult.fromJson({
      'draft': {'goal': '예약'},
      'missing': ['phoneNumber'],
      'placeQuery': ?placeQuery,
    });
    expect(parse('치과').placeQuery, '치과');
    expect(parse(null).placeQuery, isNull);
    expect(parse(7).placeQuery, isNull);
  });

  // AC-003 (app display) / REQ-015 (design.md D9)
  test('formatPhone shows Korean representative numbers', () {
    const table = {
      '+15880000': '1588-0000',
      '+16441234': '1644-1234',
      '+18001234': '1800-1234',
      '+14155550100': '+14155550100',
      '+17001234': '+17001234',
      '+821012345678': '010-1234-5678',
    };
    table.forEach(
      (input, output) => expect(formatPhone(input), output, reason: input),
    );
  });

  test('place search results parse without throwing on unknown values', () {
    final result = PlaceSearchResult.fromJson({
      'source': 'kakao',
      'places': [
        {
          'id': '26338954',
          'name': '라 파스타',
          'category': '양식',
          'address': '서울 강남구 테헤란로 12',
          'distanceM': 350,
          'phone': '02-111-0000',
          'phoneNumber': '+8221110000',
          'phoneCheck': 'ok',
        },
        {'id': 'b', 'name': '봉골레 키친', 'phoneCheck': 'missing'},
        {
          'id': 'c',
          'name': '응급 파스타',
          'phone': '119',
          'phoneCheck': 'blocked',
          'distanceM': 1200.0,
        },
        {
          'id': 'd',
          'name': '이상한 값',
          'phoneNumber': '+8221110000',
          'phoneCheck': 'weird',
        },
        {'name': '아이디 없음'},
        'not a map',
      ],
    });
    expect(result.source, PlaceSearchSource.kakao);
    expect(result.places.map((p) => p.id), ['26338954', 'b', 'c', 'd']);
    final first = result.places.first;
    expect(first.callable, isTrue);
    expect(first.distanceM, 350);
    expect(first.category, '양식');
    expect(result.places[1].phoneCheck, PlacePhoneCheck.missing);
    expect(result.places[1].callable, isFalse);
    expect(result.places[2].distanceM, 1200);
    // An unknown check is never callable, even with a number.
    expect(result.places[3].phoneCheck, PlacePhoneCheck.invalid);
    expect(result.places[3].callable, isFalse);

    expect(
      PlaceSearchResult.fromJson({'source': 'other', 'places': 'x'}).source,
      PlaceSearchSource.unknown,
    );
    expect(PlaceSearchResult.fromJson({}).places, isEmpty);
    expect(
      PlaceSearchResult.fromJson({'source': 'simulated'}).source,
      PlaceSearchSource.simulated,
    );
  });

  test(
    'the places repository posts the query and the rounded-by-server position',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({'source': 'simulated', 'places': <Object>[]}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final repo = PlacesRepository(
        ApiClient(baseUrl: 'http://server.test', token: 't', client: client),
      );

      expect((await repo.search('파스타')).source, PlaceSearchSource.simulated);
      await repo.search('약국', near: (lat: 37.55, lng: 126.91));

      expect(requests.map((r) => '${r.method} ${r.url.path}'), [
        'POST /v1/places/search',
        'POST /v1/places/search',
      ]);
      expect(jsonDecode(requests[0].body), {'query': '파스타'});
      expect(jsonDecode(requests[1].body), {
        'query': '약국',
        'near': {'lat': 37.55, 'lng': 126.91},
      });
      expect(requests[0].headers['Authorization'], 'Bearer t');
    },
  );

  test('PhoneSource.search reads as 검색 결과', () {
    expect(PhoneSource.search.label, '검색 결과');
  });
}
