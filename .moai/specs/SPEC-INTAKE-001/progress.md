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
- Commit: `ab029ec`.

### M7 — regression and compatibility (AC-024)

Final verification batch at HEAD `ab029ec` (this run, this tree):

| Check | Command | Observed |
|---|---|---|
| server tests | `npm --prefix server test` | exit 0, `Test Files  14 passed (14)` / `Tests  370 passed (370)` (`m7-server-test.txt`; baseline 13 / 293) |
| server typecheck | `npm --prefix server run typecheck` | exit 0 |
| test-file compile | `tsc -p server/tsconfig.testcheck.json` | exit 0 |
| layering rules | `npm --prefix server test -- src/architecture.test.ts` | `Tests  4 passed (4)`; file not modified |
| app tests | `cd app && flutter --suppress-analytics test` | exit 0, `+53: All tests passed!` (`m7-app-test.txt`; baseline +25) |
| app analyze | `cd app && flutter --suppress-analytics analyze` | `1 issue found` — the baseline info only (`test/support/fakes.dart:54:5`, was :53) |
| existing test bodies | `git diff 42e2f16 HEAD -- app/test/approval_flow_test.dart server/src/http/app.test.ts server/src/services/callService.test.ts server/src/brain/heuristicBrain.test.ts server/src/brain/openaiBrain.test.ts app/test/unit_test.dart app/test/outcome_card_test.dart app/test/calls_controller_test.dart app/test/approval_card_test.dart server/src/architecture.test.ts server/src/brain/prompts.test.ts \| grep -E '^-[^-]'` | no output (grep exit 1): no line removed or changed; only additions (new tests, new import lines) |
| fake (test support) | `git diff 42e2f16 HEAD -- app/test/support/fakes.dart` | one replaced line: `create` now records the request and can throw `createError`; with neither set it returns `nextCreated!` as before |
| boundary | `git diff --stat 42e2f169..HEAD` | `28 files changed, 2532 insertions(+), 54 deletions(-)` = the 26 plan §B files + `spec.md` + `progress.md`; nothing else |
| added log lines | `git diff 42e2f16 HEAD -- server/src/services/callService.ts server/src/brain/openaiBrain.ts server/src/domain/intake.ts server/src/http/app.ts \| grep -nE '^\+.*(log\.\|console\.)'` | one line: `this.log.warn({ taskId: task.id, reason: "auto_start_not_recorded" }, …)` (auto-start record failure; no request text or number). The intake path adds no log line; LLM fallback reuses the existing `{op, reason, status?}` warn |

Manual form never auto-starts: `intake_flow_test.dart` "the manual form never auto-starts" (in the +53).

### AC matrix

| AC | Status | Test (file — name) | RED observed |
|---|---|---|---|
| AC-001 | PASS | `app.test.ts` — "drafts an intake without creating a task" (6 rows) | M4: (1)-(5) `expected 404 to be 200/400`; (6) 401 passed before (auth hook) |
| AC-002 | PASS | `app.test.ts` — "refuses intake while shutting down" | M4: `expected 404 to be 503` |
| AC-003 | PASS | `callService.test.ts` — "intake has no side effects and logs no request text" | M4: `calls.draftIntake is not a function` |
| AC-004 | PASS | `intake.test.ts` — "finds Korean phone numbers in free text" (18 rows) | M2: `Cannot find module './intake.js'` |
| AC-005 | PASS | `callService.test.ts` — "never proposes a blocked number, even from history" (2) | M4 |
| AC-006 | PASS (vector note) | `callService.test.ts` — "finds the number of a counterparty who answered before" (5 rows + stored-number-blocked case) | M4. Row 4 asserts `+8229999999` (policy value for `02-999-9999`); design.md lists `+82299999999` — SPEC vector typo, see M4 |
| AC-007 | PASS | `intake.test.ts` — "masks number-shaped text before it reaches the LLM" (6); `callService.test.ts` — "masks numbers before calling the LLM", "uses only numbers from the text or history"; `openaiBrain.test.ts` — "sends the text it receives unchanged" | M2 (masking) / M3 (brain) / M4 (service) |
| AC-008 | PASS | `callService.test.ts` — "post-processes LLM intake content in the service" (3); `openaiBrain.test.ts` — "returns schema-validated intake content unchanged" (3) | M3 / M4 |
| AC-009 | PASS | `openaiBrain.test.ts` — "falls back visibly when the intake LLM fails" (6), "bounds the intake LLM call below the app timeout" | M3: `draftIntake is not a function` |
| AC-010 | PASS | `heuristicBrain.test.ts` — "drafts intake content without an LLM" (6) | M3 |
| AC-011 | PASS | `callService.test.ts` — "matches the longest known counterparty name" | M4 |
| AC-012 | PASS | `callService.test.ts` — "lists missing fields in a fixed order"; `app.test.ts` AC-001 (1)(2) | M4 |
| AC-013 | PASS | `app.test.ts` — "accepts an optional autoStart flag" | M1: `expected undefined to be true` |
| AC-014 | PASS | `callService.test.ts` — "starts the call once planning finishes when autoStart is set", "auto-started calls open with the template AI disclosure"; `app.test.ts` — "auto-starts a simulated call without approve-plan" | M1 |
| AC-015 | PASS | `callService.test.ts` — "records why an auto start was blocked…", "records daily_limit…", "records shutting_down…", "records auto_start_failed…" | M1 |
| AC-016 | PASS | `callService.test.ts` — "never auto-starts outside the planning completion" | M1: passed before GREEN (negative guard; no trigger existed yet) |
| AC-017 | PASS | `intake_flow_test.dart` — "home sends one line to intake" (+ settings-first, manual-form cases) | M6 |
| AC-018 | PASS | `intake_flow_test.dart` — "suggests recent counterparties and templates" (+ no-tasks case); `unit_test.dart` — "derives recent counterparties", "normalizes names like the server" | M6 |
| AC-019 | PASS | `plan_card_test.dart` — "shows the draft and edits rows in place" (2 cases) | M5: compile error (`intake_models.dart` missing) |
| AC-020 | PASS | `plan_card_test.dart` — "asks for the number once" (3 cases) | M5 |
| AC-021 | PASS | `plan_card_test.dart` — "starts the call with one tap (1)…(6)" | M5 |
| AC-022 | PASS | `intake_flow_test.dart` — "falls back to a blank plan card on older servers" (2 cases) | M6 |
| AC-023 | PASS | `plan_card_test.dart` — "explains a blocked auto start on the detail screen (1)-(3)"; `unit_test.dart` — "parses autoStartBlocked defensively" | M5 |
| AC-024 | PASS | full server and app suites, `architecture.test.ts`, existing-test diff above, "the manual form never auto-starts" | n/a (regression) |

### Addendum — residual risks (audit request; still true at HEAD `ab029ec`)

- Over-masking: the 15xx/16xx/18xx shape also matches amounts such as `15000000원` (`1500` + `0000`), so the LLM receives `[전화번호]원` and the goal loses the amount; a 0-leading order number such as `0123-4567-8901` matches the domestic candidate shape, is masked, and is proposed as a number whenever `checkTargetNumber` returns `ok`. Both are visible on the plan card and editable. Not exercised by a test in this run.
- The first call on a device passes both the plan-card confirmation ([이대로 시작]) and the first-run trust acknowledgement (SPEC-FOLLOWUP-001 REQ-014, not yet implemented) — one extra tap on the first call relative to owner decision 3. To be surfaced in sync-phase docs.
- SPEC vector defect: design.md §3.4 history row 4 value (see M4).

## §E.3 Run-phase Audit-Ready Signal

```yaml
run_complete_at: 2026-11-22
run_start_sha: 42e2f169ab9dea50f6ff7533979afd070417b260
run_commit_sha: ab029ec   # last implementation commit (M6); the M7 commit that carries this section is evidence-only
run_status: complete
ac_pass_count: 24
ac_fail_count: 0
ac_notes: "AC-006 row 4 asserts the checkTargetNumber value (+8229999999); design.md vector typo reported"
milestone_commits: [1d778c2, f1e0e3f, ec0cd36, 9c6a1e8, 27c0fb0, ab029ec]
server_tests: "14 files / 370 tests passed (baseline 13 / 293)"
server_typecheck_exit: 0
test_file_compile_exit: 0
architecture_test: "4 passed, unmodified"
app_tests: "+53 passed (baseline +25)"
app_analyze: "1 info (baseline info, fakes.dart:54)"
existing_tests_modified: false
new_warnings_or_lints_introduced: 0
total_run_phase_files: 28   # 26 planned + spec.md + progress.md
m1_to_mN_commit_strategy: "one commit per milestone on the worktree branch; no push, no amend"
l44_pre_commit_fetch: not-run   # isolated worktree; no fetch/push requested
l44_post_push_fetch: not-applicable   # no push
cross_platform_build: not-applicable   # TypeScript + Flutter tests only; no device or platform build run
external_services_contacted: none   # OpenAI and KAT were never called; fetch was stubbed
```

## §E.4 Sync-phase Audit-Ready Signal

```yaml
sync_complete_at: 2026-11-27
sync_commit_sha: "the docs(SPEC-INTAKE-001) sync commit that adds this section (resolve via git log)"
sync_status: implemented
run_commit_sha: ab029ec   # §E.3 value: last implementation commit (M6) on worktree branch worktree-agent-a5729f8126e4d139f
run_commit_sha_on_main: e34808a   # the same M6 landed on main as e34808a (git diff --quiet ab029ec e34808a -> exit 0, identical tree); M7 evidence commit -> d161cab on main
run_start_sha: 42e2f169ab9dea50f6ff7533979afd070417b260   # SPEC-APPROVAL-001 M6 evidence commit on main
depends_on_note: "depends_on SPEC-APPROVAL-001 was `in-progress` when this run started; it closes at `implemented` in the sync commit just before this one (this repository's terminal value is `implemented`, see SPEC-UX-001 §E.4 sync-audit C1)"
sync_evidence_source: orchestrator   # measured by the orchestrator on HEAD 8ad8239 on 2026-11-27, not by this agent; evidence under .moai/state/verify/coverage/ (gitignored, local only)
app_tests_at_sync: "00:08 +84: All tests passed!"   # cd app && flutter --suppress-analytics test --coverage
app_line_coverage_at_sync: "1497/1689 = 88.6% (app + kolbi_core + kolbi_ui, from app tests; combined.lcov)"
server_tests_at_sync: "Tests 387 passed (387); Lines 95.42% (1085/1137), Statements 92.3%, Branches 81.49%, Functions 91.66%"   # npx vitest run --coverage (server.txt)
server_typecheck_exit_at_sync: 0   # npm --prefix server run typecheck
web_build_at_sync: "✓ Built build/web"   # cd app && flutter build web --debug
browser_run_at_sync: "web build against a simulated server (CALL_PROVIDER=simulated, no .env): home -> 내 정보 -> plan card (이렇게 걸어 볼게요) -> trust notice -> live call with transcript; browser console: no errors"
acceptance_distinct_ac_ids: 24   # grep -oE 'AC-([A-Z0-9]+-)*[0-9]+' acceptance.md | sort -u | wc -l -> 24 = §E.3 ac_pass_count 24
ac_matrix_test_names_at_sync: all-present   # every test name cited in the §E.2 AC matrix found by grep -F in server/src or app/test at HEAD 8ad8239
frontmatter_status_transitions:
  spec.md: in-progress -> implemented   # updated: 2026-11-22 -> 2026-11-27; spec/plan/acceptance/design bodies unchanged
changelog_entry_position: not-applicable   # repository has no CHANGELOG.md
mx_scan: skipped   # --skip-mx semantics
divergence:
  planned_vs_changed_files: match   # git diff --name-only 42e2f16..e34808a = the 26 files of plan.md §B (14 server + 12 app) + spec.md + progress.md; no unplanned file, no planned-but-unchanged file
  deviations: "§E.2 M4 AC-006 row 4 asserts +8229999999 (checkTargetNumber value for 02-999-9999) where design.md §3.4 lists +82299999999; M6 home draws a TextField look-alike while its route is not current so existing tests stay unmodified; CallBrain.draftIntake is optional"
  spec_vector_defect_open: "design.md §3.4 history row 4 value; for manager-spec (spec body not edited in sync)"
later_changes:   # history not rewritten; paths below are the current locations at 8ad8239
  SPEC-FOLLOWUP-001: "intake_models.dart (PlanDraft.fromTask, PhoneSource.previousCall), call_models.dart (appointment), plan_card_screen.dart and call_detail_screen.dart (trust gate, follow-up actions), plan_card_test.dart (one setup line, AC-016), unit_test.dart, server prompts.ts/openaiBrain.ts/types.ts/brain tests"
  SPEC-UX-001: "home_screen.dart, plan_card_screen.dart and call_detail_screen.dart restyled (tokens, AppCard, plain status labels)"
  SPEC-MODULE-001: "app/lib/features/calls/domain/{call_models,intake_models,counterparties}.dart are now re-exports of packages/kolbi_core/lib/src/models/; CallsRepository moved to packages/kolbi_core/lib/src/data/calls_repository.dart (app keeps the providers in calls_repository.dart); screens and app_router.dart stay in the app"
device_check: not-run   # §E.3 cross_platform_build not-applicable; no device run at sync (no Xcode/simulator on this Mac)
residual_risks_carried: "over-masking of amounts like 15000000원 and 0-leading order numbers (visible and editable on the plan card, not tested); the first call on a device passes two confirmations (plan card [이대로 시작] + trust notice [확인했어요]), a small gap from owner decision 3"
project_docs_synced: [.moai/project/structure.md, .moai/project/codemaps/modules.md, .moai/project/codemaps/entry-points.md, .moai/specs/EPIC-ASSISTANT-UX/overview.md]   # domain/intake.ts, plan_card_screen.dart, /plan route, POST /v1/intake; committed once for the three SPECs in the docs(SPEC-ASSISTANT-UX) commit that follows the FOLLOWUP sync commit
tech_md: unchanged   # no new dependency
sync_audit: pending
```
