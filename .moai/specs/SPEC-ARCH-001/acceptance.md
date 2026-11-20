# SPEC-ARCH-001 인수 기준

## 공통 검증 명령

```bash
export PATH=/opt/homebrew/Cellar/node/23.7.0/bin:$PATH
S=/Users/jason/Documents/Jason-Danmuzi/Jason-Danmuzi/server
npm --prefix $S test -- src/architecture.test.ts src/http/app.test.ts src/providers/realtimeBridge.test.ts src/providers/kat/katProvider.test.ts src/brain/openaiBrain.test.ts
npm --prefix $S test
npm --prefix $S run typecheck
```

앱(작업 디렉터리 `/Users/jason/Documents/Jason-Danmuzi/Jason-Danmuzi/app`):

```bash
flutter --suppress-analytics test test/unit_test.dart
flutter --suppress-analytics test
flutter --suppress-analytics analyze
```

기준선(오케스트레이터 측정): 서버 typecheck exit 0, 3개 파일 / 33개 테스트. 앱 analyze info 1건(`test/support/fakes.dart:53`), 테스트 12개. 이 SPEC은 마지막에 구현되므로 앞선 네 SPEC의 테스트가 더해진 상태가 실제 기준선이다.

규칙: 구조 변경 대상은 보호 테스트(현재 동작 고정)를 먼저 통과시키고, 새 동작(형식 오류 무시·로그, 라우트 계약, 의존 규칙)은 실패하는 테스트로 시작한다. 실제 KAT·OpenAI 네트워크는 쓰지 않는다.

## 인수 기준

### AC-001 — HTTP 계층이 구체 제공자를 모른다 (REQ-001)

- 테스트: `server/src/architecture.test.ts` — "http layer does not know concrete providers": `src/http/app.ts` 원문에서 `providers/kat`, `KatCallProvider`, `simulatedProvider`, `realtimeBridge`, `"/kat/"`, `=== "kat"`가 0건
- 보조 명령: `grep -cE 'providers/kat|KatCallProvider|"/kat/"|=== "kat"' $S/src/http/app.ts` → `0`
- RED: 이 세션 측정값 `4`(`app.ts:12`, `:20`, `:70`, `:110`).

### AC-002 — 선언한 라우트가 등록되고 원문 본문을 받는다 (REQ-002, REQ-004, REQ-021)

- **Given** `POST /fake/hook`(`rawBody: true`)을 선언하고 받은 원문을 기록하는 가짜 제공자
- **When** `buildApp`으로 앱을 만들고 `{"a": 1,  "b":2}`(공백 포함 원문)를 보내면
- **Then** 응답이 가짜 핸들러가 정한 상태 코드이고, 핸들러가 받은 원문이 보낸 바이트와 같다. 원문 본문을 선언하지 않은 라우트에는 원문이 전달되지 않는다
- 테스트: `server/src/http/app.test.ts` — "registers provider-declared routes with raw bodies"
- RED: 현재 `AppDeps`에 라우트 입력이 없다.

### AC-003 — 라우트가 없는 제공자 (REQ-003, REQ-021)

- **Given** 시뮬레이션 제공자 구성(기존 `app.test.ts` 구성)
- **When** `POST /kat/status`, `GET /kat/media`를 요청하면
- **Then** 둘 다 404다
- 테스트: "registers no provider routes in simulation mode" (보호 테스트 — 현재도 통과해야 함)

### AC-004 — KAT 라우트 외부 동작 불변 (REQ-004, REQ-005)

- **Given** 테스트용 비밀키로 만든 KAT 제공자(네트워크 없음, `fetch` 주입)와 그 라우트로 만든 앱
- **When** (1) 서명 없는 `POST /kat/status`, (2) 서명이 맞는 `POST /kat/status`, (3) API 토큰 없이 `POST /kat/status`(유효 서명)를 보내면
- **Then** (1) 401 `{"error":"invalid_signature"}`, (2) 204, (3) 204(제공자 라우트에는 `/v1/*` 토큰 검사가 적용되지 않음)
- 테스트: `app.test.ts` — "keeps the KAT webhook contract"
- 순서: 구조 변경 전에 작성해 현재 코드에서 통과시킨 뒤(보호), 변경 뒤에도 통과해야 한다.

### AC-005 — `/v1/config` 불변 (REQ-006)

- **Given** 시뮬레이션 구성과 `realCalls: true`를 넘긴 구성
- **When** `GET /v1/config`
- **Then** 각각 `{"provider":"simulated","brain":"heuristic","realCalls":false}`, `{"provider":"kat",…,"realCalls":true}`이며 `app.ts`에 제공자 이름 비교가 없다(AC-001)
- 테스트: "serves /v1/config from wiring-provided provider info"

### AC-006 — 제공자는 brain을 가져오지 않는다 (REQ-007)

- 테스트: `architecture.test.ts` — "providers do not import brain": `src/providers/**/*.ts`(테스트 파일 제외)에서 `from "../brain/` 또는 `from "../../brain/"` 0건, `src/brain/scenario.ts`가 존재하지 않음(재수출 우회 방지)
- 보조 명령: `grep -rn 'from "\.\./brain\|from "\.\./\.\./brain' $S/src/providers` → 출력 없음
- RED: 현재 `realtimeBridge.ts:2`, `simulatedProvider.ts:2` 두 건(이 세션에서 grep으로 확인).

### AC-007 — 지시문은 세션으로 주입되고 내용이 같다 (REQ-008)

- **Given** 계획이 있는 작업과 그 작업의 세션, 가짜 WebSocket으로 연결한 브리지
- **When** AI 소켓이 `open`되면
- **Then** 첫 `session.update` 메시지의 `session.instructions`가 `buildAgentInstructions(task)`와 글자 단위로 같고, 그 값이 `session.agentInstructions()`(또는 확정된 이름)에서 왔다(가짜 세션이 반환한 고유 문자열로 확인)
- 테스트: `server/src/providers/realtimeBridge.test.ts` — "sends session-provided instructions"; `callService.test.ts` — "session exposes the agent instructions for its task"

### AC-008 — KAT API 응답 해석 (REQ-009)

- **Given** 주입 `fetch`가 (1) `{"callId":"c-1"}`, (2) `{"code":0,"result":{"callId":"c-2"}}`, (3) `{"result":{}}`, (4) `"not json"`(200), (5) 500 + `{"message":"boom"}`, (6) 500 + `[1,2]`
- **When** 통화를 생성하면
- **Then** (1)(2)는 각각 `c-1`, `c-2` 확보, (3)(4)는 "KAT Cloud did not return a callId" 오류, (5)는 `boom`이 담긴 오류, (6)은 예외 없이 원문 앞부분이 담긴 오류
- 테스트: `katProvider.test.ts` — "parses KAT API responses safely" (`it.each`)

### AC-009 — 형식 오류 상태 웹훅은 무시 (REQ-010)

- **Given** 활성 세션이 있는 KAT 제공자와 가짜 로거
- **When** `{ data: { type: 123 } }`, `{ data: "x" }`, `[]` 본문을 처리하면
- **Then** 세션 메서드 호출 0회, warn 로그 각 1건(본문 원문 미포함), 라우트 응답 204
- 테스트: `katProvider.test.ts` — "ignores malformed status webhooks"; `app.test.ts`의 AC-004 구성으로 204 확인
- RED: 현재는 로그 없이 지나간다.

### AC-010 — 형식 오류 미디어 프레임 (REQ-011)

- **Given** 서명이 유효하고 헤더 통화 ID가 활성 세션에 연결된 미디어 연결
- **When** (1) `start.customParameters`가 숫자인 `start` 프레임, 이어서 (2) 정상 `start` 프레임을 보내면
- **Then** (1)은 무시되고 warn 1건, (2)에서 정상적으로 연결 처리된다. 별도로 JSON이 아닌 프레임과 `payload` 없는 `media` 프레임은 로그 없이 무시된다
- 예외 확인(REQ-011, SPEC-LIFECYCLE-001 REQ-016): 서명은 유효하지만 헤더 통화 ID에 활성 세션이 **없는** 연결에서는 같은 형식 오류 `start` 프레임 (1)이 무시되지 않고, 프레임 검증보다 먼저 종료 API 1회 호출 + 소켓 닫힘이 일어난다. 프레임이 오지 않으면 10,000 ms 시점에 같은 결과다. 이 동작은 SPEC-LIFECYCLE-001 AC-014가 만든 테스트이며, 이 SPEC의 zod 적용 뒤에도 수정 없이 통과해야 한다
- 테스트: "ignores malformed media frames and keeps waiting for start"; 예외는 `katProvider.test.ts`의 "terminates signed media streams that have no active session"(SPEC-LIFECYCLE-001) 재실행

### AC-011 — Realtime 이벤트 검증 (REQ-012)

- **Given** 가짜 AI 소켓으로 연결한 브리지와 가짜 로거
- **When** (1) `delta` 없는 `response.output_audio.delta`, (2) `transcript`가 숫자인 전사 완료 이벤트, (3) `name` 없는 함수 호출 완료 이벤트, (4) `type: "session.created"`(처리 대상 아님), (5) `question`이 없는 `request_user_approval` 인자를 보내면
- **Then** (1)~(3)은 미디어 전송·대화 기록·도구 처리가 일어나지 않고 각각 warn 1건, (4)는 로그 없음, (5)는 기본 질문 "진행해도 될까요?"로 승인 요청
- 테스트: `realtimeBridge.test.ts` — "validates handled realtime events and ignores the rest"
- RED: 현재 (1)은 `payload: undefined`인 미디어 프레임을 보내고, (2)는 `"123"`을 대화 기록에 넣는다.

### AC-012 — `any` 제거 (REQ-013)

- 테스트: `architecture.test.ts` — "no any for external data": `src/providers/kat/katProvider.ts`, `src/providers/realtimeBridge.ts`에서 정규식 `Record<string, any>|:\s*any\b|as any\b` 일치 0건
- 보조 명령: `grep -cE 'Record<string, any>|: any\b|as any\b' $S/src/providers/kat/katProvider.ts $S/src/providers/realtimeBridge.ts`
- RED: 이 세션 측정값 각각 `4`, `2`.

### AC-013 — 제공자 식별자 타입 확장 (REQ-014)

- **RED 기준(이 기준의 실패 신호)**: 아래 명령. 현재 출력은 2줄(`src/domain/types.ts:83`, `src/providers/types.ts:30` — plan-auditor와 manager-spec이 각각 실행해 확인). GREEN은 출력 없음.

```bash
grep -n 'provider: "simulated" | "kat"\|name: "simulated" | "kat"' $S/src/domain/types.ts $S/src/providers/types.ts
```

- 추가 확인: `npm run typecheck` exit 0(프로덕션 코드에서 `CallProvider.name`, `CallTask.provider`가 `ProviderId`를 쓰고, 시뮬레이션·KAT 제공자의 이름 상수가 대입 가능).
- 보조 테스트: `callService.test.ts` — "accepts any provider id"(이름이 `"fake"`인 가짜 제공자로 만든 작업의 `provider`가 `"fake"`이고, 기존 `"simulated"`, `"kat"` 값을 가진 저장 작업이 그대로 적재됨). 이 테스트는 vitest가 타입을 지우고 `tsconfig.json`이 테스트 파일을 제외하므로 **현재 코드에서도 통과한다**. 실행 시 동작을 고정하는 보호 테스트이며 RED 근거가 아니다.

### AC-014 — 앱은 모르는 제공자를 견딘다 (REQ-015)

- **Given** `provider: "telco_x"`인 작업 JSON
- **When** `CallTask.fromJson`
- **Then** 예외 없이 파싱되고 `isSimulated == false`
- 테스트: `app/test/unit_test.dart` — "treats unknown providers as real calls" (보호 테스트, OD-1 DEFAULT)

### AC-015 — 브리지 동작 고정 (REQ-016)

`realtimeBridge.test.ts`(가짜 WebSocket, 가짜 타이머)에서 각 항목이 별도 테스트로 통과. 주입 지점 추가 직후 작성해 현재 동작에서 통과해야 한다(보호).
- (a) AI `open` → `session.update`(음성 형식 `audio/pcmu`, 도구 2개) + `response.create`
- (b) KAT `media` 프레임 → AI `input_audio_buffer.append`; AI 음성 조각 → KAT `media` 프레임(같은 `streamSid`)
- (c) `input_audio_buffer.speech_started` → KAT `clear`
- (d) 상대 전사 완료 → `appendTranscript("callee", …)`, 에이전트 전사 완료 → `appendTranscript("agent", …)`
- (e) `request_user_approval` → `session.requestApproval(question)` → `function_call_output`(승인 여부·사유·의견·지시문) + `response.create`
- (f) `end_call` → 2,500 ms 뒤 `hangup` 1회(2,499 ms 시점에는 0회)
- (g) `error`(메시지에 `billing`) → 시스템 기록 + `session.end({error})` + `hangup`
- (h) 첫 연결 거절(`unexpected-response`) → 재연결 1회(가짜 WebSocket 생성 2회째). 두 번째 거절 → 실패 처리(`session.end({error})` + `hangup`), WebSocket 생성은 총 2회로 끝남. 거절마다 `"Realtime handshake rejected"` warn 로그에 상태 코드와 응답 본문 앞 400자가 지금처럼 담긴다(spec.md §4 예외). 근거: `REALTIME_CONNECT_RETRIES = 2`(`realtimeBridge.ts:45`)이고 `connectAi`가 시도 전에 `connectAttempt`를 1로 올리므로 `connectAttempt < 2`는 첫 거절에서만 참이다
- (i) KAT `stop` → AI 소켓 닫기

### AC-016 — 상태 웹훅 동작 고정 (REQ-017)

`katProvider.test.ts`(가짜 세션)에서 각 항목이 별도 테스트로 통과(보호):
- (a) `media_stream.call.ringing` → `markRinging` 1회
- (b) `media_stream.call.answered` 또는 `status: "in-progress"` → `markConnected` 1회
- (c) 음성 미연결 상태 `media_stream.call.completed` → `end({error})`(미디어 연결 실패 문구)
- (d) 음성 연결 뒤 `completed` + `status: "completed"` → `end()` 오류 없음
- (e) `busy`, `no-answer`, `rejected`, `canceled`, `failed` → 각 `FAILURE_MESSAGES` 문구
- (f) 메타데이터·통화 ID 모두 모르는 작업 → 세션 호출 0회

### AC-017 — 미디어 스트림 동작 고정 (REQ-018)

`katProvider.test.ts`(가짜 소켓, 서명 헬퍼, 브리지 주입)에서 각 항목이 별도 테스트로 통과(보호):
- (a) 서명 무효 → 소켓 닫힘, 브리지 호출 0회
- (b) 정상 `start`(통화 ID 일치) → `markConnected`, 브리지 1회 호출(올바른 `streamSid`)
- (c) 통화 ID 없이 토큰 불일치 → 소켓 닫힘, `end({error})`, 종료 요청 1회
- (d) 활성 세션이 있는 연결에서 `start` 없이 10,000 ms 경과 → 소켓 닫힘(활성 세션이 없는 경우는 SPEC-LIFECYCLE-001 AC-014 (b)가 다룸)

### AC-018 — 계획 LLM 경로 (REQ-019)

- **Given** 가짜 `fetch`가 (1) 정상 계획, (2) `steps` 9개, (3) `approvalPoints` 6개, (4) `openingLine` 빈 문자열
- **When** `OpenAiBrain.createPlan`
- **Then** (1)은 응답 계획 그대로, (2)~(4)는 휴리스틱 계획 + warn 1건(`op: "plan"`, `reason: "schema_mismatch"` — SPEC-OUTCOME-001 형식)
- 테스트: `openaiBrain.test.ts` — "validates LLM plans against schema bounds"

### AC-019 — `/v1/stream` (REQ-020)

- **Given** 기존 `app.test.ts` 구성(토큰 `test-token`)
- **When** (1) `Authorization: Bearer test-token`으로 `injectWS("/v1/stream")`, (2) `?token=test-token`, (3) 토큰 없음
- **Then** (a) (1)의 첫 메시지가 `{"type":"snapshot","tasks":[…]}`, (b) 이어서 작업을 만들면 `{"type":"task.updated","task":{…}}` 수신, (c) (2)도 (a)와 같은 첫 메시지를 받음, (d) (3)은 401로 거부
- 테스트: `app.test.ts` — "streams snapshots and task updates", "rejects stream connections without a token"

### AC-020 — 회귀 없음 (REQ-022)

- 서버: 기존 테스트 파일의 기존 테스트가 수정 없이 통과(앞선 SPEC들이 의도적으로 바꾼 기대값은 그 결과 기준), `npm test` 전체 통과, `npm run typecheck` exit 0.
- 앱: `flutter test` 전체 통과, `flutter analyze` 결과가 기준선보다 늘지 않음.
- 전송 형식: `app.test.ts`의 기존 흐름 테스트가 같은 응답 필드를 받는다. `/v1/stream` 이벤트 유형은 `snapshot`, `task.updated`, `task.deleted` 셋뿐이다: `git -C /Users/jason/Documents/Jason-Danmuzi/Jason-Danmuzi diff --stat <run_start_sha>..HEAD -- server/src/events/` 출력이 비어 있다. `<run_start_sha>`는 run 진입 시 `progress.md` §E.2 첫 줄에 기록한 HEAD다.

## 엣지 케이스

- 원문 본문 라우트 경로에 쿼리 문자열이 붙은 경우(`/kat/status?x=1`)에도 원문이 캡처된다.
- 제공자 라우트 경로가 `/v1/`로 시작하도록 선언되면 거부한다(인증 훅 우회 방지). 테스트 1건 추가 권장.
- 두 제공자가 같은 경로를 선언하는 경우는 지금 구성에서 일어나지 않는다(활성 제공자 하나). 등록 시 Fastify가 중복을 거부한다.

## 잔여 위험

- 실제 KAT·OpenAI가 보내는 페이로드 변형은 이 환경에서 확인할 수 없다. 스키마는 현재 코드가 허용하는 형태를 기준으로 하며, 실서비스에서 처음 보는 형태가 오면 무시·로그된다(통화가 끊길 수 있음). 실통화 시험 전 로그 모니터링을 권고.
- 테스트 파일은 타입 검사를 받지 않는다(`tsconfig.json` 제외 설정). 별도 작업으로 다룰 것을 권고.

## 완료 정의 (Definition of Done)

- AC-001 ~ AC-020 충족. 보호 테스트 통과 원문과 새 동작 RED/GREEN 원문을 `progress.md` §E.2에 기록.
- OD-1, OD-2 기본값이 소유자 검토 대기 중임을 sync-phase 문서에 기록.
- `.moai/project/structure.md`의 계층 설명과 KAT 라우트 설명(`:71`)을 sync-phase에서 갱신하도록 메모.
