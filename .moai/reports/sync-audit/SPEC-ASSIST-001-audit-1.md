# Sync 감사 보고서 — SPEC-ASSIST-001 (1차)

- 감사 대상: 워크트리 `/Users/jason/Documents/Jason-Danmuzi/wt-assist-001`, 브랜치 `feat/SPEC-ASSIST-001`, HEAD `69aff3c`. run 시작 `7b32f44`(origin/main), 구현 커밋 `7623909`(M1)·`b39c48d`(M2)·`afa4fa8`(M3)·`013df8c`(M5)·`dd3e451`(M4)·`f5ab61b`(Android 안내), run 기록 커밋 `6025987`·`477dac5`, sync 커밋 `69aff3c`
- 등급: Tier M (16 REQ / 16 AC, 파일 수는 소유자 승인 편차로 M 유지). 선례 `SPEC-SHELL-001-audit-1.md`와 같은 형식·채점 방식.
- 평가 프로필: `.moai/config/evaluator-profiles/default.md` (Functionality 40%, Security 25%, Craft 20%, Consistency 15%. 필수 통과 차원은 Functionality와 Security)
- 집계: 차원 점수의 비가중 조화 평균(선례와 같음). 참고로 가중 조화 평균도 적는다.
- 감사 방식: 읽기 전용. 아래 명령은 모두 이번 감사에서 HEAD `69aff3c` 트리에 직접 실행했다. 임시 파일(커버리지 lcov, 서식 비교용 사본)은 세션 scratchpad에만 두었고, 저장소에 쓴 파일은 이 보고서 하나다. `server/.env`는 읽지 않았다.
- 상태: 완료

## 1. 판정 요약

| 차원 | 점수 | 판정 | 근거 요약 |
|------|------|------|-----------|
| Functionality (40%) | 88 | PASS | 다섯 테스트·분석 명령을 다시 실행해 모두 기대 결과(앱 `+132`, kolbi_ui `+72`, kolbi_core `+27`, 루트 `+2`, 분석은 기준선 info 1건뿐). AC 16개 모두 이름이 맞는 테스트에 연결되고 테스트 본문이 Then 조건을 확인함. REQ-007 다섯 경우 직접 확인. 감점: [말하기 끝](`finishSpeaking`)과 "한국어 인식 언어 없음" 경로가 어떤 테스트에서도 실행되지 않음(F3), 첫 열기 중 배경 전환 경쟁(F2, 코드 읽기) |
| Security (25%) | 86 | PASS | 비밀 값 없음, `server/` 무변경, 오디오 바이트·파일 쓰기 없음(grep), 서버로 가는 것은 `intake` 하나(`callLog` 단언), 안내 기록은 기기 안 SharedPreferences 불리언 하나. Critical/High 없음. 감점: iOS 플러그인이 기기 안 인식 불가 오류를 돌려준 뒤에도 마이크를 켜는데 어댑터가 끄지 않음(M2, 중간), iOS 음성 인식 권한 문구가 "기기의 음성 인식"으로 단정(S4) |
| Craft (20%) | 80 | PASS | 앱 `lib` 줄 커버리지 91.7%, 새 화면·상태 파일 94~100%. 포트·어댑터 분리와 `@MX` 주석이 명확함. 감점: 새 파일 4개가 서식 밖(M1, DoD 위반), 어댑터 49.5%로 오류 코드 변환이 테스트되지 않음(S2), Android 안내는 test-after |
| Consistency (15%) | 84 | PASS | spec·acceptance 본문 변경은 소유자 결정 두 건뿐. §E.4의 SHA·파일 수(39)·테스트 diff(11개, +1442/−18)가 git과 일치. f5ab61b→69aff3c는 문서 13개만 바뀌어 측정이 그대로 유효. 코드맵·structure·11_ARCHITECTURE의 경로·함수 이름이 코드와 일치. 감점: README의 동작 설명 한 문장과 소제목(S5), acceptance 제목 버전(S6), 오래된 주석(I2) |
| **조화 평균** | **84.4** (가중 85.2) | | |

**최종 판정: PASS-with-debt.** 두 필수 차원 모두 통과하며 막는(blocking) 결함은 없다. 다만 M1(서식, 명령 한 줄)과 M2(어댑터 한 줄)는 PR 병합 전에 고치기를 권한다.

## 2. 기준 측정 (이번 감사, 이 트리, HEAD `69aff3c`)

```
$ cd app && flutter --suppress-analytics test
00:11 +132: All tests passed!

$ cd app && flutter --suppress-analytics analyze
   info • Use the null-aware marker '?' rather than a null check via an 'if'. Try using '?' • test/support/fakes.dart:54:5 • use_null_aware_elements
1 issue found. (ran in 1.6s)          (기준선 info 1건뿐, exit 1은 info 때문)

$ dart test                                   (저장소 루트)
00:00 +2: All tests passed!

$ cd packages/kolbi_ui && flutter --suppress-analytics test
00:01 +72: All tests passed!

$ cd packages/kolbi_core && dart test
00:00 +27: All tests passed!

$ git diff --stat 7b32f44 -- server/
(출력 없음)

$ git diff --name-only f5ab61b 69aff3c
.moai/project/codemaps/{dependencies,entry-points,modules}.md, .moai/project/{structure,tech}.md,
.moai/specs/EPIC-KOLBI-APP/overview.md, .moai/specs/SPEC-ASSIST-001/{acceptance,progress,spec}.md,
README.md, docs/planning/06_DESIGN_DECISIONS.md, docs/product/{10_PRODUCT_PLAN,11_ARCHITECTURE}.md
→ 코드·테스트·pubspec 변경 없음. §E.4의 "f5ab61b에서 측정" 값이 69aff3c에도 그대로 맞고, 위 재실행 결과와도 같다
```

테스트 수는 SHELL 완료 시점(앱 `+109`, kolbi_ui `+68`)보다 늘었다(AC-016 "줄지 않음" 충족). 서버 `npm test`는 `server/` diff가 비어 있어 다시 돌리지 않았다.

## 3. Functionality — 88, PASS

### 3.1 AC → 증거 연결

| AC | 증거(테스트·명령) | 이번 감사에서 직접 본 것 |
|---|---|---|
| AC-001 | assistant_test "assistant screen follows the immersive layout" | 세로 순서 8항목 비교, 조작 줄 세 버튼 같은 줄, 바탕 `0xFF11131F`, 예시 칩 → 입력칸 `callTemplates.first.goal`·`intakeCalls` 빈 목록, `assistant_placeholder.dart` 없음 단언 |
| AC-002 | "orb state is shown in words and announced", kolbi_ui orb_test | `orb.dart` `_sync`가 움직임 줄이기에서 컨트롤러를 버리고 만들지 않음, `ExcludeSemantics`로 감쌈 |
| AC-003 | "dictation fills the request and opens the plan card", "an older server keeps the blank-plan fallback" | `listenCalls == [(ko-KR, onDevice: true, partialResults: true)]`, 중간 문장 두 개, `PlanCardScreen`, 탭 바 없음, 뒤로 → 비서. 가짜 없이 열면 글로 입력·예외 없음 |
| AC-004 | "only the final text reaches Kolbi" + AC-003 테스트의 `callLog.sublist(before) == ['intake']` | 아래 4절. 단 `callLog`·`onDevice` 단언은 AC-003 테스트 안에 있음(I1) |
| AC-005 | "microphone permission is asked with a purpose first" | 통과 |
| AC-006 | "recognition failures never loop or send an empty request" | (5)에서 `listenCalls` 길이 2, (6) 다시 열고 Orb → `onDevice: false`·OD-2 안내 없음 확인 |
| AC-007 | "stopping or leaving cancels dictation; inactive does not" | 3.2 |
| AC-008 | "text mode carries the whole request box" | 통과 |
| AC-009 | "missing profile and intake errors keep the request" | 통과. `_submit`이 프로필 없으면 `openAssistantSettings`(자식 경로) |
| AC-010 | "today hands requests to the assistant" | `home_screen.dart:212-221` 브리핑 빈 문구·링크·바로가기가 `openAssistant` |
| AC-011 | live_call_test 세 테스트 | `approval_listener.dart`가 `liveCallLocation`도 숨김 조건에 넣음, `live_call_screen.dart:36-46` 통화 끝나면 한 번 `closeLiveCall` |
| AC-012 | "task screen links to the live call" | 통과 |
| AC-013 | architecture_test "speech and permission packages stay inside the assistant feature" + grep | 3.3 |
| AC-014 | assistant_test·live_call_test "immersive screens meet the accessibility guidelines" | 통과 |
| AC-015 | `git diff --stat` 10개 파일 | 3.4 |
| AC-016 | 서버 diff, 테스트 diff | 3.4 |

### 3.2 REQ-007 — 멈춤·닫기·배경 전환

- 코드: `assistant_screen.dart:74-80`이 `paused`·`hidden`·`detached`에서만 `_controller.cancel()`을 부르고 `inactive`는 무시한다. 닫기·[그만하기]는 `_close`(`:142-145`)로 `cancel` 뒤 `closeAssistant`. 시스템 뒤로 가기는 화면이 사라지며 `dispose` → `AssistantController.dispose`(`assistant_controller.dart:276-281`)가 `_closed = true` 뒤 `recognizer.cancel()`. `_set`이 `_closed`를 보므로 늦은 이벤트가 상태·`intake`에 닿지 않는다.
- 테스트(`assistant_test.dart:439-518`): (1)~(3) 각각 새 앱에서 `cancelCalls > 0`, 같은 상세 `c`·업무 탭 선택, 늦은 `SpeechFinal` 뒤 `intakeCalls` 빈 목록·예외 없음. (4) `inactive → hidden → paused` 뒤 `cancelCalls > 0`, 되돌아와 늦은 결과가 와도 `intake` 없음. (5) `inactive`만이면 `cancelCalls == 0`, 칩 "듣고 있어요". 수락 기준과 같다.
- 빈틈: 첫 열기에서 `_listen`이 `koreanLocaleId()`(처음이면 `initialize`)를 기다리는 사이 배경으로 가면, `cancel()`은 아직 `listening`이 아니라 아무것도 막지 못하고, 기다림이 끝난 뒤 `_start`가 실행된다(F2).

### 3.3 AC-013 — 구조 grep (이번 감사에서 실행)

```
$ grep -rln "speech_to_text\|permission_handler" app/lib packages/*/lib
app/lib/features/assistant/speech/platform_speech_recognizer.dart

$ grep -n "allowedCrossFeature =" app/test/architecture_test.dart
8:const allowedCrossFeature = <String>{};

$ grep -rnE "\.go\(|goNamed\(|goBranch\(" app/lib/features             (출력 없음)
$ grep -rnE "'/(calls|plan|settings|inbox|history|me|assistant)" app/lib/features   (출력 없음)
$ grep -rn "features/calls" app/lib/features/assistant                 (출력 없음)
```

비서는 `shell/request_intake.dart`·`shell/navigation.dart`만 거친다. `KolbiOrb` 생성자는 `state`·`size`(와 key)만 받는다.

### 3.4 AC-015·AC-016 — 테스트 변경 범위

```
$ git diff --stat 7b32f44 -- app/test/{approval_card,plan_card,follow_up,trust_notice,outcome_card,calls_controller,unit,theme,history,font_overflow}_test.dart
 app/test/font_overflow_test.dart | 3 ++-
 1 file changed, 2 insertions(+), 1 deletion(-)

$ git diff --stat 7b32f44 HEAD -- app/test/ | tail -1
 11 files changed, 1442 insertions(+), 18 deletions(-)

$ git diff 7b32f44 -- app/test/support/fakes.dart | grep '^-'
--- a/app/test/support/fakes.dart        (머리줄만, 지운 줄 없음)
```

기존 파일마다 `git diff -U0` 덩어리를 AC-016 표와 맞췄다.

| 파일 | 실제 변경 | 표 행 | 판정 |
|---|---|---|---|
| `font_overflow_test.dart` | `:73` 표식 `'직접 입력하기'` → `'전화 대신하기'` + 이유 주석 한 줄 | 소유자 승인 확장 행(2026-11-28) | 일치. 변수 이름 `manual`은 그대로(I7) |
| `intake_flow_test.dart` | 도우미에 `/assistant?mode=text` push 5줄 + import 1줄, `:138` `피자집` 한 줄 삭제, `:151` "귀찮은 전화" 한 줄 삭제 | 도우미 행, :138 행, :151 행 | 일치. 표에 적힌 나머지 블록(:67, :90-102, :104, :178-189, :192)은 도우미 변경만으로 통과해 손대지 않음(허용 범위보다 적음) |
| `approval_flow_test.dart` | `:39-40` 첫 사용 빈 상태 → 브리핑 빈 문구 | :36-37 행 | 일치 |
| `accessibility_test.dart` | `:343` 빈 상태 블록, `:567` 글로 입력 모드로 띄우는 줄, `:618` 홈 순서의 입력칸 항목 제거 | 세 행 | 일치 |
| `shell_test.dart` | AC-006 (2) 주석과 단언 5줄(`/assistant/plan` 위, 뒤로 → 비서, 닫기 → 상세 `c`) | AC-006 행 | 일치 |
| `today_test.dart` | AC-015 블록에서 입력칸·예시·보내기·"귀찮은 전화" 단언 제거, 브리핑 빈 문구, `today-briefing findsNothing` 제거 | AC-015 행 | 일치(브리핑 카드가 이제 보이므로 "없음" 단언 제거는 "브리핑 빈 문구"에 포함) |
| `architecture_test.dart` | 새 테스트 2개(끝에 더함) | AC-013, spec §4 | 허용(SHELL C5와 같은 성격) |
| `fakes.dart` | 더하기만(`intakeHold`, `callLog`, `cancel`·`delete` 재정의) | fakes 행 | 일치 |

`inbox_test.dart`와 `today_test` "today shortcuts"는 비서가 SHELL 키(`assistant-intake-field` 등)를 그대로 써서 바뀌지 않았다. §E.4 기록과 같다.

## 4. Security — 86, PASS

```
$ git diff 7b32f44 HEAD | grep -niE "^\+.*(api[_-]?key|secret|password|bearer|BEGIN (RSA|PRIVATE)|sk-[a-zA-Z0-9]{10})"
(출력 없음)

$ grep -rnE "\.wav|\.m4a|\.aac|writeAsBytes|Uint8List" app/lib/features/assistant
(출력 없음)
```

- **OD-1·REQ-004 (글만 서버로)**: 포트 `SpeechRecognizer`(`speech_recognizer.dart:58-81`)는 글 이벤트만 돌려주고 오디오 멤버가 없다. 서버로 가는 유일한 길은 `_submit` → `requestPlanDraft`(`shell/request_intake.dart:28-46`) → `intake(text)`. AC-003 테스트가 비서를 연 뒤 `callLog`가 `['intake']`뿐임을 확인한다.
- **기기 안 인식 우선**: 첫 `listen`은 `onDevice: !memory.generalRecognizer`(`assistant_controller.dart:186`)라 처음엔 늘 `true`. 일반 인식(`onDevice: false`)은 `acceptGeneralRecognizer`(`:233-239`, OD-2 안내 [계속])에서만 시작한다. 다시 열 때 `generalRecognizer`가 기억되어 있으면 안내 없이 `false`로 듣는데, 이는 AC-006 (6)이 요구한 동작(앱 실행 동안만, 저장하지 않음)이다.
- **iOS에서 안내 없는 네트워크 인식**: iOS 플러그인은 `onDevice: true`이면 `requiresOnDeviceRecognition = true`(`SpeechToTextPlugin.swift:557-559`)를 세우므로 안내 전에 애플 서버로 가는 길은 없다. 다만 기기 안 인식을 지원하지 않는 기기에서 플러그인은 `onDeviceError`를 돌려준 **뒤 `return` 없이** 오디오 세션과 오디오 엔진을 켠다(`:507-514` 뒤 `:519-601`). 어댑터는 이 오류를 `SpeechOnDeviceUnavailable`로 바꾸고 세션을 닫기만 하고 `_speech.cancel()`을 부르지 않는다(`platform_speech_recognizer.dart:147-155`). 그래서 OD-2 안내가 떠 있는 동안 마이크가 켜져 있을 수 있다. 요청이 기기 안 전용이라 음성이 밖으로 나가지는 않고, 나가기·[글로 입력]·[그만하기]는 모두 `cancel()`을 거쳐 끈다(M2, 중간, 실기기 미확인).
- **Android 안내**: `_needsSpeechServiceNotice`(`assistant_screen.dart:57-59`)는 Android이고 `androidSpeechServiceNoticeAcknowledged`가 참이 아닐 때만. 기록은 `sharedPreferencesProvider`의 불리언 하나(기기 안)이고 서버·로그로 가지 않는다. 테스트 "Android shows the speech-service notice once…"가 (1) 권한 있음 → 안내 카드, [계속] 전 `listen` 0, 뒤 1, 저장 참 (2) 본 뒤 바로 듣기 (3) 권한 묻기 전 → 목적 안내 한 장에 두 문장을 확인한다. iOS 테스트는 미리 안내가 없음을 확인한다.
- **권한 문구**: `Info.plist:68-72` 두 키 모두 한국어. `NSMicrophoneUsageDescription`은 REQ-005 사전 안내와 같은 문장. `NSSpeechRecognitionUsageDescription`은 "기기의 음성 인식으로 글로 바꿔"라고 단정하는데, OD-2 대체 시 애플 서버가 처리하므로 조금 넘치는 표현이다(S4). Android는 `RECORD_AUDIO`와 `<queries>` `RecognitionService`만, 블루투스 없음(architecture_test가 확인).
- **새 의존**: `speech_to_text` 7.5.0(BSD-3), `permission_handler` 13.0.2(MIT), `pubspec.lock` 80줄 추가·0줄 삭제(§E.2 M1). 커밋하지 않은 `Package.resolved` 두 개는 `CwlCatchException` 2.2.1 고정뿐이며 비밀 값 없음.

## 5. Craft — 80, PASS

### 5.1 코드 검토

- 포트·어댑터·상태·화면의 경계가 분명하다. 컨트롤러는 포트만 알고, Android 안내 판단과 저장은 화면이 콜백으로 주입한다. `_closed` 가드, `@MX:ANCHOR`/`@MX:REASON`이 REQ-007 의도를 적었다.
- 어댑터는 비지원 플랫폼에서 플러그인을 건드리지 않고 `unavailable`을 돌려준다(위젯 테스트 호스트에서 플러그인 호출이 끝나지 않는 문제를 피함). 주석이 이유를 설명한다.
- 남은 점: `stop()`(`platform_speech_recognizer.dart:204-208`)만 `PlatformException`을 잡지 않는다(I9). `acceptConsent`는 권한 결과와 무관하게 Android 안내를 확인 처리한다(`assistant_controller.dart:155`, I6, 해는 없음).

### 5.2 서식

```
$ cd app && git diff --name-only --diff-filter=A 7b32f44 -- '*.dart' | sed 's#^app/##' | xargs dart format --output=none --set-exit-if-changed
Changed lib/features/assistant/assistant_controller.dart
Changed lib/features/assistant/assistant_screen.dart
Changed lib/features/assistant/mic_consent_sheet.dart
Changed test/assistant_test.dart
Formatted 12 files (4 changed) in 0.05 seconds.

$ (같은 네 파일의 dd3e451 사본) dart format --output=none --set-exit-if-changed .
Formatted 4 files (0 changed)
```

새 앱 파일 12개 중 4개가 서식 밖이고, 네 파일 모두 `dd3e451`에서는 서식 통과였다. 즉 `f5ab61b`(Android 안내, 오케스트레이터 적용)가 서식을 적용하지 않았다. kolbi_ui 새 파일 3개는 통과. 완료 정의 "서식은 변경 파일에만 적용"에 어긋난다(M1).

### 5.3 RED 기록

`.moai/state/verify/SPEC-ASSIST-001/red/`에 9개 파일(M1~M5, M4 깨짐·표식 기록, `android_notice_red.txt`). Android 안내는 기능을 `false &&`로 끈 실패로 대신했다(test-after, §E.3에 정직하게 적힘). 이 폴더는 `.gitignore:205`(`.moai/state/`)로 커밋되지 않는다(I3).

### 5.4 커버리지 (이번 감사에서 측정)

```
$ cd app && flutter --suppress-analytics test --coverage --coverage-package callmate --coverage-package kolbi_ui --coverage-path=<scratchpad>/lcov.info
00:14 +132: All tests passed!
```

| 범위 | 덮인 줄 / 전체 | 비율 |
|---|---|---|
| 앱 `lib` 전체 | 2010 / 2191 | 91.7% |
| `assistant_controller.dart` | 110 / 117 | 94.0% |
| `assistant_screen.dart` | 173 / 175 | 98.9% |
| `mic_consent_sheet.dart` | 46 / 46 | 100% |
| `request_box.dart` | 48 / 49 | 98.0% |
| `speech/platform_speech_recognizer.dart` | 46 / 93 | 49.5% |
| `live_call_screen.dart` | 128 / 128 | 100% |
| `shell/navigation.dart` | 34 / 36 | 94.4% |
| `shell/request_intake.dart` | 12 / 13 | 92.3% |
| kolbi_ui `orb.dart`, `immersive_theme.dart` | 47 / 47, 1 / 1 | 100% |

덮이지 않은 줄 중 의미 있는 것: `assistant_controller.dart:242-243`(`finishSpeaking`, [말하기 끝]), `:185`(한국어 로캘 없음 → `noKorean`), `:162/:164`(요청 뒤 영구 거부·unavailable). 어댑터 `:35-46`(`_combine` 권한 합치기), `:147-157`(iOS 기기 안 오류 판별), `:163-187`(`_onResult`·`_onError`·`_onStatus` 이벤트 변환). 어댑터는 생성자에서 `SpeechToText`를 받을 수 있는데(`:21`) 이를 이용한 단위 테스트가 없다(S2). 프로필 기준 85%는 앱 전체에서 넘는다.

## 6. Consistency — 84, PASS

- **spec.md**(`git show 69aff3c`): `version` 0.3.0 → 0.3.1, `status` in-progress → implemented, `updated` 2026-11-26 → 2026-11-28, HISTORY 0.3.1 한 행, §5 OD-2 행에 Android 편차. 그 밖의 본문 변경 없음. §E.4 `frontmatter_status_transitions`와 같다(477dac5의 값 직접 확인).
- **acceptance.md**: AC-006 아래 편차 문단, AC-015 단서 한 문장, AC-016 표 한 행과 확장 문단, DoD 한 줄. 그 밖의 변경 없음. 확장 문단이 가리키는 §E.2 "실행 상태 — M4 커밋 전에 멈춤"이 실제로 있다.
- **§E.4와 git**: `run_start_sha 7b32f44`, 마일스톤 SHA, `run_evidence_commit_sha 477dac5`가 `git log`와 같다. `git diff --name-only 7b32f44 f5ab61b | wc -l` → 39. `app/test/` 11개 파일 +1442/−18 일치. `sync_commit_sha: pending-backfill`은 자기 SHA를 적을 수 없다는 설명과 함께 있어 문제 없음(HEAD `69aff3c`).
- **문서 주장과 코드**: structure.md 경로 표 5행(`/assistant`, 자식 셋, `/calls/:id/live`)이 `app_router.dart` 그대로다(이름 `assistant-plan`·`assistant-settings`·`assistant-new`·`live-call`, `/assistant/plan`의 `extra` 리다이렉트). modules.md의 `navigation.dart` 함수 목록이 파일과 같다. entry-points.md의 "브리핑 빈 문구의 링크"는 `home_screen.dart:216-217`, "통화 중 화면에서도 조용함"은 `approval_listener.dart` 변경과 맞다. `/calls/new`가 "경로만 남음"인 것도 맞다(`RouteNames.newCall`은 라우터에만). dependencies.md mermaid의 `intake --> feed`는 `request_intake.dart:8`의 `task_feed.dart` import와 맞다. modules.md의 Orb 설명(대기 멈춤, 듣는 중 숨쉬기, 처리 중 빛 돌기)과 `KolbiTheme.immersive() => AppTheme.dark()`가 코드와 같다. tech.md 패키지 두 행과 SwiftPM 제약(`Package.resolved` 미커밋)이 사실이다. plan §G의 네 항목(structure, 06 Q-3, 10 A-7, README)이 모두 반영됐다.
- **README 정확도**: `README.md:26` "Orb를 누르고 말하면 … [말하기 끝]을 누르면 … 계획 카드를 엽니다"는 실제 기본 동작(권한이 있으면 화면을 열자마자 듣기 시작, OD-3; 인식기가 말이 끝났다고 알려도 보냄)과 다르다. `README.md:29` 소제목 "음성은 서버로 보내지 않습니다"는 본문이 애플·구글 처리를 설명하지만 소제목만 보면 REQ-004가 일부러 피한 "음성이 기기를 떠나지 않는다"로 읽힌다(S5).
- **한국어 문서 규칙**: sync 커밋이 더한 줄을 검사했다(백틱·괄호 밖 한글이 거의 없고 영어 단어 6개 이상인 줄). 걸린 것은 문서 끝 "Generated by /moai project … Updated by /moai sync …" 꼬리줄 5개(기존 관례를 이어 씀)와 progress.md YAML 값 속 명령 출력 인용뿐이다. 본문 산문은 모두 한국어다(I5).
- 감점: S5, S6(acceptance 제목 버전), I2(`navigation.dart:6` "four functions").

## 7. 발견 사항

확신도는 높음/중간/낮음.

| ID | 심각도 | 차원 | 확신도 | 내용 | 권장 조치 |
|---|---|---|---|---|---|
| M1 | 중간(비차단, 병합 전 수정) | Craft | 높음 | 새 파일 4개가 서식 밖: `app/lib/features/assistant/assistant_controller.dart`, `assistant_screen.dart`(예: `:59`의 긴 줄), `mic_consent_sheet.dart`, `app/test/assistant_test.dart`. 네 파일 모두 `dd3e451`에서는 통과였고 `f5ab61b`가 깨뜨림. 완료 정의 "서식은 변경 파일에만 적용"에 어긋나고 §E.2·§E.4는 이를 말하지 않음 | 이 네 파일에만 `dart format`(프로젝트 전체 금지 규칙 유지). 테스트를 다시 돌려 `+132` 확인 |
| M2 | 중간(비차단, 병합 전 수정 권장) | Security | 중간(플러그인 소스 읽기, 실기기 미확인) | iOS에서 기기 안 인식을 지원하지 않으면 speech_to_text 7.5.0은 `onDeviceError`를 돌려준 뒤에도 `return` 없이 오디오 엔진을 켠다(`~/.pub-cache/.../SpeechToTextPlugin.swift:507-514`, 이어서 `:519-601`). 어댑터 `platform_speech_recognizer.dart:147-155`는 `SpeechOnDeviceUnavailable`을 내보내고 세션만 닫으며 `_speech.cancel()`을 부르지 않는다. 그래서 OD-2 안내([계속]/[글로 입력])가 떠 있는 동안 마이크가 켜져 있을 수 있다. 요청은 `requiresOnDeviceRecognition = true`라 음성이 밖으로 나가지는 않고, 나가는 경로는 모두 `cancel()`로 끈다 | `SpeechOnDeviceUnavailable`을 내보낼 때 `_speech.cancel()`을 함께 부른다(iOS 판별 분기와 Android `error_language_*` 분기 모두). 실기기 확인 목록에 "OD-2 안내 중 마이크 표시등 꺼짐"을 더한다 |
| F2 | 낮음 | Functionality/Security | 중간(코드 읽기) | `_listen`(`assistant_controller.dart:179-187`)이 `koreanLocaleId()`(첫 호출이면 `initialize`)를 기다리는 동안 앱이 배경으로 가면, `cancel()`(`:254-258`)은 `listening`이 아니라 아무것도 막지 못하고, 기다림 뒤 `_closed`가 거짓이라 `_start`가 듣기를 시작한다. 첫 열기의 짧은 창에서만 생김 | `cancel()`이 세대 번호를 올리고 `_listen`·`acceptConsent`가 await 뒤 같은 세대인지 확인하게 한다(또는 `_start` 전에 생명주기 상태 확인) |
| F3 | 낮음 | Functionality | 높음 | 테스트되지 않은 경로: [말하기 끝] → `finishSpeaking` → `recognizer.stop()`(`assistant_controller.dart:242-243`, REQ-003의 명시 경로), 한국어 로캘 없음 → `noKorean` 문구와 글로 입력(`:185`, acceptance 엣지 케이스), 요청 뒤 영구 거부(`:162`) | 가짜 인식기로 [말하기 끝] 뒤 `stop` 호출과 최종 문장 `intake`, `koreanLocaleId == null`이면 글로 입력·문구를 확인하는 위젯 테스트를 더한다 |
| S2 | 낮음 | Craft | 높음 | 어댑터 줄 커버리지 49.5%. 권한 합치기(`:35-46`), iOS 기기 안 오류 판별(`:147-157`, 오류 문자열에 "on device"가 있는지에 기대는 취약한 판별), 오류 코드 → 이벤트 변환(`:172-183`)이 테스트되지 않았다. 생성자가 `SpeechToText`를 받으므로 가짜로 바꿀 수 있다 | `SpeechToText`를 상속한 가짜로 `_onError`·`ListenFailedException` 변환을 단위 테스트한다 |
| S4 | 낮음 | Security/Consistency | 중간 | `app/ios/Runner/Info.plist:72` `NSSpeechRecognitionUsageDescription` "말한 내용을 기기의 음성 인식으로 글로 바꿔…"는 OD-2 대체 시 애플 서버가 처리하는 경우를 덮지 못한다. OS 권한 창 문구라 처음 보는 고지 문장이다 | "기기의 음성 인식(필요하면 애플의 음성 인식 서비스)으로…"처럼 바꾸고 법률 검토(03 NFR-LAW) 항목에 함께 올린다 |
| S5 | 낮음 | Consistency | 높음 | `README.md:26` "Orb를 누르고 말하면 … [말하기 끝]을 누르면 계획 카드를 엽니다"는 기본 동작(권한이 있으면 열자마자 듣기, 말이 끝나도 보냄)과 다르다. `README.md:29` 소제목 "음성은 서버로 보내지 않습니다"는 "콜비 서버로"가 빠져 REQ-004가 피한 보장처럼 읽힌다 | ":26"을 "화면을 열면(처음이면 권한 안내 뒤) 바로 듣고, 말이 끝나거나 [말하기 끝]을 누르면…"으로, ":29" 소제목을 "음성은 콜비 서버로 보내지 않습니다"로 |
| S6 | 낮음 | Consistency | 높음 | `acceptance.md:1` 제목이 "(0.3.0)"인데 0.3.1 주석이 들어갔고 spec은 0.3.1이다(SHELL C3와 같은 종류) | 제목을 0.3.1로 |
| I1 | 정보 | Consistency | 높음 | AC-004의 핵심 단언(`callLog`가 `intake`뿐, 첫 `listen`이 `onDevice: true`)은 AC-004 이름의 테스트가 아니라 AC-003 테스트(`assistant_test.dart:221-237`)에 있다. 주석 `// AC-003, AC-004`로 표시돼 추적은 된다 | 다음부터 progress AC 표에 실제 단언이 있는 테스트 이름도 적는다 |
| I2 | 정보 | Craft | 높음 | `app/lib/shell/navigation.dart:6` "Features call these four functions"는 함수가 열 개 넘게 늘어 맞지 않는다 | 주석을 "these functions"로 |
| I3 | 정보 | Consistency | 높음 | progress가 인용하는 증거 파일(`.moai/state/verify/SPEC-ASSIST-001/…`)은 `.gitignore:205`로 커밋되지 않아 이 작업 폴더에서만 볼 수 있다 | 기록만(선례와 같음) |
| I4 | 정보 | Consistency | 높음 | `app/ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved`와 `project.xcworkspace` 쪽 사본이 추적되지 않는다. 원격 SwiftPM 의존(`CwlCatchException` 2.2.1)을 고정하는 파일이라, 앱 저장소에서는 보통 커밋해 빌드를 재현 가능하게 한다 | 소유자 결정 대기(§E.4 `untracked_handling`). 커밋하거나 `.gitignore`에 넣어 어느 쪽이든 정한다 |
| I5 | 정보 | Consistency | 높음 | sync가 더한 영어 산문은 문서 끝 "Generated by /moai … Updated by /moai sync …" 꼬리줄뿐(기존 관례) | 기록만 |
| I6 | 정보 | Craft | 높음 | `acceptConsent`(`assistant_controller.dart:155`)는 권한 요청 결과와 무관하게 Android 안내를 확인 처리한다. 사용자는 목적 안내에서 그 문장을 이미 봤으므로 해는 없다 | 기록만 |
| I7 | 정보 | Craft | 높음 | `font_overflow_test.dart:74` 변수 이름 `manual`이 이제 '전화 대신하기'를 가리킨다. 승인된 행의 범위(표식 한 줄)를 지키려고 이름을 두었다고 보인다 | 기록만 |
| I8 | 정보 | Craft | 높음 | 어댑터 `stop()`(`platform_speech_recognizer.dart:204-208`)만 `PlatformException`을 잡지 않는다 | `cancel()`처럼 감싼다 |

막는(blocking) 항목은 없다. Security에 Critical/High는 없다.

## 8. 검증하지 않은 것

- 실제 기기(권한 창, 기기 안 한국어 지원, 한국어 로캘 ID, Android 조용한 대체, M2의 마이크 표시등). §E.4도 `device_check: pending`이다.
- 서버 테스트(`npm test`)는 다시 돌리지 않았다. `server/` diff가 비어 있는 것만 확인했다.
- 오케스트레이터의 시뮬레이터·브라우저 점검(§E.4 `simulator_check`·`browser_check`)은 다시 하지 않았다.
- kolbi_core 커버리지와 kolbi_ui 자체 실행 기준 커버리지는 따로 재지 않았다(앱 실행 기준만).
- 기존 파일(서식이 원래 깨져 있는 파일)의 서식은 메모리 규칙("프로젝트 전체 format 금지")에 따라 보지 않았다.
- 커밋 메시지 형식과 pre-commit 훅은 보지 않았다.

## 9. 점수 계산

- 비가중 조화 평균: 4 / (1/88 + 1/86 + 1/80 + 1/84) = **84.4**
- 가중 조화 평균(참고): 1 / (0.40/88 + 0.25/86 + 0.20/80 + 0.15/84) = **85.2**
- 필수 차원 Functionality 88, Security 86 모두 PASS. 막는 결함 없음 → **최종 PASS-with-debt**
- 권장: M1(서식 네 파일)과 M2(어댑터에서 `cancel` 한 줄)는 PR 병합 전 작은 커밋으로 고친다. F2·F3·S2는 후속 작은 수정 또는 다음 SPEC의 부채로, S4는 법률 검토와 함께, S5·S6은 문서 정리 커밋에서 처리한다. 고친 뒤 `sync_audit`을 갱신하고 `status`를 completed로 올리는 것은 오케스트레이터 몫이다.
