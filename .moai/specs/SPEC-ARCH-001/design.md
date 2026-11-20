# SPEC-ARCH-001 설계

이 문서는 `spec.md`의 요구사항을 만족하는 구조 결정을 정리한다. 이름과 형태는 run-phase RED 테스트를 쓰면서 확정하며, 여기의 시그니처는 인터페이스를 고정하기 위한 의사 구조다.

## 1. 제공자 중립 라우트 계약 (REQ-001 ~ REQ-006)

### 결정

`server/src/providers/types.ts`에 Fastify에 의존하지 않는 라우트 선언을 둔다. 제공자는 선언만 하고, HTTP 계층은 선언을 Fastify 라우트로 옮긴다.

의사 구조:

- `ProviderHttpRoute { method: "POST" | "GET"; path: string; rawBody: boolean; handle(req: { headers; rawBody?: string; body: unknown }): { status: number; body?: object } | Promise<…> }`
- `ProviderSocketRoute { path: string; attach(socket: WebSocket, req: IncomingMessage): void }`
- `CallProvider`에 선택 속성 `routes?: { http: ProviderHttpRoute[]; sockets: ProviderSocketRoute[] }` 또는 같은 내용을 돌려주는 메서드.

KAT 제공자의 `/kat/status` 핸들러는 지금 `app.ts:163-170`이 하는 일을 그대로 옮긴다: 서명 검증 실패 → `{ status: 401, body: { error: "invalid_signature" } }`, 성공 → 본문을 스키마로 해석해 처리 → `{ status: 204 }`.

HTTP 계층:

- `AppDeps`에서 `kat?: KatCallProvider`를 빼고 `providerRoutes?`(또는 `provider`의 라우트 목록)와 `providerInfo: { id; realCalls }`를 받는다.
- 원문 본문 캡처 훅은 `rawBody: true`로 선언된 라우트 경로 집합에 대해서만 동작한다(`/kat/` 접두어 하드코딩 제거).
- `/v1/config`의 `realCalls`는 `providerInfo.realCalls`.

### 대안과 기각 이유

| 대안 | 기각 이유 |
|------|-----------|
| 제공자가 Fastify 플러그인을 직접 등록 | 제공자 계층이 HTTP 프레임워크에 묶인다. 허브·SDK 방향에서 다른 전송 계층을 쓰게 되면 다시 분리해야 한다. |
| HTTP 계층에 제공자별 `switch` 유지 | 현재 문제 그 자체. 제공자를 추가할 때마다 HTTP를 고친다. |

### 되돌리기 쉬운 정도

중간. 계약 모양은 바꿀 수 있지만, 한 번 KAT 핸들러를 옮기면 테스트(AC-002~004)가 계약을 고정한다. plan-auditor·사용자 검토에서 가장 먼저 볼 결정이다.

## 2. 에이전트 지시문 주입 (REQ-008)

### 결정

`CallSession`에 지시문을 돌려주는 메서드(예: `agentInstructions(): string`)를 추가한다. `CallService.openSession`이 `brain/prompts.ts`의 `buildAgentInstructions(this.get(taskId))`로 만든다. 서비스 → brain 의존은 문서화된 계층에서 허용된다(`structure.md:56-61`). `realtimeBridge.ts`는 `session.agentInstructions()`를 `session.update`에 싣는다.

호출 시점: 지금은 브리지가 연결될 때 `session.task()` 스냅숏으로 한 번 만든다(`realtimeBridge.ts:61,142`). 같은 시점에 한 번 호출해 동작을 유지한다.

### 대안과 기각 이유

| 대안 | 기각 이유 |
|------|-----------|
| `CallBrain` 인터페이스에 지시문 생성 추가 | brain 구현마다 지시문을 따로 가질 이유가 없고, 지금도 `HeuristicBrain`/`OpenAiBrain`과 무관한 순수 함수다. 인터페이스만 넓어진다. |
| `RealtimeOptions`에 지시문 생성 함수를 넣어 `container.ts`에서 주입 | 동작은 하지만 작업별 값이 설정 객체를 통과하게 되어 의미가 흐려진다. 세션이 작업 단위 값을 나르는 곳이다. |

## 3. 시나리오 템플릿 위치 (REQ-007)

`server/src/brain/scenario.ts`는 `HeuristicBrain`(계획 템플릿)과 `SimulatedCallProvider`(각본의 상대 답변·승인 질문)가 함께 쓴다. 이 파일을 제공자와 brain 모두가 의존해도 되는 중립 위치로 옮긴다. 후보: `server/src/domain/scenario.ts`(순수 데이터·순수 함수라 도메인 규칙과 성격이 맞음).

- 파일 이동 + import 경로 수정뿐이며 내용은 바꾸지 않는다.
- `brain/scenario.ts`를 재수출 파일로 남기지 않는다(의존 규칙 검사가 다시 우회되므로).

이 항목은 오케스트레이터가 넘긴 근거 목록에 없던 것으로, 이 SPEC 작성 중 `grep`으로 찾았다(`research.md` §2). 범위에서 빼려면 REQ-007을 "`realtimeBridge.ts`만"으로 좁히고 AC-006의 검사 대상을 바꾼다.

## 4. 외부 입력 스키마와 실패 정책 (REQ-009 ~ REQ-013)

새 파일:

- `server/src/providers/kat/schemas.ts` — KAT API 응답(통화 생성, 오류 본문, `result` 감싼 형태), 상태 웹훅(`data.type`, `data.callId`, `data.status`, `data.metadata.taskId`), 미디어 프레임(`start`, `media`, `stop`).
- `server/src/providers/realtimeEvents.ts` — 처리 대상 Realtime 이벤트(유형별 스키마), 도구 인자 스키마.

공통 정책:

| 입력 | 형식 오류 시 | 로그 |
|------|-------------|------|
| KAT API 통화 생성 응답 | 기존 오류 문구로 실패 | 기존 경로 |
| KAT API 오류 응답 본문 | 문구 추출 대체값(원문 앞 200자 → 상태 텍스트) | 없음 |
| KAT 상태 웹훅 | 무시, 204 | warn 1건(유형·통화 ID가 읽히면 그것만) |
| 미디어 `start` | 무시, 계속 대기. 단, 헤더 통화 ID에 활성 세션이 없으면 해석 전에 종료(SPEC-LIFECYCLE-001 REQ-016, 이 SPEC REQ-011 예외) | warn 1건 |
| 미디어 `media`/`stop` | 무시 | 없음 |
| Realtime 처리 대상 이벤트 | 무시 | warn 1건(유형 이름만) |
| Realtime 기타 유형 | 무시 | 없음 |
| 도구 인자 | 기본 질문 사용(현행) | 현행 warn 유지 |

스키마는 알려진 필드만 검사하고 나머지 필드는 통과시킨다(외부 서비스가 필드를 추가해도 깨지지 않게). 현재 코드가 허용하는 형태(예: `customParameters`가 문자열 JSON 또는 객체, `streamSid` 위치 여러 곳)는 그대로 허용한다.

SPEC-LIFECYCLE-001이 `api()`에 시간 제한과 `fetch` 주입을 넣은 상태에서 시작하므로, 이 SPEC은 응답 해석 부분만 바꾼다.

## 5. 제공자 식별자 타입 (REQ-014, REQ-015)

`server/src/domain/types.ts`에 `ProviderId = string`(필요하면 읽기 좋게 브랜드 없이 별칭)을 두고 `CallTask.provider`, `CallProvider.name`에 쓴다. 알려진 값 상수(`"simulated"`, `"kat"`)는 각 제공자 파일에 둔다. `AppConfig.provider`(`config.ts:35`)는 설정이 실제로 고를 수 있는 값이므로 두 값 열거형을 유지한다.

앱은 이미 `json['provider'] == 'simulated'`만 본다(`call_models.dart:202`). 코드 변경 없이 테스트만 추가한다.

## 6. 테스트 주입 지점 (REQ-016 ~ REQ-021)

- `bridgeToRealtime`에 WebSocket 생성 함수 주입(기본값은 지금의 `new WebSocket(url, opts)`, `realtimeBridge.ts:251-257`). 가짜 소켓은 `EventEmitter` 기반으로 `send`, `close`, `readyState`, `open`/`message`/`close`/`error`/`unexpected-response` 이벤트를 흉내 낸다.
- KAT 미디어 테스트는 가짜 소켓 + `IncomingMessage` 흉내 객체(헤더만) + 서명 헬퍼(기존 `katProvider.test.ts`의 HMAC 계산 방식)로 만든다. 브리지 호출은 `KatOptions`의 브리지 주입 또는 브리지 생성 함수 주입으로 가로챈다(실제 OpenAI 연결 방지).
- `/v1/stream`은 `@fastify/websocket` 11.3.7의 `app.injectWS`를 쓴다(타입 정의에 `injectWS` 존재 확인 — `research.md` §6).

## 7. 변경 뒤 의존 그래프 (목표)

```
http/app.ts ──► services/callService.ts ──► brain/ (prompts, heuristic, openai)
     │                    │
     │                    ├──► providers/types.ts (계약)
     │                    └──► store/, events/
     └──► providers/types.ts (라우트 계약만)

providers/kat/**, providers/realtimeBridge.ts, providers/simulatedProvider.ts
     └──► providers/types.ts, domain/ (phone, scenario, types)

container.ts: 구체 클래스를 아는 유일한 곳 (현행 유지)
```
