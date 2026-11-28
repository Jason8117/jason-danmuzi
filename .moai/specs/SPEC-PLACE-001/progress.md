# SPEC-PLACE-001 진행 기록

## §E.1 Plan-phase Audit-Ready Signal

- plan_status: audit-ready
- plan_status_final: plan-audit 2/3차 PASS 0.91 (보고서 `.moai/reports/plan-audit/SPEC-PLACE-001-review-2.md`). 감사 2차 지적 N1~N4는 0.1.2에서 반영
- kickoff: 소유자 Implementation Kickoff Approval 2026-11-28
- plan_complete_at: 2026-11-28
- spec_version: 0.1.2 (계획 감사 2차 PASS 0.91 뒤 N1~N4 정리)
- spec_version_history: 0.1.0 → 0.1.1(계획 감사 1차 FAIL 0.84 반영, 보고서 `.moai/reports/plan-audit/SPEC-PLACE-001-review-1.md`) → 0.1.2
- base_sha: 74a87c3 (SPEC-ASSIST-001 병합 직후 `main`. 계획 문서는 아직 커밋 전. run_start_sha는 run에서 기록)
- tier: L (서버 새 모듈·외부 어댑터·새 경로 + 앱 새 기능·새 의존, 49개 파일(+ 도구가 갱신하는 iOS SwiftPM 산출 파일 최대 3개), 1,000줄 이상 예상. 에픽 개요 §2 표의 예상 M보다 큼 — 에픽 표는 sync에서 갱신하는 관례라 계획 단계에서는 고치지 않음), harness: standard (권장, 외부 API·개인정보 경계로 thorough도 고려), methodology: tdd, mode: serial
- artifacts: spec.md, plan.md, acceptance.md, design.md, research.md, progress.md
- counts: 22 REQ / 22 AC (Tier L 상한 25 / 25)
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

## §F Phase 4 Mode Selection

- kickoff: 소유자가 구현 시작을 승인함(2026-11-28, "기본값으로 시작"). OD-1~OD-10 모두 결정됨. 진행은 자율 실행 뒤 소유자가 화면을 보고 sync·감사·PR, 병합은 소유자
- precondition: SPEC-ASSIST-001 `completed`(PR #2로 main에 병합, 74a87c3). plan-audit 2차 PASS 0.91
- route: 작업 폴더 /Users/jason/Documents/Jason-Danmuzi/wt-place-001의 feat/SPEC-PLACE-001 브랜치(origin/main 74a87c3에서 만듦). 계획 문서도 이 브랜치의 첫 커밋으로 PR에 함께 들어감
- D-11: 개발 서버는 실제 통화(KAT)에 쓰이므로 run 단계는 그 서버를 건드리지 않음. 로컬 확인은 따로 띄운 CALL_PROVIDER=simulated 서버로만 하고 server/.env는 읽지 않음
- inputs: tier L(약 49개 파일, 마일스톤 6개), 영역: 서버 places 모듈과 경로, kolbi_core 검색어·표시, 앱 장소 선택 화면·위치 포트·계획 카드, 테스트. 언어: TypeScript + Dart + iOS/Android 설정. 병렬 이득 낮음
- evaluation: direct — 선택 안 함, fanout — 선택 안 함(코딩 위주), sweep — 선택 안 함(기계적 일괄 변환 아님), serial — 선택
- Decision: serial
- justification: M1의 서버 계약과 저장 금지 증명이 앱 쪽 마일스톤의 바탕이고, 앱 마일스톤들이 같은 라우터·비서 화면·계획 카드를 고치므로 한 작업자가 순서대로 해야 충돌이 없다. manager-lead를 쓸 만큼 영역이 나뉘지 않아 serial로 둔다
