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

커밋: `165efcd`

#### M6 — 연결과 회귀 확인 (AC-015, AC-016)

`index.ts`의 신호 처리를 `createShutdownHandler`로 위임했다(`process.once` → `process.on`, 두 번째 신호가 처리기에 닿도록).

AC-015 RED — M5 커밋(`165efcd`, 연결 전 코드)에서 acceptance.md 절차를 실행(worktree 서버 경로, `cd` 없이 `bash .moai/state/verify/run-lifecycle/lifecycle/ac015.sh`):

```
approve=200
exit=0 elapsed=0s
"status": "dialing"
dialing | undefined
```

AC-015 GREEN — 연결 후 같은 절차:

```
approve=200
exit=0 elapsed=0s
"status": "failed"
failed | 서버가 종료되어 통화를 끊었습니다.
--- server log (마지막 줄) ---
{"level":"info","time":"2026-11-21T00:21:54.593Z","msg":"Shutting down","signal":"SIGTERM"}
```

AC-016 전체 회귀:

```
$ npm --prefix server test -- --reporter=verbose   → exit 0
 Test Files  6 passed (6)
      Tests  81 passed (81)        (기준선 46 + 신규 35, 기존 테스트 수정 없음)
 ✓ src/http/app.test.ts > CallMate API > plans, calls, pauses for approval and summarizes 140ms
$ npm --prefix server run typecheck → exit 0
$ (app) flutter --suppress-analytics test → exit 0, "00:01 +13: All tests passed!"   (기준선 12 + 1)
$ (app) flutter --suppress-analytics analyze → exit 1, "1 issue found." — info 1건 test/support/fakes.dart:53:5 (기준선과 동일, 증가 없음)
```

### AC 판정표 (이 트리, M6 기준 전체 실행 `final-npm-test.txt`)

| AC | 판정 | 검증 명령 | 실제 출력 (발췌 원문) | RED 관찰 |
|----|------|-----------|------------------------|----------|
| AC-001 (a)(b)(c) | PASS | `npm --prefix server test -- --reporter=verbose` | `✓ … CallService shutdown flag (AC-001) > rejects new work and new approvals while shutting down 12ms` | M2 RED `TypeError: calls.beginShutdown is not a function` |
| AC-001 (d) | PASS | 같음 | `✓ … approvePlan checks shutting_down before state and limits 1ms` | M2 RED 같음 |
| AC-002 | PASS | 같음 | `✓ src/shutdown.test.ts > shutdown (AC-002) > terminates calls before app.close and moves on when app.close hangs 5ms` | M2 RED `Cannot find module './shutdown.js'` |
| AC-003 | PASS | 같음 | `✓ … the termination step is bounded to its deadline 3ms` | M2 RED |
| AC-004 | PASS | 같음 | `✓ … closed as failed without a summary (hangup completes) 2ms` / `(hangup hangs past the 3 s deadline) 1ms` | M2 RED |
| AC-005 (a)~(e) | PASS | 같음 | `✓ runs the steps in order`, `✓ finishes within 9 s + 500 ms when every step hangs`, `✓ maps the final flush result to the exit code (failure)/(success)`, `✓ a second signal exits immediately`, `✓ treats a hanging final flush as a failure and exits 1 within the budget`, `✓ … when every step hangs (9 s)` | M2 RED |
| AC-006 | PASS | 같음 | `✓ … stores the provider call id on the task 3ms` / `✓ … reports the KAT callId to the session 12ms` | M1 RED `expected undefined to be 'c-1'` / `getaddrinfo ENOTFOUND kat.test` |
| AC-007 (a)(b)(c) | PASS | 같음 | `✓ recovery terminates a still-running provider call (a: …)/(b: …)/(c: termination never finishes)` | M4 RED `Cannot read properties of undefined (reading 'then')` |
| AC-008 (a)(b) | PASS | 같음 | `✓ recovery without a call id or with a different provider only marks the task failed 1ms` | M4 RED `expected [] to have a length of 1 but got +0` |
| AC-009 | PASS | `flutter --suppress-analytics test test/unit_test.dart` | `CallTask.fromJson ignores providerCallId when parsing tasks` / `All tests passed!` | 없음 — 보호 테스트(설계상 첫 실행부터 통과) |
| AC-010 | PASS | `npm --prefix server test -- --reporter=verbose` | `✓ … every KAT request carries an abort signal and times out 105ms` | M3 RED `TestTimeoutError: Test timed out in 2000ms.` |
| AC-011 | PASS | 같음 | `✓ … a hung provider start fails the task promptly and frees the slot 102ms` / `✓ … maps a KAT timeout to a readable Korean error 52ms` | M3 RED `TestTimeoutError` |
| AC-012 | PASS | 같음 | `✓ hangup never throws on timeout or error (timeout) 51ms` / `(HTTP 500) 1ms` | M3 RED (timeout) `TestTimeoutError`; 500 경우는 RED 전부터 통과 |
| AC-013 (a)(b) | PASS | 같음 | `✓ derives timeLimit … (600 s -> 630)/(5 s -> 35)/(1 s -> 31)/(20000 s -> 14400)`, `✓ clamps an injected duration below the floor to 10` | M3 RED `expected 900 to be 630` 등 |
| AC-014 (a)(b)(d) | PASS | 같음 | `✓ … (a: header call id, non-JSON first frame)`, `✓ … (b: header call id, no frame for 10 s)`, `✓ … (d: invalid signature)` | M5 RED `expected [] to deeply equal [ Array(1) ]` ((d)는 RED 전부터 통과) |
| AC-014 (c) | PASS-WITH-DEBT | 같음 | `✓ … (c: no header call id, start frame call id) 2ms` | M5 RED 같음. 서명 검사를 스텁으로 대체해 검증 — 실제 검증기로는 도달 불가(M5 발견 사항) |
| AC-015 | PASS | `bash .moai/state/verify/run-lifecycle/lifecycle/ac015.sh` | `approve=200` / `exit=0 elapsed=0s` / `"status": "failed"` / `failed \| 서버가 종료되어 통화를 끊었습니다.` | M5 커밋에서 `"status": "dialing"` |
| AC-016 | PASS | 위 회귀 명령 4개 | `Tests  81 passed (81)`, typecheck exit 0, flutter `+13: All tests passed!`, analyze 기준선 info 1건 유지 | 해당 없음 |

### 검증하지 않은 것 (Gaps)

- 실제 KAT Cloud·OpenAI Realtime 호출 없음. KAT 응답 형식, 종료 API의 실제 동작(이미 끝난 통화 응답 등), `timeLimit` 기준 시점은 확인되지 않았다.
- AC-015는 시뮬레이션 모드 프로세스로 1회만 확인했다. 실제 프로세스에서 두 번째 신호(REQ-007), 단계가 멈출 때의 9 s 상한, 종료 중 HTTP `503` 응답은 확인하지 않았다(모두 가짜 타이머 단위 테스트로만 검증). `elapsed`는 초 단위 측정이다.
- AC-014 (c)는 실제 서명 검증기로는 재현할 수 없다(스텁 사용).
- 커버리지는 측정하지 않았다(`@vitest/coverage-v8` 미설치, 의존성 추가는 범위 밖). 린터 설정이 없어 lint도 실행하지 않았다.
- SIGTERM 수신 후 실제 플랫폼 유예 시간(10 s 가정)은 확인되지 않았다.

### 잔여 위험

- 종료 단계 1에서 3 s 안에 끝나지 않은 종료 요청은 버려진 채 백그라운드에서 계속되다 `process.exit`로 끊긴다. 그 통화가 KAT에서 실제로 끊겼는지는 알 수 없다(마지막 안전장치는 KAT `timeLimit`).
- 통화 생성 응답을 기다리는 중(`dialing`, 통화 ID 없음)에 종료되면 끊을 방법이 없다. 단계 1은 `Shutdown hangup without a provider call id` warn만 남긴다(plan.md §D 잔여 위험).
- `providerCallId` 저장은 저장소의 300 ms 디바운스를 따른다. 통화 생성 직후 그 사이에 프로세스가 죽으면 ID가 파일에 남지 않는다.
- 신호 처리기는 `listen` 뒤에 설치된다(기존과 같음). 기동 복구(최대 10 s) 중에 온 신호는 기본 동작으로 프로세스를 끝내고, 그 경우 작업 상태는 파일에 그대로 남아 다음 기동에서 다시 복구된다.
- 단일 인스턴스 가정(spec.md §4): 같은 `DATA_FILE`을 쓰는 두 인스턴스에서는 복구와 주인 없는 스트림 처리가 정상 통화를 끊는다.
- 기본 설정에서 KAT `timeLimit`이 900에서 630으로 바뀐다(OD-3 DEFAULT).

### 기록 정정

M6 커밋(`702648a`)에서 §E.2를 갱신하는 편집이 `## §E.3` 제목까지 덮어써 그 커밋에는 §E.3가 빠졌다. 후속 커밋에서 §E.3를 복구하고 `run_commit_sha`를 채웠다(`--amend` 금지 지시에 따라 새 커밋).

## §E.3 Run-phase Audit-Ready Signal

```yaml
run_complete_at: 2026-11-21
run_start_sha: f17a1880b334a5d24c554f67de8ee763fdd512c8
run_commit_sha: 702648a   # M6 (마지막 구현 마일스톤) 커밋
milestone_commits: [ee36872 (M1), 34bc706 (M2), 0341ed9 (M3), d1ce301 (M4), 165efcd (M5), 702648a (M6)]
run_status: complete-with-debt
ac_pass_count: 16          # AC-014는 (c)만 PASS-WITH-DEBT
ac_fail_count: 0
ac_pass_with_debt: [AC-014 (c)]
server_tests: "6 files / 81 passed (baseline 4 / 46)"
server_typecheck_exit: 0
flutter_test: "+13 All tests passed (baseline 12)"
flutter_analyze: "1 info, unchanged from baseline"
preserve_list_post_run_count: "existing tests unmodified; simulatedProvider.ts unchanged (plan §B '확인')"
l44_pre_commit_fetch: not-run          # worktree 격리, push 금지 지시
l44_post_push_fetch: not-applicable    # push 하지 않음
new_warnings_or_lints_introduced: 0    # typecheck 0 errors, flutter analyze 증가 없음; 린터 미구성
cross_platform_build:
  typecheck: pass
  windows: not-applicable              # Node/TS, OS별 빌드 태그 없음
total_run_phase_files: 13              # 코드 11 + SPEC 문서 2 (spec.md 상태, progress.md)
m1_to_mN_commit_strategy: one commit per milestone on the worktree branch + one record-fix commit, explicit pathspec staging, no push
```

## §E.4 Sync-phase Audit-Ready Signal

_<pending sync-phase>_
