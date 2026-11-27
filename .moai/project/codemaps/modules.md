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
| `router/app_router.dart` (다시 내보내기 → `shell/app_router.dart`, SPEC-SHELL-001) | `routerProvider` | `app.dart`, `approval_listener.dart`, 테스트 |
| `clock.dart` | `clockProvider`(`DateTime Function()`, 기본 `DateTime.now`; 테스트가 덮어씀) | `home_screen.dart`, `shell/task_feed.dart` |
| `widgets/trust_notice.dart` (SPEC-SHELL-001에서 `features/calls/presentation/`에서 옮김) | `trustStatements`, `agentRulesNotice`, `liveCallTrustLine`, `ensureTrustAcknowledged`, `TrustStatementList` | `settings_screen.dart`, `features/calls/presentation/trust_notice.dart`(다시 내보내기) |
| `theme/app_theme.dart` (다시 내보내기 → `packages/kolbi_ui/lib/src/theme/app_theme.dart`) | `AppTheme`(씨앗 색 `#635BFF`, `fontFamily` Pretendard, 카드 1px 선), `CardTone`(neutral·attention·positive·caution·critical; `caution`은 neutral과 같은 무채색 값), `ToneColors`, 상태 색 | `app.dart`, 여러 화면·위젯 |
| `theme/tokens.dart` (다시 내보내기 → `packages/kolbi_ui/lib/src/theme/tokens.dart`) | `AppSpace`(4~32), `AppRadius`(12·16·20·pill), `AppMotion`(150·250·400 ms, `pulse` 1100 ms), `kMinTapTarget`(48), `motionDuration`, `scrollToOffset`, `relativeLuminance`, `contrastRatio`. 06 §3 색 상수 `AppColors`도 이 파일에 있으나 배럴로 내보내지 않는 패키지 내부용이다(SPEC-DESIGN-001) | `app_theme.dart`, `common.dart`, `features/calls/presentation/**`, `settings_screen.dart` |
| `utils/formatters.dart` (다시 내보내기 → `packages/kolbi_core/lib/src/format/formatters.dart`) | `formatPhone`, `formatDuration`, `formatRelative`, `formatClock` | `home_screen`, `new_call_screen`, `call_detail_screen` |
| `widgets/common.dart` (다시 내보내기 → `packages/kolbi_ui/lib/src/widgets/common.dart`) | `ResponsiveBody`, `AppCard`(공용 카드: 머리 줄·본문·행동 줄·`tone`), `SectionCard`, `BulletList`, `MessageView`(공용 빈 상태), `PulsingDot`, `runWithFeedback`, `describeError` | 화면과 위젯 전반 |

### `features/calls/`

| 계층 | 파일 | 공개 인터페이스 | 사용처 |
|---|---|---|---|
| domain | `call_models.dart` (다시 내보내기 → `packages/kolbi_core/lib/src/models/call_models.dart`; 같은 방식으로 `intake_models`·`counterparties` → `src/models/`, `follow_up` → `src/follow_up.dart`, `approval_comment` → `src/approval_comment.dart` + kolbi_ui `src/input/code_point_formatter.dart`) | `CallLanguage`, `TaskStatus`, `Speaker`, `ApprovalStatus`, `OutcomeResult`, `TranscriptEntry`, `CallPlan`, `ApprovalRequest`, `CallOutcome`, `CallTask`(SPEC-SHELL-001에서 `kind`(`String?`, 없거나 문자열이 아니면 `null` = `call`) 추가), `NewCallRequest`, `ServerInfo` | 거의 모든 calls 파일, `settings_screen.dart`, `app_router.dart` |
| data | `calls_repository.dart` (공급자는 앱에 남고, 클래스·이벤트는 `packages/kolbi_core/lib/src/data/calls_repository.dart`에서 다시 내보냄) | `CallsEvent`(`TasksSnapshot`, `TaskUpdated`, `TaskDeleted`), `CallsRepository`(`serverInfo`, `list`, `create`, `approvePlan`, `cancel`, `decide`, `delete`, `openLiveChannel`, `parseEvent`) — kolbi_core; `apiClientProvider`, `callsRepositoryProvider`, `serverInfoProvider` — 앱 | `calls_controller.dart`, `home_screen.dart` |
| application | `calls_controller.dart` | `LiveStatusController`, `liveStatusProvider`, `CallsController`, `callsControllerProvider`, `sortedTasksProvider`, `taskProvider`(family), `PendingApproval`, `pendingApprovalsProvider` | 화면, `approval_listener.dart`, `approval_card.dart` |
| presentation | `home_screen.dart`(오늘 탭: 날짜·인사·브리핑·바로가기·확인이 필요해요·진행 중), `plan_card_screen.dart`(`PlanCardScreen`, [이대로 시작] 뒤 `openTask`), `new_call_screen.dart`, `call_detail_screen.dart`(맨 위 `KolbiStepTimeline`), `trust_notice.dart`(다시 내보내기 → `core/widgets/trust_notice.dart`), `call_templates.dart`(`CallTemplate`), `approval_listener.dart`(`ApprovalListener`, `scaffoldMessengerKey`), `widgets/`(`approval_card`·`follow_up_actions`(`FollowUpService`, `DeviceFollowUpService`, `followUpServiceProvider`, `followUpClockProvider`, `FollowUpActions`)·`call_task_tile`(`CallTaskTile`, 옛 홈 `_TaskTile`, 칩 열은 화면 폭의 40 % 이하)는 앱에 남음; `outcome_card`·`status_chip`·`transcript_view`는 다시 내보내기 → `packages/kolbi_ui/lib/src/widgets/`) | `app_router.dart`, `app.dart` |

### `features/settings/settings_screen.dart`

`SettingsScreen`. 설정 저장(`settingsProvider`)과 서버 정보 조회에 `ApiClient`를 직접 쓴다(`kolbi_core` 배럴로). 신뢰 안내는 `core/widgets/trust_notice.dart`에서 가져온다. 사용처는 `shell/app_router.dart`.

### `features/inbox`, `features/history`, `features/me` (SPEC-SHELL-001)

세 기능은 `features/calls`를 가져오지 않는다. 작업 목록·묶음은 `shell/task_feed.dart`, 행·상세는 `shell/kind_registration.dart`, 이동은 `shell/navigation.dart`·`shell/routes.dart`로 한다.

| 파일 | 공개 인터페이스 | 사용처 |
|---|---|---|
| `inbox/inbox_screen.dart` | `InboxScreen`(키 `tasks-screen`; 개수 세 칸 진행 중·승인 대기·오늘 완료, 승인 요청·진행 중·반복 묶음, "끝난 업무는 기록에서 볼 수 있어요" 링크, 빈 상태 [비서에게 맡기기], 오류 [다시 시도]) | `shell/app_router.dart` |
| `history/history_screen.dart` | `HistoryScreen`(서울 날짜 묶음 + 결과 칩), `historyLineOf(task)`(결과 한 줄) | `shell/app_router.dart` |
| `me/me_screen.dart` | `MeScreen`(프로필 카드, 비서·권한과 안전·앱 묶음, 비활성 항목은 "곧 쓸 수 있어요"), `maskCallbackNumber(number)` | `shell/app_router.dart` |

### `shell/` (SPEC-SHELL-001)

라우터와 탭 사이 이동은 이 디렉터리에만 있다(`architecture_test.dart` "router and tab switching live in the shell").

| 파일 | 공개 인터페이스 | 사용처 |
|---|---|---|
| `app_router.dart` | `routerProvider`(유일한 `GoRouter`: `StatefulShellRoute` 4갈래 + 셸 밖 `/assistant`) | `core/router/app_router.dart`(다시 내보내기) |
| `routes.dart` | `RouteNames`(today, new-call, plan, inbox, task, history, me, settings, assistant), `AppTab`(today `/`, tasks `/inbox`, history `/history`, me `/me`) | 셸, 기능 화면 |
| `navigation.dart` | `registerTabShell`, `openTask(router, id)`(쌓인 화면을 최대 32번 닫고 `goNamed(inbox)` + `pushNamed(task)`), `openTab(router, tab)`(등록된 셸의 `goBranch`, 없으면 `go`), `openAssistant`, `submitFromAssistant(router, draft)`(비서를 닫고 계획 카드), `taskLocation` | 오늘·업무·기록, 계획 카드, 직접 입력, 승인 스낵바, 임시 비서 |
| `tab_scaffold.dart` | `TabScaffold`(`Scaffold`가 아닌 `Material` + `Column`, 탭 화면에는 탭 바 위 높이의 `MediaQuery`), `BranchStack`(`IndexedStack` + 숨은 갈래 `HeroMode` 끔), `TabScrollScope`(탭 첫 화면 스크롤, 다시 누르면 맨 위로) | `app_router.dart`, 탭 첫 화면 |
| `assistant_placeholder.dart` | `AssistantPlaceholderScreen`(부탁 입력·보내기·예시 칩; 보낼 때 프로필이 없으면 비서를 닫고 설정을 엶) | `app_router.dart` |
| `kind_registration.dart` | `taskKindCatalogProvider`(`call` 등록), `taskKindPresentersProvider`, `presenterForTask(ref, task)`, `CallKindPresenter`, `TaskDetailRoute` | 업무·기록·오늘, `app_router.dart` |
| `task_feed.dart` | `taskListProvider`, `taskGroupsProvider`, `historyDaysProvider`, `reloadTasks`, `refreshTasks` | 오늘·업무·기록, 탭 바 배지 |

## 공용 패키지 (`packages/`, SPEC-MODULE-001)

| 패키지 | 파일(`lib/src/`) | 배럴 |
|---|---|---|
| `kolbi_core`(순수 Dart) | `models/call_models.dart`, `models/intake_models.dart`, `models/counterparties.dart`, `follow_up.dart`, `approval_comment.dart`(상수·`codePointLength`·`truncateToCodePoints`·`withQuickReply`·`hasSensitiveDigits`), `network/api_client.dart`, `network/live_channel.dart`, `format/formatters.dart`, `format/korean_particle.dart`, `data/calls_repository.dart`(이벤트·`CallsRepository`), `kinds/task_kind.dart`, `kinds/call_kind.dart`, `tasks/task_groups.dart`, `tasks/task_steps.dart` | `lib/kolbi_core.dart` |
| `kolbi_ui`(Flutter) | `theme/tokens.dart`, `theme/app_theme.dart`, `theme/fonts.dart`(`registerKolbiFontLicenses`), `widgets/common.dart`, `widgets/status_chip.dart`(`StatusChip`, `StatusCategory`), `widgets/outcome_card.dart`, `widgets/transcript_view.dart`, `widgets/step_timeline.dart`, `widgets/briefing_card.dart`, `widgets/tab_badge.dart`, `kinds/task_kind_presenter.dart`, `input/code_point_formatter.dart`(`CodePointLengthLimitingFormatter`) | `lib/kolbi_ui.dart` |

`kolbi_ui`의 SPEC-DESIGN-001 추가분:

| 이름 | 위치 | 내용 |
|---|---|---|
| `StatusCategory` | `widgets/status_chip.dart`(배럴 공개) | 상태 칩 다섯 범주 `waiting`·`active`·`needsApproval`·`done`·`failed`. 작업 상태 9개 × 대기 승인 여부 2개(18칸)를 이 다섯으로 나눈다(plan §A.2). 대기 승인이 있으면 어떤 상태든 `needsApproval` |
| `StatusChip.category(category, label)` | 같은 파일 | 작업 상태가 아닌 것(결과 종류 등)을 범주 색·아이콘으로 그리는 생성자. 깜박이는 점은 없다. 이때 `status`는 `null`(`TaskStatus?`). 기존 `StatusChip(status, needsApproval:)` 생성자는 그대로다 |
| `StatusChip.iconOf`, `StatusChip.category`(getter) | 같은 파일 | 범주별 아이콘(서로 다른 모양 다섯)과 칩의 범주를 돌려주는 공개 도우미 |
| `AppColors` | `theme/tokens.dart`(내부) | 06 §3.1~§3.3 색 상수. 배럴에서 내보내지 않는다 |
| `registerKolbiFontLicenses()` | `theme/fonts.dart`(배럴 공개) | Pretendard OFL 문구를 `LicenseRegistry`에 등록. 앱 `main.dart`가 `runApp` 전에 호출한다(SPEC-SHELL-001) |

SPEC-SHELL-001 추가분(작업 종류·단계·묶음):

| 이름 | 위치 | 내용 |
|---|---|---|
| `TaskKindDescriptor`, `TaskKindCatalog`, `UnknownTaskKind`, `DuplicateTaskKindError`, `kCallKindId` | kolbi_core `kinds/task_kind.dart` | 작업 종류의 화면 밖 절반(`id`, `isKnown`, `statusLabel`, `parseDetails`, `steps`)과 등록부. 같은 id를 두 번 등록하면 오류, `kind` 값이 없으면 `call`, 모르는 값이면 `UnknownTaskKind` |
| `CallTaskKind` | kolbi_core `kinds/call_kind.dart` | `call` 종류. 단계는 `taskSteps` |
| `TaskStepId`, `TaskStepState`, `TaskStep`, `taskSteps(task)` | kolbi_core `tasks/task_steps.dart` | 6단계(요청 이해 · 연락처 확인 · 가능 여부 확인 · 내 승인 · 확정 · 결과 보고)와 상태(끝남·지금·대기·실패·건너뜀·취소), 단계마다 고정 설명 줄(SHELL design.md D2.2·D2.3). 상태 enum 이름은 `material_ui`의 `StepState`와 겹치지 않게 `TaskStepState` |
| `TaskGroups`, `groupTasks(tasks, now:)`, `isApprovalRequest(task)` | kolbi_core `tasks/task_groups.dart` | 승인 요청·진행 중·오늘 완료 수, 배지 수 = 승인 요청 수, 브리핑 수 = 승인 요청 + 진행 중. 승인 요청 규칙은 `isApprovalRequest` 한 곳에만 있다 |
| `HistoryDay`, `groupHistory(tasks, now:)` | 같은 파일 | 끝난 작업을 서울(UTC+9 고정) 날짜로 묶고 "오늘 · 11월 26일" / "어제 · …" / "11월 24일" 이름을 붙임 |
| `withSubjectParticle(name)` | kolbi_core `format/korean_particle.dart` | 끝 글자 받침으로 이/가를 붙임. 한글로 끝나지 않으면 "(이)가" |
| `TaskKindPresenter`, `UnknownKindPresenter`, `TaskKindPresenters` | kolbi_ui `kinds/task_kind_presenter.dart` | 작업 종류의 화면 절반(아이콘, 행 `buildRow`, 상세 `buildDetail`)과 표시자 등록부. 모르는 종류는 "이 작업은 앱을 업데이트하면 볼 수 있어요" |
| `KolbiStepTimeline` | kolbi_ui `widgets/step_timeline.dart` | CMP-34. 단계 줄마다 키 `task-step-<n>`, 읽기 라벨 "6단계 중 N단계, <이름>, <상태>". 첫 취소 단계 뒤는 숨김 |
| `KolbiBriefingCard` | kolbi_ui `widgets/briefing_card.dart` | CMP-37. 제목·한 문장·링크 |
| `KolbiTabBadge` | kolbi_ui `widgets/tab_badge.dart` | 업무 탭 배지. 0이면 숨김, 10 이상은 "9+". 읽기 문구는 탭이 맡음("업무, 승인 대기 N개") |

테스트: kolbi_core `test/task_kind_test.dart`, `task_steps_test.dart`(design.md D2.2 표를 행마다), `task_groups_test.dart`, `test/support/tasks.dart`; kolbi_ui `test/step_timeline_test.dart`(배지·브리핑 카드·표시자 등록부 포함); 앱 `shell_test.dart`, `inbox_test.dart`, `history_test.dart`, `today_test.dart`, `test/support/shell_support.dart`, `accessibility_test.dart`의 "shell screens meet the accessibility guidelines".

테스트(SPEC-DESIGN-001): `packages/kolbi_ui/test/`에 `theme_values_test.dart`(역할·분위기 짝·카드 선·글꼴 값), `tokens_contrast_test.dart`(대비 48쌍 + `#635BFF` 글자 금지), `status_chip_test.dart`(18칸 × 밝은·어두운)가 더해졌고, 앱에는 `app/test/design_contrast_test.dart`(디자인 화면 대비·기기 다크 모드), `app/test/font_overflow_test.dart`(실제 Pretendard로 360x640·글자 2배 넘침 검사)가 더해졌다.

---

Generated by /moai project on 2026-11-20; based on repository state at commit c95953f. Updated by /moai sync on 2026-11-27 for SPEC-UX-001 (state at c2e732d). Updated by /moai sync on 2026-11-27 for SPEC-MODULE-001 (state at 6cdf8af). Updated by /moai sync on 2026-11-27 for SPEC-APPROVAL/INTAKE/FOLLOWUP-001 (state at 8ad8239). Updated by /moai sync on 2026-11-27 for SPEC-DESIGN-001 (state at 5ee6eef). Updated by /moai sync on 2026-11-27 for SPEC-SHELL-001 (state at b67d452).
