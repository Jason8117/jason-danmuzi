# SPEC-OUTCOME-001 진행 기록

## §E.1 Plan-phase Audit-Ready Signal

- plan_status: revised after plan-audit iteration 2 (FAIL 0.88) — re-audit pending
- plan_complete_at: 2026-11-21
- artifacts: spec.md, plan.md, acceptance.md, research.md
- counts: 13 REQ / 12 AC
- depends_on: SPEC-POLICY-001
- open_decisions: OD-1 RESOLVED (owner); OD-2, OD-3 DEFAULT (pending owner review)
- note: the result assertion in test "plans, calls, pauses for approval and summarizes" (`server/src/http/app.test.ts`, `:95` at f4d531e) changes from "success" to "unverified" by design
- release note: server and app ship in the same release
- run-entry note: manager-develop records `run_start_sha` (HEAD at run entry) as the first line of §E.2

## §E.2 Run-phase Evidence

- run_start_sha: b3528db9866edc2d32ea6907f81cc86190138671
- cycle_type: tdd, harness: standard
- worktree: `.claude/worktrees/agent-ad15f0afc701df87f` (branch `worktree-agent-ad15f0afc701df87f`, fast-forwarded to b3528db)
- evidence dir (gitignored, on disk in the worktree): `.moai/state/verify/outcome-run/outcome/`

### Baseline (this run, HEAD b3528db)

| Check | Command | Observed |
|-------|---------|----------|
| server tests | `npm --prefix server test` | `Test Files  6 passed (6)` / `Tests  111 passed (111)` |
| server typecheck | `npm --prefix server run typecheck` | exit 0 |
| app tests | `flutter --suppress-analytics test` (in `app/`) | `00:00 +13: All tests passed!` |
| app analyze | `flutter --suppress-analytics analyze app` | `info • Use the null-aware marker '?' … • app/test/support/fakes.dart:53:5 • use_null_aware_elements` / `1 issue found.` (exit 1, info only) |

### Milestone log

_(appended per milestone below)_

#### M1 — domain types + heuristic (includes the M3 integration assertion, see deviation note)

- RED `npm --prefix server test -- src/brain/heuristicBrain.test.ts` (exit 1): `Tests  7 failed (7)`; e.g. `AssertionError: expected undefined to be 'heuristic'`, `AssertionError: expected 'success' not to be 'success'`, `Expected: "unverified" / Received: "partial"`, `AssertionError: expected false to be true` (prefix check).
- RED AC-011 — `app.test.ts` two-line change run against the base `heuristicBrain.ts` (temporarily restored from HEAD): `npm --prefix server test -- src/http/app.test.ts -t "plans, calls"` (exit 1): `× plans, calls, pauses for approval and summarizes` / `Expected: "unverified"` / `Received: "success"` / `Tests  1 failed | 8 skipped (9)`.
- GREEN `npm --prefix server test -- src/brain/heuristicBrain.test.ts src/http/app.test.ts` (exit 0): `Tests  16 passed (16)`; full `npm --prefix server test` (exit 0): `Test Files  7 passed (7)` / `Tests  118 passed (118)`; typecheck exit 0.
- Deviation: the AC-011 assertion change (plan M3) is committed with M1, because M1 GREEN makes the old `"success"` assertion fail and a separate commit would leave the suite red. RED for AC-011 was still observed before GREEN (above).
- Interim: `openaiBrain.ts` `summarize` got an explicit `completeJson<CallOutcome>` type argument so M1 typechecks; M2 replaces it.
- Commit: `0da933d`

#### M2 — OpenAI fallback path

- RED `npm --prefix server test -- src/brain/openaiBrain.test.ts` (exit 1): `Tests  9 failed (9)`; e.g. `AssertionError: expected { err: 'OpenAI responded 500' } to match object { Object (op, taskId, ...) }`, `AssertionError: expected { result: 'success', …(3) } to deeply equal { result: 'success', …(4) }` (no `source`), `AssertionError: expected { err: 'OpenAI responded 500' } to match object { op: 'plan', …(2) }`.
- GREEN `npm --prefix server test -- src/brain/heuristicBrain.test.ts src/brain/openaiBrain.test.ts src/http/app.test.ts` (exit 0): `Test Files  3 passed (3)` / `Tests  25 passed (25)`; typecheck exit 0.
- Design: `request()` returns a `Completion<T>` union (no throw/catch of messages); `completeJson()` logs `{ op, reason, status?, taskId? }` once and returns `undefined`; callers fall back. Body-read timeout is classified `timeout`, other body-read failures `invalid_json`.
- Commit: `608b896`

#### M3 — server integration assertion

- Folded into M1 (`0da933d`); RED/GREEN evidence recorded under M1.

#### M4 — app model

- RED `flutter --suppress-analytics test test/unit_test.dart` (in `app/`, exit 1): compile failure — `test/unit_test.dart:48:48: Error: Member not found: 'unverified'.`, `test/unit_test.dart:49:34: Error: Undefined name 'OutcomeSource'.`, `test/unit_test.dart:49:26: Error: The getter 'source' isn't defined for the type 'CallOutcome'.`
- GREEN same command (exit 0): `00:00 +6: CallTask.fromJson parses outcome result and source, old and new` … `00:00 +10: All tests passed!` (existing "parses outcomes" unchanged and passing).
- `flutter --suppress-analytics analyze app`: still only the baseline info at `app/test/support/fakes.dart:53:5` (`1 issue found.`).

## §E.3 Run-phase Audit-Ready Signal

_<pending run-phase>_

## §E.4 Sync-phase Audit-Ready Signal

_<pending sync-phase>_
