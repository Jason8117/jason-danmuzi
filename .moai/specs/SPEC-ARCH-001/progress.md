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

### Milestone log

- M1 done (commit: see git log `feat(SPEC-ARCH-001): M1`)
- next: M2

## §E.3 Run-phase Audit-Ready Signal

_<pending run-phase>_

## §E.4 Sync-phase Audit-Ready Signal

_<pending sync-phase>_
