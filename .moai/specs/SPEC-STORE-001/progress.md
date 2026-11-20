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

GREEN (full suite, exit 0; log `m3-green.txt`): `Test Files 4 passed (4)`, `Tests 44 passed (44)`; `npm run typecheck` exit 0. Commit `7447b48`.

### M4 — startup protection and real-file-system regression (AC-014, AC-002, AC-015)

On the fixed code (`npm --prefix server test -- src/store/taskStore.test.ts -t "startup|read-only"`, exit 0; log `m4-current.txt`): `Tests 2 passed | 11 skipped (13)`.

RED against the pre-fix code: `server/src/store/taskStore.ts` was temporarily replaced with `git show 8d628f6:server/src/store/taskStore.ts`, the same command was run (exit 1; log `m4-red-original-code.txt`), and the file was then restored with `git checkout HEAD -- server/src/store/taskStore.ts` (`git diff --stat` afterwards showed only the test file):

```
     × keeps current startup behavior: corrupt or unreadable files fail, legacy entries load 93ms
     × survives a read-only data directory (regression) 431ms
AssertionError: expected SyntaxError: Expected property name or '}… to match object { code: 'EACCES' }
AssertionError: expected [ …(1) ] to have a length of +0 but got 1
      Tests  2 failed | 11 skipped (13)
```

- AC-002 RED is the reproduced defect: one unhandled rejection recorded after `chmod 555` on the real directory.
- AC-014 on the pre-fix code: sub-case (1) (corrupt JSON rejects, directory and file unchanged) passed; sub-case (2) failed only because the pre-fix `open()` has no injection point, so it read the real corrupt file instead of the injected `EACCES` reader; sub-cases (3) and (4) were not reached in that run. On the fixed code all four sub-cases pass, and the `open()` read/parse lines are unchanged apart from `store.fs.readFile`.

REFACTOR: no structural change needed; two `@MX:NOTE [AUTO]` tags added (the grep-counted message constant, the 5 s shutdown budget).

Final (log `final-test.txt`, `final-typecheck.txt`, `final-store-verbose.txt`):

```
$ npm --prefix server test                 → exit 0
 Test Files  4 passed (4)
      Tests  46 passed (46)
$ npm --prefix server run typecheck        → exit 0
$ npm --prefix server test -- src/store/taskStore.test.ts --reporter=verbose → exit 0, Tests 13 passed (13)
$ (store tests repeated 3×)                → run1 exit=0, run2 exit=0, run3 exit=0
```

AC-013 re-run on the final tree (log `ac013-final-log.txt`): `POST=201`, `health=200`, `exit=1`, `final_fail_count=1`.

### Final AC matrix

| AC | Status | Evidence |
|----|--------|----------|
| AC-001 | PASS | "background flush failure never becomes an unhandled rejection" ✓ (`final-store-verbose.txt`); RED in M1 |
| AC-002 | PASS | "survives a read-only data directory (regression)" ✓ (ran, not skipped: non-root, darwin); RED on pre-fix code: 1 unhandled rejection |
| AC-003 | PASS | "a failed write does not poison later writes" ✓ (max concurrent writes 1); RED in M1 |
| AC-004 | PASS | "reads and writes keep working in memory while persistence fails" ✓ |
| AC-005 | PASS | "logs each failed write once with path, code and count" ✓; RED in M2 |
| AC-006 | PASS | "retries with capped exponential backoff" ✓ (intervals 1, 2, 4, 8, 16, 30, 30 s, then one more at 30 s); RED in M2 |
| AC-007 | PASS | "coalesces saves while a retry is pending" ✓ (not RED on M1 code, see M2 note) |
| AC-008 | PASS | "the next successful write persists the full current state" ✓; RED in M2 |
| AC-009 | PASS | "logs recovery once and resets the backoff" ✓; RED in M2 |
| AC-010 | PASS | "a failed write leaves the previous file intact" ✓ (protective, real disk with rename failure) |
| AC-011 | PASS | "final flush cancels pending debounce and retry timers" ✓; RED in M3 |
| AC-012 | PASS | "final flush reports success or failure and never hangs" ✓; RED in M3 |
| AC-013 | PASS | `POST=201`, `health=200`, `exit=1`, `final_fail_count=1`; intermediate RED `final_fail_count=0` |
| AC-014 | PASS | "keeps current startup behavior: …" ✓ on the fixed code (see M4 note on the pre-fix run) |
| AC-015 | PASS | `Tests 46 passed (46)` (33 baseline + 13 new), typecheck exit 0, `server/src/http/app.test.ts` unmodified |

## §E.3 Run-phase Audit-Ready Signal

```yaml
run_complete_at: 2026-11-21
run_commit_sha: "M1 4f1272b, M2 69e8585, M3 7447b48, M4 = the commit carrying this section"
run_status: complete
ac_pass_count: 15
ac_fail_count: 0
preserve_list_post_run_count: 33   # baseline tests still passing
new_warnings_or_lints_introduced: 0   # typecheck exit 0; the project has no linter configured
cross_platform_build:
  typecheck: pass
  windows: not-run   # AC-002 skips on win32 and as root
total_run_phase_files: 5   # taskStore.ts, taskStore.test.ts, index.ts, spec.md (status), progress.md
m1_to_mN_commit_strategy: one commit per milestone on worktree branch worktree-agent-ab6f0ab6d666bcfd3, no push
coverage: not-measured   # no coverage provider installed; adding one would be a new dependency
```

## §E.4 Sync-phase Audit-Ready Signal

_<pending sync-phase>_
