# SPEC-PLACE-001 인수 기준 (0.2.1)

## 공통 검증 명령

서버(저장소 루트):

```bash
npm --prefix server test
npm --prefix server run typecheck
```

공유 패키지와 앱:

```bash
(cd packages/kolbi_core && dart test && dart analyze)
(cd app && flutter --suppress-analytics test test/places_test.dart test/architecture_test.dart)
(cd app && flutter --suppress-analytics test)
(cd app && flutter --suppress-analytics analyze)
```

변경 범위(저장소 루트):

```bash
git diff --stat <run_start_sha> -- server/src/services server/src/brain server/src/providers server/src/store server/src/domain
git diff <run_start_sha> -- app/test/ server/src/http/app.test.ts
```

기준선(74a87c3, `research.md` R4): 서버 `Tests  387 passed (387)`, 앱 `+148: All tests passed!`, `kolbi_core` `+27: All tests passed!`. run 시작 시 manager-develop이 `run_start_sha`, 위 명령 결과, `grep -rn "최근 통화한 곳" app/test` 결과를 `progress.md` §E.2 첫 부분에 기록하고 AC-022 표와 대조한다.

공통 준비:

- 서버 시험은 가짜 `fetch`와 `InMemoryTaskStore`(D4는 임시 디렉터리의 `JsonFileTaskStore`)를 쓴다. 실제 카카오를 부르지 않는다.
- 앱 위젯 시험은 기존 방식(`FakeCallsRepository`, `SharedPreferences` 대역, `ProviderScope` 재정의)에 `FakePlacesRepository`(응답·오류·`hold`·`searchCalls` 기록)와 `FakeLocationReader`(권한 상태, 요청 결과, 좌표 또는 실패, 호출 기록)를 더한다. 비서에서 장소 선택으로 가려면 `repo.intakeResult = IntakeResult(draft: …, missing: ['phoneNumber'])`로 둔다.
- 기본 가짜 장소 응답 `kakaoFour`: `source: kakao`, 후보 넷 — ① "라 파스타", 양식, 350m, `02-111-0000`, `ok` ② "파스타 하우스", 양식, 600m, `02-222-0000`, `ok` ③ "봉골레 키친", 양식, 900m, 번호 없음, `missing` ④ "응급 파스타", 양식, 1,200m, `119`, `blocked`.

규칙: 사진 비교 시험을 쓰지 않는다. 시험 먼저(RED) → 구현(GREEN). 서식은 이 SPEC이 만들거나 고친 파일에만.

## AC-001 — 제공자 조립 (REQ-001)

- **Given** 설정 (1) `KAKAO_REST_API_KEY` 있음 + 시뮬레이션 통화 (2) 같은 키 + KAT 설정 완비 (3) 키 없음 + 시뮬레이션 통화 (4) 키 없음 + KAT 설정 완비
- **When** `createContainer`로 조립하면
- **Then** (1)(2) `places.source`가 `kakao` (3) `simulated` (4) `places`가 없다(`undefined`). `loadConfig`는 키가 없어도 실패하지 않고, 키 값은 `index.ts` 기동 로그 객체에 없다(`placeSearch` 값만 있음)
- 시험: `server/src/places/placeSearch.test.ts` — "the container picks the place provider from the key and the call provider"

## AC-002 — 경로 계약 (REQ-002)

- **Given** 시뮬레이션 제공자로 만든 앱, 토큰 `test-token`
- **When** (1) 토큰 없이 `POST /v1/places/search` (2) `{query: "   "}` (3) `{query: 101자}` (4) `{query: "파스타", near: {lat: 91, lng: 0}}` (5) `{query: "파스타"}` (6) `{query: "파스타", near: {lat: 37.5, lng: 127.0}}` (7) `{query: "파스타", near: {lat: 37.4979, lng: 127.0276}}`
- **Then** (1) 401 `unauthorized` (2)(3)(4) 400 `invalid_request`, 응답 `message`에 입력 값이 들어 있지 않다 (5) 200, 키가 정확히 `places`, `source`이고 후보 5곳, 각 후보 키가 정확히 `address, category, distanceM, id, name, phone, phoneCheck, phoneNumber`, 모든 `distanceM`이 `null`, 머리 `Cache-Control`이 `no-store` (6) 200, 모든 `distanceM`이 숫자이며 오름차순(REQ-006). 별도로, 가짜 제공자로 `PlaceQuery`를 기록하면 (5)는 `{keyword: "파스타", limit: 5, radiusM: 2000}`에 `near` 없음, (6)은 `near: {lat: 37.5, lng: 127.0}`가 있으며, (7)은 반올림된 `near: {lat: 37.498, lng: 127.028}`이다
- 시험: `server/src/http/places.test.ts` — "POST /v1/places/search validates and answers in the documented shape"

## AC-003 — 번호 판정 (REQ-003)

- **Given** 가짜 제공자가 번호 원문 `02-111-0000`, `010 1234 5678`, `""`(빈 값), `119`, `1588-0000`, `12`를 가진 후보 여섯을 돌려줌
- **When** `createPlaceSearch(fake).search({query: "x"})`
- **Then** 순서대로 `phoneCheck`가 `ok`, `ok`, `missing`, `blocked`, `ok`, `invalid`이고, `phoneNumber`가 `+8221110000`, `+821012345678`, `null`, `null`, `+15880000`, `null`이다(계획 단계에서 `checkTargetNumber`를 실행해 얻은 값, `research.md` R3). `phone`은 원문 그대로(빈 값은 `null`)다. 앱 표시: `formatPhone`이 `design.md` D9 표의 여섯 줄을 그대로 돌려준다(`formatPhone('+15880000') == '1588-0000'`, `formatPhone('+14155550100') == '+14155550100'`)
- 시험: `placeSearch.test.ts` — "every candidate number goes through checkTargetNumber", `packages/kolbi_core/test/places_test.dart` — "formatPhone shows Korean representative numbers"

## AC-004 — 저장·캐시·이벤트·로그 금지 (REQ-004)

- **Given / When / Then** `design.md` D4의 준비·동작 (a)~(e)·확인 1~6 전부. 특히 (c) 카카오 500, (d) 표식을 메시지와 `input`·`code` 속성에 담은 `TypeError`, (e) 형식이 틀린 200 응답이 모두 502 `place_search_failed`(고정 문구 본문)이고, 표식이 붙잡은 모든 출력과 오류 응답 본문에 없다.
- 시험: `server/src/http/places.test.ts` — "place search results never reach storage, cache, events or logs"
- 추가 확인(앱): AC-015 흐름 끝에 `SharedPreferences`의 모든 키와 값에 후보 이름·번호·주소·장소 ID가 없다(`places_test.dart` — "the app keeps no place results")

## AC-005 — 카카오 어댑터 (REQ-005)

- **Given** 가짜 `fetch`
- **When** (1) `{keyword: "강남역 파스타집", limit: 5, radiusM: 2000}`로 검색 (2) 같은 질의에 이미 반올림된 `near {lat: 37.498, lng: 127.028}` (3) 응답 문서 하나가 `category_name: "음식점 > 양식 > 이탈리안"`, `road_address_name: ""`, `address_name: "서울 강남구 역삼동 1"`, `phone: ""`, `distance: ""` (4) `place_name`이 공백뿐인 문서 (5) `fetch`가 401을 돌려줌 (6) `fetch`가 거절함 (7) 응답이 `{documents: "x"}` (8) 신호를 따르며 끝나지 않는 가짜 `fetch`에, 시험이 `AbortController.abort()`를 부름 (9) `fetch`가 표식 메시지의 `TypeError`를 던짐 (10) `createPlaceSearch(kakao, {timeoutMs: 20})`로 끝나지 않는 `fetch`를 부름(실제 시계)
- **Then** (1) URL이 `https://dapi.kakao.com/v2/local/search/keyword.json`이고 검색 매개변수가 정확히 `query=강남역 파스타집`, `size=5`, `page=1`이며 `Authorization` 머리가 `KakaoAK <키>`다 (2) 매개변수에 `x=127.028`, `y=37.498`, `radius=2000`, `sort=distance`가 더해지고, `fetch`가 받은 `signal`이 넘긴 신호와 같다 (3) `category` `"이탈리안"`, `address` `"서울 강남구 역삼동 1"`, `phone` `null`, `distanceM` `null` (4) 그 문서는 결과에서 빠진다 (5)(6)(7)(8) 각각 `PlaceSearchError`의 종류 `status`(401)·`network`·`format`·`timeout`이고, 어댑터 로거에 남은 한 줄에는 상태·종류만 있고 응답 본문·검색어가 없다 (9) `PlaceSearchError`(종류 `network`, `design.md` D3)이고 `cause`가 없으며 메시지에 표식이 없다 (10) 100ms 안에 `PlaceSearchError("timeout")`. 경로를 거치면 (5)~(10) 모두 502 `place_search_failed`. 또 `createPlaceSearch(provider).search()`가 거절한 값은 (5)~(10)과, 제공자가 표식을 담은 일반 `Error`를 던지는 경우 모두 `PlaceSearchError`이고 `error.cause === undefined`이며 메시지에 표식이 없다
- 시험: `server/src/places/kakaoLocalPlaceSearch.test.ts` — "kakao keyword search request, mapping and failures", `placeSearch.test.ts` — "search rejects only with a bare PlaceSearchError"

## AC-006 — 시뮬레이션 제공자 (REQ-006)

- **Given** `SimulatedPlaceSearch`, 가짜 `fetch`를 전역에 심어 호출을 셈
- **When** "파스타"로 두 번, `near`를 주고 한 번 검색
- **Then** 세 번 모두 후보 5곳, 같은 검색어의 두 결과가 같고(결정적), 이름이 모두 "연습용"으로 시작하며, `phoneCheck`에 `ok`·`missing`·`invalid`가 모두 있고, `near`가 없으면 거리가 모두 `null`, 있으면 모두 숫자이고 오름차순이다. 전역 `fetch` 호출 수는 0이다. 경로 응답의 `source`는 `simulated`다
- 시험: `placeSearch.test.ts` — "the simulated provider is deterministic and offline"

## AC-007 — 장소 검색 꺼짐 (REQ-007)

- **Given** `places`가 없는 `buildApp`(AC-001 (4)의 조립)
- **When** 토큰과 함께 `{query: "파스타"}`를 보내면
- **Then** 503 `place_search_unavailable`이고 다른 경로(`/v1/tasks`, `/v1/intake`, `/v1/config`)의 응답은 `places`가 있을 때와 같다
- 시험: `places.test.ts` — "without a place provider the route answers 503"

## AC-008 — 모듈 경계와 키 (REQ-008)

- **Given** 이 SPEC의 변경 뒤
- **When** `architecture.test.ts`를 실행하고 소스를 검색하면
- **Then** `design.md` D2 구조 규칙 1~4가 통과하고(위반 목록이 빈 배열), 규칙이 실제로 파일을 읽었음을 확인한다(`places/kakaoLocalPlaceSearch.ts`가 검사 목록에 있음). `grep -rn "KAKAO_REST_API_KEY" app packages` 출력이 없다
- 시험: `server/src/architecture.test.ts` — "places module stays stateless and out of store, brain and services", "http layer does not know concrete place providers", "no any for place provider data"

## AC-009 — 비서에서 장소 선택으로 (REQ-009)

- **Given** 프로필 있음, 가짜 인식기 없음(비서가 글로 입력 모드로 열림), 접수 결과 (1) `missing: ['phoneNumber']`, 이름 없음 (2) `missing: ['phoneNumber']`, 이름 "라 파스타" (3) 번호 있음(`missing` 빔) (4) `missing: ['phoneNumber']`, `draft.numberBlocked: true` (5) `intakeError` 404 (6) 기본 가짜(빈 `missing`)
- **When** 글로 입력 모드에서 부탁을 보내면
- **Then** (1)(2) 장소 선택 화면이 열리고(탭 바 없음, 현재 위치 `/assistant/places`), 시스템 뒤로 가기 하면 비서 글로 입력 모드에 보낸 문장이 그대로 있다 (3)(4)(5)(6) 장소 선택 화면 없이 계획 카드(`/assistant/plan`)가 열리고 `FakePlacesRepository.searchCalls`가 비어 있다
- 시험: `app/test/places_test.dart` — "the assistant opens place selection only when the number is missing"

## AC-010 — 첫 검색어와 근처 (REQ-010)

- **Given** `design.md` D6 공유 예시 표의 서른네 줄("해 줘", "근처 치과 내일 오전 예약해 줘" 포함, `placeQuery` 없는 결과 — 옛 서버의 대체 규칙)과 이름 있는 경우 한 줄, `placeQuery`가 있는 결과(문장 "근처 치과 내일 오전 예약해 줘", `placeQuery` `치과`; 공백뿐인 `placeQuery` `"  "`; 40자 `placeQuery`), 그리고 번호 있음·차단 번호 결과. `IntakeResult.fromJson`에 `placeQuery` `"치과"` / 키 없음 / `7`(숫자)
- **When** `placeSearchStartFor`를 부르고 JSON을 해석하면
- **Then** 표의 `keyword`·`nearby`와 같고, `placeQuery` `치과`이면 `keyword` `치과`·`nearby` `true`, 공백뿐이면 대체 규칙 값, 40자면 30자로 잘림, 번호 있음·차단은 `null`이다. 해석은 차례로 `"치과"`, `null`, `null`(예외 없음). 앱에서는 (1) 검색어 "강남역 파스타집"으로 화면이 열리면 검색칸 글자가 그것이고 `searchCalls`가 `["강남역 파스타집"]`이다 (2) 검색어가 빈 문장("해 줘", D6 표의 고정 줄)이면 검색칸이 비어 초점을 갖고 `searchCalls`가 비어 있으며, "망원동 세탁소"를 적고 [다시 찾기]를 누르면 `searchCalls`가 `["망원동 세탁소"]`다
  앱에서 (3) 부탁 "근처 치과 내일 오전 예약해 줘", 접수 결과의 `placeQuery`가 `치과의원`(대체 규칙 값 `치과`와 일부러 다르게), 가짜 위치가 이미 허용·좌표 (37.55, 126.91)이면 검색칸 글자가 "치과의원"이고 `searchCalls`가 검색어 "치과의원"과 `near (37.55, 126.91)` 하나다(`nearby`는 앱이 정함) (4) 같은 부탁에 `placeQuery`가 없으면(옛 서버) 검색어가 "치과"다
- 시험: `packages/kolbi_core/test/places_test.dart` — "place search start vectors", "place search start prefers the intake placeQuery", `places_test.dart` — "the search field starts from the request", "the assistant searches with the intake placeQuery"

## AC-011 — 장소 선택 화면 구성 (REQ-011)

- **Given** 응답 `kakaoFour`, 부탁 "강남역 근처 파스타집, 금요일 7시 2명 예약해 줘"
- **When** 장소 선택 화면이 열리면
- **Then** 부탁 줄과 [고치기], 검색칸, "강남역 파스타집 4곳을 찾았어요", 후보 카드 넷, "장소 정보는 카카오 로컬 검색 결과예요", [번호 직접 입력]이 이 순서로 위에서 아래에 있다(세로 위치 비교). ① 카드에 "가장 가까워요" 칩이 있고 ① 카드의 [여기로 전화]만 `FilledButton`, ② 카드의 [여기로 전화]는 `OutlinedButton`이다. 각 카드에 이름·"양식"·거리(`350m` 등)·번호 원문(있을 때)·[상세]가 있다. [고치기]를 누르면 비서 글로 입력 모드에 부탁 문장이 그대로 있다. `source: simulated` 응답에서는 출처 줄이 "연습용 장소예요. 실제 가게가 아니에요"이고, 거리가 없는 응답에서는 "가장 가까워요"가 없다
- 시험: `places_test.dart` — "place selection follows the wireframe order"

## AC-012 — 로딩·없음·실패·꺼짐·걸 곳 없음 (REQ-012)

- **Given** 가짜 장소 저장소 (1) `hold` 설정 (2) 빈 후보 (3) 502 `ApiException` (4) 503 `ApiException` (5) 후보가 ③·④뿐
- **When** 장소 선택 화면이 열리면
- **Then** (1) `hold`를 풀기 전 "강남역 파스타집을 찾는 중이에요"와 뼈대 카드 3개(`Key('place-skeleton')` 셋) (2) "조건에 맞는 곳을 찾지 못했어요" (3) "장소를 찾지 못했어요. 잠시 뒤 다시 시도해 주세요"와 [다시 시도], 누르면 `searchCalls`가 하나 늘어남 (4) "지금은 장소 찾기를 쓸 수 없어요"이고 [다시 시도]가 없음 (5) 카드 둘과 "전화할 수 있는 곳이 없어요", 계획 카드가 열리지 않음. 다섯 경우 모두 [번호 직접 입력]이 있다
- 시험: `places_test.dart` — "loading, empty, failure and nothing callable"

## AC-013 — 걸 수 없는 후보는 고를 수 없음 (REQ-013)

- **Given** 응답 `kakaoFour`
- **When** ③·④ 카드를 보고 각 [여기로 전화]를 눌러 보고, ③의 [상세]를 열면
- **Then** ① 카드에 "걸 수 있음", ③에 "번호 없음"과 "번호가 없어 전화할 수 없어요", ④에 "걸 수 없는 번호"와 "걸 수 없는 번호예요"가 보인다. ③·④의 [여기로 전화]는 `onPressed`가 `null`이고 눌러도 계획 카드가 열리지 않는다. ③ 상세의 [여기에 물어보기]도 비활성이다
- 시험: `places_test.dart` — "uncallable candidates cannot be chosen"

## AC-014 — 장소 상세 시트 (REQ-014)

- **Given** 응답 `kakaoFour`
- **When** ① 카드의 [상세]를 누르고, [번호 복사]를 누른 뒤, [닫기]를 누르면
- **Then** 시트에 "라 파스타"(초점을 가진 제목), "양식 · 350m", 주소, "02-111-0000", [번호 복사], [여기에 물어보기]가 있고, [번호 복사] 뒤 클립보드(시험 채널 기록)가 "02-111-0000"이며, 닫은 뒤 ① 카드의 [상세]에 초점이 있다. ③의 상세에는 [번호 복사]가 없다
- 시험: `places_test.dart` — "place detail sheet"

## AC-015 — 고른 곳으로 계획 카드 (REQ-015)

- **Given** 접수 초안: 목표 "금요일 7시 2명 예약", 조건 ["창가 자리"], 이름 없음, `missing: ['phoneNumber']`; 응답 `kakaoFour`. (4)만 응답이 후보 하나 "고객센터 대표", `phone` `1588-0000`, `phoneNumber` `+15880000`, `phoneCheck` `ok`
- **When** (1) ① 카드의 [여기로 전화] (2) 새로 띄워 ②의 [상세] → [여기에 물어보기] (3) 새로 띄워 [번호 직접 입력] (4) 새로 띄워 그 후보의 [여기로 전화] 뒤 [이대로 시작]
- **Then** (1) 계획 카드에 "라 파스타", "02-111-0000", "검색 결과", "금요일 7시 2명 예약", "창가 자리"가 있고 번호 칸(`Key('plan-phone-field')`)이 맨 위에 없다. 뒤로 가면 장소 선택(후보 넷 그대로, `searchCalls` 수 그대로), 한 번 더 뒤로 가면 비서. [이대로 시작]을 누르면 가짜 저장소 `create`가 받은 요청의 `targetName`이 "라 파스타", `phoneNumber`가 `+8221110000`이다 (2) 같은 방식으로 "파스타 하우스", "02-222-0000" (3) 계획 카드 맨 위에 번호 칸이 있고 "전화할 곳"이 비어 있다(지금의 번호 없음 동작) (4) 계획 카드 번호 줄에 "1588-0000"이 있고 "+15880000"이라는 글자는 화면에 없으며, `create`가 받은 요청의 `phoneNumber`가 `+15880000`이다
- 시험: `places_test.dart` — "choosing a place fills the plan card"

## AC-016 — 근처와 위치 권한 (REQ-016)

- **Given** 부탁 "근처 약국 오늘 몇 시까지 하는지 물어봐 줘", `missing: ['phoneNumber']`, 가짜 위치 (1) 묻지 않음 → 허용, 좌표 (37.55, 126.91) (2) 묻지 않음 → 거부 (3) 다시 묻지 않음 (4) 허용됨, 읽기 실패 (5) 허용됨, 11초 동안 답 없음 (6) `unavailable`
- **When** 장소 선택 화면이 열리면
- **Then** (1) 사전 안내 문구("근처 가게를 찾으려면 지금 위치가 필요해요. 가까운 가게를 찾는 데만 써요. 콜비는 위치를 저장하지 않아요.")와 [계속]이 보이고, "위치는 검색에만"이라는 글자는 없으며, [계속] 전 `request` 호출 수 0, 뒤 1이며, `searchCalls`의 마지막이 검색어 "약국"과 `near (37.55, 126.91)`이다 (2) [계속] 뒤 "동네 이름을 알려 주세요"가 보이고 `searchCalls`가 비어 있으며, "망원동"을 적고 [찾기]를 누르면 검색어 "망원동 약국", `near` 없음 (3) 사전 안내 없이 동네 이름 칸과 [설정 열기], 누르면 가짜의 `openSettings` 호출 수 1 (4)(5)(6) 사전 안내 없이 동네 이름 칸, 예외 없음(`tester.takeException()`이 `null`)
- 시험: `places_test.dart` — "nearby asks for location with a purpose first"

## AC-017 — 위치를 남기지 않고 경계를 지킴 (REQ-017)

- **Given** (1) AC-016 (1)의 흐름 끝 (2) "근처"가 아닌 부탁(AC-011)
- **When** 상태와 저장소를 보고, 의존 규칙 시험을 실행하면
- **Then** (1) `SharedPreferences`의 키·값에 `37.55`·`126.91`이 없다 (2) 가짜 위치의 `access`·`request`·`readOnce` 호출 수가 모두 0이고 `searchCalls`의 `near`가 `null`이다. `geolocator` import는 `app/lib/features/places/location/` 안에만 있고 `packages/kolbi_core/lib`·`packages/kolbi_ui/lib`에는 없다
- 시험: `places_test.dart` — "location stays out of storage and other requests", `architecture_test.dart` — "the location package stays inside the places feature"

## AC-018 — 권한 선언 (REQ-018)

- **Given** 이 SPEC의 변경 뒤
- **When** 플랫폼 파일을 읽으면
- **Then** `Info.plist`에 `<key>NSLocationWhenInUseUsageDescription</key>`이 있고 그 문구에 "콜비는 위치를 저장하지 않아요"가 있으며, `NSLocationAlways`가 없으며, `AndroidManifest.xml`에 `android.permission.ACCESS_COARSE_LOCATION`이 있고 `ACCESS_FINE_LOCATION`·`ACCESS_BACKGROUND_LOCATION`이 없다. 기존 마이크·음성 인식 선언 검사는 그대로 통과한다
- 시험: `architecture_test.dart` — "platform files declare coarse location only"

## AC-019 — 계획 카드 펼침 규칙 일부 (REQ-019)

- **Given** (1) AC-015 (1)의 계획 카드 (2) 기존 `plan_card_test.dart`·`shell_test.dart`
- **When** 화면을 보고 시험을 실행하면
- **Then** (1) "통화 언어"와 "내 이름" 두 행 대신 접힌 한 줄(`Key('plan-defaults-row')`) 안에 "한국어"와 "김민수"가 있고, "한국어"와 "김민수"는 각각 따로 된 `Text` 위젯이다(`find.text('한국어')`, `find.text('김민수')`가 각각 `findsOneWidget`, 두 글자를 합친 한 `Text`는 없음 — `find.textContaining('한국어 · 김민수')`가 `findsNothing`). "한국어"를 누르면 "English"로, "김민수"를 누르면 설정 화면이 비서 위에 열린다. 두 글자의 누르는 자리는 각각 48×48 이상이다 (2) `plan_card_test.dart`, `shell_test.dart`가 수정 없이 통과한다
- 시험: `places_test.dart` — "the plan card folds defaults into one line"

## AC-020 — "최근 장소" (REQ-020)

- **Given** 작업 "섞음" + 끝난 연결 작업(최근 장소가 계산됨)
- **When** 오늘과 비서 글로 입력 모드를 보면
- **Then** 두 곳 모두 "최근 장소"가 있고 "최근 통화한 곳"이 없으며, 칩 글자와 누르면 채우는 글자("{이름}에 ")는 지금과 같다. `grep -rn "최근 통화한 곳" app/lib` 출력이 없다(제목 두 줄과 주석 다섯 줄 — `home_screen.dart:19`, `:133`, `:166`, `request_box.dart:9`, `shell/request_intake.dart:18` — 을 모두 바꿈)
- 시험: AC-022 표의 수정된 블록들

## AC-021 — 접근성 (REQ-021)

- **Given** 장소 선택 화면(결과 `kakaoFour`), 상세 시트, 위치 사전 안내
- **When** 네 지침을 검사하고 360×640·`TextScaler.linear(2.0)`으로 띄우면
- **Then** 지침 검사가 모두 통과하고 넘침 오류가 없으며, ① 카드의 의미 라벨이 "라 파스타, 양식, 350미터, 걸 수 있음"을 담고, ③ 카드 라벨이 "번호 없음"을 담는다. 검색이 끝날 때 "강남역 파스타집 4곳을 찾았어요"가 정중한 수준으로 한 번 알려진다(같은 결과를 다시 그려도 알림 수가 늘지 않음)
- 시험: `places_test.dart` — "place screens meet the accessibility guidelines"

## AC-022 — `/v1` 불변과 의도한 시험 변경 (REQ-022)

- **Given** run 시작 시점
- **When** run 끝에 공통 검증의 변경 범위 명령을 실행하면
- **Then** `server/src/providers`·`store` 변경이 없고, `services`·`brain`·`domain`은 `plan.md` §B.4 표의 파일만 바뀐다(0.2.0 M7, `/v1/intake`의 `placeQuery`). `/v1/config` 응답 고정 시험은 그대로 통과한다. 기존 시험에서 바뀐 곳은 다음뿐이다:

  | 파일 | 블록(테스트 이름 · 74a87c3 줄) | 바뀌는 내용 |
  |---|---|---|
  | `app/test/today_test.dart` | "today follows the dashboard order"(`:31`, 단언 `:44`) | `find.text('최근 통화한 곳')` → `find.text('최근 장소')` |
  | `app/test/assistant_test.dart` | "text mode carries the whole request box"(`:524`, 단언 `:556`, `:580`) | 같음(두 줄) |
  | `app/test/assistant_test.dart` | "today hands requests to the assistant"(`:828`, 단언 `:850`) | 같음 |
  | `app/test/accessibility_test.dart` | "screens follow the wireframe order"(`:610`, 단언 `:622`) | 같음 |
  | `app/test/intake_flow_test.dart` | "suggests recent counterparties and templates"(`:119`, 단언 `:130`) | 같음 |
  | `app/test/intake_flow_test.dart` | "…: no tasks yet"(`:153`, 단언 `:157`) | 같음(`findsNothing` 유지) |
  | `app/test/assistant_test.dart`, `today_test.dart`의 주석 | `:121`, `:14` | 주석의 묶음 이름(선택) |
  | `app/test/architecture_test.dart` | 파일 끝 | 더하기만: AC-017·AC-018 시험 |
  | `server/src/architecture.test.ts` | 파일 끝 | 더하기만: AC-008 시험 |
  | `server/src/http/app.test.ts` | "drafts an intake without creating a task $name"(`:689`, 단언 `:699`, 0.2.0) | 응답 키 목록 `["draft", "missing", "numberIssue", "phoneSource", "source"]` → `["draft", "missing", "numberIssue", "phoneSource", "placeQuery", "source"]`(한 줄). `:700`의 `draft` 키 목록은 그대로 |
  | `server/src/brain/openaiBrain.test.ts` | 파일 끝(0.2.0) | 더하기만: AC-023의 프롬프트·스키마 시험. 기존 블록(`:261-` "OpenAiBrain intake")은 그대로 |

  `app/test/unit_test.dart`의 `formatPhone` 시험(`:12-15`)은 바꾸지 않고 그대로 통과한다(대표번호 규칙은 `kolbi_core` 새 시험에서 확인). 도구가 갱신하는 iOS SwiftPM 파일(plan §B.3)은 시험 파일이 아니라 이 표와 무관하다.

  표 밖에서 깨지는 블록이 있으면 고치기 전에 소유자 확인을 받아 이 표에 더한다. 서버·앱·`kolbi_core` 시험 수가 기준선보다 줄지 않는다
- 확인: 위 `git diff` 원문을 `progress.md`에 기록

## AC-023 — 접수의 `placeQuery` (REQ-023)

- **Given** (1) 휴리스틱 두뇌의 앱(`places.test.ts`의 `makeApp`) (2) 접수 내용을 정해 주는 가짜 두뇌 (3) 가짜 `fetch`로 부르는 `OpenAiBrain`
- **When** (1) `POST /v1/intake`에 "근처 치과 내일 오전 예약해 줘", "강남역 근처 파스타집, 금요일 7시 2명 예약해 줘", "라 파스타에 전화해서 금요일 7시 예약", "해 줘" (2) 두뇌가 `placeQuery` `"치과"` / `"근처 치과 010-1234-5678"` / `"   "`(문장 "근처 치과 내일 오전 예약해 줘") / 값 없음 (3) LLM 답의 `placeQuery`가 `"치과"` / 없음 / `null` / `7` / 101자이고, 프롬프트를 보면
- **Then** (1) 응답 `placeQuery`가 차례로 `"치과"`, `"강남역 파스타집"`, `"라 파스타"`, `null`이고 `draft.goal`에는 "내일 오전"이 그대로 있다. `domain/placeQuery.test.ts`가 D6 공유 예시 표 서른네 줄을 `placeQueryFor(text, null)`로 고정한다 (2) `"치과"`, `"치과"`(번호·`근처` 지움), `"치과"`(대체 규칙), `"치과"`(대체 규칙) (3) 결과 `placeQuery`가 `"치과"`이고 `source` `llm`; 없음·`null`·`7`·101자이면 결과에 `placeQuery` 키가 없고 `source`는 여전히 `llm`(휴리스틱으로 떨어지지 않음, 경고 로그 0). `INTAKE_SYSTEM_PROMPT`에 `placeQuery`와 `"근처"`가 있다
- 시험: `server/src/domain/placeQuery.test.ts` — "place query vectors shared with the app", `server/src/http/places.test.ts` — "intake answers with a place query", `server/src/brain/openaiBrain.test.ts` — "intake reads placeQuery leniently"

## AC-024 — `placeQuery`는 응답에만 (REQ-024)

- **Given** 표식 장소 이름 `"표식치과-5a5a"`, 임시 디렉터리의 `JsonFileTaskStore`(작업 하나), 이벤트 수를 세는 버스, Fastify 로그 스트림과 두뇌 로거를 붙잡음. 두뇌 (1) LLM 성공(가짜 `fetch`가 `placeQuery` `"표식치과-5a5a"`를 답함) (2) LLM 실패(가짜 `fetch` 500) → 서비스 대체 규칙
- **When** 각각 `POST /v1/intake`에 "근처 표식치과-5a5a 내일 오전 예약해 줘"를 보내면
- **Then** 두 응답 모두 `placeQuery`가 `"표식치과-5a5a"`이고, 붙잡은 모든 출력(Fastify 스트림, 두뇌 로거)에 표식이 없으며, 저장소 파일 바이트·`store.list()`가 그대로이고 이벤트 수가 0이다. 또 `grep -rnE "(log|logger)\.(info|warn|error|debug)\(" server/src --include=*.ts | grep placeQuery` 출력이 없다
- 시험: `server/src/http/places.test.ts` — "intake placeQuery never reaches storage, events or logs"

## 엣지 케이스

- 검색 중에 화면을 닫음: 늦게 온 응답은 무시하고 예외가 없다(컨트롤러가 닫힌 뒤 상태를 바꾸지 않음).
- 같은 이름의 후보가 둘: `id`로 구별해 둘 다 보인다.
- 번호 원문이 `02-111-0000~2`처럼 범위 표기: `checkTargetNumber`가 판정한 대로(대부분 `invalid` 또는 앞 번호) 보이고, 사용자는 [번호 직접 입력]으로 고칠 수 있다.
- 큰 글자 2.0에서 주소가 길면 카드가 세로로 늘고 버튼 줄은 줄바꿈된다.
- 기기 언어가 영어여도 문구는 한국어다(03 F-SET-04).
- "근처"인데 위치 서비스가 꺼져 있음: `unavailable` → 동네 이름 칸.

## 잔여 위험

- 실제 카카오 응답의 번호 모양과 오류 형식은 가짜로만 시험한다. 완료 정의에 실제 키 확인 1건을 둔다.
- OD-3(작업 기록이 "결과 저장"에 해당하는지)은 법무·카카오 해석에 따라 개정될 수 있다.
- 사용자별 검색 제한이 없어 쿼터가 소진될 수 있다(plan §D).
- 사람 이름("엄마", 연락처 이름)이 검색어로 카카오에 전송된다. OD-6 결정(2026-11-28)으로 소유자가 받아들인 위험이다. 개정 후보: 사람 호칭에 걸리면 자동 검색 없이 검색칸만 연다.
- "근처" 검색의 좌표는 반올림(약 100m)된 채 카카오로 넘어가며, 카카오 쪽 보관 여부는 콜비가 보장하지 못한다. 그래서 문구는 "콜비는 위치를 저장하지 않아요"까지만 말한다.
- `formatPhone`의 대표번호 규칙은 `+1` 뒤 7자리라는 서버의 현재 판정 모양에 기댄다. SPEC-POLICY-001이 대표번호 판정을 바꾸면 이 규칙도 다시 본다.
- (sync 주석 2026-11-28) 서버 `checkTargetNumber`는 여전히 `"1588-0000"`을 `+15880000`(국가 번호 +1)으로 판정한다. 이 SPEC은 표시만 고쳤고(`formatPhone`, 앱 전체에 적용) 서버 판정은 바꾸지 않았다. 실제로 거는 숫자는 `toDomesticDialString`의 `15880000`이다.
- (sync 주석 2026-11-28) 검색어 대체 규칙(서버 `domain/placeQuery.ts`, 앱 `kolbi_core` `place_intent.dart`)은 고정 낱말 목록이다. 시간 낱말·사람 조사·인용 어미·동행 표현·관형형 동사(`갈`·`올`·`먹을`·`마실`·`모일`·`놀`·`묵을`)를 건너뛰지만, 목록에 없는 관형형 동사(예: `앉을`·`쉴`)나 낯선 말투는 검색어에 섞일 수 있다. 사용자는 장소 선택 화면의 검색칸에서 고치거나 [번호 직접 입력]으로 넘어갈 수 있다. 실제 LLM(`OpenAiBrain`)이 내는 `placeQuery`의 품질은 가짜 `fetch` 시험으로만 확인했고 실제 호출로는 아직 보지 않았다.
- (sync 주석 2026-11-28) Android에서 위치 권한을 한 번 거부한 뒤 다시 "근처" 부탁을 하면 사전 안내가 다시 보인다(`checkPermission`의 `denied`를 "아직 안 물음"으로 읽음). OS 창이 다시 뜰지는 OS가 정하며 실기기에서 확인하지 않았다.

## 완료 정의 (Definition of Done)

- [ ] AC-001 ~ AC-022 모두 PASS, 명령 원문과 출력이 `progress.md` §E.2에 있음
- [ ] AC-004 증명 시험의 확인 1~6이 각각 단언으로 존재(이름 적힌 `expect`)
- [ ] 의도한 기존 시험 변경은 AC-022 표의 행뿐
- [ ] `server/src/services`·`brain`·`providers`·`store`·`domain`과 `app.test.ts` 무변경
- [ ] M5 패키지 확인 기록(`geolocator` 버전·라이선스·SwiftPM·최소 iOS)과 권한 선언 diff, 도구가 갱신한 iOS SwiftPM 파일 diff가 `progress.md`에 있음
- [ ] 개발 서버가 실제 통화를 하지 않는지 run 시작 전 소유자와 확인한 기록(D-11)
- [ ] 소유자 확인: 카카오 개발자 콘솔에서 앱의 카카오맵(로컬) API 사용 설정이 켜져 있고 REST API 키가 그 앱의 것임
- [ ] 소유자 확인 1건: 실제 카카오 키로 "강남역 파스타" 검색 → 후보 → 계획 카드(통화 시작 없이)까지, 서버 로그에 결과 내용이 없음. 실패하면 로그의 `status`(401 키 오류 / 403 사용 설정)를 기록
- [ ] 서식은 변경 파일에만 적용
- [ ] sync-phase 문서 항목(`plan.md` §G)이 manager-docs에 넘겨짐
- [ ] (0.2.0) AC-023·AC-024 PASS, RED 원문 `.moai/state/verify/SPEC-PLACE-001/red/amend_*.txt`
- [ ] (0.2.0) iOS `BYPASS_PERMISSION_LOCATION_ALWAYS`: 빌드 설정으로 넣을 수 없음을 실행으로 확인한 기록(`design.md` D11)이 있고, 배포 절차(`flutter clean && BYPASS_PERMISSION_LOCATION_ALWAYS=1 flutter build ipa`, 바이너리 `strings` 확인 0)가 sync 문서 항목으로 넘겨짐. 소유자가 첫 배포 빌드에서 `strings` 확인 1건

sync 주석(2026-11-28, 본문 기준은 바꾸지 않음):

- 첫 줄의 "AC-001 ~ AC-022"는 0.2.0 개정 뒤 AC-023·AC-024 줄과 합쳐 AC-001 ~ AC-024로 읽는다. run 결과 24 / 24 PASS(`progress.md` §E.2 "M7 최종 확인", §E.3).
- "`server/src/services`·`brain`·`providers`·`store`·`domain`과 `app.test.ts` 무변경" 줄은 0.1.x 범위의 기준이다. 0.2.0부터는 AC-022 Then이 기준이며, `providers`·`store`는 무변경, `services`·`brain`·`domain`은 `plan.md` §B.4 표의 파일만, `app.test.ts`는 `:699` 한 줄만 바뀌었다(`progress.md` §E.2 M7 범위).
- 남은 소유자 확인: 카카오 콘솔의 로컬 API 사용 설정과 실제 키 1건, 첫 배포 빌드의 `strings` 확인 0, Android 재요청 동작, 실기기 위치 권한 창, OD-3 법무 해석. 상태는 `progress.md` §E.4 `owner_checks_pending`에 있다.
