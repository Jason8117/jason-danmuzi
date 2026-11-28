# SPEC-ASSIST-001 진행 기록

## §E.1 Plan-phase Audit-Ready Signal

- owner_verdict: PASS-with-debt (owner decision 2026-11-26, iteration 3 at 0.83; N8/N9 fixed). Tier deviation signed off: stays Tier M with 33 files (14 are one-block test edits or declarations)
- plan_status: audit-ready (plan-audit not yet run)
- plan_status_final: plan-audit iteration 3/3 PASS-with-debt 0.83 (report .moai/reports/plan-audit/SPEC-ASSIST-001-review-3.md); blocking N8, N9 fixed after the report; owner sign-off pending for tier deviation (33 files, Tier M kept) or SCR-T08 split
- audit_debt (during run): N10 add SHELL navigation.dart (submitFromAssistant obsolete) and route names for assistant child routes to plan §B; N12 SHELL AC-005 row assumes a not-yet-written SHELL test; N14 REQ-006 vs plan A.1 failure rule + remembered fallback in REQ-006; N11/N13/N15/N16/N17 fixed in docs
- spec_version: 0.3.0 (plan-audit iteration 2: FAIL 0.77, report .moai/reports/plan-audit/SPEC-ASSIST-001-review-2.md; D2 and N1-N7 addressed; should-fix D8-D12 addressed)
- spec_version_0.2.0: (plan-audit iteration 1: FAIL 0.71, report .moai/reports/plan-audit/SPEC-ASSIST-001-review-1.md; must-fix D1-D7, D9-D11 addressed; should-fix D8, D12, D13, D15 addressed, D14 partly (scope notes), D16 partly)
- spec_version_history: 0.1.0
- plan_complete_at: 2026-11-26
- base_sha: c2e732d (plus uncommitted planning docs; run-phase records run_start_sha after SPEC-SHELL-001 completes)
- tier: M (about 30 files; above the M file band — owner to judge), harness: standard (recommended), methodology: tdd
- artifacts: spec.md, plan.md, acceptance.md, progress.md
- counts: 16 REQ / 16 AC
- depends_on: SPEC-SHELL-001, SPEC-DESIGN-001
- open_decisions: OD-1 decided (device speech recognition, text only to server); OD-2 ~ OD-5 DEFAULT (pending owner review)
- intended test changes: see acceptance.md AC-016 table (fakes.dart additive; intake_flow_test helper + named blocks; approval_flow_test :36-37; accessibility_test :341-343, :563, home order block; shell_test SHELL-001 0.3.0 AC-006 (2); today_test AC-015/AC-016; inbox_test AC-012 (1); intake_flow_test :138)
- verified at plan time: no speech package in app/pubspec.yaml; iOS Info.plist has no microphone/speech usage strings; AndroidManifest has INTERNET only; intake entry is home_screen.dart _IntakeBox (:153, :188); call detail hosts TranscriptView (:186) and pinned ApprovalCard (:172)
- note: app + kolbi_ui only; no server change

## §E.2 Run-phase Evidence

Evidence files (gitignored, kept for audit): `.moai/state/verify/SPEC-ASSIST-001/{pre,red,final}/`.

### Pre-flight (recorded at run start, before any change — the pubspec edit came after these runs)

- `git -C <wt> rev-parse HEAD` → `7b32f44b644c587d6756be7028e27e25217bb0e5` (run_start_sha)
- `git -C <wt> status --short` → ` M .moai/specs/SPEC-ASSIST-001/progress.md` (orchestrator's §F)
- root `dart test` → `00:00 +2: All tests passed!`
- app `flutter --suppress-analytics test` → `00:10 +109: All tests passed!`; `flutter analyze` → `1 issue found` (info `test/support/fakes.dart:54:5 • use_null_aware_elements`)
- kolbi_ui `flutter test` → `00:01 +68: All tests passed!`; analyze → `No issues found!`
- kolbi_core `dart test` → `00:00 +27: All tests passed!`; `dart analyze` → `No issues found!`
- server `npm --prefix server test` → `Test Files  14 passed (14)` / `Tests  387 passed (387)`; `npm run typecheck` → exit 0
- `flutter --version` → `Flutter 3.50.1 • channel stable` / `Tools • Dart 3.14.0 • DevTools 2.61.0`; `xcodebuild -version` → `Xcode 27.2` / `Build version 27B52`; `pod --version` → `1.17.0`
- acceptance grep `grep -rn "home-intake\|귀찮은 전화\|byTooltip('보내기')\|직접 입력하기" app/test` → 16 hits: `approval_flow_test.dart:39`; `font_overflow_test.dart:73`; `design_contrast_test.dart:108` (a map key label only); `today_test.dart:41,63,67,74`; `accessibility_test.dart:343,566,618`; `intake_flow_test.dart:19,20,73,107,151,196`. Against the AC-016 table: all hits are table rows except `font_overflow_test.dart:73` (not in the table; see "AC-016 table vs current tree" below) and `design_contrast_test.dart:108` (label text, no assertion).

### Plan refresh vs 7b32f44 (plan written at c2e732d, before SPEC-SHELL-001 landed)

| plan.md §B / acceptance cite | Current tree (7b32f44) | Action |
|---|---|---|
| `home_screen.dart:153` `_IntakeBox`, `:188` key, `:48-74` `_send` | `_IntakeBox` `:192`, key `:225`, `_send` `:62-76`, `requestPlanDraft` `:21-32` | same intent at new lines |
| `app_router.dart` (plan says `app/lib/shell/app_router.dart`) | `app/lib/shell/app_router.dart`; `/assistant` builds `AssistantPlaceholderScreen` | as planned |
| `app/lib/shell/assistant_placeholder.dart` delete | exists (keys `assistant-intake-field`, `assistant-intake-send`, `assistant-close`) | delete; keep the three keys on the new screen so unlisted SHELL tests (`shell_test.dart:108`) stay unmodified |
| plan A.1 "submitFromAssistant obsolete" (debt N10) | `shell/navigation.dart:44` `submitFromAssistant` (close then push `/plan`) | replace with child-route helpers in `navigation.dart` + names in `routes.dart` |
| `approval_listener.dart:30` | `:30` `router.state.uri.path == taskLocation(router, task.id)` | unchanged line |
| `call_detail_screen.dart:186` `TranscriptView`, `:172` pinned card, `:421` `_CallTimer` | `:182`, `:166-172` (`_ActionBar`), `:417-442` | same intent |
| AC-016 `accessibility_test.dart:341-343`, `:563`, home order block | `:342-345` (empty-state block), `:566`, `:617-621` | same blocks |
| AC-016 `approval_flow_test.dart:36-37` | `:39-40` (SHELL added 3 view-size lines) | same block |
| AC-016 `intake_flow_test.dart` lines | unchanged (SHELL did not touch the file) | as listed |
| features may not import each other (SHELL AC-018, allowlist empty; ASSIST AC-013 keeps it empty) | `features/assistant` cannot import `features/calls` (intake, templates) | bridge through the shell, like SHELL's `task_feed.dart`: new `app/lib/shell/request_intake.dart` (not in plan §B) |
| plan card's profile link `plan_card_screen.dart:270` pushes `/settings` | on `/assistant/plan` that pushes a tab route over `/assistant` (R1-G assert) | route it through a `navigation.dart` helper that picks `/assistant/settings` under the assistant (file not in plan §B) |

### M1 — package check (pub.dev API + pub cache, 2026-11-28)

- `speech_to_text` **7.5.0** (latest; `environment: sdk ^3.12.0, flutter >=3.44.0`), BSD 3-Clause (`LICENSE` "BSD 3-Clause License, Copyright (c) 2019, Corner Software Development Corp."). `SpeechListenOptions(onDevice, partialResults, localeId, listenMode)`; `onDevice` defaults to false; `stop`/`cancel`; iOS SwiftPM `Package.swift` `.iOS("12.0")` (app deployment target 15.0).
- `permission_handler` **13.0.2** (latest; `sdk ^3.6.0, flutter >=3.24.0`), MIT ("Copyright (c) 2018 Baseflow"); `Permission.microphone`, `Permission.speech`, `openAppSettings()`; resolved platform packages `permission_handler_apple 9.6.5`, `permission_handler_android 14.1.1`.
- `cd app && flutter pub add speech_to_text:^7.5.0 permission_handler:^13.0.2` → `Changed 10 dependencies`. `git diff pubspec.lock` → 80 added lines, `0` removed lines; the 10 new entries: `json_annotation 4.12.0` (transitive), `permission_handler`, `permission_handler_android`, `permission_handler_apple`, `permission_handler_html 0.1.4+1`, `permission_handler_platform_interface 4.4.1`, `permission_handler_windows 0.2.4`, `speech_to_text 7.5.0`, `speech_to_text_platform_interface 2.5.0`, `speech_to_text_windows 1.0.1`. No existing entry changed.
- iOS Podfile: **not needed**. The iOS project uses SwiftPM (`grep -c FlutterGeneratedPluginSwiftPackage Runner.xcodeproj/project.pbxproj` → 10, no Pods), both plugins ship `Package.swift`, and the permission_handler README (SwiftPM section) says permissions are enabled from the `Info.plist` keys with no further configuration for a single-flavor app. The Podfile macro route applies to CocoaPods only. No Podfile created.
- Korean locale id: the adapter takes whichever id from `locales()` matches `^ko([-_]|$)` (iOS reports `ko-KR`, Android `ko_KR`/`ko-KR` depending on the recognizer); tests use `ko-KR`. Real-device confirmation pending (owner device check).
- On-device failure codes from the plugin source: iOS `listen` fails with `FlutterError(code: onDeviceError, "on device recognition is not supported on this device")` → `ListenFailedException` → `SpeechOnDeviceUnavailable`; Android 12+ on-device without a language pack → `error_language_unavailable` / `error_language_not_supported` → `SpeechOnDeviceUnavailable`. Finding for the owner (OD-2 / legal): on Android, when `isOnDeviceRecognitionAvailable` is false (SDK < 31 or no on-device service) the plugin silently creates the default recognizer instead of failing (`SpeechToTextPlugin.kt:623-636`), so the OD-2 notice cannot appear there; to be checked on a real device.
- Permissions: `speech_to_text.initialize` itself raises the OS dialog, so the adapter calls it only after `requestPermission` grants both permissions.
- Accessibility announcement API in Flutter 3.50.1: send with `SemanticsService.sendAnnouncement(View.of(context), message, textDirection, assertiveness: Assertiveness.polite)` (`announce` is deprecated since 3.35); record with `tester.takeAnnouncements()` → `CapturedAccessibilityAnnouncement` (`flutter_test/lib/src/binding.dart:1662`).
- Declarations: `Info.plist` `NSMicrophoneUsageDescription` "말로 부탁하면 제가 글로 받아 적어요. 콜비는 음성을 저장하지 않아요.", `NSSpeechRecognitionUsageDescription` "말한 내용을 기기의 음성 인식으로 글로 바꿔 부탁으로 보내요. 콜비는 음성을 저장하지 않아요." (`plutil -lint` → OK); `AndroidManifest.xml` `RECORD_AUDIO` + `<queries><intent><action android:name="android.speech.RecognitionService"/></intent>`; no Bluetooth permission.

### Run status — stopped before the M4 commit (owner decision needed)

- Committed on feat/SPEC-ASSIST-001: M1 `7623909`, M2 `b39c48d`, M3 `afa4fa8`, M5 `013df8c` (M5 was taken before M4 because it does not depend on it and M4 is blocked). Each commit ran the pre-commit hook normally; `flutter.version.json` present after each.
- M4 is implemented in the working tree, **uncommitted** (patch copy: `.moai/state/verify/SPEC-ASSIST-001/m4_pending.patch`): today without the request box and first-use empty state, briefing empty wording, recent places and shortcuts open the assistant, the AC-016 table edits (`intake_flow_test` helper + `:138`/`:151` lines; `approval_flow_test` empty-state lines; `accessibility_test` empty-state block, `byTooltip('보내기')`, home order block; `today_test` AC-015 block) and the new AC-010 test.
- With all of it applied: `flutter test` → `00:11 +129 -1: Some tests failed.` — the only failure is **`font_overflow_test.dart:73-75` "home fits a 360x640 phone at 2x text with the real font"** (`Bad state: No element` in `scrollUntilVisible(find.text('직접 입력하기'))`). It is not in the AC-016 table. Cause: REQ-010 removes [직접 입력하기] from today, and the test uses that label as its probe for the Pretendard font on home. The app cannot keep the label on today without breaking REQ-010 / AC-010.
- `today_test` "today shortcuts" and `inbox_test` "empty and error states" (AC-016 rows) needed no edit: the assistant keeps the SHELL keys `assistant-intake-field` / `assistant-intake-send` around the new input and send button. `shell_test` AC-006 (2) was edited in M2 per the table.

## §E.3 Run-phase Audit-Ready Signal

_<pending run-phase>_

## §E.4 Sync-phase Audit-Ready Signal

_<pending sync-phase>_

## §F Phase 4 Mode Selection

- kickoff: Implementation Kickoff Approval given by owner (2026-11-27: "기본값으로 시작" choices — OD-2 ~ OD-5 plan defaults; route: branch + PR; progression: autonomous run, then owner reviews screenshots before sync/audit/merge). Started after the owner installed Xcode 27.2 (macOS 27.2.1); iOS 27.2 simulator runtime is being installed by the owner in parallel
- precondition: SPEC-SHELL-001 and SPEC-DESIGN-001 `completed` (SHELL merged to main via PR #1, 7b32f44)
- route: branch feat/SPEC-ASSIST-001 in worktree /Users/jason/Documents/Jason-Danmuzi/wt-assist-001 (from origin/main 7b32f44); PR after run; owner merges
- carried from SHELL-001 sync-audit F1: /assistant opened as the first route (web deep link) — close pop() and submitFromAssistant push over /assistant (research R1-G)
- inputs: tier M (about 33 files, owner accepted the M deviation), domains: speech port + platform adapter, assistant state + screens, Orb animation, entry points, in-call screen, tests; language mix Dart + iOS/Android config; concurrency benefit LOW
- evaluation: direct — not selected; fanout — not selected (coding-heavy); sweep — not selected; serial — selected
- Decision: serial
- justification: the speech port (M1) and assistant state (M2) gate every screen milestone, and M4/M5 edit the shell router and call screens that M2 also touches; one writer in order avoids races
- Resolution (owner decision 2026-11-28, via orchestrator AskUserQuestion): AC-016 table extended by one row — `font_overflow_test.dart:73` probe changed from '직접 입력하기' to '전화 대신하기' (a Today shortcut that stays under REQ-010); intent unchanged (Home, 360×640, 2× text, real Pretendard). Cause: REQ-010. Applied by the orchestrator after the run agent hit the usage limit. Result on the working tree: `cd app && flutter --suppress-analytics test` → `00:11 +130: All tests passed!`; `flutter analyze` → `1 issue found.` (baseline info). Evidence `.moai/state/verify/SPEC-ASSIST-001/m4_app_test.txt`.
- Pending owner decision applied next (2026-11-28): Android OD-2 deviation — speech_to_text 7.5.0 silently falls back to the network recognizer on Android (SpeechToTextPlugin.kt:620-640), so show a one-time notice with the first-use pre-permission sheet on Android: "Android에서는 구글 음성 인식 서비스가 말을 글로 바꿀 수 있어요. 콜비는 음성을 저장하지 않아요." (not blocking; iOS keeps the planned event-driven notice).

### Android speech-service notice (OD-2 deviation, owner decision 2026-11-28) — applied by the orchestrator

- Cause: speech_to_text 7.5.0 on Android silently uses the default (network) recognizer when on-device recognition is unavailable (`SpeechToTextPlugin.kt` 620-640 in pub-cache, read by the orchestrator), so the planned "notice before falling back" cannot fire on Android.
- Change: on Android only, the sentence "Android에서는 구글 음성 인식 서비스가 말을 글로 바꿀 수 있어요. 콜비는 음성을 저장하지 않아요." is shown once before the first dictation — inside the purpose sheet when permission is not asked yet, or as its own card ([글로 입력] / [계속]) when permission is already granted. The flag `androidSpeechServiceNoticeAcknowledged` is stored in SharedPreferences (device only). iOS keeps the planned event-driven OD-2 notice. Dictation is not blocked.
- Files: `assistant_controller.dart` (phase `speechServiceNotice`, `acceptSpeechServiceNotice`, injected need/acknowledge callbacks), `assistant_screen.dart`, `mic_consent_sheet.dart` (`SpeechServiceNotice`, `MicConsentSheet.withSpeechService`), `test/assistant_test.dart` (base `profile` now marks the notice seen because flutter_test runs as Android; two new tests).
- RED (feature disabled with `false &&`, then restored): `Expected: exactly one matching candidate / Actual: _TextWidgetFinder:<Found 0 widgets with text "Android에서는 구글 음성 인식 서비스가 …` — `.moai/state/verify/SPEC-ASSIST-001/red/android_notice_red.txt`. Note: the test was written after the code (test-after), then checked against the disabled feature.
- GREEN: `cd app && flutter test` → `00:11 +132: All tests passed!`; analyze → baseline info only; root `dart test` +2; kolbi_ui +72; `git diff --stat 7b32f44 -- server/` empty.
