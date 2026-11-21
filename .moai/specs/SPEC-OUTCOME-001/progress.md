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
- Commit: `fdb0626`

#### M5 — app outcome card

- RED `flutter --suppress-analytics test test/outcome_card_test.dart` (in `app/`, exit 1): `Expected: exactly one matching candidate` / `Actual: _TextWidgetFinder:<Found 0 widgets with text "자동 요약이라 목표를 이뤘는지 확인하지 못했어요. 대화 기록을 직접 확인해 …` / `00:00 +0 -1: shows an unverified outcome distinctly [E]` / `00:00 +1 -1: Some tests failed.` (the label already came from the M4 enum; the card still used the error icon and had no notice).
- GREEN `flutter --suppress-analytics test test/unit_test.dart test/outcome_card_test.dart` (exit 0): `+11: … outcome_card_test.dart: keeps the success presentation` / `00:00 +12: All tests passed!`
- Commit: `3bb4138`

#### M6 — regression (HEAD 3bb4138)

| Check | Command | Observed |
|-------|---------|----------|
| server tests | `npm --prefix server test` | exit 0 — `Test Files  8 passed (8)` / `Tests  127 passed (127)` (baseline 6 / 111; +16 new) |
| server typecheck | `npm --prefix server run typecheck` | exit 0 |
| app tests | `flutter --suppress-analytics test` (in `app/`) | exit 0 — `00:01 +16: All tests passed!` (baseline 13; +3 new) |
| app analyze | `flutter --suppress-analytics analyze app` | exit 1, info only — `info • … • app/test/support/fakes.dart:53:5 • use_null_aware_elements` / `1 issue found.` (= baseline) |
| REQ-013 grep | `grep -n "outcome" server/src/store/taskStore.ts server/src/services/callService.ts` | `taskStore.ts:137:` (a doc comment) and `callService.ts:475:      task.outcome = await this.brain.summarize(task);` — the only assignment |

### AC matrix

| AC | Status | Test / command | Actual output (this run) |
|----|--------|----------------|--------------------------|
| AC-001 | PASS | `heuristicBrain.test.ts` "every heuristic outcome declares its source"; `openaiBrain.test.ts` "a validated LLM outcome is marked as llm" | M2 GREEN `Tests  25 passed (25)`; M6 `Tests  127 passed (127)` |
| AC-002 | PASS | "never claims success without LLM verification" (3 cases) | as above |
| AC-003 | PASS | "keeps a verified failure when the callee never spoke" (2 cases) | as above |
| AC-004 | PASS | "labels the heuristic summary as unverified" | as above |
| AC-005 | PASS | "falls back visibly when the summary LLM fails" (6 cases: http_status+500, timeout, empty_content, invalid_json, schema_mismatch, network; log-leak assertions) | as above |
| AC-006 | PASS | "a validated LLM outcome is marked as llm" (`toEqual({...llm, source:"llm"})`, 0 warns) | as above |
| AC-007 | PASS | "logs which operation fell back during planning" | as above |
| AC-008 | PASS | "the LLM schema only accepts the three LLM result values" + typecheck | as above; typecheck exit 0 |
| AC-009 | PASS | `unit_test.dart` "parses outcome result and source, old and new"; existing "parses outcomes" unmodified; REQ-013 grep | `+6: … parses outcome result and source, old and new`; grep shows one assignment |
| AC-010 | PASS | `outcome_card_test.dart` "shows an unverified outcome distinctly", "keeps the success presentation" | `00:00 +12: All tests passed!` |
| AC-011 | PASS | `app.test.ts` "plans, calls, pauses for approval and summarizes" — only the two specified lines changed (`git diff b3528db -- server/src/http/app.test.ts`: 1 line replaced, 1 added) | M1 RED `Received: "success"`; M6 `127 passed` |
| AC-012 | PASS | full server suite, typecheck, flutter test, analyze | see M6 table |

## §E.3 Run-phase Audit-Ready Signal

```yaml
run_complete_at: 2026-11-21
run_commit_sha: 3bb4138a8414932a7f26b9171668f2f0c5774497  # last implementation commit (M5); the evidence-only M6 commit follows it
run_start_sha: b3528db9866edc2d32ea6907f81cc86190138671
run_status: audit-ready
ac_pass_count: 12
ac_fail_count: 0
milestone_commits: [0da933d (M1+M3), 608b896 (M2), fdb0626 (M4), 3bb4138 (M5), M6 evidence commit]
new_warnings_or_lints_introduced: 0  # flutter analyze = baseline 1 info; tsc exit 0
total_run_phase_files: 12  # 10 planned code/test files + spec.md (status) + progress.md
m1_to_mN_commit_strategy: one commit per milestone; M3 folded into M1 so no commit leaves the suite red
l44_pre_commit_fetch: not run (worktree branch, no push)
l44_post_push_fetch: not applicable (no push by instruction)
cross_platform_build: not applicable (TypeScript server + Flutter app; no platform build was run)
deviations:
  - M3 folded into M1 (AC-011 RED observed against the base heuristic before GREEN)
  - flutter test run as `cd <worktree>/app && flutter test` (flutter test has no project-directory flag); analyze used the path argument
gaps:
  - no real OpenAI call (by design); no app build or device run; evidence files under .moai/state/ are gitignored
```

## §E.4 Sync-phase Audit-Ready Signal

```yaml
sync_complete_at: 2026-11-21
sync_commit_sha: "the docs(SPEC-OUTCOME-001) sync commit that adds this section (resolve via git log)"
sync_status: implemented
main_branch_commits: [0c9eedb, 63974b0, 1278662, 06f7e3c, b5bde14]   # cherry-picked onto main; worktree SHAs cited in §E.2/§E.3 do not exist on main
run_commit_sha_on_main: 06f7e3c   # corrected run_commit_sha (last implementation commit on main); §E.3 left untouched (run-phase owned)
acceptance_distinct_ac_ids: 12   # grep -oE 'AC-([A-Z0-9]+-)*[0-9]+' acceptance.md | sort -u | wc -l
server_tests_at_sync: "10 files / 182 passed (re-measured at facb660)"
server_typecheck_exit_at_sync: 0
frontmatter_status_transitions:
  spec.md: in-progress -> implemented   # updated: already 2026-11-21
changelog_entry_position: not-applicable   # repository has no CHANGELOG.md
mx_scan: skipped   # --skip-mx semantics
residual_risk:
  - "older app builds render result 'unverified' as 'failed'; deploy server and app together"
  - "stored tasks keep their old results (no reclassification)"
```
