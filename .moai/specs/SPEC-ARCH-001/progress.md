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

### Milestone log

- M1 done (commit: see git log `feat(SPEC-ARCH-001): M1`)
- M2 done (commit: see git log `feat(SPEC-ARCH-001): M2`)
- M3 done (commit: see git log `feat(SPEC-ARCH-001): M3`)
- M4 done (commit: see git log `feat(SPEC-ARCH-001): M4`)
- next: M5

## §E.3 Run-phase Audit-Ready Signal

_<pending run-phase>_

## §E.4 Sync-phase Audit-Ready Signal

_<pending sync-phase>_
