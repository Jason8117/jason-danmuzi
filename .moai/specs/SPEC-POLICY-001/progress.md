# SPEC-POLICY-001 진행 기록

## §E.1 Plan-phase Audit-Ready Signal

- plan_status: revised after plan-audit iteration 2 (FAIL 0.88) — re-audit pending
- plan_complete_at: 2026-11-21
- artifacts: spec.md, plan.md, acceptance.md, research.md
- counts: 11 REQ / 11 AC
- depends_on: SPEC-LIFECYCLE-001
- open_decisions: OD-1 RESOLVED (owner); OD-2 DEFAULT (pending owner review)
- run-entry note: manager-develop records `run_start_sha` (HEAD at run entry) as the first line of §E.2 (used by AC-011)

## §E.2 Run-phase Evidence

run_start_sha: 6ffe4ba0904444fb9db41bc2c2ebc61a9b9dd008

- run started: 2026-11-21, manager-develop, cycle_type=tdd, harness standard
- worktree: `.claude/worktrees/agent-a2f6355898e7ce23b` (branch `worktree-agent-a2f6355898e7ce23b`, fast-forwarded to `6ffe4ba`)
- evidence directory: `.moai/state/verify/policy-run/policy/` (worktree-local)

### Baseline (this run, HEAD 6ffe4ba)

| Command | Result |
|---------|--------|
| `npm --prefix server test` | exit 0 — `Test Files  6 passed (6)` / `Tests  81 passed (81)` |
| `npm --prefix server run typecheck` | exit 0 — `tsc -p tsconfig.json --noEmit` (no diagnostics) |

### Milestone log

#### M1 — domain rule `checkTargetNumber` (AC-008, AC-009)

- RED: `npm --prefix server test -- src/domain/domain.test.ts` → exit 1
  ```
  TypeError: checkTargetNumber is not a function
   Test Files  1 failed (1)
        Tests  18 failed | 21 passed (39)
  ```
- GREEN: same command → exit 0
  ```
   Test Files  1 passed (1)
        Tests  39 passed (39)
  ```
- typecheck after GREEN: exit 0
- files: `server/src/domain/phone.ts`, `server/src/domain/domain.test.ts`

- commit: `d8ddb62`

#### M2 — enforce at creation (AC-001..AC-004)

- RED: `npm --prefix server test -- src/services/callService.test.ts` → exit 1
  ```
  AssertionError: expected '010-1234-5678' to be '+821012345678' // Object.is equality      (AC-001)
  AssertionError: expected undefined to match object { statusCode: 400, …(2) }             (AC-002 "12")
  AssertionError: expected undefined to match object { statusCode: 400, …(2) }             (AC-003 "119", "+82 112")
  AssertionError: expected '010 9999 8888' to be '+821099998888' // Object.is equality      (AC-004)
  AssertionError: expected 'abc' to be undefined // Object.is equality                      (AC-004)
  AssertionError: expected '' to be undefined // Object.is equality                         (AC-004)
   Test Files  1 failed (1)
        Tests  7 failed | 12 passed (19)
  ```
  (the "callback omitted" case already passed — protection case)
- GREEN: `npm --prefix server test` → exit 0 — `Test Files  6 passed (6)` / `Tests  107 passed (107)`; typecheck exit 0
- files: `server/src/services/callService.ts`, `server/src/services/callService.test.ts`

- commit: `e163fea`

#### M3 — re-check before dialing (AC-010)

- RED: `npm --prefix server test -- src/services/callService.test.ts` → exit 1
  ```
  FAIL ... approvePlan re-checks the number right before dialing
  AssertionError: promise resolved "{ id: 'blocked', version: 2, …(13) }" instead of rejecting
  FAIL ... approvePlan checks in the order shutting_down, state, number, limits
  AssertionError: expected Error: Too many calls are in progress { …(2) } to match object { statusCode: 400, …(2) }
   Test Files  1 failed (1)
        Tests  2 failed | 19 passed (21)
  ```
  (first test stops at its first assertion: the stored `+82119` task was dialed; (iii) answered 429 instead of 400. (i) 503 and (ii) 409 / 404 are protection items and were not the failing assertions.)
- GREEN: `npm --prefix server test` → exit 0 — `Test Files  6 passed (6)` / `Tests  109 passed (109)`; typecheck exit 0
- files: `server/src/services/callService.ts`, `server/src/services/callService.test.ts`

- commit: `8ee2463`

#### M4 — HTTP layer cleanup (AC-006, AC-007 (c)(d))

- RED: `npm --prefix server test -- src/http/app.test.ts` → exit 1
  ```
  FAIL  src/http/app.test.ts > CallMate API > rejects emergency numbers with blocked_number
  AssertionError: expected { error: 'invalid_phone', …(1) } to deeply equal { error: 'blocked_number', …(1) }
   Test Files  1 failed (1)
        Tests  1 failed | 8 passed (9)
  ```
  ("keeps invalid_request for schema violations" passed before and after — protection item)
- RED: `grep -c "normalizePhoneNumber\|isBlockedNumber\|invalid_phone\|blocked_number" server/src/http/app.ts` → `5`
- GREEN: `npm --prefix server test` → exit 0 — `Test Files  6 passed (6)` / `Tests  111 passed (111)`; typecheck exit 0; same grep → `0`
- files: `server/src/http/app.ts`, `server/src/http/app.test.ts`

- commit: `0136dc4`

#### M5 — regression check (AC-005, AC-007 (a)(b)(d), AC-011)

Final measurements against HEAD `0136dc4` (code-final tree; M5 adds only this evidence):

- `npm --prefix server test` → exit 0 — `Test Files  6 passed (6)` / `Tests  111 passed (111)` (baseline 81 + 30 new)
- `npm --prefix server run typecheck` → exit 0
- `npm --prefix server test -- src/services/callService.test.ts src/domain/domain.test.ts src/http/app.test.ts --reporter=verbose` → exit 0 — `Test Files  3 passed (3)` / `Tests  69 passed (69)`
- `git diff 6ffe4ba..HEAD -- server/src/http/app.test.ts server/src/domain/domain.test.ts server/src/services/callService.test.ts | grep -E "^-[^-]"` → only `-import { isBlockedNumber, maskPhoneNumber, normalizePhoneNumber } from "./phone.js";` (the import line widened to add `checkTargetNumber`; no existing assertion removed or edited)
- `git diff --stat 6ffe4ba..HEAD -- app/` → empty

### AC matrix

| AC | Status | Verification command | Actual output | RED observed |
|----|--------|----------------------|---------------|--------------|
| AC-001 | PASS | targeted verbose run | `✓ … create normalizes the target number` | M2: `expected '010-1234-5678' to be '+821012345678'` |
| AC-002 | PASS | targeted verbose run | `✓ … create rejects an invalid number without side effects` | M2: `expected undefined to match object { statusCode: 400, …(2) }` |
| AC-003 | PASS | targeted verbose run | `✓ … create blocks emergency and special numbers: 119` / `: +82 112` | M2: same `expected undefined to match object …` for both |
| AC-004 | PASS | targeted verbose run | `✓ … create normalizes or drops the callback number: 010 9999 8888` / `abc` / `` / `undefined` | M2: `'010 9999 8888'`, `'abc'`, `''` stored raw (omitted case was a protection item) |
| AC-005 | PASS | `grep -n "from \"../domain/phone.js\"" src/services/callService.ts`; `grep -n "^[[:space:]]*create(" src/services/callService.ts` | `3:import { checkTargetNumber, normalizePhoneNumber } from "../domain/phone.js";` / `217:  create(input: CallTaskInput): CallTask {` | first grep 0 matches at baseline (callService.ts had no phone.js import) |
| AC-006 | PASS | `grep -c "normalizePhoneNumber\|isBlockedNumber\|invalid_phone\|blocked_number" server/src/http/app.ts` | `0` | M4: `5` |
| AC-007 (a) | PASS | targeted verbose run | `✓ … plans, calls, pauses for approval and summarizes` (test body unchanged) | protection item |
| AC-007 (b) | PASS | targeted verbose run | `✓ … validates phone numbers` (test body unchanged) | protection item |
| AC-007 (c) | PASS | targeted verbose run | `✓ … rejects emergency numbers with blocked_number` | M4: `expected { error: 'invalid_phone', …(1) } to deeply equal { error: 'blocked_number', …(1) }` |
| AC-007 (d) | PASS | targeted verbose run | `✓ … keeps invalid_request for schema violations` | protection item (passed before and after) |
| AC-008 | PASS | targeted verbose run | 9 × `✓ … blocked in every notation: <input>` (119, 112, 182, (119), +82 119, +82-182, 0082-112, 0119, +82 112) | M1: `TypeError: checkTargetNumber is not a function` (18 failed) |
| AC-009 | PASS | targeted verbose run | 4 × `… is ok`, 4 × `… is invalid` (`+1 911`, ``, `abc`, `+12`), `keeps the block list unchanged`; existing `normalizes`/`rejects`/`blocks Korean emergency short codes` unchanged and passing | M1: same TypeError |
| AC-010 | PASS | targeted verbose run | `✓ … approvePlan re-checks the number right before dialing` / `✓ … approvePlan checks in the order shutting_down, state, number, limits` | M3: `promise resolved "{ id: 'blocked', …}" instead of rejecting`; (iii) `expected Error: Too many calls are in progress …` |
| AC-011 | PASS | `npm --prefix server test`; `npm --prefix server run typecheck`; `git diff --stat 6ffe4ba..HEAD -- app/` | `Tests  111 passed (111)` exit 0; typecheck exit 0; app/ diff empty | n/a |

Evidence files (worktree, gitignored): `.moai/state/verify/policy-run/policy/{baseline-*,m1-*,m2-*,m3-*,m4-*,final-*,bypass-probe}.txt`.

### Gaps

- Flutter `test`/`analyze` not run: no app file is in scope and `app/` diff is empty.
- No coverage tool configured in `server/package.json`; coverage % on modified files was not measured.
- No linter configured for the server; only `tsc --noEmit` ran.
- No real KAT call was placed; the dial path was exercised with a fake provider only.

### Residual risk (observed with `.moai/state/verify/policy-run/policy/probe.ts`, output `bypass-probe.txt`)

- `119-1234-5678` → `{"kind":"ok","e164":"+11912345678"}`, KAT receives `11912345678`; `+82 119 1234` → `+821191234`, KAT `01191234`. Long numbers starting with a short code are not blocked; whether the carrier routes them to 119 was not verified. Pre-existing normalization (REQ-011 keeps it; OD-2 excludes new rules).
- Full-width digits (`１１９`), zero-width space (`119​`), non-ASCII hyphens (`1‑1‑9`), `82119`, `00119`, `+820119`, `*119`, `tel:119` → `invalid` (rejected with `invalid_phone`, not `blocked_number`). Not dialable, so the rejection still holds; only the error code differs.

## §E.3 Run-phase Audit-Ready Signal

```yaml
run_complete_at: 2026-11-21
run_start_sha: 6ffe4ba0904444fb9db41bc2c2ebc61a9b9dd008
run_commit_sha: pending-backfill (M5 commit; code-final HEAD 0136dc4)
run_status: audit-ready
ac_pass_count: 11
ac_fail_count: 0
milestone_commits: [d8ddb62 M1, e163fea M2, 8ee2463 M3, 0136dc4 M4, M5 = this evidence commit]
tests: "6 files / 111 tests passed (baseline 6 / 81)"
typecheck_exit: 0
preserve_list_post_run_count: "existing test assertions in app.test.ts / domain.test.ts / callService.test.ts unchanged (only one import line widened)"
app_diff_since_run_start: empty
l44_pre_commit_fetch: not-run (worktree-local branch, no push per orchestrator instruction)
l44_post_push_fetch: not-applicable (no push)
new_warnings_or_lints_introduced: 0 (tsc only; no server linter configured)
cross_platform_build: not-applicable (TypeScript server, no platform-specific code)
total_run_phase_files: 8 (6 planned source/test files + spec.md status + progress.md)
m1_to_mN_commit_strategy: one commit per milestone on worktree branch, explicit pathspec staging, no push
```

## §E.4 Sync-phase Audit-Ready Signal

```yaml
sync_complete_at: 2026-11-21
sync_commit_sha: "the docs(SPEC-POLICY-001) sync commit that adds this section (resolve via git log)"
sync_status: implemented
main_branch_commits: [9e9dbae, 5c6306a, 4f20971, afb6805, b3528db]   # cherry-picked onto main; worktree SHAs cited in §E.2/§E.3 do not exist on main
run_commit_sha_on_main: afb6805   # corrected run_commit_sha (last implementation commit on main); §E.3 left untouched (run-phase owned)
acceptance_distinct_ac_ids: 11   # grep -oE 'AC-([A-Z0-9]+-)*[0-9]+' acceptance.md | sort -u | wc -l
server_tests_at_sync: "10 files / 182 passed (re-measured at facb660)"
server_typecheck_exit_at_sync: 0
frontmatter_status_transitions:
  spec.md: in-progress -> implemented   # updated: already 2026-11-21
changelog_entry_position: not-applicable   # repository has no CHANGELOG.md
mx_scan: skipped   # --skip-mx semantics
residual_risk:
  - "long numbers starting with a short code (e.g. 119-1234-5678 -> +11912345678) are NOT blocked; pre-existing normalization, follow-up SPEC candidate"
  - "non-+82 numbers reach KAT as bare digits"
```

## Audit-fix addendum

Source: independent sync audit `FIVE-SPECS-audit-1` finding **F1** (High). Fix cycle base `534a53e` (run_start_sha `534a53edfdf9efaecb6c142997d20ea6fd563319`); commit: `fix(SPEC-POLICY-001): ...` on the fix worktree branch (resolve via `git log --grep "fix(SPEC-POLICY-001)"`). Evidence: `.moai/state/verify/fix-audit-1/` (gitignored, local).

- Owner decision implemented: the number is judged by its FINAL dialed form. `toDomesticDialString` (moved from `katProvider.toKatPhoneNumber` into `domain/phone.ts`) is the single transformation; `toKatPhoneNumber` is now that same function (`katProvider.test.ts` asserts identity). `isBlockedNumber` judges the dialed string: leading `0` (all +82) -> exact national match (unchanged); no leading `0` (non-+82) -> blocked when it starts with a short code.
- RED (before fix, `f1-red.log`): `Tests 14 failed | 93 passed (107)` across domain/service/HTTP, e.g. `AssertionError: expected 201 to be 400` for `"119 1234 5678"`.
- GREEN (`f1-green.log`): `Test Files 10 passed (10)` / `Tests 210 passed (210)`; typecheck exit 0; test-file compile exit 0. AC-008/AC-009 rows unchanged and green.
- Newly blocked (sweep `f1-sweep.out`): inputs that normalize to `+1…` whose bare digits start with 112/113/114/117/118/119/122/125/182, incl. real NANP area codes 22x/25x/82x (e.g. `+1 225 …`, `+1 251 …`, `+1 828 …`) — KAT would dial them as domestic `122…`/`125…`/`182…` strings. No +82 number changed (010/011/016/019/02/031/051/064/0505/0507/070/080 and 1588/1544/1577/1600/1644/1800/1899 all still `ok`).
- NOT implemented (blocker returned to the orchestrator): rejecting `callbackNumber "112-0000-0000"` with HTTP 400 `blocked_number`. spec.md REQ-004 states the callback number is normalized or dropped to `undefined` and "새 거절 규칙을 만들지 않음"; AC-004 pins "어느 경우도 예외가 없다". A 400 on the callback number needs a manager-spec REQ-004/AC-004 amendment first. Callback behavior is unchanged (`"112-0000-0000"` -> stored `"+11200000000"`; the server never dials it).

## Callback-number decision addendum

Source: owner decision resolving the blocker above. A `callbackNumber` that the number policy classifies as blocked is DROPPED: it is stored as `undefined`, with no error and no 400, and the task is still created (201). This is consistent with REQ-004's "invalid callback numbers are stored as undefined". Fix cycle base `b140218` (run_start_sha `b140218beae0e8b1d5e9f4986ae1414ccef64630`); commit: `fix(SPEC-POLICY-001): drop blocked callback numbers` (resolve via `git log --grep "drop blocked callback numbers"`). Evidence: `.moai/state/verify/fix-hotfix-1/` (gitignored, local).

- Change: `CallService.create` passes the callback number through the same `checkTargetNumber` rule as the target number, via the private helper `allowedCallbackNumber`. `ok` keeps the E.164 value; `invalid` and `blocked` both become `undefined`. Valid and invalid callback numbers behave exactly as before, because the `ok` branch returns the same `normalizePhoneNumber` value.
- RED (`b-red.log`): `AssertionError: expected '+11200000000' to be undefined` / `expected '+11912345678' to be undefined` at service and HTTP level / `Tests 4 failed | 55 passed (59)`. `"119"` and `"+82 112"` were already `undefined` before the fix, because they fail E.164 normalization. They are kept as guard cases.
- GREEN (`b-green.log`, `final-test.log`): `Test Files 11 passed (11)` / `Tests 229 passed (229)`; typecheck exit 0; test-file compile exit 0. `"010 9999 8888"` still normalizes to `+821099998888`. The absent, `""` and `"abc"` cases are unchanged.
- Follow-up for manager-spec: the REQ-004 / AC-004 text in spec.md and acceptance.md does not yet say that blocked callback numbers are dropped. It needs a scope-doc update. spec.md, plan.md and acceptance.md were not edited in this cycle.
- Not changed: tasks loaded from the data file that already hold a blocked callback number (stored before this fix) keep it. `approvePlan` re-checks only the target number. The callback number is never dialed; it appears only as text in the agent prompt (`brain/prompts.ts`).

## Sync re-audit (round 2, 2026-11-27)

- sync_audit_round2: "PASS 87.3 (F1 fixed by f833092 and 50343ad; round-1 probes now return 400 blocked_number); remaining R1 REQ-004/AC-004 text does not yet say blocked callback numbers are dropped, R3 non-+82 numbers reach KAT as bare digits (known residual risk)"
- report: .moai/reports/sync-audit/FIVE-SPECS-audit-2.md
- status: implemented -> completed (owner decision 2026-11-27: sync-audited SPECs end at `completed`)
