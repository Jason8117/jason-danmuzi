# 콜비 — 구조와 모듈 경계

콜비(구 CallMate)의 저장소 구조를 정리한다. 콜비라는 이름은 이 `.moai/project/` 문서에서만 쓰며, `README.md`, `docs/`, 디렉터리·패키지·식별자는 여전히 CallMate / `callmate`를 쓴다. 이를 바꾸는 일은 아직 하지 않은 별도 작업이다.

「최상위 디렉터리」부터 「어디를 고쳐야 하는가」까지의 절은 코드로 확인된 현재 구현 상태를 설명하며, 「목표 방향」 절은 미구현이다.

## 최상위 디렉터리

```
.
├── pubspec.yaml          Dart pub 워크스페이스 루트(name: kolbi_workspace, workspace: app, packages/kolbi_core, packages/kolbi_ui)
├── pubspec.lock          워크스페이스 전체의 잠금 파일 하나(app/pubspec.lock은 없음)
├── test/                 workspace_test.dart — 워크스페이스 구성 검사(루트 `dart test`, pre-commit 게이트가 실행)
├── packages/
│   ├── kolbi_core/       순수 Dart(Flutter 의존 없음): 모델, 형식 함수, ApiClient, LiveChannel, CallsRepository, PlacesRepository·장소 모델·첫 검색어 규칙(SPEC-PLACE-001). 배럴 lib/kolbi_core.dart, 구현 lib/src/
│   └── kolbi_ui/         Flutter: 디자인 토큰, 테마, 공용 위젯, 입력 포매터. 배럴 lib/kolbi_ui.dart, 구현 lib/src/, 글꼴 자산 assets/fonts/(PretendardVariable.ttf, OFL.txt — SPEC-DESIGN-001)
├── app/                  Flutter 클라이언트 (iOS, Android, web 타깃 디렉터리 존재, resolution: workspace)
│   ├── lib/              앱 소스
│   ├── test/             위젯·단위 테스트(architecture_test.dart: 앱 의존 규칙)
│   ├── android/ ios/ web/  플랫폼별 프로젝트
│   └── pubspec.yaml
├── server/               Fastify + TypeScript 백엔드 (헤드리스: REST, WebSocket, 웹훅)
│   ├── src/              서버 소스
│   ├── .env.example      환경 변수 예시
│   └── package.json
├── docs/                 설계 문서 (구현된 내용은 ARCHITECTURE.md, IMPLEMENTATION_BASELINE.md)
├── .github/workflows/    label-sync.yml 하나뿐
└── README.md
```

`server/data/`는 런타임 데이터 저장 위치이며(실제 작업 데이터 포함) 문서화 대상이 아니다.

## 서버 (`server/src/`)

### 파일 배치

| 경로 | 역할 |
|---|---|
| `index.ts` | 진입점(기동 복구 후 리슨, SIGINT/SIGTERM에 `shutdown.ts` 핸들러 연결) |
| `shutdown.ts` | 종료 절차: 신규 작업 차단 → 진행 중 통화 끊기 → `app.close()` → 저장소 최종 flush → 종료 코드 0/1. 단계별 예산 3 s + 1 s + 5 s(합계 9 s) |
| `config.ts` | 환경 변수 검증(zod)과 제공자·LLM 선택 |
| `container.ts` | 구체 구현을 조립하는 유일한 위치 |
| `logger.ts` | 로거 |
| `architecture.test.ts` | 모듈 경계 테스트: HTTP 계층은 구체 제공자를 모름(장소 제공자 포함), 외부 데이터에 `any` 금지(장소 제공자 데이터 포함), `providers/`는 `brain/`을 import하지 않음, `places/`는 상태를 갖지 않고 `store`·`brain`·`services`를 가져오지 않음(SPEC-PLACE-001) |
| `domain/types.ts` | `CallTask`, `TaskStatus`, `Language`, `OutcomeResult`(`unverified` 포함), `OutcomeSource`(`llm` \| `heuristic`) 등 도메인 타입 |
| `domain/stateMachine.ts` | 상태 전이 규칙(`canTransition`, `assertTransition`) |
| `domain/phone.ts` | 번호 정규화·마스킹, 차단 번호 판별, `checkTargetNumber`(ok / invalid / blocked) |
| `domain/scenario.ts` | 시나리오 판별과 템플릿(`detectScenario`, `SCENARIO_TEMPLATES`). `brain/`에서 옮겨 왔다 |
| `domain/approvalComment.ts` | 승인 코멘트 정제(제어 문자·줄바꿈 제거)와 카드·주민번호 모양 숫자열 가리기(`sanitizeApprovalComment`, `SENSITIVE_PLACEHOLDER` = `[민감정보 삭제]`). SPEC-APPROVAL-001 |
| `domain/placeQuery.ts` | 접수 응답 `placeQuery`의 결정적 규칙 `placeQueryFor(text, targetName)`(시간 낱말·사람 조사·인용 어미·동행 표현·관형형 동사를 건너뜀, `근처`·`주변` 빼기)와 두뇌 값 정리 `cleanPlaceQuery`(번호 지움, 30자). 예시 표는 앱 `kolbi_core` 대체 규칙과 같다(SPEC-PLACE-001 0.2.0 `design.md` D6·D10) |
| `domain/intake.ts` | 한 줄 부탁의 번호 후보 찾기·가리기(`findPhoneNumberInText`, `maskPhoneNumbers`, `PHONE_PLACEHOLDER` = `[전화번호]`), 이름 정규화, 통화 기록에서 이름·번호 찾기(`answeredHistory`, `findKnownName`, `findHistoryNumber`). SPEC-INTAKE-001 |
| `brain/` | 통화 계획·판단 로직: `types.ts`(인터페이스), `openaiBrain.ts`, `heuristicBrain.ts`, `prompts.ts` |
| `providers/` | 통화 실행: `types.ts`(인터페이스·`ProviderRoutes`), `simulatedProvider.ts`, `realtimeBridge.ts`, `realtimeEvents.ts`(OpenAI Realtime 이벤트 스키마) |
| `providers/kat/` | KAT Cloud 연동: `katProvider.ts`(자기 라우트를 `routes()`로 선언), `webhook.ts`(서명 검증), `schemas.ts`(KAT API 응답·웹훅·미디어 프레임 zod 스키마) |
| `services/callService.ts` | 작업 생명주기 조정(계획, 승인, 번호 정책 검사, 발신, 취소, 상한 적용, 종료 중 차단), 의뢰 해석(`draftIntake`, 응답의 `placeQuery`는 두뇌 값을 정리하고 비면 `placeQueryFor`로 채움 — SPEC-PLACE-001 0.2.0), 계획 완료 뒤 자동 시작(`autoStart`, 막히면 `autoStartBlocked`), 승인 코멘트 정제와 "사용자 안내:" 기록 줄 |
| `store/taskStore.ts` | 작업 저장소(JSON 파일, 쓰기 실패 격리·제한된 재시도, 테스트용 `InMemoryTaskStore`) |
| `events/eventBus.ts` | `task.updated` / `task.deleted` 이벤트 전달 |
| `http/app.ts` | `/v1` 라우트, 인증, 오류 매핑, 제공자가 선언한 라우트 등록(`registerProviderRoutes`). `POST /v1/places/search`는 `Cache-Control: no-store`, `PlaceSearchError`는 `request.log.error`보다 먼저 잡아 종류·상태만 경고로 남기고 502 |
| `http/schemas.ts` | 요청 스키마(zod), `PlaceSearchBody`(`query` 공백 제거 뒤 1~100자, 선택 `near{lat,lng}`) |
| `places/types.ts` | 장소 검색 포트 `PlaceSearchProvider`(`name: "kakao" \| "simulated"`, `search(query, signal)`), `PlaceQuery`, `ProviderPlace`(번호 원문), `PlaceCandidate`(응답 후보), `PhoneCheck`, 원인을 담지 않는 `PlaceSearchError(kind, status?)` (SPEC-PLACE-001) |
| `places/placeSearch.ts` | `createPlaceSearch(provider, {timeoutMs = 5000})`: 질의 채우기(후보 5곳·반경 2,000m, `near` 좌표를 소수 셋째 자리로 반올림), `AbortController`와 시간 제한, 모든 번호를 `checkTargetNumber`로 판정, 모든 예외를 원인 없이 `PlaceSearchError`로 감쌈 |
| `places/kakaoLocalPlaceSearch.ts` | 카카오 로컬 키워드 검색 어댑터(`GET /v2/local/search/keyword.json`, `Authorization: KakaoAK …`, zod 응답 스키마, `fetch` 주입) |
| `places/simulatedPlaceSearch.ts` | 키 없이 쓰는 연습용 후보 5곳(결정적, 네트워크 없음) |

### 계층 구조

```
            HTTP / WebSocket 클라이언트          KAT Cloud
                       │                            │
                       ▼                            ▼
             http/app.ts, http/schemas.ts ◄── provider.routes() (KAT: /kat/status, /kat/media)
                       │
                       ▼
             services/callService.ts ───────► events/eventBus.ts ──► /v1/stream
              │          │          │
              ▼          ▼          ▼
          brain/     providers/   store/
              │          │
              └────┬─────┘
                   ▼
               domain/  (types, stateMachine, phone, scenario, approvalComment, intake, placeQuery)

             http/app.ts ──► places/ (PlaceSearch) ──► domain/phone.ts (checkTargetNumber)
                                 └─► 카카오 로컬 API (키가 있을 때) / 연습용 후보

   container.ts: config를 읽어 brain·provider·store·bus를 조립해 CallService에 주입하고, 장소 검색 제공자를 골라 places에 넘김
```

- `CallService`는 `CallBrain`, `CallProvider`, `TaskStore` 인터페이스에 의존하며, 이 밖에 `EventBus`와 `domain/stateMachine`도 직접 가져온다(`callService.ts`). 두뇌·제공자·저장소의 구체 클래스는 `container.ts`에서만 선택된다.
- 제공자 전용 라우트는 제공자가 직접 선언한다. `CallProvider.routes?()`가 `ProviderRoutes`(HTTP 웹훅과 WebSocket 라우트, 서명 검증용 `rawBody` 여부)를 돌려주면 `http/app.ts`의 `registerProviderRoutes`가 선언대로 등록한다. KAT 제공자는 `/kat/status`(원문 본문 보관)와 `/kat/media`를 선언하며, 시뮬레이션 제공자는 라우트를 선언하지 않으므로 시뮬레이션 모드에서는 등록되는 제공자 라우트가 없다. `http/app.ts`는 `KatCallProvider`나 `providers/kat`을 import하지 않으며, `architecture.test.ts`가 이를 검사한다.
- 번호 정규화·차단 정책은 HTTP 계층이 아니라 `CallService`(`checkTargetNumber`)가 강제하며, 발신 직전에 저장된 번호를 다시 검사한다.

### 제공자·두뇌 선택 로직 (`config.ts`, `container.ts`)

- `CALL_PROVIDER`: `auto`(기본) | `simulated` | `kat`
- `katReady`는 `KAT_API_KEY`, `KAT_GROUP_ID`, `KAT_FROM_NUMBER`, `KAT_WEBHOOK_SECRET`, `PUBLIC_BASE_URL`, `OPENAI_API_KEY`가 모두 설정되었을 때 참이다.
- `CALL_PROVIDER=kat`인데 `katReady`가 거짓이면 기동 시 오류가 난다.
- `simulated`이거나 `katReady`가 거짓이면 `SimulatedCallProvider`(`SIMULATION_SPEED` 적용), 그렇지 않으면 `KatCallProvider`(OpenAI Realtime 설정 포함)를 쓴다.
- 제공자가 `kat`인데 `API_TOKEN`이 없으면 기동 시 오류가 난다.
- 두뇌는 제공자와 독립적이다. `OPENAI_API_KEY`가 있으면 `OpenAiBrain`, 없으면 `HeuristicBrain`.
- 장소 검색(SPEC-PLACE-001 OD-2): `KAKAO_REST_API_KEY`가 있으면 `KakaoLocalPlaceSearch`, 키가 없고 조립된 통화 제공자(`config.provider`, `CALL_PROVIDER` 값이 아님)가 시뮬레이션이면 `SimulatedPlaceSearch`, 키가 없고 실제 통화(`kat`)면 장소 검색을 끄고 `POST /v1/places/search`가 503 `place_search_unavailable`로 답한다(연습용 번호에 실제로 거는 일을 막음). 기동 로그에는 `placeSearch: "kakao" | "simulated" | "off"`만 남고 키 값은 남지 않는다.
- 접수 검색어(SPEC-PLACE-001 0.2.0): `OpenAiBrain`은 LLM 응답의 `placeQuery`를 관대한 스키마로 읽고, 휴리스틱 두뇌·LLM 실패 대체·`draftIntake`가 없는 두뇌에서는 `CallService`가 결정적 규칙 `placeQueryFor`로 채운다. 어느 경로든 서비스 후처리(번호 지움, `근처` 빼기, 30자)를 지난다.

## Flutter 앱 (`app/lib/`)

### 기능 우선 계층

```
lib/
├── main.dart, app.dart              main.dart가 registerKolbiFontLicenses()로 Pretendard 라이선스를 등록(SPEC-SHELL-001)
├── shell/                           SPEC-SHELL-001. 기능 화면을 모으는 유일한 곳
│   ├── app_router.dart              유일한 GoRouter: StatefulShellRoute 4갈래 + 셸 밖 /assistant(자식 plan·settings·new·places)와 /calls/:id/live
│   ├── routes.dart                  경로 이름 RouteNames, 탭 AppTab(today·tasks·history·me)
│   ├── navigation.dart              이동 함수(openTask, openTab, openAssistant·closeAssistant, 비서 자식 경로 openAssistantPlan·Settings·Manual·Places, openSettings, openLiveCall·closeLiveCall)와 taskLocation·liveCallLocation
│   ├── tab_scaffold.dart            다섯 칸 탭 바(가운데 비서 버튼, 업무 배지, 다시 누름, 라벨 배율 상한 1.3), BranchStack, TabScrollScope
│   ├── kind_registration.dart       작업 종류 등록부·표시자 공급자, call 종류 표시자, TaskDetailRoute
│   ├── task_feed.dart               기능들이 함께 읽는 작업 목록·묶음·기록 날짜 공급자, 다시 불러오기
│   ├── request_intake.dart          비서가 쓰는 부탁 접수(requestIntake → /v1/intake, IntakeResult)·템플릿·최근 장소 공급자(SPEC-ASSIST-001, SPEC-PLACE-001에서 requestPlanDraft를 바꿈)
│   └── place_search.dart            placesRepositoryProvider·locationReaderProvider(장소 기능이 쓰는 셸 다리, SPEC-PLACE-001)
├── core/
│   ├── clock.dart                   주입 가능한 시계 clockProvider(오늘 인사·날짜, 묶음 기준 시각)
│   ├── config/app_settings.dart     서버 URL·토큰·요청자 설정, 신뢰 안내 확인 기록(shared_preferences + 빌드 정의)
│   ├── network/api_client.dart      REST 클라이언트 (다시 내보내기 → kolbi_core src/network/api_client.dart)
│   ├── network/live_channel.dart    WebSocket 채널 (다시 내보내기 → kolbi_core src/network/live_channel.dart)
│   ├── router/app_router.dart       다시 내보내기 → shell/app_router.dart의 routerProvider(테스트 호환)
│   ├── theme/app_theme.dart         밝은·어두운 테마(Midnight Indigo 색, Pretendard), 카드 분위기(CardTone)·상태 색(대비 기준 포함) (다시 내보내기 → kolbi_ui src/theme/app_theme.dart)
│   ├── theme/tokens.dart            디자인 토큰(간격·모서리·움직임·최소 탭 크기 48), 움직임 줄이기 처리, WCAG 대비 계산 (다시 내보내기 → kolbi_ui src/theme/tokens.dart)
│   ├── widgets/common.dart          공용 위젯(AppCard, SectionCard, MessageView 빈 상태, PulsingDot 등) (다시 내보내기 → kolbi_ui src/widgets/common.dart)
│   ├── widgets/trust_notice.dart    신뢰 안내 문구·첫 통화 전 시트(SPEC-SHELL-001에서 features/calls/presentation/에서 옮김)
│   ├── utils/formatters.dart        포매터 (다시 내보내기 → kolbi_core src/format/formatters.dart)
└── features/
    ├── assistant/                         SPEC-ASSIST-001. AI 비서(SCR-A01, 늘 몰입형 다크)
    │   ├── assistant_screen.dart            Orb·상태 칩·받아쓰기 문장·조작 줄, 글로 입력 모드, 접근성 상태 알림
    │   ├── assistant_controller.dart        비서 상태(대기·듣는 중·처리 중, 실패 규칙, 앱 실행 동안의 대체 인식 기억)
    │   ├── mic_consent_sheet.dart           마이크 목적 안내, OD-2 안내, Android 음성 인식 서비스 안내, 설정 열기 안내
    │   ├── request_box.dart                 글로 입력 모드의 부탁 입력 상자(옛 오늘 _IntakeBox)
    │   └── speech/
    │       ├── speech_recognizer.dart       받아쓰기 포트(SpeechRecognizer, SpeechEvent, speechRecognizerProvider)
    │       └── platform_speech_recognizer.dart  speech_to_text·permission_handler 어댑터(두 패키지를 가져오는 유일한 파일)
    ├── places/                            SPEC-PLACE-001. 장소 선택(SCR-H02)·장소 상세(SCR-H03)
    │   ├── place_search_screen.dart         검색칸·출처 줄·후보 목록·[번호 직접 입력], 로딩·없음·실패·꺼짐·걸 곳 없음, 동네 이름 칸
    │   ├── place_search_controller.dart     화면이 소유하는 ValueNotifier 상태(대기·위치 필요·동네 묻기·로딩·결과·실패), 늦은 응답 무시
    │   ├── place_card.dart                  후보 카드(CMP-05): 이름·분류·거리·주소·번호 상태, 걸 수 없는 이유, 첫 걸 수 있는 후보 강조
    │   ├── place_detail_sheet.dart          장소 상세 시트(CMP-06): [번호 복사], [여기에 물어보기](걸 수 있을 때만)
    │   ├── location_consent_sheet.dart      위치 목적 사전 안내(CMP-23)
    │   └── location/
    │       ├── location_reader.dart         위치 포트(LocationReader, LocationAccess)
    │       └── platform_location_reader.dart  geolocator 어댑터(대략 위치 한 번, 10초 제한, geolocator를 가져오는 유일한 파일)
    ├── calls/
    │   ├── domain/                          call_models·intake_models·counterparties·follow_up·approval_comment 모두 다시 내보내기(→ kolbi_core src/; approval_comment는 kolbi_ui의 CodePointLengthLimitingFormatter도 함께)
    │   ├── data/calls_repository.dart       Riverpod 공급자 3개(apiClientProvider 등) + kolbi_core CallsRepository·이벤트 다시 내보내기
    │   ├── application/calls_controller.dart  Riverpod 상태 관리, 버전 병합
    │   └── presentation/                    화면(home = 오늘 탭(SPEC-ASSIST-001부터 부탁 입력 상자 없음), plan_card, new_call, call_detail = 맨 위 단계 타임라인·[통화 보기], live_call = 통화 중 몰입형 화면), trust_notice(다시 내보내기 → core/widgets/trust_notice.dart), approval_listener, call_templates, widgets/(approval_card·follow_up_actions·call_task_tile(작업 행, 옛 홈 _TaskTile)·call_timer(통화 시간, 상세와 통화 중 화면이 함께 씀)은 앱에 남음; status_chip·outcome_card·transcript_view는 다시 내보내기 → kolbi_ui src/widgets/)
    ├── inbox/inbox_screen.dart              업무 탭(SCR-T01): 개수 세 칸, 승인 요청·진행 중·반복 묶음, 기록 링크, 빈 상태·오류
    ├── history/history_screen.dart          기록 탭(SCR-R01): 서울 날짜 묶음, 결과 칩·결과 한 줄
    ├── me/me_screen.dart                    내 정보 탭(SCR-M01): 프로필 카드, 비서·권한과 안전·앱 항목, 설정 연결
    └── settings/settings_screen.dart
```

의존 방향은 주로 `presentation → application → data → domain`이며, `core/`는 모든 기능이 공유한다. `shell/`은 기능 화면을 모아 라우터에 등록하고, 업무·기록·내 정보 기능은 `features/calls`를 직접 가져오지 않고 `shell/`의 공급자(`task_feed.dart`, `kind_registration.dart`)와 이동 함수(`navigation.dart`, `routes.dart`)를 쓴다(SPEC-SHELL-001). 다만 엄격하게 지켜지지는 않아 `presentation`이 `data`를 직접 가져오는 곳도 있다(예: `home_screen.dart`의 `calls_repository.dart` import).

SPEC-MODULE-001 이후 앱 소스는 옛 경로 대신 배럴 `package:kolbi_core/kolbi_core.dart`·`package:kolbi_ui/kolbi_ui.dart`를 가져온다. 옛 경로는 테스트 import를 고치지 않기 위해 다시 내보내기 파일로 남아 있다(이후 SPEC에서 지움). SPEC-MODULE-001의 14개에 SPEC-SHELL-001이 `core/router/app_router.dart`와 `features/calls/presentation/trust_notice.dart`를 더해 16개다. 패키지 의존 방향은 `kolbi_core ◄── kolbi_ui ◄── app`이며, 다음 테스트가 import 줄을 글자로 읽어 검사한다.

| 테스트 | 검사 |
|---|---|
| `packages/kolbi_core/test/dependency_rules_test.dart` | `lib/`가 `package:flutter/`, `dart:ui`, `package:flutter_riverpod/`, `package:riverpod/`, `package:shared_preferences/`, `package:kolbi_ui/`, `package:callmate/`를 가져오지 않음 |
| `packages/kolbi_ui/test/dependency_rules_test.dart` | `lib/`가 `package:callmate/`, `package:go_router/`, `package:flutter_riverpod/`, `package:shared_preferences/`, `package:share_plus/`, `package:kolbi_core/src/`를 가져오지 않음 |
| `app/test/architecture_test.dart` | 앱이 패키지 `src/`를 직접 가져오지 않음, 기능 간 import 허용 목록이 비어 있음(SPEC-SHELL-001), 옛 경로는 다시 내보내기만 함, 테스트의 `package:callmate` import가 모두 실제 파일을 가리킴, `core/`는 기능·셸을 가져오지 않음(고정된 다시 내보내기 파일 `core/router/app_router.dart` 제외), `GoRouter(`는 `lib/shell/app_router.dart`에만 있고 `lib/features/`에는 `.go(`·`goNamed(`·`goBranch(`와 경로 글자(`'/calls` 등)가 없음, `speech_to_text`·`permission_handler`는 `features/assistant/speech/platform_speech_recognizer.dart`에서만 가져옴, `Info.plist`·`AndroidManifest.xml`에 마이크·음성 인식 권한 선언이 있음(SPEC-ASSIST-001), `geolocator`는 `features/places/location/platform_location_reader.dart`에서만 가져옴, 위치 권한은 대략 위치만(`NSLocationWhenInUseUsageDescription`, `ACCESS_COARSE_LOCATION`; "항상" 키·정밀 위치 없음)(SPEC-PLACE-001) |

### 라우트 (`shell/app_router.dart`, SPEC-SHELL-001)

`StatefulShellRoute` 4갈래(탭)와 셸 밖 최상위 경로 `/assistant`(SPEC-ASSIST-001부터 자식 경로 셋, SPEC-PLACE-001에서 넷)·`/calls/:id/live`로 이루어진다. 옛 경로 다섯 개는 그대로 두고 갈래에 나누어 넣었다.

| 경로 | 이름(`RouteNames`) | 갈래(탭) | 화면 |
|---|---|---|---|
| `/` | `today` | 오늘 | `HomeScreen`(오늘 대시보드) |
| `/calls/new` | `new-call` | 오늘 | 새 통화(직접 입력 양식) |
| `/plan` | `plan` | 오늘 | `PlanCardScreen`(계획 카드, `extra`로 `PlanDraft`를 받으며 없으면 `/`로 돌아감) |
| `/inbox` | `inbox` | 업무 | `InboxScreen` |
| `/calls/:id` | `task` | 업무 | `TaskDetailRoute` → 작업 종류의 상세(call이면 통화 상세 + 단계 타임라인) |
| `/history` | `history` | 기록 | `HistoryScreen` |
| `/me` | `me` | 내 정보 | `MeScreen` |
| `/settings` | `settings` | 내 정보 | `SettingsScreen` |
| `/assistant` | `assistant` | 셸 밖(탭 바 없음) | `AssistantScreen`(SCR-A01; `?mode=text`면 글로 입력 모드, `extra` 문자열은 입력칸에 채움) |
| `/assistant/plan` | `assistant-plan` | 셸 밖 | `PlanCardScreen`(비서 위, `extra`가 `PlanDraft`가 아니면 `/assistant`로) |
| `/assistant/settings` | `assistant-settings` | 셸 밖 | `SettingsScreen`(비서 위) |
| `/assistant/new` | `assistant-new` | 셸 밖 | 직접 입력 양식(비서 위) |
| `/assistant/places` | `assistant-places` | 셸 밖 | `PlaceSearchScreen`(SCR-H02, 비서 위; `extra`가 `PlaceSearchStart`가 아니면 `/assistant`로). 고른 곳의 계획 카드는 그 위 `/assistant/plan`에 쌓이므로 뒤로 가면 목록 그대로다(SPEC-PLACE-001) |
| `/calls/:id/live` | `live-call` | 셸 밖 | `LiveCallScreen`(SCR-T08, 몰입형 다크; 자막·끊기·승인 카드, 통화가 끝나면 닫힘) |

탭 사이 이동은 `shell/navigation.dart`의 함수로만 한다. 작업 열기(`openTask`)는 쌓인 화면을 모두 닫고 업무 탭을 고른 뒤 상세를 올리므로 뒤로 가면 업무 첫 화면이다. go_router 18에서 셸 밖 경로 위에 탭 경로를 올리면 assert가 나므로(SPEC-SHELL-001 research R1-G), 비서가 여는 화면(계획 카드·설정·직접 입력·장소 선택)은 모두 `/assistant`의 자식 경로다(SPEC-ASSIST-001 REQ-009, R1-G3; 장소 선택은 SPEC-PLACE-001 REQ-009). 비서는 접수 결과의 `missing`에 `phoneNumber`가 있고 차단 번호가 아니면 계획 카드 대신 장소 선택을 연다(`placeSearchStartFor`). SHELL의 `submitFromAssistant`(비서를 닫은 뒤 `/plan`)는 지웠다. 계획 카드의 프로필 링크는 `openSettings`가 지금 경로를 보고 `/assistant/settings`와 `/settings` 가운데 고른다. 비서를 첫 화면으로 열었을 때(웹 주소 직접 입력) 닫기는 `pop` 대신 오늘로 간다(`closeAssistant`, SHELL sync-audit F1). 통화 중 화면은 업무 상세 위에 `push`하고, 통화가 끝나면 `pop`으로 상세에 돌아간다(`closeLiveCall`).

## 클라이언트–서버 계약

### REST (`/v1/*`는 `Authorization: Bearer <API_TOKEN>` 필요, `API_TOKEN` 설정 시. 브라우저는 WebSocket 핸드셰이크에 헤더를 설정할 수 없으므로 `/v1/stream`은 `?token=` 쿼리도 받는다)

| 메서드 | 경로 | 용도 |
|---|---|---|
| GET | `/health` | 상태 확인 |
| GET | `/v1/config` | 서버 설정 조회 |
| GET | `/v1/tasks` | 작업 목록 |
| POST | `/v1/tasks` | 작업 생성(201) |
| POST | `/v1/intake` | 한 줄 부탁 → 계획 카드 초안(작업을 만들지 않음, SPEC-INTAKE-001). 응답 키 `draft`·`missing`·`numberIssue`·`phoneSource`·`placeQuery`·`source` — `placeQuery`(장소 이름·분류만, 없으면 `null`)는 SPEC-PLACE-001 0.2.0에서 더함. 옛 서버처럼 키가 없어도 앱은 대체 규칙으로 동작 |
| POST | `/v1/places/search` | 장소 후보 검색 `{query, near?}` → `{source, places}`(최대 5곳, `Cache-Control: no-store`). 결과는 응답으로만 넘기고 저장·캐시·로그하지 않음(SPEC-PLACE-001, 에픽 D-8) |
| GET | `/v1/tasks/:id` | 작업 조회 |
| POST | `/v1/tasks/:id/approve-plan` | 계획 승인 |
| POST | `/v1/tasks/:id/cancel` | 취소 |
| POST | `/v1/tasks/:id/approvals/:approvalId` | 통화 중 승인 응답 |
| DELETE | `/v1/tasks/:id` | 삭제(204) |
| POST | `/kat/status` | KAT 상태 웹훅(KAT 모드 전용) |
| WS | `/kat/media` | KAT 미디어 스트림(KAT 모드 전용) |

오류 응답은 대체로 `{ error, message }` 형식이며 `invalid_request`(400), `blocked_number`(400, 긴급·특수번호), `unauthorized`(401), `invalid_state`(409), `internal`(500), `shutting_down`(503, 종료 진행 중), `place_search_failed`(502, 장소 제공자 실패·시간 초과, 원인 없음), `place_search_unavailable`(503, 키 없는 실제 통화 서버) 등을 쓴다. 동시 통화·일일 상한 초과 시에는 429(`too_many_active_calls`, `daily_limit`, `callService.ts`)를 반환한다. 예외로 `/kat/status` 서명 검증 실패는 `message` 없이 `{ error: "invalid_signature" }`(401)만 돌려준다.

### WebSocket (`/v1/stream`)

메시지는 세 종류다. 연결 직후 서버가 `{ type: "snapshot", tasks }`를 한 번 보내고(`http/app.ts`, 앱은 `calls_repository.dart`에서 파싱), 이후 `{ type: "task.updated", task }`와 `{ type: "task.deleted", taskId }` 이벤트가 이어진다(`events/eventBus.ts`).

### 버전 규칙

`CallTask.version`은 변경될 때마다 증가한다. HTTP 응답이 더 새로운 스트림 이벤트보다 늦게 도착할 수 있으므로, 앱(`calls_controller.dart`)은 항상 버전이 더 높은 스냅샷을 유지한다.

## 어디를 고쳐야 하는가

| 변경 내용 | 위치 |
|---|---|
| 상태 추가·전이 규칙 | `server/src/domain/types.ts`, `domain/stateMachine.ts` (+ `packages/kolbi_core/lib/src/models/call_models.dart`, `packages/kolbi_ui/lib/src/widgets/status_chip.dart`) |
| 차단 번호·번호 형식 | `server/src/domain/phone.ts` (강제 위치는 `services/callService.ts`) |
| 통화 계획·프롬프트 | `server/src/brain/` (시나리오 템플릿은 `domain/scenario.ts`) |
| 새 통신사·발신 제공자 | `server/src/providers/`에 `CallProvider` 구현 추가(웹훅이 필요하면 `routes()`로 선언) 후 `container.ts`, `config.ts`에 선택 조건 추가. `http/app.ts`는 고치지 않는다 |
| 외부 응답 검증 | `server/src/providers/kat/schemas.ts`, `providers/realtimeEvents.ts` |
| 종료 절차·예산 | `server/src/shutdown.ts`, `index.ts` |
| 상한·제한 시간 | `server/src/config.ts` 기본값, `CallService` 옵션 |
| API 라우트·요청 검증 | `server/src/http/app.ts`, `http/schemas.ts` (+ `packages/kolbi_core/lib/src/network/api_client.dart`, `packages/kolbi_core/lib/src/data/calls_repository.dart`) |
| 저장 방식 | `server/src/store/taskStore.ts` |
| 장소 검색(제공자·후보 수·반경·시간 제한) | `server/src/places/`(포트 `types.ts`, `placeSearch.ts`, 카카오 어댑터, 연습용 후보), 조립 `container.ts`, 키 `config.ts`(`KAKAO_REST_API_KEY`, `KAKAO_LOCAL_BASE_URL`). 결과를 저장·캐시·로그하지 않는다는 증명 시험은 `server/src/http/places.test.ts` |
| 첫 검색어 규칙 | 서버 `server/src/domain/placeQuery.ts`와 앱 대체 규칙 `packages/kolbi_core/lib/src/places/place_intent.dart`를 함께 고친다. 두 시험(`server/src/domain/placeQuery.test.ts`, `packages/kolbi_core/test/places_test.dart`)이 같은 예시 표(SPEC-PLACE-001 `design.md` D6, 24줄)를 고정한다 |
| 장소 선택·상세·위치 | `app/lib/features/places/`(위치 패키지는 `location/platform_location_reader.dart`만), 위치 권한 문구는 `app/ios/Runner/Info.plist`(`NSLocationWhenInUseUsageDescription`)와 `AndroidManifest.xml`(`ACCESS_COARSE_LOCATION`) |
| 번호 표시 | `packages/kolbi_core/lib/src/format/formatters.dart`의 `formatPhone`. SPEC-PLACE-001부터 서버가 `+15880000`처럼 판정한 15xx·16xx·18xx 대표번호를 `1588-0000`으로 보인다(계획 카드, 업무 상세·결과·통화 중 화면, 오늘·기록 목록, 최근 장소 칩, 공유 문구 등 `formatPhone`을 쓰는 모든 곳) |
| 화면·UI | `app/lib/features/calls/presentation/`(오늘·계획·상세·통화 중), `app/lib/features/{assistant,inbox,history,me}/` (공용 토큰·테마·위젯은 `packages/kolbi_ui/lib/src/`) |
| 탭·경로·탭 사이 이동 | `app/lib/shell/`(`app_router.dart`, `routes.dart`, `navigation.dart`, `tab_scaffold.dart`) |
| 새 작업 종류 | `packages/kolbi_core/lib/src/kinds/`(서술자)와 `packages/kolbi_ui/lib/src/kinds/task_kind_presenter.dart`(표시자)를 구현해 `app/lib/shell/kind_registration.dart`에 등록 |
| 업무 묶음·배지·기록 날짜·단계 계산 | `packages/kolbi_core/lib/src/tasks/task_groups.dart`, `task_steps.dart` |
| 서버 주소·토큰 설정 | `app/lib/core/config/app_settings.dart` |
| 받아쓰기(음성 인식 패키지·권한) | `app/lib/features/assistant/speech/`(포트 `speech_recognizer.dart`, 어댑터 `platform_speech_recognizer.dart`), 권한 문구는 `app/ios/Runner/Info.plist`(`NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`)와 `app/android/app/src/main/AndroidManifest.xml`(`RECORD_AUDIO`, `RecognitionService` 조회) |
| Orb·몰입형 다크 | `packages/kolbi_ui/lib/src/widgets/orb.dart`(`KolbiOrb`), `src/theme/immersive_theme.dart`(`KolbiTheme.immersive()`) |

## 목표 방향 (미구현, 소유자 진술 기준)

허브 연동, SDK·애드온, A2A·MCP·OAuth·JWT·Ory Hydra는 구현되지 않았다(`server/src`, `app/lib`, `server/package.json`, `app/pubspec.yaml` grep 결과 해당 용어 없음). 아래는 기존 코드와 제안 문서에서 확인되는 접점일 뿐이며, 각 프로토콜이 어느 모듈에 대응하는지는 정해지지 않았다.

| 접점 | 근거 |
|---|---|
| 새 연결 경로 | `server/src/providers/types.ts`의 `CallProvider` 인터페이스(현재 `name`은 `"simulated" \| "kat"`)와 `container.ts`의 제공자 선택. 새 경로를 제공자로 추가할 수 있는 구조지만, 허브 채널을 제공자로 둘지는 미정이다 |
| 외부 공개 API | `server/src/http/app.ts`에 라우트가 모여 있다. `docs/04`는 기존 Fastify 서버 안에 `/platform/v1` 라우트·서비스를 추가하는 모듈러 모놀리스를 제안하며, 기존 `/v1/tasks`는 유지하고 공유 `CallService`를 권한 검사 계층 아래에서 호출하는 방식이다(구현되지 않은 제안) |

---

Generated by /moai project on 2026-11-20; based on repository state at commit c95953f. Updated by /moai sync on 2026-11-21 for SPEC-STORE/LIFECYCLE/POLICY/OUTCOME/ARCH-001 (state at facb660). Updated by /moai sync on 2026-11-27 for SPEC-UX-001 (state at c2e732d). Updated by /moai sync on 2026-11-27 for SPEC-MODULE-001 (state at 6cdf8af). Updated by /moai sync on 2026-11-27 for SPEC-APPROVAL/INTAKE/FOLLOWUP-001 (state at 8ad8239). Updated by /moai sync on 2026-11-27 for SPEC-DESIGN-001 (state at 5ee6eef). Updated by /moai sync on 2026-11-27 for SPEC-SHELL-001 (state at b67d452). Updated by /moai sync on 2026-11-28 for SPEC-ASSIST-001 (state at 477dac5). Updated by /moai sync on 2026-11-28 for SPEC-PLACE-001 (state at 2d84a91).
