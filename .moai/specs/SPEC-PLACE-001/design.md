# SPEC-PLACE-001 설계 (0.1.1)

spec.md의 요구사항이 가리키는 계약·표·규칙을 모은다. 근거는 `research.md`(카카오 공식 문서 R1, 약관 답변 R2, 코드 조사 R3·R4), `docs/product/11_ARCHITECTURE.md` §4.2·§4.3, `docs/planning/04_DESIGN_PLAN.md` §7.2·§7.3·§17.1·§17.8.

## D1. `POST /v1/places/search` 계약 (REQ-002, REQ-003, REQ-007)

요청(JSON 본문, 검색어와 좌표를 URL에 싣지 않으려고 POST — 요청 로그는 URL만 남긴다, `app.ts:104-107`):

```json
{ "query": "강남역 파스타집", "near": { "lat": 37.4979, "lng": 127.0276 } }
```

| 필드 | 규칙 |
|---|---|
| `query` | 문자열, 공백 제거 뒤 1~100자. 어기면 400 `invalid_request`(지금의 ZodError 처리, 메시지에는 경로만 있고 값은 없음 — `app.ts:123-124`) |
| `near` | 선택. `lat` −90~90, `lng` −180~180 숫자. 모르는 필드는 버림 |

응답 200:

```json
{
  "source": "kakao",
  "places": [
    {
      "id": "26338954",
      "name": "라 파스타",
      "category": "양식",
      "address": "서울 강남구 테헤란로 12",
      "distanceM": 350,
      "phone": "02-111-0000",
      "phoneNumber": "+8221110000",
      "phoneCheck": "ok"
    }
  ]
}
```

| 필드 | 규칙 |
|---|---|
| `source` | `kakao` \| `simulated`. 앱은 모르는 값이면 출처 줄을 보이지 않는다(앞으로 제공자를 더할 때의 호환) |
| `places` | 0~5개, 제공자 순서 그대로 |
| `id` | 제공자 장소 ID(문자열). 앱은 화면 키로만 쓰고 저장하지 않음 |
| `category` | 카카오 `category_name`의 마지막 단계(`"음식점 > 양식 > 이탈리안"` → `"이탈리안"`), 비면 `null` |
| `address` | `road_address_name`, 비면 `address_name`, 둘 다 비면 `null` |
| `distanceM` | 정수 미터. `near`가 없거나 제공자가 주지 않으면 `null` |
| `phone` | 제공자가 준 원문, 비면 `null` |
| `phoneNumber` | `phoneCheck == "ok"`일 때 `checkTargetNumber`의 E.164, 아니면 `null` |
| `phoneCheck` | `phone`이 `null`이면 `missing`, 아니면 `checkTargetNumber(phone).kind`(`ok`·`invalid`·`blocked`) |

오류:

| 상태 | `error` | 언제 |
|---|---|---|
| 400 | `invalid_request` | 본문 검증 실패 |
| 401 | `unauthorized` | 토큰(지금 규칙 그대로) |
| 502 | `place_search_failed` | 제공자 시간 초과(5초), 2xx 아님, 형식 불일치, 그 밖의 어떤 예외(`TypeError` 등)든 |
| 503 | `place_search_unavailable` | 장소 검색이 꺼진 조립(OD-2) |

응답 머리: 200·502·503 모두 `Cache-Control: no-store`(R2의 "임시 저장 불허"를 서버 밖 중간 캐시까지 적용. 배포는 터널을 거침). 502·503 본문은 `{error, message}`이며 `message`는 고정 문구("Place search failed", "Place search is not available")다. 제공자 응답·예외 메시지를 싣지 않는다.

## D2. 포트와 조립 (REQ-001, REQ-008)

```ts
// server/src/places/types.ts
export interface PlaceQuery { keyword: string; near?: { lat: number; lng: number }; radiusM: number; limit: number }
export interface ProviderPlace {            // 제공자가 준 그대로의 모양(번호 판정 전)
  providerPlaceId: string; name: string; category: string | null; address: string | null;
  distanceM: number | null; phone: string | null;
}
export interface PlaceSearchProvider {
  readonly name: "kakao" | "simulated";
  search(query: PlaceQuery, signal: AbortSignal): Promise<ProviderPlace[]>;
}
export type PhoneCheck = "ok" | "invalid" | "blocked" | "missing";
export interface PlaceCandidate { id: string; name: string; category: string | null; address: string | null;
  distanceM: number | null; phone: string | null; phoneNumber: string | null; phoneCheck: PhoneCheck }
```

`server/src/places/placeSearch.ts`의 `createPlaceSearch(provider, { timeoutMs = 5000 } = {})`가 `{ source, search(body) }`를 만든다: `PlaceQuery`를 채우고(`limit` 5, `near`가 있으면 좌표를 소수 셋째 자리로 반올림 — 약 100m, `Math.round(v * 1000) / 1000` — 하고 `radiusM` 2000), `AbortController`와 `setTimeout(timeoutMs)`로 만든 신호를 넘겨 제공자를 부르고(끝나면 `clearTimeout`), 후보마다 `checkTargetNumber`로 `phoneCheck`를 붙인다. 제공자 호출과 정규화를 하나의 `try`로 감싸, 무엇이 던져지든 원래 예외를 `cause`로 달지 않고 메시지·속성을 옮기지 않은 새 `PlaceSearchError(kind)`(`kind` = `timeout` · `network` · `status` · `format` · `unexpected`, `status`일 때만 숫자 상태)만 밖으로 던진다. 상태(캐시·맵·카운터)를 갖지 않는다.

| 조건(`container.ts`) | `places` | 비고 |
|---|---|---|
| `KAKAO_REST_API_KEY` 있음 | `createPlaceSearch(new KakaoLocalPlaceSearch({apiKey, baseUrl, fetch?, logger}))` | 통화 제공자와 무관 |
| 키 없음, `config.provider === "simulated"` | `createPlaceSearch(new SimulatedPlaceSearch())` | 설계서 OD-K3 |
| 키 없음, `config.provider === "kat"` | `undefined` → 경로는 503 | OD-2 |

`AppDeps`에는 `places?: PlaceSearch | null`을 더한다(더하기만). 값이 `undefined`인 기존 테스트의 `buildApp` 호출은 경로가 503으로 답할 뿐 다른 동작이 같다. 시험에서 Fastify 로그를 붙잡기 위해 `logger?: boolean`을 `logger?: boolean | { stream: NodeJS.WritableStream }`로 넓힌다(기존 `false`·생략은 그대로). `stream`을 주면 운영 설정(`app.ts:102-108`의 `req` serializer, 기본 수준 `info`) **위에** `stream`만 더한다 — serializer와 수준을 바꾸지 않으므로, 증명 시험이 붙잡는 로그는 운영 로그와 같은 모양이다. 오류 처리기는 `PlaceSearchError`를 `request.log.error(error)`(`app.ts:136`)보다 먼저 잡아 `request.log.warn({ kind, status }, "Place search failed")`만 쓰고 502를 돌려준다.

`config.ts`에는 `KAKAO_REST_API_KEY: optional`, `KAKAO_LOCAL_BASE_URL: z.string().default("https://dapi.kakao.com")`를 더한다. `/v1/config` 응답은 바꾸지 않는다(`app.test.ts:455-490`이 키를 고정).

구조 규칙(`architecture.test.ts`에 더함):

1. `places/**/*.ts`(시험 파일 제외)의 상대 경로 import는 `../domain/`과 `../logger.js`(타입)뿐이고, 외부 패키지 import는 `zod`뿐이다. 특히 `from "../store/`, `from "../brain/`, `from "../services/`, `"node:fs"`, `"fs"`가 없다.
2. 같은 파일들에 `new Map(`, `new Set(`, `WeakMap`, `localStorage`, 모듈 수준 `let`이 없다(캐시 금지의 글자 대조).
3. `http/app.ts`에 `kakaoLocal`, `KakaoLocalPlaceSearch`, `simulatedPlaceSearch`, `dapi.kakao.com`이 없다.
4. `places/**/*.ts`에 `Record<string, any>`, `: any`, `as any`가 없다(외부 데이터, SPEC-ARCH-001 AC-012와 같은 방식).

## D3. 카카오 응답 → `ProviderPlace` (REQ-005)

공식 문서에서 확인한 필드(`research.md` R1)만 쓴다.

| 카카오 `documents[]` | 타입(문서) | `ProviderPlace` |
|---|---|---|
| `id` | String | `providerPlaceId` |
| `place_name` | String | `name`(공백만이면 그 문서를 버림) |
| `category_name` | String | `category` = `" > "`로 나눈 마지막 값, 비면 `null` |
| `road_address_name` / `address_name` | String | `address`(앞의 것 우선) |
| `phone` | String | `phone`, 빈 문자열이면 `null` |
| `distance` | String(미터, 좌표를 줄 때만) | `distanceM` = 정수로 읽히면 그 값, 아니면 `null` |
| `x`, `y`, `place_url`, `category_group_code`, `category_group_name` | — | 쓰지 않음(길찾기·카테고리 검색은 범위 밖). zod 스키마는 `passthrough` 없이 필요한 필드만 읽음 |
| `meta.total_count`·`pageable_count`·`is_end`·`same_name` | — | 쓰지 않음(1쪽만) |

요청 매개변수: `query`(검색어), `size=5`, `page=1`; `near`가 있으면 반올림한 `x=lng`, `y=lat`(D2), `radius=2000`, `sort=distance`. 없으면 `sort`를 보내지 않는다(기본 `accuracy`). 어댑터는 받은 `signal`을 `fetch`에 그대로 넘긴다.

오류 처리: 신호가 abort되어 `fetch`가 거절 → `PlaceSearchError("timeout")`; 그 밖의 `fetch` 거절 → `"network"`; 2xx 아님 → `("status", status)`(응답 본문은 읽지 않음); JSON 해석·zod 실패 → `"format"`; 그 밖의 예외 → `"unexpected"`(D2의 `createPlaceSearch`가 마지막으로 감쌈). 어느 경우든 원래 예외를 `cause`로 달지 않는다. 어댑터는 `logger.warn({ provider: "kakao", kind, status }, "Place search failed")` 한 줄만 쓴다(본문·검색어·좌표·원래 메시지 없음). `status`로 401(키 오류)과 403(콘솔의 카카오맵 API 사용 설정이 꺼졌거나 권한 없음 — 확인 못 함, R6)을 구분해 진단할 수 있다. 경로는 이를 502로 바꾼다. 쿼터 초과(429 등) 전용 처리는 하지 않는다(응답 형식 미확인, R6).

## D4. 저장·캐시·로그 금지 증명 (REQ-004, 에픽 D-8)

시험 파일 `server/src/http/places.test.ts`, 이름 "place search results never reach storage, cache, events or logs".

준비:

- 임시 디렉터리(`mkdtemp`)의 `DATA_FILE`로 `JsonFileTaskStore.open`, 작업 하나를 만들어 둠(빈 파일과 구별).
- 가짜 `fetch`: 호출을 기록하고, 표식 값으로 채운 카카오 응답을 돌려줌 — `place_name` `"표식장소-7f3a"`, `phone` `"02-555-0142"`, `road_address_name` `"표식로 77"`, `id` `"PID-9c1e"`, `x` `"127.0276"`, `y` `"37.4979"`, `distance` `"350"`.
- `KakaoLocalPlaceSearch({ apiKey: "test-kakao-key", fetch, logger: 붙잡는 로거 })`.
- `buildApp({ ..., places, logger: { stream: 붙잡는 스트림 } })` — 운영 serializer와 `info` 수준 위에 스트림만 더한 설정(D2)으로 Fastify 로그를 붙잡음. `console.log`·`console.error`·`process.stdout.write`도 `vi.spyOn`으로 붙잡음.
- `bus.subscribe`로 이벤트 수를 셈.
- 저장소 파일의 바이트와 임시 디렉터리 목록을 기록.

동작(같은 검색어 `"표식검색어-41b2"`, `near {lat: 37.4979, lng: 127.0276}`로 다섯 번):

- (a)(b) 정상 응답으로 같은 요청 두 번.
- (c) 가짜 `fetch`가 500과 표식 본문(`"표식오류본문-d00d"`)을 돌려줌.
- (d) 가짜 `fetch`가 표식을 담은 예상 못 한 예외를 던짐: `Object.assign(new TypeError("표식예외-e1e1"), { input: "https://dapi.kakao.com/v2/local/search/keyword.json?query=표식검색어-41b2", code: "ERR_INVALID_URL" })`.
- (e) 가짜 `fetch`가 200과 형식이 틀린 본문 `{"documents": [{"place_name": "표식형식-f0f0", "id": 7}]}`을 돌려줌.

확인:

1. 처음 두 응답은 200이고 표식 이름·번호 원문·주소가 들어 있다(결과는 응답으로는 간다).
2. 가짜 `fetch` 호출 수가 5다(같은 요청도 매번 제공자 호출, 캐시 없음). 첫 호출의 URL이 `https://dapi.kakao.com/v2/local/search/keyword.json`으로 시작하고, 좌표 매개변수가 반올림된 `x=127.028`, `y=37.498`이며, `Authorization` 머리가 `KakaoAK test-kakao-key`다. 모든 응답에 `Cache-Control: no-store`가 있다.
3. (c)(d)(e) 응답은 모두 502 `place_search_failed`이고 본문은 D1의 고정 문구뿐이다(400 `invalid_request`가 아님 — 형식 오류의 zod 이슈가 전역 처리기로 새지 않음).
4. 붙잡은 모든 출력(Fastify 스트림, 어댑터 로거, `console`, `stdout`)과 (c)(d)(e)의 응답 본문을 합친 글자에 다음이 하나도 없다: 표식 이름, `"02-555-0142"`, `"+8225550142"`, 표식 주소, `"PID-9c1e"`, 표식 검색어, `"37.4979"`, `"127.0276"`, `"37.498"`, `"127.028"`, 표식 오류 본문, `"표식예외-e1e1"`, `"ERR_INVALID_URL"`, `"표식형식-f0f0"`, `"test-kakao-key"`. 상태 코드 `500`과 `kind` 값은 있어도 된다.
5. 저장소 파일 바이트와 디렉터리 목록이 처음과 같고, `store.list()`가 준비 때의 작업 하나뿐이다.
6. 이벤트 수가 0이다.

구조 규칙 D2-1·2와 함께, "저장하지 않는다"를 실행 결과(5·6)와 소스 글자(D2) 양쪽에서 본다.

## D5. 앱 흐름과 경로 (REQ-009, REQ-015)

```
/assistant (A01) ─ 접수: missing에 phoneNumber, 차단 아님 → /assistant/places (H02) ─[여기로 전화]→ /assistant/plan (H04)
                 └ 그 밖(번호 있음·차단·404 대체) ─────────────────────────────────────→ /assistant/plan (H04)
H02 ─[상세]→ H03(아래 시트, 경로 아님) ─[여기에 물어보기]→ /assistant/plan
H02 ─[번호 직접 입력]→ /assistant/plan (접수 초안 그대로)
뒤로: H04 → H02(목록 그대로) → A01(문장 그대로) → 닫힘
```

- `/assistant/places`는 `/assistant`의 자식 경로다(SPEC-ASSIST-001 REQ-009, SHELL research R1-G3). `extra`는 `kolbi_core`의 `PlaceSearchStart{draft, requestText, keyword, nearby}`. `extra`가 없으면 `/assistant`로 돌려보낸다(지금의 `assistantPlan` 방식, `app_router.dart:124-125`).
- 비서는 `features/places`를 가져오지 않는다(기능 간 import 금지, 허용 목록 비어 있음 — `architecture_test.dart:8`). 이동은 `shell/navigation.dart`의 `openAssistantPlaces(router, start)`로 하고, 저장소 공급자는 셸의 새 파일 `shell/place_search.dart`가 `apiClientProvider`로 만든다(`request_intake.dart`와 같은 다리).
- 접수 결과 판단에는 `missing`이 필요하므로 `requestPlanDraft`(`request_intake.dart:28-46`)를 `IntakeResult?`를 돌려주는 `requestIntake`로 바꾼다. 404 대체는 `IntakeResult(draft: PlanDraft.blank(text))`(빈 `missing`)라서 계획 카드로 간다. 가짜 저장소의 기본 응답도 `missing`이 비어 있어(`fakes.dart:118`) 기존 비서·접수 테스트는 계획 카드로 간다.
- 고른 후보로 만든 초안: `PlanDraft`에 `copyWith`를 더하지 않고 생성자로 새로 만든다 — 접수 초안의 `goal`·`conditions`·`context`·`language`·`source`는 그대로, `targetName`·`phoneNumber`·`phoneSource: PhoneSource.search`만 바꾸고 `numberBlocked`는 `false`.

## D6. 첫 검색어와 "근처" (REQ-010)

`kolbi_core` `src/places/place_intent.dart`:

```dart
PlaceSearchStart? placeSearchStartFor(String requestText, IntakeResult result);
```

- `result.missing`에 `phoneNumber`가 없거나 `result.draft.numberBlocked`이면 `null`.
- `nearby`: 문장을 공백으로 나눈 낱말 가운데 `근처`·`주변`이 맨 앞이거나 바로 앞 낱말이 `내`·`여기`·`이`이면, 또는 `가까운`으로 시작하는 낱말이 있으면 `true`. "강남역 근처"처럼 앞에 장소 이름이 있으면 `false`.
- `keyword`: 초안 `targetName`이 있으면 그 값에서 `근처`·`주변` 낱말을 뺀 것. 없으면 문장 규칙:
  1. 쉼표 앞까지만 본다.
  2. 낱말을 앞에서부터 읽으며 날짜·시각·인원 낱말(`오늘`·`내일`·`모레`·`이번`·`다음`, `…요일`, 숫자+`시`·`분`·`명`)과 `근처`·`주변`·`가까운…`·`내`·`여기`는 건너뛴다.
  3. 요청 낱말(`예약…`·`문의…`·`확인…`·`물어봐…`·`알아봐…`·`전화…`·`찾아…`·`부탁…`·`해`·`해줘`·`해주세요`·`중에`·`있는`·`몇`·`…까지`·`…하는지`·`…있는지`)이나 `줘`·`주세요`로 끝나는 낱말을 만나면 멈춘다.
  4. `에서`·`에게`·`에`로 끝나는 낱말은 조사를 떼고 담은 뒤 거기서 멈춘다("꽃집에" → "꽃집", 다음 낱말은 보지 않음).
  5. 담은 낱말 끝의 조사 `의`·`을`·`를`을 떼고 공백 하나로 잇는다. 30자를 넘으면 30자에서 자른다. 비면 빈 문자열.

| 문장(초안 이름 없음, 번호 없음) | keyword | nearby |
|---|---|---|
| 강남역 근처 파스타집, 금요일 7시 2명 예약해 줘 | `강남역 파스타집` | false |
| 근처 약국 오늘 몇 시까지 하는지 물어봐 줘 | `약국` | true |
| 내일 치과 예약 바꿔 줘 | `치과` | false |
| 내 주변 세탁소 문의해 줘 | `세탁소` | true |
| 가까운 꽃집에 장미 있는지 알아봐 줘 | `꽃집` | true |
| 해 줘 | (빈 값) | false |

여섯 줄 모두 고정 기대값이다. 초안 이름이 있는 경우: 이름 `라 파스타`, 문장 "라 파스타에 금요일 예약해 줘" → (`라 파스타`, false). 규칙이 놓친 검색어는 사용자가 검색칸에서 고친다.

## D7. 화면 문구와 상태 (REQ-011~REQ-016)

| 자리 | 문구 |
|---|---|
| H02 제목 | 장소 선택 |
| 부탁 줄 | ✦ {부탁 문장} + [고치기] |
| 검색칸 힌트·버튼 | "어디에 전화할까요?" · [다시 찾기] |
| 결과 문장 | {검색어} {n}곳을 찾았어요 |
| 로딩 | {검색어}을(를) 찾는 중이에요(조사는 `withSubjectParticle`과 같은 방식의 받침 판단, 목적격) + 뼈대 카드 3개 |
| 결과 없음 | 조건에 맞는 곳을 찾지 못했어요 |
| 실패(502·네트워크) | 장소를 찾지 못했어요. 잠시 뒤 다시 시도해 주세요 + [다시 시도] |
| 꺼짐(503) | 지금은 장소 찾기를 쓸 수 없어요 |
| 걸 수 있는 곳 없음 | 전화할 수 있는 곳이 없어요 |
| 출처 | kakao: 장소 정보는 카카오 로컬 검색 결과예요 / simulated: 연습용 장소예요. 실제 가게가 아니에요 |
| 카드 상태 글자 | 걸 수 있음 · 번호 없음 · 걸 수 없는 번호 |
| 비활성 이유 | missing: 번호가 없어 전화할 수 없어요 / invalid·blocked: 걸 수 없는 번호예요 |
| 추천 이유 | 첫 후보에 거리가 있으면 "가장 가까워요"(칩). 그 밖에는 붙이지 않음(받지 않은 근거 금지, 04 §7.2) |
| 카드 버튼 | [상세] · [여기로 전화] |
| 하단 | 찾는 곳이 없나요? [번호 직접 입력] |
| H03 | 제목 = 이름, 분류 · 거리, 주소, 번호 원문 + [번호 복사], [여기에 물어보기](주 버튼), [닫기] |
| 위치 사전 안내 | 근처 가게를 찾으려면 지금 위치가 필요해요. 가까운 가게를 찾는 데만 써요. 콜비는 위치를 저장하지 않아요. + [계속] |
| iOS `NSLocationWhenInUseUsageDescription` | 가까운 가게를 찾는 데만 써요. 콜비는 위치를 저장하지 않아요. |
| 위치 거부 | 동네 이름을 알려 주세요(입력칸, 힌트 "예: 망원동") + [찾기] |
| 다시 묻지 않음 | 설정에서 위치 권한을 켜면 근처를 찾을 수 있어요 + [설정 열기] |

거리 표시: 1,000m 미만은 `350m`, 이상은 소수 첫째 자리 `1.2km`. 읽기 문구는 `350미터`·`1.2킬로미터`. 후보 카드 읽기 단위: "{이름}, {분류}, {거리}, {상태 글자}"(값이 없으면 그 조각을 뺌).

## D8. 위치 흐름 (REQ-016, REQ-017)

```dart
// app/lib/features/places/location/location_reader.dart (설계용)
enum LocationAccess { notDetermined, granted, denied, deniedForever, unavailable }
abstract interface class LocationReader {
  Future<LocationAccess> access();
  Future<LocationAccess> request();          // OS 창
  Future<({double lat, double lng})?> readOnce({Duration timeLimit = const Duration(seconds: 10)});
  Future<void> openSettings();
}
```

| `access()` | 화면 |
|---|---|
| `notDetermined` | 사전 안내 → [계속] → `request()` → 허용이면 `readOnce`, 아니면 동네 이름 칸 |
| `granted` | 사전 안내 없이 `readOnce` |
| `denied` | 동네 이름 칸 |
| `deniedForever` | 동네 이름 칸 + 설정 안내 + [설정 열기] |
| `unavailable`(플러그인 없음·위치 서비스 꺼짐, 시험 환경 포함) | 동네 이름 칸 |

`readOnce`가 `null`이거나 시간을 넘기면 동네 이름 칸. 좌표는 검색 요청 하나에만 쓰고 상태·`SharedPreferences`에 두지 않는다. `nearby`가 `false`면 `LocationReader`를 부르지 않는다.

## D9. 대표번호 표시 (REQ-003, REQ-015)

서버 `checkTargetNumber`는 `"1588-0000"`을 `{ok, "+15880000"}`으로 판정하고(SPEC-POLICY-001의 기존 동작, `domain.test.ts:115`), 실제로 거는 숫자는 `toDomesticDialString`이 만드는 `15880000`이다. 서버 `domain`은 바꾸지 않는다. 화면만 고친다.

`packages/kolbi_core/lib/src/format/formatters.dart`의 `formatPhone`에 규칙 하나를 `+82` 처리 앞에 더한다: 값이 `+1` 뒤에 숫자가 정확히 7자리이고 그 첫 숫자가 `5`·`6`·`8`이면(`^\+1([568]\d{6})$`, 북미 번호는 `+1` 뒤 10자리라 겹치지 않음) `1{앞 세 자리}-{뒤 네 자리}`로 보인다.

| 입력 | 출력 |
|---|---|
| `+15880000` | `1588-0000` |
| `+16441234` | `1644-1234` |
| `+18001234` | `1800-1234` |
| `+14155550100` | `+14155550100`(그대로, 기존 시험 `unit_test.dart:15`) |
| `+17001234` | `+17001234`(첫 숫자 7은 해당 없음) |
| `+821012345678` | `010-1234-5678`(그대로) |

계획 카드의 번호 줄(`plan_card_screen.dart:194`)은 `formatPhone`을 쓰므로 고칠 곳이 없다. 만들기 요청의 `phoneNumber`는 E.164 `+15880000` 그대로다.
