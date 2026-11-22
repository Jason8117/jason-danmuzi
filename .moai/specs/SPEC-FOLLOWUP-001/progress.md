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

## §E.3 Run-phase Audit-Ready Signal

_<pending run-phase>_

## §E.4 Sync-phase Audit-Ready Signal

_<pending sync-phase>_
