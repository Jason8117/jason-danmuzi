# SPEC-PLACE-001 구현 계획 (0.2.0 — 소유자 화면 검토 뒤 개정)

검토 순서 안내: 바뀔 가능성이 큰 결정(서버 계약과 저장 금지 증명, 키가 없을 때의 동작, 비서에서 장소 선택으로 가는 조건, 위치 권한 흐름)을 앞에, 화면 문구·권한 선언·기존 테스트 문구 수정 같은 기계적 작업을 뒤에 둔다. 계약과 표는 `design.md`, 근거와 줄 번호는 `research.md`다.

## A. 접근 방식

### A.0 서버 계약과 저장 금지를 먼저 정하는 이유

앱 화면·상태·시험이 모두 응답 모양(`design.md` D1)에 기댄다. 또 "결과를 남기지 않는다"는 나중에 덧붙이기 어려운 성질이라, 경로를 처음 만들 때 증명 시험(D4)부터 쓰고(RED) 그 시험을 통과하도록 모듈을 만든다. 그래서 M1이 서버 모듈(두 제공자 포함)과 증명 시험이다.

### A.1 서버 `places` 모듈 (REQ-001~REQ-008)

- 설계서 §4.3의 포트를 그대로 쓰되, 번호 판정은 제공자가 아니라 `placeSearch.ts` 한 곳에서 한다(두 제공자가 같은 규칙을 지나게). 제공자는 `ProviderPlace`(번호 원문)만 돌려준다.
- 카카오 어댑터는 KAT 제공자처럼 `fetch`를 주입받는다(`katProvider.ts:25-26`). 응답은 zod 스키마로 읽고 `any`를 쓰지 않는다(SPEC-ARCH-001 규칙과 같은 방식의 구조 규칙을 더함).
- 경로 `POST /v1/places/search`는 `app.ts`의 `/v1/intake` 옆에 둔다. 검증 → `places.search` → 응답(`Cache-Control: no-store`). `createPlaceSearch`는 제공자 호출과 정규화에서 나는 모든 예외를 원인 없이 `PlaceSearchError`로 감싸고(D2), 오류 처리기는 이를 `request.log.error(error)`(`app.ts:136`)보다 먼저 잡아 종류·상태만 경고로 남기고 502로 바꾼다. 그래서 예상 못 한 예외(메시지·`input` 속성에 검색어가 든 `TypeError` 등)도, 형식 오류의 zod 이슈도 로그·응답에 나가지 않는다.
- 시간 제한은 `AbortController` + 주입 가능한 `timeoutMs`(기본 5000)로 만든다. 시험은 가짜 시계 대신 `timeoutMs`를 작게 주거나 직접 abort한다.
- 좌표는 서버가 카카오로 넘기기 전에 소수 셋째 자리로 반올림한다(약 100m, D2).
- 키가 없고 실제 통화 서버면 경로는 503(OD-2). 이 판단은 `container.ts`만 한다.
- 시험에서 Fastify 로그를 붙잡을 수 있게 `AppDeps.logger`를 넓힌다(D2). 스트림은 운영 serializer와 `info` 수준 위에 더하기만 하므로 운영 동작과 로그 모양이 같다.

### A.2 앱 분기 (REQ-009, REQ-010)

- `request_intake.dart`의 `requestPlanDraft`를 `requestIntake`(`IntakeResult?` 반환)로 바꾸고, 비서의 `_submit`(`assistant_screen.dart:123-140`)은 `placeSearchStartFor(text, result)`가 값을 주면 `openAssistantPlaces`, 아니면 지금처럼 `openAssistantPlan`.
- 404 대체와 가짜 저장소 기본값은 `missing`이 비어 있어 계획 카드로 간다(research R4). 기존 비서·접수 시험을 고치지 않는 이유다.
- 검색어·"근처" 규칙은 `kolbi_core` 순수 함수(D6)로 두어 Dart 단위 시험으로 고정한다.

### A.3 장소 선택·상세 화면 (REQ-011~REQ-015)

- `features/places/place_search_screen.dart`(SCR-H02)는 `PlaceSearchController`(Riverpod `Notifier`, 상태: `idle(keyword)` · `needLocation` · `askArea(foreverDenied)` · `loading` · `results(source, places)` · `empty` · `failed(unavailable)`)를 본다. 후보 카드(CMP-05)와 상세 시트(CMP-06)는 같은 기능 안의 위젯 파일이다.
- 고른 후보로 초안을 새로 만들어(D5) `openAssistantPlan`. 장소 선택 화면은 비서 위에 쌓이고 계획 카드는 그 위에 쌓인다(뒤로 = 목록 그대로).
- 출처 줄은 응답 `source`로 정한다. `/v1/config`를 바꾸지 않는다(`app.test.ts:455-490` 고정).

### A.4 위치 (REQ-016~REQ-018)

- 비서의 받아쓰기 포트와 같은 방식: 앱 안 포트 `LocationReader`(D8)와 실제 구현 `PlatformLocationReader`(`geolocator`), 시험은 `FakeLocationReader`. 플러그인이 없으면(`MissingPluginException`) `unavailable`로 알려 동네 이름 칸으로 간다 — 가짜를 넣지 않은 시험에서도 예외가 없다.
- 사전 안내 시트(CMP-23)는 비서의 마이크 안내(`mic_consent_sheet.dart`)를 가져오지 않고(기능 간 import 금지) 장소 기능 안에 위치용으로 새로 둔다. 모양은 같게.
- 좌표는 검색 요청 하나에만 쓴다. 대략 위치(`LocationAccuracy.low`), 10초 제한.

### A.5 계획 카드와 오늘 (REQ-019, REQ-020)

- `PhoneSource.search('검색 결과')`를 더한다(서버는 보내지 않음, `previousCall`과 같은 앱 전용 값).
- 언어·내 이름 두 행을 한 줄로 접되 두 글자는 각각 따로 누르게 둔다(OD-10). `plan_card_test.dart:117`, `shell_test.dart:289`가 그대로 통과해야 한다.
- 묶음 제목 두 곳만 바꾼다(`home_screen.dart:147`, `request_box.dart:93`).

### A.6 접수가 장소 검색어를 준다 (0.2.0, REQ-010·REQ-023·REQ-024)

- 화면 검토(2026-11-28)에서 "근처 치과 내일 오전 예약해 줘" → 검색어 "치과 오전"이 나왔다. 소유자 결정: 서버 AI가 검색어도 뽑는다(OD-7 개정). 날짜·시각은 부탁 문장에 남고 검색어에서만 빠진다.
- 서버: `IntakeContent.placeQuery?`(선택), LLM 프롬프트·관대한 스키마, 서비스 후처리(번호 지움·`근처` 빼기·30자)와 결정적 대체 규칙(`domain/placeQuery.ts`). 휴리스틱 두뇌 자체는 바꾸지 않고 서비스가 규칙을 적용한다 — 휴리스틱 두뇌·LLM 실패 대체·`draftIntake` 없는 두뇌가 모두 같은 규칙을 지나고, 기존 두뇌 시험의 `toEqual`이 그대로 통과한다.
- 앱: `IntakeResult.placeQuery`, `placeSearchStartFor`가 `placeQuery`를 먼저 쓰고 없으면 대체 규칙(같은 시간 낱말, "근처" 판단은 시간 낱말 뒤의 `근처`도 인정). 비서 화면은 이미 `placeSearchStartFor(text, result)`를 부르므로 코드 변경이 없다.
- 시험 먼저(RED): 서버 `domain/placeQuery.test.ts`(공유 예시 표), `places.test.ts`의 접수 블록(경로·후처리·로그 금지), `openaiBrain.test.ts` 끝에 더한 프롬프트·스키마 시험, `app.test.ts:699` 키 목록; 앱 `kolbi_core/test/places_test.dart` 예시 표 확장과 `placeQuery` 우선, `app/test/places_test.dart`의 비서 → 검색어 시험.

## B. 변경 파일 (74a87c3 기준으로 확인)

### B.1 서버

| 파일 | 변경 | 이유 |
|------|------|------|
| `server/src/places/types.ts` | 새 파일 | 포트, `PlaceQuery`, `ProviderPlace`, `PlaceCandidate`, `PhoneCheck`, `PlaceSearchError`(REQ-001) |
| `server/src/places/placeSearch.ts` | 새 파일 | `createPlaceSearch`: 질의 채우기·시간 제한·`checkTargetNumber` 판정(REQ-002, REQ-003) |
| `server/src/places/kakaoLocalPlaceSearch.ts` | 새 파일 | 카카오 어댑터와 zod 응답 스키마(REQ-005) |
| `server/src/places/simulatedPlaceSearch.ts` | 새 파일 | 연습용 후보 5곳(REQ-006) |
| `server/src/places/placeSearch.test.ts` | 새 파일 | 번호 판정·질의 채우기·시뮬레이션 |
| `server/src/places/kakaoLocalPlaceSearch.test.ts` | 새 파일 | 요청 URL·머리·매개변수, 응답 옮기기, 오류 종류(가짜 `fetch`, `AbortController`로 직접 abort) |
| `server/src/http/places.test.ts` | 새 파일 | 경로 계약, 401·400·502·503, 저장 금지 증명(D4) |
| `server/src/http/app.ts` | 수정 | `AppDeps.places`(`:15-24`), 로그 스트림 옵션(`:98-109`), 오류 처리기에 `PlaceSearchError`(`:122-138`), 경로 추가(`:166-170` 옆) |
| `server/src/http/schemas.ts` | 수정(더하기) | `PlaceSearchBody` |
| `server/src/container.ts` | 수정 | 장소 제공자 선택(D2 표), `Container.places`(`:13-20`, `:64`) |
| `server/src/config.ts` | 수정(더하기) | `KAKAO_REST_API_KEY`, `KAKAO_LOCAL_BASE_URL`(`:8-32`) |
| `server/src/index.ts` | 수정 | `places`를 `buildApp`에 넘김(`:10`, `:14`), 기동 로그에 `placeSearch: "kakao" \| "simulated" \| "off"`(키 값 없음) |
| `server/src/architecture.test.ts` | 수정(더하기만) | D2 구조 규칙 네 개(REQ-008) |
| `server/.env.example` | 수정(더하기) | `KAKAO_REST_API_KEY=` 한 줄과 설명 주석(값 없음) |

### B.2 `kolbi_core`

| 파일 | 변경 | 이유 |
|------|------|------|
| `packages/kolbi_core/lib/src/models/place_models.dart` | 새 파일 | `Place`, `PlacePhoneCheck`, `PlaceSearchSource`, `PlaceSearchResult`, `PlaceSearchStart`, JSON 해석(모르는 값에 예외 없음) |
| `packages/kolbi_core/lib/src/data/places_repository.dart` | 새 파일 | `PlacesRepository.search(query, {near})` → `POST /v1/places/search` |
| `packages/kolbi_core/lib/src/places/place_intent.dart` | 새 파일 | `placeSearchStartFor`(D6) |
| `packages/kolbi_core/lib/src/models/intake_models.dart` | 수정(더하기) | `PhoneSource.search('검색 결과')`(`:6-15`) |
| `packages/kolbi_core/lib/kolbi_core.dart` | 수정 | 새 공개 이름 |
| `packages/kolbi_core/lib/src/format/formatters.dart` | 수정 | `formatPhone`에 대표번호 표시 규칙(`design.md` D9, `:4-18`) |
| `packages/kolbi_core/test/places_test.dart` | 새 파일 | JSON 해석, D6 예시 표, 저장소 요청 모양, `formatPhone` 대표번호 표(D9) |

### B.3 앱

| 파일 | 변경 | 이유 |
|------|------|------|
| `app/lib/features/places/place_search_screen.dart` | 새 파일 | SCR-H02(REQ-011, REQ-012) |
| `app/lib/features/places/place_search_controller.dart` | 새 파일 | 상태 관리(A.3) |
| `app/lib/features/places/place_card.dart` | 새 파일 | CMP-05(REQ-011, REQ-013, REQ-021) |
| `app/lib/features/places/place_detail_sheet.dart` | 새 파일 | SCR-H03·CMP-06(REQ-014) |
| `app/lib/features/places/location_consent_sheet.dart` | 새 파일 | CMP-23 위치(REQ-016) |
| `app/lib/features/places/location/location_reader.dart` | 새 파일 | 위치 포트(D8) |
| `app/lib/features/places/location/platform_location_reader.dart` | 새 파일 | `geolocator` 감싸기(REQ-017) |
| `app/lib/shell/place_search.dart` | 새 파일 | `placesRepositoryProvider`, `locationReaderProvider`(셸 다리, D5) |
| `app/lib/shell/routes.dart` | 수정 | `assistantPlaces`(`:13-16` 옆) |
| `app/lib/shell/app_router.dart` | 수정 | `/assistant/places` 자식 경로(`:120-139`) |
| `app/lib/shell/navigation.dart` | 수정 | `openAssistantPlaces`(`:58-71` 옆) |
| `app/lib/shell/request_intake.dart` | 수정 | `requestPlanDraft` → `requestIntake`(`:26-46`), 주석 "최근 장소"(`:18`) |
| `app/lib/features/assistant/assistant_screen.dart` | 수정 | 분기(`:123-140`) |
| `app/lib/features/assistant/request_box.dart` | 수정(두 줄) | "최근 장소"(`:93`), 주석(`:9`) |
| `app/lib/features/calls/presentation/home_screen.dart` | 수정(한 줄과 주석 셋) | "최근 장소"(`:147`), 주석(`:19`, `:133`, `:166`) |
| `app/lib/features/calls/presentation/plan_card_screen.dart` | 수정 | 접힌 줄(`:261-272`), 출처는 `PhoneSource.label`이라 자동(`:195-200`) |
| `app/pubspec.yaml` | 수정 | `geolocator` |
| `pubspec.lock`(저장소 루트) | 갱신 | 위 의존(워크스페이스 잠금 하나) |
| `app/ios/Runner/Info.plist` | 수정 | `NSLocationWhenInUseUsageDescription`(`:69-72` 옆), 문구 "가까운 가게를 찾는 데만 써요. 콜비는 위치를 저장하지 않아요." |
| `app/ios/Runner.xcodeproj/project.pbxproj`, `app/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`, `app/ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved` | 도구가 갱신(허용) | `geolocator`를 더하면 Flutter·Xcode의 SwiftPM 통합이 고칠 수 있는 추적 파일. 손으로 고치지 않고, 바뀌면 diff를 `progress.md`에 기록. Android·그 밖의 플랫폼에서 도구가 바꾸는 추적 파일도 같은 규칙 |
| `app/android/app/src/main/AndroidManifest.xml` | 수정 | `ACCESS_COARSE_LOCATION`(`:2-4` 옆) |
| `app/test/support/fake_places_repository.dart` | 새 파일 | 가짜 저장소(응답·오류·보류·호출 기록) |
| `app/test/support/fake_location_reader.dart` | 새 파일 | 가짜 위치 |
| `app/test/places_test.dart` | 새 파일 | 분기·화면·상태·선택·상세·위치·접근성 |
| `app/test/architecture_test.dart` | 수정(더하기만) | 위치 패키지 경계, 위치 권한 선언 |
| `app/test/today_test.dart`, `assistant_test.dart`, `accessibility_test.dart`, `intake_flow_test.dart` | 수정(이름 적은 줄) | "최근 장소"(AC-022 표) |

합계: 서버 14(새 7, 수정 7), `kolbi_core` 7(새 4, 수정 3), 앱 28(새 11, 수정 16, 잠금 파일 1) — 49개 파일, 그리고 도구가 갱신하는 iOS SwiftPM 산출 파일(최대 3개). 새 로직은 서버 모듈·증명 시험·장소 화면 셋·컨트롤러·위치 포트이고, 나머지는 연결·선언·문구 한 줄이다.

### B.4 0.2.0 개정에서 더하는 변경 (M7)

| 파일 | 변경 | 이유 |
|------|------|------|
| `server/src/domain/types.ts` | 수정(더하기) | `IntakeContent.placeQuery?: string`, `IntakeResult.placeQuery: string \| null`(REQ-023) |
| `server/src/domain/placeQuery.ts` | 새 파일 | 결정적 규칙 `placeQueryFor(text, targetName)`, `cleanPlaceQuery`(D6·D10) |
| `server/src/domain/placeQuery.test.ts` | 새 파일 | 공유 예시 표(D6), 후처리 |
| `server/src/brain/prompts.ts` | 수정 | `INTAKE_SYSTEM_PROMPT`에 `placeQuery` 키(D10) |
| `server/src/brain/openaiBrain.ts` | 수정 | `IntakeSchema`에 관대한 `placeQuery`, 값이 있을 때만 결과에 넣음 |
| `server/src/brain/openaiBrain.test.ts` | 수정(파일 끝 더하기만) | 프롬프트·스키마 시험 |
| `server/src/services/callService.ts` | 수정 | `draftIntake` 후처리와 대체 규칙(D10) |
| `server/src/http/places.test.ts` | 수정(이 SPEC의 새 파일, 블록 더함) | 접수 경로의 `placeQuery`와 로그·저장 금지(AC-023, AC-024) |
| `server/src/http/app.test.ts` | 수정(한 줄) | `:699` 응답 키 목록에 `placeQuery`(AC-022 표) |
| `packages/kolbi_core/lib/src/models/intake_models.dart` | 수정(더하기) | `IntakeResult.placeQuery` |
| `packages/kolbi_core/lib/src/places/place_intent.dart` | 수정 | `placeQuery` 우선, 시간 낱말, "근처" 판단(D6) |
| `packages/kolbi_core/test/places_test.dart` | 수정(이 SPEC의 새 파일) | 예시 표 12줄, `placeQuery` 우선·JSON 해석 |
| `app/test/places_test.dart` | 수정(이 SPEC의 새 파일, 시험 더함) | 비서가 접수 `placeQuery`로 검색 |
| iOS 배포 빌드 절차 | 문서만(`design.md` D11) | `BYPASS_PERMISSION_LOCATION_ALWAYS=1`은 SwiftPM 매니페스트 환경 변수로만 먹고 빌드 설정으로는 닿지 않음을 실행으로 확인 — 설정 파일 변경 없음. sync에서 README·`tech.md`의 배포 절차에 옮김 |

합계(0.2.0): 서버 9(새 2, 수정 7), `kolbi_core` 3, 앱 1 — 13개 파일. 앱 `lib`는 바뀌지 않는다(`assistant_screen.dart`는 이미 `placeSearchStartFor(text, result)`를 씀).

### B.5 손대지 않는 것

`server/src/providers/**`, `store/**`, `services/**`·`brain/**`·`domain/**`의 B.4 밖 파일, `brain/heuristicBrain.ts`(규칙은 서비스가 적용), `/v1/intake`의 요청과 `placeQuery` 밖 응답, `/v1/config`·WebSocket, `app/lib/features/assistant/speech/**`, `kolbi_ui`, 다른 SPEC 디렉터리, `.moai/harness/*`·`.moai/state/*`, `server/.env`(읽지도 않음).

## C. 마일스톤 (우선순위 순, 하나씩 순서대로)

### M1 — 서버 계약과 저장 금지 증명 (Priority High)

`places.test.ts`의 D4 증명 시험과 계약 시험을 먼저 쓰고(RED), 포트·`placeSearch.ts`(감싸기·반올림·시간 제한)·카카오 어댑터(가짜 `fetch`)·시뮬레이션 제공자·경로·오류 처리·로그 스트림 옵션을 만든다. 구조 규칙을 더한다. AC-002~AC-006, AC-008.

### M2 — 조립과 꺼짐 (Priority High)

`config.ts`·`container.ts`·`index.ts`, 503 경로, `.env.example`. AC-001, AC-007.

### M3 — `kolbi_core`와 비서 분기 (Priority High)

모델·저장소·`placeSearchStartFor`(예시 표 먼저), `PhoneSource.search`, `formatPhone` 대표번호 규칙(표 먼저), `requestIntake`, 비서 분기, 경로·이동 도우미. AC-009, AC-010, AC-003의 앱 표시 부분.

### M4 — 장소 선택·상세 (Priority High)

컨트롤러(RED 먼저), H02, CMP-05, H03, 선택 → 계획 카드. AC-011~AC-015.

### M5 — 위치 (Priority Medium)

첫 작업: `geolocator` 확인(버전·라이선스·SwiftPM 지원·최소 iOS 15.0 이하 여부·`permission_handler`와의 공존)을 `progress.md`에 기록(spec §4·OD-8과 같은 시점). 그다음 위치 포트·실제 구현·사전 안내·동네 이름 칸, 권한 선언, 의존 규칙. AC-016~AC-018.

### M6 — 계획 카드·문구·접근성·회귀 (Priority Medium)

접힌 줄, "최근 장소"와 이름 적은 시험 수정, 접근성 지침, 전체 회귀와 범위 확인. AC-019~AC-022.

### M7 — 접수의 장소 검색어 (0.2.0, Priority High)

RED 먼저(서버 규칙 표·경로·두뇌, 앱 예시 표·`placeQuery` 우선·비서 시험, 원문 `.moai/state/verify/SPEC-PLACE-001/red/amend_*.txt`) → 서버 타입·규칙·프롬프트·스키마·서비스 → `kolbi_core` 모델·규칙. iOS `BYPASS_PERMISSION_LOCATION_ALWAYS`는 D11대로 문서. AC-010, AC-022, AC-023, AC-024.

## D. 위험 요소

| 위험 | 대응 |
|---|---|
| 카카오 `phone` 모양이 다양함(대표번호, 내선, 빈 값) | 판정은 기존 `checkTargetNumber` 그대로. 시험에 하이픈·빈 값·15xx·단축 번호를 넣음. 걸 수 없는 번호는 이유와 함께 비활성 |
| 대표번호 15xx의 E.164가 이상하게 나옴 | 계획 단계에서 실행해 확인: `checkTargetNumber("1588-0000")` → `{kind: "ok", e164: "+15880000"}`(국가 번호 +1로 읽힘. 실제로 거는 숫자는 `toDomesticDialString`으로 `15880000`). 서버 `domain`은 바꾸지 않고, 앱 표시만 `formatPhone`에서 `1588-0000`으로 고친다(`design.md` D9, AC-003·AC-015) |
| 쿼터(일 100,000건) 소진, 남용 | 이번 범위에서는 사용자별 제한 없음. 실패는 502로 보이고 [번호 직접 입력]이 늘 남음. 사용자별 제한은 Phase 0 계정 뒤 별도 SPEC(spec §2.1) |
| 오류 응답·쿼터 초과 형식 미확인(research R6) | 상태 코드만 보고 502로 묶음. 실제 키로 소유자와 한 번 확인(완료 정의) |
| 결과가 실수로 로그에 섞임(예상 못 한 오류의 `request.log.error`) | 모든 예외를 원인 없이 `PlaceSearchError`로 감쌈, 증명 시험이 500·예상 못 한 예외·형식 오류 경로까지 붙잡음(D4 (c)~(e), 확인 3·4) |
| 개발 서버가 실제 통화(KAT)에 쓰임(D-11, 소유자 답변 2026-11-28) | run은 그 서버를 멈추거나 다시 시작하거나 그 데이터·설정을 건드리지 않는다. 로컬 시험·화면 확인은 따로 띄운 서버(`CALL_PROVIDER=simulated`와 필요한 값을 명령에 직접 준 환경, `server/.env`·`--env-file` 쓰지 않음, 다른 포트·임시 `DATA_FILE`)로만 한다. 키 없는 실제 통화 서버는 장소 검색을 끔(OD-2) |
| 검색어 규칙이 엉뚱한 낱말을 뽑음 | 검색칸에서 고칠 수 있음. 예시 표는 시험으로 고정 |
| "엄마"·연락처 이름 같은 사람 이름이 검색어로 카카오(제3자)에 전송됨(OD-6) | **소유자가 받아들인 위험(2026-11-28 OD-6 결정)**. [번호 직접 입력] 한 번으로 지금의 번호 칸. 이후 개정 후보: 사람 호칭 사전에 걸리면 자동 검색 없이 검색칸만 연다 |
| 위치 좌표가 카카오(제3자)로 넘어감 | 서버가 소수 셋째 자리(약 100m)로 반올림한 뒤에만 보냄, 사전 안내 문구는 "콜비는 위치를 저장하지 않아요"로 콜비가 보장하는 범위만 말함(감사 D6) |
| 카카오 콘솔에서 로컬 API 사용 설정을 켜지 않으면 403 | 502로 묶여 동작은 안전. 어댑터 로그의 `status`로 401·403 구분. 완료 정의에 콘솔 설정 확인 |
| 기능 간 import 금지와 위치 안내 시트 중복 | 시트 하나 분량의 중복을 받아들임. 공용화는 `kolbi_ui`로 옮길 때(이후 SPEC) |
| ROUTINE-001과 오늘 화면 파일 겹침(12 R-5) | PLACE 다음에 ROUTINE run(에픽 순서 그대로) |
| 시험 환경에 위치·플러그인 없음 | 포트 뒤에 두고 `unavailable`로 처리, 가짜만 씀 |
| LLM이 `placeQuery`에 시간·요청 낱말을 넣거나 엉뚱한 값을 줌(0.2.0) | 프롬프트로 금지, 서비스가 번호·`근처`를 지우고 30자로 자름, 사용자는 검색칸에서 고침. 비거나 문자열이 아니면 결정적 규칙 |
| 서버 규칙과 앱 대체 규칙이 어긋남(0.2.0) | 두 언어 구현이 `design.md` D6의 같은 예시 표를 고정 기대값으로 시험. 표를 바꿀 때는 두 시험을 함께 고침 |
| `placeQuery`가 로그·저장소로 샘(0.2.0) | 접수는 작업을 만들지 않고, 로그는 URL과 실패 종류뿐. AC-024 시험과 로그 호출 grep |
| 배포 빌드에 `requestAlwaysAuthorization`이 남아 ITMS-90683 경고(0.2.0) | 빌드 설정으로는 막을 수 없음을 확인(D11). 배포 절차를 깨끗한 빌드 + 환경 변수로 문서화하고 `strings` 확인을 완료 정의에 둠. 자동화는 배포 파이프라인 작업에서 |

## E. 하네스·복잡도 지표

| 지표 | 값 |
|---|---|
| Tier | L — 서버 새 모듈과 외부 어댑터, 새 경로, 앱 새 기능(화면 둘·시트 둘·포트), 새 앱 의존, 49개 파일(+ 도구 갱신 iOS 산출 파일), 1,000줄 이상 예상. 에픽 표의 예상(M)보다 크다 |
| REQ / AC | 24 / 24 (Tier L 상한 25, 0.2.0에서 REQ-023·REQ-024 / AC-023·AC-024 더함) |
| 산출물 | spec.md, plan.md, acceptance.md, design.md, research.md, progress.md |
| 권장 하네스 | standard(외부 API와 개인정보 경계가 있어 thorough도 고려) |
| 방법론 | TDD(서버 증명 시험·어댑터·순수 함수·컨트롤러는 시험 먼저) |
| 모드 | serial(마일스톤 6개, 서버·앱 두 영역이지만 M3부터 서버 계약에 기대는 순차 작업) |

## F. 자체 검증

run 완료 보고는 다음을 원문 출력과 함께 담는다: AC별 PASS/FAIL 표와 명령, `npm --prefix server test` 마지막 줄들, `npm --prefix server run typecheck`, `cd app && flutter --suppress-analytics test` 마지막 줄, `cd packages/kolbi_core && dart test`, `flutter analyze`, `dart analyze`, `git diff --stat <run_start_sha> -- server/src/services server/src/brain server/src/providers server/src/store server/src/domain`(0.1.x 범위에서는 비어 있음, 0.2.0 M7 뒤에는 §B.4 표의 파일만), `git diff <run_start_sha> -- app/test/`(AC-022 표의 줄과 더하기만), M5의 패키지 확인 기록, M7 뒤 `grep`으로 서버 로그 호출에 `placeQuery`가 없음, 도구가 갱신한 iOS SwiftPM 파일 diff, 권한 선언 diff, 서식을 적용한 파일 목록.

## G. sync-phase 문서 항목

- (0.2.0) `/v1/intake` 응답의 `placeQuery`: SPEC-INTAKE-001 계약을 설명하는 문서(`.moai/project/structure.md`의 API 설명, `docs/product/11_ARCHITECTURE.md`의 접수 절)에 한 줄. 앱은 옛 서버에서도 동작(대체 규칙).
- (0.2.0) iOS 배포 절차(`design.md` D11): README 또는 `.moai/project/tech.md`의 배포 절에 `flutter clean && BYPASS_PERMISSION_LOCATION_ALWAYS=1 flutter build ipa`와 `strings` 확인.

- `.moai/project/structure.md`: 서버 `places/` 행, `http/app.ts`의 `POST /v1/places/search`, 앱 `features/places`, 경로 `/assistant/places`, `kolbi_core`의 장소 모델·`PlacesRepository`.
- `.moai/project/tech.md`: 앱 의존 `geolocator`(버전·라이선스), 서버 환경 변수 `KAKAO_REST_API_KEY`·`KAKAO_LOCAL_BASE_URL`, 키가 없을 때의 동작.
- `.moai/project/codemaps/`(있는 경우): 서버 모듈 그림에 `places`.
- `docs/product/11_ARCHITECTURE.md` §4.3: 실제 포트 모양(번호 판정을 `placeSearch.ts`로 옮긴 점), 카카오 필드 확인 완료("검증 필요" 해소), 키 없는 실제 통화 서버에서 꺼짐(OD-2).
- `docs/planning/03_SERVICE_FEATURE_PLAN.md` §8.1: 키워드 검색 `size` 상한 15(01 §5.2의 30은 주소 검색 기준), OD-5 진행 상황.
- `docs/planning/01_SERVICE_BENCHMARK.md` §5.2: 위 `size` 정정 한 줄(소유자 판단).
- `.moai/specs/EPIC-KOLBI-APP/overview.md` §2 표: PLACE-001 상태·Tier(L)·문서 목록.
- `README.md`: 장소 찾기 한 단락, 위치 권한 설명, `KAKAO_REST_API_KEY` 설정.
- `server/.env.example`는 run에서 이미 바뀜(B.1).
- `formatPhone`의 대표번호 표시 변경(`design.md` D9)은 앱 전체에 적용된다: 계획 카드뿐 아니라 업무 실행·결과·통화 중 화면, 오늘·기록 목록, 최근 장소 칩, 공유 문구처럼 `formatPhone`을 쓰는 모든 곳에서 `+15880000`이 `1588-0000`으로 보인다. `.moai/project/structure.md`(또는 `kolbi_core` 형식 함수 설명)와 `CHANGELOG`(있는 경우)에 이 동작 변화를 적는다.
