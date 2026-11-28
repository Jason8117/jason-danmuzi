# SPEC-ASSIST-001 인수 기준 (0.3.1)

## 공통 검증 명령

앱(작업 디렉터리 `app/`):

```bash
flutter --suppress-analytics test test/assistant_test.dart test/live_call_test.dart test/architecture_test.dart
flutter --suppress-analytics test
flutter --suppress-analytics analyze
```

패키지:

```bash
(cd packages/kolbi_ui && flutter --suppress-analytics test)
```

변경 범위(저장소 루트):

```bash
git diff --stat <run_start_sha> -- server/
git diff <run_start_sha> -- app/test/
```

기준선: SPEC-SHELL-001이 `completed`된 상태에서 시작한다. run-phase 시작 시 manager-develop이 `run_start_sha`와 위 명령 결과, 그리고 `grep -rn "home-intake\|귀찮은 전화\|byTooltip('보내기')\|직접 입력하기" app/test` 결과를 `progress.md` §E.2 첫 부분에 기록한다(AC-016 목록과 대조).

공통 준비: 위젯 테스트는 기존 방식(`app/test/support/fakes.dart`의 `FakeCallsRepository`, `SharedPreferences` 대역, `ProviderScope` 재정의)으로 앱 전체를 띄운다. 음성 인식은 `FakeSpeechRecognizer`(권한 상태, 흘려보낼 이벤트 목록, 기기 안 인식 실패 여부를 테스트가 정함; `listen`(인자 포함)·`stop`·`cancel`·`requestPermission` 호출을 기록)로 바꾼다. 기본 가짜 = 권한 허용, 기기 안 인식 성공. `FakeCallsRepository`에는 이 SPEC이 두 가지를 더한다(기존 줄은 바꾸지 않음, AC-016): `intakeHold`(설정되면 `intake`가 이를 기다림)와 `callLog`(가짜가 재정의한 모든 메서드 — `create`, `intake`, `list`, `approvePlan`, `serverInfo`, `decide`, 그리고 이 SPEC이 새로 재정의하는 `cancel`(통화 끊기 포함)·`delete`, 이미 재정의된 `openLiveChannel`(`fakes.dart:158`) — 의 이름을 순서대로 기록). 가짜 인식기를 넣지 않은 테스트(기존 테스트 포함)에서는 음성 인식 플러그인이 없으므로 비서가 글로 입력 모드로 열린다(REQ-003, REQ-008). 작업 묶음 "섞음"은 SPEC-SHELL-001 acceptance와 같다.

규칙: 사진 비교 테스트를 쓰지 않는다. 테스트 먼저(RED) → 구현(GREEN). 서식은 이 SPEC이 만들거나 고친 파일에만.

## AC-001 — AI 비서 화면 구성 (REQ-001)

- **Given** 밝은 모드 기기에서 앱을 띄움
- **When** 가운데 "비서 부르기"를 누르고, 예시 칩 첫째를 누르면
- **Then** 누른 직후 "AI 비서", 상태 칩, Orb(`Key('assistant-orb')`), "무엇을 도와드릴까요?", "말씀해 주시면 제가 대신 처리할게요.", "이렇게 부탁해 보세요", 예시 칩 두 개(글자가 `callTemplates`의 첫째·둘째 라벨), 아래 조작 줄의 세 버튼이 이 순서로 위에서 아래에 있다(세로 위치 비교). 화면 바탕색이 `#11131F`다. 예시 칩을 누르면 글로 입력 모드가 되고 입력칸(`Key('home-intake-field')`) 글자가 `callTemplates.first.goal`이며 `intake` 호출 수는 0이다. SHELL-001의 임시 화면 파일이 없다(`test ! -f app/lib/shell/assistant_placeholder.dart`)
- 테스트: `app/test/assistant_test.dart` — "assistant screen follows the immersive layout"

## AC-002 — Orb 상태와 움직임 줄이기 (REQ-002)

- **Given** (1) 가짜 인식기가 `partial("오늘")` 뒤 `finalResult("오늘 저녁 7시 예약해 줘")`를 보냄, 가짜 저장소 `intakeHold`가 설정됨 (2) 같은 조건 + `MediaQuery(disableAnimations: true)`
- **When** 비서 화면을 연다
- **Then** (1) 칩 글자가 "듣고 있어요" → "처리하고 있어요"로 바뀌고(`intakeHold`를 풀기 전), 각 바뀜마다 정중한 수준의 접근성 알림이 한 번씩 있다(테스트 바인딩의 알림 기록. Flutter 3.50.1에서 알림 기록 API 이름은 M3 첫 작업에서 확인해 progress.md에 적음). Orb는 의미 트리에 없다(`ExcludeSemantics`) (2) 같은 칩 변화가 있고, Orb 하위 트리에 애니메이션 위젯이 없다(`find.descendant(of: find.byKey(Key('assistant-orb')), matching: find.byType(AnimatedBuilder))`가 없음 — 화면의 다른 진행 표시와 섞이지 않게 Orb로 범위를 좁힘). `kolbi_ui` 단위 테스트는 네 상태(대기·듣는 중·처리 중·응답 중)마다 Orb가 오류 없이 그려지고, 움직임 줄이기에서 애니메이션 컨트롤러를 만들지 않음을 확인한다
- 테스트: `assistant_test.dart` — "orb state is shown in words and announced", `packages/kolbi_ui/test/orb_test.dart`

## AC-003 — 받아쓰기에서 계획 카드까지 (REQ-003)

- **Given** 가짜 인식기 이벤트 `partial("금요일")`, `partial("금요일 7시 2명")`, `finalResult("금요일 7시 2명 라 파스타 예약해 줘")`, 가짜 저장소 `intake`는 번호가 있는 초안을 돌려줌
- **When** 비서 화면을 열면(권한 허용 상태)
- **Then** 화면을 연 직후 `listen`이 한국어 로케일(M1에서 확정한 ID, progress.md 기록)과 `partialResults: true`로 한 번 불리고, 받아쓰기 자리에 "금요일" → "금요일 7시 2명"이 차례로 보이며, 최종 결과 뒤 `intake`가 최종 문장 그대로 한 번 불리고, 계획 카드가 `/assistant/plan`으로 비서 위에 열린다(계획 카드의 부탁 글자 확인, 탭 바가 보이지 않음, 시스템 뒤로 가기 하면 비서 화면). `intakeError`가 404인 가짜 저장소에서는 지금과 같은 대체 동작(문장을 목표로 한 계획 카드)이 일어난다. 별도로, 가짜 인식기를 넣지 않고 앱을 띄워 비서를 열면 글로 입력 모드(`Key('home-intake-field')`)로 열리고 예외가 없다(`tester.takeException()`이 `null`)
- 테스트: `assistant_test.dart` — "dictation fills the request and opens the plan card", "an older server keeps the blank-plan fallback"

## AC-004 — 앱은 음성을 다루지 않고 글만 보냄 (REQ-004)

- **Given** AC-003의 조건
- **When** 받아쓰기 흐름을 끝까지 진행하면
- **Then** 가짜 저장소 `callLog`에서 비서 화면을 연 뒤 기록된 항목이 `intake` 하나뿐이고(앱 시작 때의 `list`·`serverInfo`는 화면을 열기 전에 기록되므로 비교에서 뺌), 첫 `listen`은 `onDevice: true`로 불린다. 받아쓰기 포트에는 오디오 바이트를 돌려주는 멤버가 없다(`grep -nE "Uint8List|List<int>" app/lib/features/assistant/speech/speech_recognizer.dart` 출력 없음). 비서 기능 소스에 오디오 파일 쓰기가 없다(`grep -rnE "\.wav|\.m4a|\.aac|writeAsBytes" app/lib/features/assistant` 출력 없음). 사전 안내 문구는 "콜비는 음성을 저장하지 않아요"이며 "음성은 저장하지 않아요"처럼 제공자 처리까지 부정하는 문구가 없다
- 테스트: `assistant_test.dart` — "only the final text reaches Kolbi"

## AC-005 — 마이크 권한 흐름 (REQ-005)

- **Given** 가짜 권한 상태 (1) 묻지 않음 (2) 묻지 않음이고 요청 결과 거부 (3) 다시 묻지 않음으로 거부
- **When** 비서 화면을 열면
- **Then** (1) "말로 부탁하면 제가 글로 받아 적어요. 콜비는 음성을 저장하지 않아요."와 [계속]이 보이고, [계속]을 누르기 전에는 `requestPermission` 호출 수가 0이며, 누른 뒤 1이 되고(마이크·음성 인식 두 권한을 한 번의 흐름에서 요청) 허용되면 듣기 시작한다 (2) [계속] 뒤 글로 입력 모드(`Key('home-intake-field')` 보임)와 "마이크 없이도 글로 부탁할 수 있어요"가 보이고 `listen` 호출 수가 0이다 (3) 사전 안내 시트가 없고, 설정에서 켜는 방법 한 줄과 [설정 열기]가 보이며 `requestPermission` 호출 수가 0이고, [설정 열기]를 누르면 가짜의 앱 설정 열기 호출 수가 1이다
- 테스트: `assistant_test.dart` — "microphone permission is asked with a purpose first"

## AC-006 — 인식 실패와 기기 안 인식 대체 (REQ-006)

- **Given** 가짜 인식기 (1) `noSpeech` (2) `error("network")` (3) `finalResult("")` (4) 기기 안 인식 불가 오류 뒤, 일반 인식에서 `finalResult("내일 치과 예약 바꿔 줘")` (5) 기기 안 인식 불가 오류 뒤, 일반 인식에서도 `error("network")`
- **When** 비서 화면을 열면
- **Then** (1)~(3) "잘 못 들었어요. 다시 말하거나 글로 적어 주세요"가 보이고, 칩이 "기다리고 있어요"로 돌아가며, `intake` 호출 수가 0이다 (4) OD-2 안내("이 기기에서는 … 음성 인식 서비스가 말을 글로 바꿔요. 콜비는 음성을 저장하지 않아요.")와 [계속]이 보이고, [계속] 뒤 `listen`이 `onDevice: false`로 한 번 더 불리며, 최종 문장으로 `intake`가 한 번 불린다 (5) 실패 문구와 함께 글로 입력 모드가 되고, `listen` 호출 수는 정확히 2다(되풀이 없음). 화면을 닫았다 다시 열면 자동으로 듣기 시작하지 않는다(`listen` 호출 수 그대로) (6) (4)에서 OD-2 안내의 [글로 입력]을 누르면 `listen`이 더 불리지 않고 글로 입력 모드가 된다. (4)를 한 번 지난 뒤 화면을 닫았다 다시 열고 Orb를 누르면, 기기 안 인식을 다시 시도하지 않고 OD-2 안내도 다시 보이지 않은 채 `onDevice: false`로 듣는다(앱 실행 동안 기억)
- 테스트: `assistant_test.dart` — "recognition failures never loop or send an empty request"
- 편차(OD-2 Android, 소유자 결정 2026-11-28): speech_to_text 7.5.0은 Android에서 기기 안 인식을 쓸 수 없으면 알리지 않고 기본(네트워크) 인식기를 쓰므로(`SpeechToTextPlugin.kt` 620-640) (4)의 이벤트가 Android에서는 오지 않을 수 있다. 그래서 Android는 첫 받아쓰기 전에 "Android에서는 구글 음성 인식 서비스가 말을 글로 바꿀 수 있어요. 콜비는 음성을 저장하지 않아요."를 한 번 보이고(권한을 묻기 전이면 AC-005 목적 안내 안에, 권한이 이미 있으면 [글로 입력]/[계속] 카드로) SharedPreferences `androidSpeechServiceNoticeAcknowledged`에 본 것을 기록한다. 받아쓰기를 막지는 않는다. (1)~(6)은 이벤트가 오는 경우(iOS, 그리고 Android에서 언어 팩 오류가 오는 경우)의 기준으로 그대로 둔다. 테스트: `assistant_test.dart` — "Android shows the speech-service notice once before the first dictation", "iOS does not show the Android notice up front"(flutter_test는 Android로 돌기 때문에 다른 테스트의 기본 `profile`은 이 안내를 본 상태로 둔다)

## AC-007 — 멈춤, 닫기, 배경 전환 (REQ-007)

- **Given** 업무 탭에서 작업 상세를 연 뒤 가운데 버튼으로 비서 화면을 열고, 가짜 인식기가 `partial("오늘 저녁")`까지 보낸 상태
- **When** (1) [그만하기] (2) 닫기 (3) 시스템 뒤로 가기 (4) 생명주기를 `paused`로 바꿈 (5) 생명주기를 `inactive`로만 바꿨다가 `resumed`로 되돌림 — 각각 새로 띄운 앱에서
- **Then** (1)~(4)는 `cancel`이 한 번 이상 불리고 `intake` 호출 수가 0이며, (1)~(3)은 업무 탭이 선택된 채 같은 작업 상세가 보인다. 닫힌 뒤 가짜 인식기가 늦게 `finalResult`를 보내도 `intake`가 불리지 않고 예외가 없다 (5)는 `cancel`이 불리지 않고 칩이 여전히 "듣고 있어요"다(권한 창이 만드는 `inactive`에서 받아쓰기가 끊기지 않음)
- 테스트: `assistant_test.dart` — "stopping or leaving cancels dictation; inactive does not"

## AC-008 — 글로 입력 모드 (REQ-008)

- **Given** (1) 가짜 인식기가 `partial("내일 치과")`까지 보낸 상태 (2) 끝난 작업 셋(최근 통화한 곳이 계산됨)으로 `/assistant?mode=text`를 엶
- **When** (1) [글로 입력]을 누르고 입력칸 끝에 " 예약 바꿔 줘"를 더해 "보내기"를 누름 (2) 화면을 봄
- **Then** (1) [글로 입력]을 누르자 `cancel`이 불리고, 입력칸에 "내일 치과"가 채워져 있으며, Orb 크기가 처음보다 작고(`tester.getSize` 비교), 보내기 뒤 `intake`가 "내일 치과 예약 바꿔 줘"로 한 번 불리고 계획 카드가 열린다 (2) 입력칸(`Key('home-intake-field')`), 툴팁 "보내기" 버튼, [직접 입력하기], "최근 통화한 곳"과 칩, "이런 부탁도 할 수 있어요"와 템플릿 칩이 있고, 상태 칩·"이렇게 부탁해 보세요"·아래 조작 줄은 없다. "무엇을 도와드릴까요?"(입력칸 힌트)와 "식당 예약"(템플릿 칩)은 각각 `findsOneWidget`이다. [직접 입력하기]는 `/assistant/new`로 직접 입력 화면을 비서 위에 열고, 뒤로 가면 비서로 돌아온다. 작업 목록 불러오기가 실패하는 가짜 저장소에서는 "최근 통화한 곳" 묶음만 없고 나머지는 같다
- 테스트: `assistant_test.dart` — "text mode carries the whole request box"

## AC-009 — 프로필 없음과 접수 오류 (REQ-009)

- **Given** (1) 프로필이 없는 설정 (2) `intakeError`가 500 `ApiException`인 가짜 저장소
- **When** 글로 입력 모드에서 "내일 치과 예약"을 보내면
- **Then** (1) 설정 화면이 `/assistant/settings`로 비서 위에 열리고(탭 바 없음, 예외 없음), 뒤로 가면 AI 비서 화면 글로 입력 모드에 "내일 치과 예약"이 그대로 있으며 `intake` 호출 수는 0이다 (2) 오류 알림 글자(`describeError` 결과)가 보이고, 계획 카드가 열리지 않으며, 입력 문장이 그대로 있다
- 테스트: `assistant_test.dart` — "missing profile and intake errors keep the request"

## AC-010 — 오늘 화면 정리와 진입점 (REQ-010)

- **Given** (1) 작업 "섞음" + 최근 통화한 곳이 계산되는 끝난 작업 (2) 작업 0개
- **When** 오늘을 보고, (1)에서 "최근 통화한 곳" 첫 칩·바로가기 "전화 대신하기"·"정보 찾아보기"를 각각 누르면(각각 새로 띄운 앱에서)
- **Then** 두 경우 모두 `Key('home-intake-field')`, 툴팁 "보내기", [직접 입력하기], "이런 부탁도 할 수 있어요"가 없다. (1) 브리핑 카드, 비서에게 부탁하기 바로가기, "확인이 필요해요", "진행 중", "최근 통화한 곳"이 이 순서로 있고, 최근 칩을 누르면 AI 비서가 글로 입력 모드로 열리며 입력칸이 "{이름}에 "이다. 바로가기 둘은 AI 비서를 연다 (2) "귀찮은 전화, 대신 걸어드릴게요"가 없고, 브리핑 카드에 "오늘은 맡긴 일이 없어요."와 "가운데 버튼으로 부탁해 보세요."가 보인다. 툴팁 "설정" 버튼은 그대로 있다
- 테스트: `assistant_test.dart` — "today hands requests to the assistant"

## AC-011 — 통화 중 화면 (REQ-011)

- **Given** (1) 통화 중(`inProgress`) 작업, 대화 기록 22줄(콜비·상대 번갈아), 800×600 화면 (2) 같은 작업에 `pending` 승인 1개 (3) (1)의 작업이 `summarizing`으로 바뀌는 갱신 이벤트
- **When** 업무 상세(`/calls/<id>`)의 [통화 보기]를 눌러 `/calls/<id>/live`를 열고(plan-audit 3차 N13), (3)은 열린 상태에서 이벤트를 보내면
- **Then** (1) 바탕이 `#11131F`이고, [통화 끊기], "통화 중", 상대 이름, 부탁 요약이 보이며, 각 말풍선 위에 "콜비" 또는 상대 이름이 있고, 자막 목록이 끝까지 내려가 있으며(움직임 줄이기에서도), "실시간 자막 · 통화는 글로 기록돼요"가 보인다. [통화 끊기]를 누르면 지금과 같은 확인 창이 뜬다 (2) 화면 아래 승인 카드(지금 `ApprovalCard`의 질문 글자)가 밝은 바탕으로 보이고, [승인]을 누르면 가짜 저장소의 `decisions`가 하나 늘어난다 (3) 통화 중 화면이 닫혀(`pop`) 아래의 업무 실행 화면(`Key('task-steps')`)이 보이고, 뒤로 가기 하면 업무 첫 화면(`Key('tasks-screen')`)이다(업무 실행 화면이 두 번 쌓이지 않음) (4) (2)의 상태에서 가짜 실시간 채널로 같은 작업의 **새 승인 id**(앱 시작 때 알린 승인과 다른 id — `ApprovalListener`는 한 번 알린 id를 다시 알리지 않으므로, `approval_listener.dart:22-26`)를 보내도 `ApprovalListener` 스낵바(`find.byType(SnackBar)`)가 없다(`:30`의 숨김 조건이 `/calls/<id>/live`에도 맞아야 통과, plan-audit 3차 N8). 다른 작업 "헤어살롱 봄"의 승인이 오면 스낵바가 뜨고, [답하기]를 누르면 `tab-tasks`가 선택된 채 그 작업 상세가 열리며 예외가 없다 (5) AI 비서를 연 채로 다른 작업의 승인 스낵바 [답하기]를 누르면 비서가 닫히고 같은 결과다
- 테스트: `app/test/live_call_test.dart` — "live call screen shows captions, hang-up and approvals", "finishing the call returns to the task screen", "approval alerts from the live and assistant screens"

## AC-012 — 업무 실행 화면의 통화 보기 (REQ-012)

- **Given** (1) 통화 중 작업, 대화 6줄 (2) 끝난 작업
- **When** 업무 실행 화면(`/calls/<id>`)을 보면
- **Then** (1) [통화 보기](`Key('open-live-call')`)가 있고 누르면 통화 중 화면이 열린다. 대화 6줄이 모두 지금처럼 보이고(접지 않음), 하단 고정 승인 카드 동작은 SPEC-UX-001 테스트대로다 (2) [통화 보기]가 없다. 같은 승인을 T02에서 응답한 뒤 T08을 열면 승인 카드가 없다(가짜 저장소가 돌려준 상태 기준)
- 테스트: `live_call_test.dart` — "task screen links to the live call"

## AC-013 — 구조 경계 (REQ-013)

- **Given** 이 SPEC의 변경 뒤
- **When** 의존 규칙 테스트를 실행하고 소스를 검색하면
- **Then** `packages/kolbi_ui/lib`과 `packages/kolbi_core/lib`에 `speech_to_text`·권한 패키지 import가 없고, 두 패키지 import는 `app/lib/features/assistant/speech/` 안에만 있다. Orb 위젯 생성자는 상태 값(과 크기·스타일)만 받는다. 기능 간 import 허용 목록은 비어 있다
- 테스트: `architecture_test.dart` — "speech and permission packages stay inside the assistant feature"

## AC-014 — 접근성 (REQ-014)

- **Given** AI 비서 화면(대기·듣는 중·글로 입력)과 통화 중 화면(승인 있음)
- **When** `meetsGuideline(androidTapTargetGuideline)`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline`을 검사하고, 360×640·`TextScaler.linear(2.0)`으로 띄우면
- **Then** 모든 지침 검사가 통과하고, 넘침 오류가 없으며(`tester.takeException()`이 `null`), 아래 조작 줄의 세 버튼 읽기 문구가 "글로 입력하기", "말하기 끝내고 보내기", "그만하기"이고, 통화 중 화면의 [승인]은 스크롤로 닿아 누를 수 있다. 받아쓰기 중간 문장이 바뀌어도 접근성 알림 수가 늘지 않고, 보낼 때 최종 문장으로 한 번 알린다
- 테스트: `assistant_test.dart`·`live_call_test.dart` — "immersive screens meet the accessibility guidelines"

## AC-015 — 기존 흐름 유지 (REQ-015)

- **Given** 이 SPEC의 변경 뒤
- **When** 기존 테스트 파일 `approval_card_test.dart`, `plan_card_test.dart`, `follow_up_test.dart`, `trust_notice_test.dart`, `outcome_card_test.dart`, `calls_controller_test.dart`, `unit_test.dart`, `theme_test.dart`, 그리고 SPEC-SHELL-001이 만든 `history_test.dart`, SPEC-DESIGN-001이 만든 `font_overflow_test.dart`를 실행하면
- **Then** 모두 수정 없이 통과한다(`git diff --stat <run_start_sha> -- app/test/`에 이 파일들이 없음). AC-016의 파일들은 이름 적은 블록만 바뀐 채 통과한다. 단 `font_overflow_test.dart`는 AC-016 표 확장 행(소유자 결정 2026-11-28)의 표식 한 줄만 바뀐 채 통과한다
- 확인: 위 diff 원문을 `progress.md`에 기록

## AC-016 — 서버 불변과 의도한 테스트 변경 (REQ-016)

- **Given** run 시작 시점
- **When** run 끝에 공통 검증 명령의 변경 범위 명령을 실행하면
- **Then** `server/` 변경이 없다. 기존 테스트에서 바뀐 곳은 다음뿐이다. 각 항목은 "부탁 시작 위치가 오늘 → AI 비서(글로 입력 모드)로 바뀜"과 "첫 사용 빈 상태가 브리핑 빈 문구로 바뀜" 두 가지 이유만으로 바뀌며, 접수 뒤 단언(초안·계획 카드·대체 동작·오류 알림)은 그대로다.

  | 파일 | 블록(테스트 이름 · 현재 줄) | 바뀌는 내용 |
  |---|---|---|
  | `test/support/fakes.dart` | `FakeCallsRepository` | 더하기만: `intakeHold`, `callLog`(기존 줄 무변경) |
  | `intake_flow_test.dart` | 홈을 띄우는 도우미(`pumpHome`, 파일 위쪽) | 앱을 띄운 뒤 `/assistant?mode=text`로 들어가게 바꿈 |
  | `intake_flow_test.dart` | "home sends one line to intake" (:67, :70-73) | 위치 단언이 오늘이면 AI 비서로 |
  | `intake_flow_test.dart` | "…without a name it opens settings first" (:90-102) | 설정에서 돌아온 곳이 AI 비서 글로 입력 모드(문장 유지 단언은 그대로) |
  | `intake_flow_test.dart` | "…the manual form stays reachable" (:104) | [직접 입력하기]를 AI 비서 글로 입력 모드에서 누름 |
  | `intake_flow_test.dart` | "suggests recent counterparties and templates" (:113-146) | `find.text('피자집')`(:138, 진행 중 작업이 오늘 화면에 보임) 단언 한 줄 제거 — 테스트가 비서 글로 입력 모드에서 시작해 오늘이 보이지 않음. 최근 통화한 곳·템플릿 채우기 단언(:124-146)은 그대로 |
  | `intake_flow_test.dart` | "suggests recent counterparties and templates: no tasks yet" (:148, :151) | "귀찮은 전화…" 단언(:151) 한 줄 제거 — 테스트가 비서에서 시작해 오늘이 보이지 않음. 첫 사용 빈 문구는 SHELL-001 AC-010 (2)와 `approval_flow_test.dart:36-37`이 이미 확인함(plan-audit 3차 N9). 템플릿 채우기 단언은 AI 비서에서 그대로 |
  | `intake_flow_test.dart` | "…other errors stay home" (:178-189) | "오늘에 머묾" → "AI 비서에 머묾"(알림·문장 유지 단언은 그대로) |
  | `intake_flow_test.dart` | "the manual form never auto-starts" (:192, :196) | [직접 입력하기] 누르는 위치 |
  | `approval_flow_test.dart` | :36-37 | 첫 사용 빈 상태 단언 → 브리핑 빈 문구 |
  | `accessibility_test.dart` | :341-343 빈 상태 검사 | 같음 |
  | `accessibility_test.dart` | :563 `byTooltip('보내기')` | 오늘이 아니라 AI 비서 글로 입력 모드에서 찾음 |
  | `accessibility_test.dart` | 홈 순서 블록(SHELL-001이 고친 것) | 입력칸·예시 칩 항목 제거 |
  | `shell_test.dart`(SHELL-001 0.3.0) | "centre button opens the assistant over the current tab"(SHELL AC-006) | (1)은 무변경(가짜 인식기 없이 열면 글로 입력 모드라 입력칸이 보임). (2)는 "임시 화면이 닫히고 업무 탭 위에 계획 카드" → "계획 카드가 `/assistant/plan`으로 비서 위에 열리고, 뒤로 가면 비서, 비서를 닫으면 업무 탭의 같은 상세" |
  | `shell_test.dart`(SHELL-001 0.3.0) | "opening a task switches to the tasks tab"(SHELL AC-005) | 무변경. (4)의 계획 카드는 테스트가 `routerProvider.push('/plan', extra:)`로 열므로 오늘 화면의 입력칸과 무관 |
  | `today_test.dart`(SHELL-001 0.3.0) | "today follows the dashboard order"(SHELL AC-015) | 입력칸·예시 칩·"보내기"·"귀찮은 전화…" 단언 제거, 브리핑 빈 문구 |
  | `today_test.dart`(SHELL-001 0.3.0) | "today shortcuts"(SHELL AC-016) | 바로가기가 임시 화면이 아니라 AI 비서를 엶 |
  | `inbox_test.dart`(SHELL-001 0.3.0) | "empty and error states"(SHELL AC-012) (1) | [비서에게 맡기기]가 AI 비서를 엶 |
  | `font_overflow_test.dart`(SPEC-DESIGN-001) | "home fits a 360x640 phone at 2x text with the real font"(`:73`) | 홈 글꼴 확인 표식 `find.text('직접 입력하기')` → `find.text('전화 대신하기')`(REQ-010 뒤에도 오늘에 남는 바로가기)와 이유 주석 한 줄. 원인: REQ-010 — 오늘 화면에서 [직접 입력하기]가 빠져 `scrollUntilVisible`이 `Bad state: No element`. 검사 의도(홈, 360×640, 2배 글자, 실제 Pretendard)는 그대로. 소유자 결정 2026-11-28 |

  표 확장(소유자 결정 2026-11-28): 위 표의 마지막 행(`font_overflow_test.dart`)은 run M4에서 REQ-010을 구현하자 원래 표 밖의 이 블록이 깨져, 아래 문단의 절차대로 소유자 확인을 받아 더한 것이다. 이 확장에 따라 AC-015의 "수정 없이" 목록 가운데 `font_overflow_test.dart`는 이 행만 바뀐 채 통과하면 된다. 깨짐 기록과 결과(`+130` 통과)는 `progress.md` §E.2 "실행 상태 — M4 커밋 전에 멈춤"에 있다.

  줄 번호는 plan-phase(HEAD c2e732d) 기준이며 SHELL-001 run 뒤 달라질 수 있다. run 시작 시 공통 검증의 grep 결과와 이 표를 대조하고, 표 밖에서 깨지는 블록이 있으면 고치기 전에 소유자 확인을 받아 이 표에 더한다. `flutter test` 전체가 통과하고 테스트 수가 SPEC-SHELL-001 완료 시점보다 줄지 않는다
- 확인: `git diff` 원문을 `progress.md`에 기록

## 엣지 케이스

- 받아쓰기 중 전화가 오거나 다른 앱이 마이크를 가져감: 인식기 오류로 들어오며 AC-006과 같이 처리한다.
- 비서 화면을 연 채로 승인 알림이 옴: 지금의 `ApprovalListener` 동작(스낵바·이동)을 따른다. 이동하면 받아쓰기는 AC-007처럼 취소된다.
- 큰 글자 2.0에서 받아쓰기 문장이 길어지면 문장 자리가 스크롤되고 아래 조작 줄은 고정이다.
- 기기 언어가 영어여도 받아쓰기 언어는 한국어다(화면 한국어, 03 F-SET-04).
- 기기에 한국어 인식 언어가 아예 없음(`locales()`에 한국어 없음): 화면을 열면 글로 입력 모드로 시작하고 "이 기기에서는 말로 부탁하기를 쓸 수 없어요"를 보인다(자동 듣기 없음).

## 잔여 위험

- 실제 기기의 인식 품질과 기기 안 한국어 지원 범위는 위젯 테스트로 확인할 수 없다. 완료 정의에 소유자 기기 수동 확인을 둔다.
- 일반 인식으로 넘어가는 경우의 고지 문구(OD-2)는 법률 검토 결과로 바뀔 수 있다.
- 통화 중 화면은 실시간 이벤트 빈도에 따라 대화가 많이 쌓인다. 긴 통화의 스크롤 성능은 이번 범위에서 측정하지 않는다.

## 완료 정의 (Definition of Done)

- [ ] AC-001 ~ AC-016 모두 PASS, 명령 원문과 출력이 `progress.md` §E.2에 있음
- [ ] 의도한 기존 테스트 변경은 AC-016 표의 행뿐(소유자 결정 2026-11-28로 더한 `font_overflow_test.dart` 한 행 포함)
- [ ] `server/` 무변경
- [ ] M1 패키지 확인 기록(버전, 라이선스, 로케일 ID, 기기 안 한국어 지원, 권한 패키지)과 권한 선언 diff가 `progress.md`에 있음
- [ ] 소유자 실제 기기(iOS 또는 Android 한 대)에서 말로 부탁 → 계획 카드까지 한 번 확인한 기록
- [ ] 서식은 변경 파일에만 적용
- [ ] sync-phase 문서 항목(`plan.md` §G) 목록이 manager-docs에 넘겨짐
