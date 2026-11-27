# SPEC-SHELL-001 진행 기록

## §E.1 Plan-phase Audit-Ready Signal

- owner_verdict: PASS-with-debt (owner decision 2026-11-26, iteration 3 at 0.85; D1/D2 fixed; debt per audit_debt). Also owner chose: tonal buttons repainted in SHELL-001 (home_screen [내 정보 입력], follow_up_actions [다시 걸기]) — plan.md file table
- plan_status: plan-audit iteration 3/3 done (0.85 = Tier L threshold; FAIL only on blocking text defects D1/D2, both fixed after the report; auditor recommends PASS-with-debt; owner decision pending). Reports review-1..3.
- audit_debt (iteration 3, optional): D4 fixed, D5 header/citation fixed, D6 router-argument signature fixed, D7 R-12 fixed; open: D9 AC-018 grep does not check `goBranch(`; REQ-008/REQ-012/REQ-021 mix GEARS forms; D8 ASSIST plan openTask wording (fix after ASSIST iteration 3)
- spec_version: 0.3.1 (iteration-2 fixes)
- spec_version_0.3.0: (owner decision 2026-11-26: split tokens/font/status chip into SPEC-DESIGN-001, move shell to Tier L)
- spec_version_history: 0.1.0 (3-tab), 0.2.0 (design-review 5-slot)
- plan_complete_at: 2026-11-26
- base_sha: c2e732d (plus uncommitted planning docs; run-phase records run_start_sha after SPEC-MODULE-001 and SPEC-DESIGN-001 complete)
- tier: L (about 40 files), harness: standard, methodology: tdd
- artifacts: spec.md, plan.md, acceptance.md, design.md, research.md (+ research/go_router_spike_test.dart.txt, audit_branch_spike_test.dart.txt, open_task_spike_test.dart.txt), progress.md
- counts: 21 REQ / 21 AC
- depends_on: SPEC-MODULE-001, SPEC-DESIGN-001
- open_decisions: OD-1, OD-3 decided; OD-2, OD-4 ~ OD-8 DEFAULT (pending owner review)
- intended test changes: accessibility_test.dart home-order block (:614-619) and plan_card_test.dart back-navigation block (:194-196) — AC-021 table (research R2)
- verified at plan time: go_router 18.1.4 cross-branch behaviour by spike (research R1, cases A-H incl. G assertion and G2/G3 alternatives; goBranch cases X1-X6 and openTask cases Y1-Y3 re-run 2026-11-26, each with --plain-name); awaiting_approval = pre-call plan approval (stateMachine.ts:4); pendingApprovalsProvider covers every task with task.pendingApproval regardless of status (calls_controller.dart:115-120); CallTask fields (call_models.dart:262-278)
- audit iteration 1 must-fix mapping: D1 -> research R2 + AC-021 + design D2.3; D2 -> design D3 + AC-013; D3 -> SPEC-DESIGN-001 §A.2 + design D4; D4 -> design D2.2; D5 -> research R1 + design D1.2; D6 -> SPEC-DESIGN-001; D7 -> Tier L + split; D8 -> this file; D10 -> design D5 + REQ-016
- note: app + packages; no server change

## §E.2 Run-phase Evidence

Evidence files (gitignored, kept for audit): `.moai/state/verify/SPEC-SHELL-001/{pre,red,final}/`.

### Pre-flight (recorded at run start, before any change)

- `git -C <wt> rev-parse HEAD` → `2fef928b882e55ea23e379ad9674063758f5f2f2` (run_start_sha)
- `git -C <wt> status --short` → ` M .moai/specs/SPEC-SHELL-001/progress.md` (orchestrator's §F, not touched by the run)
- root `dart test` → `00:00 +2: All tests passed!`
- app `flutter --suppress-analytics test` → `00:08 +88: All tests passed!`; `flutter analyze` → `1 issue found` (info, `test/support/fakes.dart:54:5 • use_null_aware_elements`)
- kolbi_ui `flutter test` → `00:01 +63: All tests passed!`; analyze → `No issues found!`
- kolbi_core `dart test` → `00:00 +3: All tests passed!`; `dart analyze` → `No issues found!`
- `npm --prefix server ci` (node_modules was missing) then `npm --prefix server test` → `Tests  387 passed (387)`; `npm run typecheck` → exit 0
- acceptance grep `grep -rn "지난 통화\|home-intake\|최근 통화한 곳\|'CallMate'\|'기록'\|'내 정보'\|'설정'" app/test` → 10 hits: `plan_card_test.dart:196`, `intake_flow_test.dart:19,20,97,124,153`, `accessibility_test.dart:562,615,616,618`. Matches research R2 (the two "바뀜" rows plus the "그대로" rows).

### Pre-commit hook incident (resolved before M1 landed)

The first M1 commit was refused by the hook: `quality gate failed: dart test … the Flutter SDK is not available`. Cause: in a linked worktree git exports an absolute `GIT_DIR` to hooks; it leaked into the shared Flutter SDK's own git calls (`GIT_DIR=… flutter --version` printed `channel [user-branch] • https://github.com/Jason8117/jason-danmuzi.git`) and `bin/cache/flutter.version.json` disappeared. Owner chose option A (2026-11-27); the orchestrator changed `.git/hooks/pre-commit` to `env -u GIT_DIR -u GIT_INDEX_FILE -u GIT_WORK_TREE moai gate`. Every commit below ran the hook normally; `flutter.version.json` was present after each.

### AC-021 table extended by owner decision 2026-11-27 (option A)

M4 made REQ-015 and REQ-010 real and broke five existing test blocks that research R2 / the AC-021 table did not list (acceptance.md and research.md bodies left unchanged; the orchestrator annotates them at sync).

| # | Existing block | Break | Cause |
|---|---|---|---|
| 1 | `approval_flow_test.dart:36` (800×600 default view) | "귀찮은 전화, 대신 걸어드릴게요" below the fold; sliver items outside the viewport are offstage to `find` | REQ-015 order |
| 2 | `approval_flow_test.dart:44,47` | today row "라 파스타" below the fold; the tap misses | REQ-015 order |
| 3 | `approval_card_test.dart:45` (`openCall`, used by `:176` with a completed task) | today no longer lists finished tasks | REQ-015 / OD-1 |
| 4 | `font_overflow_test.dart:73-74` (360×640, 2×) | "직접 입력하기" below date/greeting/briefing → offstage | REQ-015 order |
| 5 | `accessibility_test.dart:480` (result detail, 360×640, 2×) | timeline on top pushes the result card offstage; `ensureVisible` → `Bad state: No element` | REQ-010 |

The four approved edits (verbatim, `git diff -U0 2fef928`):

```
approval_flow_test.dart  @@ -16,0 +17,3   + tester.view.physicalSize = const Size(800, 2400); + tester.view.devicePixelRatio = 1; + addTearDown(tester.view.reset);
approval_card_test.dart  @@ -3,0 +4      + import 'package:callmate/core/router/app_router.dart';
                         @@ -45 +46      - await tester.tap(find.text('라 파스타').first);
                                         + ProviderScope.containerOf(tester.element(find.byType(CallMateApp))).read(routerProvider).push('/calls/${task.id}');
font_overflow_test.dart  @@ -73,0 +74     + await tester.scrollUntilVisible(manual, 200, scrollable: find.byType(Scrollable).first);
accessibility_test.dart  @@ -479,0 +482   + await tester.scrollUntilVisible(find.text('다시 걸기'), 200, scrollable: find.byType(Scrollable).first);
```

A sixth break (`accessibility_test.dart:223`, transcript auto-follow) was fixed in the app, with no test edit: the step rows are one line each (name and line side by side), so a live call's content still fits the "near bottom" window.

### Existing-test changes (AC-019 / AC-021), verbatim from `git diff -U0 2fef928 -- app/test/`

- `plan_card_test.dart` `@@ -196 +196` `- expect(find.text('CallMate'), findsOneWidget);` → `+ expect(find.byKey(const Key('tasks-screen')), findsOneWidget);` (AC-021 table row 2)
- `accessibility_test.dart` home order block `@@ -616 +618,0 - find.text('최근 통화한 곳'),` and `@@ -618 +620 - find.text('지난 통화'),` → `+ find.text('최근 통화한 곳'),`, giving `home-intake-field` → `진행 중` → `최근 통화한 곳` (AC-021 table row 1); plus row 5 above, two imports, and the new AC-020 test appended at the end of `main()`
- `approval_flow_test.dart`, `approval_card_test.dart`, `font_overflow_test.dart`: the option A edits above only
- `architecture_test.dart`: allowlist emptied, two re-export paths pinned, two new tests (plan §B / AC-018)
- untouched: `intake_flow_test`, `follow_up_test`, `trust_notice_test`, `outcome_card_test`, `calls_controller_test`, `unit_test`, `theme_test`, `design_contrast_test`, `support/fakes.dart`
- new: `shell_test.dart`, `inbox_test.dart`, `history_test.dart`, `today_test.dart`, `support/shell_support.dart`

### E1 — AC matrix (final HEAD of the implementation, `5b15c79`)

Final suite: `cd app && flutter --suppress-analytics test` → `00:10 +109: All tests passed!` (`final/app_test.txt`). Each AC test below is in that run.

| AC | Result | Command / test | Key output |
|---|---|---|---|
| AC-001 | PASS | shell_test "tab bar shows four tabs and the centre assistant button" | five cells left→right; labels 오늘/업무/비서/기록/내 정보; `tab-today` isSelected, label color `0xFF4F46E5`; assistant label "비서 부르기", no selected state; tab bar hit-testable on `/plan`, `/calls/a`, `/calls/new`, `/settings`, absent on `/assistant` |
| AC-002 | PASS | shell_test "re-tapping the current tab pops to its root, then scrolls to top" | (1) detail gone, `tasks-screen`; (2) 30 finished tasks, history dragged > 0 → re-tap → `pixels == 0` |
| AC-003 | PASS | shell_test "tasks badge counts approval requests" | "2" + "업무, 승인 대기 2개"; live update → "1"; 11 → "9+"; finished only → no Badge, "업무" |
| AC-004 | PASS | shell_test "legacy and new locations open the expected screens"; `grep -rnE "'/(calls\|plan\|settings\|inbox\|history\|me\|assistant)" app/lib/features` | nine locations → expected screens, first six with `tab-today` selected; grep exit 1 (no output) |
| AC-005 | PASS | shell_test "opening a task switches to the tasks tab" | cases (1)-(7): detail + `tab-tasks` selected, back → `tasks-screen`; after start, `tab-today` → today, no PlanCardScreen; (7) detail kept, re-tap → list |
| AC-006 | PASS | shell_test "centre button opens the assistant over the current tab" | tab bar hidden; close → same detail on tasks; send "내일 치과 예약" → `intakeCalls` one entry, assistant closed, PlanCardScreen on tasks tab, `takeException() == null` |
| AC-007 | PASS | kolbi_core `task_kind_test` (3 tests); inbox_test "rows are drawn through the registered kind" | duplicate → `DuplicateTaskKindError`; null/call → call, 'web' → unknown; `kind-call-row` in today, 3 in tasks, 2 in history |
| AC-008 | PASS | inbox_test "unknown kinds degrade to a placeholder" | "가 업체" in a call row; unknown row text; tap → "이 작업은 앱을 업데이트하면 볼 수 있어요"; no exception |
| AC-009 | PASS | kolbi_core `task_steps_test` (16 row tests + wording) | `dart test` → `+27: All tests passed!` (`final/core_test.txt`); "—" cells tried with every value |
| AC-010 | PASS | inbox_test "task detail shows the six steps above the existing detail"; kolbi_ui `step_timeline_test` | a..e: six steps top→down, D2.3 lines in their step keys, labels "6단계 중 N단계, 이름, 상태"; a's question, transcript line and "상대방이 기다리고 있어요" findsOneWidget; steps above the header |
| AC-011 | PASS | kolbi_core `task_groups_test` "tasks tab groups…"; inbox_test "tasks tab groups approvals, ongoing and routines" | counts 1/2/1; order 승인 요청 → 진행 중 → 반복; a before b; d, e absent; link → `tab-history`; finished only → no approval/ongoing group |
| AC-012 | PASS | inbox_test "empty and error states" | "아직 맡긴 일이 없어요" → [비서에게 맡기기] opens the assistant; failing list → "서버와 연결되지 않았어요", [다시 시도] → `listCalls == before + 1` |
| AC-013 | PASS | kolbi_core "in-call approvals agree with pending approvals"; shell_test "badge, tasks and today agree"; code review | {a} both sides; badge 2 = tasks approval rows 2 = today count 2; listener alerts a only. The approval-request rule lives only in `packages/kolbi_core/lib/src/tasks/task_groups.dart` (`isApprovalRequest`); `grep -rn awaitingApproval app/lib` outside the domain re-export → `call_detail_screen.dart:146,200,282` only (status-specific UI branches, not the request rule) |
| AC-014 | PASS | kolbi_core "history groups by Seoul date"; history_test "history lists finished tasks by day with result chips" | 오늘 · 11월 26일 / 어제 · 11월 25일 order; empty state; 23:59 / 00:01 on different days; seven D4 rows: chip category, wording, icon |
| AC-015 | PASS | today_test "today follows the dashboard order", "greeting follows the time of day" | twelve elements in order; today count "2"; no "지난 통화"/"CallMate"; empty: first-use state, no briefing/lists; 09/14/21 → 아침/오후/저녁; no name → "좋은 오후예요." |
| AC-016 | PASS | today_test "today shortcuts" | call/search → assistant; calendar/mail → isEnabled false, label has "곧 쓸 수 있어요", tap does nothing; "업무 보기 →" → `tab-tasks` |
| AC-017 | PASS | shell_test "me tab lists items and opens settings" | "김지은" + "010-****-5678"; groups 비서 → 권한과 안전 → 앱; all D6 items; disabled item labelled and inert; card and 서버 연결(개발용) → settings; empty → "내 정보를 입력해 주세요" |
| AC-018 | PASS | architecture_test (6 tests); `grep -rn "GoRouter(" app/lib`; `grep -rnE "\.go\(\|goNamed\(\|goBranch\(" app/lib/features` | allowlist `<String>{}`; core → features/shell only from pinned `lib/core/router/app_router.dart`; GoRouter only `app/lib/shell/app_router.dart:22`; feature grep exit 1. The rule caught a probe file (`goBranch(0)`, `'/calls/x'`) before it was deleted |
| AC-019 | PASS | full suite; diff above | listed flow tests pass; only the table edits changed |
| AC-020 | PASS | accessibility_test "shell screens meet the accessibility guidelines" | today/tasks/history/me/detail(a), light + dark, four guidelines; 360×640 at 2× no exception; [승인] reached and tapped (`decisions.single.approve == true`); tab label scale ≤ 1.5 (clamped at 1.3) |
| AC-021 | PASS | `git diff --stat 2fef928 -- server/` → empty (`0` lines); app/test diff = 5 new files + AC-021 table edits (as extended 2026-11-27); test count 88 → 109 | end-of-run grep (`final/grep_end.txt`): old hits unchanged except `plan_card_test:196` (gone) and the accessibility order block (now intake → 진행 중 → 최근 통화한 곳); other hits are new SHELL tests |

### E2 — last lines (final tree)

- root `dart test` → `00:00 +2: All tests passed!`
- app `flutter test` → `00:10 +109: All tests passed!`; `flutter analyze` → `1 issue found` (the baseline `fakes.dart:54:5` info only)
- kolbi_ui `flutter test` → `00:00 +68: All tests passed!`; analyze → `No issues found!`
- kolbi_core `dart test` → `00:00 +27: All tests passed!`; `dart analyze` → `No issues found!`
- server `npm test` → `Tests  387 passed (387)`; typecheck exit 0 (unchanged tree)

### E3 — scope

- `git diff --stat 2fef928 -- server/` → empty
- `git diff --stat 2fef928 -- app/test/` → 11 files, 1437 insertions, 8 deletions: new `history_test`, `inbox_test`, `shell_test`, `today_test`, `support/shell_support`; edited `accessibility_test`, `approval_card_test`, `approval_flow_test`, `architecture_test`, `font_overflow_test`, `plan_card_test` (all as above)

### E4 — RED before GREEN, per milestone (files in `red/`)

- M1 `m1_core.txt`: `Error: Method not found: 'groupTasks'` / `'groupHistory'` / `'withSubjectParticle'`; `m1_ui.txt`: `Error: Type 'TaskKindPresenter' not found.`, `Method not found: 'KolbiStepTimeline'`, `Undefined name 'KolbiTabBadge'`
- M2 `m2_shell.txt`: `Error when reading 'lib/shell/navigation.dart': No such file or directory`, `Error when reading 'lib/core/clock.dart'`, `Method not found: 'openTask'`
- M3 `m3.txt`: history "Found 0 widgets with text "오늘 · 11월 26일"", inbox "Found 0 widgets with key [<'kind-call-row'>]", four inbox tests + two shell tests `[E]`
- M4 `m4.txt`: today_test four tests `[E]` (e.g. greeting "Found 0 widgets with text containing …^좋은"), inbox AC-010 "Found 0 widgets with key [<'task-steps'>]", shell "badge, tasks and today agree" `[E]`
- M5 `m5.txt`: "Found 0 widgets with text "김지은"" → `me tab lists items and opens settings [E]`
- M6 `m6_arch.txt`: with a probe violation `router and tab switching live in the shell [E]` listing `zz_probe.dart:3 tab switch: r.goBranch(0);` and `:4 route literal`; probe removed → `+6`. `m6_a11y.txt`: `A RenderFlex overflowed by 13 pixels on the right.` (tasks screen at 2×; fixed in `call_task_tile.dart`)

### E5 — formatted files (`dart format <explicit paths>`, default width)

M1: the 14 new kolbi_core/kolbi_ui files. M2: `core/clock.dart`, `widgets/call_task_tile.dart`, `features/{inbox,history,me}/*_screen.dart`, the seven `shell/*.dart`, `test/shell_test.dart`, `test/support/shell_support.dart`. M3: `inbox_screen`, `history_screen`, `inbox_test`, `history_test`, `shell_test`, `shell_support`. M4: `today_test`, `inbox_test`, `shell_test`, `history_test`. M5: `me_screen`, `shell_test`. M6: `call_task_tile.dart`, `test/architecture_test.dart`. That last file existed before the run; it was format-clean already, and the diff shows the formatter touched only the lines this SPEC added. Everything else that existed before was edited by hand. `accessibility_test.dart` is not format-clean and was not formatted.

### E7 — deviations and interpretations (accepted / recorded per orchestrator 2026-11-27)

1. `CallTask.kind` (nullable; missing or non-string → null → `call`) added in `packages/kolbi_core/lib/src/models/call_models.dart`. That file is outside plan §B, but AC-008 needs the field.
2. The step state enum is `TaskStepState`, because `material_ui` already exports `StepState`.
3. Extra test files beyond plan §B: `kolbi_core/test/support/tasks.dart`, `app/test/support/shell_support.dart`. `kolbi_ui/test/step_timeline_test.dart` also covers the badge, briefing card and presenter registry.
4. Cross-feature data goes through the shell. `shell/task_feed.dart` (task list, groups, history days, reload) and `shell/kind_registration.dart` (kind catalog, presenters, `TaskDetailRoute`) let inbox, history and me read tasks without importing `features/calls`, so the allowlist is empty (AC-018). Features import `shell/` for these and for `navigation.dart` / `routes.dart`.
5. Shell layout:
   - The tab shell is `Material` + `Column`, not a `Scaffold`. With a nested Scaffold the approval SnackBar floated over the pinned approval card.
   - Tab screens get a MediaQuery whose height is the space above the bar, so the pinned card's ½ and ⅔ limits match what is visible (`approval_flow_test:53` passes unmodified).
   - `BranchStack` is the indexedStack container plus `HeroMode` off in hidden branches, to avoid duplicate SnackBar hero tags.
   - Label text scale is clamped at 1.3 (inside the ≤ 1.5 limit) and the bar is 57 px tall, so the 2× approval SnackBar still fits at 360×640.
6. `openTab` uses the `StatefulNavigationShell` the tab scaffold registers per GoRouter (Expando), falling back to `go(tab.path)`. This is design.md D1.2's "셸 위젯이 갈래 전환 함수를 등록". Re-tap scroll-to-top uses `TabScrollScope` controllers, given only to a tab's first page (all four tabs).
7. The assistant placeholder (OD-6) holds the request input, send and example chips; it has no manual-form link and no recent places. With no profile it closes itself, then opens settings, because pushing a shell route over `/assistant` asserts (research R1-G).
8. The test harness disables Riverpod 3's automatic retry (`ProviderScope(retry: …)` in `pumpShell` only), so a failing list stays an error. `CountingCallsRepository` opens a fresh fake live connection on reload, because the existing fake cannot reopen after `close()`. `fakes.dart` is unchanged. In the app, the tasks and history screens show the error whenever there is an error and no list yet.
9. `CallTaskTile` (former home `_TaskTile`) caps its chip column at 40 % of the screen width, so a long chip wraps at 2× (found by the AC-020 RED).
10. `app/lib/app.dart` is unchanged. Kind registration happens through the shell providers, and `MaterialApp.title` stays (spec §6.4). `KolbiTabBadge` keeps Material's Badge colors; its text is excluded from semantics, and the tab reads "업무, 승인 대기 N개".
11. OD defaults as interpreted:
    - OD-2: the first-use empty state stays when there are no tasks, and the settings icon stays.
    - OD-4: the name "최근 통화한 곳" stays.
    - OD-5: `features/calls` is not split.
    - OD-6: the temporary light assistant screen as in item 7.
    - OD-7: only the timeline is added to the detail.
    - OD-8: the failed step is decided by whether there is a transcript.

## §E.3 Run-phase Audit-Ready Signal

```yaml
run_complete_at: 2026-11-27
run_start_sha: 2fef928b882e55ea23e379ad9674063758f5f2f2
run_commit_sha: 5b15c79   # M6, last implementation commit; M1 d030b0b, M2 07565f5, M3 19d58ca, M4 1048911, M5 d99abac; the commit carrying this section is evidence-only
run_status: complete
ac_pass_count: 21
ac_fail_count: 0
app_tests: "+109 passed (baseline +88; +21 new: shell 8, inbox 5, history 1, today 4, accessibility 1, architecture 2)"
app_analyze: "1 info (baseline info, fakes.dart:54)"
root_workspace_test: "dart test +2 passed"
kolbi_core: "dart test +27 passed (baseline +3); dart analyze No issues found!"
kolbi_ui: "flutter test +68 passed (baseline +63); flutter analyze No issues found!"
server_tests: "387 passed; typecheck exit 0 (server/ untouched)"
protected_paths_diff: "server/ empty; app/test/ = 5 new files + AC-021 table edits (plan_card :196, accessibility home-order block) + the four option A edits (owner decision 2026-11-27) + architecture_test per AC-018 + appended AC-020 test"
existing_tests_modified: "plan_card_test:196; accessibility_test home-order block, :480 scroll, AC-020 test appended; approval_flow_test pumpApp view size; approval_card_test openCall push; font_overflow_test scroll; architecture_test rules"
ac021_table_extended: "owner decision 2026-11-27 option A: 5 conflicts (REQ-015 order, OD-1, REQ-010), 4 edits; acceptance.md/research.md bodies unchanged, to be annotated at sync"
new_dependencies: none
new_warnings_or_lints_introduced: 0
dart_format_scope: "new files by explicit path; architecture_test.dart formatted (already clean, only added lines changed); other existing files hand-edited"
red_evidence: "per milestone M1-M6 in §E.2 E4; files in .moai/state/verify/SPEC-SHELL-001/red/"
m1_to_mN_commit_strategy: "one commit per milestone M1-M6, pre-commit hook ran normally on each (after the owner-approved hook fix); this docs commit last; no push"
hook_incident: "worktree GIT_DIR leaked into the shared Flutter SDK; hook patched by orchestrator 2026-11-27 (option A); flutter.version.json present after every commit"
deviations: "11 items in §E.2 E7 (CallTask.kind, TaskStepState, extra test support files, shell data providers, non-Scaffold shell + inner MediaQuery + BranchStack HeroMode + label clamp 1.3, openTab registration, assistant placeholder scope, test-only retry off, CallTaskTile chip width cap, app.dart unchanged, OD defaults)"
audit_debt_carried: "D9 closed (AC-018 checks goBranch); mixed GEARS forms and D8 left to plan owner"
sync_handoff: "plan.md §G items + annotate acceptance.md AC-021 / research.md R2 with the option A rows"
external_services_contacted: none
```

## §E.4 Sync-phase Audit-Ready Signal

_<pending sync-phase>_

## §F Phase 4 Mode Selection

- kickoff: Implementation Kickoff Approval given by owner on 2026-11-27 ("기본값으로 시작": OD-2, OD-4 ~ OD-8 take the plan defaults; route: branch + PR; progression: autonomous run, then owner reviews screenshots before sync/audit/merge)
- precondition: SPEC-MODULE-001 and SPEC-DESIGN-001 `completed` (466c73b, b8e7ff0)
- route: B (Tier L) — branch feat/SPEC-SHELL-001 in worktree /Users/jason/Documents/Jason-Danmuzi/wt-shell-001 (created from origin/main 2fef928); PR opened after run; owner merges
- inputs: tier L, about 40 files, 6 milestones, domains: kolbi_core (task kinds/steps), kolbi_ui (indicators, tab bar, timeline), app (router, 4 branches, screens), tests; language mix Dart; concurrency benefit LOW (router and shared contracts gate later milestones)
- evaluation: direct — not selected; fanout — not selected (coding-heavy); sweep — not selected (non-uniform); serial — selected. manager-lead (Tier L coordination) is not available in this session's agent catalog, so one implementation agent runs M1 → M6 in order
- Decision: serial
- justification: M1 contracts and M2 router are prerequisites for M3-M5 screens and all touch app_router/navigation; one writer in order avoids races on the same files
