# SPEC-POLICY-001 진행 기록

## §E.1 Plan-phase Audit-Ready Signal

- plan_status: revised after plan-audit iteration 2 (FAIL 0.88) — re-audit pending
- plan_complete_at: 2026-11-21
- artifacts: spec.md, plan.md, acceptance.md, research.md
- counts: 11 REQ / 11 AC
- depends_on: SPEC-LIFECYCLE-001
- open_decisions: OD-1 RESOLVED (owner); OD-2 DEFAULT (pending owner review)
- run-entry note: manager-develop records `run_start_sha` (HEAD at run entry) as the first line of §E.2 (used by AC-011)

## §E.2 Run-phase Evidence

run_start_sha: 6ffe4ba0904444fb9db41bc2c2ebc61a9b9dd008

- run started: 2026-11-21, manager-develop, cycle_type=tdd, harness standard
- worktree: `.claude/worktrees/agent-a2f6355898e7ce23b` (branch `worktree-agent-a2f6355898e7ce23b`, fast-forwarded to `6ffe4ba`)
- evidence directory: `.moai/state/verify/policy-run/policy/` (worktree-local)

### Baseline (this run, HEAD 6ffe4ba)

| Command | Result |
|---------|--------|
| `npm --prefix server test` | exit 0 — `Test Files  6 passed (6)` / `Tests  81 passed (81)` |
| `npm --prefix server run typecheck` | exit 0 — `tsc -p tsconfig.json --noEmit` (no diagnostics) |

### Milestone log

#### M1 — domain rule `checkTargetNumber` (AC-008, AC-009)

- RED: `npm --prefix server test -- src/domain/domain.test.ts` → exit 1
  ```
  TypeError: checkTargetNumber is not a function
   Test Files  1 failed (1)
        Tests  18 failed | 21 passed (39)
  ```
- GREEN: same command → exit 0
  ```
   Test Files  1 passed (1)
        Tests  39 passed (39)
  ```
- typecheck after GREEN: exit 0
- files: `server/src/domain/phone.ts`, `server/src/domain/domain.test.ts`

- commit: `d8ddb62`

#### M2 — enforce at creation (AC-001..AC-004)

- RED: `npm --prefix server test -- src/services/callService.test.ts` → exit 1
  ```
  AssertionError: expected '010-1234-5678' to be '+821012345678' // Object.is equality      (AC-001)
  AssertionError: expected undefined to match object { statusCode: 400, …(2) }             (AC-002 "12")
  AssertionError: expected undefined to match object { statusCode: 400, …(2) }             (AC-003 "119", "+82 112")
  AssertionError: expected '010 9999 8888' to be '+821099998888' // Object.is equality      (AC-004)
  AssertionError: expected 'abc' to be undefined // Object.is equality                      (AC-004)
  AssertionError: expected '' to be undefined // Object.is equality                         (AC-004)
   Test Files  1 failed (1)
        Tests  7 failed | 12 passed (19)
  ```
  (the "callback omitted" case already passed — protection case)
- GREEN: `npm --prefix server test` → exit 0 — `Test Files  6 passed (6)` / `Tests  107 passed (107)`; typecheck exit 0
- files: `server/src/services/callService.ts`, `server/src/services/callService.test.ts`

- commit: `e163fea`

#### M3 — re-check before dialing (AC-010)

- RED: `npm --prefix server test -- src/services/callService.test.ts` → exit 1
  ```
  FAIL ... approvePlan re-checks the number right before dialing
  AssertionError: promise resolved "{ id: 'blocked', version: 2, …(13) }" instead of rejecting
  FAIL ... approvePlan checks in the order shutting_down, state, number, limits
  AssertionError: expected Error: Too many calls are in progress { …(2) } to match object { statusCode: 400, …(2) }
   Test Files  1 failed (1)
        Tests  2 failed | 19 passed (21)
  ```
  (first test stops at its first assertion: the stored `+82119` task was dialed; (iii) answered 429 instead of 400. (i) 503 and (ii) 409 / 404 are protection items and were not the failing assertions.)
- GREEN: `npm --prefix server test` → exit 0 — `Test Files  6 passed (6)` / `Tests  109 passed (109)`; typecheck exit 0
- files: `server/src/services/callService.ts`, `server/src/services/callService.test.ts`

_<M4-M5 pending>_

## §E.3 Run-phase Audit-Ready Signal

_<pending run-phase>_

## §E.4 Sync-phase Audit-Ready Signal

_<pending sync-phase>_
