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
| `approvalComment.ts` | `SENSITIVE_PLACEHOLDER`, `sanitizeApprovalComment` (SPEC-APPROVAL-001) | `services/callService.ts`, `brain/prompts.ts`(규칙 7 문구의 자리표시) |
| `intake.ts` | `PHONE_PLACEHOLDER`, `maskPhoneNumbers`, `TextNumber`, `findPhoneNumberInText`, `normalizeName`, `stripPhoneNumbers`, `answeredHistory`, `findKnownName`, `findHistoryNumber` (SPEC-INTAKE-001) | `services/callService.ts`, `brain/heuristicBrain.ts`(`PHONE_PLACEHOLDER`) |

다른 모듈에 의존하지 않는 최하위 계층이다.

### `brain/`

책임: 통화 전 계획 작성과 통화 후 요약. 실시간 대화는 맡지 않는다(`types.ts` 주석).

| 파일 | 공개 인터페이스 | 사용처 |
|---|---|---|
| `types.ts` | `interface CallBrain { name; createPlan(input); summarize(task); draftIntake?(maskedText, language) }` — `draftIntake`는 선택(없으면 서비스가 결정적 규칙을 씀) | `services/callService.ts`, `container.ts` |
| `openaiBrain.ts` | `class OpenAiBrain` (Chat Completions, `response_format: json_object`), `OpenAiBrainOptions`(`intakeTimeoutMs`), `LLM_TIMEOUT_MS`(30 s), `INTAKE_LLM_TIMEOUT_MS`(15 s), `SUMMARY_TIMEZONE`. LLM 호출이 실패하면 내부의 `HeuristicBrain`으로 대체한다(`completeJson`의 `fallback`). 요약 결과의 선택 필드 `appointment`는 확정된 일정만 남긴다(SPEC-FOLLOWUP-001) | `container.ts` |
| `heuristicBrain.ts` | `class HeuristicBrain`, `isFiller` | `container.ts`, `openaiBrain.ts` |
| `prompts.ts` | `openingLine`, `buildAgentInstructions`(Hard rule 7: `user_comment` 따르기), `PLAN_SYSTEM_PROMPT`, `INTAKE_SYSTEM_PROMPT`, `SUMMARY_SYSTEM_PROMPT` | `heuristicBrain.ts`, `openaiBrain.ts`, `providers/realtimeBridge.ts` |

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

공개 인터페이스: `class CallService`(`recoverInterruptedTasks`, `list`, `get`, `create`(선택 `{ autoStart }`), `draftIntake`, `approvePlan`, `cancel`, `respondToApproval`, `delete`), `ServiceError(statusCode, code, message)`, `CallServiceOptions`, `ApprovalResponseInput`.

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

SPEC-MODULE-001 이후 아래 표에서 "다시 내보내기"로 표시한 파일은 본문이 공용 패키지로 옮겨졌고, 옛 경로에는 `export` 줄만 남아 있다(테스트 import를 고치지 않기 위함). 앱 소스는 배럴 `package:kolbi_core/kolbi_core.dart`·`package:kolbi_ui/kolbi_ui.dart`를 가져오며, 공개 인터페이스는 각 배럴의 `show` 목록과 같다. 패키지 쪽 위치는 아래 「공용 패키지」 절에 있다.

### `core/`

| 파일 | 공개 인터페이스 | 사용처 |
|---|---|---|
| `config/app_settings.dart` | `sharedPreferencesProvider`, `AppSettings`(`serverUrl`, `apiToken`, `requesterName`, `callbackNumber`, `trustNoticeAcknowledged`, `defaultServerUrl`), `SettingsController`(`acknowledgeTrustNotice`, `save`), `settingsProvider` | `main.dart`, `calls_repository.dart`, `home_screen.dart`, `new_call_screen.dart`, `settings_screen.dart` |
| `network/api_client.dart` (다시 내보내기 → `packages/kolbi_core/lib/src/network/api_client.dart`) | `ApiException`, `ApiClient`(`get`, `post`, `delete`, `webSocketUri`) — 요청 제한 시간 20초 | `calls_repository.dart`, `settings_screen.dart`, `packages/kolbi_ui/lib/src/widgets/common.dart` |
| `network/live_channel.dart` (다시 내보내기 → `packages/kolbi_core/lib/src/network/live_channel.dart`) | `LiveStatus`, `LiveConnection`, `LiveChannel` — 재연결 대기는 `min(30, 2^attempt)`초 | `calls_repository.dart`, `calls_controller.dart`, `home_screen.dart` |
| `router/app_router.dart` | `routerProvider` | `app.dart`, `approval_listener.dart` |
| `theme/app_theme.dart` (다시 내보내기 → `packages/kolbi_ui/lib/src/theme/app_theme.dart`) | `AppTheme`, `CardTone`(neutral·attention·positive·caution·critical), `ToneColors`, 상태 색 | `app.dart`, 여러 화면·위젯 |
| `theme/tokens.dart` (다시 내보내기 → `packages/kolbi_ui/lib/src/theme/tokens.dart`) | `AppSpace`(4~32), `AppRadius`(12·16·20·pill), `AppMotion`(150·250·400 ms, `pulse` 1100 ms), `kMinTapTarget`(48), `motionDuration`, `scrollToOffset`, `relativeLuminance`, `contrastRatio` | `app_theme.dart`, `common.dart`, `features/calls/presentation/**`, `settings_screen.dart` |
| `utils/formatters.dart` (다시 내보내기 → `packages/kolbi_core/lib/src/format/formatters.dart`) | `formatPhone`, `formatDuration`, `formatRelative`, `formatClock` | `home_screen`, `new_call_screen`, `call_detail_screen` |
| `widgets/common.dart` (다시 내보내기 → `packages/kolbi_ui/lib/src/widgets/common.dart`) | `ResponsiveBody`, `AppCard`(공용 카드: 머리 줄·본문·행동 줄·`tone`), `SectionCard`, `BulletList`, `MessageView`(공용 빈 상태), `PulsingDot`, `runWithFeedback`, `describeError` | 화면과 위젯 전반 |

### `features/calls/`

| 계층 | 파일 | 공개 인터페이스 | 사용처 |
|---|---|---|---|
| domain | `call_models.dart` (다시 내보내기 → `packages/kolbi_core/lib/src/models/call_models.dart`; 같은 방식으로 `intake_models`·`counterparties` → `src/models/`, `follow_up` → `src/follow_up.dart`, `approval_comment` → `src/approval_comment.dart` + kolbi_ui `src/input/code_point_formatter.dart`) | `CallLanguage`, `TaskStatus`, `Speaker`, `ApprovalStatus`, `OutcomeResult`, `TranscriptEntry`, `CallPlan`, `ApprovalRequest`, `CallOutcome`, `CallTask`, `NewCallRequest`, `ServerInfo` | 거의 모든 calls 파일, `settings_screen.dart`, `app_router.dart` |
| data | `calls_repository.dart` (공급자는 앱에 남고, 클래스·이벤트는 `packages/kolbi_core/lib/src/data/calls_repository.dart`에서 다시 내보냄) | `CallsEvent`(`TasksSnapshot`, `TaskUpdated`, `TaskDeleted`), `CallsRepository`(`serverInfo`, `list`, `create`, `approvePlan`, `cancel`, `decide`, `delete`, `openLiveChannel`, `parseEvent`) — kolbi_core; `apiClientProvider`, `callsRepositoryProvider`, `serverInfoProvider` — 앱 | `calls_controller.dart`, `home_screen.dart` |
| application | `calls_controller.dart` | `LiveStatusController`, `liveStatusProvider`, `CallsController`, `callsControllerProvider`, `sortedTasksProvider`, `taskProvider`(family), `PendingApproval`, `pendingApprovalsProvider` | 화면, `approval_listener.dart`, `approval_card.dart` |
| presentation | `home_screen.dart`, `plan_card_screen.dart`(`PlanCardScreen`), `new_call_screen.dart`, `call_detail_screen.dart`, `trust_notice.dart`(`trustStatements`, `agentRulesNotice`, `liveCallTrustLine`, `ensureTrustAcknowledged`, `TrustStatementList` — `settings_screen.dart`도 가져옴), `call_templates.dart`(`CallTemplate`), `approval_listener.dart`(`ApprovalListener`, `scaffoldMessengerKey`), `widgets/`(`approval_card`·`follow_up_actions`(`FollowUpService`, `DeviceFollowUpService`, `followUpServiceProvider`, `followUpClockProvider`, `FollowUpActions`)는 앱에 남음; `outcome_card`·`status_chip`·`transcript_view`는 다시 내보내기 → `packages/kolbi_ui/lib/src/widgets/`) | `app_router.dart`, `app.dart` |

### `features/settings/settings_screen.dart`

`SettingsScreen`. 설정 저장(`settingsProvider`)과 서버 정보 조회에 `ApiClient`를 직접 쓴다(`kolbi_core` 배럴로). 사용처는 `app_router.dart`.

## 공용 패키지 (`packages/`, SPEC-MODULE-001)

| 패키지 | 파일(`lib/src/`) | 배럴 |
|---|---|---|
| `kolbi_core`(순수 Dart) | `models/call_models.dart`, `models/intake_models.dart`, `models/counterparties.dart`, `follow_up.dart`, `approval_comment.dart`(상수·`codePointLength`·`truncateToCodePoints`·`withQuickReply`·`hasSensitiveDigits`), `network/api_client.dart`, `network/live_channel.dart`, `format/formatters.dart`, `data/calls_repository.dart`(이벤트·`CallsRepository`) | `lib/kolbi_core.dart` |
| `kolbi_ui`(Flutter) | `theme/tokens.dart`, `theme/app_theme.dart`, `widgets/common.dart`, `widgets/status_chip.dart`, `widgets/outcome_card.dart`, `widgets/transcript_view.dart`, `input/code_point_formatter.dart`(`CodePointLengthLimitingFormatter`) | `lib/kolbi_ui.dart` |

---

Generated by /moai project on 2026-11-20; based on repository state at commit c95953f. Updated by /moai sync on 2026-11-27 for SPEC-UX-001 (state at c2e732d). Updated by /moai sync on 2026-11-27 for SPEC-MODULE-001 (state at 6cdf8af). Updated by /moai sync on 2026-11-27 for SPEC-APPROVAL/INTAKE/FOLLOWUP-001 (state at 8ad8239).
