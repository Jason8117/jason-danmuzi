# SPEC-UX-001 진행 기록

## §E.1 Plan-phase Audit-Ready Signal

- plan_status: revised after plan-audit iteration 1 (PASS-with-fixes 0.86; D18, D19 fixed, D20, D21 applied) — re-audit pending
- spec_version: 0.3.0 (plan-audit iteration 2: FAIL 0.84 -> N5, N6, N7 fixed; A1 applied — injectable `now`, sendAnnouncement or a separate live-region node, jumpTo when motion is zero)
- plan_complete_at: 2026-11-21
- base_sha: c664596
- tier: M (file count 19 exceeds the M guidance; rationale in plan.md §B; auditor D23 accepted M), harness: standard (recommended)
- artifacts: spec.md, plan.md, acceptance.md, design.md, research.md, progress.md
- counts: 14 REQ / 15 AC
- depends_on: SPEC-FOLLOWUP-001 (last SPEC of EPIC-ASSISTANT-UX; order rationale in plan.md §A.0)
- open_decisions: OD-1 ~ OD-4 DEFAULT (pending owner review)
- note: app-only; no server or data-layer change (AC-014). Three task-status labels change by design (OD-3)
- run-entry note: manager-develop records `run_start_sha`, the measured test baseline and the AC-001 literal counts as the first lines of §E.2

## §E.2 Run-phase Evidence

run_start_sha: ba1ee1790078643628522a0402556c840f1e0169 (main, run on 2026-11-25 in the primary checkout, no push)

### Plan refresh before run (plan-audit iteration 3 not run as a separate agent)

The plan was written at c664596, before SPEC-APPROVAL/INTAKE/FOLLOWUP landed. Checked against ba1ee17 in the main session:
all 13 target Dart files in plan.md §B exist; every text/widget the ACs look for exists (`SectionCard`, `MessageView`,
`PulsingDot`, '최근 통화한 곳', '전화할 곳', '이대로 시작', '통화 중 결정한 것', '부탁한 일', '대화 내용', '다시 걸기',
'이대로 전화 걸기', '연결 테스트'); the Flutter 3.50.1 APIs the plan assumes exist
(`MediaQuery.supportsAnnounceOf` media_query.dart:2108, `SemanticsService.sendAnnouncement` semantics_service.dart:81,
`assert(duration > Duration.zero)` scroll_activity.dart:703). Owner approved the kickoff with "end-to-end autonomous".

### Baseline (run entry, HEAD ba1ee17, before any change)

```
$ cd app && flutter --suppress-analytics test        -> 00:02 +65: All tests passed!
$ cd app && flutter --suppress-analytics analyze     -> 1 issue (info, test/support/fakes.dart:54:5 use_null_aware_elements)
$ npm --prefix server test                           -> Test Files 14 passed (14) / Tests 387 passed (387)
$ grep -rn "'계획 중'\|'연결 중'\|'정리 중'" app/test -> (no output)
```

AC-001 literal lines at run entry (same grep as acceptance.md), 43 in total: home_screen 11, call_detail_screen 5,
common 5, app_theme 4, transcript_view 4, new_call_screen 3, plan_card_screen 3, trust_notice 3, approval_card 2,
status_chip 2, settings_screen 1, outcome_card 0, follow_up_actions 0.

### What changed (milestones M1 ~ M5 in one implementation commit — see "Deviations")

- M1 `core/theme/tokens.dart` (new): spacing/radius/motion/tap tokens, `motionDuration`, `scrollToOffset`
  (jumpTo when the duration is zero), WCAG `contrastRatio`. `app_theme.dart`: REQ-003 type scale, `CardTone`
  (neutral/attention/positive/caution/critical) and `live` color pairs per mode; `warning`/`callLive` removed.
- M2 `common.dart`: `AppCard` (header, body, action row, tone; attention draws the border), `SectionCard` kept as a thin
  wrapper with the same arguments, `MessageView` as the one empty state, `PulsingDot` stops under reduced motion.
- M3 approval card: attention tone, live region "승인 요청: <질문>" without seconds, seconds excluded from semantics,
  30 s / 10 s announcements (`sendAnnouncement`, or a separate live-region node when unsupported), injectable `now`,
  light haptic on a successful decision. Call detail: pinned area capped and scrollable, reduced-motion scrolls,
  empty transcript → `MessageView` "대화를 기다리고 있어요", follow-up actions moved into the result card's action row
  (REQ-013 order), busy progress on 취소 / 이대로 전화 걸기 / 통화 끊기.
- M4 home, plan card (row min height 48, pencil is an `IconButton` with tooltip "수정", progress on [이대로 시작] and
  light haptic on success), outcome card tones, follow-up progress (except 다시 걸기), transcript guidance pill,
  settings/new call/trust notice tokens.
- M5 status labels (OD-3), status chip `Semantics(container, label: '상태: …')`, cross-fade, label can wrap.

### RED/GREEN record (honest order)

The production code was written first and the new tests after it, so most new ACs have no recorded RED run before the
implementation. The failures the new tests did find on the implemented code (each fixed, then the test passed):

| Found by | Failure (verbatim summary) | Fix |
|----------|---------------------------|-----|
| existing approval_flow_test (unmodified) | `Bad state: No element` at `repo.decisions.single` — 승인 button pushed out of the 300 px pinned area at 800×600 | cap = 1/2 of the height only with enlarged text, 2/3 at normal size; quick replies back to one horizontal row |
| AC-011 | `A RenderFlex overflowed by 4.0 pixels on the right` — StatusChip row at 2× text (offset 12,4 = chip padding) | label is `Flexible` |
| AC-012 | `Found 0 widgets with a semantics label named "상태: 통화 중"` — chip label merged into the header node | `container: true` on the chip semantics |
| AC-006 scroll | `Expected: <1358.0> Actual: <2507.67>` — after the jump the lazily laid-out list re-estimated its end | settle on the real end for up to 3 frames (`_settleAtBottom`, both motion modes) |
| harness | ProviderScope overrides changed between screens; HTTP timer left pending | test-only fixes (fresh scope per screen, silent HTTP client) |

AC-009 (tap targets: android / iOS / labeled) and AC-010 (text contrast, light and dark, 5 screen variants) passed on
their first run against the implemented code ("처음부터 통과" after implementation, not before it).

### Final verification (this tree, evidence files in `.moai/state/verify/ux-run/`, gitignored — local only)

```
$ cd app && flutter --suppress-analytics test        -> 00:05 +80: All tests passed!            (app-test.txt)
$ cd app && flutter --suppress-analytics analyze     -> 1 issue found (same baseline info, fakes.dart:54:5) (analyze.txt)
$ npm --prefix server test                           -> Test Files 14 passed (14) / Tests 387 passed (387), exit 0 (server-test.txt)
$ npm --prefix server run typecheck                  -> exit 0 (server-typecheck.txt)
$ AC-001 grep over the 13 target files               -> no output, ac001_lines=0 (ac001-grep.txt)
$ grep -nA3 'EdgeInsets\.[a-zA-Z]*($' <targets>     -> no output (ac001-multiline.txt)
$ git diff --stat HEAD -- server/ app/lib/features/calls/data/ app/lib/core/network/ app/lib/core/router/ app/lib/features/calls/application/
                                                      -> no output (ac014-protected.txt)
$ git diff --stat HEAD -- <the nine earlier test files> -> app/test/unit_test.dart | 19 +++ (new AC-005 test only) (ac014-tests.txt)
```

### AC matrix

| AC | Result | Test / evidence |
|----|--------|-----------------|
| AC-001 | PASS | theme_test "design tokens have the agreed values"; grep 0 lines |
| AC-002 | PASS | theme_test "status color pairs meet contrast in light and dark" (21.00, 3.19 vectors) |
| AC-003 | PASS | theme_test "text styles follow the type scale" |
| AC-004 | PASS | accessibility_test "cards share one component and tone" |
| AC-005 | PASS | unit_test "uses plain Korean status labels"; chip "승인 대기" covered by approval_flow_test |
| AC-006 | PASS (see deviation 3) | theme_test "respects reduce motion"; accessibility_test "scrolls without animation when motion is reduced" |
| AC-007 | PASS (see deviation 4) | accessibility_test "busy buttons show progress and success gives light haptics" |
| AC-008 | PASS | accessibility_test "empty states share one widget and wording"; existing empty-state test unmodified |
| AC-009 | PASS | accessibility_test "tap targets meet guidelines" (5 variants × 3 guidelines) |
| AC-010 | PASS | accessibility_test "text contrast meets guidelines" (5 variants × light/dark) |
| AC-011 | PASS | accessibility_test "survives 2x text scale on a small phone" |
| AC-012 | PASS | accessibility_test "screen reader labels are present", "announces the remaining time only at 30 and 10 seconds" |
| AC-013 | PASS | accessibility_test "screens follow the wireframe order" |
| AC-014 | PASS | protected-path diff empty; earlier tests unchanged except the added AC-005 test; label grep empty |
| AC-015 | PASS | app 80 passed, analyze = baseline, server 387 passed |

### Deviations for sync / plan-auditor

1. Commits: M1–M5 share one implementation commit, because removing `warning`/`callLive` (M1) breaks every screen
   until M3/M4 land; per-milestone commits would not compile.
2. Pinned-area cap (REQ-011): half the screen while text is enlarged (the REQ's own state condition), two thirds at
   normal size. A strict half at normal size made the unmodified approval_flow_test fail at 800×600.
3. AC-006 "one pump": a live event needs one pump to arrive and one frame to draw; the end position then settles
   within up to 3 more frames because the lazily built list re-estimates its extent. The test pumps accordingly.
4. AC-007 heavy haptic: on arrival the card's `heavyImpact` and the existing app-wide `ApprovalListener`'s
   `heavyImpact` both fire (pre-existing, unchanged). The test asserts ≥1 on arrival and no extra heavy after deciding.
5. Formatting: `dart format` was applied to the 10 heavily edited target files (the repo has no formatter config and
   older code is not formatter-clean), so those diffs include line-wrapping changes. An accidental project-wide format
   was reverted for every file outside the plan, and small-edit files were restored and re-edited by hand.
6. Device checks (TalkBack / VoiceOver reading, real haptics) were not run — out of the SPEC's automatic scope.

## §E.3 Run-phase Audit-Ready Signal

```yaml
run_complete_at: 2026-11-25
run_start_sha: ba1ee1790078643628522a0402556c840f1e0169
run_commit_sha: d63740d   # implementation commit; the commit carrying this section is evidence-only
run_status: complete
ac_pass_count: 15
ac_fail_count: 0
app_tests: "+80 passed (baseline +65)"
app_analyze: "1 info (baseline info, fakes.dart:54)"
server_tests: "14 files / 387 tests passed (unchanged, server not modified)"
server_typecheck_exit: 0
ac001_literal_lines: "43 -> 0"
protected_paths_diff: empty
existing_tests_modified: "unit_test.dart: one test added (AC-005); no existing assertion changed"
new_dependencies: none
new_warnings_or_lints_introduced: 0
m1_to_mN_commit_strategy: "one implementation commit (M1-M5 do not compile apart) + one evidence commit; no push"
l44_pre_commit_fetch: not-run   # primary checkout; no push requested
l44_post_push_fetch: not-applicable
device_check: deferred   # screen readers and haptics on real devices
external_services_contacted: none
```

## §E.4 Sync-phase Audit-Ready Signal

```yaml
sync_complete_at: 2026-11-27
sync_commit_sha: 9bf5f82   # follow-up commit records the sync-audit result
sync_status: implemented
run_commit_sha: d63740d   # implementation commit (M1-M5)
run_evidence_commit_sha: c2e732d   # run-phase evidence commit; sync measured at this HEAD
app_tests_at_sync: "00:08 +80: All tests passed! (exit 0)"   # .moai/state/verify/ux-sync/app-test.txt
app_analyze_at_sync: "1 issue found. (info, test/support/fakes.dart:54:5 use_null_aware_elements = run baseline; exit 1 due to the info)"   # .moai/state/verify/ux-sync/analyze.txt
server_tests_at_sync: "Test Files 14 passed (14) / Tests 387 passed (387) (exit 0)"   # .moai/state/verify/ux-sync/server-test.txt
server_typecheck_exit_at_sync: 0   # .moai/state/verify/ux-sync/server-typecheck.txt
evidence_dir_note: ".moai/state/verify/ux-sync/ is gitignored (local only)"
acceptance_distinct_ac_ids: 15   # grep -oE 'AC-([A-Z0-9]+-)*[0-9]+' acceptance.md | sort -u | wc -l
frontmatter_status_transitions:
  spec.md: in-progress -> implemented   # updated: 2026-11-25 -> 2026-11-27; spec/plan/acceptance bodies unchanged
changelog_entry_position: not-applicable   # repository has no CHANGELOG.md
mx_scan: skipped   # --skip-mx semantics
divergence:
  planned_vs_changed_files: match   # git diff --name-only ba1ee17..d63740d = the 19 files of plan.md §B (15 app/lib + 4 app/test) + spec.md; no unplanned file
  deviations: "§E.2 Deviations 1-6 (one commit for M1-M5; REQ-011 pinned-area cap; AC-006 pump count; AC-007 duplicate heavy haptic pre-existing; dart format on 10 files; device checks deferred)"
  as_implemented_value_difference: "deviation 2 — REQ-011 is met (1/2 cap while text is enlarged, call_detail_screen.dart:330,335; AC-011 passes). The 2/3 cap at normal size differs only from the plan.md §B note, which REQ-011 does not constrain (sync-audit C3)"
device_check: deferred   # TalkBack / VoiceOver reading and real haptics not run
project_docs_synced: [.moai/project/structure.md, .moai/project/codemaps/modules.md, .moai/specs/EPIC-ASSISTANT-UX/overview.md]
tech_md: unchanged   # no new dependency
downstream_note_spec_module_001: "SPEC-MODULE-001 plan checks that SPEC-UX-001 is `completed`, but this repository closes sync at `implemented` (SPEC-STORE-001 etc.). Owner asked to start SPEC-MODULE-001 after this sync (2026-11-27); MODULE progress.md records the precondition as met by `implemented` with that reason (sync-audit C1)"
sync_audit: "PASS 85.8 (harmonic mean), .moai/reports/sync-audit/SPEC-UX-001-audit-1.md; C1, C3, C4 handled here; C2, F1, F2 recorded"
```
