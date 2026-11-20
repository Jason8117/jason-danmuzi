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

GREEN (full suite, exit 0; log `m1-green.txt`): `Test Files 4 passed (4)`, `Tests 36 passed (36)`; `npm run typecheck` exit 0. Commit `4f1272b`.

### M2 — retry and recovery (AC-005 … AC-010)

RED (`npm --prefix server test -- src/store/taskStore.test.ts`, after M1, exit 1; log `m2-red.txt`):

```
     × logs each failed write once with path, code and count 26ms
     × retries with capped exponential backoff 24ms
     × the next successful write persists the full current state 23ms
     × logs recovery once and resets the backoff 23ms
AssertionError: expected undefined to be 'Store write failed' // Object.is equality
AssertionError: expected 1 to be 2 // Object.is equality
AssertionError: expected 2 to be 3 // Object.is equality
AssertionError: expected 2 to be 3 // Object.is equality
      Tests  4 failed | 5 passed (9)
```

Not RED on the M1 code, as observed: "coalesces saves while a retry is pending" (AC-007; with no retry yet, the debounce already merged the five saves into one write) and "a failed write leaves the previous file intact" (AC-010; acceptance.md marks it protective — the temp-file + rename write already preserved the file). Both are kept as guards.

GREEN (full suite, exit 0; log `m2-green.txt`): `Test Files 4 passed (4)`, `Tests 42 passed (42)`; `npm run typecheck` exit 0. Commit `69e8585`.

### M3 — final flush and exit code (AC-011, AC-012, AC-013)

RED (`npm --prefix server test -- src/store/taskStore.test.ts`, after M2, exit 1; log `m3-red.txt`):

```
     × final flush cancels pending debounce and retry timers 24ms
     × final flush reports success or failure and never hangs 25ms
TypeError: first.finalFlush is not a function
AssertionError: expected undefined to be 'Final store flush failed' // Object.is equality
      Tests  2 failed | 9 passed (11)
```

GREEN (store tests): `Tests 11 passed (11)` (log `m3-store-green.txt`).

AC-013 process check — intermediate RED (store fixed, `index.ts` still calling `await store.flush()`; log `ac013-red-log.txt`). Procedure from acceptance.md adapted to the worktree: absolute `tsx` path, `PORT=8798`, `API_TOKEN=t0k` (POST sends `authorization: Bearer t0k`), `unset OPENAI_API_KEY KAT_API_KEY CALL_PROVIDER` (simulation mode), `DATA_FILE=$(mktemp -d)/tasks.json`:

```
POST=201
health=200
exit=1
final_fail_count=0
```

The server survived the failed writes, but the shutdown `flush()` rejected and crashed the process (`Error: EACCES: permission denied, open '…/tasks.json.tmp'` in the log) with no fixed message, so the third condition failed.

AC-013 GREEN (after `index.ts` uses `finalFlush()`; log `ac013-green-log.txt`):

```
POST=201
health=200
exit=1
final_fail_count=1
```

Log line: `{"level":"error",…,"msg":"Final store flush failed","path":"…/tasks.json","reason":"error","code":"EACCES"}`. Phone number occurrences in the log: `phone_in_log=0`. Success path (writable directory, same procedure without `chmod 555`; log `ac013-success-log.txt`): `POST=201`, `exit=0`, `final_fail_count=0`, `tasks_in_file=1`.

GREEN (full suite, exit 0; log `m3-green.txt`): `Test Files 4 passed (4)`, `Tests 44 passed (44)`; `npm run typecheck` exit 0.

## §E.3 Run-phase Audit-Ready Signal

_<pending run-phase>_

## §E.4 Sync-phase Audit-Ready Signal

_<pending sync-phase>_
