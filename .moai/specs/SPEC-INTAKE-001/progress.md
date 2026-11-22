# SPEC-INTAKE-001 진행 기록

## §E.1 Plan-phase Audit-Ready Signal

- plan_status: revised after plan-audit iteration 1 (FAIL 0.82; D5-D8 fixed, D9-D12 applied, OD-7 added) — re-audit pending
- spec_version: 0.3.0 (plan-audit iteration 2: PASS 0.89; N2, N3, N4 fixed; A2, A3, A8 applied)
- execution: Route B (Tier L PR route); single serial writer (callService.ts touched by M1 and M4); design-phase skip decided by the orchestrator at Kickoff
- plan_complete_at: 2026-11-21
- base_sha: c664596
- tier: L, harness: thorough (recommended)
- artifacts: spec.md, plan.md, acceptance.md, design.md, research.md, progress.md
- counts: 24 REQ / 24 AC
- depends_on: SPEC-APPROVAL-001
- open_decisions: OD-1 ~ OD-7 DEFAULT (pending owner review); OD-1 (server-side autoStart) is the highest-impact decision
- note: existing tests are expected to pass unmodified; new tests only (AC-024)
- release note: server and app ship in the same release; mixed versions degrade safely (REQ-022, REQ-024)
- run-entry note: manager-develop records `run_start_sha` (HEAD at run entry) and the measured test baseline as the first lines of §E.2

## §E.2 Run-phase Evidence

- run_start_sha: 42e2f169ab9dea50f6ff7533979afd070417b260 (worktree branch `worktree-agent-a5729f8126e4d139f`, fast-forwarded from c95953f with `git merge --ff-only 42e2f16`)
- cycle_type: tdd; single serial writer; evidence files under `.moai/state/verify/intake-run/intake/`
- environment: Node v23.7.0 (`/opt/homebrew/Cellar/node/23.7.0/bin`), Flutter 3.50.1

### Baseline (run entry, HEAD 42e2f16, before any change)

| Check | Command | Observed |
|---|---|---|
| server tests | `npm --prefix server test` | `Test Files  13 passed (13)` / `Tests  293 passed (293)` |
| server typecheck | `npm --prefix server run typecheck` | exit 0 |
| test-file compile | `tsc -p server/tsconfig.testcheck.json` (temporary: extends tsconfig.json, `include: ["src"]`, `exclude: []`, noEmit; deleted after the run) | exit 0 |
| app tests | `cd app && flutter --suppress-analytics test` | `+25: All tests passed!` |
| app analyze | `cd app && flutter --suppress-analytics analyze` | `1 issue found` — info `use_null_aware_elements` at `test/support/fakes.dart:53:5` |

### M1 — auto start (AC-013 ~ AC-016)

- RED: `npm --prefix server test -- src/services/callService.test.ts src/http/app.test.ts -t "INTAKE"` → exit 1, `Tests  8 failed | 1 passed | 76 skipped (85)`. Failures: `accepts an optional autoStart flag` (`expected undefined to be true`), `auto-starts a simulated call without approve-plan` (timeout), `starts the call once planning finishes…` (`expected [] to include '<id>'`), `auto-started calls open with the template AI disclosure` (same), the four `records …` cases (`expected undefined to be defined` / `expected undefined to be 'daily_limit'` / `… 'shutting_down'`). The one pass is AC-016 `never auto-starts outside the planning completion`, a negative guard that holds before the feature exists (it pins that the new trigger stays scoped). Evidence: `m1-red.txt`.
- GREEN: `npm --prefix server test` → exit 0, `Test Files  13 passed (13)` / `Tests  302 passed (302)`; typecheck exit 0; test-file compile exit 0. Evidence: `m1-green.txt`.
- One test-only adjustment during GREEN: the integration case first used the goal "영업시간 문의", whose simulated script has no approval step, so it timed out for a reason unrelated to the feature; it now uses the reservation goal (the existing flow test's goal).
- Commit: `1d778c2`.

### M2 — number and name rules (AC-004, AC-007 (a) masking vectors, §3.1 normalization)

- RED: `npm --prefix server test -- src/domain/intake.test.ts` → exit 1, `FAIL src/domain/intake.test.ts` / `Error: Cannot find module './intake.js'` / `Tests  no tests`. Evidence: `m2-red.txt`.
- GREEN: same command → `Tests  28 passed (28)` (18 AC-004 rows + 6 masking rows + placeholder + 3 normalization rows). Full suite `Test Files  14 passed (14)` / `Tests  330 passed (330)`, typecheck exit 0, test-file compile exit 0. Evidence: `m2-green.txt`.
- Implementation: `server/src/domain/intake.ts` (pure; only imports `checkTargetNumber`). History lookups are added in M4, where the service tests drive them.
- Commit: `f1e0e3f`.

### M3 — brain intake (AC-010, AC-008 brain side, AC-009, AC-007 (a) brain side)

- RED: `npm --prefix server test -- src/brain/heuristicBrain.test.ts src/brain/openaiBrain.test.ts -t "intake"` → exit 1, `Tests  17 failed | 34 skipped (51)`; failures `TypeError: brain.draftIntake is not a function` / `(intermediate value).draftIntake is not a function` (6 heuristic rows, 1 "sends the text it receives unchanged", 3 "returns schema-validated intake content unchanged", 6 "falls back visibly when the intake LLM fails", 1 "bounds the intake LLM call below the app timeout"). Evidence: `m3-red.txt`.
- GREEN: `npm --prefix server test` → exit 0, `Test Files  14 passed (14)` / `Tests  347 passed (347)`; typecheck exit 0; test-file compile exit 0. Evidence: `m3-green.txt`.
- Plan §F check: `grep -n "phoneNumber" server/src/brain/openaiBrain.ts` → no output (the intake schema has no number field).
- Commit: `ec0cd36`.
- Design note: `CallBrain.draftIntake` is declared optional so the existing test brain fake in `callService.test.ts` (`recordingBrain`, unmodifiable per AC-024) still compiles; the service falls back to the deterministic rules when a brain lacks it. Both shipped brains implement it. The timeout is injected through a new 4th constructor argument `{ intakeTimeoutMs }`; exported `INTAKE_LLM_TIMEOUT_MS = 15000`, `LLM_TIMEOUT_MS = 30000` (plan/summary unchanged).

### M4 — service intake and endpoint (AC-001, AC-002, AC-003, AC-005, AC-006, AC-007 (a) body + (b)-(e), AC-008 service, AC-011, AC-012)

- RED: `npm --prefix server test -- src/services/callService.test.ts src/http/app.test.ts -t "intake|Intake"` → exit 1, `Tests  22 failed | 1 passed | 85 skipped (108)`; `TypeError: calls.draftIntake is not a function` (16 service cases) and `expected 404 to be 200/400/503` (HTTP cases). The one pass is AC-001 (6) (no token → 401), which the existing `/v1/*` auth hook answers before routing. Evidence: `m4-red.txt`.
- GREEN: `npm --prefix server test` → exit 0, `Test Files  14 passed (14)` / `Tests  370 passed (370)`; typecheck exit 0 (`m4-typecheck.txt`); test-file compile exit 0. Evidence: `m4-green.txt`.
- Plan §F check: `grep -n "/v1/intake" server/src/http/app.ts` → `167:  app.post("/v1/intake", async (request) => {` (one route; the handler parses `IntakeBody` and calls `calls.draftIntake` only).
- **SPEC vector defect (for manager-spec, not edited here):** design.md §3.4 history table row 4 (`라 파스타에 전화해서 02-999-9999로`) lists `+82299999999`. Measured: `checkTargetNumber("02-999-9999")` → `{"kind":"ok","e164":"+8229999999"}`, `checkTargetNumber("02-9999-9999")` → `+82299999999` (tsx one-liner, this run). REQ-004 fixes the value through `checkTargetNumber`, and REQ-007 forbids emitting a number not in the text, so the test keeps the row's text and asserts `+8229999999` (comment in the test). The row's intent — the text number wins over history (`phoneSource "text"`) — is asserted unchanged. Suggested fix: change the table value to `+8229999999` (or the text to `02-9999-9999`).
- Interpretation note: when the brain's name is dropped by the containment check (an invented name), the service treats it like a null name and runs the REQ-011 history-name match.
- Commit: `9c6a1e8`.

### M5 — app models and plan card (AC-019, AC-020, AC-021, AC-023, unit parsing)

- RED: `cd app && flutter --suppress-analytics test test/plan_card_test.dart test/unit_test.dart` → exit 1; `Error: Error when reading 'lib/features/calls/domain/intake_models.dart': No such file or directory`, `'PlanDraft' isn't a type`, `Undefined name 'IntakeResult'`, `test/unit_test.dart:177:9: Error: No named parameter with the name 'autoStart'`. Evidence: `m5-red.txt`.
- GREEN: same command → `+32: All tests passed!`; full `flutter --suppress-analytics test` → `+43: All tests passed!` (`m5-app-full.txt`); `flutter --suppress-analytics analyze` → `1 issue found` (the baseline info at `test/support/fakes.dart:53:5` only).
- Two test-only adjustments during GREEN (assertions unchanged): AC-021 (1) needed one more 400 ms frame before asserting the replaced page had left (exit transition), and uses `tap(find.byType(BackButton))` because `pageBack()` looks for the English "Back" tooltip while the app runs in Korean. The new test file's unused `flutter/services.dart` import was removed to keep analyze at baseline.
- Notes: the plan card's [이대로 시작] sends the draft's E.164 number unless the user edited the number; a 400 `invalid_phone`/`blocked_number` opens the number for editing with the server message as its error text. `calls_controller.dart` needed no change (`create` already takes `NewCallRequest`).
- Commit: `27c0fb0`.

### M6 — home screen (AC-017, AC-018, AC-022, AC-024 manual form)

- RED: `cd app && flutter --suppress-analytics test test/intake_flow_test.dart test/unit_test.dart` → exit 1; all 8 `intake_flow_test.dart` cases failed (e.g. `Found 0 widgets with text "무엇을 도와드릴까요?"`, `Found 0 widgets with text "최근 통화한 곳"`), and `unit_test.dart` did not compile (`Error when reading 'lib/features/calls/domain/counterparties.dart'`, `Method not found: 'recentCounterparties'`, `Method not found: 'normalizeName'`). Evidence: `m6-red.txt`.
- First GREEN attempt broke 4 existing tests (`approval_flow_test.dart` "user approves a mid-call request…", `approval_card_test.dart` ×3) with `Bad state: Too many elements` from `find.byType(TextField)`: after their single 400 ms frame the push transition is still running, so the home route — now holding the intake `TextField` — is still onstage. The tests stay unmodified (AC-024); the fix is in the home: while its route is not current, the input is drawn as an `InputDecorator` + `Text` look-alike instead of a `TextField`.
- GREEN: `cd app && flutter --suppress-analytics test` → `+53: All tests passed!` (`m6-green.txt`); `flutter --suppress-analytics analyze` → `1 issue found` (the baseline `use_null_aware_elements` info, now reported at `test/support/fakes.dart:54:5` because an import line was added above it).
- Notes: suggestions are `ActionChip`s whose label is one `Text` `<이름> · <번호> · N번 통화`, one per line; recency uses `createdAt` like the server's history order; "직접 입력하기" keeps the former FAB's profile guard (no name → settings). The home sends `language: "ko"` (no picker on home; the plan card toggles the call language).

## §E.3 Run-phase Audit-Ready Signal

_<pending run-phase>_

## §E.4 Sync-phase Audit-Ready Signal

_<pending sync-phase>_
