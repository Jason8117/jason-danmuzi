# SPEC-SHELL-001 설계 (0.3.1)

spec.md의 요구사항이 가리키는 표와 규칙을 모은다. 근거: `research.md`(R1 실험, R2 테스트 영향), `docs/product/11_ARCHITECTURE.md` §2.5·§3, `docs/planning/04_DESIGN_PLAN.md` §17, `docs/planning/06_DESIGN_DECISIONS.md`.

## D1. 경로 구성과 탭 사이 이동

### D1.1 경로 구성

```
StatefulShellRoute.indexedStack (탭 바 = CMP-01 개정)
├── 갈래 0 오늘:   /  (SCR-H01)        /plan  /calls/new
├── 갈래 1 업무:   /inbox (SCR-T01)    /calls/:id (SCR-T02/T05)
├── 갈래 2 기록:   /history (SCR-R01)
└── 갈래 3 내 정보: /me (SCR-M01)       /settings
셸 밖 최상위: /assistant (임시 비서 화면, 전체 화면, 탭 바 가림)
```

가운데 비서 버튼은 갈래가 아니다. 탭 바는 탭 네 칸 + 가운데 버튼 한 칸을 그린다.

### D1.2 이동 규칙(research R1 근거)

| 출발 | 동작 | 방법 | 결과 |
|---|---|---|---|
| 어디서든 | 작업 행 누름(오늘·업무·기록), 계획 카드 [이대로 시작] 성공, 직접 입력 만들기 성공, 승인 알림 [답하기] | `openTask`: 지금 쌓인 화면을 모두 닫고(`canPop`인 동안 `pop`, 비서 포함) `go('/inbox')` 다음 `push('/calls/<id>')` | 업무 탭 선택, 업무 탭은 첫 화면부터 다시 쌓임, 뒤로 = 업무 첫 화면. 다른 탭에 계획 카드 등이 남지 않음(research R1 X1·Y1~Y3) |
| 탭 바 | 다른 탭 누름 | `goBranch(i)` | 그 탭에 쌓인 화면 유지(R1 X2) |
| 탭 바 | 이미 선택된 탭 누름 | 첫 화면이 아니면 `goBranch(i, initialLocation: true)`, 첫 화면이면 맨 위로 스크롤 | R1 X2 |
| 오늘 | 계획 카드·직접 입력·설정 열기 | `push(경로)` | 오늘 탭 위에 쌓임(지금 동작) |
| 업무 상세 | 결과 [다시 걸기] → 계획 카드 | `push('/plan', extra: 초안)` | 업무 탭 위에 쌓임(R1-F). 뒤로 = 상세 |
| 내 정보 | 프로필·서버 연결 → 설정 | `push('/settings')` | 내 정보 탭 위 |
| 어디서든 | 가운데 비서 버튼 | `push('/assistant')` | 탭 바 가림. 닫으면 원래 탭·쌓인 화면(R1-E) |
| 임시 비서 화면 | 부탁 보내기 → 계획 카드 | 비서를 닫고(`pop`) `push('/plan', extra: 초안)` | 원래 탭 위에 계획 카드(R1-G2). 비서 위에 바로 `push`하면 go_router 오류(R1-G) |
| 업무 빈 상태 | [비서에게 맡기기] | `push('/assistant')` | 위와 같음 |
| 업무 아래 링크 | "끝난 업무는 기록에서 볼 수 있어요" | `openTab(history)` = `goBranch(2)` | 기록 탭(쌓인 화면 유지) |
| 오늘 브리핑 | "업무 보기 →" | `openTab(tasks)` = `goBranch(1)` | 업무 탭 |
| 테스트 도우미 | `routerProvider.push(location)` | 그대로 | 지금 탭(오늘) 위에 그 화면, 탭 바 있음(R1-A·D) |

이 규칙은 `app/lib/shell/navigation.dart`의 함수 네 개로만 쓴다: `openTask(router, id)`, `openTab(router, tab)`, `openAssistant(router)`, `submitFromAssistant(router, draft)`(임시 비서에서 계획 카드). `router`는 `GoRouter`이며, 화면에서는 `GoRouter.of(context)`, 라우터 바깥(`MaterialApp.router`의 `builder`, `app.dart:22`)에 있는 `ApprovalListener`는 지금처럼 `ref.read(routerProvider)`로 넘긴다(plan-audit 3차 D6). `openTab`은 셸의 `StatefulNavigationShell`을 직접 쓰지 않고 탭 첫 경로로 `go`하는 대신, 셸이 등록한 갈래 번호로 `goBranch`를 부르도록 셸 위젯이 `navigation.dart`에 갈래 전환 함수를 등록한다(M2에서 실제 셸로 확인). 기능 모듈은 이 네 함수와 경로 이름(`pushNamed`)만 부르고 `go`·`goBranch`를 직접 부르지 않는다(AC-018).

## D2. 업무 실행 단계 계산(REQ-009, REQ-010)

### D2.1 단계와 상태

단계 여섯: ① 요청 이해 ② 연락처 확인 ③ 가능 여부 확인 ④ 내 승인 ⑤ 확정 ⑥ 결과 보고.
단계 상태 여섯: 끝남 · 지금 · 대기 · 실패 · 건너뜀 · 취소.

### D2.2 기대 표

입력: 작업 상태, 대기 승인(`approvals`에 `pending` 있음), 답한 승인(`approvals`에 `pending` 아닌 항목 있음), 대화(`transcript`가 비어 있지 않음), 결과(`outcome` 있음).

| # | 작업 상태 | 대기 승인 | 답한 승인 | 대화 | 결과 | ① | ② | ③ | ④ | ⑤ | ⑥ |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `planning` | — | — | — | — | 지금 | 대기 | 대기 | 대기 | 대기 | 대기 |
| 2 | `awaitingApproval` | — | — | — | — | 끝남 | 끝남 | 대기 | 대기 | 대기 | 대기 |
| 3 | `dialing`·`ringing` | 없음 | — | — | — | 끝남 | 끝남 | 지금 | 대기 | 대기 | 대기 |
| 4 | `inProgress` | 없음 | 없음 | 있거나 없음 | — | 끝남 | 끝남 | 지금 | 대기 | 대기 | 대기 |
| 5 | `inProgress` | 없음 | 있음 | 있거나 없음 | — | 끝남 | 끝남 | 끝남 | 끝남 | 지금 | 대기 |
| 6 | `dialing`·`ringing`·`inProgress` | 있음 | — | — | — | 끝남 | 끝남 | 끝남 | 지금 | 대기 | 대기 |
| 7 | `summarizing` | — | 있음 | — | — | 끝남 | 끝남 | 끝남 | 끝남 | 지금 | 대기 |
| 8 | `summarizing` | — | 없음 | — | — | 끝남 | 끝남 | 끝남 | 건너뜀 | 지금 | 대기 |
| 9 | `completed` | — | 있음 | — | 있음 | 끝남 | 끝남 | 끝남 | 끝남 | 끝남 | 끝남 |
| 10 | `completed` | — | 없음 | — | 있음 | 끝남 | 끝남 | 끝남 | 건너뜀 | 끝남 | 끝남 |
| 11 | `completed` | — | — | — | 없음 | 끝남 | 끝남 | 끝남 | (9·10과 같음) | 끝남 | 대기 |
| 12 | `failed` | — | — | 없음 | — | 끝남 | 끝남 | 실패 | 대기 | 대기 | 대기 |
| 13 | `failed` | — | 있음 | 있음 | — | 끝남 | 끝남 | 끝남 | 끝남 | 실패 | 대기 |
| 14 | `failed` | — | 없음 | 있음 | — | 끝남 | 끝남 | 끝남 | 건너뜀 | 실패 | 대기 |
| 15 | `canceled` | — | — | 없음 | — | 끝남 | 끝남 | 취소 | 취소 | 취소 | 취소 |
| 16 | `canceled` | — | — | 있음 | — | 끝남 | 끝남 | 끝남 | 취소 | 취소 | 취소 |

- `failed` 작업이 어느 단계에서 실패했는지는 데이터에 직접 없으므로 **대화가 있었는가**로 정한다: 대화가 없으면 통화가 이어지지 않은 것이라 ③ 실패, 있으면 통화 뒤 확정하지 못한 것이라 ⑤ 실패(행 12~14). 이 규칙은 근사이며, 서버가 실패 단계를 알려 주게 되면(Phase 0 상태 이름 전환) 그 값으로 바꾼다.
- `planning`에서 ①이 "지금"인 것은 서버가 부탁을 계획으로 바꾸는 중이기 때문이다. `awaitingApproval`은 통화 전 계획 승인이라(research R3) ①②를 끝남으로 본다. ④ "내 승인"은 통화 중 승인만 뜻한다.
- 화면은 "취소" 상태 단계를 무채색 "취소" 표시로 그리고, 같은 행 뒤쪽 단계는 숨긴다.

### D2.3 단계 설명 줄

설명 줄은 **화면의 다른 글자를 되풀이하지 않는다**(기존 `findsOneWidget` 단언 보호, research R2).

| 단계 | 끝남 | 지금 | 실패 |
|---|---|---|---|
| ① | "부탁을 이해했어요" | "부탁을 살펴보고 있어요" | — |
| ② | "연락처를 확인했어요" | — | — |
| ③ | "통화가 연결됐어요" | "상대와 통화하고 있어요" | "통화가 이어지지 않았어요" |
| ④ | 승인·거절이면 "답했어요", 만료면 "응답 시간이 지났어요" | "응답을 기다리고 있어요" (승인 질문 글자는 쓰지 않음) | — |
| ⑤ | "확정했어요" | "결과를 정리하고 있어요" | "확정하지 못했어요" |
| ⑥ | "결과를 정리했어요" | — | — |

건너뜀 = "확인할 일이 없었어요", 대기 = "다음 순서예요", 취소 = "멈췄어요". ("대기 중"은 상세의 승인 기록 `call_detail_screen.dart:557`, "취소"는 끊기·취소 버튼 `:282`·`:290`과 겹쳐 쓰지 않음 — plan-audit 2차 N7.) 각 단계 줄은 `Key('task-step-<1~6>')`를 가진다.

"답한 승인"은 `approvals` 가운데 상태가 `pending`이 아닌 것(승인·거절·만료)이다.

①②의 설명을 고정 문구로 두는 이유: 상세 화면이 이미 목표(`task.goal`, `_GoalCard`)와 상대 이름·번호(`task.targetName`·`task.phoneNumber`, `_CallHeader`)를 보이므로, 같은 글자를 되풀이하지 않는다.

## D3. 업무·기록·오늘 묶음(REQ-011~REQ-015)

| 묶음 | 계산 | 순서 |
|---|---|---|
| 승인 요청 | `awaitingApproval`이거나, 상태와 관계없이 `task.pendingApproval`이 있는 작업(끝난 작업 제외) | 대기 승인 만료가 가까운 순, 만료가 없는 작업(`awaitingApproval`)은 그 뒤에 `updatedAt` 최근 순 |
| 진행 중 | 끝나지 않았고(`completed`·`failed`·`canceled` 아님) 승인 요청에 들지 않은 작업(`planning`·`dialing`·`ringing`·`inProgress`·`summarizing` 가운데 대기 승인 없음) | `updatedAt` 최근 순 |
| 반복 | 이 SPEC에서는 빈 묶음 | — |
| 기록 날짜 묶음 | `completed`·`failed`·`canceled`를 `updatedAt`의 아시아/서울 날짜로 | 날짜 최근 순, 같은 날 안 `updatedAt` 최근 순 |
| 개수 세 칸 | 진행 중 수 · 승인 요청 수 · 오늘(아시아/서울) `updatedAt`인 `completed` 수 | — |
| 배지 | 승인 요청 수 | — |
| 오늘 "확인이 필요해요" | 승인 요청과 같은 목록, 처음 두 개 | 같음 |
| 오늘 "진행 중" | 진행 중과 같은 목록, 처음 두 개 | 같음 |

두 묶음은 겹치지 않는다(plan-audit 2차 N4). **기존 판정과의 관계(plan-audit D2)**: 승인 요청 가운데 `task.pendingApproval`이 있는 부분집합은 `pendingApprovalsProvider`(`calls_controller.dart:115-120`)의 작업 집합에서 끝난 작업을 뺀 것과 같다. 그 공급자는 끝난 작업에 남은 대기 승인도 세지만, 오늘의 승인 요청 묶음은 끝난 작업을 넣지 않는다(위 표, plan-audit 3차 D3). 알림·배지는 지금처럼 공급자를 그대로 쓴다. 계획 승인 대기(`awaitingApproval`)는 승인 요청 묶음에만 들어가고 `ApprovalListener`의 알림 대상은 바꾸지 않는다(지금처럼 통화 중 승인만 알림).

## D4. 기록 결과 칩(REQ-014)

SPEC-DESIGN-001의 `StatusChip.category(category, label)`를 쓴다.

| 작업 상태 | 결과(`outcome.result`) | 범주 | 글자 |
|---|---|---|---|
| `completed` | `success` | 완료 | 완료 |
| `completed` | `partial` | 대기 중(무채색) | 일부 달성 |
| `completed` | `unverified` 또는 결과 없음 | 대기 중 | 확인 못 함 |
| `completed` | `failed` | 실패 | 달성 못 함 |
| `failed` | — | 실패 | 실패 |
| `canceled` | — | 대기 중 | 취소됨 |

행의 결과 한 줄은 `outcome.summary`(`call_models.dart:170`)가 비어 있지 않으면 그 첫 줄, 아니면 상태 글자다. 행 제목은 `task.targetName`.

## D5. 오늘 화면 규칙(REQ-015, REQ-016)

| 요소 | 규칙 |
|---|---|
| 워드마크 | "kolbi." 글자와 인디고 사각 로고(지금 앱 바 제목 `CallMate` 자리) |
| 날짜 | "11월 26일 목요일" 형식(`intl` `ko` 로케일, `M월 d일 EEEE`), 시각은 주입 가능(테스트) |
| 인사 | 05:00~10:59 "좋은 아침이에요", 11:00~16:59 "좋은 오후예요", 17:00~04:59 "좋은 저녁이에요". 프로필 이름이 있으면 ", <이름> 님." 붙임, 없으면 "." |
| 부제 | "오늘도 제가 함께할게요." |
| 브리핑 제목 | "오늘 중요한 일이 N개 있어요."(N = 승인 요청 수 + 진행 중 수, N ≥ 1) |
| 브리핑 설명 | 다음 가운데 해당하는 첫 문장 하나: 승인 요청이 있으면 "<첫 승인 요청 상대 이름>이(가) 답을 기다려요." → 진행 중만 있으면 "<첫 진행 중 상대 이름>에 전화하고 있어요." 조사 처리는 이름 끝 받침으로 정한다 |
| 브리핑 링크 | "업무 보기 →", 누르면 `openTab(tasks)`(D1.2) |
| 바로가기 | 전화 대신하기 → `openAssistant`, 정보 찾아보기 → `openAssistant`, 일정 관리·메일 확인 → 비활성 "곧 쓸 수 있어요" |
| 작업 0개 | 브리핑 카드 없이 지금의 첫 사용 빈 상태(OD-2) |

## D6. 내 정보 항목(REQ-017)

| 묶음 | 항목 | 이 SPEC에서 |
|---|---|---|
| 비서 | 연결 앱 · 스킬, 연락처, 기억, 맡기는 방식 | 모두 비활성 "곧 쓸 수 있어요" |
| 권한과 안전 | 권한 설정, 알림, 안전하게 쓰는 법 | 비활성 |
| 앱 | 화면 · 언어, 서버 연결(개발용), 문의 · 신고, 계정 | 서버 연결만 활성(→ `/settings`) |

"서버 연결(개발용)"은 04 §17.8에 없지만, 지금 설정 화면(서버 주소·토큰)으로 가는 유일한 길이라 F-SET-06(Phase 0, 상용 빌드에서 숨김)까지 둔다(plan-audit D9).

## D7. 모듈 배치

| 위치 | 담는 것 |
|---|---|
| `packages/kolbi_core/lib/src/kinds/` | `TaskKindDescriptor`(+`steps`), `TaskKindCatalog`, `call` 서술자 |
| `packages/kolbi_core/lib/src/tasks/task_steps.dart` | D2 계산 |
| `packages/kolbi_core/lib/src/tasks/task_groups.dart` | D3 계산(시각·시간대 인자) |
| `packages/kolbi_ui/lib/src/kinds/` | `TaskKindPresenter`, 모르는 종류 행 |
| `packages/kolbi_ui/lib/src/widgets/step_timeline.dart` | CMP-34 |
| `packages/kolbi_ui/lib/src/widgets/briefing_card.dart` | CMP-37 |
| `packages/kolbi_ui/lib/src/widgets/tab_badge.dart` | 배지 |
| `app/lib/shell/` | 라우터, 경로 이름, `navigation.dart`(D1.2), 탭 바, 가운데 버튼, 임시 비서 화면, 종류 등록 |
| `app/lib/features/{inbox,history,me}/` | 세 화면 |
| `app/lib/core/widgets/trust_notice.dart` | 신뢰 안내 조각. `kolbi_ui`가 아닌 이유: 앱 설정(Riverpod)을 읽으므로 `kolbi_ui` 규칙(Riverpod 금지, 11 §2.4 R-2)에 어긋남(plan-audit D11) |
