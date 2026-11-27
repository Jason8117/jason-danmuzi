# SPEC-DESIGN-001 진행 기록

## §E.1 Plan-phase Audit-Ready Signal

- owner_verdict: PASS-with-debt (owner decision 2026-11-26, iteration 3 PASS 0.90). N6 tonal-button colour handed to SPEC-SHELL-001
- plan_status: plan-audit iteration 3/3 PASS 0.90 (report .moai/reports/plan-audit/SPEC-DESIGN-001-review-3.md; scratch run +80 all passed); auditor recommends PASS-with-debt; N3 residue, N7, N8, D14 fixed in docs after the report
- audit_debt (optional): N4 dark neutral chip bg equals card colour (no pill outline); N5 dark container roles outside the §A.3 table keep fromSeed values; N6 FilledButton.tonal takes the filledButtonTheme #635BFF background (home_screen.dart:337 '내 정보 입력', follow_up_actions.dart:88 '다시 걸기' now look like primary buttons; contrast 4.70 ok) — owner to accept or hand to SHELL-001
- spec_version: 0.2.1
- plan_complete_at: 2026-11-26
- origin: split from SPEC-SHELL-001 0.2.0 REQ-013 per plan-audit iteration 1 tier recommendation (owner chose split, 2026-11-26)
- base_sha: c2e732d (plus uncommitted planning docs; run-phase records run_start_sha after SPEC-MODULE-001 completes)
- tier: M (16 files), harness: standard, methodology: tdd
- artifacts: spec.md, plan.md, acceptance.md, progress.md
- counts: 11 REQ / 14 AC (AC-001..AC-013 with AC-004a/b)
- depends_on: SPEC-MODULE-001
- open_decisions: OD-1 decided (text colours from 06 §3.2/§3.3); OD-2 ~ OD-4 DEFAULT (pending owner review)
- intended test change: app/test/theme_test.dart:29 seed value only; new app tests font_overflow_test.dart, design_contrast_test.dart — AC-011
- audit facts: primary #635BFF as text fails a11y (home TextButton 4.43, approval OutlinedButton 4.28) -> primary #4F46E5, #635BFF only as filled-button bg (white 4.7, recomputed); AppCard is Card elevation 0 (common.dart:61, app_theme.dart:37); card colour surfaceContainerLow (app_theme.dart:39) -> surfaceContainerLowest
- verified at plan time: status_chip.dart labels and pulsing dot (needsApproval -> '승인 대기', status.label otherwise; dot when isLiveCall || needsApproval); TaskStatus labels (call_models.dart); CardTone enum (app_theme.dart:66); seed + fromSeed (app_theme.dart:6, :24); theme_test.dart:29 asserts the old seed
- note: kolbi_ui plus one app/lib line (hang-up button foregroundColor onError, REQ-009 exception); kolbi_core, server unchanged

## §E.2 Run-phase Evidence

Evidence directory: `.moai/state/verify/design-run/` (preflight.txt, build-before.txt, build-after.txt, m1-red-*.txt, m1-green-*.txt, m1-without-hangup-fix.txt, m2-red-1-table.txt, m2-red-2-category.txt, m2-green-*.txt, m3-red-*.txt, m3-green-*.txt, ac003-ratios.txt, final.txt).

### Pre-flight (verbatim, run_start_sha)

```
$ git rev-parse HEAD
466c73b677c9e87ea316396c8682600eb3a9b1e5
$ dart test                                   (repo root)
00:00 +2: All tests passed!
$ cd app && flutter --suppress-analytics test
00:07 +84: All tests passed!
$ cd app && flutter --suppress-analytics analyze
   info • Use the null-aware marker '?' rather than a null check via an 'if'. Try using '?' • test/support/fakes.dart:54:5 • use_null_aware_elements
1 issue found. (ran in 1.9s)
$ cd packages/kolbi_ui && flutter --suppress-analytics test
00:00 +4: All tests passed!
$ cd packages/kolbi_ui && flutter --suppress-analytics analyze
No issues found! (ran in 1.4s)
$ cd packages/kolbi_core && dart test
00:00 +3: All tests passed!
$ cd packages/kolbi_core && dart analyze
No issues found!
$ cd app && flutter --suppress-analytics build web --debug && du -sk build/web
✓ Built build/web
53288	build/web          (52M; main.dart.js 13,227,808 bytes; build/web/assets 3,020 KB)
```

Plan §D risk checks at run start: `packages/kolbi_ui/test/widgets_test.dart` has no colour or card-shape assertion (it checks spacing tokens, an AppCard title/body render, and barrel names), so no existing package test line needed changing. `grep -rn "primaryContainer\|secondaryContainer" app/test` -> no matches.

Font: `packages/kolbi_ui/assets/fonts/PretendardVariable.ttf` 6,739,336 bytes (6.7MB; the plan assumed about 2MB), sha256 3090ccde0442bb347aa7685d9ba8b17436a60682df6e8f92a9a670de14056e22; `OFL.txt` 4,418 bytes, sha256 d31ddd9f2bed32fd7e302a205cf2380ba0de6529152d239ef99cfb6f261bfc04. Source and owner approval: §F. Downloaded by the orchestrator, not by the run agent; hashes re-checked before the M3 commit.

### RED before GREEN (E4, verbatim failing lines)

M1 (before any value change; `m1-red-kolbi_ui.txt`, `m1-red-app.txt`; hex in parentheses is derived from the printed channel values):
```
theme_values_test.dart: seed, roles, background, card and filled button follow plan §A.3 [E]
  Expected: Color:<Color(alpha: 1.0000, red: 0.3882, green: 0.3569, blue: 1.0000, ...)>   (#635BFF)
    Actual: Color:<Color(alpha: 1.0000, red: 0.1216, green: 0.5412, blue: 0.4392, ...)>   (#1F8A70)
loading tokens_contrast_test.dart [E]
  Failed to load ...: Null check operator used on a null value   (no filled-button colours yet)
  test/tokens_contrast_test.dart 26:50  textPairs
theme_values_test.dart: tone pairs follow plan §A.1 and keep their names [E]
  Expected: (#EEEDFC)  Actual: (#DCF2E4)  light live background
theme_values_test.dart: dark scheme uses the 06 dark roles [E]
  Expected: (#A6ACFF)  Actual: (#87D6BC)
app theme_test.dart: status color pairs meet contrast in light and dark [E]   (seed line 29 changed first)
app design_contrast_test.dart: app follows the device dark mode [E]
  Expected: (#11131F)  Actual: (#0F1512)
```
Note: `design_contrast_test` "text contrast meets guidelines on design screens" passed against the old green theme; it is the M1 gate for the new values. With the new values and without the hang-up fix it fails (`m1-without-hangup-fix.txt`): `Expected contrast ratio of at least 4.5 but found 1.90 for a font size of 16.0.` — the REQ-009 exception line is load-bearing.

M2 (`m2-red-1-table.txt`, then `m2-red-2-category.txt`):
```
status_chip_test.dart: every status with and without a pending approval follows the 18-cell table [E]
  Expected: (#EEEDFC live)  Actual: (#E5E1E9 old surfaceContainerHighest)   planning dark=false background
status_chip_test.dart:78:25: Error: 'StatusCategory' isn't a type.
status_chip_test.dart:79:7: Error: Undefined name 'StatusCategory'.
```
M3 (`m3-red-kolbi_ui.txt`, `m3-red-app.txt`):
```
theme_values_test.dart: Pretendard is a package font with its licence, used by the theme [E]
  Expected: contains 'family: Pretendard'   Actual: 'name: kolbi_ui\n' ...
theme_values_test.dart: every AppCard draws a 1px border [E]
  Expected: <1>  Actual: <0.0>   light neutral width
font_overflow_test.dart:67:5: Error: Method not found: 'registerKolbiFontLicenses'.
```
Two test-harness fixes were made during RED/GREEN and are not behaviour changes: the chip test pumps an empty tree between cells (AnimatedSwitcher otherwise shows the previous chip fading out), and the card-border test does the same (MaterialApp animates a theme change between pumps).

### AC matrix at final implementation HEAD 3de1cee (E1)

| AC | Result | Command | Key output |
|---|---|---|---|
| AC-001 | PASS | `cd packages/kolbi_ui && flutter test test/theme_values_test.dart` | "seed, roles, background, card and filled button follow plan §A.3" passes; `+5: All tests passed!` |
| AC-002 | PASS | same | "tone pairs follow plan §A.1 and keep their names" passes (CardTone order neutral, attention, positive, caution, critical) |
| AC-003 | PASS | `flutter test test/tokens_contrast_test.dart --reporter expanded` | `+50: All tests passed!`, 48 ratio tests + 2 "never draws Electric Indigo #635BFF as text"; lowest text pair `#FFFFFF on #635BFF (4.70)`, then `light caution text #5F6478 on #F1F2F8 (5.25)`; lowest accent `light neutral/caution accent #7A7F94 on #F1F2F8 (3.55)` |
| AC-004a | PASS | `theme_values_test.dart` | "dark scheme uses the 06 dark roles" passes |
| AC-004b | PASS | `cd app && flutter test test/design_contrast_test.dart` | "app follows the device dark mode" passes (home Scaffold #11131F; settings texts equal in light and dark) |
| AC-005 | PASS | `theme_values_test.dart`, `cd app && flutter test test/font_overflow_test.dart` | pubspec has `family: Pretendard` + one font asset + `assets/fonts/OFL.txt`; bodyMedium/titleLarge/app bar/filled button family `packages/kolbi_ui/Pretendard`; real font loaded with `FontLoader('packages/kolbi_ui/Pretendard')`, home at 360x640 and 2x text, `takeException()` null; `+2: All tests passed!`; `theme_test.dart:51-69` unchanged and passing |
| AC-006 | PASS | `theme_values_test.dart` | "every AppCard draws a 1px border" passes for 5 tones + `color: Colors.amber`, both modes (attention = tone accent, others outlineVariant #E6E8F0 / #2A2E45, radius AppRadius.lg) |
| AC-007 | PASS | `flutter test test/status_chip_test.dart` | 18 cells × 2 modes: background, text, `상태: <글자>`, dot only for approval/live-call cells, otherwise one icon in text colour; no check_circle/error icons; `+2: All tests passed!`; `theme_test.dart:83-103` unchanged and passing |
| AC-008 | PASS | same | "category chips use the category tone and five distinct icons" passes (5 distinct codePoints, label "상태: 라벨") |
| AC-009 | PASS | `git diff 466c73b -- app/lib/`; `cd app && flutter test` | only `call_detail_screen.dart` hang-up `foregroundColor: Theme.of(context).colorScheme.onError`; `00:08 +88: All tests passed!` (accessibility_test light/dark guideline checks included) |
| AC-010 | PASS | `git diff --stat 466c73b -- server/ packages/kolbi_core/` | empty output |
| AC-011 | PASS | `git diff 466c73b -- app/test/`; `git diff --stat 466c73b -- packages/kolbi_ui/test/widgets_test.dart packages/kolbi_ui/test/dependency_rules_test.dart` | existing-file change only `theme_test.dart:29` `0xFF1F8A70` -> `0xFF635BFF`; new files `design_contrast_test.dart`, `font_overflow_test.dart`; package existing tests: empty diff |
| AC-012 | PASS (record only) | `cd app && flutter build web --debug; du -sk build/web` | before 53,288 KB (52M), after 59,888 KB (58M), +6,600 KB; main.dart.js 13,227,808 -> 13,235,582 bytes; `build/web/assets/packages/kolbi_ui/assets/fonts/PretendardVariable.ttf` 6,739,336 bytes; FontManifest lists `packages/kolbi_ui/Pretendard` |
| AC-013 | PASS | `design_contrast_test.dart` | "text contrast meets guidelines on design screens" passes for home, approval, call detail (통화 끊기), settings after 연결 테스트 (failure text shown, asserted), plan card × light/dark = 10; `accessibility_test.dart:388` unchanged and passing |

14 / 14 PASS.

### Final suites (E2, verbatim, `final.txt`)

```
HEAD 3de1cee630346f90b81f41a9911b5598d9cb108f
== root dart test
00:00 +2: All tests passed!
== app test
00:08 +88: All tests passed!          (baseline +84; +2 design_contrast_test, +2 font_overflow_test)
== app analyze
   info • ... • test/support/fakes.dart:54:5 • use_null_aware_elements
1 issue found. (ran in 1.7s)
== kolbi_ui test
00:01 +61: All tests passed!          (baseline +4; +5 theme_values, +50 tokens_contrast, +2 status_chip)
== kolbi_ui analyze
No issues found! (ran in 1.4s)
== kolbi_core test
00:00 +3: All tests passed!
== kolbi_core analyze
No issues found!
```

### Scope diffs (E3)

```
$ git diff --stat 466c73b -- server/ packages/kolbi_core/
(empty)
$ git diff --stat 466c73b -- app/test/
 app/test/design_contrast_test.dart | 167 +++++
 app/test/font_overflow_test.dart   |  98 +++
 app/test/theme_test.dart           |   2 +-
-    expect(AppTheme.seed, const Color(0xFF1F8A70));
+    expect(AppTheme.seed, const Color(0xFF635BFF));
```

### Formatted files (E6)

`dart format` was run only on these new files, by explicit path: `packages/kolbi_ui/test/theme_values_test.dart`, `packages/kolbi_ui/test/tokens_contrast_test.dart`, `packages/kolbi_ui/test/status_chip_test.dart`, `packages/kolbi_ui/lib/src/theme/fonts.dart`, `app/test/design_contrast_test.dart`, `app/test/font_overflow_test.dart`. Edited existing files (`app_theme.dart`, `tokens.dart`, `common.dart`, `status_chip.dart`, `kolbi_ui.dart`, `pubspec.yaml`, `call_detail_screen.dart`, `theme_test.dart`) were hand-edited and not formatted.

### Deviations and notes (E8)

- Font size 6.7MB vs the plan's ~2MB assumption (owner-approved before download, §F); web debug build +6,600 KB.
- `AppColors` (tokens.dart) is internal, not exported from the barrel; tests use hex literals from plan §A.1/§A.3.
- `StatusChip.status` is now `TaskStatus?` (null only for `StatusChip.category`); the `StatusChip(status, {needsApproval})` constructor and both app call sites are unchanged. `StatusChip.iconOf(category)` and the `category` getter are public helpers.
- The theme applies Pretendard to the app bar title and filled-button text explicitly (`textTheme.apply`), because those styles come from the static type scale and would otherwise miss the theme font.
- Tonal buttons (N6) not touched (SPEC-SHELL-001). `registerKolbiFontLicenses()` is not called from `app/lib/main.dart` (SPEC-SHELL-001).
- Not verified: real-device rendering, and whether the variable font's `wght` axis follows `FontWeight` on each platform (no `fontVariations` set; widget tests do not show glyph weight). Owner device check per acceptance residual risk.
- Blockers: none.

## §E.3 Run-phase Audit-Ready Signal

```yaml
run_complete_at: 2026-11-27
run_start_sha: 466c73b677c9e87ea316396c8682600eb3a9b1e5
run_commit_sha: 3de1cee   # M3, last implementation commit; M1 7687615, M2 4430e31; M4 = regression only (no code), the commit carrying this section is evidence-only
run_status: complete
ac_pass_count: 14
ac_fail_count: 0
app_tests: "+88 passed (baseline +84; +2 design_contrast_test, +2 font_overflow_test)"
app_analyze: "1 info (baseline info, fakes.dart:54)"
root_workspace_test: "dart test +2 passed"
kolbi_core: "dart test +3 passed; dart analyze No issues found!"
kolbi_ui: "flutter test +61 passed (baseline +4); flutter analyze No issues found!"
app_build: "flutter build web --debug -> ✓ Built build/web; 53,288 KB -> 59,888 KB"
server_tests: not-run   # server/ untouched (diff empty)
protected_paths_diff: "server/ and packages/kolbi_core/ empty; app/test/ = 2 new files + theme_test.dart:29; app/lib/ = hang-up foregroundColor only"
existing_tests_modified: "app/test/theme_test.dart:29 only (AC-011)"
new_dependencies: none
new_assets: "packages/kolbi_ui/assets/fonts/PretendardVariable.ttf (6,739,336 B, sha256 3090ccde...6e22), OFL.txt (4,418 B, sha256 d31ddd9f...fc04)"
new_warnings_or_lints_introduced: 0
dart_format_scope: "6 new files by explicit path (§E.2 E6); edited files hand-edited"
red_evidence: "M1 theme_values/tokens_contrast/dark-mode, M2 18-cell + StatusCategory compile, M3 font/card/licence; verbatim in §E.2, files in .moai/state/verify/design-run/"
m1_to_mN_commit_strategy: "one commit per milestone M1-M3, pre-commit hook passed on each; M4 regression has no code change; this docs commit last; no push"
audit_debt_carried: "N4, N5 (§E.1); N6 handed to SPEC-SHELL-001"
external_services_contacted: none
```

## §E.4 Sync-phase Audit-Ready Signal

```yaml
sync_complete_at: 2026-11-27
sync_commit_sha: e47e099
sync_status: implemented   # orchestrator raises to completed after the sync audit passes (owner decision 2026-11-27)
run_start_sha: 466c73b
run_commit_sha: 3de1cee   # M3, last implementation commit (M1 7687615, M2 4430e31, M3 3de1cee)
run_evidence_commit_sha: 5ee6eef   # run-phase evidence commit
head_before_sync: 797c0da   # unrelated docs commit for other SPECs on top of 5ee6eef; tree identical for this SPEC's paths
pushed_state: not-pushed   # this sync commit is not pushed
measured_by: orchestrator on the 5ee6eef/797c0da tree, 2026-11-27
root_workspace_test_at_sync: "dart test -> 00:00 +2: All tests passed!"
app_tests_at_sync: "cd app && flutter --suppress-analytics test -> 00:08 +88: All tests passed!"
kolbi_ui_tests_at_sync: "cd packages/kolbi_ui && flutter --suppress-analytics test -> 00:01 +61: All tests passed!"
kolbi_core_tests_at_sync: "cd packages/kolbi_core && dart test -> 00:00 +3: All tests passed!"
protected_paths_diff_at_sync: "git diff --stat 466c73b -- server/ packages/kolbi_core/ -> empty; app/ = call_detail_screen.dart 1 line, theme_test.dart 1 line, 2 new tests (design_contrast_test.dart, font_overflow_test.dart)"
font_asset: "PretendardVariable.ttf 6,739,336 B + OFL.txt 4,418 B from github.com/orioncactus/pretendard v1.3.9 (sha256 in §F)"
web_build_size: "53,288 KB -> 59,888 KB (+6,600 KB; run agent measurement, §E.2 AC-012)"
acceptance_distinct_ac_ids: 13   # grep -oE 'AC-([A-Z0-9]+-)*[0-9]+' .moai/specs/SPEC-DESIGN-001/acceptance.md | sort -u | wc -l -> 13; the pattern drops the a/b suffix, so AC-004a and AC-004b count as one; with the suffix there are 14 (AC-001..AC-013 incl. AC-004a/b), matching §E.2 14/14 PASS
frontmatter_status_transitions:
  spec.md: draft -> implemented   # updated: 2026-11-26 -> 2026-11-27; spec/plan/acceptance bodies unchanged (run phase did not move status to in-progress)
changelog_entry_position: not-applicable   # repository has no CHANGELOG.md
mx_scan: skipped
coverage: not-measured
divergence:
  planned_vs_changed_files: "plan.md §B lists 16 files; git diff --name-only 466c73b..3de1cee -> the same 16 (theme/app_theme.dart, theme/tokens.dart, theme/fonts.dart new, widgets/common.dart, widgets/status_chip.dart, kolbi_ui.dart, assets/fonts/PretendardVariable.ttf + OFL.txt, kolbi_ui pubspec.yaml, 3 kolbi_ui tests, 2 app tests, app/test/theme_test.dart, call_detail_screen.dart); no unplanned file"
  app_colors_internal: "AppColors constants live in tokens.dart and are not exported from the barrel; tests use hex literals from plan §A.1/§A.3"
  status_chip_nullable_status: "StatusChip.status is TaskStatus? (null only for StatusChip.category); the original constructor and both app call sites unchanged"
  public_helpers: "StatusChip.iconOf(category) and the category getter are public"
  fixed_type_scale_font: "theme applies Pretendard to the app bar title and filled-button text with textTheme.apply, because those styles come from the static type scale"
  no_font_variations: "no fontVariations set; whether the variable font's wght axis follows FontWeight on each platform is unverified on device"
  font_size: "6.7MB vs the plan's ~2MB assumption (owner approved before download, §F)"
debt_carried:
  - "N4 dark neutral chip background equals the card colour (no pill outline)"
  - "N5 dark container roles outside the §A.3 table keep fromSeed values"
  - "N6 FilledButton.tonal takes the #635BFF filled-button background -> SPEC-SHELL-001"
  - "registerKolbiFontLicenses() call in app/lib/main.dart -> SPEC-SHELL-001 (listed in SHELL plan.md:54; grep -rn registerKolbiFontLicenses app/lib -> no match on 2026-11-27)"
device_check: pending   # owner: variable-font weight rendering and real-font overflow on a device
plan_g_items:
  docs/planning/06_DESIGN_DECISIONS.md: "§3 implementation note (values unchanged; neutral chip bg, caution = neutral, #635BFF never text); §7 Q-1 and Q-2 closed"
  docs/planning/04_DESIGN_PLAN.md: "§4 revision block: caution = neutral, chip category table link (plan §A.2), seed now #635BFF"
  .moai/project/tech.md: "font asset, OFL licence, Pretendard v1.3.9 source and sha256, build size, main.dart call pending (SHELL)"
  SPEC-UX-001: "done in 8d6770f (spec 0.3.1: OD-2/OD-4 superseded by SPEC-DESIGN-001, AC-002 seed 0xFF635BFF)"
  SPEC-SHELL-001: "checked only: the main.dart line is in SHELL plan.md:54 and not yet in app/lib; SHELL docs unchanged"
project_docs_synced: [.moai/project/tech.md, .moai/project/structure.md, .moai/project/codemaps/modules.md, docs/planning/06_DESIGN_DECISIONS.md, docs/planning/04_DESIGN_PLAN.md, .moai/specs/EPIC-KOLBI-APP/overview.md]
sync_audit: "PASS 89.8 (harmonic mean), .moai/reports/sync-audit/SPEC-DESIGN-001-audit-1.md; F1 Medium: variable font registered without weight entries or fontVariations, w600/w700 may render at 400 or synthetic bold on devices (owner device check); F2 dark neutral chip bg equals card colour (N4); F3 font 6.7MB; F4 registerKolbiFontLicenses call owned by SHELL-001"
status_transition: implemented -> completed (sync audit passed, owner rule 2026-11-27)
```

## §F Phase 4 Mode Selection

- kickoff: Implementation Kickoff Approval given by owner on 2026-11-27 ("바로 시작", progression autonomous, sync + audit + push at the end)
- precondition: SPEC-MODULE-001 `completed` (466c73b)
- font: owner approved PretendardVariable.ttf 6,739,336 bytes (plan assumed about 2MB) and LICENSE (OFL 1.1, 4,418 bytes) from github.com/orioncactus/pretendard tag v1.3.9 (raw paths packages/pretendard/dist/public/variable/PretendardVariable.ttf and LICENSE). Downloaded by the orchestrator to packages/kolbi_ui/assets/fonts/ (LICENSE saved as OFL.txt); sha256 3090ccde0442bb347aa7685d9ba8b17436a60682df6e8f92a9a670de14056e22 (ttf), d31ddd9f2bed32fd7e302a205cf2380ba0de6529152d239ef99cfb6f261bfc04 (OFL.txt)
- inputs: tier M, about 16 files, domains: kolbi_ui theme/widgets + one app/lib line + tests, language mix Dart/YAML, concurrency benefit LOW (M1 value gate before M2/M3)
- evaluation: direct — not selected (multi-file); fanout — not selected (coding-heavy, gated sequence); sweep — not selected (small, non-uniform); serial — selected
- Decision: serial
- justification: M1 must pass the contrast gate before chip and font work, and every milestone edits the same theme file, so one implementation agent working in order is the safe shape
