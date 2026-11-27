# SPEC-SHELL-001 인수 기준 (0.3.1)

## 공통 검증 명령

앱(작업 디렉터리 `app/`):

```bash
flutter --suppress-analytics test test/shell_test.dart test/inbox_test.dart test/history_test.dart test/today_test.dart test/architecture_test.dart
flutter --suppress-analytics test
flutter --suppress-analytics analyze
```

패키지:

```bash
(cd packages/kolbi_core && dart test)
(cd packages/kolbi_ui && flutter --suppress-analytics test)
```

변경 범위(저장소 루트):

```bash
git diff --stat <run_start_sha> -- server/
git diff <run_start_sha> -- app/test/
grep -rn "지난 통화\|home-intake\|최근 통화한 곳\|'CallMate'\|'기록'\|'내 정보'\|'설정'" app/test
```

기준선: SPEC-MODULE-001과 SPEC-DESIGN-001이 `completed`된 상태에서 시작한다. run-phase 시작 시 manager-develop이 `run_start_sha`와 위 명령 결과를 `progress.md` §E.2 첫 부분에 기록하고, 마지막 grep 결과를 `research.md` R2 표와 대조한다.

공통 준비: 위젯 테스트는 기존 방식(`app/test/support/fakes.dart`의 `FakeCallsRepository`, `taskJson`, `approvalJson`, `SharedPreferences` 대역, `ProviderScope` 재정의)으로 앱 전체(`CallMateApp`)를 띄운다. 시계는 2026-11-26 12:00(아시아/서울)로 주입한다. 표준 작업 묶음 "섞음"은 상대 이름을 모두 다르게 둔다:

| 작업 | 상대 이름 | 상태 | 그 밖 |
|---|---|---|---|
| a | 라 파스타 | `in_progress` | `pending` 승인 1개(만료 60초 뒤), 대화 2줄 |
| b | 우리동네 치과 | `awaiting_approval` | — |
| c | 헤어살롱 봄 | `in_progress` | 대기 승인 없음, 대화 2줄 |
| d | 관리사무소 | `completed` | 결과 `success`, `updatedAt` `2026-11-26T10:00:00+09:00` |
| e | 행복 소아과 | `failed` | 대화 없음, `updatedAt` `2026-11-25T18:00:00+09:00` |

밝은 모드가 기본이며 어두운 모드는 `MediaQuery(platformBrightness: Brightness.dark)`로 띄운다. 새 테스트는 탭·화면을 글자가 아니라 `Key`(예: `Key('tab-today')`, `Key('tab-tasks')`, `Key('tab-history')`, `Key('tab-me')`, `Key('assistant-button')`, `Key('tasks-screen')`, `Key('history-screen')`)로 찾는다.

규칙: 사진 비교 테스트를 쓰지 않는다. 테스트 먼저(RED) → 구현(GREEN). 서식은 이 SPEC이 만들거나 고친 파일에만.

## AC-001 — 다섯 칸 탭 바 (REQ-001)

- **Given** 작업 "섞음"으로 앱을 띄움
- **When** 첫 화면과 `/plan`(초안 있음)·`/calls/<a>`·`/calls/new`·`/settings`를 각각 `push`한 화면, 그리고 `/assistant`를 본다
- **Then** `/assistant`를 뺀 모든 화면에 탭 바가 있고, 탭 바의 다섯 칸이 `tab-today`·`tab-tasks`·`assistant-button`·`tab-history`·`tab-me` 순서로 왼쪽에서 오른쪽에 있다(가로 위치 비교). 라벨은 "오늘"·"업무"·"비서"·"기록"·"내 정보"다. 첫 화면에서는 `tab-today`가 선택 상태(`isSelected`)이고 라벨 글자색이 `#4F46E5`다. `assistant-button`은 선택 상태 의미가 없고 읽기 문구가 "비서 부르기"다. `/assistant`에서는 탭 바가 화면에 보이지 않는다(`hitTestable` 없음)
- 테스트: `app/test/shell_test.dart` — "tab bar shows four tabs and the centre assistant button"

## AC-002 — 탭 다시 누름 (REQ-002)

- **Given** (1) 업무 탭에서 작업 상세를 연 상태 (2) 끝난 작업 30개로 기록을 아래로 스크롤한 상태
- **When** (1) `tab-tasks` (2) `tab-history`를 누르면
- **Then** (1) 업무 첫 화면(`tasks-screen`)이 보인다 (2) 스크롤 위치가 0이 된다
- 테스트: `shell_test.dart` — "re-tapping the current tab pops to its root, then scrolls to top"

## AC-003 — 업무 배지 (REQ-003)

- **Given** (1) 작업 "섞음"(승인 요청 2개: a, b) (2) 승인 요청 작업 11개 (3) 끝난 작업만 2개
- **When** 각각 앱을 띄우면
- **Then** (1) 배지 글자 "2", 업무 탭 읽기 문구 "업무, 승인 대기 2개" (2) 배지 "9+" (3) 배지 없음, 읽기 문구 "업무". (1)에서 a의 승인을 응답 처리한 갱신 이벤트를 가짜 실시간 채널로 보내면 배지가 "1"로 바뀐다
- 테스트: `shell_test.dart` — "tasks badge counts approval requests"

## AC-004 — 경로 유지와 새 경로 (REQ-004)

- **Given** 앱을 띄움
- **When** `routerProvider`로 `/calls/new`, `/plan`(초안), `/plan`(초안 없음), `/calls/<a>`, `/calls/nope`, `/settings`, `/inbox`, `/history`, `/me`를 차례로 `push`하면(각각 새로 띄운 앱에서)
- **Then** 각 경로가 다음 화면을 보인다: 직접 입력, 계획 카드, 오늘로 되돌림(지금 `app_router.dart:26`의 규칙), 통화 상세, "찾을 수 없음" 빈 상태, 설정 화면, `tasks-screen`, `history-screen`, 내 정보. 앞의 여섯 경로는 `tab-today`가 선택된 채 열린다(research R1-A·D). 그리고 `app/lib/features/` 아래 소스에 경로 문자열 리터럴이 없다(`grep -rnE "'/(calls|plan|settings|inbox|history|me|assistant)" app/lib/features` 출력 없음)
- 테스트: `shell_test.dart` — "legacy and new locations open the expected screens"

## AC-005 — 작업 열기는 업무 탭으로 (REQ-005)

- **Given** (1) 작업 "섞음"의 오늘 (2) 업무 (3) 기록 (4) 오늘에서 연 계획 카드(번호 있는 초안) (5) 업무 상세를 연 뒤 받은 승인 알림이 아닌, 오늘 탭에 있을 때 받은 a의 승인 알림 스낵바
- **When** (1) 오늘의 "라 파스타" 행 (2) 업무의 "헤어살롱 봄" 행 (3) 기록의 "관리사무소" 행 (4) [이대로 시작](가짜 저장소가 새 작업을 돌려줌) (5) 스낵바 [답하기]를 누른 뒤, 각각 시스템 뒤로 가기
- **Then** 다섯 경우 모두 `tab-tasks`가 선택된 채 그 작업의 상세가 보이고, 뒤로 가기 뒤에는 `tasks-screen`이 보인다. (4) 뒤 `tab-today`를 누르면 계획 카드가 아니라 오늘 첫 화면이 보인다(탭 바 누름 = `goBranch`, research R1 X1·Y1). (6) 오늘에서 계획 카드를 열고 그 위에 설정을 연 뒤 설정에서 돌아와 [이대로 시작]을 눌러도 같고, `tab-today`를 누르면 오늘 첫 화면이다 (7) 업무 상세를 연 채 `tab-today` → `tab-tasks`를 누르면 그 상세가 그대로 보이고, `tab-tasks`를 한 번 더 누르면 `tasks-screen`이다(research R1 X2)
- 테스트: `shell_test.dart` — "opening a task switches to the tasks tab"

## AC-006 — 가운데 비서 버튼 (REQ-006)

- **Given** 업무 탭에서 "헤어살롱 봄" 상세를 연 상태
- **When** (1) `assistant-button`을 누르고 닫기를 누름 (2) 다시 열어 임시 화면의 입력칸에 "내일 치과 예약"을 적어 보냄(가짜 저장소가 초안을 돌려줌)
- **Then** (1) 누른 뒤 탭 바가 보이지 않는 화면에 부탁 입력칸이 보이고, 닫은 뒤에는 `tab-tasks`가 선택된 채 같은 상세가 보인다 (2) 임시 화면이 닫히고 계획 카드가 보이며 `tab-tasks`가 선택된 상태다(업무 탭 위에 쌓임, research R1-G2). 테스트 중 예외가 없다(`tester.takeException()`이 `null`)
- 테스트: `shell_test.dart` — "centre button opens the assistant over the current tab"

## AC-007 — 작업 종류 등록부 (REQ-007)

- **Given** 빈 등록부
- **When** `call` 서술자를 등록하고, 같은 id를 한 번 더 등록하고, `call`·`null`·`'web'`을 각각 찾으면
- **Then** 두 번째 등록은 오류를 던지고, `call`과 `null`은 `call` 서술자를, `'web'`은 "모르는 종류" 서술자를 돌려준다. 앱을 띄우면 `call`이 등록되어 있고, 오늘·업무·기록의 작업 행이 등록된 표시자를 거쳐 그려진다(행마다 `Key('kind-call-row')`)
- 테스트: `packages/kolbi_core/test/task_kind_test.dart`(`dart test`), `app/test/inbox_test.dart` — "rows are drawn through the registered kind"

## AC-008 — 종류 값 없음·모르는 종류 (REQ-008)

- **Given** `kind` 필드가 없는 작업 "가 업체"와 `kind: 'web'`인 작업 "나 사이트"(둘 다 진행 중)
- **When** 업무를 보고 "나 사이트" 쪽 행을 누르면
- **Then** "가 업체"는 통화 작업 행으로, 다른 하나는 "이 앱에서 아직 볼 수 없는 작업이에요" 행으로 보이며, 누르면 빈 상태 "이 작업은 앱을 업데이트하면 볼 수 있어요"가 보인다. 예외가 없다
- 테스트: `inbox_test.dart` — "unknown kinds degrade to a placeholder"

## AC-009 — 단계 계산 (REQ-009)

- **Given** `design.md` D2.2 표의 16행 각각을 만족하는 작업
- **When** `taskSteps(task)`를 부르면
- **Then** 행마다 여섯 단계 상태가 표와 같다. 표의 "—"(무관) 칸은 가능한 값 두 가지 이상으로 각각 시험한다
- 테스트: `packages/kolbi_core/test/task_steps_test.dart` — 행 번호를 이름에 넣은 16개 이상 테스트

## AC-010 — 단계 타임라인 화면 (REQ-010)

- **Given** 작업 a·b·c·d·e
- **When** 각 작업의 상세를 열면
- **Then** 맨 위에 `Key('task-steps')`가 있고 단계 이름 여섯 개가 위에서 아래 순서로 있다. 단계 설명은 단계 키 안에서 찾는다(`find.descendant(of: find.byKey(Key('task-step-N')), matching: find.text(...))`): a의 `task-step-4`는 "응답을 기다리고 있어요", b의 `task-step-3`은 "다음 순서예요", c의 `task-step-3`은 "상대와 통화하고 있어요", d의 `task-step-4`는 "확인할 일이 없었어요", e의 `task-step-3`은 "통화가 이어지지 않았어요"다(plan-audit 3차 D1). 각 단계의 의미 라벨은 "6단계 중 N단계, <이름>, <상태 글자>"다. a의 상세에서 승인 질문 글자와 대화 첫 줄은 여전히 `findsOneWidget`이다(설명이 되풀이하지 않음). 그 아래 기존 내용이 지금처럼 보인다
- 테스트: `inbox_test.dart` — "task detail shows the six steps above the existing detail"

## AC-011 — 업무 묶음 (REQ-011)

- **Given** 작업 "섞음"
- **When** 업무 탭을 보면
- **Then** 개수 세 칸이 진행 중 "1"(c), 승인 대기 "2"(a, b), 오늘 완료 "1"(d)이고, 묶음 제목 "승인 요청", "진행 중", "반복"이 이 순서로 위에서 아래에 있으며, "승인 요청"에는 라 파스타 → 우리동네 치과 순서(만료가 있는 a가 먼저, design.md D3), "진행 중"에는 헤어살롱 봄이 있고, "반복" 아래에 "반복할 일을 만들면 여기에 모여요"가 있다. 관리사무소·행복 소아과는 업무에 없다. 맨 아래 "끝난 업무는 기록에서 볼 수 있어요"를 누르면 `tab-history`가 선택된다. 끝난 작업만 있으면 "승인 요청"·"진행 중" 제목이 없다
- 테스트: `packages/kolbi_core/test/task_groups_test.dart`, `inbox_test.dart` — "tasks tab groups approvals, ongoing and routines"

## AC-012 — 업무 빈 상태와 오류 (REQ-012)

- **Given** (1) 작업 0개 (2) 작업 목록 불러오기가 실패하는 가짜 저장소(`listError`)
- **When** 업무 탭을 보면
- **Then** (1) "아직 맡긴 일이 없어요"와 [비서에게 맡기기]가 보이고, 누르면 임시 비서 화면이 열린다 (2) 기존 오류 빈 상태 문구와 [다시 시도]가 보이고, 누르면 다시 불러온다(가짜 저장소의 `list` 호출 수가 1 늘어남)
- 테스트: `inbox_test.dart` — "empty and error states"

## AC-013 — 묶음 계산 한 곳 (REQ-013)

- **Given** AC-011 단위 테스트의 입력 표
- **When** (1) 묶음 함수의 "승인 요청" 가운데 통화 중 대기 승인 작업과 기존 `pendingApprovalsProvider`(`calls_controller.dart:115`)의 결과를 비교하고 (2) 앱에서 배지 수·업무 "승인 요청" 행 수·오늘 "확인이 필요해요" 개수 표시를 세면
- **Then** (1) 두 작업 집합이 같다({a}) (2) 세 수가 같다(2). 그리고 `app/lib` 안에서 승인 요청 판정 조건(`awaitingApproval`과 대기 승인 확인의 조합)을 묶음 함수 밖에서 다시 쓰는 곳이 없다(코드 검토, 위치를 `progress.md`에 기록). `ApprovalListener`는 b(계획 승인 대기)에 알림을 띄우지 않는다(지금 동작)
- 테스트: `task_groups_test.dart` — "in-call approvals agree with pending approvals", `shell_test.dart` — "badge, tasks and today agree"

## AC-014 — 기록 (REQ-014)

- **Given** (1) 작업 "섞음" (2) 끝난 작업 0개 (3) 2026-11-25 23:59와 2026-11-26 00:01(아시아/서울)에 끝난 작업 두 개 (4) `design.md` D4 표의 여섯 행을 하나씩 만족하는 끝난 작업
- **When** 기록 탭을 보면
- **Then** (1) "오늘 · 11월 26일" 아래 관리사무소(칩 "완료"), "어제 · 11월 25일" 아래 행복 소아과(칩 "실패")가 이 순서로 있고, 진행 중·승인 요청 작업은 없다 (2) "아직 끝난 업무가 없어요"가 보인다 (3) 두 작업이 서로 다른 날짜 묶음에 있다(기기 시간대를 UTC로 둬도 같음) (4) 행마다 칩 글자와 범주 색이 D4 표와 같고, 각 칩이 아이콘과 글자를 함께 가진다
- 테스트: `task_groups_test.dart` — "history groups by Seoul date", `app/test/history_test.dart` — "history lists finished tasks by day with result chips"

## AC-015 — 오늘 배치 (REQ-015)

- **Given** (1) 작업 "섞음" + 최근 통화한 곳이 계산되는 끝난 작업, 800×2400 화면, 프로필 이름 "지은" (2) 작업 0개 (3) 시계 09:00·14:00·21:00 각각
- **When** 오늘을 보면
- **Then** (1) "kolbi.", "11월 26일 목요일", "좋은 오후예요, 지은 님.", "오늘도 제가 함께할게요.", 브리핑 "오늘 중요한 일이 3개 있어요."와 "라 파스타가 답을 기다려요.", `Key('home-intake-field')`, 예시 칩 첫 글자("식당 예약"), 바로가기 "전화 대신하기", "확인이 필요해요"(개수 "2"), "진행 중", "최근 통화한 곳"이 이 순서로 위에서 아래에 있고, "지난 통화"와 "CallMate" 글자는 없다 (2) "귀찮은 전화, 대신 걸어드릴게요"와 "식당 예약"이 보이고 브리핑 카드·"확인이 필요해요"·"진행 중"이 없다 (3) 인사가 각각 "좋은 아침이에요", "좋은 오후예요", "좋은 저녁이에요"로 시작한다. 모든 경우 툴팁 "설정"·"보내기" 버튼이 있다
- 테스트: `app/test/today_test.dart` — "today follows the dashboard order", "greeting follows the time of day"

## AC-016 — 오늘 바로가기 (REQ-016)

- **Given** 작업 "섞음"의 오늘
- **When** (1) "전화 대신하기" (2) "정보 찾아보기" (3) "일정 관리" (4) "업무 보기 →"를 누르면(각각 새로 띄운 앱에서)
- **Then** (1)·(2) 임시 비서 화면이 열린다 (3) 화면이 바뀌지 않고, 그 타일의 의미 정보에 비활성(`isEnabled` 거짓)과 "곧 쓸 수 있어요"가 있다 (4) `tab-tasks`가 선택된다
- 테스트: `today_test.dart` — "today shortcuts"

## AC-017 — 내 정보 (REQ-017)

- **Given** (1) 이름 "김지은", 회신 번호 "010-1234-5678"이 저장된 설정 (2) 빈 설정
- **When** 내 정보 탭을 보면
- **Then** (1) 프로필 카드에 "김지은"과 "010-****-5678"이 보이고 (2) "내 정보를 입력해 주세요"가 보인다. 묶음 제목 "비서", "권한과 안전", "앱"이 이 순서로 있고 `design.md` D6의 항목이 있다. 프로필 카드 또는 "서버 연결(개발용)"을 누르면 설정 화면이 열린다. 그 밖의 항목(예: "연결 앱 · 스킬")에는 "곧 쓸 수 있어요"가 보이고, 눌러도 화면이 바뀌지 않으며 의미 정보에 비활성이 있다
- 테스트: `shell_test.dart` — "me tab lists items and opens settings"

## AC-018 — 구조 규칙 (REQ-018)

- **Given** `app/test/architecture_test.dart`(SPEC-MODULE-001에서 만든 것)
- **When** 이 SPEC의 변경 뒤 실행하면
- **Then** 기능 간 import 허용 목록이 비어 있고, `app/lib/core/`의 어떤 파일도 `features/`를 가져오지 않으며(다시 내보내기 전용 파일 제외), 다시 내보내기 전용 파일 목록이 테스트에 고정되어 있다. `GoRouter` 생성은 `app/lib/shell/`에만 있고(`grep -rn "GoRouter(" app/lib`이 `shell/` 한 곳), 기능 모듈은 탭 전환을 `navigation.dart`의 함수로만 한다(`grep -rnE "\.go\(|goNamed\(" app/lib/features` 출력 없음)
- 테스트: `architecture_test.dart` — "features do not import each other", "core does not import features", "router and tab switching live in the shell"

## AC-019 — 기존 흐름 유지 (REQ-019)

- **Given** 이 SPEC의 변경 뒤
- **When** 기존 테스트 파일 `approval_flow_test.dart`, `approval_card_test.dart`, `intake_flow_test.dart`, `follow_up_test.dart`, `trust_notice_test.dart`, `outcome_card_test.dart`, `calls_controller_test.dart`, `unit_test.dart`, `theme_test.dart`를 실행하면
- **Then** 모두 수정 없이 통과한다(`git diff --stat <run_start_sha> -- app/test/`에 이 파일들이 없음). `plan_card_test.dart`는 AC-021 표의 한 블록만 바뀐 채 통과한다. 단 `approval_flow_test.dart`·`approval_card_test.dart`는 AC-021 표 확장 행(소유자 결정 2026-11-27)만 바뀐 채 통과한다
- 확인: diff 원문을 `progress.md`에 기록

## AC-020 — 접근성 (REQ-020)

- **Given** 오늘·업무·기록·내 정보·통화 상세(a, 승인 카드 있음) 다섯 화면, 작업 "섞음"
- **When** 밝은·어두운 모드에서 `meetsGuideline(androidTapTargetGuideline)`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline`을 검사하고, 360×640·`TextScaler.linear(2.0)`으로 다섯 화면을 띄우면
- **Then** 모든 지침 검사가 통과하고, 넘침 오류가 없으며, 승인 카드의 [승인]은 스크롤로 닿아 누를 수 있고, 탭 바 라벨 글자의 실제 배율이 1.5 이하다(라벨 `Text`가 받는 `TextScaler`의 `scale(14) / 14 <= 1.5`)
- 테스트: `app/test/accessibility_test.dart` 끝에 새 테스트 추가 — "shell screens meet the accessibility guidelines"

## AC-021 — 서버 불변과 의도한 테스트 변경 (REQ-021)

- **Given** run 시작 시점
- **When** run 끝에 공통 검증의 변경 범위 명령을 실행하면
- **Then** `server/` 변경이 없고, 기존 테스트에서 바뀐 곳은 다음 표(research R2)뿐이다. 새 테스트를 기존 파일 끝에 더하는 것은 허용한다. `flutter test` 전체가 통과하고 테스트 수가 run 시작 시점보다 줄지 않는다.

  | 파일 | 블록 | 바뀌는 내용 |
  |---|---|---|
  | `accessibility_test.dart` | "screens follow the wireframe order"의 홈 순서 블록(`:614-619`) | 데이터 `homeTasks()`(`:41-45`, 진행 중 1건 + 끝난 2건, 대기 승인 없음)는 바꾸지 않는다. 기대 목록을 `find.byKey(const Key('home-intake-field'))` → `find.text('진행 중')` → `find.text('최근 통화한 곳')`으로 바꾼다("지난 통화" 제거, "확인이 필요해요"는 이 데이터에서 나오지 않으므로 넣지 않음 — plan-audit 2차 N2) |
  | `plan_card_test.dart` | 시작 뒤 뒤로 가기 블록(`:194-196`) | `find.text('CallMate')` → `find.byKey(Key('tasks-screen'))`(REQ-005: 뒤로 = 업무 첫 화면, REQ-015: 워드마크) |
  | `approval_flow_test.dart` | `pumpApp`의 화면 크기(`:16` 뒤 세 줄) | 기본 800×600 대신 `tester.view.physicalSize = const Size(800, 2400)`, `devicePixelRatio = 1`, `addTearDown(tester.view.reset)`. 원인: REQ-015 순서 — 오늘 화면의 "귀찮은 전화, 대신 걸어드릴게요"(`:36`)와 작업 행 "라 파스타"(`:44,47`)가 첫 화면 아래로 밀려 `find`와 누름이 닿지 않음. 소유자 결정 2026-11-27 |
  | `approval_card_test.dart` | `openCall`(`:45`, `:176`이 끝난 작업으로 부름) | 오늘의 "라 파스타" 행 누름 대신 `routerProvider`를 읽어 `push('/calls/<id>')`(import 한 줄 추가). 원인: REQ-015 / OD-1 — 오늘은 끝난 작업을 보이지 않음. 소유자 결정 2026-11-27 |
  | `font_overflow_test.dart` | 360×640·2배 블록(`:73-74`) | "직접 입력하기"까지 `scrollUntilVisible` 한 줄 추가. 원인: REQ-015 순서 — 날짜·인사·브리핑 아래로 밀려 화면 밖(offstage)이 됨. 소유자 결정 2026-11-27 |
  | `accessibility_test.dart` | 결과 상세 큰 글자 검사(`:480`) | `ensureVisible` 앞에 `scrollUntilVisible(find.text('다시 걸기'), …)` 한 줄 추가. 원인: REQ-010 — 맨 위 단계 타임라인이 결과 카드를 화면 밖으로 밀어 `Bad state: No element`. 소유자 결정 2026-11-27 |

  표 확장(소유자 결정 2026-11-27, 선택 A): 위 표의 마지막 네 행(`approval_flow_test.dart`부터)은 run M4에서 REQ-015·REQ-010을 구현하자 원래 표 밖의 기존 블록 다섯 곳(`approval_flow_test.dart` 두 곳 포함)이 깨져, 아래 문단의 절차대로 소유자 확인을 받아 더한 것이다. 여섯째 깨짐(`accessibility_test.dart:223`, 대화 자동 따라가기)은 테스트를 고치지 않고 앱에서 해결했다. 이 확장에 따라 AC-019의 "수정 없이" 목록 가운데 `approval_flow_test.dart`·`approval_card_test.dart`는 이 표의 행만 바뀐 채 통과하면 된다. diff 원문과 깨짐 기록은 `progress.md` §E.2 "AC-021 table extended by owner decision 2026-11-27 (option A)"에 있다.

  run에서 이 표 밖의 기존 단언이 깨지면 고치지 않고 plan 단계로 돌아가 research R2와 이 표를 고친 뒤(소유자 확인) 다시 진행한다.
- 확인: `git diff` 원문을 `progress.md`에 기록

## 엣지 케이스

- 승인 만료 시각이 지난 `pending` 승인(서버가 아직 만료 처리 전): 작업은 승인 요청에 남는다. 묶음 함수는 서버 상태만 보고 현재 시각으로 묶음을 바꾸지 않는다.
- 실시간 연결이 끊긴 동안: 업무·기록은 마지막으로 받은 목록을 보이고, 실시간 연결 표시(오늘)는 그대로다.
- 업무 탭에서 상세를 연 채로 오늘 탭을 눌렀다 돌아오면 상세가 그대로 있다. 가운데 버튼으로 비서를 열었다 닫아도 같다.
- 큰 글자 2.0에서 탭 라벨이 두 줄이 되지 않는다(배율 상한 1.5).
- 기기 시간대가 아시아/서울이 아니어도 날짜·인사·기록 묶음은 아시아/서울 기준이다.
- 프로필 이름이 없으면 인사는 "좋은 오후예요."처럼 이름 없이 끝난다.

## 잔여 위험

- 탭 사이 이동은 go_router 18.1.4의 동작(research R1)에 기대므로, 버전을 올리면 AC-004·AC-005·AC-006을 다시 확인해야 한다.
- 실패 단계 판정은 대화 유무로 근사한다(OD-8). 연결됐지만 대화가 비어 있는 드문 경우 ③이 실패로 보인다.
- 오늘 화면의 입력칸과 첫 사용 빈 상태는 과도기(OD-2·OD-6)이며, 승인된 목업과 다르다. SPEC-ASSIST-001이 끝나야 목업과 같아진다.

## 완료 정의 (Definition of Done)

- [ ] AC-001 ~ AC-021 모두 PASS, 명령 원문과 출력이 `progress.md` §E.2에 있음
- [ ] 기존 테스트 통과, 의도한 변경은 AC-021 표의 행뿐(원래 두 블록 + 소유자 결정 2026-11-27로 더한 네 행)
- [ ] `server/` 무변경
- [ ] 기능 간 import 허용 목록이 비어 있음
- [ ] 서식은 변경 파일에만 적용
- [ ] sync-phase 문서 항목(`plan.md` §G) 목록이 manager-docs에 넘겨짐
