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

## §E.3 Run-phase Audit-Ready Signal

_<pending run-phase>_

## §E.4 Sync-phase Audit-Ready Signal

_<pending sync-phase>_
