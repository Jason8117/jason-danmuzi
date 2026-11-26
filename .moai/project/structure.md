# 콜비 — 구조와 모듈 경계

콜비(구 CallMate)의 저장소 구조를 정리한다. 콜비라는 이름은 이 `.moai/project/` 문서에서만 쓰며, `README.md`, `docs/`, 디렉터리·패키지·식별자는 여전히 CallMate / `callmate`를 쓴다. 이를 바꾸는 일은 아직 하지 않은 별도 작업이다.

「최상위 디렉터리」부터 「어디를 고쳐야 하는가」까지의 절은 코드로 확인된 현재 구현 상태를 설명하며, 「목표 방향」 절은 미구현이다.

## 최상위 디렉터리

```
.
├── app/                  Flutter 클라이언트 (iOS, Android, web 타깃 디렉터리 존재)
│   ├── lib/              앱 소스
│   ├── test/             위젯·단위 테스트
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
| `architecture.test.ts` | 모듈 경계 테스트: HTTP 계층은 구체 제공자를 모름, 외부 데이터에 `any` 금지, `providers/`는 `brain/`을 import하지 않음 |
| `domain/types.ts` | `CallTask`, `TaskStatus`, `Language`, `OutcomeResult`(`unverified` 포함), `OutcomeSource`(`llm` \| `heuristic`) 등 도메인 타입 |
| `domain/stateMachine.ts` | 상태 전이 규칙(`canTransition`, `assertTransition`) |
| `domain/phone.ts` | 번호 정규화·마스킹, 차단 번호 판별, `checkTargetNumber`(ok / invalid / blocked) |
| `domain/scenario.ts` | 시나리오 판별과 템플릿(`detectScenario`, `SCENARIO_TEMPLATES`). `brain/`에서 옮겨 왔다 |
| `brain/` | 통화 계획·판단 로직: `types.ts`(인터페이스), `openaiBrain.ts`, `heuristicBrain.ts`, `prompts.ts` |
| `providers/` | 통화 실행: `types.ts`(인터페이스·`ProviderRoutes`), `simulatedProvider.ts`, `realtimeBridge.ts`, `realtimeEvents.ts`(OpenAI Realtime 이벤트 스키마) |
| `providers/kat/` | KAT Cloud 연동: `katProvider.ts`(자기 라우트를 `routes()`로 선언), `webhook.ts`(서명 검증), `schemas.ts`(KAT API 응답·웹훅·미디어 프레임 zod 스키마) |
| `services/callService.ts` | 작업 생명주기 조정(계획, 승인, 번호 정책 검사, 발신, 취소, 상한 적용, 종료 중 차단) |
| `store/taskStore.ts` | 작업 저장소(JSON 파일, 쓰기 실패 격리·제한된 재시도, 테스트용 `InMemoryTaskStore`) |
| `events/eventBus.ts` | `task.updated` / `task.deleted` 이벤트 전달 |
| `http/app.ts` | `/v1` 라우트, 인증, 오류 매핑, 제공자가 선언한 라우트 등록(`registerProviderRoutes`) |
| `http/schemas.ts` | 요청 스키마(zod) |

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
               domain/  (types, stateMachine, phone, scenario)

   container.ts: config를 읽어 brain·provider·store·bus를 조립해 CallService에 주입
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

## Flutter 앱 (`app/lib/`)

### 기능 우선 계층

```
lib/
├── main.dart, app.dart
├── core/
│   ├── config/app_settings.dart     서버 URL·토큰 설정(shared_preferences + 빌드 정의)
│   ├── network/api_client.dart      REST 클라이언트
│   ├── network/live_channel.dart    WebSocket 채널
│   ├── router/app_router.dart       go_router 라우트
│   ├── theme/app_theme.dart         밝은·어두운 테마, 카드 분위기(CardTone)·상태 색(대비 기준 포함)
│   ├── theme/tokens.dart            디자인 토큰(간격·모서리·움직임·최소 탭 크기 48), 움직임 줄이기 처리, WCAG 대비 계산
│   ├── widgets/common.dart          공용 위젯(AppCard, SectionCard, MessageView 빈 상태, PulsingDot 등)
│   ├── utils/                       포매터
└── features/
    ├── calls/
    │   ├── domain/call_models.dart          모델
    │   ├── data/calls_repository.dart       서버 접근
    │   ├── application/calls_controller.dart  Riverpod 상태 관리, 버전 병합
    │   └── presentation/                    화면(home, new_call, call_detail), approval_listener, call_templates, widgets/
    └── settings/settings_screen.dart
```

의존 방향은 주로 `presentation → application → data → domain`이며, `core/`는 모든 기능이 공유한다. 다만 엄격하게 지켜지지는 않아 `presentation`이 `data`를 직접 가져오는 곳도 있다(예: `home_screen.dart`의 `calls_repository.dart` import).

### 라우트 (`core/router/app_router.dart`)

| 경로 | 화면 |
|---|---|
| `/` | `HomeScreen` |
| `/calls/new` | 새 통화 |
| `/calls/:id` | 통화 상세 |
| `/settings` | `SettingsScreen` |

## 클라이언트–서버 계약

### REST (`/v1/*`는 `Authorization: Bearer <API_TOKEN>` 필요, `API_TOKEN` 설정 시. 브라우저는 WebSocket 핸드셰이크에 헤더를 설정할 수 없으므로 `/v1/stream`은 `?token=` 쿼리도 받는다)

| 메서드 | 경로 | 용도 |
|---|---|---|
| GET | `/health` | 상태 확인 |
| GET | `/v1/config` | 서버 설정 조회 |
| GET | `/v1/tasks` | 작업 목록 |
| POST | `/v1/tasks` | 작업 생성(201) |
| GET | `/v1/tasks/:id` | 작업 조회 |
| POST | `/v1/tasks/:id/approve-plan` | 계획 승인 |
| POST | `/v1/tasks/:id/cancel` | 취소 |
| POST | `/v1/tasks/:id/approvals/:approvalId` | 통화 중 승인 응답 |
| DELETE | `/v1/tasks/:id` | 삭제(204) |
| POST | `/kat/status` | KAT 상태 웹훅(KAT 모드 전용) |
| WS | `/kat/media` | KAT 미디어 스트림(KAT 모드 전용) |

오류 응답은 대체로 `{ error, message }` 형식이며 `invalid_request`(400), `blocked_number`(400, 긴급·특수번호), `unauthorized`(401), `invalid_state`(409), `internal`(500), `shutting_down`(503, 종료 진행 중) 등을 쓴다. 동시 통화·일일 상한 초과 시에는 429(`too_many_active_calls`, `daily_limit`, `callService.ts`)를 반환한다. 예외로 `/kat/status` 서명 검증 실패는 `message` 없이 `{ error: "invalid_signature" }`(401)만 돌려준다.

### WebSocket (`/v1/stream`)

메시지는 세 종류다. 연결 직후 서버가 `{ type: "snapshot", tasks }`를 한 번 보내고(`http/app.ts`, 앱은 `calls_repository.dart`에서 파싱), 이후 `{ type: "task.updated", task }`와 `{ type: "task.deleted", taskId }` 이벤트가 이어진다(`events/eventBus.ts`).

### 버전 규칙

`CallTask.version`은 변경될 때마다 증가한다. HTTP 응답이 더 새로운 스트림 이벤트보다 늦게 도착할 수 있으므로, 앱(`calls_controller.dart`)은 항상 버전이 더 높은 스냅샷을 유지한다.

## 어디를 고쳐야 하는가

| 변경 내용 | 위치 |
|---|---|
| 상태 추가·전이 규칙 | `server/src/domain/types.ts`, `domain/stateMachine.ts` (+ 앱 `call_models.dart`, `status_chip.dart`) |
| 차단 번호·번호 형식 | `server/src/domain/phone.ts` (강제 위치는 `services/callService.ts`) |
| 통화 계획·프롬프트 | `server/src/brain/` (시나리오 템플릿은 `domain/scenario.ts`) |
| 새 통신사·발신 제공자 | `server/src/providers/`에 `CallProvider` 구현 추가(웹훅이 필요하면 `routes()`로 선언) 후 `container.ts`, `config.ts`에 선택 조건 추가. `http/app.ts`는 고치지 않는다 |
| 외부 응답 검증 | `server/src/providers/kat/schemas.ts`, `providers/realtimeEvents.ts` |
| 종료 절차·예산 | `server/src/shutdown.ts`, `index.ts` |
| 상한·제한 시간 | `server/src/config.ts` 기본값, `CallService` 옵션 |
| API 라우트·요청 검증 | `server/src/http/app.ts`, `http/schemas.ts` (+ 앱 `api_client.dart`, `calls_repository.dart`) |
| 저장 방식 | `server/src/store/taskStore.ts` |
| 화면·UI | `app/lib/features/calls/presentation/` |
| 서버 주소·토큰 설정 | `app/lib/core/config/app_settings.dart` |

## 목표 방향 (미구현, 소유자 진술 기준)

허브 연동, SDK·애드온, A2A·MCP·OAuth·JWT·Ory Hydra는 구현되지 않았다(`server/src`, `app/lib`, `server/package.json`, `app/pubspec.yaml` grep 결과 해당 용어 없음). 아래는 기존 코드와 제안 문서에서 확인되는 접점일 뿐이며, 각 프로토콜이 어느 모듈에 대응하는지는 정해지지 않았다.

| 접점 | 근거 |
|---|---|
| 새 연결 경로 | `server/src/providers/types.ts`의 `CallProvider` 인터페이스(현재 `name`은 `"simulated" \| "kat"`)와 `container.ts`의 제공자 선택. 새 경로를 제공자로 추가할 수 있는 구조지만, 허브 채널을 제공자로 둘지는 미정이다 |
| 외부 공개 API | `server/src/http/app.ts`에 라우트가 모여 있다. `docs/04`는 기존 Fastify 서버 안에 `/platform/v1` 라우트·서비스를 추가하는 모듈러 모놀리스를 제안하며, 기존 `/v1/tasks`는 유지하고 공유 `CallService`를 권한 검사 계층 아래에서 호출하는 방식이다(구현되지 않은 제안) |

---

Generated by /moai project on 2026-11-20; based on repository state at commit c95953f. Updated by /moai sync on 2026-11-21 for SPEC-STORE/LIFECYCLE/POLICY/OUTCOME/ARCH-001 (state at facb660). Updated by /moai sync on 2026-11-27 for SPEC-UX-001 (state at c2e732d).
