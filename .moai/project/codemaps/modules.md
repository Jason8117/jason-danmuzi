# 콜비 — 모듈별 책임과 공개 인터페이스

파일 배치 표는 `structure.md`에 있다. 여기서는 각 모듈이 밖으로 내놓는 것과 누가 그것을 가져다 쓰는지를 import 문으로 확인해 적는다. 「사용처」에는 테스트 파일을 넣지 않았다.

## 서버 (`server/src/`)

### `domain/`

| 파일 | 공개 인터페이스 | 사용처 |
|---|---|---|
| `types.ts` | `Language`, `TaskStatus`, `Speaker`, `TranscriptEntry`, `CallPlan`, `ApprovalStatus`, `ApprovalDecisionReason`, `ApprovalDecision`, `ApprovalRequest`, `OutcomeResult`, `CallOutcome`, `CallTaskInput`, `CallTask`, `ACTIVE_CALL_STATUSES`, `TERMINAL_STATUSES`, `isActiveCall`, `isTerminal` | `services`, `brain`, `providers`, `store`, `events` |
| `stateMachine.ts` | `canTransition`, `assertTransition`, `InvalidTransitionError` | `services/callService.ts`(`assertTransition`), `http/app.ts`(`InvalidTransitionError`로 409 매핑) |
| `phone.ts` | `normalizePhoneNumber`, `isBlockedNumber`, `checkTargetNumber`, `maskPhoneNumber` | `services/callService.ts`(정규화·차단 강제), `providers/kat/katProvider.ts`(로그 마스킹) |
| `scenario.ts` | `Scenario`, `detectScenario`, `SCENARIO_TEMPLATES` (SPEC-ARCH-001에서 `brain/`에서 이동) | `brain/heuristicBrain.ts`, `providers/simulatedProvider.ts` |

다른 모듈에 의존하지 않는 최하위 계층이다.

### `brain/`

책임: 통화 전 계획 작성과 통화 후 요약. 실시간 대화는 맡지 않는다(`types.ts` 주석).

| 파일 | 공개 인터페이스 | 사용처 |
|---|---|---|
| `types.ts` | `interface CallBrain { name; createPlan(input); summarize(task) }` | `services/callService.ts`, `container.ts` |
| `openaiBrain.ts` | `class OpenAiBrain` (Chat Completions, `response_format: json_object`). LLM 호출이 실패하면 내부의 `HeuristicBrain`으로 대체한다(`completeJson`의 `fallback`) | `container.ts` |
| `heuristicBrain.ts` | `class HeuristicBrain`, `isFiller` | `container.ts`, `openaiBrain.ts` |
| `prompts.ts` | `openingLine`, `buildAgentInstructions`, `PLAN_SYSTEM_PROMPT`, `SUMMARY_SYSTEM_PROMPT` | `heuristicBrain.ts`, `openaiBrain.ts`, `providers/realtimeBridge.ts` |

### `providers/`

책임: 발신과 오디오. 상태·저장은 `CallSession`을 통해 `CallService`에 맡긴다.

| 파일 | 공개 인터페이스 | 사용처 |
|---|---|---|
| `types.ts` | `EndOptions`, `CallSession`(`taskId`, `task()`, `signal`, `markRinging`, `markConnected`, `appendTranscript`, `requestApproval`, `end`), `CallProvider`(`name: "simulated" \| "kat"`, `start`, `hangup`) | `services/callService.ts`, `container.ts`, 각 제공자 |
| `simulatedProvider.ts` | `class SimulatedCallProvider(speed)` — 시나리오 템플릿으로 통화를 재생하고 승인 단계에서 `requestApproval`을 호출 | `container.ts` |
| `realtimeBridge.ts` | `RealtimeOptions`, `bridgeToRealtime(params)` — OpenAI Realtime WebSocket 연결, `request_user_approval`·`end_call` 도구 처리 | `providers/kat/katProvider.ts` |
| `realtimeEvents.ts` | `parseRealtimeEvent`, `ApprovalToolArgs` (OpenAI Realtime 이벤트 zod 검증) | `realtimeBridge.ts` |
| `kat/katProvider.ts` | `KatOptions`, `toKatPhoneNumber`, `katTimeLimitSec`, `class KatCallProvider`(`start`, `hangup`, `routes`, `handleStatusWebhook`, `attachMediaStream`) | `container.ts` (`http/app.ts`는 `ProviderRoutes`로만 접근) |
| `kat/webhook.ts` | `verifyKatHttpSignature`, `verifyKatStreamSignature` | `kat/katProvider.ts` |
| `kat/schemas.ts` | `CreateCallResponse`, `ApiErrorBody`, `StatusWebhook`, `StartFrame`, `parseMediaStreamFrame` | `kat/katProvider.ts`, `realtimeBridge.ts` |

### `services/callService.ts`

책임: 작업 생명주기 전체(생성, 비동기 계획, 계획 승인, 발신, 통화 중 승인, 취소, 삭제, 요약, 상한 적용, 재시작 복구).

공개 인터페이스: `class CallService`(`recoverInterruptedTasks`, `list`, `get`, `create`, `approvePlan`, `cancel`, `respondToApproval`, `delete`), `ServiceError(statusCode, code, message)`, `CallServiceOptions`, `ApprovalResponseInput`.

사용처: `container.ts`(생성), `http/app.ts`(호출, `ServiceError` 매핑), `index.ts`(`recoverInterruptedTasks`).

### `store/taskStore.ts`

공개 인터페이스: `interface TaskStore { list; get; save; delete; flush }`, `InMemoryTaskStore`, `JsonFileTaskStore.open(path)`.

사용처: `index.ts`(`JsonFileTaskStore`), `container.ts`·`callService.ts`(`TaskStore` 타입). `InMemoryTaskStore`는 테스트(`http/app.test.ts`)가 쓴다.

### `events/eventBus.ts`

공개 인터페이스: `ServerEvent`(`task.updated` | `task.deleted`), `class EventBus { publish; subscribe → unsubscribe }`.

사용처: `container.ts`(생성), `callService.ts`(발행), `http/app.ts`(`/v1/stream` 구독).

### `http/`

| 파일 | 공개 인터페이스 | 사용처 |
|---|---|---|
| `app.ts` | `AppDeps`, `buildApp(deps)` | `index.ts`, `app.test.ts` |
| `schemas.ts` | `CreateTaskBody`, `ApprovePlanBody`, `ApprovalDecisionBody`, `TaskParams`, `ApprovalParams` (zod) | `app.ts` |

### 최상위 파일

| 파일 | 공개 인터페이스 | 사용처 |
|---|---|---|
| `config.ts` | `AppConfig`(env 필드 + `provider`, `llm`), `loadConfig(env)` | `index.ts`, `container.ts`, `http/app.ts`(타입) |
| `container.ts` | `Container { calls; bus; kat? }`, `createContainer(config, store, log)` | `index.ts` |
| `logger.ts` | `Logger` 인터페이스, `logger` | `index.ts`, `container.ts` |
| `index.ts` | 없음(진입점) | — |

## Flutter 앱 (`app/lib/`)

### `core/`

| 파일 | 공개 인터페이스 | 사용처 |
|---|---|---|
| `config/app_settings.dart` | `sharedPreferencesProvider`, `AppSettings`(`serverUrl`, `apiToken`, `requesterName`, `callbackNumber`, `defaultServerUrl`), `SettingsController`, `settingsProvider` | `main.dart`, `calls_repository.dart`, `home_screen.dart`, `new_call_screen.dart`, `settings_screen.dart` |
| `network/api_client.dart` | `ApiException`, `ApiClient`(`get`, `post`, `delete`, `webSocketUri`) — 요청 제한 시간 20초 | `calls_repository.dart`, `settings_screen.dart`, `core/widgets/common.dart` |
| `network/live_channel.dart` | `LiveStatus`, `LiveConnection`, `LiveChannel` — 재연결 대기는 `min(30, 2^attempt)`초 | `calls_repository.dart`, `calls_controller.dart`, `home_screen.dart` |
| `router/app_router.dart` | `routerProvider` | `app.dart`, `approval_listener.dart` |
| `theme/app_theme.dart` | `AppTheme` | `app.dart`, 여러 화면·위젯 |
| `utils/formatters.dart` | 형식 함수(세부 미확인) | `home_screen`, `new_call_screen`, `call_detail_screen` |
| `widgets/common.dart` | `ResponsiveBody`, `SectionCard`, `BulletList`, `MessageView`, `PulsingDot` | 화면과 위젯 전반 |

### `features/calls/`

| 계층 | 파일 | 공개 인터페이스 | 사용처 |
|---|---|---|---|
| domain | `call_models.dart` | `CallLanguage`, `TaskStatus`, `Speaker`, `ApprovalStatus`, `OutcomeResult`, `TranscriptEntry`, `CallPlan`, `ApprovalRequest`, `CallOutcome`, `CallTask`, `NewCallRequest`, `ServerInfo` | 거의 모든 calls 파일, `settings_screen.dart`, `app_router.dart` |
| data | `calls_repository.dart` | `CallsEvent`(`TasksSnapshot`, `TaskUpdated`, `TaskDeleted`), `CallsRepository`(`serverInfo`, `list`, `create`, `approvePlan`, `cancel`, `decide`, `delete`, `openLiveChannel`, `parseEvent`), `apiClientProvider`, `callsRepositoryProvider`, `serverInfoProvider` | `calls_controller.dart`, `home_screen.dart` |
| application | `calls_controller.dart` | `LiveStatusController`, `liveStatusProvider`, `CallsController`, `callsControllerProvider`, `sortedTasksProvider`, `taskProvider`(family), `PendingApproval`, `pendingApprovalsProvider` | 화면, `approval_listener.dart`, `approval_card.dart` |
| presentation | `home_screen.dart`, `new_call_screen.dart`, `call_detail_screen.dart`, `call_templates.dart`(`CallTemplate`), `approval_listener.dart`(`ApprovalListener`, `scaffoldMessengerKey`), `widgets/`(`approval_card`, `outcome_card`, `status_chip`, `transcript_view`) | `app_router.dart`, `app.dart` |

### `features/settings/settings_screen.dart`

`SettingsScreen`. 설정 저장(`settingsProvider`)과 서버 정보 조회에 `ApiClient`를 직접 쓴다. 사용처는 `app_router.dart`.

---

Generated by /moai project on 2026-11-20; based on repository state at commit c95953f.
