# SPEC-STORE-001 진행 기록

## §E.1 Plan-phase Audit-Ready Signal

- plan_status: revised after plan-audit iteration 1 (FAIL 0.76) — re-audit pending
- plan_complete_at: 2026-11-21
- artifacts: spec.md, plan.md, acceptance.md, research.md
- counts: 14 REQ / 15 AC
- open_decisions: OD-1 RESOLVED (owner), OD-2 DEFAULT (pending owner review)
- run-entry note: manager-develop records `run_start_sha` (HEAD at run entry) as the first line of §E.2

## §E.2 Run-phase Evidence

run_start_sha: 8d628f6ec682014701058d98160ac9e93370036a

- run location: L1 worktree `.claude/worktrees/agent-ab6f0ab6d666bcfd3`, branch `worktree-agent-ab6f0ab6d666bcfd3`, fast-forwarded to `8d628f6` before any change (`git merge --ff-only 8d628f6…` → HEAD `8d628f6ec682014701058d98160ac9e93370036a`). Commits land on that branch; `main` is fast-forwarded by the orchestrator.
- evidence directory: `.moai/state/verify/340eb6c9-3304-4932-af26-fd9fc6afad65/store/` inside the worktree (gitignored, not committed)

### Baseline (this tree, HEAD 8d628f6)

```
$ npm --prefix server test            → exit 0
 Test Files  3 passed (3)
      Tests  33 passed (33)
$ npm --prefix server run typecheck   → exit 0
```

### M1 — write-failure isolation (AC-001, AC-003, AC-004)

RED (`npm --prefix server test -- src/store/taskStore.test.ts`, before implementation, exit 1; full log `m1-red.txt`):

```
     × background flush failure never becomes an unhandled rejection 52ms
     × a failed write does not poison later writes 24ms
     × reads and writes keep working in memory while persistence fails 34ms
 FAIL  ... > background flush failure never becomes an unhandled rejection
AssertionError: expected +0 to be 1 // Object.is equality
 FAIL  ... > a failed write does not poison later writes
AssertionError: expected +0 to be 1 // Object.is equality
 FAIL  ... > reads and writes keep working in memory while persistence fails
AssertionError: expected 0 to be greater than 0
      Tests  3 failed (3)
```

RED reason as observed: the current `open()` has no injection point, so the injected failing layer was never called (writes counted 0). The literal crash (unhandled `EACCES`) is reproduced on the real file system by AC-002 in M4.

GREEN (full suite, exit 0; log `m1-green.txt`): `Test Files 4 passed (4)`, `Tests 36 passed (36)`; `npm run typecheck` exit 0.

## §E.3 Run-phase Audit-Ready Signal

_<pending run-phase>_

## §E.4 Sync-phase Audit-Ready Signal

_<pending sync-phase>_
