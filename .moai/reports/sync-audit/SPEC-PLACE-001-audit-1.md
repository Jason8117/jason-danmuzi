# Sync 감사 보고서 — SPEC-PLACE-001 (1차)

- 감사 대상: 워크트리 `/Users/jason/Documents/Jason-Danmuzi/wt-place-001`, 브랜치 `feat/SPEC-PLACE-001`, HEAD `d29fb4e`(sync 커밋). 코드 기준선 `74a87c3`(origin/main), 계획 커밋 `be92194`, 마지막 구현 커밋 `2d84a91`
- 등급: 24 REQ / 24 AC, spec `version: "0.2.1"`, `status: implemented`. 변경 72개 파일, +5934/−100
- 형식: 선례 `SPEC-ASSIST-001-audit-1.md`와 같은 네 차원(Functionality 40%, Security 25%, Craft 20%, Consistency 15%). 필수 통과 차원은 Functionality와 Security. 집계는 비가중 조화 평균이고, 참고로 가중 조화 평균도 적는다.
- 감사 방식: 읽기 전용. 아래 명령은 이번 감사에서 HEAD `d29fb4e` 트리에 직접 실행했다. `server/.env`는 읽지 않았고 `npm run dev`/`npm start`는 실행하지 않았다(D-11). 서버를 띄울 필요가 없어 띄우지 않았다. 임시 파일(커버리지 계산, 새 문장 실험 스크립트)은 세션 scratchpad에 두었고, `packages/kolbi_core`에 잠깐 만든 실험 폴더는 바로 지웠다(`git status` 깨끗함 확인). 저장소에 쓴 파일은 이 보고서 하나다.
- 상태: 완료

## 1. 판정 요약

| 차원 | 점수 | 판정 | 근거 요약 |
|------|------|------|-----------|
| Functionality (40%) | 90 | PASS | 명령을 모두 다시 실행했고 기대 결과가 나왔다(서버 438, 앱 +165, kolbi_core +33, kolbi_ui +72, 루트 +2, typecheck 0, 분석은 기준선 info 1건뿐). AC 24개 모두 이름이 맞는 시험에 연결되고, 시험 본문이 Then 조건을 확인한다. 서버와 앱의 공유 표 24줄이 프로그램 비교에서 똑같았다. 감점: 대체 규칙이 흔한 의문형 말투("자리 있어?", "가능한지", "있나")에서 검색어를 더럽힌다(S1) |
| Security (25%) | 90 | PASS | 키는 서버 환경 변수로만 받고, 로그·응답·앱에 나오지 않는다(시험 표식 `test-kakao-key`, `grep KAKAO app packages` 0건). D-8 증명 시험이 제대로 되어 있다. 권한 선언은 최소이고, geolocator 플러그인 매니페스트도 권한을 합치지 않는다. diff에 비밀 값이 없다. Critical/High는 없다. 감점: 앱이 반올림 전 좌표를 콜비 서버로 보낸다(서버가 반올림하며 기록하지 않음, I2). `KAKAO_LOCAL_BASE_URL`가 https를 강제하지 않는다(I3) |
| Craft (20%) | 85 | PASS | 새 기능 파일 커버리지: 카드·상세·사전 안내 100%, 컨트롤러 98.6%, 화면 97.9%. 오류를 원인 없이 다시 만드는 설계와 `@MX` 주석이 분명하다. 새 Dart 파일 15개가 모두 서식 통과. 감점: `platform_location_reader.dart` 57.7%(플러그인이 없는 시험 환경 한계, I1). 대체 규칙은 고정 낱말 목록이라 확장성이 약하다(S1) |
| Consistency (15%) | 88 | PASS | 기존 시험 변경이 AC-022 표와 정확히 일치한다. 동기화 문서(structure, tech, codemaps, 11_ARCHITECTURE, 03, README, EPIC)의 경로·함수·동작 서술이 코드와 맞는다. progress의 시험 수가 재실행 결과와 같다. 감점: README "말로 부탁하기" 문단의 한 문장이 낡았다(S2). acceptance/design 제목 버전이 0.2.0이다(I5) |
| **조화 평균** | **88.2** (가중 88.6) | | |

**최종 판정: PASS-with-debt.** 두 필수 차원 모두 통과했고 반드시 고칠 결함은 없다. S1(대체 규칙의 의문형 어미)과 S2(README 한 문장)는 PR 병합 전이나 직후 작은 개정으로 고치기를 권한다.

## 2. 기준 측정 (이번 감사, HEAD `d29fb4e`)

```
$ npm --prefix server test
 Test Files  18 passed (18)
      Tests  438 passed (438)

$ npm --prefix server run typecheck
> tsc -p tsconfig.json --noEmit
(exit 0)

$ cd packages/kolbi_core && dart test
00:00 +33: All tests passed!
$ dart analyze
No issues found!

$ cd packages/kolbi_ui && flutter --suppress-analytics test
00:01 +72: All tests passed!

$ cd app && flutter --suppress-analytics test --coverage
00:17 +165: All tests passed!

$ cd app && flutter --suppress-analytics analyze
   info • Use the null-aware marker '?' rather than a null check via an 'if'. Try using '?' • test/support/fakes.dart:54:5 • use_null_aware_elements
1 issue found.        (기준선 info 1건뿐. exit 1은 이 info 때문)

$ dart test            (저장소 루트)
00:00 +2: All tests passed!
```

기준선(서버 387, 앱 +148, kolbi_core +27)보다 줄어든 수가 없다(AC-022 충족).

커버리지(앱 `coverage/lcov.info`, 새로 만들거나 고친 파일):

| 파일 | 줄 |
|---|---|
| `features/places/place_card.dart` | 93/93 100% |
| `features/places/place_detail_sheet.dart` | 52/52 100% |
| `features/places/location_consent_sheet.dart` | 14/14 100% |
| `features/places/place_search_controller.dart` | 72/73 98.6% |
| `features/places/place_search_screen.dart` | 142/145 97.9% |
| `features/calls/presentation/plan_card_screen.dart` | 166/181 91.7% |
| `shell/request_intake.dart` | 12/13 92.3% |
| `shell/place_search.dart` | 3/4 75.0% |
| `features/places/location/platform_location_reader.dart` | 15/26 57.7% |

## 3. Functionality — 90, PASS

### 3.1 AC → 증거

| AC | 시험 | 이번 감사에서 직접 본 것 |
|---|---|---|
| AC-001 | placeSearch.test "the container picks the place provider…" | `container.ts`는 조립이 끝난 `config.provider`로 판단한다. `loadConfig`가 `auto`+KAT 미완비를 `simulated`로 바꿔 두므로 "조립된 제공자 규칙"이 맞다. 키 있음 → kakao, 키 없음+simulated → simulated, 키 없음+kat → `undefined`. `index.ts` 기동 로그에는 `placeSearch: places?.source ?? "off"`만 있다 |
| AC-002 | places.test "validates and answers in the documented shape", "hands the provider the documented query" | 401, 400 세 가지(메시지에 입력 없음), 200 응답 키, 후보 키 8개, `distanceM` null, `Cache-Control: no-store`, near 오름차순을 확인한다. 반올림 `37.4979→37.498`, `127.0276→127.028`, 모르는 필드 `extra`는 버린다 |
| AC-003 | placeSearch.test "every candidate number goes through checkTargetNumber", kolbi_core "formatPhone shows Korean representative numbers" | 번호 판정은 `toCandidate` 한 곳에서 `checkTargetNumber`를 거친다. 여섯 줄의 기대값이 AC와 같다. `formatPhone` 정규식 `^\+1([568]\d{6})$`: `+15880000→1588-0000`, `+14155550100`(10자리)과 `+17001234`는 그대로 둔다. `unit_test.dart`는 무변경이고 통과한다 |
| AC-004 | places.test "place search results never reach storage, cache, events or logs", 앱 "choosing a place fills the plan card" 끝부분 | 아래 3.2 참고 |
| AC-005 | kakaoLocalPlaceSearch.test, placeSearch.test "search rejects only with a bare PlaceSearchError" | 어댑터는 실패 응답의 본문을 읽지 않는다. `fail()`은 `{provider, kind, status}`만 경고로 남긴다. `createPlaceSearch`는 어떤 예외든 새 `PlaceSearchError`로 만든다(원인 없음). 정규화 중 예외(가짜 배열)도 감싼다 |
| AC-006 | "the simulated provider is deterministic and offline" | 해시로 정해지는 다섯 칸(`ok`·`missing`·`invalid` 포함), 이름 "연습용 …", near가 없으면 거리 null |
| AC-007 | "without a place provider the route answers 503" | 503 응답 본문과 `no-store`를 확인한다. 토큰이 없으면 여전히 401이다. `/v1/tasks`·`/v1/config`·`/v1/intake` 응답은 places가 있을 때와 같다 |
| AC-008 | architecture.test 세 블록 | 허용 import 목록, `new Map(`/`Set`/`fs` 금지, 모듈 수준 `let` 금지, http의 구체 제공자 이름 금지, `any` 금지를 검사한다. 파일을 실제로 읽었는지도 단언한다(`kakaoLocalPlaceSearch.ts` 포함) |
| AC-009 | 앱 "the assistant opens place selection only when the number is missing" | (1)(2) `/assistant/places`, 탭 바 없음, 뒤로 가면 입력 문장이 그대로다. (3)~(6) `/assistant/plan`이고 `searchCalls`가 비어 있다. 404는 `IntakeResult(draft: blank)`라 계획 카드로 간다 |
| AC-010 | kolbi_core "place search start vectors"/"…prefers the intake placeQuery", 앱 두 블록 | 24줄 표, 이름 있음, 번호 있음·차단 null, 30자 자르기, `fromJson` `7`→null |
| AC-011~AC-014 | 앱 해당 블록 | 세로 순서 비교, Filled/Outlined, 걸 수 없는 후보 `onPressed == null`, 상세 시트의 클립보드 기록과 초점 복귀 |
| AC-015 | "choosing a place fills the plan card" | `create` 요청의 `targetName`·`phoneNumber`. (4) `+15880000` 글자가 화면에 없고 요청에는 `+15880000`이 있다 |
| AC-016/017 | "nearby asks for location with a purpose first", "location stays out of storage and other requests" | [계속] 전 `request` 0회, 뒤 1회. near가 아닌 부탁에서는 `access+request+read` 0회, `SharedPreferences`에 `37.55`·`126.91`이 없다 |
| AC-018 | architecture_test "platform files declare coarse location only" | Info.plist·AndroidManifest diff는 각각 2줄. `NSLocationAlways`·FINE·BACKGROUND 없음 |
| AC-019 | "the plan card folds defaults into one line" | `_TapText`가 48×48 최소 크기이고, `plan_card_test`·`shell_test`는 무변경으로 통과한다 |
| AC-020 | AC-022 표의 블록 | `grep -rn "최근 통화한 곳" app/lib` 출력 없음 |
| AC-021 | "place screens meet the accessibility guidelines" | 네 지침, 360×640·2.0배, polite 알림 1회, 다시 그려도 알림이 늘지 않음 |
| AC-022 | git diff | 3.4 참고 |
| AC-023 | domain/placeQuery.test, places.test "intake answers with a place query", openaiBrain.test "intake reads placeQuery leniently" | `IntakeSchema.placeQuery`는 `.max(100).optional().catch(undefined)`라 잘못된 값이 있어도 intake 전체가 휴리스틱으로 떨어지지 않는다(경고 0). `CallService`는 `cleanPlaceQuery(...) || placeQueryFor(masked, …)`. 프롬프트에 `placeQuery`와 `"근처"`가 있다 |
| AC-024 | places.test "intake placeQuery never reaches storage, events or logs" | LLM 성공·실패 두 경로에서 표식이 응답에만 있다. `grep -rnE "(log|logger)\.(info|warn|error|debug)\(" server/src | grep placeQuery` 출력 없음 |

### 3.2 D-8 증명 시험 검토 (AC-004)

- 준비: 임시 디렉터리의 실제 `JsonFileTaskStore`(작업 1개). Fastify는 `logger: { stream }`로 만든다. 이 옵션은 운영 설정(`req` serializer, 토큰 가림)을 그대로 두고 출력만 바꾼다(`app.ts`의 spread). 그래서 "운영 serializer 위의 로그 스트림" 요구를 만족한다. 어댑터 로거, `console.*`, `process.stdout.write`도 붙잡는다.
- 다섯 단계: 200 두 번(캐시 없음, `fetchCalls` 5), 500 본문 표식, `TypeError`(메시지·`input`·`code`에 표식), 형식이 틀린 200(`id: 7`, place_name 표식). 실패 셋은 모두 `{error: "place_search_failed", message: "Place search failed"}`.
- 표식 15개(이름, 번호 원문과 E.164, 주소, 장소 ID, 검색어, 원래 좌표와 반올림 좌표, 오류 본문, 예외 메시지, `ERR_INVALID_URL`, 형식 표식, 키)가 붙잡은 출력과 실패 본문 어디에도 없다. `captured.length > 0`으로 붙잡기 자체도 확인한다.
- 저장소 파일 바이트와 디렉터리 목록이 그대로이고, `store.list()`도 그대로다. 저장 디바운스를 감안해 400ms를 기다린다. 이벤트 수는 0이다.
- 코드 측면: 오류 처리기는 `PlaceSearchError`를 `request.log.error`보다 먼저 잡아 `{kind, status}`만 경고로 남긴다. `PlaceSearchError`에는 원인이나 원래 메시지를 담을 자리가 없다. 요청 본문은 기본 serializer상 로그에 들어가지 않는다.

### 3.3 서버 규칙과 앱 대체 규칙 표 비교 (프로그램 비교)

`server/src/domain/placeQuery.test.ts`의 `it.each` 표와 `packages/kolbi_core/test/places_test.dart`의 `vectors`를 정규식으로 뽑아 비교했다. 결과는 `24 24 identical: True`(null ↔ `''` 대응). 두 구현의 낱말 목록(`TIME_WORDS`, `WHEN_PARTICLES`, `REQUEST_*`, `PLACE_PARTICLES`, 동행·관형형 목록, `COUNT_WORD`, `HOUR_WORD`)도 눈으로 대조했고 같았다. 아래 3.5의 새 문장 15개도 두 구현이 같은 검색어를 냈다.

### 3.4 시험 변경 규율 (AC-022)

- `git diff 74a87c3..HEAD -- app/test/{today,assistant,accessibility,intake_flow}_test.dart`: 바뀐 줄은 `'최근 통화한 곳'` → `'최근 장소'`뿐이다(assistant 3줄+주석 1, today 1+주석 1, accessibility 1, intake_flow 2). 표의 줄 번호와 맞는다.
- `architecture_test.dart`, `server/src/architecture.test.ts`, `openaiBrain.test.ts`는 파일 끝에 더하기만 했다(openaiBrain.test는 import 1줄 + 끝 블록).
- `app.test.ts`는 `:699` 한 줄만 바뀌었다(`placeQuery` 키 추가).
- 가짜: `fakes.dart`는 무변경이고, `fake_location_reader.dart`·`fake_places_repository.dart`를 새로 더했다.
- `server/src/providers`·`store`는 무변경이다.
- 구조 규칙: `features/places`는 다른 기능을 가져오지 않는다(`shell/navigation`, `shell/place_search`만). `permission_handler`는 `assistant/speech`에만, `geolocator`는 `places/location/platform_location_reader.dart`에만 있다. 서버 `places/`는 `./`, `../domain/`, `../logger.js`, `zod`만 가져온다.

### 3.5 새 문장으로 해 본 대체 규칙 (정보)

서버 `placeQueryFor(text, null)`과 kolbi_core `placeSearchStartFor`에 표에 없는 문장 15개를 넣었다. 두 구현의 결과는 같았다.

| 문장 | 검색어 | 평가 |
|---|---|---|
| 근처 피자집에서 피자 두 판 배달되는지 물어봐 줘 | 피자집 | 좋음 |
| 홍대 근처 고기집 오늘 저녁 6명 자리 있어? | **홍대 고기집 자리 있어?** | 나쁨: 의문형 어미와 `?` |
| 동물병원 오늘 진료하는지 알려줘 | 동물병원 | 좋음 |
| 역삼동 맛있는 삼겹살집 예약 부탁해 | 역삼동 맛있는 삼겹살집 | 보통(형용사 "맛있는") |
| 내일 오후에 다닐 헬스장 가격 물어봐 | **다닐 헬스장 가격** | 나쁨: 목록 밖 관형형, "가격" |
| 아이랑 갈 키즈카페 주말 예약해 줘 | **아이랑 키즈카페** | 나쁨: "…랑"은 `함께`·`같이`가 뒤따를 때만 뗌 |
| 회사 앞 중국집에 짜장면 두 개 주문해줘 | 회사 앞 중국집 | 보통 |
| 치과 예약 좀 | 치과 | 좋음 |
| 스타벅스 강남점에 케이크 있는지 | 스타벅스 강남점 | 좋음 |
| 근처에 24시 약국 있나 찾아줘 | **약국 있나** | 나쁨: `있나` |
| 부모님 모시고 갈 한정식집 다음주 토요일 예약 | **부모님 모시고 한정식집** | 나쁨 |
| 가까운 정형외과 오늘 몇 시까지 해? | 정형외과 | 좋음 |
| 판교 주변 세차장 지금 가능한지 확인해 줘 | **판교 세차장 가능한지** | 나쁨: `가능한지` |
| 엄마 생신이라 케이크 가게에 예약 | 엄마 생신이라 케이크 가게 | 나쁨(드문 말투) |
| 근처 미용실에 커트 예약 가능해? | 미용실 | 좋음 |

해석: LLM 두뇌가 켜진 서버에서는 이 규칙이 대체 경로일 뿐이다. 그러나 휴리스틱 두뇌 서버(OpenAI 키 없음)와 LLM 실패 때에는 주 경로다. "자리 있어?", "있나", "가능한지"처럼 아주 흔한 의문형 끝맺음이 검색어에 섞이면, 카카오 키워드 검색이 0건이 되기 쉽다. 사용자가 검색칸에서 고칠 수 있고 [번호 직접 입력]도 있어 막히지는 않는다. 그래서 must-fix가 아니라 S1으로 둔다.

## 4. Security — 90, PASS

- 키: `config.ts`에서 `KAKAO_REST_API_KEY: optional`로 받는다. 쓰는 곳은 `container.ts` → 어댑터의 `authorization` 머리뿐이다. 기동 로그에는 `placeSearch` 값만 있다. 증명 시험 표식에 키가 있고 0건이다. `grep -rn KAKAO app/lib app/test packages` 출력 없음. `.env.example`은 빈 값이다.
- 비밀 값: diff에서 `sk-…`·`KakaoAK <긴 값>`·긴 api key 리터럴을 찾았고 0건이었다(시험용 `test-kakao-key`, `sk-test`만 있음).
- 위치: 앱은 "근처" 부탁에서만, 사전 안내 뒤에 `LocationAccuracy.low`로 10초 제한을 두고 한 번 읽는다. 위치는 상태·저장소에 남지 않는다(시험). 서버는 소수 셋째 자리로 반올림한 뒤에만 카카오로 넘긴다. [다시 시도]는 위치를 새로 읽는다(보관하지 않음).
- 권한: Info.plist에 `NSLocationWhenInUseUsageDescription` 1개, AndroidManifest에 `ACCESS_COARSE_LOCATION` 1개. pub 캐시의 `geolocator_android-5.2.1` 매니페스트에는 `uses-permission`이 없어 합쳐지는 권한도 없다.
- iOS "항상" 위치: `geolocator_apple 2.4.3`이 `BYPASS_PERMISSION_LOCATION_ALWAYS` 환경 변수를 받지 못하면 `requestAlwaysAuthorization`을 남긴다. 이 점이 D11(실행 기록 표), README 「iOS 배포 빌드」, tech.md에 일관되게 적혀 있다. 첫 배포 빌드의 `strings` 확인은 소유자 확인으로 남았다(progress §E.4).
- D-8과 `placeQuery`: 3.2와 AC-024 참고.
- 감점 근거(정보): I2, I3.

## 5. Craft — 85, PASS

- 장점: 포트(`LocationReader`, `PlaceSearchProvider`)와 어댑터가 분리되어 있다. 컨트롤러는 세대 번호로 늦게 온 응답을 무시한다(시험 "a late answer after leaving place selection is ignored"). 오류는 "다시 던지지 않고 다시 만든다". zod 스키마는 쓰는 필드만 받는다.
- 서식: 새로 만든 Dart 파일 15개는 모두 `dart format --set-exit-if-changed` 통과. 고친 파일 중 기준선부터 서식 밖이던 6개(`home_screen`, `plan_card_screen`, `accessibility_test`, `architecture_test`, `intake_flow_test`, `formatters`, `intake_models`)는 HEAD에서도 그대로 서식 밖이다. 이 프로젝트 규칙(편집한 파일만, 전체 서식 금지)에 비추어 새 부채는 아니다.
- 감점: 대체 규칙이 늘 낱말 목록 덧붙이기로 고쳐지고 있다(M7 뒤 수정 커밋 3개). 의문형 어미 같은 큰 묶음이 빠져 있다(S1). 플랫폼 위치 어댑터의 권한 변환(`_fromCheck`/`_fromRequest`)은 시험 환경에서 실행되지 않는다(I1).

## 6. Consistency — 88, PASS

- 문서와 코드가 맞는 곳(확인함): `createContainer` 반환 `{…, places}`와 조립 규칙. 기동 로그의 `placeSearch`. 오류 처리기 순서(`PlaceSearchError` → 502가 `ZodError`보다 먼저). `/v1/places/search`는 places가 없으면 본문 검증 전에 503(코드와 같음). `/assistant/places` 경로 이름 `assistant-places`. `shell/place_search.dart` 다리. "기능 간 의존 없음". `geolocator ^14.1.2`. `formatPhone` 규칙(5·6·8 시작 7자리). 반올림 셋째 자리, 반경 2,000m, size 5, 시간 제한 5초. 위치 읽기 10초. 공유 표 24줄. EPIC 표 `implemented(0.2.1)`. 03 §8.1의 size 1~15. progress의 시험 수(438/+165/+33/+72/+2)가 재실행과 같다.
- 한국어 규칙: sync가 건드린 문서(structure, tech, codemaps 셋, 11_ARCHITECTURE, 03, README, EPIC overview, SPEC 문서 여섯)의 본문은 한국어이고 식별자·명령만 영어다. `server/.env.example` 주석은 영어지만 이 파일은 기존부터 영어 주석 관례를 따르는 코드 설정 파일이라 문제 삼지 않는다.
- 감점: S2, I5.

## 7. 발견 사항

### Must-fix

없음.

### Should-fix

- **S1** `server/src/domain/placeQuery.ts:12-15`(`REQUEST_WORDS`/`REQUEST_SUFFIXES`), `packages/kolbi_core/lib/src/places/place_intent.dart:37-49`: 의문형·가능 여부 어미(`있어?`, `있나`, `있어요`, `가능한지`, `가능해`, `되나`, `돼?`)와 끝 문장부호(`?`, `.`, `!`)가 검색어에 섞인다. 예: "홍대 근처 고기집 오늘 저녁 6명 자리 있어?" → `홍대 고기집 자리 있어?`. 휴리스틱 두뇌 서버에서는 이 규칙이 주 경로다. 고치는 방법: `words()` 전에 끝 문장부호를 지운다. 멈춤 어미에 `한지`, `있어`, `있나`, `가능`, `되나`, `돼`를 더한다. "자리"처럼 어미 바로 앞의 목적 명사는 멈춤 규칙상 남을 수 있으니 표에 기대값을 정해 둔다. 두 언어의 공유 표에 3.5의 나쁨 줄을 2~4개 더한다(두 파일을 함께 바꾸는 기존 절차대로).
- **S2** `README.md:26`: "말이 끝나거나 [말하기 끝]을 누르면 그 문장으로 통화 계획 카드를 엽니다"는 이제 반만 맞다(번호가 없으면 장소 선택이 열림). 고치는 방법: "…계획 카드를 엽니다(번호 없이 장소만 말하면 먼저 장소 선택을 엽니다, 「장소 찾기」)."

### 정보 (Info)

- **I1** `app/lib/features/places/location/platform_location_reader.dart` 커버리지 57.7%. 시험 환경에 플러그인이 없어 `_fromCheck`/`_fromRequest` 변환이 실행되지 않는다. 두 함수를 `@visibleForTesting` 정적 함수로 드러내 표 시험을 하나 두면 Android `denied` 해석(acceptance 잔여 위험)이 시험으로 고정된다.
- **I2** 앱이 반올림 전 좌표를 콜비 서버로 보낸다(`places_repository.dart`, 시험 `37.55`/`126.91` 그대로). 서버가 반올림하고 기록하지 않으므로 지금 계약에 어긋나지는 않는다. 다층 방어로 앱에서도 셋째 자리로 반올림해 보낼 수 있다.
- **I3** `server/src/config.ts` `KAKAO_LOCAL_BASE_URL: z.string()`. 잘못 설정하면(`http://…`) 키가 평문으로 나간다. `z.string().url().startsWith("https://")` 정도로 막을 수 있다.
- **I4** 400(`invalid_request`) 응답의 `Cache-Control: no-store`는 단언이 없다. 응답에 결과가 없어 영향은 없다.
- **I5** `acceptance.md`·`design.md` 제목이 `(0.2.0)`이다. 0.2.1은 문서 기록만 바꾼 개정이라 틀린 것은 아니지만, 선례처럼 제목 버전을 spec과 맞추면 읽기 쉽다.
- **I6** 남은 소유자 확인(progress §E.4 `owner_checks_pending`): 실제 카카오 키 1건, 첫 iOS 배포 빌드의 `strings` 0, Android 재요청, 실기기 위치 창, OD-3 법무, 실제 LLM의 `placeQuery` 품질. 감사는 이 항목들을 대신 확인할 수 없다.

## 8. 실행한 명령

```
git log --oneline -8; git diff --stat 74a87c3..HEAD
npm --prefix server test                         -> Tests 438 passed (438)
npm --prefix server run typecheck                -> exit 0
(cd packages/kolbi_core && dart test)            -> +33: All tests passed!
(cd packages/kolbi_core && dart analyze)         -> No issues found!
(cd packages/kolbi_ui && flutter --suppress-analytics test) -> +72: All tests passed!
(cd app && flutter --suppress-analytics test --coverage)    -> +165: All tests passed!
(cd app && flutter --suppress-analytics analyze) -> info 1건 (fakes.dart:54, 기준선)
dart test (루트)                                 -> +2: All tests passed!
python3: lcov 파일별 줄 커버리지 계산
python3: 서버·Dart 공유 표 추출 비교           -> 24 24 identical: True
npx tsx <scratchpad>/pq.ts                       -> 새 문장 15개 (서버 규칙)
dart run (kolbi_core 임시 폴더, 실행 뒤 삭제)    -> 같은 15개 (앱 규칙), 결과 동일
git diff 74a87c3..HEAD -- app/test/... server/src/http/app.test.ts server/src/brain ...
grep: 최근 통화한 곳 / KAKAO / permission_handler / geolocator / placeQuery 로그 호출 / 비밀 값 패턴
dart format --output=none --set-exit-if-changed (새 파일 15개, 고친 파일 기준선·HEAD 비교)
pub 캐시 geolocator_android-5.2.1 매니페스트의 uses-permission 검색 -> 없음
```
