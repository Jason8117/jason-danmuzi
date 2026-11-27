# 콜비 — 진입점

## 서버 기동 (`server/src/index.ts`)

최상위 `await`로 차례대로 실행된다.

1. `loadConfig()` — 환경 변수를 zod로 검증하고 `provider`(`simulated` | `kat`)와 `llm`(`openai` | `heuristic`)을 정한다. `CALL_PROVIDER=kat`인데 필수 변수가 빠졌거나, `kat`인데 `API_TOKEN`이 없으면 여기서 예외로 멈춘다.
2. `JsonFileTaskStore.open(config.DATA_FILE)` — 파일을 읽어 메모리에 올린다. 파일이 없으면(`ENOENT`) 빈 저장소로 시작하고, 그 밖의 읽기·파싱 오류는 그대로 던진다. `version`이 없는 옛 레코드는 0으로 채운다.
3. `createContainer(config, store, logger)` — `EventBus`, 두뇌, 제공자, `CallService`를 만들고 `{ calls, bus, kat }`를 돌려준다. `kat`은 KAT 모드에서만 존재한다.
4. `calls.recoverInterruptedTasks()` — 재시작 전에 끝나지 않은 작업을 정리한다(`data-flow.md` 「재시작 복구」).
5. `buildApp({ config, calls, bus, kat })` — Fastify 인스턴스를 만들고 라우트를 등록한다.
6. `API_TOKEN`이 없으면 API가 열려 있다는 경고를 남긴다.
7. `app.listen({ port, host })` 후 `"CallMate server ready"` 로그(제공자, 두뇌, 포트, `PUBLIC_BASE_URL`의 호스트만).

종료: `SIGINT`·`SIGTERM`을 한 번씩 받으면 `app.close()` → `store.flush()`(대기 중인 저장을 즉시 기록) → `process.exit(0)`. 진행 중인 통화를 끊거나 승인을 정리하는 단계는 없다.

## HTTP 미들웨어 (`server/src/http/app.ts` `buildApp`)

등록 순서:

1. `@fastify/formbody`, `@fastify/websocket`(`maxPayload` 1MiB). 본문 한도는 64KiB.
2. `CORS_ORIGINS`가 있으면 `@fastify/cors`(메서드 GET, POST, DELETE).
3. `preParsing` 훅: 제공자가 `rawBody: true`로 선언한 HTTP 라우트(KAT는 `/kat/status`)의 원문 본문을 `rawBody`에 보관한다. 서명이 원문 바이트 기준이기 때문이다(`registerProviderRoutes`).
4. 오류 처리기: `ZodError` → 400 `invalid_request`, `ServiceError` → 자체 코드, `InvalidTransitionError` → 409 `invalid_state`, 그 밖의 4xx → `bad_request`, 나머지 → 500 `internal`.
5. `onRequest` 훅: `/v1/`로 시작하고 `API_TOKEN`이 설정된 경우에만 토큰을 `timingSafeEqual`로 비교한다. `/v1/stream`만 `?token=`도 받는다. 요청 로그에서는 `token=` 값을 `***`로 가린다.

## 라우트

메서드·경로·용도 표는 `structure.md` 「클라이언트–서버 계약」에 있다. 아래는 각 핸들러가 호출하는 코드다.

| 경로 | 핸들러가 하는 일 |
|---|---|
| `GET /health` | `{ ok: true }` |
| `GET /v1/config` | `{ provider, brain, realCalls: provider === "kat" }` |
| `GET /v1/tasks` | `calls.list()` → `{ tasks }` (생성 시각 내림차순) |
| `GET /v1/tasks/:id` | `calls.get(id)`, 없으면 404 `not_found`. `id`는 UUID 검증 |
| `POST /v1/tasks` | `CreateTaskBody` 검증(선택 `autoStart`) → `calls.create(input, { autoStart })`(종료 중 503 `shutting_down`, `checkTargetNumber`로 400 `invalid_phone` / `blocked_number`, 상한 429) → 201 |
| `POST /v1/intake` | `IntakeBody`(`text`, `language`) 검증 → `calls.draftIntake()` → 계획 카드 초안(작업을 만들지 않음, 종료 중 503) |
| `POST /v1/tasks/:id/approve-plan` | `ApprovePlanBody`(선택적 `plan` 부분 덮어쓰기) → `calls.approvePlan()` |
| `POST /v1/tasks/:id/cancel` | `calls.cancel()` |
| `POST /v1/tasks/:id/approvals/:approvalId` | `ApprovalDecisionBody`(`decision`, 선택적 `comment`) → `calls.respondToApproval()` |
| `DELETE /v1/tasks/:id` | `calls.delete()` → 204 |
| `WS /v1/stream` | 연결 즉시 `snapshot` 전송 → `bus.subscribe`로 이후 이벤트 전달 → 25초마다 ping → 닫히면 구독·타이머 해제 |

### 제공자 선언 라우트 (`registerProviderRoutes`)

제공자가 `routes()`로 선언한 라우트만 등록된다. KAT 제공자(`KatCallProvider.routes()`)가 아래 두 라우트를 선언하며, 시뮬레이션 제공자는 선언하지 않으므로 시뮬레이션 모드에서는 404다.

| 경로 | 처리 |
|---|---|
| `POST /kat/status` | 서명이 유효하지 않으면 401 `{ error: "invalid_signature" }`. 유효하면 `providers/kat/schemas.ts`의 `StatusWebhook`으로 검증해 처리한 뒤 204 |
| `WS /kat/media` | `KatCallProvider.attachMediaStream`. 시작 프레임은 `StartFrame` 스키마로 검증 |

## 웹훅 처리 (`providers/kat/katProvider.ts`)

- `handleStatusWebhook`: `data.metadata.taskId` 또는 `callId`로 진행 중인 통화를 찾는다. 못 찾으면 무시한다.
  - `media_stream.call.ringing` → `session.markRinging()`
  - `media_stream.call.answered` 또는 `status === "in-progress"` → `session.markConnected()`
  - `media_stream.call.completed` / `failed` → 음성이 한 번도 연결되지 않았으면 터널·WSS 점검 안내를 담은 오류로 종료, `status === "completed"`면 정상 종료, 그 밖에는 `FAILURE_MESSAGES`의 오류로 종료
- `attachMediaStream`: 업그레이드 요청의 스트림 서명을 먼저 검증하고(실패 시 소켓을 닫는다), 10초 안에 `start` 이벤트가 오지 않으면 닫는다. `start`가 오면 `customParameters`의 토큰을 확인한 뒤 OpenAI Realtime과 연결한다(`bridgeToRealtime`). 이후 세부 흐름은 일부만 읽었다(미확인 부분 있음).
- 서명 검증 함수는 `providers/kat/webhook.ts`의 `verifyKatHttpSignature`, `verifyKatStreamSignature`다.

## 앱 진입점

### `app/lib/main.dart`

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `SharedPreferences.getInstance()`와 `initializeDateFormatting('ko')`를 동시에 기다린다.
3. `ProviderScope`에서 `sharedPreferencesProvider`를 로드된 인스턴스로 덮어쓴 뒤 `CallMateApp`을 실행한다.

### `app/lib/app.dart`

`CallMateApp`은 `MaterialApp.router`를 만든다. 제목 `'CallMate'`, 라이트·다크 테마, `routerProvider`, 전역 `scaffoldMessengerKey`, 로케일 `ko`(지원 `ko`, `en`). `builder`가 모든 화면을 `ApprovalListener`로 감싸므로, 어느 화면에 있든 새 통화 중 승인이 오면 진동과 함께 12초짜리 스낵바(「답하기」 → `/calls/:id`)가 뜬다. 이미 그 상세 화면에 있으면 띄우지 않는다.

### 라우트 (`app/lib/core/router/app_router.dart`)

경로 표는 `structure.md`에 있다. 코드에서 더 확인한 내용:

- `/calls/new`는 `state.extra`로 `CallTemplate`(템플릿에서 시작) 또는 `CallTask`(다시 걸기)를 받는다.
- `/plan`은 `state.extra`가 `PlanDraft`일 때만 `PlanCardScreen(draft)`을 열고, 아니면 `/`로 돌려보낸다. 홈의 한 줄 부탁과 상세 화면의 "다시 걸기"가 이 경로로 온다.
- `/calls/:id`는 `CallDetailScreen(taskId)`.
- 라우터는 Riverpod `Provider`이며 dispose 시 함께 정리된다.

### 빌드 정의 (`--dart-define`)

| 이름 | 읽는 곳 | 우선순위 |
|---|---|---|
| `CALLMATE_SERVER_URL` | `AppSettings.defaultServerUrl` | 설정 화면 저장값 → 빌드 정의 → Android `http://10.0.2.2:8787` → 그 밖 `http://127.0.0.1:8787` |
| `CALLMATE_API_TOKEN` | `SettingsController.build` | 설정 화면 저장값 → 빌드 정의 → 빈 문자열 |

서버의 빌드 정의에 해당하는 것은 없다. 서버 설정은 모두 실행 시 환경 변수(`tech.md`)로 받는다.

---

Generated by /moai project on 2026-11-20; based on repository state at commit c95953f. Updated by /moai sync on 2026-11-27 for SPEC-APPROVAL/INTAKE/FOLLOWUP-001 (state at 8ad8239).
