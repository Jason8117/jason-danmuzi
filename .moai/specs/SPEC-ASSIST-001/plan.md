# SPEC-ASSIST-001 구현 계획 (0.3.0 — plan-audit 2차 반영)

검토 순서 안내: 바뀔 가능성이 큰 결정(받아쓰기 포트와 개인정보 경계, 권한 흐름, 오늘 화면에서 입력칸 빼기, 통화 중 화면 분리)을 앞에, 테마·권한 선언 같은 기계적 작업과 회귀를 뒤에 둔다. 화면은 `docs/planning/04_DESIGN_PLAN.md` §17.1·§17.4·§17.6, 문구는 `docs/planning/06_DESIGN_DECISIONS.md` §4.2, 다크 값은 06 §3.3, 구조는 `docs/product/11_ARCHITECTURE.md` §2.3(2026-11-26 추가)·AD-9·AD-10.

## A. 접근 방식

### A.0 받아쓰기 포트를 먼저 정하는 이유

화면·권한·오류 처리·테스트가 모두 "인식기가 무엇을 알려 주는가"에 기댄다. 패키지를 화면에서 바로 부르면 테스트가 실제 마이크에 묶이고, 패키지를 바꿀 때 화면을 다시 고친다. 그래서 M1에서 앱 안 포트 하나를 정하고, 화면과 상태 관리는 포트만 안다.

```dart
// app/lib/features/assistant/speech/speech_recognizer.dart (설계용 의사 코드)
abstract interface class SpeechRecognizer {
  Future<MicPermission> permission();            // notDetermined / granted / denied / permanentlyDenied (권한 패키지)
  Future<MicPermission> requestPermission();     // 마이크 + 음성 인식(iOS는 둘을 따로 요청)
  Future<void> openAppSettings();                // REQ-005 (3)
  Future<String?> koreanLocaleId();              // 인식기 locales()에서 한국어 ID, 없으면 null(엣지 케이스)
  Stream<SpeechEvent> listen({required String localeId, required bool onDevice});
  Future<void> stop();                           // 최종 결과를 내고 끝냄
  Future<void> cancel();                         // 결과를 버리고 즉시 끝냄(REQ-007)
}
sealed class SpeechEvent { /* partial(text), finalResult(text), noSpeech, error(code), onDeviceUnavailable */ }
```

실제 구현(`PlatformSpeechRecognizer`)은 `speech_to_text`와 권한 패키지를 감싸고(권한 상태 네 가지와 설정 열기는 권한 패키지, 듣기는 `speech_to_text`), 기기 안 인식 불가를 알리는 플랫폼 오류(Android `error_language_unavailable` 계열, iOS 1101 계열 — 정확한 코드는 M1에서 실제 기기로 확인)를 `onDeviceUnavailable` 이벤트로 바꾼다. 기기 안 인식 지원 여부를 미리 묻는 API는 없으므로(plan-audit D6) 먼저 `onDevice: true`로 시도하고 이 이벤트로 판단한다. 테스트는 `FakeSpeechRecognizer`(이벤트를 순서대로 흘려보내고 호출을 기록)를 쓴다. 공급자는 Riverpod 재정의로 바꾼다(지금 테스트의 `ProviderScope` 재정의 방식).

플러그인이 없는 환경(위젯 테스트에서 가짜를 넣지 않은 경우 포함)에서는 실제 구현이 첫 호출(`initialize`·권한 확인)에서 나는 `MissingPluginException`을 잡아 `unavailable`로 알리고, 비서는 글로 입력 모드로 연다(REQ-003). M1에서 가짜 없이 앱을 띄우는 테스트로 확인한다(AC-003). 그래서 비서를 여는 기존 테스트의 도우미마다 가짜를 넣지 않아도 된다(plan-audit 2차 N4, 3차 N11).

### A.1 비서 상태 관리 (REQ-002, REQ-003, REQ-006~008)

`AssistantController`(앱, Riverpod `Notifier`)가 상태를 하나로 가진다: `idle` · `consent`(사전 안내) · `fallbackConsent`(OD-2 안내) · `listening(partial, onDevice)` · `processing(text)` · `textInput(draft)` · `error(message)`. 연속 실패 수를 세어 둘째 실패에서 글로 입력으로 바꾸고, 다음 열기부터 자동 듣기를 끈다(REQ-006, 앱 실행 동안만 기억). Orb 상태는 이 값에서 계산한다(`listening` → 듣는 중, `processing` → 처리 중, 나머지 → 대기). 부탁 보내기는 지금 `home_screen.dart:48-74`의 `_send`(프로필 없으면 설정, 404면 빈 초안, 그 밖의 오류는 알림)와 `_IntakeBox` 위젯(입력칸·보내기·직접 입력하기·최근 통화한 곳·예시 템플릿)을 **그대로** 비서 기능으로 옮긴다. 키(`home-intake-field`, `home-intake-send`)와 툴팁·글자를 유지해 기존 테스트가 시작 위치만 바꾸면 되게 한다(plan-audit D2·D3). 최근 통화한 곳 계산은 오늘에도 남으므로 지금 공급자를 둘이 같이 쓴다. 접수 뒤 이동(계획 카드 `extra`로 초안 전달)은 지금과 같다. 단, 셸 밖 경로인 `/assistant` 위에 셸 안 경로를 바로 `push`하면 go_router 오류가 난다(SPEC-SHELL-001 research R1-G). 그래서 **비서에서 여는 화면은 모두 `/assistant`의 자식 경로**로 둔다: `/assistant/plan`(계획 카드), `/assistant/settings`(설정), `/assistant/new`(직접 입력). 같은 화면 위젯을 경로만 하나 더 등록한다. 계획 카드는 R1-G3에서 확인한 방식이고(뒤로 = 비서, [이대로 시작] 뒤 `openTask` = 업무 탭 상세), 설정·직접 입력은 같은 구조라 M2 첫 작업에서 R1 실험 코드에 두 경우를 더해 확인한다(plan-audit 2차 N2). 비서를 닫는 방식(G2)은 입력 문장을 지킬 수 없어 쓰지 않는다.

### A.2 개인정보 경계 (REQ-004, OD-2)

- `listen(onDevice: true)`를 먼저 부른다. `onDeviceUnavailable`이 오면 OD-2 안내를 보이고, [계속]이면 같은 말하기 안에서 한 번만 `onDevice: false`로 다시 부른다.
- 앱은 오디오 바이트를 다루지 않는다(포트에 오디오를 내보내는 메서드가 없음). 콜비 서버로 가는 것은 접수 글뿐이다. 테스트는 `FakeCallsRepository`에 더한 `callLog`로 비서 화면을 연 뒤의 저장소 호출이 `intake` 하나뿐임을 확인한다. 이것은 "음성이 기기를 떠나지 않는다"는 보장이 아니다(REQ-004): 일반 인식이면 OS 제공자가 음성을 처리한다.
- 앱이 배경으로 가면(`AppLifecycleState.paused`·`hidden`) `cancel()`을 부른다. `inactive`는 iOS 권한 창이 떠 있을 때도 생기므로 취소하지 않는다(plan-audit D7, AC-007 (5)).

### A.3 권한 흐름 (REQ-005)

`permission()` 결과로 나눈다(권한 패키지가 마이크·음성 인식 두 권한을 합쳐 판단, 하나라도 거부면 거부): `notDetermined` → 사전 안내 시트(CMP-23) → [계속] → `requestPermission()`. `denied` → 글로 입력 모드 + 안내 한 줄. `permanentlyDenied` → 안내 한 줄 + [설정 열기](`openAppSettings()`). 사전 안내는 사용자가 [계속]을 누르기 전에는 OS 창을 띄우지 않는다(04 DP-7 "권한은 처음 쓸 때 목적 문장과 함께").

### A.4 오늘 화면에서 입력칸 빼기 (REQ-010)

SHELL-001이 과도기로 남긴 입력 상자와 첫 사용 빈 상태를 오늘에서 뺀다. 입력 상자는 A.1대로 비서 글로 입력 모드로 옮기므로, 기존 테스트는 "어디서 시작하는가"만 바뀐다. 바뀌는 블록 전체 목록은 `acceptance.md` AC-016 표다(plan-audit D1·D2에서 `shell_test.dart`의 SHELL-001 블록 셋과 `intake_flow_test.dart`의 여러 블록, `accessibility_test.dart:563`이 더해짐). 오늘에 남는 "최근 통화한 곳"은 누르면 `/assistant?mode=text`를 열고 "{이름}에 "를 채운다. run 시작 시 공통 검증의 grep 결과를 그 표와 대조한다.

### A.5 통화 중 화면 분리 (REQ-011, REQ-012, OD-5)

- 새 화면 `LiveCallScreen`(`/calls/:id/live`)은 지금 통화 상세의 조각을 다시 쓴다: `TranscriptView`(대화), `_CallTimer`(경과 시간 — 지금 `call_detail_screen.dart:421`의 비공개 위젯을 같은 파일 밖으로 꺼냄), 끊기 확인 동작, `ApprovalCard`, 자막 따라가기 스크롤(지금 통화 상세의 방식, 움직임 줄이기 포함). 새로 그리는 것은 다크 머리줄과 말풍선 위 화자 이름뿐이다.
- 승인 카드는 지금 통화 상세의 `_ActionBar` 방식처럼 화면 아래 고정 영역에 둔다(스크롤이 승인을 밀어내지 않음). 그 영역만 밝은 테마로 감싸 SPEC-UX-001 승인 카드 테스트와 같은 조건으로 그린다.
- `/calls/:id/live`는 셸 밖 최상위 경로다(탭 바 가림, R1-E와 같은 구조). 업무 실행 화면의 [통화 보기]에서만 `push`하므로 아래에는 늘 업무 실행 화면이 있다. 통화가 끝나 상태가 `summarizing` 이후로 바뀌면 `pop`으로 닫는다(`pushReplacement`를 쓰면 업무 실행 화면이 두 번 쌓임, plan-audit 2차 D11). 끝난 작업이면 아래 화면이 결과(SCR-T05)를 보이므로 04 §17.6과 같다.
- 승인 알림(`ApprovalListener`): 지금은 현재 경로가 `/calls/:id`와 같을 때만 스낵바를 숨긴다(`approval_listener.dart:30`). `/calls/:id/live`도 같은 작업으로 보고 숨긴다. [답하기]는 SHELL-001 0.3.1의 `openTask`(쌓인 화면을 모두 `pop`한 뒤 `go('/inbox')`+`push`)라서 비서·통화 중 화면이 먼저 닫히고 R1-G 오류가 생기지 않는다(SHELL research Y2, 감사 3차 Z2에서 통화 중 화면 → `openTask` 확인). AC-011 (4)(5)로 확인.
- 업무 실행 화면은 [통화 보기]만 더하고 대화 기록은 접지 않는다(OD-5, plan-audit D10: 접으면 `accessibility_test.dart:189-232`의 자막 따라가기 검사가 깨짐).

### A.6 Orb와 몰입형 다크 (REQ-002, REQ-013)

- `kolbi_ui`의 `KolbiOrb`(이 SPEC이 새로 만든다. SHELL-001은 탭 바 가운데 버튼에 정적 원형 아이콘만 쓴다 — plan-audit SHELL 2차 N8): 대기 = 정지, 듣는 중 = 천천히 커졌다 작아짐, 처리 중 = 표면 빛이 돎, 응답 중 = 일렁임. 움직임은 `AnimationController` 하나로, `MediaQuery.disableAnimations`가 참이면 만들지 않는다.
- 그라데이션은 06 §3.1 색(흰색 → `#E4E2FF` → `#A6ACFF` → `#635BFF` → `#2E2A78`)의 방사형으로, 목업 값을 따른다.
- `KolbiTheme.immersive()`는 SPEC-DESIGN-001이 만든 어두운 색 체계(`AppTheme.dark`의 `ColorScheme`·분위기 짝, 배경 `#11131F`·카드 `#1B1F33`)를 그대로 쓰는 `ThemeData`다(같은 값을 다시 정의하지 않음, plan-audit 2차 D9). AI 비서·통화 중 화면은 이 테마를 `Theme` 위젯으로 감싸 기기 모드와 무관하게 쓴다.

## B. 변경 파일

| 파일 | 변경 | 이유 |
|------|------|------|
| `app/lib/features/assistant/speech/speech_recognizer.dart` | 새 파일 | 포트, 이벤트 타입(REQ-003~007) |
| `app/lib/features/assistant/speech/platform_speech_recognizer.dart` | 새 파일 | 패키지 감싸기 |
| `app/lib/features/assistant/assistant_controller.dart` | 새 파일 | 상태 관리(A.1) |
| `app/lib/features/assistant/request_box.dart` | 새 파일(옮김) | 지금 `_IntakeBox`와 `_send`를 그대로 옮김(A.1) |
| `app/lib/features/assistant/assistant_screen.dart` | 새 파일 | SCR-A01(REQ-001, REQ-008) |
| `app/lib/features/assistant/mic_consent_sheet.dart` | 새 파일 | CMP-23(REQ-005) |
| `app/lib/shell/app_router.dart` | 수정 | `/assistant`를 비서 화면으로, 자식 경로 `plan`·`settings`·`new`, 셸 밖 `/calls/:id/live` 추가 |
| `app/lib/features/calls/presentation/approval_listener.dart` | 수정(한 곳) | 통화 중 화면에서도 같은 작업 알림 숨김(`:30`) |
| `app/lib/shell/routes.dart` | 수정 | `liveCall` 경로 이름 |
| `app/lib/shell/assistant_placeholder.dart` | 삭제 | SHELL-001 임시 화면 |
| `app/lib/features/calls/presentation/home_screen.dart` | 수정 | 입력 상자·첫 사용 빈 상태 빼기, 최근 통화한 곳·바로가기를 비서로 연결(REQ-010) |
| `app/lib/features/calls/presentation/live_call_screen.dart` | 새 파일 | SCR-T08(REQ-011) |
| `app/lib/features/calls/presentation/call_detail_screen.dart` | 수정 | [통화 보기], `_CallTimer` 꺼내기(REQ-012) |
| `app/lib/features/calls/presentation/widgets/call_timer.dart` | 새 파일(꺼냄) | 두 화면 공용 |
| `packages/kolbi_ui/lib/src/widgets/orb.dart` | 수정 또는 새 파일 | 상태 움직임(REQ-002, REQ-013) |
| `packages/kolbi_ui/lib/src/theme/immersive_theme.dart` | 새 파일 | 몰입형 다크(REQ-001, REQ-011) |
| `packages/kolbi_ui/lib/kolbi_ui.dart` | 수정 | 공개 |
| `packages/kolbi_ui/test/orb_test.dart` | 새 파일 | 상태·움직임 줄이기 |
| `app/pubspec.yaml` | 수정 | `speech_to_text`, 권한 패키지 |
| `app/ios/Runner/Info.plist` | 수정 | 권한 문구 두 개 |
| `app/ios/Podfile` | 생성 후 커밋(필요 시 — 지금 저장소에 없음, `flutter build ios` 때 생김) | 권한 패키지가 쓰는 권한만 켜는 설정(마이크, 음성 인식) — M1에서 패키지 문서로 필요 여부 확인(plan-audit 2차 D10) |
| `app/android/app/src/main/AndroidManifest.xml` | 수정 | `RECORD_AUDIO`, 기존 `<queries>`에 `android.speech.RecognitionService` |
| `app/test/support/fake_speech_recognizer.dart` | 새 파일 | 가짜 인식기 |
| `app/test/support/fakes.dart` | 수정(더하기만) | `intakeHold`, `callLog`(AC-016) |
| `app/test/assistant_test.dart` | 새 파일 | 비서 화면·받아쓰기·권한·오류·멈춤 |
| `app/test/live_call_test.dart` | 새 파일 | 통화 중 화면·전환 |
| `app/test/architecture_test.dart` | 수정 | `kolbi_ui`·`kolbi_core`가 음성 인식 패키지를 가져오지 않음 |
| `app/test/intake_flow_test.dart`, `approval_flow_test.dart`, `accessibility_test.dart`, `shell_test.dart`, `today_test.dart`, `inbox_test.dart` | 수정(이름 적은 블록) | AC-016 표 |

약 30개 파일. 새 로직은 포트·상태 관리·두 화면·Orb이고 나머지는 연결·선언·한 줄 수정이다.

## C. 마일스톤 (우선순위 순, 하나씩 순서대로)

### M1 — 패키지 확인과 받아쓰기 포트 (Priority High)

패키지 확인 결과를 `progress.md`에 기록: `speech_to_text`(plan-audit에서 확인한 7.5.0·BSD-3-Clause·`onDevice` 기본 false 재확인, 최소 iOS 버전 — 앱은 iOS 15.0), 권한 패키지(버전·라이선스·마이크/음성 인식 권한·설정 열기), 한국어 로케일 ID, 실제 기기의 기기 안 한국어 지원과 실패 오류 코드, Flutter 3.50.1 테스트의 접근성 알림 기록 API. 포트·이벤트 타입·가짜 인식기·실제 구현, 권한 선언. AC-004(포트 부분), AC-013.

### M2 — 비서 상태 관리와 화면 (Priority High)

`AssistantController`(RED 먼저), `submitIntake` 꺼내기, 비서 화면, 사전 안내 시트, 글로 입력. AC-001, AC-003, AC-005~AC-008.

### M3 — Orb 움직임과 몰입형 다크 (Priority High)

`KolbiOrb` 상태 움직임, 움직임 줄이기, `KolbiTheme.immersive()`, 상태 알림. AC-002, AC-014(비서 화면).

### M4 — 진입점과 오늘 화면 (Priority Medium)

바로가기·최근 통화한 곳 연결, 오늘에서 입력 상자·빈 상태 빼기, 이름 적은 기존 테스트 수정. AC-009, AC-010, AC-016.

### M5 — 통화 중 화면 (Priority Medium)

`LiveCallScreen`, `/calls/:id/live`, 업무 실행 화면의 [통화 보기], 끝나면 전환. AC-011, AC-012, AC-014(통화 중).

### M6 — 구조 규칙과 회귀 (Priority Low)

의존 규칙 테스트, 접근성 지침, 전체 회귀, 서버 불변 확인. AC-013~AC-016.

## D. 위험 요소

| 위험 | 대응 |
|---|---|
| 기기 안 한국어 인식이 기기에 없음(언어 팩) | 먼저 시도하고 `onDeviceUnavailable`이면 한 번만 일반 인식으로(REQ-006), 두 번째 실패는 글로 입력 |
| `speech_to_text`가 권한 상태·설정 열기를 지원하지 않음(확인됨) | 권한 패키지를 함께 씀(spec §4) |
| iOS 음성 인식이 기기 밖 처리를 할 수 있음 | `onDeviceOnly`를 기본으로 켜고, 불가 기기는 OD-2 문구로 알림. 법률 검토 항목에 추가 |
| 화면을 닫았는데 인식기가 늦게 이벤트를 보냄 | 컨트롤러가 닫힌 뒤 이벤트를 무시하고 `cancel()`을 두 번 불러도 안전하게(AC-007) |
| 오늘에서 입력칸을 빼며 예상보다 많은 기존 테스트가 깨짐 | A.4 표 + run 시작 grep, 표 밖이면 소유자 확인 후 AC-016에 더함 |
| 다크 화면에서 승인 시트(밝은)의 대비 혼동 | 승인 시트는 밝은 테마로 감싸 SPEC-UX-001 승인 카드 테스트와 같은 조건에서 그려짐 |
| 시뮬레이터·에뮬레이터에서 실제 인식이 안 됨 | 위젯 테스트는 가짜만 씀. 실제 기기 확인은 소유자와 함께 별도로(완료 정의에 수동 확인 1건) |

## E. 하네스·복잡도 지표

| 지표 | 값 |
|---|---|
| Tier | M(약 30개 파일) |
| REQ / AC | 16 / 16 |
| 권장 하네스 | standard |
| 방법론 | TDD(포트·컨트롤러·새 화면은 테스트 먼저), 기존 흐름은 기존 테스트로 보존 |
| 모드 | serial |

## F. 자체 검증

run 단계 완료 보고는 다음을 원문 출력과 함께 담는다: AC별 PASS/FAIL 표와 명령, `cd app && flutter --suppress-analytics test` 마지막 줄, `flutter test`(kolbi_ui), `flutter analyze`, `git diff --stat <run_start_sha> -- server/`(비어 있음), `git diff <run_start_sha> -- app/test/`(AC-016 표의 블록만), 패키지 확인 기록(M1), 권한 선언 diff, 서식을 적용한 파일 목록.

## G. sync-phase 문서 항목

- `.moai/project/structure.md`: `features/assistant`, 경로 `/assistant`·`/calls/:id/live`.
- `docs/planning/06_DESIGN_DECISIONS.md` §7 Q-3: 받아쓰기 방식 확정 내용.
- `docs/product/10_PRODUCT_PLAN.md` 가정 A-7: 확인 결과.
- `README.md`: 말로 부탁하기 한 단락, 권한 설명.
