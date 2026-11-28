# 콜비 — 의존성

## 외부 패키지

버전과 용도 표는 `tech.md` 「기술 스택」에 있다(`server/package.json`, `app/pubspec.yaml`과 대조해 일치함을 확인했다). 여기서는 각 패키지를 실제로 가져다 쓰는 파일만 덧붙인다.

### 서버

| 패키지 | 사용 파일 |
|---|---|
| `fastify` ^5.12.8 | `http/app.ts` |
| `@fastify/cors` ^11.4.3 | `http/app.ts` (`CORS_ORIGINS`가 있을 때만 등록) |
| `@fastify/formbody` ^9.0.2 | `http/app.ts` |
| `@fastify/websocket` ^11.3.7 | `http/app.ts` (`/v1/stream`, `/kat/media`, `maxPayload` 1MiB) |
| `ws` ^8.23.0 | `providers/realtimeBridge.ts`(OpenAI Realtime 클라이언트), `providers/kat/katProvider.ts`(타입) |
| `zod` ^4.6.7 | `config.ts`, `http/schemas.ts`, `http/app.ts`(`ZodError`), `brain/openaiBrain.ts` |
| Node 내장 | `node:crypto`(UUID, HMAC, `timingSafeEqual`), `node:fs/promises`, `node:events`, `node:stream`, `node:timers/promises` |

OpenAI와 KAT Cloud는 SDK 없이 전역 `fetch`와 `ws`로 호출한다(`openaiBrain.ts`, `katProvider.ts`).

### 앱

| 패키지 | 사용 파일 |
|---|---|
| `flutter_riverpod` ^3.5.0 | `main.dart`, `app.dart`, `core/config`, `core/router`, `features/**` |
| `go_router` ^18.1.4 | `shell/app_router.dart`(유일한 `GoRouter`), `shell/navigation.dart`·`shell/tab_scaffold.dart`(탭 사이 이동), 화면의 `pushNamed`·`pop` |
| `http` ^1.6.0 | `packages/kolbi_core/lib/src/network/api_client.dart` (앱 `core/network/api_client.dart`는 다시 내보내기) |
| `web_socket_channel` ^3.0.3 | `packages/kolbi_core/lib/src/network/live_channel.dart` (앱 `core/network/live_channel.dart`는 다시 내보내기) |
| `share_plus` ^13.3.1 | `features/calls/presentation/widgets/follow_up_actions.dart`(요약 공유, `.ics` 캘린더 파일 공유; SPEC-FOLLOWUP-001 OD-1) |
| `shared_preferences` ^2.5.6 | `main.dart`, `core/config/app_settings.dart`, `features/assistant/assistant_screen.dart`(Android 음성 인식 서비스 안내 본 여부 `androidSpeechServiceNoticeAcknowledged`, `sharedPreferencesProvider`로) |
| `speech_to_text` ^7.5.0 | `features/assistant/speech/platform_speech_recognizer.dart`만(기기 음성 인식, SPEC-ASSIST-001; BSD 3-Clause) |
| `permission_handler` ^13.0.2 | `features/assistant/speech/platform_speech_recognizer.dart`만(마이크·음성 인식 권한, 앱 설정 열기; MIT) |
| `intl` ^0.20.3 | `main.dart`(`initializeDateFormatting('ko')`), 형식 처리 |
| `material_ui` ^1.1.0 | 위젯 전반(`package:material_ui/material_ui.dart`), `packages/kolbi_ui` |

### 공용 패키지 (SPEC-MODULE-001, 루트 `pubspec.yaml` 워크스페이스)

| 패키지 | 의존(`pubspec.yaml`) |
|---|---|
| `kolbi_core` | `characters` ^1.4.1, `http` ^1.6.0, `intl` ^0.20.3, `meta` ^1.19.0, `web_socket_channel` ^3.0.3; dev `test` ^1.29.0 |
| `kolbi_ui` | `flutter`, `kolbi_core` ^0.1.0, `material_ui` ^1.1.0; dev `flutter_test` |
| `app` | 위 표 + `kolbi_core` ^0.1.0, `kolbi_ui` ^0.1.0 |
| 루트(`kolbi_workspace`) | dev `test` ^1.29.0 (`test/workspace_test.dart`) |

## 내부 의존 그래프

### 서버 (import 문 기준, 타입 전용 import 포함)

```mermaid
flowchart TD
  index[index.ts] --> config[config.ts]
  index --> container[container.ts]
  index --> http[http/app.ts]
  index --> store[store/taskStore.ts]
  index --> logger[logger.ts]
  container --> brain[brain/*]
  container --> providers[providers/*]
  container --> service[services/callService.ts]
  container --> events[events/eventBus.ts]
  container --> store
  http --> service
  http --> events
  http --> ptypes[providers/types.ts]
  http --> sm[domain/stateMachine.ts]
  index --> shutdown[shutdown.ts]
  container --> kat[providers/kat/katProvider.ts]
  service --> phone[domain/phone.ts]
  service --> prompts
  http --> schemas[http/schemas.ts]
  service --> brain
  service --> providers
  service --> store
  service --> events
  service --> sm
  service --> types[domain/types.ts]
  providers --> scenario[domain/scenario.ts]
  brain --> scenario
  brain --> prompts[brain/prompts.ts]
  kat --> phone
  kat --> katschemas[providers/kat/schemas.ts]
  brain --> types
  store --> types
  events --> types
```

계층을 벗어나는 지점:

SPEC-POLICY-001과 SPEC-ARCH-001로 해소된 이전 예외(참고용): 번호 정책은 이제 `CallService`가 강제하고 `http/app.ts`는 `domain/phone.ts`를 import하지 않는다. `http/app.ts`는 `KatCallProvider`를 모르며 제공자가 선언한 `ProviderRoutes`만 등록한다. `providers/`는 `brain/`을 import하지 않는다(시나리오는 `domain/scenario.ts`, 에이전트 지시문은 `CallService`가 `buildAgentInstructions`로 만들어 `CallSession`에 담아 전달). 세 규칙은 `architecture.test.ts`가 검사한다.

남은 예외:
- `CallService`는 `CallBrain`·`CallProvider`·`TaskStore`는 인터페이스로 받지만, `EventBus`는 구체 클래스를 타입으로 받는다.

### 앱 (상대 경로 import 기준)

```mermaid
flowchart TD
  main[main.dart] --> appd[app.dart]
  main --> settings[core/config]
  appd --> router[shell/app_router, core/router는 다시 내보내기]
  appd --> listener[presentation/approval_listener]
  router --> screens[presentation 화면]
  router --> tabs[features/inbox · history]
  router --> me[features/me]
  router --> assistant[features/assistant]
  assistant --> intake[shell/request_intake]
  intake --> repo
  intake --> feed
  assistant --> speech[assistant/speech 포트 + 어댑터]
  speech --> plugins[speech_to_text · permission_handler]
  screens --> feed
  router --> settingsScreen[features/settings]
  router --> models[kolbi_core models]
  tabs --> feed[shell/task_feed · kind_registration]
  feed --> controller
  screens --> controller[application/calls_controller]
  screens --> models
  controller --> repo[data/calls_repository 공급자 + kolbi_core CallsRepository]
  controller --> live[kolbi_core LiveChannel]
  controller --> models
  repo --> api[kolbi_core ApiClient]
  repo --> live
  repo --> settings
  repo --> models
  settingsScreen --> api
  settingsScreen --> models
  widgetsCommon[kolbi_ui common] --> api
```

`structure.md`가 적은 대로 주 흐름은 `presentation → application → data → domain`이다. SPEC-MODULE-001 이후 앱 소스는 모델·네트워크·테마·공용 위젯을 `kolbi_core`·`kolbi_ui` 배럴로 가져온다(그래프의 패키지 노드). 예외는 다음과 같다.

- `presentation/home_screen.dart`가 `data/calls_repository.dart`를 직접 import한다(`LiveChannel`은 `kolbi_core` 배럴로).
- SPEC-SHELL-001 이후 라우터는 `shell/app_router.dart`에 있고, 셸이 `features/` 화면을 모아 등록한다. `core/router/app_router.dart`는 `routerProvider`를 다시 내보내는 파일로만 남았으며, `architecture_test.dart`가 이 파일 하나만 `core` 밖을 가리키도록 고정한다. 업무·기록·내 정보 기능은 `shell/`(공급자·이동 함수)을 가져오고, `shell/task_feed.dart`·`kind_registration.dart`가 `features/calls`를 가져온다.
- `packages/kolbi_ui/lib/src/widgets/common.dart`가 `kolbi_core` 배럴을 import한다(오류가 `ApiException`이면 `userMessage`를 보여 주기 위해서다, `common.dart:269`). 허용된 방향(`kolbi_ui → kolbi_core`)이다.
- 기능 간 의존은 없다. SPEC-ASSIST-001의 비서도 `features/calls`의 접수·템플릿을 직접 가져오지 않고 `shell/request_intake.dart`를 거친다(`shell/task_feed.dart`와 같은 방식). 마지막 1건(`settings_screen.dart` → `calls`의 `trust_notice.dart`)은 SPEC-SHELL-001이 신뢰 안내를 `core/widgets/trust_notice.dart`로 옮겨 풀었고(`settings_screen.dart:8`), `app/test/architecture_test.dart` 허용 목록은 비어 있다.

---

Generated by /moai project on 2026-11-20; based on repository state at commit c95953f. Updated by /moai sync on 2026-11-27 for SPEC-MODULE-001 (state at 6cdf8af). Updated by /moai sync on 2026-11-27 for SPEC-APPROVAL/INTAKE/FOLLOWUP-001 (state at 8ad8239). Updated by /moai sync on 2026-11-27 for SPEC-SHELL-001 (state at b67d452). Updated by /moai sync on 2026-11-28 for SPEC-ASSIST-001 (state at 477dac5).
