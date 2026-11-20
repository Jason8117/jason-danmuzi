# SPEC-LIFECYCLE-001 인수 기준

## 공통 검증 명령

```bash
export PATH=/opt/homebrew/Cellar/node/23.7.0/bin:$PATH
S=/Users/jason/Documents/Jason-Danmuzi/Jason-Danmuzi/server
npm --prefix $S test -- src/shutdown.test.ts src/services/callService.test.ts src/providers/kat/katProvider.test.ts
npm --prefix $S test
npm --prefix $S run typecheck
```

앱(작업 디렉터리 `/Users/jason/Documents/Jason-Danmuzi/Jason-Danmuzi/app`):

```bash
flutter --suppress-analytics test test/unit_test.dart
flutter --suppress-analytics test
flutter --suppress-analytics analyze
```

기준선(오케스트레이터 측정, 서버는 plan-auditor 재측정): 서버 typecheck exit 0, 테스트 3개 파일 / 33개 통과. 앱 `flutter analyze` info 1건(`test/support/fakes.dart:53`), `flutter test` 12개 통과(재측정 안 됨). 이 SPEC은 SPEC-STORE-001 뒤에 구현되므로 서버 기준선에는 그 SPEC의 테스트가 더해진다.

규칙:
- 모든 테스트는 구현보다 먼저 작성해 현재 코드에서 실패(RED)하는 것을 확인한다.
- 실제 KAT·OpenAI 네트워크는 쓰지 않는다. 가짜 제공자, 주입 `fetch`, 가짜 앱·저장소·`exit`, 가짜 타이머(`vi.useFakeTimers` + `vi.advanceTimersByTimeAsync`)를 쓴다.
- **예외**: AC-010과 AC-011의 KAT 요청 시간 제한은 실제 타이머로 검증한다. 주입한 `requestTimeoutMs: 50`과 중단 신호를 받으면 `AbortError`로 거부하는 가짜 `fetch`를 쓰고, 각 테스트에 vitest 상한 `{ timeout: 2000 }`을 둔다.

## 인수 기준

### AC-001 — 종료 중 상태 (REQ-001)

- **Given** `awaiting_approval` 작업 1건과 `in_progress` 작업 1건이 있고 `beginShutdown()`을 호출한 `CallService`
- **When** (a) `create(...)`, (b) `approvePlan(awaitingId)`, (c) 진행 중 세션의 `requestApproval("…")`을 호출하면
- **Then** (a)(b)는 `ServiceError`(503, `shutting_down`, "서버가 종료 중입니다. 잠시 후 다시 시도해 주세요.")이고 작업이 새로 생기거나 `dialing`으로 바뀌지 않으며, (c)는 즉시 `{ approved: false, reason: "canceled" }`로 끝나고 작업의 `approvals`에 새 항목이 없다
- 테스트: `server/src/services/callService.test.ts` — "rejects new work and new approvals while shutting down"
- (d) 검사 순서(REQ-001 (d)): `beginShutdown()` 뒤에 (1) `in_progress` 작업의 `approvePlan`은 409가 아니라 503 `shutting_down`, (2) `maxConcurrentCalls`가 이미 가득 찬 상태에서 `awaiting_approval` 작업의 `approvePlan`도 429가 아니라 503 `shutting_down`이고, (3) 존재하지 않는 작업 ID의 `approvePlan`도 404가 아니라 503 `shutting_down`이다(순서 503 → 404 → 409 → 400 → 429). 400 번호 재검사의 위치는 SPEC-POLICY-001 AC-010 (3)이 고정한다 — 테스트: "approvePlan checks shutting_down before state and limits"
- RED: `beginShutdown`이 없다.

### AC-002 — 통화 종료는 `app.close()` 전에, `app.close()`가 끝나지 않아도 진행 (REQ-002, REQ-005)

- **Given** 호출 순서를 기록하는 가짜 `calls`(활성 통화 2건), `close()`가 **영원히 끝나지 않는** 가짜 앱, 성공하는 가짜 저장소, 가짜 `exit`, 가짜 타이머
- **When** 종료 모듈에 첫 신호를 주고 타이머를 4,000 ms 진행하면
- **Then** 기록된 순서가 `beginShutdown` → `terminateActiveCalls` → `app.close` → `finalFlush`이고, 가짜 제공자의 `hangup`이 2회 호출되었으며(0 ms 시점에 이미 호출됨), `finalFlush`는 `app.close` 호출 1,000 ms 뒤에 호출되고(`terminateActiveCalls`가 즉시 끝나는 가짜이므로 첫 신호 기준 1,000 ms 시점), `app.close` 1 s 초과 warn 로그가 1건 있다
- 테스트: `server/src/shutdown.test.ts` — "terminates calls before app.close and moves on when app.close hangs"
- RED: `shutdown.ts`가 없다. (참고: 현재 `index.ts:30-36`은 `app.close()`를 먼저 부르고 통화를 끊지 않는다.)

### AC-003 — 통화 종료 단계 마감 3 s (REQ-003)

- **Given** `hangup`이 끝나지 않는 가짜 제공자와 활성 통화 1건(`id: "t-1"`)을 가진 `CallService`
- **When** `terminateActiveCalls({ deadlineMs: 3000 })`를 호출하고 타이머를 3,000 ms 진행하면
- **Then** 호출이 반환되고, `"t-1"`이 담긴 warn 로그 1건이 남는다
- 테스트: `callService.test.ts` — "the termination step is bounded to its deadline"

### AC-004 — 종료로 끊은 통화의 최종 상태 (REQ-004)

- **Given** 대화 기록 2줄과 대기 승인 1건이 있는 `in_progress` 작업, 호출을 기록하는 가짜 brain
- **When** `terminateActiveCalls`가 끝나면(정상 종료와 3 s 마감 두 경우 모두)
- **Then** 작업 `status`는 `failed`, `error`는 "서버가 종료되어 통화를 끊었습니다.", `transcript` 길이 2 유지, 승인 `status`는 `expired`, `brain.summarize` 호출 0회, `task.updated` 이벤트 발행
- 테스트: `callService.test.ts` — "a call ended by shutdown is closed as failed without a summary" (`it.each`로 두 경우)

### AC-005 — 전체 순서·마감·종료 코드·두 번째 신호 (REQ-006, REQ-007)

`server/src/shutdown.test.ts`, 가짜 타이머:
- (a) 모든 가짜 의존성이 즉시 성공하면 순서가 `beginShutdown` → `terminateActiveCalls` → `app.close` → `finalFlush` → `exit(0)` — "runs the steps in order"
- (b) `terminateActiveCalls`, `app.close`, `finalFlush`가 모두 끝나지 않으면(최종 저장 가짜는 자체 5 s 마감을 흉내 내 5,000 ms 뒤 실패 결과) `exit`가 9,000 ms 시점에 정확히 1회 호출되고 9,500 ms 이내다 — "finishes within 9 s + 500 ms when every step hangs"
- (c) 최종 저장이 실패 결과를 돌려주면 `exit(1)`과 `"Final store flush failed"` error 로그 1건, 성공이면 `exit(0)`이고 그 로그 0건 — "maps the final flush result to the exit code"
- (d) 첫 신호 뒤 1,000 ms에 두 번째 신호를 주면 그 즉시 `exit(1)`이 호출되고 남은 단계는 기다리지 않는다 — "a second signal exits immediately"
- (e) `terminateActiveCalls`와 `app.close`는 즉시 끝나지만 `finalFlush`가 **영원히 끝나지 않으면**(자체 마감을 지키지 않는 가짜), 종료 모듈의 단계 3 예산(5,000 ms)이 끝나는 시점에 `"Final store flush failed"` error 로그가 정확히 1건 남고 `exit(1)`이 정확히 1회 호출된다. 모든 단계가 끝나지 않는 경우(앞 단계도 예산을 다 쓰는 경우)에도 같은 결과가 9,000 ms 시점에 나온다 — "treats a hanging final flush as a failure and exits 1 within the budget"
- RED: `shutdown.ts`가 없다.

### AC-006 — 외부 통화 ID 저장 (REQ-008)

- **Given** `start`에서 통화 ID `"c-1"`을 보고하는 가짜 제공자, 그리고 `{ result: { callId: "c-1" } }`를 돌려주는 주입 `fetch`를 쓴 `KatCallProvider`(가짜 세션)
- **When** 계획 승인으로 통화를 시작하면
- **Then** 작업의 `providerCallId`가 `"c-1"`이고 이를 담은 `task.updated` 이벤트가 발행된다. `KatCallProvider`는 세션에 `"c-1"`을 정확히 1회 보고한다
- 테스트: `callService.test.ts` — "stores the provider call id on the task"; `katProvider.test.ts` — "reports the KAT callId to the session"

### AC-007 — 재기동 복구가 살아 있는 실통화를 끊는다 (REQ-009)

- **Given** 저장소에 `in_progress`, `provider: "kat"`, `providerCallId: "c-2"`인 작업이 있고, 활성 제공자 이름이 `kat`이며 통화 ID 기반 종료를 기록하는 가짜 제공자
- **When** 복구를 실행하면
- **Then** (a) 종료가 `"c-2"`로 1회 호출된 뒤 작업이 `failed`가 된다(호출 순서 기록으로 확인). (b) 종료가 거부되는 경우에도 작업은 `failed`이고 warn 로그 1건, 복구 함수는 정상 반환된다. (c) 종료가 끝나지 않는 경우 가짜 타이머 10,000 ms 진행 뒤 복구 함수가 반환되고 작업은 `failed`다
- 테스트: `callService.test.ts` — "recovery terminates a still-running provider call" (`it.each`로 a/b/c)
- RED: 현재 `recoverInterruptedTasks`는 제공자를 호출하지 않는다.

### AC-008 — 통화 ID 없음·제공자 불일치 (REQ-010)

- **Given** (a) `providerCallId`가 없는 `in_progress` 작업, (b) `provider: "kat"`이지만 활성 제공자가 `simulated`인 작업. 비교용으로 (c) `summarizing`·`planning` 작업, (d) `awaiting_approval` 작업
- **When** 복구를 실행하면
- **Then** 종료 요청은 0회이고, (a)(b)는 `failed` + 각각 원인을 담은 warn 로그 1건, (c)는 `failed`(현행), (d)는 그대로(현행)
- 테스트: `callService.test.ts` — "recovery without a call id or with a different provider only marks the task failed"

### AC-009 — 하위 호환 (REQ-011)

- **Given** `providerCallId`가 없는 기존 형식의 작업 JSON과 있는 JSON
- **When** 서버 저장소로 읽고, 앱 `CallTask.fromJson`으로 파싱하면
- **Then** 서버는 두 형식을 모두 적재하고(AC-008 (a)가 필드 없는 작업으로 함께 검증), 앱은 두 JSON에서 `id`, `status`, `isSimulated`, `transcript` 길이가 같은 값으로 파싱된다
- 테스트: `app/test/unit_test.dart` — "ignores providerCallId when parsing tasks" (보호 테스트: 앱 모델을 바꾸지 않는다는 계약 고정)

### AC-010 — 모든 KAT 요청에 시간 제한 (REQ-012)

- **Given** 받은 `signal`을 기록하고, 그 신호가 중단되면 `AbortError`로 거부하며, 그 전에는 끝나지 않는 주입 `fetch`. `requestTimeoutMs: 50`인 `KatCallProvider`(실제 타이머, 테스트 상한 2,000 ms)
- **When** 통화 생성 요청과 종료 요청을 각각 보내면
- **Then** 두 요청 모두 `fetch`에 `signal`이 전달되고, 각 요청은 50 ms 뒤 중단되어 시작부터 550 ms 이내에 끝난다
- 테스트: `katProvider.test.ts` — "every KAT request carries an abort signal and times out"
- RED: 현재 `api()`는 `signal`을 넘기지 않아 요청이 끝나지 않고, 테스트는 vitest 상한으로 실패한다.

### AC-011 — 통화 생성 시간 초과 시 빠른 실패 (REQ-013)

- **Given** AC-010의 주입 방식(`requestTimeoutMs: 50`, 실제 타이머)을 쓴 `KatCallProvider`, `summarize`가 즉시 반환하는 가짜 brain(또는 `HeuristicBrain`)을 쓴 `maxConcurrentCalls: 1`인 `CallService`, `awaiting_approval` 작업 A와 B. (b)의 `failed`는 `endSession` → `summarizing` → `brain.summarize` 뒤에 정해지므로, 즉시 반환하는 brain을 써야 판정 시점이 (a)의 550 ms 안에 들어온다
- **When** 작업 A의 `approvePlan`을 호출하면
- **Then** (a) `approvePlan`이 호출부터 550 ms(=50 ms + 500 ms) 이내에 반환되고, (b) 작업 A가 `failed`가 되며 `error`에 "KAT Cloud가 응답하지 않아"가 포함되고, (c) 이어서 작업 B의 `approvePlan`이 `too_many_active_calls`(429)로 거부되지 않는다
- 테스트: `callService.test.ts` — "a hung provider start fails the task promptly and frees the slot"; `katProvider.test.ts` — "maps a KAT timeout to a readable Korean error"

### AC-012 — 종료 요청 실패는 예외가 되지 않는다 (REQ-014)

- **Given** 통화 ID가 확보된 활성 통화와, 종료 요청에서 (1) 시간 초과(AC-010 방식) (2) 500 응답을 내는 주입 `fetch`
- **When** `hangup(taskId)`를 호출하면
- **Then** 두 경우 모두 Promise가 이행되고 warn 로그 1건이 남는다
- 테스트: `katProvider.test.ts` — "hangup never throws on timeout or error"
- RED: 500은 현재도 잡히지만 시간 초과는 끝나지 않는다.

### AC-013 — timeLimit이 설정을 따른다 (REQ-015, OD-3 DEFAULT)

- (a) **Given** `maxCallDurationSec`가 600, 5, 1, 20,000인 `KatCallProvider` 각각과 요청 본문을 기록하는 주입 `fetch` / **When** 통화를 생성하면 / **Then** 요청 본문 `timeLimit`이 각각 630, 35, 31, 14,400이다(`clamp(설정 + 30, 10, 14_400)`). 테스트: `katProvider.test.ts` — "derives timeLimit from MAX_CALL_DURATION_SEC" (`it.each`). RED: 현재는 언제나 900.
- (b) 하한 방어 코드: 설정(`config.ts:30`, 1 이상의 정수)으로는 하한 10에 닿지 않으므로, 생성자에 `maxCallDurationSec: -25`를 **직접 주입**한 `KatCallProvider`로 통화를 생성하면 `timeLimit`이 10이다. 테스트: "clamps an injected duration below the floor to 10" (별도 테스트). RED: 현재는 900.

### AC-014 — 주인 없는 미디어 스트림 (REQ-016)

`katProvider.test.ts` — "terminates signed media streams that have no active session", 가짜 소켓, 유효·무효 서명 헤더, 종료 요청을 기록하는 주입 `fetch`, 활성 세션 없음:
- (a) 유효 서명 + `x-kat-call-id: c-9` + 첫 프레임으로 **JSON이 아닌 문자열**을 보냄 → 종료 API(`…/media-stream/calls/c-9/termination`) 1회, 소켓 닫힘. 프레임을 해석하기 전에 판정한다는 것을 이 입력으로 확인한다
- (b) 유효 서명 + `x-kat-call-id: c-9` + 프레임 없이 가짜 타이머 10,000 ms 진행 → 종료 API 1회, 소켓 닫힘
- (c) 유효 서명 + 헤더 통화 ID 없음 + 유효한 `start` 프레임(`start.callId: "c-8"`) → 종료 API(`…/calls/c-8/termination`) 1회, 소켓 닫힘
- (d) 무효 서명 + `x-kat-call-id: c-9` → 종료 API 0회, 소켓 닫힘
- RED: 현재는 활성 세션이 없으면 소켓만 닫는다(`katProvider.ts:257-274`, `:217`).

### AC-015 — 프로세스 단위 종료 확인 (REQ-001, REQ-004, REQ-006, 수동 검증)

시뮬레이션 모드에서 통화 중 종료 신호를 보낸다.

```bash
export PATH=/opt/homebrew/Cellar/node/23.7.0/bin:$PATH
D=$(mktemp -d); cd /Users/jason/Documents/Jason-Danmuzi/Jason-Danmuzi/server
DATA_FILE=$D/tasks.json PORT=18788 SIMULATION_SPEED=0.2 ./node_modules/.bin/tsx src/index.ts > $D/log.txt 2>&1 &
PID=$!; sleep 2
ID=$(curl -s -X POST localhost:18788/v1/tasks -H 'content-type: application/json' \
  -d '{"targetName":"x","phoneNumber":"010-1234-5678","goal":"영업시간 문의","requesterName":"김"}' \
  | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).id))')
sleep 1; curl -s -o /dev/null -w 'approve=%{http_code}\n' -X POST localhost:18788/v1/tasks/$ID/approve-plan -H 'content-type: application/json' -d '{}'
sleep 3; START=$(date +%s); kill -TERM $PID; wait $PID; echo "exit=$? elapsed=$(( $(date +%s) - START ))s"
grep -o '"status": *"[a-z_]*"' $D/tasks.json | head -1
node -e 'const t=require(process.argv[1])[0];console.log(t.status, "|", t.error)' $D/tasks.json
```

- GREEN: `approve=200`, `exit=0`, `elapsed`가 10 s 미만, grep 출력 `"status": "failed"`, node 출력 `failed | 서버가 종료되어 통화를 끊었습니다.`
- RED(현재 코드, plan-auditor가 관찰): `exit=0`, grep 출력 `"status": "dialing"`(공백 허용 grep 기준). 콜론 뒤 공백 없이 쓴 grep(`'"status":"…"'`)은 파일이 `JSON.stringify(…, null, 2)`로 쓰여 아무것도 찾지 못하므로 쓰지 않는다.

### AC-016 — 회귀 없음

- 서버 `npm test` 전체 통과(기존 테스트 수정 없음), `npm run typecheck` exit 0.
- 앱 `flutter test` 전체 통과, `flutter analyze` 결과가 기준선보다 늘지 않음.
- 시뮬레이션 모드에서 계획 → 승인 → 통화 → 중간 승인 → 요약 흐름이 그대로 동작(`server/src/http/app.test.ts`의 "plans, calls, pauses for approval and summarizes" 통과).

## 엣지 케이스

- 종료 중 이미 `ending` 상태인 세션: `hangup`을 중복 호출해도 안전해야 한다(`CallProvider.hangup` 계약).
- 복구 대상이 수십 건: 종료 요청은 병렬, 전체 10 s 하나로 제한.
- 종료 단계 1 도중 KAT 상태 웹훅이 도착: 세션이 이미 정리되어 무시된다.

## 잔여 위험

- 통화 생성 응답 전에 서버가 죽거나 종료되면 통화 ID를 저장하지 못한다. 서버가 계속 떠 있으면 REQ-016이 미디어 스트림 시점에 막고, 서버가 사라졌으면 KAT `timeLimit`만 남는다.
- KAT `timeLimit`은 설정을 따라 커진다(OD-3 DEFAULT). KAT가 이 값을 생성 시점부터 세는지 응답 시점부터 세는지는 확인되지 않았다. `MAX_CALL_DURATION_SEC`가 14,371 이상이면 여유가 30 s보다 줄어들고, 14,401 이상이면 KAT 상한 14,400 s가 서버 타이머보다 먼저 끊어 서버 타이머 경로를 타지 않는다.
- 데이터 파일이 손상되었거나 읽을 수 없으면 기동이 실패하므로(SPEC-STORE-001 OD-1 RESOLVED) 복구가 실행되지 않고, 그 안의 진행 중 작업은 복구되지 않으며 그 실통화도 서버가 끊을 수 없다.
- 같은 `DATA_FILE`을 쓰는 두 인스턴스가 함께 떠 있으면 새 인스턴스가 기존 인스턴스의 정상 통화를 끊는다(단일 인스턴스 가정).
- 플랫폼 종료 유예가 10 s보다 짧으면 최종 저장 전에 강제 종료될 수 있다.
- 실제 KAT의 종료 API 동작(이미 끝난 통화에 대한 응답 등)은 이 환경에서 검증할 수 없다.

## 완료 정의 (Definition of Done)

- AC-001 ~ AC-016 충족. AC-015 절차의 출력 원문을 `progress.md` §E.2에 기록.
- plan.md §G의 운영 안내가 sync-phase 문서에 들어감.
