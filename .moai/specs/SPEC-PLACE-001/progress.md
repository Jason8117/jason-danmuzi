# SPEC-PLACE-001 진행 기록

## §E.1 Plan-phase Audit-Ready Signal

- plan_status: audit-ready
- plan_status_final: plan-audit 2/3차 PASS 0.91 (보고서 `.moai/reports/plan-audit/SPEC-PLACE-001-review-2.md`). 감사 2차 지적 N1~N4는 0.1.2에서 반영
- kickoff: 소유자 Implementation Kickoff Approval 2026-11-28
- plan_complete_at: 2026-11-28
- spec_version: 0.2.0 (소유자 화면 검토 뒤 개정 2026-11-28 — `/v1/intake`의 `placeQuery`, 아래 "소유자 화면 검토 후 개정" 절). 이전: 0.1.2 (계획 감사 2차 PASS 0.91 뒤 N1~N4 정리)
- spec_version_history: 0.1.0 → 0.1.1(계획 감사 1차 FAIL 0.84 반영, 보고서 `.moai/reports/plan-audit/SPEC-PLACE-001-review-1.md`) → 0.1.2 → 0.2.0(소유자 화면 검토 뒤 OD-7 개정)
- base_sha: 74a87c3 (SPEC-ASSIST-001 병합 직후 `main`. 계획 문서는 아직 커밋 전. run_start_sha는 run에서 기록)
- tier: L (서버 새 모듈·외부 어댑터·새 경로 + 앱 새 기능·새 의존, 49개 파일(+ 도구가 갱신하는 iOS SwiftPM 산출 파일 최대 3개), 1,000줄 이상 예상. 에픽 개요 §2 표의 예상 M보다 큼 — 에픽 표는 sync에서 갱신하는 관례라 계획 단계에서는 고치지 않음), harness: standard (권장, 외부 API·개인정보 경계로 thorough도 고려), methodology: tdd, mode: serial
- artifacts: spec.md, plan.md, acceptance.md, design.md, research.md, progress.md
- counts: 24 REQ / 24 AC (Tier L 상한 25 / 25; 0.1.x는 22 / 22, 0.2.0에서 REQ-023·REQ-024 / AC-023·AC-024 더함)
- depends_on: SPEC-ASSIST-001 (`completed` 0.3.1, 2026-11-28 — 에픽 개요 §2 표)
- open_decisions: OD-1~OD-10 모두 **DECIDED**. OD-2·OD-3·OD-6·OD-7은 소유자 결정 2026-11-28(권장 기본값 그대로, OD-2 판정 기준은 조립된 `config.provider` = `realCalls` false이며 `CALL_PROVIDER` 환경 변수 값이 아님, OD-3은 법무 해석을 계속 확인, OD-6은 사람 이름이 카카오 검색어로 나가는 위험을 소유자가 받아들임). OD-1·OD-4·OD-5·OD-8·OD-9·OD-10은 소유자 결정 2026-11-28(Kickoff 승인 때 기본값으로 확정, OD-8의 버전·SwiftPM 확인은 M5 첫 작업)
- intended test changes: `acceptance.md` AC-022 표(문구 "최근 통화한 곳" → "최근 장소" 7줄, 두 `architecture` 시험 파일은 더하기만). `server/src/http/app.test.ts`와 `plan_card_test.dart`·`shell_test.dart`는 바꾸지 않음
- external facts verified at plan time (2026-11-28, `research.md` R1·R2·R5):
  - 카카오 키워드 검색 `GET https://dapi.kakao.com/v2/local/search/keyword.json`, `Authorization: KakaoAK ${REST_API_KEY}`, `size` 1~15, `page` 1~45, `radius` 0~20,000, `sort` accuracy(기본)/distance(`x`·`y` 필요), `documents[]` 필드 12개(`distance`는 좌표를 줄 때만) — https://developers.kakao.com/docs/ko/local/dev-guide
  - 쿼터: 키워드 검색 일 100,000건, 전체 월 3,000,000건, 첫 활성 앱만 무료 — https://developers.kakao.com/docs/ko/getting-started/quota
  - 저장: "실시간 호출로만 사용 가능", 20분 임시 저장 불허, 장소 ID만 기록은 "허용 가능한 방향"(직원 포럼 답변, 공식 정책 문서 아님) — https://devtalk.kakao.com/t/api-20/151271
  - `geolocator` 14.1.2, MIT, `NSLocationWhenInUseUsageDescription`, `ACCESS_COARSE_LOCATION`로 대략 위치 — https://pub.dev/packages/geolocator
- not verified (R6): 카카오 오류·쿼터 초과 응답 형식, 운영 정책·약관 본문의 저장 조항, 실제 `phone` 값 분포, `geolocator` SwiftPM 지원과 최소 iOS
- verified at plan time (코드, 74a87c3): 서버에 `places` 모듈·`/v1/places` 경로 없음(`server/src/http/app.ts:147-205`), `checkTargetNumber`는 `server/src/domain/phone.ts:57`, `/v1/intake` 응답 키 고정 `http/app.test.ts:699-700`, `/v1/config` 고정 `:455-490`, 비서는 접수 뒤 늘 계획 카드(`app/lib/features/assistant/assistant_screen.dart:123-140`), 접수 함수는 `missing`을 버림(`app/lib/shell/request_intake.dart:28-46`), 가짜 접수 기본 응답의 `missing`은 빔(`app/test/support/fakes.dart:118`), "최근 통화한 곳"은 `home_screen.dart:147`·`request_box.dart:93`과 시험 7곳, 기능 간 import 허용 목록 비어 있음(`app/test/architecture_test.dart:8`), 앱에 위치 패키지·위치 권한 선언 없음
- baseline (이 계획 작업에서 실행, 74a87c3): `npm --prefix server test` → `Tests  387 passed (387)`; `cd app && flutter --suppress-analytics test` → `00:13 +148: All tests passed!`; `cd packages/kolbi_core && dart test` → `00:00 +27: All tests passed!`
- run preconditions: SPEC-ASSIST-001 `completed`(충족), 소유자 OD 결정(충족, 2026-11-28), plan-audit PASS(충족, 2차 0.91 ≥ Tier L 0.85), Kickoff 승인(충족, 2026-11-28)
- D-11 (소유자 답변 2026-11-28): 개발 서버는 실제 통화(KAT)에 쓰인다. **run 규칙**: run 단계는 그 서버를 멈추거나 다시 시작하거나 그 데이터 파일·설정을 건드리지 않는다. 모든 로컬 시험과 화면 확인은 따로 띄운 서버로만 하며, 그 서버는 `CALL_PROVIDER=simulated`와 필요한 값(포트, 임시 `DATA_FILE`, `API_TOKEN` 등)을 명령에 직접 준 환경으로 띄운다. `server/.env`는 읽거나 불러오지 않는다(`npm run dev`·`npm start`의 `--env-file-if-exists=.env` 경로를 쓰지 않음). `npm --prefix server test`는 서버를 띄우지 않으므로 그대로 쓴다
- note: 서버·`kolbi_core`·앱이 바뀜. `kolbi_ui`, 서버 `services`·`brain`·`providers`·`store`·`domain`은 바뀌지 않음

### 계획 감사 1차 결과와 반영 (2026-11-28)

- 결과: FAIL 0.84(Tier L 기준 0.85). Clarity 0.80, Completeness 0.85, Testability 0.78, Traceability 0.95. 막는 결함 감사 D1~D4, 권장 감사 D5~D16(감사 보고서의 결함 번호이며 `design.md`의 D1~D9, 에픽의 D-*와 다름).
- 소유자 결정 2026-11-28(오케스트레이터 AskUserQuestion): OD-2·OD-3·OD-6·OD-7을 권장 기본값대로 확정.

| 지적 | 반영 위치 |
|---|---|
| 감사 D1 OD 상태 | spec.md HISTORY 0.1.1, §5 OD-2·3·6·7 DECIDED, OD-2·REQ-001에 `config.provider` 기준(`config.ts:56-57`), 이 문서 open_decisions |
| 감사 D2 검색어 규칙과 AC-010(2) 모순 | design.md D6 규칙 3에 `부탁…`·`해`·`해줘`·`해주세요`, 표에 "해 줘 → (빈 값, false)" 고정 줄, acceptance AC-010 |
| 감사 D3 대표번호 표시 | design.md D9(새 절, `formatPhone` 규칙과 표), spec REQ-015·§2, plan §B.2(`formatters.dart`)·M3·§D, acceptance AC-003(값 고정 + 표시)·AC-015 (4), 잔여 위험 |
| 감사 D4 저장 금지 증명의 빈틈 | design.md D2(모든 예외를 원인 없이 감쌈, 스트림은 운영 serializer·`info` 위에 더함, 오류 처리기가 `request.log.error`보다 먼저 잡음), D3(오류 종류 `unexpected`), D4 동작 (d) `TypeError`+`input`·`code`, (e) 형식 오류, 확인 2~4, spec REQ-005, acceptance AC-004 |
| 감사 D5 가짜 시계 | design.md D2 `AbortController` + `timeoutMs`, acceptance AC-005 (8)(10), plan A.1 |
| 감사 D6 위치 문구·최소화 | spec REQ-016·REQ-017, design.md D2·D3 반올림, D7 문구와 Info.plist 문구, acceptance AC-002 (7)·AC-005 (2)·AC-016·AC-018, plan §B.3·§D |
| 감사 D7 사람 이름 검색어 | spec OD-6, plan §D(소유자 수용 위험), acceptance 잔여 위험 |
| 감사 D8 카카오 콘솔 | design.md D3(401·403 구분), research R6, acceptance 완료 정의, plan §D |
| 감사 D9 REQ-008 문구 | spec REQ-008(`domain`과 로거 타입, 외부 `zod`), design.md D2 규칙 1 |
| 감사 D10 마일스톤 순서 | plan §C(시뮬레이션 제공자를 M1로, AC-006도 M1, M2는 조립·꺼짐), 패키지 확인은 M5 첫 작업으로 통일(spec §4·OD-8, research R5, acceptance 완료 정의) |
| 감사 D11 파일 수·iOS 산출 | plan §B.3(SwiftPM 산출 파일 셋을 "도구가 갱신, 허용"), §B 합계 49, §E, §F |
| 감사 D12 시뮬레이션 거리 순서 | spec REQ-006, acceptance AC-002 (6)·AC-006 |
| 감사 D13 캐시 머리 | spec REQ-004, design.md D1, D4 확인 2, acceptance AC-002 (5) |
| 감사 D14 AC 필드 이름 | spec REQ-009, acceptance AC-009 (4) `draft.numberBlocked: true` |
| 감사 D15 주석 범위 | plan §B.3(주석 다섯 줄 모두 바꿈), acceptance AC-020(grep 출력 없음), research R3 |
| 감사 D16 REQ의 구현 세부 | spec REQ-001·004·008·017에서 파일 경로·클래스 이름을 덜어 `design.md`로 넘김(REQ-003의 `checkTargetNumber`는 기존 계약 이름이라 남김) |
| 감사 권장(AC-019) | acceptance AC-019: "한국어"·"김민수"가 따로 된 `Text`, 합친 `Text` 없음 |
| 감사 권장(OD-8) | spec OD-8: 장소 기능에서 `permission_handler`를 쓰면 `architecture_test.dart:188-205`가 깨짐 |

- counts: 22 REQ / 22 AC (변동 없음)
- verified at plan time (추가): `npx tsx`로 `checkTargetNumber` 실행 — `"02-111-0000"` → `+8221110000`, `"02-555-0142"` → `+8225550142`, `"1588-0000"` → `{ok, "+15880000"}`, `""` → `invalid`, `"119"` → `blocked`, `"12"` → `invalid`. iOS SwiftPM 추적 파일 셋을 `git ls-files`로 확인(plan §B.3).

### 계획 감사 2차 결과와 반영 (2026-11-28)

- 결과: PASS 0.91(보고서 `.moai/reports/plan-audit/SPEC-PLACE-001-review-2.md`).
- 반영(0.1.2): 감사 N1 AC-005 (9)를 `network`만으로(`design.md` D3과 맞춤), 감사 N2 `error.cause === undefined` 단언을 AC-004(경로 수준)에서 AC-005의 `placeSearch.test.ts` 수준(`search()`가 거절한 값)으로 옮김, 감사 N3 감사 결함 번호에 "감사" 접두(spec HISTORY, plan §D, 이 문서), 감사 N4 plan §G에 `formatPhone` 대표번호 표시가 앱 전체에 적용된다는 항목 추가.
- 소유자 결정: OD-1·OD-4·OD-5·OD-8·OD-9·OD-10 기본값으로 확정, D-11 답변(위 run 규칙).

## §E.2 Run-phase Evidence

증거 파일(gitignore, 감사용으로 보관): `.moai/state/verify/SPEC-PLACE-001/{pre,red,final}/`.

### 사전 점검 (run 시작 시점, 어떤 변경보다 먼저 기록)

- `git -C <wt> rev-parse HEAD` → `be92194317e2bf3bd49234178ef3aa5d68daf589` (run_start_sha, 계획 커밋. 코드 기준선은 그 부모 74a87c3이며 be92194는 `.moai/specs/SPEC-PLACE-001/`만 더함)
- `git -C <wt> status --short` → (빈 출력)
- 서버 `npm --prefix server test` → `Test Files  14 passed (14)` / `Tests  387 passed (387)`, `npm --prefix server run typecheck` → exit 0
- 앱 `flutter --suppress-analytics test` → `00:13 +148: All tests passed!`, `flutter analyze` → `1 issue found.` (info `test/support/fakes.dart:54:5 • use_null_aware_elements`)
- kolbi_core `dart test` → `00:00 +27: All tests passed!`, `dart analyze` → `No issues found!`
- kolbi_ui `flutter test` → `00:01 +72: All tests passed!`
- 루트 `dart test` → `00:00 +2: All tests passed!`
- `flutter --version` → `Flutter 3.50.1 • channel stable` / `Tools • Dart 3.14.0`
- `grep -rn "최근 통화한 곳" app/test` → 9줄: 단언 7줄(`today_test.dart:44`, `assistant_test.dart:556`, `:580`, `:850`, `accessibility_test.dart:622`, `intake_flow_test.dart:130`, `:157`)과 주석 2줄(`today_test.dart:14`, `assistant_test.dart:121`). AC-022 표와 정확히 맞는다(주석 두 줄은 표의 "주석(선택)" 행).
- D-11: 이 run은 `server/.env`를 읽지 않고 `npm run dev`·`npm start`를 쓰지 않는다. 서버를 띄우는 확인은 하지 않았다(필요한 확인은 모두 `app.inject` 시험으로 함).

### M1 — 서버 계약과 저장 금지 증명

- RED(시험 먼저): `placeSearch.test.ts`, `kakaoLocalPlaceSearch.test.ts`, `http/places.test.ts`, `architecture.test.ts` 끝의 규칙 셋을 먼저 쓰고 실행 → `Test Files  4 failed (4)` / `Tests  1 failed | 6 passed (7)`. 실패 원인: 모듈이 없음(`Cannot find module './placeSearch.js'` 등)과 구조 규칙 `expected [] to include 'places/kakaoLocalPlaceSearch.ts'`. 원문 `.moai/state/verify/SPEC-PLACE-001/red/m1_server_red.txt`. 새 모듈의 RED는 단언 실패가 아니라 가져오기 실패로 나타난 점을 밝혀 둔다.
- GREEN: `server/src/places/{types,placeSearch,kakaoLocalPlaceSearch,simulatedPlaceSearch}.ts`, `http/schemas.ts`의 `PlaceSearchBody`, `http/app.ts`(`AppDeps.places`·`logger: {stream}`, 오류 처리기가 `PlaceSearchError`를 `request.log.error`보다 먼저 잡아 502·`no-store`, 경로 `POST /v1/places/search`·`Cache-Control: no-store`). M1에서는 `places`가 있을 때만 경로를 등록하고, 503은 M2에서 더한다.
- 설계 판단: AC-003은 후보 여섯을 순서대로 기대하므로 `createPlaceSearch`는 결과를 자르지 않는다. 5곳 상한은 `limit: 5`(카카오 `size=5`)가 맡는다. 시간 제한은 `AbortController`와 함께 `Promise.race`로도 걸어, 신호를 무시하는 제공자도 `timeoutMs` 안에 끝난다(AC-005 (10)).
- 증명 시험이 실제로 잡는지 변이 확인(되돌림 확인 `diff` 통과): (1) 어댑터가 원래 예외 문자열을 로그에 쓰게 바꾸면 `expected [ '표식예외-e1e1' ] to deeply equal []`로 실패. (2) 검색 경로에서 검색어를 담은 `TypeError`를 감싸지 않고 다시 던지면 500·표식 노출로 실패. (d)의 `TypeError`는 설계 D3대로 어댑터에서 `network`로 바뀌므로 바깥의 `unexpected` 경로만 바꾼 변이는 통과한다(정상).
- 결과: `npm --prefix server test` → `Tests  407 passed (407)`(기준 387 + 새 20), `npm --prefix server run typecheck` → exit 0.

### M2 — 조립과 꺼짐

- RED: AC-001 시험(`placeSearch.test.ts` "the container picks the place provider from the key and the call provider")과 AC-007 시험(`http/places.test.ts` "without a place provider the route answers 503")을 먼저 더함 → `Tests  2 failed | 10 passed (12)`, `AssertionError: expected 404 to be 503`, `AssertionError: expected undefined to be 'kakao'`. 원문 `red/m2_server_red.txt`.
- GREEN: `config.ts`에 `KAKAO_REST_API_KEY`(optional, 공백은 없음), `KAKAO_LOCAL_BASE_URL`(기본 `https://dapi.kakao.com`). `container.ts`가 D2 표대로 고름(판정은 `config.provider`, `CALL_PROVIDER=auto`에 KAT 설정이 모자란 경우도 시험에 넣음). `index.ts`는 `places`를 `buildApp`에 넘기고 기동 로그에 `placeSearch: places?.source ?? "off"`만 남김(키 없음). 경로는 `places`가 없으면 제공자를 부르지 않고 503 `place_search_unavailable`·`no-store`. `.env.example`에 값 없는 `KAKAO_REST_API_KEY=`와 설명.
- 결과: `npm --prefix server test` → `Tests  409 passed (409)`, typecheck exit 0.

### M3 — `kolbi_core`와 비서 분기

- RED(kolbi_core): `packages/kolbi_core/test/places_test.dart`(D6 예시 여섯 줄과 이름 있는 줄, D9 표, JSON 해석, 저장소 요청 모양, `PhoneSource.search`)를 먼저 씀 → 컴파일 실패 `Error: Method not found: 'placeSearchStartFor'.` 등. 원문 `red/m3_core_red.txt`.
- RED(앱): `app/test/places_test.dart` AC-009 블록과 `test/support/fake_places_repository.dart` → `Error when reading 'lib/features/places/place_search_screen.dart': No such file or directory`, `Undefined name 'placesRepositoryProvider'`. 원문 `red/m3_app_red.txt`.
- GREEN: `kolbi_core`에 `models/place_models.dart`(`Place`, `PlacePhoneCheck`(모르는 값은 `invalid`), `PlaceSearchSource`(모르는 값은 `unknown`), `PlaceSearchResult`, `PlaceSearchStart`), `data/places_repository.dart`, `places/place_intent.dart`(`placeSearchStartFor`), `PhoneSource.search('검색 결과')`, `formatPhone`의 대표번호 규칙(`^\+1([568]\d{6})$`). 앱에 `shell/place_search.dart`(`placesRepositoryProvider`), `RouteNames.assistantPlaces`, `/assistant/places` 자식 경로(`extra`가 `PlaceSearchStart`가 아니면 `/assistant`로), `openAssistantPlaces`, `requestPlanDraft` → `requestIntake`(404는 빈 `missing`의 `IntakeResult`), 비서 `_submit` 분기. 장소 선택 화면은 M3에서 제목만 있는 뼈대로 두고 M4에서 채운다.
- 결과: kolbi_core `dart test` → `00:00 +32: All tests passed!`, `dart analyze` → `No issues found!`; 앱 `flutter test` → `00:13 +149: All tests passed!`, analyze → 기존 info 1건만; 루트 `dart test` → `+2`.
- 계획과 다른 점: AC-010의 앱 부분(검색칸 채움, 빈 검색어면 초점, `searchCalls`)은 화면이 있어야 해서 M4에서 시험한다. 서식: 새 파일과 HEAD에서 이미 서식이 맞던 수정 파일에만 `dart format` 적용. `intake_models.dart`, `formatters.dart`는 HEAD에서도 `dart format` 기준과 달라(줄 길이 120 관례) 전체 재배치를 피하려고 서식을 돌리지 않았다.

### M4 — 장소 선택·상세

- RED: `app/test/places_test.dart`에 AC-010(앱), AC-011, AC-012, AC-013, AC-014, AC-015(+AC-004 앱 부분) 블록을 먼저 더함. M3의 뼈대 화면에서 실행 → 다섯 블록이 `Expected: exactly one matching candidate`로 실패(`+1 -5`). 원문 `red/m4_app_red.txt`.
- GREEN: `features/places/place_search_controller.dart`(봉인 상태 `PlaceIdle`·`PlaceLoading`·`PlaceResults`·`PlaceFailed(unavailable)`, 세대 번호로 늦은 응답 무시, `draftFor`는 D5대로 이름·번호·`PhoneSource.search`만 바꿈), `place_card.dart`(CMP-05, 읽기 단위 라벨, 상태 글자·비활성 이유, 첫 걸 수 있는 후보만 인디고 테두리와 `FilledButton`, 첫 후보에 거리가 있을 때만 "가장 가까워요", 뼈대 카드), `place_detail_sheet.dart`(SCR-H03, 제목에 자동 초점, [번호 복사], [여기에 물어보기]는 걸 수 있을 때만, 닫으면 [상세]로 초점 복귀), `place_search_screen.dart`(D7 문구 전체, 목적격 조사 판단, 결과 문장 정중한 알림 1회).
- 설계 판단: 컨트롤러는 Riverpod `Notifier` 대신 화면이 소유하는 `ValueNotifier`로 했다. 상태가 화면 하나에만 속하고(REQ-004: 결과는 화면이 닫히면 사라짐), 저장소는 `placesRepositoryProvider`로 주입된다. 계획 A.3의 상태 목록 가운데 `needLocation`·`askArea`는 M5에서 더한다.
- 더한 시험: 검색 중에 화면을 닫으면 늦은 응답을 무시(acceptance.md 엣지 케이스).
- 결과: `flutter test test/places_test.dart` → `+8`, 전체 `flutter test` → `00:14 +156: All tests passed!`, `flutter analyze` → 기존 info 1건만.

### M5 — 위치

#### 첫 작업: `geolocator` 확인 (pub.dev API와 pub cache, 2026-11-28, 추가 전)

- `curl -s https://pub.dev/api/packages/geolocator`(메타데이터만 읽음) → 최신 `14.1.2`, 게시 `2026-10-19T15:29:42Z`(한 달 넘음), `environment: sdk ^3.5.0, flutter >=2.8.0`, 의존 `geolocator_platform_interface ^4.4.0`, `geolocator_android ^5.1.0`, `geolocator_apple ^2.3.14`, `geolocator_web`, `geolocator_windows`, `geolocator_linux`.
- `cd app && flutter pub add geolocator:^14.1.2` → `Changed 14 dependencies`. `git diff --stat pubspec.lock` → `112 +` (삭제 0줄). 새 항목 14개: `dbus`, `geoclue`, `geolocator`, `geolocator_android 5.2.1`, `geolocator_apple 2.4.3`, `geolocator_linux`, `geolocator_platform_interface`, `geolocator_web 4.1.4`, `geolocator_windows 0.2.5`, `gsettings 0.2.8`, `package_info_plus 10.2.2`, `package_info_plus_platform_interface 4.1.0`, `petitparser 7.1.0`, `xml 7.1.0`. 기존 항목은 바뀌지 않음.
- 라이선스: `geolocator-14.1.2/LICENSE`, `geolocator_apple-2.4.3/LICENSE` 모두 "MIT License, Copyright (c) 2018 Baseflow".
- SwiftPM: `geolocator_apple-2.4.3/darwin/geolocator_apple/Package.swift` 있음, `.iOS("11.0")`, `.macOS("10.11")` — 앱 배포 대상 `IPHONEOS_DEPLOYMENT_TARGET = 15.0` 이하이므로 문제없음. Android 쪽 `minSdkVersion flutter.minSdkVersion`, 플러그인 매니페스트에 위치 권한 선언 없음(앱 매니페스트의 `ACCESS_COARSE_LOCATION`만 쓰임).
- 권한 요청 동작(플러그인 소스 `PermissionHandler.m:79-84`): `Info.plist`에 `NSLocationWhenInUseUsageDescription`이 있으면 `requestWhenInUseAuthorization`만 부른다. 다만 빌드 때 `BYPASS_PERMISSION_LOCATION_ALWAYS=1`을 주지 않으면 바이너리에 `requestAlwaysAuthorization` 호출이 남아(`Package.swift:7-11` 주석: ITMS-90683) App Store 제출 때 "항상" 목적 문구 경고가 날 수 있다. REQ-018은 "항상" 키를 금지하므로 키는 넣지 않았다. **소유자 확인 필요**: 배포 빌드(`flutter build ipa` 등)에 `BYPASS_PERMISSION_LOCATION_ALWAYS=1` 환경 변수를 줄지(sync 문서 항목 후보).
- `permission_handler`와 공존: 두 플러그인은 서로 의존하지 않고(`pubspec.lock`에 공통 새 항목 없음), 장소 기능은 `permission_handler`를 쓰지 않는다(구조 시험). iOS 시뮬레이터 빌드가 두 플러그인을 함께 링크해 성공(아래).

#### 구현

- RED: `test/support/fake_location_reader.dart`, `places_test.dart`의 AC-016·AC-017 블록, `architecture_test.dart` 끝에 시험 둘을 먼저 더함 → `Error when reading 'lib/features/places/location/location_reader.dart'`, 구조 시험 `the location package stays inside the places feature`(`Expected: non-empty / Actual: []`)와 `platform files declare coarse location only` 실패. 원문 `red/m5_app_red.txt`.
- GREEN: `features/places/location/location_reader.dart`(D8 포트), `platform_location_reader.dart`(`geolocator`, `LocationAccuracy.low`, `timeLimit`, iOS·Android 밖이나 플러그인이 없으면 `unavailable`, `checkPermission`의 `denied`는 "아직 안 물음"으로 읽음), `location_consent_sheet.dart`(CMP-23), 컨트롤러에 `PlaceNeedLocation`·`PlaceAskArea(foreverDenied)`와 위치 흐름(10초 제한, 좌표는 검색 요청 하나에만, 다시 시도 때는 새로 읽음), 화면의 동네 이름 칸·[설정 열기], `shell/place_search.dart`의 `locationReaderProvider`, `Info.plist` `NSLocationWhenInUseUsageDescription` "가까운 가게를 찾는 데만 써요. 콜비는 위치를 저장하지 않아요."(`plutil -lint` → OK), `AndroidManifest.xml` `ACCESS_COARSE_LOCATION`. 선언 diff 원문 `final/m5_declarations.diff`.
- 처음 GREEN에서 "가짜 없이 실제 위치 구현" 시험이 실패했다: 위젯 시험 호스트에서는 플러그인 호출이 답하지 않아 화면이 로딩에 머묾. 비서의 `PlatformSpeechRecognizer`와 같은 방식으로 `supported`(iOS·Android만) 검사를 더해 해결하고, `supported: true`로 강제한 경우 `MissingPluginException`이 `unavailable`로 바뀌는 단위 시험을 더함.
- `architecture_test.dart`에 `dart format`을 돌렸더니 기존 두 줄이 다시 배치되어, HEAD 내용에 새 블록만 붙이는 방식으로 되돌림 → `git diff --numstat` `45 0`(더하기만).
- 결과: 전체 `flutter test` → `00:14 +162: All tests passed!`, `flutter analyze` → 기존 info 1건만. `cd app && flutter build ios --simulator --debug` → `✓ Built build/ios/iphonesimulator/Runner.app`(원문 `final/ios_build_m5.txt`). 빌드 뒤 `git status`에 `project.pbxproj`·`Package.resolved` 변경 없음. 생성된 `ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift`에 `geolocator_apple`이 들어감(gitignore된 산출물).

### M6 — 계획 카드·문구·접근성·회귀

- RED: AC-022 표의 기존 시험 9줄(단언 7줄 + 주석 2줄)을 "최근 장소"로 바꾸고, `places_test.dart`에 AC-019("the plan card folds defaults into one line")·AC-021("place screens meet the accessibility guidelines") 블록을 더한 뒤 전체 실행 → `00:14 +158 -6: Some tests failed.` 실패: `accessibility_test.dart: screens follow the wireframe order`, `assistant_test.dart: text mode carries the whole request box`, `assistant_test.dart: today hands requests to the assistant`, `intake_flow_test.dart: suggests recent counterparties and templates`, `today_test.dart: today follows the dashboard order`, `places_test.dart: the plan card folds defaults into one line`. 원문 `red/m6_app_red.txt`. `intake_flow_test.dart` "…: no tasks yet"은 `findsNothing`이라 바꾼 뒤에도 통과(정상).
- AC-021 블록은 처음 실행부터 통과했다. 화면을 M4·M5에서 지침에 맞춰 만들었기 때문이며, 이 블록은 사실상 test-after다(RED 출력 없음).
- GREEN: `home_screen.dart`·`request_box.dart`의 묶음 제목과 주석 다섯 줄을 "최근 장소"로. `plan_card_screen.dart`에서 "통화 언어"·"내 이름" 두 행을 `Key('plan-defaults-row')` 한 줄("통화 언어 · 내 이름")로 접고, "한국어"와 이름은 각각 따로 누르는 48×48 이상 `_TapText`로 둠. `plan_card_test.dart`·`shell_test.dart`는 손대지 않고 통과.
- 서식: `request_box.dart`(HEAD에서 서식 일치, 문자열만 바뀜)와 새 시험만. `plan_card_screen.dart`·`home_screen.dart`는 HEAD에서도 `dart format` 기준과 달라 돌리지 않음.
- 결과: 전체 `flutter test` → `00:14 +164: All tests passed!`, analyze → 기존 info 1건만.

### 최종 확인 (HEAD bee5d2b, 2026-11-28)

증거 원문은 `.moai/state/verify/SPEC-PLACE-001/final/`.

```
npm --prefix server test                         -> Test Files  17 passed (17) / Tests  409 passed (409)   (server_test.txt, 기준 387)
npm --prefix server run typecheck                -> exit 0                                          (server_typecheck.txt)
cd app && flutter --suppress-analytics test      -> 00:16 +164: All tests passed!                   (app_test.txt, --coverage, 기준 +148)
cd app && flutter --suppress-analytics analyze   -> 1 issue found. (기존 info test/support/fakes.dart:54:5)  (app_analyze.txt)
cd packages/kolbi_core && dart test              -> 00:00 +32: All tests passed!                    (core_test.txt, 기준 +27)
cd packages/kolbi_core && dart analyze           -> No issues found!                                (core_analyze.txt)
cd packages/kolbi_ui && flutter test             -> 00:01 +72: All tests passed!                    (ui_test.txt, 변경 없음)
dart test (저장소 루트)                            -> 00:00 +2: All tests passed!                     (root_test.txt)
cd app && flutter build ios --simulator --debug  -> ✓ Built build/ios/iphonesimulator/Runner.app   (ios_build.txt)
```

#### AC 표 (모두 위 실행에 포함)

| AC | 결과 | 시험 |
|---|---|---|
| AC-001 | PASS | `server/src/places/placeSearch.test.ts` "the container picks the place provider from the key and the call provider" |
| AC-002 | PASS | `server/src/http/places.test.ts` "POST /v1/places/search validates and answers in the documented shape", "hands the provider the documented query"; `placeSearch.test.ts` "fills the provider query with limit, radius and rounded coordinates" |
| AC-003 | PASS | `placeSearch.test.ts` "every candidate number goes through checkTargetNumber"; `packages/kolbi_core/test/places_test.dart` "formatPhone shows Korean representative numbers"; 앱 표시는 AC-015 (4) |
| AC-004 | PASS | `http/places.test.ts` "place search results never reach storage, cache, events or logs"(확인 1~6 각각 단언); 앱 부분 `app/test/places_test.dart` "choosing a place fills the plan card"(`SharedPreferences` 표식 없음). 변이 두 개로 시험이 실제로 잡는지 확인(M1) |
| AC-005 | PASS | `server/src/places/kakaoLocalPlaceSearch.test.ts` "kakao keyword search request, mapping and failures"(7개 `it`, (1)~(10)); `placeSearch.test.ts` "search rejects only with a bare PlaceSearchError", "keeps the provider status and kind but nothing else", "times out a provider that never answers", "passes an abort signal that fires on the time limit"; 경로 502는 AC-004 (c)(d)(e) |
| AC-006 | PASS | `placeSearch.test.ts` "the simulated provider is deterministic and offline" |
| AC-007 | PASS | `http/places.test.ts` "without a place provider the route answers 503" |
| AC-008 | PASS | `server/src/architecture.test.ts` "places module stays stateless and out of store, brain and services", "http layer does not know concrete place providers", "no any for place provider data"; `grep -rn "KAKAO_REST_API_KEY" app/lib app/test app/ios/Runner app/android/app/src packages` → 출력 없음(exit 1) |
| AC-009 | PASS | `app/test/places_test.dart` "the assistant opens place selection only when the number is missing" |
| AC-010 | PASS | `kolbi_core/test/places_test.dart` "place search start vectors"; `app/test/places_test.dart` "the search field starts from the request" |
| AC-011 | PASS | "place selection follows the wireframe order" |
| AC-012 | PASS | "loading, empty, failure and nothing callable" |
| AC-013 | PASS | "uncallable candidates cannot be chosen" |
| AC-014 | PASS | "place detail sheet" |
| AC-015 | PASS | "choosing a place fills the plan card" |
| AC-016 | PASS | "nearby asks for location with a purpose first"; 더해서 "without a location plugin a nearby request asks for the neighbourhood", "a forced platform reader without a plugin reports unavailable, never throws" |
| AC-017 | PASS | "location stays out of storage and other requests"; `app/test/architecture_test.dart` "the location package stays inside the places feature" |
| AC-018 | PASS | `architecture_test.dart` "platform files declare coarse location only"(기존 마이크·음성 선언 시험도 통과) |
| AC-019 | PASS | "the plan card folds defaults into one line"; `plan_card_test.dart`·`shell_test.dart` 무수정 통과 |
| AC-020 | PASS | AC-022 표의 수정 블록 5개(+ "no tasks yet") 통과; `grep -rn "최근 통화한 곳" app/lib` → 출력 없음(exit 1) |
| AC-021 | PASS(test-after) | "place screens meet the accessibility guidelines" |
| AC-022 | PASS | 아래 범위 확인 |

#### 범위·경계 (`final/boundaries.txt`)

- `git diff --stat 74a87c3 -- server/src/services server/src/brain server/src/providers server/src/store server/src/domain server/src/http/app.test.ts app/test/plan_card_test.dart app/test/shell_test.dart app/test/unit_test.dart packages/kolbi_ui app/lib/features/assistant/speech` → 출력 없음(바뀐 것 없음).
- `git diff --stat 74a87c3 -- app/test/` → `accessibility_test.dart 2 +-`, `architecture_test.dart 45 ++`, `assistant_test.dart 8 +-`, `intake_flow_test.dart 4 +-`, `today_test.dart 4 +-`, 새 파일 `places_test.dart 828`, `support/fake_location_reader.dart 56`, `support/fake_places_repository.dart 78` — `8 files changed, 1016 insertions(+), 9 deletions(-)`. 지운 9줄은 모두 "최근 통화한 곳" → "최근 장소"(단언 7, 주석 2, 원문 `final/existing_test_changes.diff`). `support/fakes.dart` diff 0줄. 두 `architecture` 시험 파일의 삭제 줄 0.
- 서버 `places/` 모듈의 import: `../domain/phone.js`, `./types.js`, `../logger.js`(타입), `zod`뿐.
- `permission_handler`·`speech_to_text` import는 `app/lib/features/assistant/speech/platform_speech_recognizer.dart` 하나, `geolocator` import는 `app/lib/features/places/location/platform_location_reader.dart` 하나. `const allowedCrossFeature = <String>{};` 그대로.
- iOS 빌드 뒤 `project.pbxproj`·`Package.resolved` 변경 없음(`git status`).

#### 커버리지

- 앱(`flutter test --coverage`, lcov 집계): `place_card.dart` 93/93 100%, `place_detail_sheet.dart` 52/52 100%, `location_consent_sheet.dart` 14/14 100%, `place_search_controller.dart` 72/73 98.6%, `place_search_screen.dart` 142/145 97.9%, `shell/place_search.dart` 3/4 75.0%, `location/platform_location_reader.dart` 15/26 57.7%(실제 플러그인 경로는 시험 호스트에서 돌 수 없음), 합계 391/407 **96.1%**.
- 서버: **측정 못 함(Gap)**. `server/node_modules/@vitest/`에 `mocker`, `spy`만 있고 커버리지 제공자(`@vitest/coverage-v8` 등)가 없다. 새 의존 설치는 이 run 범위 밖이라 하지 않았다. 대신 `places/` 네 파일의 분기마다 시험이 있음을 AC-001~AC-008 표로 둔다.
- kolbi_core: 측정하지 않음(Gap). 새 함수는 `places_test.dart` 5개 시험이 예시 표·JSON·저장소 요청으로 다룬다.

#### 린트

- 서버: 린터 설정 없음(`package.json`에 lint 스크립트 없음). `tsc --noEmit` exit 0.
- 앱: 기준선과 같음(info 1건, 새 경고 0). kolbi_core: `No issues found!`.

#### 계획과 다른 점

- 파일: 계획 §B의 49개를 모두 바꾸거나 만들었고 계획 밖 파일은 없다. iOS SwiftPM 산출 파일 3개는 도구가 바꾸지 않아 커밋하지 않았다.
- `createPlaceSearch`는 결과를 5곳으로 자르지 않는다(AC-003이 여섯을 기대). 상한은 `limit: 5`가 맡는다.
- 컨트롤러는 Riverpod `Notifier` 대신 화면이 소유하는 `ValueNotifier`(M4 참조).
- AC-010의 앱 부분은 M3이 아니라 M4에서 시험.
- `PlatformLocationReader`에 `supported` 검사(비서 음성 어댑터와 같은 방식)를 더함(M5 참조).

#### 소유자 확인이 필요한 것

1. 화면 검토: 장소 선택(SCR-H02), 후보 카드, 상세 시트, 위치 사전 안내, 동네 이름 칸, 계획 카드의 접힌 줄. 시뮬레이터에서는 따로 띄운 시뮬레이션 서버로 확인해야 한다(D-11, `server/.env` 쓰지 않음).
2. iOS 배포 빌드에 `BYPASS_PERMISSION_LOCATION_ALWAYS=1`을 줄지(App Store ITMS-90683 경고 회피, M5 참조). → 소유자 결정 2026-11-28: 적용. 빌드 설정으로는 안 됨을 확인해 배포 절차로 문서화(아래 개정 절, `design.md` D11).
3. 완료 정의의 실제 키 확인 1건(카카오 콘솔의 로컬 API 사용 설정, "강남역 파스타" → 후보 → 계획 카드, 서버 로그에 결과 없음).
4. Android에서 한 번 거부한 뒤 다시 "근처" 부탁을 하면 사전 안내가 다시 보인다(`checkPermission`의 `denied`를 "아직 안 물음"으로 읽기 때문). OS 창이 다시 뜰지는 OS가 정한다.

### 소유자 화면 검토 후 개정 (2026-11-28)

#### 계기와 결정

- 소유자 화면 검토(2026-11-28): "근처 치과 내일 오전 예약해 줘"의 첫 검색어가 "치과 오전"으로 나옴. 앱 규칙(`place_intent.dart`, D6)이 `오늘`·`내일`·`N시`는 건너뛰지만 `오전`은 건너뛰지 않았다.
- 소유자에게 날짜·시각은 부탁 문장(계획 카드 "부탁할 일")에 남고 검색어에서만 빠진다고 설명한 뒤, 소유자가 "서버 AI가 검색어도 뽑기"를 골랐다. OD-7(0.1.x: `/v1/intake` 불변, 앱 규칙만)을 뒤집음. 옛 선택지 설명대로 서버 응답 모양과 기존 시험 하나(`app.test.ts:699` 응답 키 고정)가 바뀐다.
- 소유자 결정: geolocator의 `BYPASS_PERMISSION_LOCATION_ALWAYS=1`을 iOS 빌드 설정에 지금 넣기(배포 빌드에서 `requestAlwaysAuthorization` 제거 → ITMS-90683 경고 없음). SwiftPM 방식에서 믿을 만하게 안 되면 문서화로 대신하고 그렇게 알림.

#### 계획 개정 (0.1.2 → 0.2.0, manager-spec)

- spec.md: HISTORY 0.2.0, REQ-010·REQ-022 개정, REQ-023(접수 응답 `placeQuery`)·REQ-024(응답 밖으로 내보내지 않음) 신설, §2 범위, OD-7 개정, 추적 표. 22 / 22 → 24 / 24.
- design.md: D6(공유 예시 표 12줄, 조율자 확인 뒤 19줄·22줄·24줄 — "근처 치과 내일 오전 예약해 줘 → 치과, nearby true"와 0.1.x의 파스타 예시 포함, 시간 낱말, "근처" 판단), D10(`placeQuery` 계약·후처리·개인정보), D11(iOS 설정 확인 결과와 문서화 결론).
- plan.md: §A.6, §B.4(M7 변경 파일 13개), §B.5, M7, 위험 4행, §E 수, §F, §G.
- acceptance.md: AC-010 개정, AC-022 표에 `app.test.ts:699`(한 줄)와 `openaiBrain.test.ts` 끝 더하기, AC-023·AC-024, 완료 정의 2행.

#### iOS `BYPASS_PERMISSION_LOCATION_ALWAYS` 확인 (계획 개정 전에 실행, 2026-11-28)

- `geolocator_apple-2.4.3/darwin/geolocator_apple/Package.swift`: `ProcessInfo.processInfo.environment["BYPASS_PERMISSION_LOCATION_ALWAYS"] == "1"`를 `cSettings`의 `.define`으로 넣음. `PermissionHandler.m:79-86`: iOS에서 `#if !BYPASS_PERMISSION_LOCATION_ALWAYS` 안의 `requestAlwaysAuthorization`(macOS 갈래의 `:75`는 iOS에 없음).
- 측정: `strings -a build/ios/iphonesimulator/Runner.app/Runner.debug.dylib | grep -c requestAlwaysAuthorization`(arm64·x86_64 두 조각이라 남으면 2).
  - 기준(환경 변수 없음, 기존 빌드): `2`.
  - `BYPASS_PERMISSION_LOCATION_ALWAYS=1 flutter build ios --simulator --debug`(증분): `✓ Built`, `2` — `geolocator_apple.o` 시각이 19:48 그대로(다시 컴파일 안 됨).
  - 이 작업 폴더의 DerivedData(`Runner-ayqpeadwacpjlwehdddmglhtjxaj`, `WorkspacePath`가 `wt-place-001/app/ios/Runner.xcworkspace`임을 확인)와 `app/build/ios`를 지우고 같은 환경 변수로 빌드: `✓ Built`, dylib `0`, `geolocator_apple.o` `0`.
  - `ios/Flutter/Debug.xcconfig`에 `BYPASS_PERMISSION_LOCATION_ALWAYS=1`과 `GCC_PREPROCESSOR_DEFINITIONS=$(inherited) BYPASS_PERMISSION_LOCATION_ALWAYS=1`을 임시로 더하고 환경 변수 없이 깨끗한 빌드: `✓ Built`, dylib `2` — 빌드 설정은 SwiftPM 패키지 대상에 닿지 않음. 시험 뒤 xcconfig를 원래대로 되돌림(`git status` 깨끗).
- 결론: SwiftPM 방식의 이 프로젝트에서는 빌드 설정으로 믿을 만하게 넣을 수 없다 → **설정 파일은 바꾸지 않고 문서화**(`design.md` D11): 배포 빌드는 `cd app && flutter clean && BYPASS_PERMISSION_LOCATION_ALWAYS=1 flutter build ipa`, 바이너리 `strings` 확인 0. 원문 `.moai/state/verify/SPEC-PLACE-001/final/ios_bypass_*.txt`.

#### M7 구현 (manager-develop, TDD)

- RED(서버, `red/amend_server_red.txt`): `npm --prefix server test -- --run src/domain/placeQuery.test.ts src/http/places.test.ts src/brain/openaiBrain.test.ts src/http/app.test.ts` → `Test Files  4 failed (4)`, `Tests  5 failed | 99 passed (104)`. 내용: `Cannot find module './placeQuery.js'`, `intake reads placeQuery leniently`(키 없음), `app.test.ts` 키 목록 `(1)`·`(2)`, `intake answers with a place query` — `근처 치과 내일 오전 예약해 줘: expected undefined to be '치과'`, `intake placeQuery never reaches storage, events or logs` — `[ 'llm', undefined ]`.
- RED(`kolbi_core`): 먼저 `red/amend_core_red.txt`(`IntakeResult`에 `placeQuery` 매개변수가 없어 시험 파일 불러오기 실패), 모델 필드만 더한 뒤 `red/amend_core_red2.txt` — `place search start vectors` `Expected: '치과' / Actual: '치과 오전'`(소유자가 본 결함 재현), `place search start prefers the intake placeQuery` `Actual: (치과 오전, true)`.
- RED(앱, `red/amend_app_red.txt`): `the assistant searches with the intake placeQuery` — `test/places_test.dart:242:7: Error: No named parameter with the name 'placeQuery'.`(컴파일 실패 단계 RED).
- GREEN: 서버 `domain/placeQuery.ts`(새, `placeQueryFor`·`cleanPlaceQuery`), `domain/types.ts`(`IntakeContent.placeQuery?`, `IntakeResult.placeQuery`), `brain/prompts.ts`(접수 프롬프트에 `placeQuery`), `brain/openaiBrain.ts`(`z.string().max(100).optional().catch(undefined)`, 값이 있을 때만 결과에 넣음), `services/callService.ts`(정리 → 비면 결정적 규칙). `kolbi_core` `intake_models.dart`(`IntakeResult.placeQuery`), `place_intent.dart`(`placeQuery` 우선, 시간 낱말·조사·숫자+`일`·`월`·`주`, 시간 낱말 뒤의 `근처`도 "근처"). 앱 `lib`는 바뀌지 않음(`assistant_screen.dart`가 이미 `placeSearchStartFor(text, result)`를 씀). 휴리스틱 두뇌는 바꾸지 않음(규칙은 서비스가 적용).
- 처음 GREEN에서 `z.unknown().transform(...)`이 zod 4에서 키가 없는 응답을 스키마 불일치로 만들어 기존 `openaiBrain.test.ts` 세 줄이 깨짐 → `.optional().catch(undefined)`로 바꿔 해결(기존 시험은 고치지 않음).
- 기존 시험 변경(AC-022 표 그대로): `server/src/http/app.test.ts:699` 한 줄(키 목록에 `"placeQuery"`). `git diff 1ec833a -- server/src/http/app.test.ts`의 `-`/`+` 한 쌍뿐. `server/src/brain/openaiBrain.test.ts`는 `git diff --numstat` `28 0`(파일 끝 더하기만). 그 밖의 기존 시험 변경 없음. 이 SPEC이 만든 시험 파일 셋(`server/src/http/places.test.ts`, `packages/kolbi_core/test/places_test.dart`, `app/test/places_test.dart`)은 블록을 더하고 `makeApp`에 `brain` 선택지·`afterEach`에 `vi.unstubAllGlobals()`를 더함.
- 범위: `git diff --stat 1ec833a -- server/src/services server/src/brain server/src/providers server/src/store server/src/domain` → 7개 파일(`openaiBrain.test.ts 28`, `openaiBrain.ts 6`, `prompts.ts 4`, `placeQuery.test.ts 39`, `placeQuery.ts 71`, `types.ts 4`, `callService.ts 5`), `155 insertions(+), 2 deletions(-)` — plan §B.4 표 안. `providers`·`store` 변경 없음.
- 서식: `dart format`을 HEAD에서 서식이 깨끗했던 `place_intent.dart`, `kolbi_core/test/places_test.dart`, `app/test/places_test.dart`에만 적용. `intake_models.dart`는 HEAD부터 서식이 깨끗하지 않아(HEAD 사본에 `--set-exit-if-changed` → 1) 적용하지 않음. 서버는 서식 도구 설정 없음.
- 개인정보 grep: `grep -rnE "(log|logger|console)\.(info|warn|error|debug|trace|fatal)\(" server/src --include='*.ts' | grep -v '\.test\.ts' | grep -ic placequery` → `0`. 비시험 서버 소스의 `placeQuery`는 스키마·프롬프트·타입·`callService.ts:303`·`:318`(응답 객체)뿐.
- 커밋: `7b87dd2`(계획 개정 0.2.0), `d05bb86`(M7 구현).
- 조율자 확인(시뮬레이션 서버, 06497a2): "주말 오후 3시 반에 미용실 예약 가능한지 물어봐 줘" → `placeQuery` `반`(띄어 쓴 "반에"를 장소 낱말로 읽음). RED `red/amend2_server_red.txt`(`expected '반' to be '미용실'` 등 3건)·`red/amend2_core_red.txt`(`Actual: '반'`) → 두 규칙에 `N시` 뒤 `반`(+`쯤` 조사) 처리, 공유 표 19줄(`design.md` D6). GREEN: 서버 `Tests  433 passed (433)`, kolbi_core `+33: All tests passed!`, 앱 `00:14 +165: All tests passed!`.
- 조율자 확인(72e9d2e, 소유자 결정 2026-11-28: 조사만 다듬고 OD-6 그대로): "엄마한테 저녁에 늦는다고 전화해 줘" → `placeQuery` `엄마한테 늦는다고`. RED `red/amend3_server_red.txt`(`expected '엄마한테 늦는다고' to be '엄마'`, `expected '김 대리님께 회 늦는다고 전해' to be '김 대리님'`)·`red/amend3_core_red.txt`(`Actual: '엄마한테 늦는다고'`) → 두 규칙에 사람 조사 `한테서`·`께서`·`한테`·`께`(장소 조사처럼 떼고 멈춤)와 인용 어미 `다고`·`라고`·`냐고`·`자고`(멈춤), 공유 표 22줄(기존 19줄 기대값 그대로 통과). GREEN: 서버 `Tests  436 passed (436)`, kolbi_core `+33: All tests passed!`, 앱 `00:14 +165: All tests passed!`.
- 조율자 확인(25a08c7): "가족과 함께 갈 근처 고깃집 예약해 줘" → `placeQuery` `가족과 함`(`함께`의 `께`를 조사로 뗌). RED `red/amend4_server_red.txt`(`expected '가족과 함' to be '고깃집'`, `expected '친구랑 같이 먹 강남역 초밥집' to be '강남역 초밥집'`)·`red/amend4_core_red.txt`(`Actual: '가족과 함'`) → 두 규칙에 동행 표현(`함께`·`같이`, 그 앞의 `…과`·`…와`·`…랑`·`…하고`)과 관형형 동사(`갈`·`올`·`먹을`·`마실`·`모일`·`놀`·`묵을`) 건너뛰기, 앱 "근처" 판단도 같은 낱말을 건너뜀, 공유 표 24줄(기존 22줄 기대값 그대로 통과). GREEN: 서버 `Tests  438 passed (438)`, kolbi_core `+33: All tests passed!`, 앱 `00:14 +165: All tests passed!`.

#### M7 최종 확인 (HEAD d05bb86, 2026-11-28)

- `npm --prefix server test` → `Test Files  18 passed (18)`, `Tests  426 passed (426)`(이전 409). 원문 `final/amend_server_test.txt`.
- `npm --prefix server run typecheck` → exit 0(`final/amend_server_tsc.txt`).
- `cd app && flutter --suppress-analytics test` → `00:14 +165: All tests passed!`(이전 +164).
- `cd app && flutter --suppress-analytics analyze` → `info • … test/support/fakes.dart:54:5 • use_null_aware_elements`, `1 issue found.`(기준선과 같은 info 1건).
- `cd packages/kolbi_core && dart test` → `00:00 +33: All tests passed!`(이전 +32), `dart analyze` → `No issues found!`.
- `cd packages/kolbi_ui && flutter test` → `00:01 +72: All tests passed!`. 저장소 루트 `dart test` → `00:00 +2: All tests passed!`.
- `cd app && flutter build ios --simulator --debug` → `✓ Built build/ios/iphonesimulator/Runner.app`(`final/amend_ios_build.txt`). `git status`에 iOS 추적 파일 변경 없음.
- AC-010·AC-022·AC-023·AC-024 PASS(위 실행에 포함: `place search start vectors`, `place search start prefers the intake placeQuery`, `the assistant searches with the intake placeQuery`, `place query vectors shared with the app`, `intake answers with a place query`, `intake reads placeQuery leniently`, `intake placeQuery never reaches storage, events or logs`). AC-001~AC-009·AC-011~AC-021은 회귀 없음(전체 시험 통과).

## §E.3 Run-phase Audit-Ready Signal

```yaml
run_complete_at: 2026-11-28
run_start_sha: be92194
code_base_sha: 74a87c3
run_commit_sha: 25a08c7 뒤의 동행 표현 수정 커밋   # 마지막 구현 커밋(0.2.0 M7 수정 포함). 이 절을 담은 커밋은 증거 기록용
milestone_commits: [d28343a (M1), fb8ffdb (M2), b9b4096 (M3), 2d6ec54 (M4), 2e3c688 (M5), bee5d2b (M6), 7b87dd2 (계획 개정 0.2.0), d05bb86 (M7), 72e9d2e (M7 반 시간), 25a08c7 (M7 사람 조사), 동행 표현 수정 (M7)]
spec_version: 0.2.0
pushed: false
run_status: complete
ac_pass_count: 24
ac_fail_count: 0
server_tests: "449 통과 (기준 387, 0.1.x 끝 409)"
server_typecheck: "exit 0"
app_tests: "+165 통과 (기준 +148, 0.1.x 끝 +164)"
app_analyze: "info 1건 (기존 fakes.dart:54)"
kolbi_core_tests: "+33 (기준 +27, 0.1.x 끝 +32)"
kolbi_core_analyze: "No issues found!"
kolbi_ui_tests: "+72 (변경 없음)"
root_workspace_test: "+2"
ios_simulator_build: "✓ Built Runner.app"
coverage_app_places: "96.1% (391/407 lines, 0.1.x 측정 — M7 뒤 다시 재지 않음)"
coverage_server_places: "not measured — no vitest coverage provider installed"
new_dependencies: "geolocator 14.1.2 (MIT) + 13 transitive packages (M7은 새 의존 없음)"
existing_test_changes: "AC-022 표: 0.1.x 9줄(단언 7 + 주석 2) + 0.2.0 app.test.ts:699 한 줄, architecture 시험 둘과 openaiBrain.test.ts는 더하기만"
red_evidence: ".moai/state/verify/SPEC-PLACE-001/red/{m1_server,m2_server,m3_core,m3_app,m4_app,m5_app,m6_app}_red.txt, amend_server_red.txt, amend_core_red.txt, amend_core_red2.txt, amend_app_red.txt, amend2_{server,core}_red.txt, amend3_{server,core}_red.txt, amend4_{server,core}_red.txt; AC-021은 test-after"
place_query_log_grep: "0 (서버 로그 호출에 placeQuery 없음)"
ios_bypass_location_always: "빌드 설정으로는 패키지에 닿지 않음을 실행으로 확인(design.md D11) → 설정 파일 변경 없이 배포 절차로 문서화"
d11: "server/.env 읽지 않음, 서버 띄우지 않음, npm run dev/start 쓰지 않음"
owner_checks_pending: ["M7 화면 재검토(근처 치과 내일 오전 → 치과)", "첫 배포 빌드에서 BYPASS 환경 변수 + strings 확인 0", "실제 카카오 키 1건 확인", "Android 재요청 동작 확인", "실제 LLM으로 placeQuery 품질 확인(시험은 가짜 fetch만)"]
```

## §E.4 Sync-phase Audit-Ready Signal

```yaml
sync_complete_at: 2026-11-28
sync_commit_sha: pending-backfill   # 이 sync 커밋은 자기 SHA를 적을 수 없음. `git log -1 --format=%h -- .moai/specs/SPEC-PLACE-001/progress.md`로 읽음
sync_status: implemented   # sync 감사 통과 뒤 오케스트레이터가 completed로 올림(소유자 규칙)
run_start_sha: be92194   # be92194317e2bf3bd49234178ef3aa5d68daf589, 계획 커밋. 코드 기준선은 부모 74a87c3
run_commit_sha: 2d84a91   # 마지막 구현 커밋(M7 동행 표현 수정). §E.3의 "25a08c7 뒤의 동행 표현 수정 커밋"이 이것. 이 sync 커밋 직전 HEAD
milestone_commits: [d28343a (M1), fb8ffdb (M2), b9b4096 (M3), 2d6ec54 (M4), 2e3c688 (M5), bee5d2b (M6), 1ec833a (run 증거), 7b87dd2 (계획 개정 0.2.0), d05bb86 (M7), 06497a2 (M7 증거), 72e9d2e (M7 반 시간), 25a08c7 (M7 사람 조사·인용 어미), 2d84a91 (M7 동행 표현·관형형 동사)]
route: B   # 작업 폴더 /Users/jason/Documents/Jason-Danmuzi/wt-place-001의 feat/SPEC-PLACE-001, PR은 아직(병합은 소유자)
pushed_state: not-pushed
measured_by: "run 단계 기록에서 옮김(§E.2 M7 조율자 확인의 마지막 GREEN, 2d84a91 트리). manager-docs는 시험을 다시 돌리지 않음. sync는 문서만 바꿈. 이 커밋의 pre-commit 게이트 결과는 아래 pre_commit_hook_note"
server_tests_at_sync: "npm --prefix server test -> Tests 438 passed (438) (기준 387)"
server_typecheck_at_sync: "npm --prefix server run typecheck -> exit 0 (§E.2 M7 최종 확인)"
app_tests_at_sync: "cd app && flutter --suppress-analytics test -> 00:14 +165: All tests passed! (기준 +148)"
app_analyze_at_sync: "flutter analyze -> 1 issue found. (기존 info test/support/fakes.dart:54:5)"
kolbi_core_tests_at_sync: "dart test -> +33: All tests passed! (기준 +27)"
kolbi_ui_tests_at_sync: "flutter test -> +72 (변경 없음)"
root_workspace_test_at_sync: "dart test -> +2"
ios_simulator_build_at_sync: "flutter build ios --simulator --debug -> ✓ Built Runner.app (§E.2 M7 최종 확인, d05bb86)"
acceptance_distinct_ac_ids: 24   # grep -oE 'AC-([A-Z0-9]+-)*[0-9]+' .moai/specs/SPEC-PLACE-001/acceptance.md | sort -u | wc -l -> 24 (AC-001..AC-024). REQ/AC 24/24
ac_result: "24 / 24 PASS (§E.2 AC 표 + M7 최종 확인). AC-021은 test-after"
frontmatter_status_transitions:
  spec.md: in-progress -> implemented   # version 0.2.0 -> 0.2.1, updated 2026-11-28, HISTORY 0.2.1 행
spec_body_annotation:   # 본문 요구사항·인수 기준은 바꾸지 않음
  spec.md: "HISTORY 0.2.1 행만(sync 기록, M7 규칙 수정 셋, 공유 예시 표 24줄, 대체 규칙 한계는 acceptance 잔여 위험으로)"
  acceptance.md: "잔여 위험에 sync 주석 3줄(서버 1588 -> +1 판정은 그대로이고 표시만 고침, 대체 규칙의 고정 낱말 한계와 빠져나갈 길, 실제 LLM placeQuery 품질 미확인, Android 재요청 동작); 완료 정의 뒤 sync 주석(AC-001~AC-024로 읽음, 0.1.x의 '무변경' 줄은 0.2.0 AC-022 Then이 대신함, 남은 소유자 확인)"
changelog_entry_position: not-applicable   # 저장소에 CHANGELOG.md 없음. formatPhone 대표번호 표시 변화는 structure.md「어디를 고쳐야 하는가」·modules.md·README「장소 찾기」에 적음
mx_scan: skipped   # 문서만 바꾼 sync
coverage: "앱 장소 기능 96.1% (391/407, 0.1.x 측정, M7 뒤 다시 재지 않음). 서버·kolbi_core는 측정 못 함(vitest 커버리지 제공자 없음)"
divergence:
  planned_vs_changed_files: "git diff --name-only 74a87c3..2d84a91 (.moai/specs 제외) -> 57개 = plan §B 49개 + §B.4(0.2.0)에서 새로 생긴 경로 8개(server/src/domain/placeQuery.ts·placeQuery.test.ts·types.ts, brain/prompts.ts·openaiBrain.ts·openaiBrain.test.ts, services/callService.ts, http/app.test.ts). 계획 밖 파일 0. iOS SwiftPM 산출 파일 3개는 도구가 바꾸지 않아 diff 없음"
  protected_paths: "git diff --stat 74a87c3..2d84a91 -- server/src/providers server/src/store -> 출력 없음"
  plan_deviations: "createPlaceSearch는 결과를 자르지 않음(상한은 limit 5), 컨트롤러는 Riverpod Notifier 대신 화면 소유 ValueNotifier, AC-010 앱 부분은 M4에서 시험, PlatformLocationReader에 supported 검사(§E.2 계획과 다른 점)"
owner_decisions:
  - "OD-1~OD-10 모두 DECIDED(2026-11-28). OD-2·OD-3·OD-6·OD-7은 plan-audit 1차 뒤 권장 기본값, 나머지는 Kickoff 승인 때 기본값"
  - "OD-2: 판정은 조립된 config.provider. 키 없는 실제 통화 서버는 장소 검색 꺼짐(503)"
  - "OD-3: 검색 결과·장소 ID는 어디에도 기록하지 않고 확정한 작업의 이름·번호만. 법무 해석은 계속 확인"
  - "OD-6: 사람 이름이 검색어로 카카오에 전송되는 위험을 소유자가 받아들임. 0.2.0 뒤 조사만 다듬고 OD-6 그대로(소유자 결정, 72e9d2e 확인 때)"
  - "OD-7 개정(0.2.0): 소유자 화면 검토에서 '근처 치과 내일 오전 예약해 줘' -> 검색어 '치과 오전'이 나와 '서버 AI가 검색어도 뽑기'를 고름. /v1/intake 응답에 placeQuery, nearby는 앱에 남김, 기존 시험 app.test.ts:699 한 줄"
  - "iOS BYPASS_PERMISSION_LOCATION_ALWAYS: 소유자가 적용을 고름 -> 빌드 설정으로는 패키지에 닿지 않음을 실행으로 확인(design.md D11) -> 설정 파일 변경 없이 배포 절차로 문서화(README「iOS 배포 빌드」, tech.md)"
  - "D-11: 개발 서버는 실제 통화(KAT)에 쓰임. run·sync는 그 서버를 멈추거나 다시 띄우거나 데이터·설정을 건드리지 않고 server/.env를 읽지 않음. 로컬 확인은 CALL_PROVIDER=simulated로 따로 띄운 서버만"
owner_screen_review:
  finding: "'근처 치과 내일 오전 예약해 줘'의 첫 검색어가 '치과 오전'(앱 규칙이 '오전'을 건너뛰지 않음)"
  fix: "0.2.0: 서버 placeQuery(LLM + 결정적 규칙)와 앱 대체 규칙에 시간 낱말. 이어서 조율자 확인 셋으로 규칙 수정: '3시 반에' -> '반'(72e9d2e), '엄마한테 … 늦는다고' -> 사람 조사·인용 어미(25a08c7), '가족과 함께 갈 근처 고깃집' -> '가족과 함'(2d84a91, 동행 표현·관형형 동사). 공유 예시 표 12 -> 19 -> 22 -> 24줄, 서버·앱 두 시험이 같은 표를 고정"
  rescreen: pending   # 소유자: M7 화면 재검토('근처 치과 내일 오전' -> '치과')
known_limits:
  - "대체 규칙은 고정 낱말 목록: 목록에 없는 관형형 동사(앉을·쉴 등)나 낯선 말투는 검색어에 섞일 수 있음. 검색칸 고치기와 [번호 직접 입력]이 빠져나갈 길"
  - "실제 LLM(OpenAiBrain)의 placeQuery 품질은 가짜 fetch 시험으로만 확인"
  - "서버 checkTargetNumber는 '1588-0000'을 +15880000(국가 번호 +1)으로 판정하는 동작 그대로. 표시만 formatPhone에서 1588-0000으로 고침(앱 전체 적용). 판정 개정은 SPEC-POLICY-001 쪽"
  - "사용자별 검색 제한 없음(쿼터 일 100,000건), 카카오 오류·쿼터 초과 응답 형식 미확인(상태 코드만 보고 502)"
debt_carried:
  - "서버·kolbi_core 커버리지 측정 안 됨(커버리지 제공자 없음)"
  - "AC-021 접근성 블록은 test-after"
  - "iOS 배포 빌드 자동화(스크립트·CI) 없음"
  - "docs/planning/01_SERVICE_BENCHMARK.md §5.2의 카카오 size '최대 30'(주소 검색 기준) 정정은 plan §G가 '소유자 판단'으로 둔 항목이라 고치지 않음. 03 §8.1에는 키워드 검색 1~15를 적음"
owner_checks_pending:
  - "카카오 개발자 콘솔에서 그 앱의 카카오맵(로컬) API 사용 설정과 REST API 키 확인, 실제 키로 '강남역 파스타' -> 후보 -> 계획 카드 1건(서버 로그에 결과 없음, 실패면 status 401/403 기록)"
  - "첫 iOS 배포 빌드: cd app && flutter clean && BYPASS_PERMISSION_LOCATION_ALWAYS=1 flutter build ipa 뒤 strings ... | grep -c requestAlwaysAuthorization -> 0"
  - "Android: 위치 권한을 한 번 거부한 뒤 다시 '근처' 부탁을 하면 사전 안내가 다시 보임(checkPermission의 denied를 '아직 안 물음'으로 읽음). OS 창이 다시 뜨는지 실기기 확인"
  - "실기기 위치 권한 창(iOS·Android 한 대)과 대략 위치로 '근처' 검색 한 번"
  - "OD-3 법무·약관 해석(작업 기록이 '결과 저장'에 해당하는지)"
  - "M7 화면 재검토, 실제 LLM으로 placeQuery 품질 확인"
simulator_check: done   # run 단계: iOS 시뮬레이터 debug 빌드 성공(§E.2). 화면 검토는 소유자가 따로 띄운 시뮬레이션 서버로 함(D-11)
device_check: pending   # 소유자: 실기기 위치 권한 창, Android 재요청 동작
untracked_handling: "git ls-files --others --exclude-standard -> 출력 없음. iOS SwiftPM Package.resolved 변경 없음"
pre_commit_hook_note: "이 sync 커밋은 pre-commit 훅(moai gate)을 정상 실행함. --no-verify·SKIP_MOAI_PRECOMMIT 쓰지 않음"
plan_g_items:
  "(0.2.0) /v1/intake placeQuery": ".moai/project/structure.md REST 표에 /v1/intake 행(응답 키, placeQuery, 옛 서버 호환), docs/product/11_ARCHITECTURE.md §4.3 '접수와의 관계'(설계서에 접수 전용 절이 없어 장소 검색 절에 둠), codemaps entry-points.md 라우트 표"
  "(0.2.0) iOS 배포 절차": "README.md「iOS 배포 빌드」(명령과 strings 확인), .moai/project/tech.md 「코드로 확인된 제약」"
  .moai/project/structure.md: "서버 places/ 4행과 domain/placeQuery.ts, http/app.ts·schemas.ts, 계층 그림, 제공자 선택에 장소 검색·접수 검색어, 앱 features/places 트리, shell/place_search.dart·request_intake(requestIntake), /assistant/places 경로, REST 표 /v1/intake·/v1/places/search와 오류 코드 502·503, architecture_test 행, 어디를 고쳐야 하는가 4행(장소 검색, 첫 검색어 규칙, 장소 선택·위치, 번호 표시)"
  .moai/project/tech.md: "앱 패키지 geolocator ^14.1.2(MIT), 환경 변수 KAKAO_REST_API_KEY·KAKAO_LOCAL_BASE_URL와 키가 없을 때의 동작, 외부 시스템 카카오 로컬, 제약(결과 저장 금지·no-store, 위치, iOS 배포 빌드)"
  codemaps: "modules.md(domain/placeQuery, places/ 절, http AppDeps, container·config, formatPhone, plan_card·home·request_box 문구, features/places 표, shell place_search·requestIntake·openAssistantPlaces, kolbi_core 장소 추가분, 시험 목록); entry-points.md(기동 단계, 오류 처리기 502, /v1/intake·/v1/places/search 핸들러, /assistant/places 진입); dependencies.md(zod 사용처, 카카오 fetch, geolocator 사용 파일, mermaid 두 그림에 places 노드)"
  docs/product/11_ARCHITECTURE.md: "§2.5 표에 /assistant/places와 SPEC-PLACE-001 구현 문단, §4.3 실제 포트 모양·카카오 필드 확인('검증 필요' 해소)·OD-2 꺼짐·placeQuery·구조 규칙, S-2, 개정 이력"
  docs/planning/03_SERVICE_FEATURE_PLAN.md: "§8.1에 키워드 검색 size 1~15 행과 OD-5 진행 상황, 개정 이력"
  docs/planning/01_SERVICE_BENCHMARK.md: "고치지 않음(소유자 판단 항목, debt_carried)"
  .moai/specs/EPIC-KOLBI-APP/overview.md: "머리 상태 줄과 §2 표: PLACE-001 implemented(0.2.1), 문서 6개, Tier L"
  README.md: "「장소 찾기」(흐름, 결과를 남기지 않음, 위치 권한과 문구, KAKAO_REST_API_KEY와 콘솔 설정, 대표번호 표시), 「iOS 배포 빌드」, 실제 통화 변수 표에 KAKAO_REST_API_KEY, 화면 구성·말로 부탁하기의 '최근 장소', 폴더 트리(server places/, app features/places/, kolbi_core)"
  server/.env.example: "run에서 이미 바뀜(B.1): 값 없는 KAKAO_REST_API_KEY=와 설명, 주석 처리한 KAKAO_LOCAL_BASE_URL"
  formatPhone_app_wide: "structure.md「어디를 고쳐야 하는가」번호 표시 행, modules.md formatters 행, 11_ARCHITECTURE SPEC-PLACE-001 구현 문단, README「장소 찾기」. CHANGELOG.md는 없음"
project_docs_synced: [README.md, .moai/project/structure.md, .moai/project/tech.md, .moai/project/codemaps/modules.md, .moai/project/codemaps/entry-points.md, .moai/project/codemaps/dependencies.md, docs/product/11_ARCHITECTURE.md, docs/planning/03_SERVICE_FEATURE_PLAN.md, .moai/specs/EPIC-KOLBI-APP/overview.md]
sync_audit: pending
```

### sync 감사 1차 후속 수정 (2026-11-28)

감사 보고서 `.moai/reports/sync-audit/SPEC-PLACE-001-audit-1.md`(PASS-with-debt 88.2, HEAD `d29fb4e`). 소유자가 모든 지적을 고치기로 승인함(2026-11-28). spec `status`는 `implemented` 그대로.

| 지적 | 바꾼 것 | 시험 | RED |
|---|---|---|---|
| S1 대체 규칙의 묻는 말 | 서버 `domain/placeQuery.ts`·`kolbi_core` `place_intent.dart`를 똑같이: 낱말 끝 `?`·`.`·`!`·`~` 지움, 멈춤 낱말 `가능…`·`있어`·`있나(요)`·`있을까(요)`·`되나(요)`·`돼(요)`·`될까(요)`·`하나요`·`해요`·`자리`·`좌석`·`가격`·`메뉴`·`영업시간`·`문`, 세 글자 이상 낱말의 `…한지`·`…나요`(두 글자 `한지`는 이름으로 남음), 이유 낱말(`…이라`·`…라서`·`…니까`) 앞은 버림, `…랑`+관형형 동사·`모시고`/`데리고`와 그 앞 낱말 건너뜀, `다닐` 추가, `24시`는 분류로 남김. `design.md` D6 34줄 | 공유 표에 10줄 더함(감사 3.5의 '나쁨' 일곱 줄 모두 + `가능해?`·`문 열었나요?`·`한지 공방` 보호 줄). 프로그램 비교 `34 34 True`. 기존 24줄 그대로 통과 | `red/audit1_server_red.txt`: `Tests  9 failed | 28 passed (37)` — `expected '홍대 고기집 자리 있어?' to be '홍대 고기집'`, `expected '약국 있나' to be '24시 약국'` 등. `red/audit1_core_red.txt`: `Actual: '홍대 고기집 자리 있어?'` |
| S2 README 낡은 문장 | `README.md:26`에 "번호 없이 장소만 말하면 먼저 장소 선택을 열고, 고른 곳으로 계획 카드를 채웁니다" | 문서 | — |
| I2 앱 좌표 반올림 | `kolbi_core` `places_repository.dart`가 보내기 전에 소수 셋째 자리로 반올림(서버 반올림은 그대로). README 위치 권한 문장도 고침 | `places_test.dart` "the places repository posts …": `(37.497952, 127.027619)` → 본문 `{lat: 37.498, lng: 127.028}` | `red/audit1_core_red.txt`: `Actual: {'query': '세탁소', 'near': {'lat': 37.497952, 'lng': 127.027619}}` |
| I3 `KAKAO_LOCAL_BASE_URL` https | `config.ts`가 `https`만 받고 `http`는 `127.0.0.1`·`localhost`만 받음. 어기면 기동 때 `loadConfig`가 실패하고 오류 문구는 고정(값 없음). `tech.md`·`design.md` D2 한 줄 | 새 `server/src/config.test.ts`: 기본값·https·루프백 통과, `http://marker-host…`·`ftp://`·주소 아님·`http://localhost.marker…` 거부, 오류 문구에 `KAKAO_LOCAL_BASE_URL`은 있고 표식 호스트·키는 없음 | `red/audit1_server_red.txt`: `http://marker-host-71c2.example: expected [Function] to throw an error` |
| I5 제목 버전 | `acceptance.md`·`design.md` 제목 `(0.2.1)` | — | — |

I1(플랫폼 위치 어댑터 커버리지)·I4(400 응답 `no-store` 단언)·I6(소유자 확인)은 이번 지시에 없어 그대로 둠.

확인(이 커밋 직전 작업 트리):
- `npm --prefix server test` → `Test Files  19 passed (19)`, `Tests  449 passed (449)`(감사 기준 438). typecheck exit 0. 원문 `final/audit1_server_test.txt`.
- `cd packages/kolbi_core && dart test` → `00:00 +33: All tests passed!`, `dart analyze` → `No issues found!`.
- `cd app && flutter --suppress-analytics test` → `00:14 +165: All tests passed!`, `flutter analyze` → 기준선 info 1건(`fakes.dart:54`).
- `kolbi_ui` → `+72: All tests passed!`, 루트 `dart test` → `+2: All tests passed!`.
- 서식: `dart format`을 HEAD에서 깨끗했던 `place_intent.dart`, `places_repository.dart`, `kolbi_core/test/places_test.dart`에만 적용.
- 커밋: `fix(SPEC-PLACE-001): sync audit 1 follow-ups — placeQuery questions, app rounding, Kakao https`(이 절을 담은 커밋).

## §F Phase 4 Mode Selection

- kickoff: 소유자가 구현 시작을 승인함(2026-11-28, "기본값으로 시작"). OD-1~OD-10 모두 결정됨. 진행은 자율 실행 뒤 소유자가 화면을 보고 sync·감사·PR, 병합은 소유자
- precondition: SPEC-ASSIST-001 `completed`(PR #2로 main에 병합, 74a87c3). plan-audit 2차 PASS 0.91
- route: 작업 폴더 /Users/jason/Documents/Jason-Danmuzi/wt-place-001의 feat/SPEC-PLACE-001 브랜치(origin/main 74a87c3에서 만듦). 계획 문서도 이 브랜치의 첫 커밋으로 PR에 함께 들어감
- D-11: 개발 서버는 실제 통화(KAT)에 쓰이므로 run 단계는 그 서버를 건드리지 않음. 로컬 확인은 따로 띄운 CALL_PROVIDER=simulated 서버로만 하고 server/.env는 읽지 않음
- inputs: tier L(약 49개 파일, 마일스톤 6개), 영역: 서버 places 모듈과 경로, kolbi_core 검색어·표시, 앱 장소 선택 화면·위치 포트·계획 카드, 테스트. 언어: TypeScript + Dart + iOS/Android 설정. 병렬 이득 낮음
- evaluation: direct — 선택 안 함, fanout — 선택 안 함(코딩 위주), sweep — 선택 안 함(기계적 일괄 변환 아님), serial — 선택
- Decision: serial
- justification: M1의 서버 계약과 저장 금지 증명이 앱 쪽 마일스톤의 바탕이고, 앱 마일스톤들이 같은 라우터·비서 화면·계획 카드를 고치므로 한 작업자가 순서대로 해야 충돌이 없다. manager-lead를 쓸 만큼 영역이 나뉘지 않아 serial로 둔다
