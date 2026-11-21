# SPEC-LIFECYCLE-001 진행 기록

## §E.1 Plan-phase Audit-Ready Signal

- plan_status: revised after plan-audit iteration 2 (FAIL 0.88) — re-audit pending
- plan_complete_at: 2026-11-21
- artifacts: spec.md, plan.md, acceptance.md, research.md
- counts: 16 REQ / 16 AC
- depends_on: SPEC-STORE-001
- open_decisions: OD-1 RESOLVED (owner); OD-2, OD-3 DEFAULT (pending owner review)
- run-entry note: manager-develop records `run_start_sha` (HEAD at run entry) as the first line of §E.2

## §E.2 Run-phase Evidence

run_start_sha: f17a1880b334a5d24c554f67de8ee763fdd512c8

- 실행 위치: L1 worktree `.claude/worktrees/agent-a2f3302bb2cbff307` (브랜치 `worktree-agent-a2f3302bb2cbff307`, `git merge --ff-only f17a188` 후 시작)
- cycle_type: tdd, harness: thorough
- 증거 파일: `.moai/state/verify/run-lifecycle/lifecycle/` (worktree 내부)

### 기준선 (코드 변경 전, 이 트리, HEAD f17a188)

```
$ npm --prefix server test
 Test Files  4 passed (4)
      Tests  46 passed (46)
$ npm --prefix server run typecheck   → exit 0
$ (app) flutter --suppress-analytics test   → exit 0, "00:01 +12: All tests passed!"
$ (app) flutter --suppress-analytics analyze → exit 1, "info • Use the null-aware marker '?' … • test/support/fakes.dart:53:5 • use_null_aware_elements" / "1 issue found."
```

### 마일스톤 기록

_(마일스톤마다 아래에 RED/GREEN 원문을 추가한다)_

#### M1 — 데이터 모델과 통화 ID 저장 (AC-006, AC-009)

RED (`npm --prefix server test -- src/services/callService.test.ts src/providers/kat/katProvider.test.ts`, exit 1):

```
     × stores the provider call id on the task 6ms
     × reports the KAT callId to the session 56ms
 FAIL  src/services/callService.test.ts > CallService provider call id (AC-006) > stores the provider call id on the task
AssertionError: expected undefined to be 'c-1' // Object.is equality
 FAIL  src/providers/kat/katProvider.test.ts > KatCallProvider call id (AC-006) > reports the KAT callId to the session
TypeError: fetch failed
Caused by: Error: getaddrinfo ENOTFOUND kat.test
      Tests  2 failed | 5 passed (7)
```

(RED의 KAT 실패는 `fetch` 주입이 없어 전역 `fetch`가 가짜 호스트 `kat.test`의 DNS 조회에서 실패한 것이다. 실제 KAT로는 요청이 나가지 않았다.)

GREEN (같은 명령, exit 0): `Tests  7 passed (7)`; `npm --prefix server run typecheck` exit 0.

AC-009 (앱 보호 테스트): `flutter --suppress-analytics test test/unit_test.dart` exit 0, `00:00 +6: CallTask.fromJson ignores providerCallId when parsing tasks` / `00:00 +9: All tests passed!`. 앱 코드를 바꾸지 않는다는 계약을 고정하는 테스트이므로 구현 전 RED가 존재하지 않는다(설계상 첫 실행부터 통과). 서버 쪽 "필드 없는 작업 적재"는 AC-008 (a)가 함께 검증한다.

커밋: `ee36872`

#### M2 — 종료 순서와 예산 (AC-001 ~ AC-005)

RED (`npm --prefix server test -- src/shutdown.test.ts src/services/callService.test.ts`, exit 1):

```
     × rejects new work and new approvals while shutting down 12ms
     × approvePlan checks shutting_down before state and limits 2ms
     × the termination step is bounded to its deadline 1ms
     × a call ended by shutdown is closed as failed without a summary (hangup completes) 1ms
     × a call ended by shutdown is closed as failed without a summary (hangup hangs past the 3 s deadline) 1ms
 FAIL  src/shutdown.test.ts [ src/shutdown.test.ts ]
Error: Cannot find module './shutdown.js' imported from …/server/src/shutdown.test.ts
TypeError: calls.beginShutdown is not a function
 Test Files  2 failed (2)
      Tests  5 failed | 1 passed (6)
```

GREEN (같은 명령, exit 0): `Test Files  2 passed (2)` / `Tests  14 passed (14)`; typecheck exit 0.

커밋: `34bc706`

#### M3 — KAT 시간 제한과 timeLimit (AC-010 ~ AC-013)

RED (`npm --prefix server test -- src/providers/kat/katProvider.test.ts src/services/callService.test.ts`, exit 1):

```
     × a hung provider start fails the task promptly and frees the slot 2006ms
     × every KAT request carries an abort signal and times out 2008ms
     × maps a KAT timeout to a readable Korean error 2004ms
     × hangup never throws on timeout or error (timeout) 2003ms
     × derives timeLimit from MAX_CALL_DURATION_SEC (600 s -> 630) 4ms
     × derives timeLimit from MAX_CALL_DURATION_SEC (5 s -> 35) 1ms
     × derives timeLimit from MAX_CALL_DURATION_SEC (1 s -> 31) 1ms
     × derives timeLimit from MAX_CALL_DURATION_SEC (20000 s -> 14400) 1ms
     × clamps an injected duration below the floor to 10 2ms
TestTimeoutError: Test timed out in 2000ms.   (×4)
AssertionError: expected 900 to be 630 // Object.is equality
AssertionError: expected 900 to be 35 // Object.is equality
AssertionError: expected 900 to be 31 // Object.is equality
AssertionError: expected 900 to be 14400 // Object.is equality
AssertionError: expected 900 to be 10 // Object.is equality
 Test Files  2 failed (2)
      Tests  9 failed | 13 passed (22)
```

AC-012의 HTTP 500 경우는 RED 단계에서도 통과했다(acceptance.md "RED: 500은 현재도 잡히지만 시간 초과는 끝나지 않는다"와 일치).

GREEN (같은 명령, exit 0): `Test Files  2 passed (2)` / `Tests  22 passed (22)`; typecheck exit 0.

마일스톤 배치 차이: `KatOptions.maxCallDurationSec`를 필수 필드로 두었기 때문에 typecheck를 유지하려고 `container.ts`의 전달 한 줄을 M6 대신 M3 커밋에 넣었다(파일 범위는 plan.md §B 그대로).

커밋: `0341ed9`

#### M4 — 재기동 복구 (AC-007, AC-008)

RED (`npm --prefix server test -- src/services/callService.test.ts`, exit 1):

```
     × recovery terminates a still-running provider call (a: termination succeeds) 3ms
     × recovery terminates a still-running provider call (b: termination is rejected) 1ms
     × recovery terminates a still-running provider call (c: termination never finishes) 1ms
     × recovery without a call id or with a different provider only marks the task failed 3ms
TypeError: Cannot read properties of undefined (reading 'then')
AssertionError: expected [] to have a length of 1 but got +0
 Test Files  1 failed (1)
      Tests  4 failed | 7 passed (11)
```

RED, KAT 쪽 `terminateByProviderCallId` (`… katProvider.test.ts -t "terminate by call id"`, exit 1):

```
     × terminates a call it has no session for, without throwing on failure 3ms
TypeError: kat.terminateByProviderCallId is not a function
      Tests  1 failed | 15 skipped (16)
```

GREEN (`npm --prefix server test -- src/providers/kat/katProvider.test.ts src/services/callService.test.ts`, exit 0): `Test Files  2 passed (2)` / `Tests  27 passed (27)`; typecheck exit 0. `index.ts`는 `await calls.recoverInterruptedTasks()`로 바꿨다(비동기화에 따른 필수 변경).

커밋: `d1ce301`

#### M5 — 주인 없는 미디어 스트림 (AC-014)

RED (`npm --prefix server test -- src/providers/kat/katProvider.test.ts -t "media streams|active session"`, exit 1):

```
     × terminates signed media streams that have no active session (a: header call id, non-JSON first frame) 8ms
     × terminates signed media streams that have no active session (b: header call id, no frame for 10 s) 2ms
     × terminates signed media streams that have no active session (c: no header call id, start frame call id) 2ms
AssertionError: expected [] to deeply equal [ Array(1) ]   (×3)
      Tests  3 failed | 2 passed | 16 skipped (21)
```

RED에서 통과한 2건은 (d) 무효 서명(종료 0회 — 현행 동작 유지 확인)과 "활성 세션이 있는 스트림은 유지"(회귀 방지) 테스트다.

GREEN (`npm --prefix server test -- src/providers/kat/katProvider.test.ts`, exit 0): `Tests  21 passed (21)`; typecheck exit 0.

**발견 사항 (AC-014 (c))**: `verifyKatStreamSignature`(`webhook.ts`, 이 SPEC 범위 밖)는 `x-kat-call-id` 헤더가 없으면 항상 `false`를 돌려준다. 따라서 "유효 서명 + 헤더 통화 ID 없음" 연결은 실제 검증기로는 만들 수 없고, 운영 환경에서 (c) 경로는 도달하지 않는다. (c) 테스트는 서명 검사(`isValidStreamUpgrade`)만 `vi.spyOn`으로 대체해 start 프레임 경로를 검증했다. 기존 코드도 `headerCallId || start.callId` 대체 경로를 이미 두고 있었으므로, (c)는 그 대체 경로에 종료 요청을 더한 방어 코드다.

## §E.3 Run-phase Audit-Ready Signal

_<pending run-phase>_

## §E.4 Sync-phase Audit-Ready Signal

_<pending sync-phase>_
