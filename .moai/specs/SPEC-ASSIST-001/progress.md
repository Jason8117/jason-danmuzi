# SPEC-ASSIST-001 진행 기록

## §E.1 Plan-phase Audit-Ready Signal

- owner_verdict: PASS-with-debt (소유자 결정 2026-11-26, 3차 감사 0.83, N8·N9 수정). Tier 편차 승인: 파일 33개(그중 14개는 테스트 한 블록 수정이나 선언)이지만 Tier M 유지
- plan_status: audit-ready (당시 계획 감사 전)
- plan_status_final: 계획 감사 3/3차 PASS-with-debt 0.83 (보고서 .moai/reports/plan-audit/SPEC-ASSIST-001-review-3.md). 막는 결함 N8·N9는 보고서 뒤 수정. Tier 편차(33개 파일, Tier M 유지) 또는 SCR-T08 분리는 소유자 승인 대기였음
- audit_debt (run 중 처리): N10 SHELL `navigation.dart`(submitFromAssistant는 쓰지 않게 됨)와 비서 자식 경로 이름을 plan §B에 추가, N12 SHELL AC-005 행이 아직 없는 SHELL 테스트를 전제, N14 REQ-006과 plan A.1의 실패 규칙 및 REQ-006의 대체 기억. N11·N13·N15·N16·N17은 문서에서 수정함
- spec_version: 0.3.0 (계획 감사 2차 FAIL 0.77, 보고서 .moai/reports/plan-audit/SPEC-ASSIST-001-review-2.md. D2·N1~N7 반영, should-fix D8~D12 반영)
- spec_version_0.2.0: (계획 감사 1차 FAIL 0.71, 보고서 .moai/reports/plan-audit/SPEC-ASSIST-001-review-1.md. must-fix D1~D7·D9~D11 반영, should-fix D8·D12·D13·D15 반영, D14·D16 일부 반영)
- spec_version_history: 0.1.0
- plan_complete_at: 2026-11-26
- base_sha: c2e732d (커밋 전 계획 문서 포함. run_start_sha는 SPEC-SHELL-001 완료 뒤 run에서 기록)
- tier: M (약 30개 파일로 M 범위를 넘음, 소유자 판단), harness: standard (권장), methodology: tdd
- artifacts: spec.md, plan.md, acceptance.md, progress.md
- counts: 16 REQ / 16 AC
- depends_on: SPEC-SHELL-001, SPEC-DESIGN-001
- open_decisions: OD-1 결정(기기 음성 인식, 서버로는 글만). OD-2~OD-5 기본값(소유자 검토 대기)
- intended test changes: acceptance.md AC-016 표 참조(fakes.dart는 더하기만, intake_flow_test 도우미와 이름 적은 블록, approval_flow_test :36-37, accessibility_test :341-343·:563·홈 순서 블록, shell_test SHELL-001 0.3.0 AC-006 (2), today_test AC-015/AC-016, inbox_test AC-012 (1), intake_flow_test :138)
- verified at plan time: app/pubspec.yaml에 음성 패키지 없음, iOS Info.plist에 마이크·음성 인식 사용 문구 없음, AndroidManifest는 INTERNET만, 부탁 입력은 home_screen.dart `_IntakeBox`(:153, :188), 통화 상세에 TranscriptView(:186)와 고정 ApprovalCard(:172)
- note: 앱과 kolbi_ui만 바뀜. 서버 변경 없음

## §E.2 Run-phase Evidence

증거 파일(gitignore, 감사용으로 보관): `.moai/state/verify/SPEC-ASSIST-001/{pre,red,final}/`.

### 사전 점검 (run 시작 시점, 어떤 변경보다 먼저 기록. pubspec 수정은 이 실행 뒤)

- `git -C <wt> rev-parse HEAD` → `7b32f44b644c587d6756be7028e27e25217bb0e5` (run_start_sha)
- `git -C <wt> status --short` → ` M .moai/specs/SPEC-ASSIST-001/progress.md` (오케스트레이터가 쓴 §F)
- 루트 `dart test` → `00:00 +2: All tests passed!`
- 앱 `flutter --suppress-analytics test` → `00:10 +109: All tests passed!`, `flutter analyze` → `1 issue found` (info `test/support/fakes.dart:54:5 • use_null_aware_elements`)
- kolbi_ui `flutter test` → `00:01 +68: All tests passed!`, analyze → `No issues found!`
- kolbi_core `dart test` → `00:00 +27: All tests passed!`, `dart analyze` → `No issues found!`
- 서버 `npm --prefix server test` → `Test Files  14 passed (14)` / `Tests  387 passed (387)`, `npm run typecheck` → exit 0
- `flutter --version` → `Flutter 3.50.1 • channel stable` / `Tools • Dart 3.14.0 • DevTools 2.61.0`, `xcodebuild -version` → `Xcode 27.2` / `Build version 27B52`, `pod --version` → `1.17.0`
- 인수 기준 grep `grep -rn "home-intake\|귀찮은 전화\|byTooltip('보내기')\|직접 입력하기" app/test` → 16곳: `approval_flow_test.dart:39`, `font_overflow_test.dart:73`, `design_contrast_test.dart:108`(맵 키 이름일 뿐), `today_test.dart:41,63,67,74`, `accessibility_test.dart:343,566,618`, `intake_flow_test.dart:19,20,73,107,151,196`. AC-016 표와 대조하면 `font_overflow_test.dart:73`(표에 없음, 아래 "실행 상태" 참조)과 `design_contrast_test.dart:108`(단언 없는 이름)만 표 밖이다.

### 계획 갱신 — 7b32f44 기준 (계획은 SPEC-SHELL-001 반영 전 c2e732d에서 작성)

| plan.md §B / acceptance 인용 | 지금 트리(7b32f44) | 처리 |
|---|---|---|
| `home_screen.dart:153` `_IntakeBox`, `:188` 키, `:48-74` `_send` | `_IntakeBox` `:192`, 키 `:225`, `_send` `:62-76`, `requestPlanDraft` `:21-32` | 같은 의도, 줄만 다름 |
| `app_router.dart` (계획은 `app/lib/shell/app_router.dart`) | `app/lib/shell/app_router.dart`, `/assistant`가 `AssistantPlaceholderScreen`을 만듦 | 계획대로 |
| `app/lib/shell/assistant_placeholder.dart` 삭제 | 있음(키 `assistant-intake-field`, `assistant-intake-send`, `assistant-close`) | 삭제하되 세 키를 새 화면에 남겨 표에 없는 SHELL 테스트(`shell_test.dart:108`)를 고치지 않음 |
| plan A.1 "submitFromAssistant 쓰지 않음"(debt N10) | `shell/navigation.dart:44` `submitFromAssistant`(닫은 뒤 `/plan` push) | `navigation.dart`의 자식 경로 도우미와 `routes.dart`의 이름으로 바꿈 |
| `approval_listener.dart:30` | `:30` `router.state.uri.path == taskLocation(router, task.id)` | 같은 줄 |
| `call_detail_screen.dart:186` `TranscriptView`, `:172` 고정 카드, `:421` `_CallTimer` | `:182`, `:166-172`(`_ActionBar`), `:417-442` | 같은 의도 |
| AC-016 `accessibility_test.dart:341-343`, `:563`, 홈 순서 블록 | `:342-345`(빈 상태 블록), `:566`, `:617-621` | 같은 블록 |
| AC-016 `approval_flow_test.dart:36-37` | `:39-40`(SHELL이 화면 크기 줄 3개 추가) | 같은 블록 |
| AC-016 `intake_flow_test.dart` 줄 | 그대로(SHELL이 건드리지 않음) | 적힌 대로 |
| 기능 간 import 금지(SHELL AC-018 허용 목록 비어 있음, ASSIST AC-013도 비움) | `features/assistant`는 `features/calls`(접수, 템플릿)를 가져올 수 없음 | SHELL의 `task_feed.dart`처럼 셸을 거침: 새 파일 `app/lib/shell/request_intake.dart`(plan §B에 없음) |
| 계획 카드의 프로필 링크 `plan_card_screen.dart:270`가 `/settings`를 push | `/assistant/plan` 위에서 탭 경로를 `/assistant` 위에 쌓게 됨(R1-G assert) | 비서 아래에서는 `/assistant/settings`를 고르는 `navigation.dart` 도우미로 보냄(plan §B에 없는 파일) |

### M1 — 패키지 확인 (pub.dev API와 pub cache, 2026-11-28)

- `speech_to_text` **7.5.0** (최신, `environment: sdk ^3.12.0, flutter >=3.44.0`), BSD 3-Clause(`LICENSE` "BSD 3-Clause License, Copyright (c) 2019, Corner Software Development Corp."). `SpeechListenOptions(onDevice, partialResults, localeId, listenMode)`, `onDevice` 기본값 false, `stop`/`cancel`, iOS SwiftPM `Package.swift` `.iOS("12.0")`(앱 배포 대상 15.0).
- `permission_handler` **13.0.2** (최신, `sdk ^3.6.0, flutter >=3.24.0`), MIT("Copyright (c) 2018 Baseflow"). `Permission.microphone`, `Permission.speech`, `openAppSettings()`. 함께 풀린 플랫폼 패키지 `permission_handler_apple 9.6.5`, `permission_handler_android 14.1.1`.
- `cd app && flutter pub add speech_to_text:^7.5.0 permission_handler:^13.0.2` → `Changed 10 dependencies`. `git diff pubspec.lock` → 80줄 추가, 0줄 삭제. 새 항목 10개: `json_annotation 4.12.0`(전이 의존), `permission_handler`, `permission_handler_android`, `permission_handler_apple`, `permission_handler_html 0.1.4+1`, `permission_handler_platform_interface 4.4.1`, `permission_handler_windows 0.2.4`, `speech_to_text 7.5.0`, `speech_to_text_platform_interface 2.5.0`, `speech_to_text_windows 1.0.1`. 기존 항목은 바뀌지 않음.
- iOS Podfile: **필요 없음**. iOS 프로젝트가 SwiftPM을 쓰고(`grep -c FlutterGeneratedPluginSwiftPackage Runner.xcodeproj/project.pbxproj` → 10, Pods 없음) 두 플러그인 모두 `Package.swift`를 제공하며, permission_handler README(SwiftPM 절)에 따르면 단일 flavor 앱은 `Info.plist` 키만으로 권한이 켜진다. Podfile 매크로 방식은 CocoaPods 전용이라 Podfile을 만들지 않음.
- 한국어 로캘 ID: 어댑터는 `locales()` 가운데 `^ko([-_]|$)`에 맞는 ID를 고른다(iOS는 `ko-KR`, Android는 인식기에 따라 `ko_KR`/`ko-KR`). 테스트는 `ko-KR`. 실기기 확인 대기(소유자 기기 점검).
- 플러그인 소스에서 본 기기 안 인식 실패 코드: iOS `listen`은 `FlutterError(code: onDeviceError, "on device recognition is not supported on this device")` → `ListenFailedException` → `SpeechOnDeviceUnavailable`. Android 12 이상에서 언어 팩 없이 기기 안 인식 → `error_language_unavailable` / `error_language_not_supported` → `SpeechOnDeviceUnavailable`. 소유자 확인 사항(OD-2·법무): Android에서 `isOnDeviceRecognitionAvailable`이 false(SDK 31 미만이거나 기기 안 서비스 없음)이면 플러그인이 실패하지 않고 기본 인식기를 조용히 만든다(`SpeechToTextPlugin.kt:623-636`). 그래서 그 경우 OD-2 안내가 뜰 수 없다. 실기기 확인 필요.
- 권한: `speech_to_text.initialize` 자체가 OS 권한 창을 띄우므로, 어댑터는 `requestPermission`이 두 권한을 모두 받은 뒤에만 부른다.
- Flutter 3.50.1의 접근성 알림 API: 보낼 때 `SemanticsService.sendAnnouncement(View.of(context), message, textDirection, assertiveness: Assertiveness.polite)`(`announce`는 3.35부터 사용 중단), 테스트에서 받을 때 `tester.takeAnnouncements()` → `CapturedAccessibilityAnnouncement`(`flutter_test/lib/src/binding.dart:1662`).
- 선언: `Info.plist` `NSMicrophoneUsageDescription` "말로 부탁하면 제가 글로 받아 적어요. 콜비는 음성을 저장하지 않아요.", `NSSpeechRecognitionUsageDescription` "말한 내용을 기기의 음성 인식으로 글로 바꿔 부탁으로 보내요. 콜비는 음성을 저장하지 않아요."(`plutil -lint` → OK). `AndroidManifest.xml` `RECORD_AUDIO`와 `<queries><intent><action android:name="android.speech.RecognitionService"/></intent>`. 블루투스 권한 없음.

### 실행 상태 — M4 커밋 전에 멈춤 (소유자 결정 필요했던 시점)

- feat/SPEC-ASSIST-001에 커밋: M1 `7623909`, M2 `b39c48d`, M3 `afa4fa8`, M5 `013df8c`(M5는 M4에 기대지 않고 M4가 막혀 있어 먼저 진행). 커밋마다 pre-commit 훅이 정상 실행됐고, 매번 `flutter.version.json`이 남아 있었다.
- M4는 작업 트리에 구현만 되고 **커밋 전**이었다(패치 사본 `.moai/state/verify/SPEC-ASSIST-001/m4_pending.patch`): 오늘 화면에서 부탁 입력 상자와 첫 사용 빈 상태 제거, 브리핑 빈 문구, 최근 통화한 곳과 바로가기가 비서를 엶, AC-016 표의 테스트 수정(`intake_flow_test` 도우미와 `:138`/`:151` 줄, `approval_flow_test` 빈 상태 줄, `accessibility_test` 빈 상태 블록·`byTooltip('보내기')`·홈 순서 블록, `today_test` AC-015 블록), 새 AC-010 테스트.
- 모두 적용하면 `flutter test` → `00:11 +129 -1: Some tests failed.` 실패는 **`font_overflow_test.dart:73-75` "home fits a 360x640 phone at 2x text with the real font"** 하나(`scrollUntilVisible(find.text('직접 입력하기'))`에서 `Bad state: No element`). AC-016 표에 없는 블록이다. 원인: REQ-010이 오늘 화면에서 [직접 입력하기]를 빼는데, 이 테스트가 그 글자를 홈의 Pretendard 글꼴 확인 표식으로 쓴다. REQ-010·AC-010을 어기지 않고는 그 글자를 오늘에 남길 수 없다.
- `today_test` "today shortcuts"와 `inbox_test` "empty and error states"(AC-016 행)는 고칠 필요가 없었다. 비서 화면이 새 입력칸과 보내기 버튼에 SHELL 키 `assistant-intake-field` / `assistant-intake-send`를 그대로 쓰기 때문이다. `shell_test` AC-006 (2)는 표대로 M2에서 고쳤다.
- 해결(소유자 결정 2026-11-28, 오케스트레이터 AskUserQuestion): AC-016 표에 한 행을 더함 — `font_overflow_test.dart:73`의 표식을 '직접 입력하기'에서 '전화 대신하기'(REQ-010 뒤에도 오늘에 남는 바로가기)로 바꿈. 검사 의도(홈, 360×640, 2배 글자, 실제 Pretendard)는 그대로. 원인 REQ-010. run 에이전트가 사용량 한도에 걸린 뒤 오케스트레이터가 적용. 결과: `cd app && flutter --suppress-analytics test` → `00:11 +130: All tests passed!`, `flutter analyze` → `1 issue found.`(기존 info). 증거 `.moai/state/verify/SPEC-ASSIST-001/m4_app_test.txt`. M4 커밋 `dd3e451`.

### Android 음성 인식 서비스 안내 (OD-2 편차, 소유자 결정 2026-11-28) — 오케스트레이터가 적용

- 원인: speech_to_text 7.5.0은 Android에서 기기 안 인식을 쓸 수 없으면 알리지 않고 기본(네트워크) 인식기를 쓴다(pub-cache의 `SpeechToTextPlugin.kt` 620-640, 오케스트레이터가 직접 읽음). 그래서 계획한 "대체 인식으로 넘어가기 전 안내"가 Android에서는 뜰 수 없다.
- 변경: Android에서만 첫 받아쓰기 전에 "Android에서는 구글 음성 인식 서비스가 말을 글로 바꿀 수 있어요. 콜비는 음성을 저장하지 않아요."를 한 번 보인다. 아직 권한을 묻지 않았으면 목적 안내 안에 함께, 이미 권한이 있으면 따로 카드([글로 입력] / [계속])로 보인다. 본 여부는 `androidSpeechServiceNoticeAcknowledged`로 SharedPreferences(기기 안)에 저장한다. iOS는 계획대로 이벤트가 올 때 OD-2 안내를 보인다. 받아쓰기를 막지는 않는다.
- 파일: `assistant_controller.dart`(단계 `speechServiceNotice`, `acceptSpeechServiceNotice`, 필요 여부·확인 콜백 주입), `assistant_screen.dart`, `mic_consent_sheet.dart`(`SpeechServiceNotice`, `MicConsentSheet.withSpeechService`), `test/assistant_test.dart`(flutter_test가 Android로 돌아가므로 기본 `profile`은 안내를 본 상태로 두고, 새 테스트 2개 추가).
- RED(기능을 `false &&`로 끈 뒤 되돌림): `Expected: exactly one matching candidate / Actual: _TextWidgetFinder:<Found 0 widgets with text "Android에서는 구글 음성 인식 서비스가 …` — `.moai/state/verify/SPEC-ASSIST-001/red/android_notice_red.txt`. 테스트는 코드 뒤에 썼고(test-after), 기능을 끈 상태에서 실패하는지 확인했다.
- GREEN: `cd app && flutter test` → `00:11 +132: All tests passed!`, analyze → 기존 info만, 루트 `dart test` +2, kolbi_ui +72, `git diff --stat 7b32f44 -- server/` 비어 있음. 커밋 `f5ab61b`.

### M6과 최종 확인 (오케스트레이터, 2026-11-28, HEAD f5ab61b)

run 에이전트는 M5 뒤 주간 사용량 한도에 걸려 멈췄다. 오케스트레이터가 M4 커밋(dd3e451), Android 안내(f5ab61b), M6 확인을 마쳤다. M6은 코드 변경이 필요 없었다(구조 규칙 테스트는 M1·M2에서 들어감).

최종 측정(이 트리):
```
cd app && flutter --suppress-analytics test        -> 00:11 +132: All tests passed!   (.moai/state/verify/SPEC-ASSIST-001/notice_app_test.txt)
cd app && flutter --suppress-analytics analyze     -> 1 issue found. (기존 info test/support/fakes.dart:54:5)
dart test (저장소 루트)                              -> 00:00 +2: All tests passed!
cd packages/kolbi_ui && flutter test               -> 00:01 +72: All tests passed!
cd packages/kolbi_core && dart test                -> +27 All tests passed!
npm --prefix server test                           -> Tests 387 passed (387)
cd app && flutter build ios --simulator --debug    -> ✓ Built build/ios/iphonesimulator/Runner.app (ios_build.txt)
git diff --stat 7b32f44 -- server/                 -> (비어 있음)
grep -rln "speech_to_text\|permission_handler" app/lib packages/*/lib -> app/lib/features/assistant/speech/platform_speech_recognizer.dart 하나뿐
app/test/architecture_test.dart:8                  -> const allowedCrossFeature = <String>{};
git diff 7b32f44 -- app/test/support/fakes.dart | grep "^-" (머리줄 제외) -> (지운 줄 없음)
```

AC-015 diff(`git diff --stat 7b32f44 -- <적힌 파일 10개>`): `app/test/font_overflow_test.dart | 3 ++-`뿐 — 소유자가 승인한 표식 변경(AC-016 표 확장, 2026-11-28). 나머지 9개 파일은 그대로.

AC-016 diff(`git diff --stat 7b32f44 -- app/test/`): accessibility_test 10, approval_flow_test 5, architecture_test +36, assistant_test(새 파일) 928, font_overflow_test 3, intake_flow_test 8, live_call_test(새 파일) 308, shell_test 8, support/fake_speech_recognizer(새 파일) 113, support/fakes +30, today_test 11 — 파일 11개, 1442줄 추가 / 18줄 삭제.

시뮬레이터 실행: iPhone 18 Pro(iOS 27.2) 시뮬레이터에 설치해 실행했고, 오늘 화면에 부탁 입력 상자 없이 빈 브리핑("오늘은 맡긴 일이 없어요." / "가운데 버튼으로 부탁해 보세요.")이 나오는 것을 확인했다. Simulator 창 앱이 없어 탭 조작은 하지 못했다.

AC 표(모두 위 +132 실행에 포함):

| AC | 결과 | 테스트 |
|---|---|---|
| AC-001 | PASS | assistant_test "assistant screen follows the immersive layout" |
| AC-002 | PASS | assistant_test "orb state is shown in words and announced", kolbi_ui orb_test |
| AC-003 | PASS | "dictation fills the request and opens the plan card", "an older server keeps the blank-plan fallback" |
| AC-004 | PASS | "only the final text reaches Kolbi" |
| AC-005 | PASS | "microphone permission is asked with a purpose first"(+ Android 안내 테스트) |
| AC-006 | PASS | "recognition failures never loop or send an empty request" |
| AC-007 | PASS | "stopping or leaving cancels dictation; inactive does not" |
| AC-008 | PASS | "text mode carries the whole request box" |
| AC-009 | PASS | "missing profile and intake errors keep the request" |
| AC-010 | PASS | "today hands requests to the assistant" |
| AC-011 | PASS | live_call_test "live call screen shows captions, hang-up and approvals", "finishing the call returns to the task screen", "approval alerts from the live and assistant screens" |
| AC-012 | PASS | live_call_test "task screen links to the live call" |
| AC-013 | PASS | architecture_test "speech and permission packages stay inside the assistant feature", 위 grep |
| AC-014 | PASS | assistant_test·live_call_test "immersive screens meet the accessibility guidelines" |
| AC-015 | PASS(소유자가 승인한 font_overflow 표식 변경 포함) | 위 diff |
| AC-016 | PASS | 서버 diff 비어 있음, 테스트 diff가 AC-016 표와 2026-11-28 확장 행에 맞음 |

## §E.3 Run-phase Audit-Ready Signal

```yaml
run_complete_at: 2026-11-28
run_start_sha: 7b32f44
run_commit_sha: f5ab61b   # 마지막 구현 커밋. 이 절을 담은 커밋은 증거 기록용
milestone_commits: [7623909 (M1), b39c48d (M2), afa4fa8 (M3), 013df8c (M5), dd3e451 (M4), f5ab61b (Android 안내)]
run_status: complete
ac_pass_count: 16
ac_fail_count: 0
app_tests: "+132 통과 (기준 +109)"
app_analyze: "info 1건 (기존 fakes.dart:54)"
kolbi_ui_tests: "+72"
kolbi_core_tests: "+27"
root_workspace_test: "+2"
server_tests: "387 통과 (서버 변경 없음)"
ios_simulator_build: "✓ Built Runner.app (Xcode 27.2, iOS 27.2 SDK)"
ios_simulator_run: "iPhone 18 Pro에서 실행, 오늘 화면 확인 (탭 조작 불가)"
new_dependencies: "speech_to_text 7.5.0, permission_handler 13.0.2 (+ 플랫폼 패키지, json_annotation 4.12.0)"
owner_decisions: ["font_overflow_test 표식 → '전화 대신하기' (2026-11-28)", "Android 음성 인식 서비스 안내를 미리 보임 (OD-2 편차, 2026-11-28)"]
red_evidence: "M1~M3·M5는 run 에이전트 기록(.moai/state/verify/SPEC-ASSIST-001/red/), M4 표식 실패 기록, Android 안내는 test-after로 기능을 끈 상태에서 실패 확인(red/android_notice_red.txt)"
device_check: pending   # 실제 권한 창, 기기 안 인식 오류 코드, 한국어 로캘 ID, 실제 받아쓰기
run_agent_note: "run 에이전트는 M5 뒤 주간 사용량 한도로 멈춤. 오케스트레이터가 M4 커밋, Android 안내, M6 확인과 이 기록을 마침"
untracked_note: "iOS 빌드가 만든 SwiftPM 상태 파일(app/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/, app/ios/Runner.xcworkspace/xcshareddata/swiftpm/)은 커밋하지 않음. sync에서 처리 결정"
```

## §E.4 Sync-phase Audit-Ready Signal

```yaml
sync_complete_at: 2026-11-28
sync_commit_sha: pending-backfill   # 이 sync 커밋은 자기 SHA를 적을 수 없음. `git log -1 --format=%h -- .moai/specs/SPEC-ASSIST-001/progress.md`로 읽음
sync_status: implemented   # sync 감사 통과 뒤 오케스트레이터가 completed로 올림(소유자 규칙 2026-11-27)
run_start_sha: 7b32f44   # 7b32f44b644c587d6756be7028e27e25217bb0e5
run_commit_sha: f5ab61b   # 마지막 구현 커밋(M1 7623909, M2 b39c48d, M3 afa4fa8, M5 013df8c, M4 dd3e451, Android 안내 f5ab61b)
run_evidence_commit_sha: 477dac5   # run 증거 커밋(6025987 뒤 한국어로 다시 쓴 기록). 이 sync 커밋 직전 HEAD
route: B   # 작업 폴더 /Users/jason/Documents/Jason-Danmuzi/wt-assist-001의 feat/SPEC-ASSIST-001, PR은 아직(병합은 소유자)
pushed_state: not-pushed
measured_by: "오케스트레이터가 f5ab61b 트리에서 측정(§E.2 M6과 최종 확인, 2026-11-28). manager-docs는 다시 돌리지 않음. sync는 문서만 바꿈"
app_tests_at_sync: "cd app && flutter --suppress-analytics test -> 00:11 +132: All tests passed!"
app_analyze_at_sync: "flutter analyze -> 1 issue found. (기존 info test/support/fakes.dart:54:5)"
root_workspace_test_at_sync: "dart test -> 00:00 +2: All tests passed!"
kolbi_ui_tests_at_sync: "flutter test -> 00:01 +72: All tests passed!"
kolbi_core_tests_at_sync: "dart test -> +27 All tests passed!"
server_tests_at_sync: "npm --prefix server test -> Tests 387 passed (387)"
protected_paths_diff_at_sync: "git diff --stat 7b32f44 -- server/ -> 비어 있음; app/test/ = 파일 11개, 1442줄 추가 / 18줄 삭제"
speech_package_grep_at_sync: 'grep -rln "speech_to_text\|permission_handler" app/lib packages/*/lib -> app/lib/features/assistant/speech/platform_speech_recognizer.dart 하나뿐'
cross_feature_allowlist_at_sync: "app/test/architecture_test.dart:8 -> const allowedCrossFeature = <String>{};"
acceptance_distinct_ac_ids: 16   # grep -oE 'AC-([A-Z0-9]+-)*[0-9]+' .moai/specs/SPEC-ASSIST-001/acceptance.md | sort -u | wc -l -> 16 (AC-001..AC-016). 접미 ID 없음. 0.3.1 주석 뒤에도 REQ/AC 16/16 그대로
frontmatter_status_transitions:
  spec.md: in-progress -> implemented   # updated 2026-11-26 -> 2026-11-28, version 0.3.0 -> 0.3.1 (아래 manager-spec 주석)
spec_body_annotation:   # manager-spec 역할로, 소유자 결정 2026-11-28 두 건만 기록. 그 밖의 본문 수정 없음
  spec.md: "HISTORY 0.3.1 행; §5 OD-2 행에 Android 편차(SpeechToTextPlugin.kt 620-640, 미리 보이는 안내 문구, SharedPreferences androidSpeechServiceNoticeAcknowledged, iOS는 계획대로)"
  acceptance.md: "AC-016 표 + 1행(font_overflow_test.dart:73 표식 '직접 입력하기' -> '전화 대신하기', 원인 REQ-010, 검사 의도 그대로, 소유자 결정 2026-11-28)과 표 확장 문단; AC-015 Then에 font_overflow_test 예외 한 문장; AC-006 아래 OD-2 Android 편차와 테스트 이름 2개; 완료 정의의 테스트 변경 줄"
changelog_entry_position: not-applicable   # 저장소에 CHANGELOG.md 없음
mx_scan: skipped
coverage: not-measured
divergence:
  planned_vs_changed_files: "plan.md §B 33개(묶음 행 6개 포함); git diff --name-only 7b32f44..f5ab61b -> 39개 = 계획 31 + 계획 밖 8. 계획했으나 바뀌지 않음: app/ios/Podfile(SwiftPM이라 필요 없음, §E.2 M1), app/test/inbox_test.dart(SHELL 키를 새 화면이 그대로 써서 고칠 필요 없음, §E.2 실행 상태)"
  unplanned_files:
    - "app/lib/shell/request_intake.dart: 비서가 features/calls의 접수·템플릿·최근 통화한 곳을 직접 가져오지 않게 셸이 넘김(SHELL task_feed.dart와 같은 방식, 기능 간 허용 목록 비어 있음 유지; §E.2 계획 갱신 표)"
    - "app/lib/shell/navigation.dart: 비서 자식 경로 도우미와 /assistant/settings를 고르는 openSettings, submitFromAssistant 삭제, closeAssistant·openLiveCall·closeLiveCall·liveCallLocation (plan-audit debt N10; §E.2 계획 갱신 표)"
    - "app/lib/features/calls/presentation/plan_card_screen.dart: 프로필 링크(:270)가 /settings 대신 openSettings를 부름(비서 위에서 탭 경로를 쌓지 않게, R1-G)"
    - "app/test/font_overflow_test.dart: 표식 한 줄 변경(AC-016 표 확장, 소유자 결정 2026-11-28)"
    - "packages/kolbi_ui/lib/src/widgets/transcript_view.dart: 선택 인자 agentName(기본 'AI 비서'), 통화 중 화면이 '콜비'를 넘김(REQ-011)"
    - "pubspec.lock: 새 항목 10개, 기존 항목 무변경(§E.2 M1)"
    - ".moai/specs/SPEC-ASSIST-001/spec.md, progress.md: run 시작 상태 변경과 run 기록"
  owner_deviations:
    - "AC-016 표 확장: font_overflow_test.dart:73 표식 -> '전화 대신하기'(REQ-010, 2026-11-28). AC-015의 수정 없음 목록에 이 한 파일만 승인된 예외"
    - "OD-2 Android 편차: 첫 받아쓰기 전 'Android에서는 구글 음성 인식 서비스가 말을 글로 바꿀 수 있어요. 콜비는 음성을 저장하지 않아요.' 한 번, SharedPreferences androidSpeechServiceNoticeAcknowledged, iOS는 이벤트가 올 때 안내(2026-11-28). 코드 app/lib/features/assistant/{assistant_controller.dart, assistant_screen.dart, mic_consent_sheet.dart}, 테스트 app/test/assistant_test.dart 2개(test-after, 기능을 끈 RED 기록 있음)"
debt_carried:
  - "OD-3·OD-4·OD-5 계획 기본값 그대로(소유자 검토 대기). OD-2 iOS 쪽 문구도 기본값이며 법률 검토(03 NFR-LAW) 대상"
  - "실기기 확인(완료 정의 항목): 실제 권한 창, 기기 안 인식 오류 코드, 한국어 로캘 ID, 말로 부탁 -> 계획 카드 한 번"
  - "Android 안내는 test-after로 썼음(RED는 기능을 끈 상태의 실패로 대신 확인)"
  - "app/ios의 SwiftPM Package.resolved 두 개가 커밋되지 않음(아래 untracked_handling)"
debt_closed:
  - "SHELL-001 sync-audit F1: /assistant를 첫 화면으로 열 때 닫기는 오늘로(closeAssistant), 비서가 여는 화면은 자식 경로라 /assistant 위에 탭 경로를 push하지 않음"
  - "plan-audit debt N10(navigation.dart와 자식 경로 이름), N12(SHELL AC-005 행은 무변경으로 통과), N14(실패 규칙과 대체 기억은 AssistantMemory)"
simulator_check: done   # 오케스트레이터, iPhone 18 Pro(iOS 27.2) 시뮬레이터에 debug 빌드 설치·실행, 오늘 화면에 입력 상자 없이 빈 브리핑 확인. Simulator 창이 없어 탭 조작은 못 함
browser_check: done   # 오케스트레이터, web 빌드와 시뮬레이션 서버(.env 없음), 2026-11-28
browser_check_observations: "AI 비서 -> 계획 카드 -> 작업 -> 통화 중 화면까지 웹에서 걸어 봄. 콘솔 오류 없음. 웹에서는 어댑터가 받아쓰기를 쓰지 않으므로(kIsWeb -> MicPermission.unavailable, 글로 입력 모드) 마이크·음성 흐름은 이 확인에 들어가지 않음"
device_check: pending   # 소유자: 실기기(iOS 또는 Android 한 대)에서 권한 창, 받아쓰기 -> 계획 카드, Android 안내, 기기 안 인식 불가 시 동작
untracked_handling: "flutter build ios가 만든 app/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/, app/ios/Runner.xcworkspace/xcshareddata/swiftpm/(각각 Package.resolved 하나, CwlCatchException 2.2.1 고정)은 이 sync 커밋에 넣지 않음. .gitignore·app/.gitignore(.swiftpm/만)·app/ios/.gitignore 어느 것도 이 경로를 무시하지 않고, SHELL에는 앞선 예가 없어(SHELL 때는 SwiftPM 원격 의존이 없었음) .gitignore도 고치지 않음. 처리 방식은 소유자 결정"
pre_commit_hook_note: "이 sync 커밋은 pre-commit 훅(moai gate)을 정상 실행함"
plan_g_items:
  .moai/project/structure.md: "features/assistant 트리(포트·어댑터 포함), shell/request_intake.dart, assistant_placeholder 삭제, 경로 표에 /assistant 자식 셋과 /calls/:id/live, 이동 규칙(자식 경로, closeAssistant, closeLiveCall), architecture_test 행, 어디를 고쳐야 하는가 2행"
  docs/planning/06_DESIGN_DECISIONS.md: "§7 Q-3 닫음(기기 음성 인식, 패키지와 버전, OD-2·Android 편차, 남은 실기기·법률 검토)"
  docs/product/10_PRODUCT_PLAN.md: "가정 A-7 문서 확인 결과(로캘, onDevice, iOS 오류·Android 조용한 대체), 실기기 시험은 대기"
  README.md: "'말로 부탁하기' 단락(Orb·상태 글자, 글로 입력, 권한, 음성은 서버로 보내지 않음, Android 안내, 권한 문구 위치, 웹은 글로 입력), 화면 구성의 오늘·비서·통화 중 화면 문장, 폴더 트리에 assistant/"
  codemaps: "modules.md(features/assistant 표, shell request_intake·navigation·routes, calls의 live_call_screen·call_timer·[통화 보기], kolbi_ui KolbiOrb·KolbiTheme·TranscriptView agentName, 테스트); entry-points.md(승인 알림이 통화 중 화면에서도 조용함, 경로 표에 비서 자식 셋과 /calls/:id/live, /calls/new·/plan 진입 변경); dependencies.md(speech_to_text·permission_handler 사용 파일, shared_preferences의 안내 기록, mermaid에 assistant·request_intake·speech 노드)"
  extra_docs: "tech.md(앱 패키지 표 2행, 받아쓰기·권한·SwiftPM 제약), docs/product/11_ARCHITECTURE.md(§2.5 표·이동 규칙, SPEC-ASSIST-001 구현 문단, AD-10, 개정 이력), .moai/specs/EPIC-KOLBI-APP/overview.md(ASSIST-001 implemented 0.3.1)"
project_docs_synced: [README.md, .moai/project/structure.md, .moai/project/tech.md, .moai/project/codemaps/modules.md, .moai/project/codemaps/entry-points.md, .moai/project/codemaps/dependencies.md, docs/product/11_ARCHITECTURE.md, docs/planning/06_DESIGN_DECISIONS.md, docs/product/10_PRODUCT_PLAN.md, .moai/specs/EPIC-KOLBI-APP/overview.md]
sync_audit: pending
```

### sync 감사 1차 후속 수정 (2026-11-28)

소유자가 감사 보고서 `.moai/reports/sync-audit/SPEC-ASSIST-001-audit-1.md`의 발견 사항을 모두 고치기로 승인함(2026-11-28). 시작 HEAD `34ad269`(M1 서식은 이미 `9988c91`에서 처리됨). RED/GREEN 출력은 `.moai/state/verify/SPEC-ASSIST-001/audit1/`에 있음(`.gitignore`로 커밋되지 않음, I3와 같음).

| 발견 | 바꾼 것 | 테스트 | RED 증거 | 커밋 |
|---|---|---|---|---|
| M2 | `pub-cache/.../SpeechToTextPlugin.swift` 507-514에서 `onDeviceError`를 돌려준 뒤 `return`이 없음을 직접 확인함. 어댑터가 실패한 `listen`(`ListenFailedException`·`PlatformException`)과 모든 `_onError` 뒤에 `_speech.cancel()`을 부름(`_release`) | `platform_speech_recognizer_test.dart` "iOS without on-device recognition: the OD-2 event and the microphone off", "Android without the on-device language pack: the microphone off too" | `m2_s2_red.txt`: `Expected: <1> Actual: <0>`, `Expected: a value greater than <0> Actual: <0>` | `511ac32` |
| S2 | 생성자의 `SpeechToText`를 상속한 가짜(`ScriptedSpeech`)로 어댑터 단위 테스트 12개: 중간·최종 결과, done만 오면 말 없음, 초기화 실패, 한국어 로캘 찾기, 오류 코드 변환 6가지, 기기 안 판별, 늦은 이벤트 무시, 권한 합치기(권한 플러그인 채널은 모의 처리기로 응답). 실패한 `listen`의 오류 코드에 `details`가 없으면 `null` 글자가 붙던 것도 고침 | 같은 파일 | `m2_s2_red.txt`: `Expected: 'failed to create speech recognizer' Actual: 'failed to create speech recognizer null'` | `511ac32` |
| F2 | `AssistantController`에 세대 번호 `_generation`을 두고 멈출 때(`cancel`·`switchToText`·`dispose`)마다 올림. `_begin`·`acceptConsent`·`_listen`이 await 뒤 같은 세대인지 확인하고, 아니면 듣지 않고 기다림 상태로(글로 입력으로 멈췄으면 글로 입력 유지). 가짜 인식기에 `localeHold` 완료자만 더함 | `assistant_test.dart` "going to the background during the first start does not listen afterwards" | `f2_f3_red.txt`: `Expected: empty Actual: [` (`listenCalls`에 기록이 남음) | `11231a5` |
| F3 | 테스트만 더함. 이미 맞게 동작하는 경로라 처음부터 통과함(RED 없음, 덮이지 않던 경로를 덮는 테스트) | "[말하기 끝] sends the words heard so far", "without a Korean recognizer the assistant opens in text mode", "refused for good in the OS dialog: the settings line" | 해당 없음(`f2_f3_red.txt`에서 세 테스트 통과) | `8fe6516` |
| S4 | `Info.plist` `NSSpeechRecognitionUsageDescription` → "말한 내용을 글로 바꿔 부탁으로 보내요. 기기에서 안 되면 애플 음성 인식 서비스를 써요. 콜비는 음성을 저장하지 않아요." `plutil -lint` OK. 옛 문구를 단언하는 테스트는 없음. 법률 검토(03 NFR-LAW)는 아직 대기 | architecture_test "platform files declare..."(키 존재만 확인) | 해당 없음(문구) | `c31ddaa` |
| S5 | README "말로 부탁하기": 권한이 있으면 화면을 열자마자 듣고, 말이 끝나거나 [말하기 끝]을 누르면 보냄, 기다리는 중에는 Orb로 다시 듣기. 소제목 "음성은 콜비 서버로 보내지 않습니다" | 해당 없음 | 해당 없음 | `c31ddaa` |
| S6 | `acceptance.md` 제목 (0.3.0) → (0.3.1) | 해당 없음 | 해당 없음 | `c31ddaa` |
| I2 | `shell/navigation.dart:6` "these four functions" → "these functions" | 해당 없음 | 해당 없음 | `c31ddaa` |

최종 확인(HEAD `c31ddaa`, 출력은 `audit1/final_*.txt`):

```
$ cd app && flutter --suppress-analytics test
00:13 +148: All tests passed!
$ cd app && flutter --suppress-analytics analyze
   info • ... • test/support/fakes.dart:54:5 • use_null_aware_elements
1 issue found.
$ dart test
00:00 +2: All tests passed!
$ cd packages/kolbi_ui && flutter --suppress-analytics test
00:01 +72: All tests passed!
$ git diff --stat 7b32f44 -- server/
(출력 없음)
$ cd app && flutter --suppress-analytics build ios --simulator --debug
✓ Built build/ios/iphonesimulator/Runner.app
$ cd app && flutter test --coverage  (lcov에서 줄 수 계산)
platform_speech_recognizer.dart 93/102 91.2%   (전: 46/93 49.5%, HEAD 34ad269)
assistant_controller.dart 120/123 97.6%
```

남은 것: 실기기에서 OD-2 안내 중 마이크 표시등이 꺼지는지 확인(M2는 플러그인 소스 읽기와 단위 테스트로만 확인), `Info.plist` 문구 법률 검토, I4(SwiftPM `Package.resolved` 처리)는 소유자 결정 대기. `fake_speech_recognizer.dart`의 `koreanLocaleId`는 한 줄 화살표 함수가 본문으로 바뀌었지만 `localeHold`가 없으면 동작이 같음.

## §F Phase 4 Mode Selection

- kickoff: 소유자가 구현 시작 승인(2026-11-27, "기본값으로 시작" — OD-2~OD-5는 계획 기본값, 반영은 브랜치 + PR, 진행은 자율 실행 뒤 소유자가 화면을 보고 sync·감사·병합). 소유자가 Xcode 27.2(macOS 27.2.1)를 설치한 뒤 시작했고, iOS 27.2 시뮬레이터 런타임은 소유자가 함께 설치함
- precondition: SPEC-SHELL-001과 SPEC-DESIGN-001 `completed`(SHELL은 PR #1로 main에 병합, 7b32f44)
- route: 작업 폴더 /Users/jason/Documents/Jason-Danmuzi/wt-assist-001의 feat/SPEC-ASSIST-001 브랜치(origin/main 7b32f44에서 만듦). run 뒤 PR, 병합은 소유자
- carried from SHELL-001 sync-audit F1: `/assistant`를 첫 화면으로 열 때(웹 주소 직접 입력) 닫기 `pop()`과 submitFromAssistant가 `/assistant` 위에 push하는 문제(research R1-G)
- inputs: tier M(약 33개 파일, 소유자가 M 편차 승인), 영역: 음성 포트와 플랫폼 어댑터, 비서 상태와 화면, Orb 움직임, 진입점, 통화 중 화면, 테스트. 언어: Dart + iOS/Android 설정. 병렬 이득 낮음
- evaluation: direct — 선택 안 함, fanout — 선택 안 함(코딩 위주), sweep — 선택 안 함, serial — 선택
- Decision: serial
- justification: 음성 포트(M1)와 비서 상태(M2)가 모든 화면 마일스톤의 바탕이고, M4·M5가 M2도 건드리는 셸 라우터와 통화 화면을 고치므로 한 작업자가 순서대로 해야 충돌이 없다
