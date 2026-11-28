# SPEC-PLACE-001 조사 (0.1.0)

조사 시점: 2026-11-28, 저장소 `main` 74a87c3(SPEC-ASSIST-001 병합 직후). 외부 문서는 이 날 직접 열어 본 것만 적고, 열어 보지 못한 것은 R6에 "확인 못 함"으로 둔다.

## R1. 카카오 로컬 키워드 검색 — 공식 문서로 확인한 사실

출처: 카카오디벨로퍼스 "로컬 API 개발 가이드" https://developers.kakao.com/docs/ko/local/dev-guide (`/docs/latest/ko/local/dev-guide`는 이 주소로 302 이동), "쿼터" https://developers.kakao.com/docs/ko/getting-started/quota

| 항목 | 확인 내용 |
|---|---|
| 경로 | `GET https://dapi.kakao.com/v2/local/search/keyword.${FORMAT}`, `FORMAT`은 `json`(기본) 또는 `xml` |
| 인증 머리 | `Authorization: KakaoAK ${REST_API_KEY}` |
| `query` | String, 필수, 검색어 |
| `category_group_code` | 선택, 카테고리 그룹 코드(MT1, CS2, PS3, SC4, AC5, PK6, OL7, SW8, BK9, CT1, AG2, PO3, AT4, AD5, FD6, CE7, HP8, PM9) |
| `x`, `y` | String, 선택, 중심 경도·위도. `radius`와 함께 씀 |
| `radius` | Integer, 선택, 0~20,000(미터) |
| `rect` | 선택, 사각 범위(왼쪽 X, 왼쪽 Y, 오른쪽 X, 오른쪽 Y) |
| `page` | Integer, 1~45, 기본 1 |
| `size` | Integer, 1~15, 기본 15 |
| `sort` | `distance` 또는 `accuracy`, 기본 `accuracy`. `distance`는 `x`·`y` 필요 |
| `meta` | `total_count`, `pageable_count`(최대 45), `is_end`, `same_name{region[], keyword, selected_region}` |
| `documents[]` | `id`, `place_name`, `category_name`, `category_group_code`, `category_group_name`, `phone`, `address_name`(지번), `road_address_name`(도로명), `x`(경도), `y`(위도), `place_url`, `distance`(미터, `x`·`y`를 줄 때만) — 모두 String |
| 쿼터 | 키워드로 장소 검색 일 100,000건, 전체 API 월 3,000,000건(무료). 유료 초과 단가 "2원/건". "카카오맵 API는 개발자 계정 기준 첫 번째로 활성화한 앱에만 무료 쿼터를 제공" |
| 초당 제한 | 쿼터 문서에 로컬 API의 초당 제한은 적혀 있지 않음 |

기획 문서와의 차이: 01 §5.2는 `size` 최대 30이라고 적었으나(주소 검색 기준이라는 단서 있음) 키워드 검색은 **1~15**다. 이 SPEC은 5를 쓰므로 영향 없음. 03 §8.1의 "일 100,000건, 월 3,000,000건"은 문서와 같다.

## R2. 결과 저장에 관한 카카오 답변

출처: 카카오 데브톡 "로컬 API 검색 결과를 세션당 최대 20분 임시 저장하는 것도 '저장' 금지에 해당하나요?" https://devtalk.kakao.com/t/api-20/151271 (01 S35와 같은 글)

- 2026-08-24 카카오맵 팀 답변: "REST API는 실시간 호출로만 사용 가능하며 위와 같은 "임시 저장" 형태의 사용은 허용하지 않습니다."
- 2026-08-26 답변(장소 ID만 기록하고 표시 정보는 실시간으로 다시 부르는 안에 대해): "장소ID만 기록하고 나머지 표시 정보는 실시간 호출하는 방향은 운영 정책상 허용 가능한 방향입니다." 단, 로컬 API에 ID 하나로 조회하는 기능은 없어 서비스가 직접 방법을 만들어야 한다고 함.
- 성격: 포럼의 직원 답변이며 공식 정책 문서가 아니다. 개발 가이드 본문에는 저장·캐시 규정이 없고 "카카오비즈니스 이용약관", "서비스 약관", "운영 정책"으로 이어지는 링크만 있다(본문은 열어 보지 않음, R6).
- 이 SPEC에 주는 결론: 서버는 결과를 어떤 형태로도 보관하지 않는다(REQ-004). 사용자가 확정해 만든 작업의 이름·번호가 "결과 저장"에 해당하는지는 여전히 해석 문제다(03 OD-5, spec OD-3).

## R3. 코드 조사 (74a87c3)

### 서버

| 사실 | 위치 |
|---|---|
| 서버는 계층 구조(`brain`, `providers`, `services`, `http`, `domain`, `store`, `events`)이고 `places` 디렉터리는 없다 | `server/src/` 목록 |
| `/v1` 경로 목록에 장소 검색 없음 | `server/src/http/app.ts:147-205` |
| `/v1/` 토큰 검사는 `onRequest` 훅 하나 | `app.ts:140-145` |
| 요청 로그는 메서드·URL만(토큰 가림), 본문은 로그하지 않음 | `app.ts:98-109` |
| ZodError 응답은 경로와 메시지만, 값 없음 | `app.ts:123-124` |
| 예상 못 한 오류는 `request.log.error(error)` — 어댑터 오류에 본문을 넣으면 여기로 샌다 | `app.ts:136` |
| `AppDeps.logger`는 `boolean` | `app.ts:23` |
| 조립은 `container.ts` 하나, 통화 제공자 `kat`/`simulated` 선택 | `container.ts:23-65` |
| 환경 변수 스키마(zod), 키는 `optional` 변환 | `config.ts:3-32` |
| `checkTargetNumber(raw)` → `ok{e164}` · `invalid` · `blocked`, 단축 번호는 원문에서 먼저 막음 | `domain/phone.ts:47-67` |
| 외부 HTTP는 주입 가능한 `fetch`(KAT 선례) | `providers/kat/katProvider.ts:25-26`, `:421` |
| 구조 규칙 테스트는 소스 글자 대조 방식 | `architecture.test.ts:5-14` |
| `/v1/intake` 응답 키가 테스트로 고정됨(`draft, missing, numberIssue, phoneSource, source` / `draft`의 6개 키) | `http/app.test.ts:699-700` |
| `/v1/config` 응답이 `toEqual`로 고정됨 | `http/app.test.ts:455-490` |
| 접수의 `missing`에 번호가 없으면 `phoneNumber`가 들어감 | `services/callService.test.ts:1124`, `:1127` |
| 휴리스틱 접수는 "<이름>에/에게… 전화·연락" 꼴에서만 이름을 뽑음 → "강남역 근처 파스타집…"은 이름 없음 | `brain/heuristicBrain.ts:38-43` |
| 설계서가 정한 포트 모양과 의존 규칙 | `docs/product/11_ARCHITECTURE.md:350`, `:360`, `:368-385` |

### 공유 패키지와 앱

| 사실 | 위치 |
|---|---|
| `PhoneSource`는 `text` · `history` · `previousCall`(앱 전용) | `packages/kolbi_core/lib/src/models/intake_models.dart:6-15` |
| `IntakeResult.missing`은 `List<String>` | `intake_models.dart:69-91` |
| 서버 접근은 `CallsRepository` 하나, `ApiClient.post` | `kolbi_core/lib/src/data/calls_repository.dart:26-74` |
| 비서의 접수 함수는 초안만 돌려줌(`missing`을 버림), 404면 빈 초안 | `app/lib/shell/request_intake.dart:28-46` |
| 비서는 접수 뒤 늘 계획 카드를 엶 | `app/lib/features/assistant/assistant_screen.dart:123-140` |
| 비서 자식 경로 `plan`·`settings`·`new`, `extra` 없으면 돌려보냄 | `app/lib/shell/app_router.dart:113-140` |
| 경로 이름 상수 | `app/lib/shell/routes.dart:13-19` |
| 비서 자식 경로로 가는 도우미 | `app/lib/shell/navigation.dart:58-79` |
| 기능 간 import 허용 목록이 비어 있음 | `app/test/architecture_test.dart:8` |
| 음성·권한 패키지 import 경계 테스트(같은 방식으로 위치 규칙을 더함) | `architecture_test.dart:188-205` |
| 권한 선언 테스트는 `contains`로 검사(위치 키를 더해도 깨지지 않음) | `architecture_test.dart:208-223` |
| 계획 카드: 번호 없으면 위에 번호 칸, 출처 라벨, 언어·이름 행 | `plan_card_screen.dart:166-172`, `:195-200`, `:261-272` |
| "최근 통화한 곳" 제목 | `home_screen.dart:147`, `features/assistant/request_box.dart:93` |
| 최근 장소는 끝난 작업에서 매번 계산(저장 없음) | `kolbi_core/lib/src/models/counterparties.dart:22-35`, `shell/request_intake.dart:18-24` |
| 가짜 저장소의 접수 기본 응답은 빈 `missing`의 빈 초안 | `app/test/support/fakes.dart:106-119` |
| `formatPhone`은 `+82`가 아니면 E.164를 그대로 돌려줌 → 대표번호 `+15880000`이 그대로 보임. 기존 시험은 `+14155550100`(11자리)을 그대로 두는 것을 고정 | `packages/kolbi_core/lib/src/format/formatters.dart:4-18`, `app/test/unit_test.dart:12-15` |
| `checkTargetNumber("1588-0000")` → `{ok, "+15880000"}`(이 계획 작업에서 `npx tsx`로 실행해 확인). 서버 시험이 `"1588-1234" → "+15881234"`를 고정 | `server/src/domain/phone.ts:57`, `server/src/domain/domain.test.ts:115` |
| "최근 통화한 곳" 주석 | `home_screen.dart:19`, `:133`, `:166`, `request_box.dart:9`, `shell/request_intake.dart:18` |
| 위치 패키지 없음, `permission_handler`는 있음 | `app/pubspec.yaml` dependencies |
| iOS 권한 키는 마이크·음성 인식뿐 | `app/ios/Runner/Info.plist:69-72` |
| Android 권한은 `INTERNET`, `RECORD_AUDIO` | `app/android/app/src/main/AndroidManifest.xml:2-4` |

## R4. 기존 테스트 영향(grep)

`grep -rn "최근 통화한 곳" app/test` → 7곳(REQ-020이 바꿈):

| 파일:줄 | 테스트 |
|---|---|
| `today_test.dart:44` | "today follows the dashboard order"(`:31`) |
| `assistant_test.dart:556`, `:580` | "text mode carries the whole request box"(`:524`) |
| `assistant_test.dart:850` | "today hands requests to the assistant"(`:828`) |
| `accessibility_test.dart:622` | "screens follow the wireframe order"(`:610`) |
| `intake_flow_test.dart:130` | "suggests recent counterparties and templates"(`:119`) |
| `intake_flow_test.dart:157` | "…: no tasks yet"(`:153`) |

계획 카드 접힘(REQ-019)이 닿는 곳: `plan_card_test.dart:117`의 `find.text('한국어')` 누르기, `shell_test.dart:289`의 `find.text('김민수')` 누르기. 접힌 줄에서도 두 글자가 각각 따로 눌리게 하면(OD-10) 고칠 필요가 없다.

비서 분기(REQ-009)가 닿는 곳: 비서·접수 테스트의 가짜 접수 응답은 모두 `missing`이 비어 있다(`fakes.dart:118` 기본값, `assistant_test.dart:221`, `:663`, `:1003`의 `IntakeResult(draft: …)`). 그래서 기존 흐름은 계획 카드로 간다.

서버: `/v1/intake`·`/v1/config`를 바꾸지 않으므로 `app.test.ts:455-490`, `:699-700`은 그대로다. `architecture.test.ts`에는 규칙을 더하기만 한다.

기준선(74a87c3, 이 조사에서 실행):

- `npm --prefix server test` → `Tests  387 passed (387)`
- `cd app && flutter --suppress-analytics test` → `00:13 +148: All tests passed!`
- `cd packages/kolbi_core && dart test` → `00:00 +27: All tests passed!`

## R5. 위치 패키지

출처: https://pub.dev/packages/geolocator

- 최신 14.1.2, MIT, Android·iOS·Linux·macOS·web·Windows.
- `Geolocator.getCurrentPosition(locationSettings: LocationSettings(accuracy: …, timeLimit: …))`, 시간 초과 시 `TimeoutException`.
- `checkPermission()`·`requestPermission()` → `LocationPermission.denied`·`deniedForever`·`whileInUse`·`always`. Android의 `checkPermission`은 `deniedForever`를 돌려줄 수 없고 `requestPermission`만 알려 준다 → D8 표의 `deniedForever`는 요청 뒤에만 나올 수 있다.
- iOS `NSLocationWhenInUseUsageDescription` 필수(배경 위치를 쓰지 않으면 "항상" 키 불필요, 빌드 플래그 `BYPASS_PERMISSION_LOCATION_ALWAYS=1` 언급). Android `ACCESS_COARSE_LOCATION`만으로 대략 위치(첫 위치가 늦을 수 있음).
- 확인 못 함: SwiftPM 지원 여부(앱 iOS 프로젝트는 SwiftPM, ASSIST progress M1), 최소 Flutter/Dart SDK, `permission_handler`와 같은 앱에 있을 때의 충돌 여부 → M5 첫 작업.

## R6. 확인하지 못한 것

- 카카오 로컬의 오류 응답 형식과 상태 코드(키 오류, 쿼터 초과, 서버 오류). 개발 가이드 본문에서 찾지 못함. 어댑터는 상태 코드만 본다.
- 카카오 "운영 정책"·"서비스 약관" 본문의 저장 관련 조항(링크만 확인, 열어 보지 않음).
- `phone` 값의 실제 모양(지역번호 하이픈, 대표번호 15xx, 빈 문자열 빈도). 문서는 "String"만 적음. 시험은 하이픈 꼴·빈 문자열·대표번호·단축 번호를 모두 넣는다.
- 쿼터 초과 시 카카오가 돌려주는 상태 코드(429 여부).
- `geolocator`의 SwiftPM 지원과 iOS 최소 버전(R5).
- 카카오 개발자 콘솔에서 카카오맵(로컬) API 사용 설정을 켜지 않으면 403이 나는지. 어댑터 로그의 `status`로 401(키 오류)과 403(사용 설정·권한)을 구분할 수 있게 둔다. 완료 정의의 소유자 확인에 콘솔 설정 확인을 넣었다.
