# SPEC-FOLLOWUP-001 진행 기록

## §E.1 Plan-phase Audit-Ready Signal

- plan_status: revised after plan-audit iteration 1 (FAIL 0.83; D13-D15 fixed, D16, D17 applied) — re-audit pending
- spec_version: 0.3.0 (plan-audit iteration 2: PASS 0.92; A4-A8 applied; calendar label default flipped to "캘린더 파일 보내기")
- plan_complete_at: 2026-11-21
- base_sha: c664596
- tier: M (file count 22 exceeds the M guidance; rationale in plan.md §B; auditor D23 accepted M), harness: standard (recommended)
- artifacts: spec.md, plan.md, acceptance.md, research.md, progress.md
- counts: 16 REQ / 16 AC
- depends_on: SPEC-INTAKE-001
- open_decisions: OD-1 ~ OD-6 DEFAULT (pending owner review); OD-1 adds one direct app dependency (`share_plus`); OD-6 calendar label depends on a manual device check
- note: test-fixture lines in two SPEC-INTAKE-001 widget tests change by design (trust-notice acknowledgement key) — AC-016
- release note: server and app ship in the same release
- run-entry note: manager-develop records `run_start_sha` (HEAD at run entry) and the measured test baseline as the first lines of §E.2

## §E.2 Run-phase Evidence

- run_start_sha: d161cababb99a65976dbe2289e32ce1f9a4d59df (worktree branch `worktree-agent-a5b78f4e1ddbd3153`, fast-forwarded from c95953f with `git merge --ff-only d161cab`)
- cycle_type: tdd; single serial writer; evidence files under `.moai/state/verify/followup-run/followup/`
- environment: Node v23.7.0 (`/opt/homebrew/Cellar/node/23.7.0/bin`), Flutter 3.50.1

### Baseline (run entry, HEAD d161cab, before any change)

| Check | Command | Observed |
|---|---|---|
| server tests | `npm --prefix server test` | exit 0, `Test Files  14 passed (14)` / `Tests  370 passed (370)` (`baseline-server-test.txt`) |
| server typecheck | `npm --prefix server run typecheck` | exit 0 |
| test-file compile | `tsc -p server/tsconfig.testcheck.json` (temporary: extends tsconfig.json, `include: ["src"]`, `exclude: []`, noEmit; deleted after each run) | exit 0 |
| app pub get | `cd app && flutter --suppress-analytics pub get` | exit 0 |
| app tests | `cd app && flutter --suppress-analytics test` | exit 0, `+53: All tests passed!` |
| app analyze | `cd app && flutter --suppress-analytics analyze` | `1 issue found` — info `use_null_aware_elements` at `test/support/fakes.dart:54:5` |

### M1 — server `appointment` (AC-001 ~ AC-004)

- RED: `npm --prefix server test -- src/brain/openaiBrain.test.ts src/brain/heuristicBrain.test.ts` → exit 1, `Tests  4 failed | 64 passed (68)`. Failures: the three keep-rows of "keeps only a confirmed, well-formed appointment" (`AssertionError: expected undefined to deeply equal { title: '라 파스타 저녁 예약', …(1) }` and the two siblings) and "sends the reference time and asks for confirmed appointments only" (`RangeError: Invalid time value` — no `referenceTime` sent). Test-file compile → exit 1: `openaiBrain.test.ts(407,86): error TS2353: … 'appointment' does not exist in type 'CallOutcome'` and `(472,25): error TS2339` (AC-001 (2) RED is this type error, as the AC says). The drop-rows, AC-004 and the heuristic guard passed before GREEN (they assert absence; the guard is a protection test). Evidence: `m1-red.txt`, `m1-red-testcompile.txt`.
- GREEN: `npm --prefix server test` → exit 0, `Test Files  14 passed (14)` / `Tests  387 passed (387)`; typecheck exit 0; test-file compile exit 0. Evidence: `m1-green.txt`, `m1-typecheck.txt`, `m1-testcompile.txt`.
- Plan §F check: `grep -n "appointment" server/src/brain/heuristicBrain.ts | wc -l` → `0`.
- Implementation: `OutcomeSchema.appointment` is `z.unknown().optional()`; a pure `confirmedAppointment(raw, referenceTime, targetName)` applies REQ-002 (b)-(e) after the schema; `failed` drops it; no log line. Reference time = `task.endedAt`, else `Date.now()`. A non-string, non-null `title` is treated as malformed (drop); a missing or null title becomes `<targetName> 일정`; `endsAt: null` is treated as absent. `startsAt`/`endsAt` are kept as the LLM wrote them (not re-normalized).
- Commit: `3e08fcb`.

### M2 — dependency and app model (OD-1, AC-005, AC-016 dependency part)

- First step: `cd app && flutter --suppress-analytics pub add share_plus` → exit 0. Verbatim output (`m2-pub-add.txt`):

  ```
  Resolving dependencies...
  Downloading packages...
  + cross_file 0.3.5+5 (0.4.0 available)
  + ffi_leak_tracker 0.1.2
  + jni_flutter 1.1.0
    material_color_utilities 0.13.0 (0.13.1 available)
  + mime 2.1.0
  + path_provider 2.1.6
  + path_provider_android 2.3.1
  + path_provider_foundation 2.6.0
  + share_plus 13.3.1
  + share_plus_platform_interface 7.2.0
    test_api 0.7.14 (0.7.15 available)
  + url_launcher_linux 3.2.3
  + url_launcher_platform_interface 2.3.2
  + url_launcher_web 2.4.3
  + url_launcher_windows 3.1.6
    vector_math 2.4.3 (2.4.4 available)
  + win32 6.4.0
  Changed 14 dependencies!
  4 packages have newer versions incompatible with dependency constraints.
  Try `flutter pub outdated` for more information.
  ```

- Resolved: `share_plus 13.3.1` (`app/pubspec.yaml` gains one line `share_plus: ^13.3.1` under `dependencies:`). `pubspec.lock` gains 14 entries: `share_plus` (`dependency: "direct main"`) and 13 transitive — `cross_file 0.3.5+5`, `ffi_leak_tracker 0.1.2`, `jni_flutter 1.1.0`, `mime 2.1.0`, `path_provider 2.1.6`, `path_provider_android 2.3.1`, `path_provider_foundation 2.6.0`, `share_plus_platform_interface 7.2.0`, `url_launcher_linux 3.2.3`, `url_launcher_platform_interface 2.3.2`, `url_launcher_web 2.4.3`, `url_launcher_windows 3.1.6`, `win32 6.4.0` (`git diff --stat -- app/pubspec.lock` → `112 insertions(+)`, no deletions). Note: `path_provider` now appears as a transitive package (share_plus writes the in-memory file to a temp dir itself); the app does not depend on it directly.
- Compatibility: Dart `3.14.0 (stable)`, Flutter 3.50.1. After the add (before any code change): `flutter test` → `+53: All tests passed!` (`m2-postadd-test.txt`), `flutter analyze` → `1 issue found` (baseline info only, `m2-postadd-analyze.txt`).
- API checked in the package source (`~/.pub-cache/hosted/pub.dev/share_plus-13.3.1`, `share_plus_platform_interface-7.2.0`, `cross_file-0.3.5+5`): `SharePlus.instance.share(ShareParams(text: …))`, `ShareParams(files: [XFile.fromData(bytes, mimeType: …)], fileNameOverrides: […])` (on io `XFile.fromData` ignores `name`, so the file name goes through `fileNameOverrides`). No `path_provider` import is needed in the app.
- RED: `cd app && flutter --suppress-analytics test test/unit_test.dart` → exit 1, `test/unit_test.dart:268:7: Error: 'Appointment' isn't a type.` / `test/unit_test.dart:277:92: Error: The getter 'appointment' isn't defined for the type 'CallOutcome'.` (`m2-red.txt`).
- GREEN: `cd app && flutter --suppress-analytics test` → `+54: All tests passed!` (`m2-green.txt`); `flutter analyze` → `1 issue found` (baseline info only, `m2-analyze.txt`).
- Implementation: `Appointment.tryParse` (`call_models.dart`) — null unless a map with a parseable `startsAt`; instants kept in UTC; a missing/non-string title becomes `''`; an unparseable `endsAt` becomes null.
- Commit: `941f700`.

### M3 — call again → plan card (AC-007)

- RED: `cd app && flutter --suppress-analytics test test/follow_up_test.dart` → exit 1, `Expected: exactly one matching candidate` / `Actual: _TextWidgetFinder:<Found 0 widgets with text "이렇게 걸어 볼게요": []>` at `follow_up_test.dart line 83` (the old form opened). The first attempt failed to compile for a harness reason (`'Override' isn't a type` — Riverpod 3 exports it from `flutter_riverpod/misc.dart`); fixed in the test's imports before the RED above was recorded. Evidence: `m3-red.txt`.
- GREEN: `cd app && flutter --suppress-analytics test` → `+55: All tests passed!` (`m3-green.txt`); `flutter analyze` → `1 issue found` (baseline info only, `m3-analyze.txt`).
- One test-only adjustment during GREEN (assertions unchanged): the first GREEN run found `02-123-4567` twice because the detail route is still onstage during the 400 ms push transition (same cause INTAKE M5 recorded); the plan-card assertions are scoped with `find.descendant(of: find.byType(PlanCardScreen), …)`.
- Implementation: `PlanDraft.fromTask(task)` (target, E.164 number, goal, context, language, `PhoneSource.previousCall`), new `PhoneSource.previousCall('지난번과 같은 번호')`; the detail screen's "다시 걸기" pushes `/plan` with that draft. `plan_card_screen.dart` needed no change for the source label (it already renders `phoneSource.label`); its planned change lands in M4 (trust gate). The `/calls/new` route keeps accepting a `CallTask` extra (no caller now) — left untouched as out of scope.
- Commit: `db249ac`.

### M4 — trust notice (AC-013 constants, AC-014, AC-015, AC-016 intended setup change)

- RED (compile): `cd app && flutter --suppress-analytics test test/trust_notice_test.dart` → exit 1, `Error when reading 'lib/features/calls/presentation/trust_notice.dart': No such file or directory` / `Undefined name 'trustStatements'` (`m4-red.txt`).
- RED (behavior, after adding only the six constants): same command → exit 1, `+1 -3`: "trust statements are exactly the agreed six" passed; AC-014 (1)-(4) and (5) failed with `Actual: _TextWidgetFinder:<Found 0 widgets with text "AI 비서는 통화를 시작할 때 AI라고 먼저 밝히도록 정해져 있어요.": []>` (line 94), AC-015 with `Found 0 widgets with text "AI 비서와 기록"` (line 168). Evidence: `m4-red-behavior.txt`.
- First GREEN run (`m4-green-1.txt`): exit 1. Expected failures in `plan_card_test.dart` "(1)/(5)/(6) starts the call with one tap" (the notice now precedes the first start — the AC-016 case). One unexpected failure: `approval_flow_test.dart` "user approves a mid-call request…" — `Found 0 widgets with text "네, 라 파스타입니다."` (line 53). Cause: that test runs on the default 800×600 surface, and the live-call line placed above the transcript pushed the transcript line out of the lazily built list. The test stays unmodified; the line moved below the transcript (it no longer displaces the header or live lines).
- AC-016 intended change: `app/test/plan_card_test.dart:59` `SharedPreferences.setMockInitialValues({'requesterName': '김민수'})` → `({'requesterName': '김민수', 'trustNoticeAcknowledged': true})` — `git diff -U0 -- app/test/plan_card_test.dart app/test/intake_flow_test.dart` shows that one line only. **`app/test/intake_flow_test.dart` is not modified**: its tests never press a gated button (the manual form's "통화 계획 만들기" is not a REQ-014 trigger), and it passes as is. AC-016 permits the change; it was not needed, so REQ-016 "unmodified" is kept for that file.
- GREEN: `cd app && flutter --suppress-analytics test` → `+59: All tests passed!` (`m4-green.txt`); `flutter analyze` → `1 issue found` (baseline info only, `m4-analyze.txt`).
- Implementation: `trust_notice.dart` — `trustStatements` (REQ-013 verbatim), `agentRulesNotice` (statements (1)(2)(5) joined by a space, used by the manual form), `liveCallTrustLine`, `ensureTrustAcknowledged(context, ref)` (modal bottom sheet with [확인했어요]; barrier/back returns false and nothing is sent), `TrustStatementList`. `AppSettings.trustNoticeAcknowledged` + `SettingsController.acknowledgeTrustNotice()` (prefs key `trustNoticeAcknowledged`; `save()` preserves the flag, because the settings form builds a fresh `AppSettings` without it). Gates: plan card `_start` and the detail screen's "이대로 전화 걸기". Settings: "AI 비서와 기록" card. Manual form (`new_call_screen.dart`): the guarantee paragraph is replaced by `agentRulesNotice`.
- Wording note (audit advisory A3-2): the SPEC text was used exactly as written; statement (6) says "서버에 OpenAI가 연결되어 있으면, …" and "실제 통화에서는 회신 번호도 …" without an "if a callback number is set" qualifier. That is what REQ-013 fixes; the callback number is only sent when one is set (`prompts.ts:28` `task.callbackNumber ? … : ""`), so the sentence reads as a general statement rather than "if set". Not edited (SPEC body is out of scope); flagged for manager-spec.
- Commit: `ed5ea07`.

### M5 — copy, share, calendar (AC-009, AC-011, AC-010, AC-006, AC-008, AC-012)

- RED (compile): `cd app && flutter --suppress-analytics test test/follow_up_test.dart` → exit 1, `Error when reading 'lib/features/calls/domain/follow_up.dart': No such file or directory`, `… widgets/follow_up_actions.dart …`, `Method not found: 'buildShareText'` / `'offersCalendarDraft'` / `'buildCalendarDraft'` (`m5-red.txt`).
- RED (behavior, with signature stubs returning `''` / `false` and the widget not wired): same command → exit 1, `+1 -6`. "builds the share text (1)-(4)" — `Which: is different. Both strings start the same, but the actual value is missing the following trailing characters: [목표 달성] 라 …`; "offers a calendar draft only for confirmed LLM outcomes" — `at location [0] is <false> instead of <true>`; "builds an RFC 5545 calendar draft (1)-(6)" — `at location [0] is [] which shorter than expected`; "shows follow-up actions that match the outcome" — `Found 0 widgets with text "요약 복사"` (line 301); "copies and shares the summary" and "shares the calendar draft as a file" failed (no buttons). AC-007 stayed green. Evidence: `m5-red-behavior.txt`.
- First GREEN run (`m5-green-1.txt`): `+5 -1` — "copies and shares the summary" `Found 0 widgets with text "공유할 수 없어 복사했어요"` (line 320): the earlier "요약을 복사했어요" snackbar was still showing, so the next was queued. Fix in the widget (not the test): each new notice hides the current snackbar first.
- GREEN: `flutter --suppress-analytics test test/follow_up_test.dart` → `+7: All tests passed!` (`m5-green-2.txt`); full `flutter --suppress-analytics test` → `+65: All tests passed!` (`m5-green.txt`); `flutter analyze` → `1 issue found` (baseline info only, `m5-analyze.txt`; an intermediate run showed one new `unnecessary_import` info for `dart:typed_data` in `follow_up_actions.dart`, removed).
- AC-009 (5) time-zone determinism (this run):
  - `cd app && TZ=UTC flutter --suppress-analytics test test/follow_up_test.dart` → exit 0, `00:02 +7: All tests passed!` (`m5-tz-utc.txt`)
  - `cd app && TZ=Asia/Seoul flutter --suppress-analytics test test/follow_up_test.dart` → exit 0, `00:02 +7: All tests passed!` (`m5-tz-seoul.txt`)
  - extra: `TZ=America/Los_Angeles` → exit 0, `00:02 +7: All tests passed!` (`m5-tz-la.txt`)
- Implementation: `follow_up.dart` (pure) — `buildShareText(task, {displayOffset = +09:00})` (shifts the UTC instant and formats `y년 M월 d일 a h:mm` in `ko`; `endedAt`, else `updatedAt`), `offersCalendarDraft(outcome)`, `buildCalendarDraft(task, {required now})` (CRLF, TEXT escaping backslash-first, rune-wise 75-octet folding with the leading space counted, `DTEND = startsAt + 60 min` when no `endsAt`, untitled → `<상대 이름> 일정`). `follow_up_actions.dart` — `FollowUpService` (copy / share text / share file), `DeviceFollowUpService` (`Clipboard.setData`; `SharePlus.instance.share(ShareParams(text:))`; `ShareParams(files: [XFile.fromData(bytes, mimeType:, name:)], fileNameOverrides: [name])`), `followUpServiceProvider`, `followUpClockProvider`, `FollowUpActions` widget (replaces the detail screen's terminal-state action; "다시 걸기" moved into it). Share returning `unavailable`/`dismissed` is not treated as failure (several platforms report `unavailable` after showing the sheet); only a thrown error falls back to copy.
- AC-005 (5) `.ics` default title is asserted in "builds an RFC 5545 calendar draft" (`SUMMARY:라 파스타 일정`).
- Commit: `36a926e`.

### M6 — regression, compatibility, AC-013 command table (AC-016, AC-013)

Final verification batch at HEAD `36a926e` (this run, this tree):

| Check | Command | Observed |
|---|---|---|
| server tests | `npm --prefix server test` | exit 0, `Test Files  14 passed (14)` / `Tests  387 passed (387)` (`m6-server-test.txt`; baseline 14 / 370) |
| server typecheck | `npm --prefix server run typecheck` | exit 0 |
| test-file compile | `tsc -p server/tsconfig.testcheck.json` (temporary, deleted after; `ls` afterwards → `No such file or directory`) | exit 0 |
| layering rules | `npm --prefix server test -- src/architecture.test.ts` | exit 0, `Tests  4 passed (4)`; file not modified |
| app tests | `cd app && flutter --suppress-analytics test` | exit 0, `+65: All tests passed!` (`m6-app-test.txt`; baseline +53) |
| app targeted | `cd app && flutter --suppress-analytics test test/follow_up_test.dart test/trust_notice_test.dart test/unit_test.dart` | exit 0, `+32: All tests passed!` |
| app analyze | `cd app && flutter --suppress-analytics analyze` | `1 issue found` — the baseline info only (`test/support/fakes.dart:54:5`) |
| existing test bodies | `git diff d161cab HEAD -- app/test server/src \| grep -nE '^-[^-]\|^\+\+\+ '` | removed lines in test files: only `app/test/plan_card_test.dart` line `-    SharedPreferences.setMockInitialValues({'requesterName': '김민수'});` (the AC-016 change). `unit_test.dart`, `heuristicBrain.test.ts`, `openaiBrain.test.ts` have additions only (new tests, two import lines). The other three removed lines are product code (`openaiBrain.ts` ×2, `prompts.ts` ×1) |
| untouched files | `git diff --stat d161cab HEAD -- server/package.json server/package-lock.json app/test/intake_flow_test.dart app/test/support/fakes.dart` | no output (none changed) |
| dependency | `git diff d161cab -- app/pubspec.yaml` | one added line under `dependencies:`: `+  share_plus: ^13.3.1` |
| boundary | `git diff --stat d161cababb99a65976dbe2289e32ce1f9a4d59df..HEAD` | `23 files changed, 1420 insertions(+), 18 deletions(-)` = 21 of the 22 plan §B files (all except `app/test/intake_flow_test.dart`, not needed — see M4) + `spec.md` + `progress.md`; nothing outside the plan |

AC-013 command table (this run, repository root of the worktree):

| Item | Command | Observed |
|---|---|---|
| (1) | `grep -c "Always say you are an AI assistant in your first sentence" server/src/brain/prompts.ts` | `1` |
| (2) | `grep -c "call the request_user_approval tool" server/src/brain/prompts.ts` | `1` |
| (3) | `grep -c 'app.delete("/v1/tasks/:id"' server/src/http/app.ts` | `1` |
| (4) | `grep -ci "audio" server/src/domain/types.ts` | `0` (exit 1) |
| (4) | `grep -rln "writeFile\|createWriteStream\|appendFile" server/src \| grep -v "\.test\.ts"` | `server/src/store/taskStore.ts` |
| (5) | `grep -c "Never give card numbers, passwords" server/src/brain/prompts.ts` | `1` |
| (6) | `grep -c 'api.openai.com/v1/chat/completions' server/src/brain/openaiBrain.ts` | `1` |
| (6) | `grep -c 'goal: input.goal' server/src/brain/openaiBrain.ts` | `1` |
| (6) | `grep -c 'userComment: a.userComment' server/src/brain/openaiBrain.ts` | `1` |
| (6) | `grep -c 'transcript: task.transcript' server/src/brain/openaiBrain.ts` | `1` |
| (6) name/info/callback | `grep -c 'requesterName: input.requesterName' server/src/brain/openaiBrain.ts` | `1` |
| (6) | `grep -c 'shareableInfo: input.context' server/src/brain/openaiBrain.ts` | `1` |
| (6) | `grep -c 'Callback number: ' server/src/brain/prompts.ts` | `1` |
| (6) | `grep -c 'agentInstructions: () => buildAgentInstructions' server/src/services/callService.ts` | `1` |
| (6) | `grep -c 'session.agentInstructions()' server/src/providers/realtimeBridge.ts` | `1` |
| plan §F | `grep -n "appointment" server/src/brain/heuristicBrain.ts \| wc -l` | `0` |

The (1)(2)(5) rows show only that the instruction strings exist; whether the model follows them is not verified (OD-3 accepted risk). Note: M1 added a sentence to `SUMMARY_SYSTEM_PROMPT` (the summary request now also sends `referenceTime`/`timezone`); statement (6) still holds — no new user data is sent.

### AC matrix

| AC | Status | Test (file — name) | RED observed |
|---|---|---|---|
| AC-001 | PASS | `openaiBrain.test.ts` — "keeps outcomes without an appointment valid"; typecheck exit 0 | M1: test-file compile `TS2353 'appointment' does not exist in type 'CallOutcome'` |
| AC-002 | PASS | `openaiBrain.test.ts` — "keeps only a confirmed, well-formed appointment" (13 rows) | M1: 3 keep-rows `expected undefined to deeply equal {…}`; drop-rows passed before (absence) |
| AC-003 | PASS | `openaiBrain.test.ts` — "sends the reference time and asks for confirmed appointments only"; existing SPEC-OUTCOME-001 AC-008 test unmodified | M1: `RangeError: Invalid time value` |
| AC-004 | PASS | `heuristicBrain.test.ts` — "never attaches an appointment"; `openaiBrain.test.ts` — "the fallback outcome has no appointment" | guard tests: passed before GREEN (absence holds by construction), as the AC notes for (1) |
| AC-005 | PASS | `unit_test.dart` — "parses appointments defensively"; (5) `.ics` title in "builds an RFC 5545 calendar draft" | M2: `'Appointment' isn't a type` |
| AC-006 | PASS | `follow_up_test.dart` — "shows follow-up actions that match the outcome" (8 rows) | M5: `Found 0 widgets with text "요약 복사"` |
| AC-007 | PASS | `follow_up_test.dart` — "call again opens a filled plan card" | M3: `Found 0 widgets with text "이렇게 걸어 볼게요"` (old form opened) |
| AC-008 | PASS (fake service) | `follow_up_test.dart` — "copies and shares the summary" | M5: no buttons |
| AC-009 | PASS | `follow_up_test.dart` — "builds the share text (1)-(4)"; (5) TZ=UTC and TZ=Asia/Seoul re-runs both `+7: All tests passed!` | M5: `actual value is missing the following trailing characters: [목표 달성] …` |
| AC-010 | PASS | `follow_up_test.dart` — "offers a calendar draft only for confirmed LLM outcomes" | M5: `at location [0] is <false> instead of <true>` |
| AC-011 | PASS | `follow_up_test.dart` — "builds an RFC 5545 calendar draft (1)-(6)" | M5: `at location [0] is [] which shorter than expected` |
| AC-012 | PASS (fake service) | `follow_up_test.dart` — "shares the calendar draft as a file" | M5: no buttons |
| AC-013 | PASS | `trust_notice_test.dart` — "trust statements are exactly the agreed six"; command table above | M4: `Undefined name 'trustStatements'` |
| AC-014 | PASS | `trust_notice_test.dart` — "asks for the trust notice once before the first call (1)-(4)", "… (5) on the plan review" | M4: `Found 0 widgets with text "AI 비서는 통화를 시작할 때 …"` |
| AC-015 | PASS | `trust_notice_test.dart` — "shows trust statements in settings and during calls" (1)-(4) | M4: `Found 0 widgets with text "AI 비서와 기록"` |
| AC-016 | PASS | full suites, `architecture.test.ts`, existing-test diff, dependency diff above | n/a (regression) |
| DoD device check (not an AC) | **deferred to device check** | Android + iOS: does the default calendar appear in the share sheet for `appointment.ics`, and does it open an event draft? Also the real share sheet for text, and clipboard on device | not run — no device in this run; label stays "캘린더 파일 보내기" (OD-6) |

### Addendum — notes for sync / manager-spec

- AC-016 named two INTAKE test files; only `plan_card_test.dart` needed the setup line. `intake_flow_test.dart` is unmodified (its tests never press a REQ-014 trigger).
- Audit advisory A3-2 (statement (6) "회신 번호" wording has no "if set" qualifier): SPEC text used verbatim; for manager-spec to decide.
- The first call on a device passes two confirmations (plan card [이대로 시작] + trust notice [확인했어요]) — acceptance.md residual risk, to surface in sync docs.
- Share result `unavailable`/`dismissed` is not treated as failure (only thrown errors fall back to copy) — on platforms that report `unavailable` after a real failure, the user sees no toast.
- `IntakeResult.fromJson` parses `phoneSource` by enum name, so a server sending `"previousCall"` would map to the new app-only value; the server never sends it.

## §E.3 Run-phase Audit-Ready Signal

```yaml
run_complete_at: 2026-11-22
run_start_sha: d161cababb99a65976dbe2289e32ce1f9a4d59df
run_commit_sha: 36a926e   # last implementation commit (M5); the M6 commit that carries this section is evidence-only
run_status: complete
ac_pass_count: 16
ac_fail_count: 0
ac_notes: "AC-008/AC-012 pass against the injected fake service; the real share sheet and calendar-app acceptance of .ics are deferred to the device check (DoD)"
device_check: deferred   # Android/iOS default calendar via share sheet — human-judged, not run
milestone_commits: [3e08fcb, 941f700, db249ac, ed5ea07, 36a926e]
share_plus_resolved: "13.3.1 (direct); 13 transitive lock entries"
server_tests: "14 files / 387 tests passed (baseline 14 / 370)"
server_typecheck_exit: 0
test_file_compile_exit: 0
architecture_test: "4 passed, unmodified"
app_tests: "+65 passed (baseline +53)"
app_analyze: "1 info (baseline info, fakes.dart:54)"
existing_tests_modified: "plan_card_test.dart setup line only (AC-016)"
new_warnings_or_lints_introduced: 0
total_run_phase_files: 23   # 21 of 22 planned (intake_flow_test.dart not needed) + spec.md + progress.md
m1_to_mN_commit_strategy: "one commit per milestone on the worktree branch; no push, no amend"
l44_pre_commit_fetch: not-run   # isolated worktree; no fetch/push requested
l44_post_push_fetch: not-applicable   # no push
cross_platform_build: not-applicable   # TypeScript + Flutter tests only; no device or platform build run
external_services_contacted: none   # OpenAI and KAT were never called; fetch and the share service were faked
```

## §E.4 Sync-phase Audit-Ready Signal

```yaml
sync_complete_at: 2026-11-27
sync_commit_sha: "the docs(SPEC-FOLLOWUP-001) sync commit that adds this section (resolve via git log)"
sync_status: implemented
run_commit_sha: 36a926e   # §E.3 value: last implementation commit (M5) on worktree branch worktree-agent-a5b78f4e1ddbd3153
run_commit_sha_on_main: fad4e60   # the same M5 landed on main as fad4e60 (git diff --quiet 36a926e fad4e60 -> exit 0, identical tree); M6 evidence commit -> ba1ee17 on main
run_start_sha: d161cababb99a65976dbe2289e32ce1f9a4d59df   # SPEC-INTAKE-001 M7 evidence commit on main
depends_on_note: "depends_on SPEC-INTAKE-001 was `in-progress` when this run started; it closes at `implemented` in the sync commit just before this one (this repository's terminal value is `implemented`, see SPEC-UX-001 §E.4 sync-audit C1)"
sync_evidence_source: orchestrator   # measured by the orchestrator on HEAD 8ad8239 on 2026-11-27, not by this agent; evidence under .moai/state/verify/coverage/ (gitignored, local only)
app_tests_at_sync: "00:08 +84: All tests passed!"   # cd app && flutter --suppress-analytics test --coverage
app_line_coverage_at_sync: "1497/1689 = 88.6% (app + kolbi_core + kolbi_ui, from app tests; combined.lcov)"
server_tests_at_sync: "Tests 387 passed (387); Lines 95.42% (1085/1137), Statements 92.3%, Branches 81.49%, Functions 91.66%"   # npx vitest run --coverage (server.txt); 387 = the §E.2 M6 server count
server_typecheck_exit_at_sync: 0   # npm --prefix server run typecheck
web_build_at_sync: "✓ Built build/web"   # cd app && flutter build web --debug
browser_run_at_sync: "web build against a simulated server (CALL_PROVIDER=simulated, no .env): plan card -> trust notice -> live call -> approval -> result card with summary, decisions and follow-up actions (다시 걸기 / 요약 복사 / 공유); browser console: no errors"
acceptance_distinct_ac_ids: 17   # grep -oE 'AC-([A-Z0-9]+-)*[0-9]+' acceptance.md | sort -u | wc -l -> 17; §E.3 ac_pass_count 16
ac_count_note: "the 17th id is AC-021, a cross-reference to SPEC-INTAKE-001 AC-021 inside AC-014 (acceptance.md:202, \"SPEC-INTAKE-001 AC-021의 초안\"), not an AC of this SPEC; AC-001..AC-016 = 16 = ac_pass_count"
ac_matrix_test_names_at_sync: all-present   # every test name cited in the §E.2 AC matrix found by grep -F in server/src or app/test at HEAD 8ad8239
frontmatter_status_transitions:
  spec.md: in-progress -> implemented   # updated: 2026-11-22 -> 2026-11-27; spec/plan/acceptance bodies unchanged
changelog_entry_position: not-applicable   # repository has no CHANGELOG.md
mx_scan: skipped   # --skip-mx semantics
divergence:
  planned_vs_changed_files: "21 of 22 planned"   # git diff --name-only d161cab..fad4e60 = 21 plan.md §B files (5 server + 16 app incl. pubspec.yaml/pubspec.lock) + spec.md + progress.md; no unplanned file
  planned_but_unchanged: [app/test/intake_flow_test.dart]   # AC-016 allowed a setup-line change; not needed (its tests never press a REQ-014 trigger), §E.2 M4
  deviations: "§E.2 M4 live-call trust line placed below the transcript (keeps approval_flow_test.dart unmodified on 800x600); M5 each follow-up notice hides the current snackbar first; share result unavailable/dismissed not treated as failure; audit advisory A3-2 (statement (6) callback-number wording) left for manager-spec"
later_changes:   # history not rewritten; paths below are the current locations at 8ad8239
  SPEC-UX-001: "call_detail_screen.dart, plan_card_screen.dart, new_call_screen.dart, trust_notice.dart, widgets/follow_up_actions.dart, settings_screen.dart restyled (tokens, AppCard)"
  SPEC-MODULE-001: "app/lib/features/calls/domain/follow_up.dart is now a re-export of packages/kolbi_core/lib/src/follow_up.dart; call_models.dart and intake_models.dart re-export packages/kolbi_core/lib/src/models/; app/pubspec.lock replaced by the workspace root pubspec.lock; share_plus stays a direct dependency of app/pubspec.yaml (^13.3.1) and kolbi_ui must not import it (packages/kolbi_ui/test/dependency_rules_test.dart); trust_notice.dart and widgets/follow_up_actions.dart stay in the app"
device_check: deferred   # §E.2/§E.3: Android and iOS share sheet, default calendar accepting appointment.ics, and clipboard on device not run; at sync no Xcode/simulator on this Mac, so real-device screen reader and haptics were not run either; label stays "캘린더 파일 보내기" (OD-6)
residual_risks_carried: "AC-008/AC-012 pass against the injected fake service only; the first call on a device passes two confirmations (plan card + trust notice); platforms that report share `unavailable` after a real failure show no toast"
project_docs_synced: [.moai/project/structure.md, .moai/project/tech.md, .moai/project/codemaps/modules.md, .moai/project/codemaps/dependencies.md, .moai/specs/EPIC-ASSISTANT-UX/overview.md]   # trust_notice.dart, widgets/follow_up_actions.dart, AppSettings.trustNoticeAcknowledged; committed once for the three SPECs in the docs(SPEC-ASSISTANT-UX) commit that follows this one
tech_md: updated   # share_plus ^13.3.1 (the one new direct dependency, OD-1) was missing from tech.md and codemaps/dependencies.md; added in the docs(SPEC-ASSISTANT-UX) commit
sync_audit: pending
```
