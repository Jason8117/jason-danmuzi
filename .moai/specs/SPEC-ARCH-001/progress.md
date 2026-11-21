# SPEC-ARCH-001 진행 기록

## §E.1 Plan-phase Audit-Ready Signal

- plan_status: revised after plan-audit iteration 2 (FAIL 0.88) — re-audit pending
- plan_complete_at: 2026-11-21
- tier: L (20 files: 4 new, 15 modified, 1 moved)
- artifacts: spec.md, plan.md, acceptance.md, design.md, research.md
- counts: 22 REQ / 20 AC
- depends_on: SPEC-STORE-001, SPEC-LIFECYCLE-001, SPEC-POLICY-001, SPEC-OUTCOME-001
- open_decisions: OD-1, OD-2 DEFAULT (pending owner review)
- note: the brain dependency in `simulatedProvider.ts:2` is an extra finding outside the orchestrator's evidence list (design.md §3)
- run-entry note: manager-develop records `run_start_sha` (HEAD at run entry) as the first line of §E.2 (used by AC-020)

## §E.2 Run-phase Evidence

run_start_sha: b5bde14719593cf491672288d5bc5b6228da49e8

- run_started_at: 2026-11-21 (manager-develop, cycle_type=tdd, serial, worktree branch `worktree-agent-a2527d470421c1c38`)
- evidence directory: `.moai/state/verify/arch-run/arch/`
- resume rule: milestones are committed one by one; the "Milestone log" below names the last finished milestone and the next one to start.

### Baseline (this run, tree b5bde14)

| Check | Command | Observed |
|-------|---------|----------|
| server tests | `npm --prefix server test` | `Test Files 8 passed (8)` / `Tests 127 passed (127)` |
| server typecheck | `npm --prefix server run typecheck` | exit 0 |
| app tests | `cd app && flutter --suppress-analytics test` | `+16: All tests passed!` |
| app analyze | `cd app && flutter --suppress-analytics analyze` | `1 issue found` — info `use_null_aware_elements` at `test/support/fakes.dart:53:5` |

### RED baseline greps (this run, tree b5bde14)

| AC | Command | Observed |
|----|---------|----------|
| AC-001 | `grep -cE 'providers/kat\|KatCallProvider\|"/kat/"\|=== "kat"' src/http/app.ts` | `4` (lines 11, 19, 69, 109) |
| AC-006 | `grep -rn 'from "\.\./brain\|from "\.\./\.\./brain' src/providers` | 2 lines: `simulatedProvider.ts:2`, `realtimeBridge.ts:2` |
| AC-012 | `grep -cE 'Record<string, any>\|: any\b\|as any\b' katProvider.ts realtimeBridge.ts` | `5`, `2` (katProvider is 5, not the plan-time 4: SPEC-LIFECYCLE-001 added `let response: Record<string, any>` at :126; the target is 0 either way) |
| AC-013 | `grep -n 'provider: "simulated" \| "kat"\|name: "simulated" \| "kat"' src/domain/types.ts src/providers/types.ts` | 2 lines: `providers/types.ts:32`, `domain/types.ts:89` |

### M1 — provider route contract

- Protection run, before any production change (app.test.ts wired the KAT app with the old `kat` dep for this run only):
  `npm --prefix server test -- src/http/app.test.ts -t "simulation mode|KAT webhook contract|values for simulation and KAT"` → `Tests  3 passed | 12 skipped (15)`, exit 0 (`m1-protect-pre.txt`).
- RED (`npm --prefix server test -- src/architecture.test.ts src/http/app.test.ts`, exit 1, `m1-red.txt`):
  ```
  × http layer does not know concrete providers      AssertionError: expected [ …(4) ] to deeply equal []
  × keeps the KAT webhook contract                   TypeError: kat.routes is not a function
  × serves /v1/config values for simulation and KAT  TypeError: kat.routes is not a function
  × serves /v1/config from wiring-provided provider info  expected { provider: 'kat', …(2) } to deeply equal { provider: 'kat', …(2) }
  × registers provider-declared routes with raw bodies    AssertionError: expected 404 to be 202
  × refuses provider routes under /v1/
  Tests  6 failed | 10 passed (16)
  ```
- GREEN: same command → `Tests  16 passed (16)`, exit 0 (`m1-green.txt`); full suite `Test Files 9 passed (9)` / `Tests 134 passed (134)` (`m1-full.txt`); typecheck exit 0; AC-001 grep → `0`.
- Plan deviation (recorded): `container.ts` / `index.ts` wiring moved from M6 into M1, because removing `AppDeps.kat` breaks `npm run typecheck` until the wiring changes.

### M2 — session-provided agent instructions

- RED (`npm --prefix server test -- src/architecture.test.ts src/services/callService.test.ts`, exit 1, `m2-red.txt`):
  ```
  × the realtime bridge does not import brain            AssertionError: expected [ Array(1) ] to deeply equal []
  × session exposes the agent instructions for its task  TypeError: session.agentInstructions is not a function
  Tests  2 failed | 22 passed (24)
  ```
- GREEN: full suite `Test Files 9 passed (9)` / `Tests 136 passed (136)`, exit 0 (`m2-full.txt`); typecheck exit 0.
- The bridge reads `session.agentInstructions()` once at bridge start (same moment it already took the `session.task()` snapshot), so the string sent on every (re)connect is unchanged. The bridge-side AC-007 assertion lands in M3 with the WebSocket injection point.
- Plan deviation (recorded): the AC-006 rule for all of `providers/**` cannot pass until `scenario.ts` moves (M5). M2 asserts only the bridge file so the M2 commit stays green; the full rule is added (RED → GREEN) in M5.

### M3 — bridge injection point, bridge tests, Realtime validation

- Step 1: `createSocket?: RealtimeSocketFactory` added to `bridgeToRealtime` (default `new WebSocket(url, options)`); no other change.
- Protection + RED, run on the step-1 tree (`npm --prefix server test -- src/providers/realtimeBridge.test.ts`, exit 1, `m3-protect-red.txt`):
  ```
  9 AC-015 (a)~(i) + AC-007 bridge tests: pass (protection)
  × validates handled realtime events and ignores the rest   AssertionError: expected [ { event: 'media', …(2) } ] to deeply equal []
  × ignores malformed KAT media frames without logging       AssertionError: expected [ { …(2) } ] to deeply equal []   (+ "audio": 42, "type": "input_audio_buffer.append")
  Tests  2 failed | 9 passed (11)
  ```
- GREEN: `realtimeEvents.ts` (handled-event schemas, `ApprovalToolArgs`) and the media/stop frame schema in `kat/schemas.ts`; same command → `Tests  11 passed (11)` (`m3-green.txt`); full suite `Test Files 10 passed (10)` / `Tests 147 passed (147)` (`m3-full.txt`); typecheck exit 0; `grep -cE 'Record<string, any>|: any\b|as any\b' src/providers/realtimeBridge.ts` → `0`.
- AC-015 (h) also pins the `"Realtime handshake rejected"` warn payload: `{ taskId, status: 401, body: <first 400 chars>, attempt: 1|2 }` (spec.md §4 exception kept).

### M4 — KAT input validation and tests

- Step 1: `KatOptions.bridge?` injection point (defaults to `bridgeToRealtime`); no other change.
- Protection + RED on the step-1 tree (`npm --prefix server test -- src/providers/kat/katProvider.test.ts src/architecture.test.ts`, exit 1, `m4-protect-red.txt`). Protection tests that passed on the old code: AC-016 (a)~(f) (incl. 5 failure statuses), AC-017 (a)~(d), AC-008 (1)~(6), the orphan-stream exception with a malformed start frame, and all pre-existing SPEC-LIFECYCLE-001 AC-014 tests. RED:
  ```
  × no any for external data                                      AssertionError: expected [ …(5) ] to deeply equal []
  × parses KAT API responses safely (7) 500 with a null body      expected a thrown error to be Error: KAT Cloud POST /group/g-1/media-st…  + TypeError {
  × parses KAT API responses safely (8) 200 with a null body      expected a thrown error to be Error: KAT Cloud did not return a callId  + TypeError {
  × ignores malformed status webhooks                             AssertionError: expected [] to deeply equal [ …(4) ]
  × ignores malformed media frames and keeps waiting for start    expected "vi.fn()" to not be called at all, but actually been called 1 times
  Tests  5 failed | 44 passed (49)
  ```
  Cases (7)/(8) are additions to the AC-008 table: they are the concrete REQ-009 (b) defect (a `null` body threw `TypeError` instead of the KAT error).
- GREEN: zod parsing in `katProvider.ts` with schemas in `kat/schemas.ts`; full suite `Test Files 10 passed (10)` / `Tests 173 passed (173)` (`m4-full.txt`); typecheck exit 0; AC-012 grep → `src/providers/realtimeBridge.ts:0`, `src/providers/kat/katProvider.ts:0`.
- `app.test.ts` "answers signed but malformed status webhooks with 204" (AC-009 route half) was added after the GREEN change; the route returned 204 for any signed body before this SPEC as well (handler code read at b5bde14: `kat.handleStatusWebhook(...); return reply.status(204).send();`), so it is a protection test without its own pre-change run — recorded as a gap.
- Targeted: `npm --prefix server test -- src/architecture.test.ts src/http/app.test.ts src/providers/kat/katProvider.test.ts` → `Test Files 3 passed (3)` / `Tests 65 passed (65)` (`m4-green.txt`).

### M5 — scenario move and provider id type

- RED (`npm --prefix server test -- src/architecture.test.ts src/services/callService.test.ts`, exit 1, `m5-red.txt`):
  ```
  × providers do not import brain   AssertionError: expected [ Array(1) ] to deeply equal []
  + "providers/simulatedProvider.ts:2: import { detectScenario, SCENARIO_TEMPLATES } from \"../brain/scenario.js\";"
  Tests  1 failed | 26 passed (27)
  ```
  The same run shows the AC-013 protection test "accepts any provider id" passing on the old code, as acceptance.md predicts (vitest strips types).
- AC-013 RED is the grep recorded in the baseline table (2 lines). App protection before any app change: `flutter --suppress-analytics test test/unit_test.dart` → `+11: All tests passed!`, exit 0 (`m5-app-unit-pre.txt`; the new "treats unknown providers as real calls" test passes with no app code change).
- GREEN: `git mv server/src/brain/scenario.ts server/src/domain/scenario.ts` (content byte-identical — its `../domain/types.js` import still resolves from `domain/`; no re-export left behind), importers updated; `ProviderId = string` in `domain/types.ts`, used by `CallTask.provider` and `CallProvider.name`; `SIMULATED_PROVIDER_ID` / `KAT_PROVIDER_ID` constants (`satisfies ProviderId`). `config.ts` `CALL_PROVIDER` enum unchanged.
- Results: typecheck exit 0; full suite `Test Files 10 passed (10)` / `Tests 176 passed (176)` (`m5-full.txt`); AC-013 grep → no output (exit 1); AC-006 grep → no output (exit 1); app `flutter test` → `+17: All tests passed!`; `flutter analyze` → `1 issue found` (the same baseline info at `test/support/fakes.dart:53:5`).

### M6 — remaining test gaps and regression

- M6 changes no production code (the wiring moved to M1), so its tests are protection tests run on the code they protect: `npm --prefix server test -- src/http/app.test.ts src/brain/openaiBrain.test.ts` → `Tests  31 passed (31)`, exit 0 (`m6-protect.txt`). New: `/v1/stream` "streams snapshots and task updates" + "rejects stream connections without a token" (AC-019), `openaiBrain` "validates LLM plans against schema bounds" (1)~(4) (AC-018).
- Final regression batch (this run, tree at the M6 commit's content):
  - `npm --prefix server test` → `Test Files 10 passed (10)` / `Tests 182 passed (182)`, exit 0 (`final-server-test.txt`)
  - `npm --prefix server run typecheck` → exit 0 (`final-typecheck.txt`)
  - acceptance.md common command (5 files) → `Test Files 5 passed (5)` / `Tests 92 passed (92)`, exit 0 (`final-targeted.txt`)
  - informational: `tsc -p .moai/state/verify/arch-run/arch/tsconfig.tests.json` (server tsconfig with `*.test.ts` included, 10 test files listed) → exit 0, 0 `error TS` (`final-tsc-tests.txt`)
  - app `flutter --suppress-analytics test` → `+17: All tests passed!`; `test/unit_test.dart` → `+11: All tests passed!`; `flutter --suppress-analytics analyze` → `1 issue found` (baseline info only)

### Milestone log

- M1 done (commit: see git log `feat(SPEC-ARCH-001): M1`)
- M2 done (commit: see git log `feat(SPEC-ARCH-001): M2`)
- M3 done (commit: see git log `feat(SPEC-ARCH-001): M3`)
- M4 done (commit: see git log `feat(SPEC-ARCH-001): M4`)
- M5 done (commit: see git log `refactor(SPEC-ARCH-001): M5`)
- M6 done (commit: see git log `test(SPEC-ARCH-001): M6`)
- run complete; this section and §E.3 are the evidence-only commit after M6.

### Commits

| Milestone | SHA | Subject |
|-----------|-----|---------|
| M1 | d639504 | feat(SPEC-ARCH-001): M1 provider-declared route contract |
| M2 | 6616576 | feat(SPEC-ARCH-001): M2 inject agent instructions through the call session |
| M3 | d5231e3 | feat(SPEC-ARCH-001): M3 test the realtime bridge and validate its inputs |
| M4 | 0309075 | feat(SPEC-ARCH-001): M4 validate KAT API responses, webhooks and start frames |
| M5 | 01ef45e | refactor(SPEC-ARCH-001): M5 move scenario templates to domain and widen provider ids |
| M6 | 4e68152 | test(SPEC-ARCH-001): M6 cover /v1/stream and the LLM plan path |

### AC matrix

All "final" observations come from the final regression batch at 4e68152 (`final-*.txt`); RED/protection observations are the per-milestone runs above.

| AC | Status | Verification | Observed | RED / protection |
|----|--------|--------------|----------|------------------|
| AC-001 | PASS | architecture.test "http layer does not know concrete providers"; `grep -cE 'providers/kat\|KatCallProvider\|"/kat/"\|=== "kat"' src/http/app.ts` | test passes; grep `0` | RED: grep `4`; test `expected [ …(4) ] to deeply equal []` (M1) |
| AC-002 | PASS | app.test "registers provider-declared routes with raw bodies" | passes (raw `{"a": 1,  "b":2}` byte-equal, also with `?x=1`; undeclared route gets no raw body; socket route attached) | RED: `expected 404 to be 202` (M1) |
| AC-003 | PASS | app.test "registers no provider routes in simulation mode" | passes | protection: passed before M1 change |
| AC-004 | PASS | app.test "keeps the KAT webhook contract" | passes: 401 `{"error":"invalid_signature"}`, 204 without API token, 204 with query string | protection: passed on old `kat` wiring before M1 |
| AC-005 | PASS | app.test "serves /v1/config values for simulation and KAT deployments" + "serves /v1/config from wiring-provided provider info" | both pass | values: protection (pre-M1 pass); wiring: RED `expected { provider: 'kat', …(2) } to deeply equal …` (M1) |
| AC-006 | PASS | architecture.test "providers do not import brain" + "the realtime bridge does not import brain"; `grep -rn 'from "\.\./brain\|from "\.\./\.\./brain' src/providers` | tests pass; grep no output (exit 1); `src/brain/scenario.ts` absent | RED: bridge test (M2), full rule `simulatedProvider.ts:2` (M5) |
| AC-007 | PASS | callService.test "session exposes the agent instructions for its task"; realtimeBridge.test "(a) sends session-provided instructions…" | both pass; bridge sends the session's unique string, `agentInstructions` called once | RED: `TypeError: session.agentInstructions is not a function` (M2) |
| AC-008 | PASS | katProvider.test "parses KAT API responses safely" (1)~(8) | all 8 pass | (1)~(6) protection (pre-M4 pass); (7)(8) null bodies RED `TypeError` (M4) |
| AC-009 | PASS | katProvider.test "ignores malformed status webhooks"; app.test "answers signed but malformed status webhooks with 204" | 0 session calls, 4 warns `Ignored malformed KAT status webhook` with `{}` payload; route 204 | RED: `expected [] to deeply equal [ …(4) ]` (M4); route-204 test has no pre-change run (gap) |
| AC-010 | PASS | katProvider.test "ignores malformed media frames and keeps waiting for start" + "still terminates a signed stream with no active session before looking at a malformed start frame" + LIFECYCLE AC-014 (a)~(d) unchanged | all pass | RED: malformed start was bridged (`markConnected` called) (M4); orphan exception protection passed pre-change |
| AC-011 | PASS | realtimeBridge.test "validates handled realtime events and ignores the rest" + "ignores malformed KAT media frames without logging" | both pass | RED: `payload: undefined` media frame sent; `"audio": 42` forwarded (M3) |
| AC-012 | PASS | architecture.test "no any for external data"; `grep -cE 'Record<string, any>\|: any\b\|as any\b' …` | test passes; `realtimeBridge.ts:0`, `katProvider.ts:0` | RED: baseline `5`, `2`; test `expected [ …(5) ]` (M4) |
| AC-013 | PASS | `grep -n 'provider: "simulated" \| "kat"\|name: "simulated" \| "kat"' src/domain/types.ts src/providers/types.ts`; typecheck; callService.test "accepts any provider id" | grep no output (exit 1); typecheck exit 0; test passes | RED: grep 2 lines (baseline); test is protection (passed pre-change, as acceptance.md says) |
| AC-014 | PASS | `flutter --suppress-analytics test test/unit_test.dart` ("treats unknown providers as real calls") | `+11: All tests passed!` | protection: passed with no app code change |
| AC-015 | PASS | realtimeBridge.test (a)~(i), 9 tests | all pass | protection: passed right after the injection point, before zod (M3) |
| AC-016 | PASS | katProvider.test AC-016 (a)~(f) (e = 5 statuses) | all pass | protection: passed before M4 change |
| AC-017 | PASS | katProvider.test AC-017 (a)~(d) | all pass | protection: passed before M4 change |
| AC-018 | PASS | openaiBrain.test "validates LLM plans against schema bounds" (1)~(4) | all pass; warn `{ op: "plan", reason: "schema_mismatch" }` | protection (M6, no production change) |
| AC-019 | PASS | app.test "streams snapshots and task updates" + "rejects stream connections without a token" | both pass; 401 → `Unexpected server response: 401` | protection (M6, no production change) |
| AC-020 | PASS | `npm --prefix server test`; typecheck; `flutter test`; `flutter analyze`; `git diff --stat <run_start_sha>..HEAD -- server/src/events/` | `Tests 182 passed (182)`; exit 0; `+17: All tests passed!`; `1 issue found` (baseline); events diff empty | removed lines in pre-existing test files: only 2 import lines (widened) and the `FakeProvider` constructor type (`"simulated" \| "kat"` → `ProviderId`); no test body changed |

| Invariant | Status | Observed |
|-----------|--------|----------|
| No network in tests (KAT/OpenAI) | PASS | all KAT calls go through injected `fetch`; bridge uses injected socket factory; openaiBrain uses `vi.stubGlobal("fetch")` |
| No new runtime dependency | PASS | `server/package.json` unchanged in `git diff --stat b5bde14..HEAD` |
| Providers do not depend on Fastify | PASS | `grep -rn 'fastify' src/providers` → no output |
| Handshake-rejected log keeps the 400-char body (spec.md §4 exception) | PASS | AC-015 (h) asserts `body: "x".repeat(400)` for both attempts |

## §E.3 Run-phase Audit-Ready Signal

```yaml
run_complete_at: 2026-11-21
run_start_sha: b5bde14719593cf491672288d5bc5b6228da49e8
run_commit_sha: 4e68152b9815fe9764e144be4329346487cf2e12   # last implementation commit (M6); this evidence commit follows it
run_status: audit-ready
ac_pass_count: 20
ac_fail_count: 0
preserve_list_post_run_count: 0   # no PRESERVE list in plan.md; prior-SPEC behavior pinned by the unchanged pre-existing tests
l44_pre_commit_fetch: not-run     # worktree branch, no push requested
l44_post_push_fetch: not-run      # no push requested
new_warnings_or_lints_introduced: 0   # tsc exit 0; flutter analyze 1 info = baseline
cross_platform_build:
  server_typecheck: pass
  server_tests: "10 files / 182 tests pass"
  app_tests: "17 pass"
  app_analyze: "1 info (baseline, test/support/fakes.dart:53)"
total_run_phase_files: 20   # plus spec.md and progress.md
m1_to_mN_commit_strategy: one commit per milestone (M1-M6) on the worktree branch, then one evidence-only commit
plan_deviations:
  - "container.ts / index.ts wiring done in M1 instead of M6 (typecheck would break otherwise)"
  - "AC-006 full providers/** rule added in M5; M2 asserted the bridge file only, to keep every commit green"
  - "AC-008 gained cases (7)(8) (null bodies) as the concrete REQ-009 (b) RED"
open_decisions: "OD-1, OD-2 implemented as DEFAULT (pending owner review)"
```

## §E.4 Sync-phase Audit-Ready Signal

```yaml
sync_complete_at: 2026-11-21
sync_commit_sha: "the docs(SPEC-ARCH-001) sync commit that adds this section (resolve via git log)"
sync_status: implemented
main_branch_commits: [3371a77, 7b7d01a, 6b749b8, f679d04, 847cd38, eeea230, facb660]   # cherry-picked onto main; worktree SHAs cited in §E.2/§E.3 do not exist on main
run_commit_sha_on_main: eeea230   # corrected run_commit_sha (last implementation commit on main); §E.3 left untouched (run-phase owned)
acceptance_distinct_ac_ids: 20   # grep -oE 'AC-([A-Z0-9]+-)*[0-9]+' acceptance.md | sort -u | wc -l
server_tests_at_sync: "10 files / 182 passed (re-measured at facb660)"
server_typecheck_exit_at_sync: 0
frontmatter_status_transitions:
  spec.md: in-progress -> implemented   # updated: already 2026-11-21
changelog_entry_position: not-applicable   # repository has no CHANGELOG.md
mx_scan: skipped   # --skip-mx semantics
```
