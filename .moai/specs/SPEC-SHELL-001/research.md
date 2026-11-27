# SPEC-SHELL-001 조사 기록 (0.3.1, plan-phase)

plan-audit 1차(`.moai/reports/plan-audit/SPEC-SHELL-001-review-1.md`)가 요구한 두 가지 근거를 담는다: (1) go_router 18.1.4에서 탭(갈래) 사이 이동이 실제로 어떻게 동작하는가, (2) 이 SPEC이 바꾸는 기존 테스트 전체 목록. 2026-11-26, HEAD c2e732d 기준.

## R1. go_router 18.1.4 탭 사이 이동 실험

### 방법

프로젝트 밖 임시 패키지(`go_router: 18.1.4`, Flutter 3.50.1, 오프라인 pub 캐시)에서 위젯 테스트로 확인했다. 실험 코드 원문: `research/go_router_spike_test.dart.txt`. 구성은 이 SPEC의 셸과 같은 모양이다: `StatefulShellRoute.indexedStack` 세 갈래(0: `/`·`/plan`, 1: `/inbox`·`/calls/:id`, 2: `/me`·`/settings`) + 셸 밖 최상위 `/assistant`(자식 `plan`). 탭 바 자리에 `TABBAR index=<현재 갈래>` 글자를 두어 현재 갈래와 탭 바 표시 여부를 읽었다.

명령: `flutter --suppress-analytics test test/spike_test.dart` (경우별 `--plain-name`).

### 결과(관찰한 출력 원문)

| 경우 | 동작 | 출력 |
|---|---|---|
| A | 오늘(0)에서 `push('/calls/1')`, 뒤로 | `A visible DETAIL=true tabbar=TABBAR index=0` / `A after pop: TODAY=true INBOX=false TABBAR index=0` |
| B | `go('/inbox')` 뒤 `push('/calls/1')`, 뒤로 | `B visible DETAIL=true TABBAR index=1` / `B after pop: INBOX=true TODAY=false TABBAR index=1` |
| C | `go('/calls/1')`만 | `C visible DETAIL=true TABBAR index=1 canPop=false` |
| D | 오늘(0)에서 `push('/settings')` | `D visible SETTINGS=true TABBAR index=0` |
| E | 업무 상세 위에 `push('/assistant')`, 뒤로 | `E assistant visible=true tabbar=false` / `E after pop: DETAIL=true TABBAR index=1` |
| F | 업무 상세(1)에서 `push('/plan')`, 뒤로 | `F visible PLAN=true TABBAR index=1` / `F after pop: DETAIL=true TABBAR index=1` |
| G | `/assistant` 위에서 `push('/plan')` | **오류**: `Failed assertion ... '!keyReservation.contains(key)'`(navigator.dart:4083, go_router builder.dart:517) |
| G2 | `/assistant`를 닫고(`pop`) `push('/plan')` | `G2 PLAN=true TABBAR index=1 exc=null` |
| G3 | `/assistant` 위에 자식 경로 `push('/assistant/plan')`, 뒤로, 다시 열고 `go('/inbox')`+`push('/calls/1')` | `G3 APLAN=true tabbarVisible=false exc=null` / `G3 back -> ASSISTANT=true` / `G3 start -> DETAIL=true ASSISTANT=false TABBAR index=1 exc=null` |
| H | 오늘에서 `push('/plan')` → `go('/inbox')`+`push('/calls/1')` → `go('/')` | `H detail TABBAR index=1 DETAIL=true` / `H today tab: TODAY=true PLAN=false` |

**보강 실험(plan-audit 2차, 2026-11-26).** 탭 바는 탭을 누를 때 `StatefulNavigationShell.goBranch`를 쓴다. 위 실험은 `go('/')`만 썼으므로, 감사가 `goBranch`로 다시 시험했고(원문 `research/audit_branch_spike_test.dart.txt`) 작성자가 같은 결과를 재현한 뒤 해법을 시험했다(원문 `research/open_task_spike_test.dart.txt`). 경우마다 `--plain-name`으로 따로 실행해야 한다(한 파일을 한 번에 돌리면 G의 assertion이 뒤 경우를 망가뜨려 `+7 -3`으로 나옴).

| 경우 | 동작 | 출력 |
|---|---|---|
| X1 | 오늘에서 `push('/plan')` → `go('/inbox')`+`push('/calls/1')` → `goBranch(0)` | `X1 goBranch0: TODAY=false PLAN=true TABBAR index=0 exc=null` — **계획 카드가 남음** |
| X2 | 업무 상세에서 `goBranch(0)` → `goBranch(1)`, 그다음 `goBranch(1, initialLocation: true)` | `X2 back to inbox: DETAIL=true INBOX=false` / `X2 retap: DETAIL=false INBOX=true` |
| X4 | 업무 상세가 있는 채로 `go('/inbox')`+`push('/calls/2')`, 뒤로 | `X4: INBOX=true DETAIL1=false TABBAR index=1` |
| X5 | 오늘에서 `push('/plan')` → `pop` → `go('/inbox')`+`push` → `goBranch(0)` | `X5 pop-then-go: TODAY=true PLAN=false TABBAR index=0 exc=null` |
| X6 | `go('/')` 다음 `go('/inbox')`+`push` → `goBranch(0)` | `X6 go-root-first: TODAY=false PLAN=true TABBAR index=0 exc=null` — `go('/')`로는 해결 안 됨 |
| Y1 | 오늘에 화면 두 개(`/plan`, `/settings`) → `openTask`(모두 `pop` → `go('/inbox')` → `push`) → 뒤로 → `goBranch(0)` | `Y1 after openTask: DETAIL=true TABBAR index=1` / `Y1 back: INBOX=true TABBAR index=1` / `Y1 goBranch0: TODAY=true PLAN=false SETTINGS=false TABBAR index=0 exc=null` |
| Y2 | 업무 상세 위 `/assistant` → `/assistant/plan` → `openTask` → 뒤로 → `goBranch(0)` | `Y2 after: DETAIL2=true ASSIST=false TABBAR index=1 exc=null` / `Y2 back: INBOX=true DETAIL1=false TABBAR index=1` / `Y2 goBranch0: TODAY=true TABBAR index=0` |
| Y3 | 업무 상세 위 `/plan`([다시 걸기]) → `openTask` → 뒤로 | `Y3 after: DETAIL3=true PLAN=false TABBAR index=1 exc=null` / `Y3 back: INBOX=true DETAIL1=false` |

### 결론

1. **`push`는 탭을 바꾸지 않는다.** 다른 갈래에 속한 경로를 `push`하면 화면은 열리지만 지금 갈래 위에 쌓이고 탭 바와 탭 선택은 그대로다(A, D, F). 그래서 기존 경로와 테스트 도우미(`routerProvider.push(location)`)는 지금처럼 그 화면을 보이며 탭 바도 있다(REQ-004 충족). plan-audit이 지적한 "셸 밖 대안"은 필요 없다.
2. **"탭 전환 + 푸시"는 `go(탭 첫 화면)` 다음 `push(대상)`이다**(B). 뒤로 가면 그 탭 첫 화면이다. `go(대상)`만 하면 뒤로 갈 곳이 없다(C).
3. **셸 밖 최상위 경로(`/assistant`)는 탭 바를 가리고, 닫으면 원래 탭과 쌓인 화면으로 돌아간다**(E).
4. **셸 밖 경로 위에 셸 안 경로를 `push`하면 오류다**(G). 비서에서 계획 카드로 가려면 비서를 닫고 `push`하거나(G2), 계획 카드를 비서의 자식 경로로 둔다(G3). 이 SPEC의 임시 비서 화면은 G2를 쓰고, SPEC-ASSIST-001은 둘 중 하나를 고른다.
5. ~~[이대로 시작] 뒤 `go('/inbox')`+`push`만 하면 오늘 탭에 계획 카드가 남지 않는다(H).~~ **정정(plan-audit 2차 N1)**: 탭 바의 `goBranch`로 돌아가면 남는다(X1, X6). **`openTask`는 먼저 지금 쌓인 화면을 모두 닫고(`canPop`인 동안 `pop`) 그다음 `go('/inbox')`+`push`**를 해야 하며, 이렇게 하면 화면이 둘 쌓였거나(Y1), 비서 위에서 시작했거나(Y2), 업무 상세 위에서 [다시 걸기]로 시작해도(Y3) 남는 화면이 없다. 이때 업무 탭은 첫 화면부터 다시 쌓인다(X4, Y2·Y3의 "뒤로 = 업무 첫 화면").
6. **탭 누름은 `goBranch(i)`로 하면 그 탭에 쌓인 화면을 지킨다**(X2 첫 줄). 이미 선택된 탭을 다시 누르면 `goBranch(i, initialLocation: true)`로 첫 화면으로 간다(X2 둘째 줄).

## R2. 기존 테스트 영향 목록

이 SPEC(0.3.0, 토큰·칩은 SPEC-DESIGN-001로 분리)이 바꾸는 동작과 기존 테스트 단언을 대조했다.

| 이 SPEC의 변경 | 확인 방법 | 영향받는 기존 단언 |
|---|---|---|
| 홈 세로 순서·지난 통화 제거(REQ-015) | `grep -rn "지난 통화\|home-intake\|최근 통화한 곳" app/test` | `accessibility_test.dart:614-619`(순서 블록) — **바뀜**. 이 테스트의 데이터 `homeTasks()`(`:41-45`)는 진행 중 1건 + 끝난 2건이라 "확인이 필요해요"가 나오지 않으므로, 바뀐 순서는 그 묶음을 뺀 목록이다(AC-021) |
| 앱 바 제목 `CallMate` → 워드마크, [이대로 시작] 뒤 뒤로 가기 = 업무 첫 화면(REQ-005, REQ-015) | `grep -rn "'CallMate'" app/test` | `plan_card_test.dart:194-196`(뒤로 간 뒤 `CallMate`) — **바뀜**: 기대를 `find.byKey(const Key('tasks-screen'))`로(AC-021과 같음) |
| 상세 맨 위 단계 타임라인(REQ-010) | 상세에서 `findsOneWidget`로 찾는 글자 | `approval_flow_test.dart:52-53`(승인 질문, 대화 한 줄) — **그대로**: 단계 설명은 승인 질문·대화 글을 되풀이하지 않는다(REQ-010, design.md D2) |
| 칩 글자·색 | — | SPEC-DESIGN-001로 이동. `approval_flow_test.dart:45`("승인 대기"), `accessibility_test.dart:560`("상태: 통화 중")은 DESIGN-001이 글자를 유지하므로 그대로 |
| 탭 라벨 "기록"·"내 정보" 추가 | 화면 글자 검색과 겹침 | 기존 테스트에 "기록"·"내 정보" 단언 없음(`grep -rn "'기록'\|'내 정보'" app/test` 결과 없음). 새 테스트는 키로 찾는다 |
| 설정 아이콘·"설정" 제목 | `grep -rn "'설정'" app/test` | `accessibility_test.dart:562`, `intake_flow_test.dart:97` — **그대로**(오늘에 설정 버튼 유지, 탭 라벨에 "설정" 없음) |
| 입력칸·예시 칩·첫 사용 빈 상태 | — | 이 SPEC에서는 유지(OD-2·OD-6). SPEC-ASSIST-001에서 바뀜 |
| 다른 갈래 숨김 화면 | 뒤에 쌓인 갈래의 글자가 `find`에 걸리는가 | `IndexedStack`의 숨은 갈래는 `find`의 기본 `skipOffstage: true`로 빠짐 |
| 쌓인 화면 아래에도 탭 바가 생김 | 탭 바가 화면 높이를 줄여 넘침·대비·누르는 영역 검사가 바뀌는가 | **그대로 통과해야 하는 기존 검사**(바뀌는 블록은 아님, 위험으로 관리): `accessibility_test.dart:132-139`의 화면별 지침 검사 목록, `:402-480`의 큰 글자 2.0 작은 화면 검사(고정 영역 높이 ≤ 320 포함). 깨지면 AC-021대로 plan으로 되돌림 |
| 단계 설명 글자 | 상세의 다른 글자와 겹치는가 | "대기 중"(`call_detail_screen.dart:557`, 승인 기록)과 "취소"(끊기 버튼 `:282`·`:290`)와 겹치지 않게 단계 문구를 정함(design.md D2.3) |
| 오늘 세로 순서(REQ-015) — run M4에서 발견 | 기본 800×600 화면에서 오늘의 글자·행을 찾는가 | `approval_flow_test.dart:36`("귀찮은 전화, 대신 걸어드릴게요"), `:44,47`("라 파스타" 행 누름) — **바뀜**: `pumpApp`을 800×2400·배율 1로 띄움(`tester.view.physicalSize`, `devicePixelRatio`, `addTearDown(tester.view.reset)`). 소유자 결정 2026-11-27 |
| 오늘에서 끝난 작업 제외(REQ-015 / OD-1) — run M4에서 발견 | 끝난 작업의 상세를 오늘 행으로 여는가 | `approval_card_test.dart:45` `openCall`(`:176`이 끝난 작업으로 부름) — **바뀜**: 행 누름 대신 `routerProvider`로 `push('/calls/<id>')`. 소유자 결정 2026-11-27 |
| 오늘 세로 순서(REQ-015) — run M4에서 발견 | 360×640·2배에서 "직접 입력하기"가 화면 안에 있는가 | `font_overflow_test.dart:73-74` — **바뀜**: `scrollUntilVisible('직접 입력하기')` 한 줄. 소유자 결정 2026-11-27 |
| 상세 맨 위 단계 타임라인(REQ-010) — run M4에서 발견 | 360×640·2배 결과 상세에서 결과 카드가 화면 안에 있는가 | `accessibility_test.dart:480` — **바뀜**: `ensureVisible` 앞에 `scrollUntilVisible('다시 걸기')` 한 줄. 소유자 결정 2026-11-27 |

위 마지막 네 행은 plan 단계 표에 없던 깨짐이다. 아래 문단의 규칙대로 run을 멈추고 소유자 결정(2026-11-27, 선택 A)으로 이 표와 AC-021 표에 함께 더했다. 같은 때 깨진 `accessibility_test.dart:223`(대화 자동 따라가기)은 테스트를 고치지 않고 앱의 단계 줄을 한 줄로 줄여 해결했다. 근거는 `progress.md` §E.2 "AC-021 table extended by owner decision 2026-11-27 (option A)".

run 시작 때 같은 명령을 다시 실행해 이 표와 대조한다. 표 밖에서 깨지는 단언이 나오면 조용히 고치지 않고 **다시 plan 단계로 돌아가** 이 표와 AC-021을 고친 뒤 진행한다(plan-audit D1의 "run 중 빠져나갈 구멍" 지적 반영).

## R3. 그 밖에 확인한 사실

- `awaiting_approval`은 통화 전 계획 승인 대기다(`server/src/domain/stateMachine.ts:4`, 앱 `call_models.dart:44`의 `isOngoing`에서 빠짐).
- `CallTask`에는 `transcript`, `approvals`, `outcome`, `updatedAt`, `connectedAt`이 있다(`call_models.dart:270-278`). 단계 계산은 이 필드만 쓴다.
- `pendingApprovalsProvider`(`calls_controller.dart:115-120`)는 작업 상태와 관계없이 `task.pendingApproval`(`call_models.dart:284`, 상태가 `pending`인 승인)이 있는 작업을 모두 센다. 계획 승인 대기(`awaitingApproval`)는 들어가지 않는다(plan-audit D2, 2차 N4).
- 가짜 작업의 기본 상대 이름은 모두 "라 파스타"다(`app/test/support/fakes.dart:20`). 새 테스트는 작업마다 다른 이름을 주거나 키로 찾는다.
