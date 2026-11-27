# Sync 감사 보고서 — SPEC-SHELL-001 (1차)

- 감사 대상: 워크트리 `/Users/jason/Documents/Jason-Danmuzi/wt-shell-001`, 브랜치 `feat/SPEC-SHELL-001`, HEAD `f120cdd`. run 시작 `2fef928`, 구현 커밋 `d030b0b`(M1)·`07565f5`(M2)·`19d58ca`(M3)·`1048911`(M4)·`d99abac`(M5)·`5b15c79`(M6), run 기록 커밋 `b67d452`, sync 커밋 `286a435`, 문구 정리 커밋 `f120cdd`(AC-019·DoD를 확장된 AC-021 표에 맞춤)
- 등급: Tier L (21 REQ / 21 AC). 선례 `SPEC-DESIGN-001-audit-1.md`보다 엄격하게 봤다.
- 평가 프로필: `.moai/config/evaluator-profiles/default.md` (Functionality 40%, Security 25%, Craft 20%, Consistency 15%. 필수 통과 차원은 Functionality와 Security)
- 집계: 차원 점수의 비가중 조화 평균(선례와 같은 방식). 참고용으로 가중 조화 평균도 적는다.
- 감사 방식: 읽기 전용. 아래 명령은 모두 이번 감사에서 이 트리에 직접 실행했다. 임시 파일(커버리지 lcov, 파일 목록 비교)은 세션 scratchpad에만 두었고, 저장소에 쓴 파일은 이 보고서 하나다.
- 상태: 완료

## 1. 판정 요약

| 차원 | 점수 | 판정 | 근거 요약 |
|------|------|------|-----------|
| Functionality (40%) | 90 | PASS | 다섯 테스트·분석 명령을 다시 실행해 모두 기대 결과(앱 `+109`, kolbi_ui `+68`, kolbi_core `+27`, 루트 `+2`, 분석은 기준선 info 1건뿐). AC 21개 모두 테스트·명령에 연결됨. `openTask`가 research R1 결론 5(모두 pop → `go('/inbox')` → push)와 일치. 단계 계산이 design.md D2.2 16행과 모두 일치. 구조 grep 세 개 결과 없음. 감점: 셸 밖 `/assistant`를 첫 화면으로 연 경우의 pop 처리(F1, 코드 읽기로 본 가설) |
| Security (25%) | 93 | PASS | 추가된 줄에 비밀 값 없음. pubspec·`pubspec.lock`·`server/` 변경 없음. 내 정보 탭은 회신 번호를 가운데를 가려 보이며 테스트가 "010-****-5678"을 확인함. `app/lib`의 새 셸·기능 코드에 디버그·테스트 전용 훅 없음 |
| Craft (20%) | 84 | PASS | 셸 코드가 짧고 주석이 이유를 설명함. 새 파일 31/32개 서식 통과. 마일스톤마다 RED 기록 있음. 앱 `lib` 줄 커버리지 92.1%, `shell/` 94.9%. 감점: 비서 화면 "프로필 없음" 경로와 기록 오류 상태가 테스트되지 않음(F2, `history_screen.dart` 83.3%), 키보드가 열렸을 때 높이 계산(F3, 추론), 자정 이후 묶음 기준 시각(F4) |
| Consistency (15%) | 82 | PASS | spec.md는 frontmatter·HISTORY 한 줄만 바뀜. acceptance·research 변경은 소유자 결정 네 행·설명 문단·f120cdd 문구뿐. §E.4의 SHA·52 대 44 파일·계획 밖 9개 목록이 git과 일치. structure·11_ARCHITECTURE·04_DESIGN_PLAN·README·entry-points의 경로·파일 이름이 코드와 일치. 감점: tech.md:47이 이제 사실이 아님(C1), dependencies.md mermaid가 me를 task_feed 사용자로 묶음(C2), 문서 머리 버전 표기(C3) |
| **조화 평균** | **87.0** (가중 88.2) | | |
| **최종 판정** | | **PASS** | 필수 차원(Functionality, Security) 모두 통과. 막는(blocking) 발견 사항 없음 |

## 2. 기준 측정 (이번 감사, 이 트리, HEAD `f120cdd`)

```
$ dart test                                   (저장소 루트)
00:00 +2: All tests passed!

$ cd app && flutter --suppress-analytics test
00:10 +109: All tests passed!

$ cd app && flutter analyze
   info • Use the null-aware marker '?' rather than a null check via an 'if'. Try using '?' • test/support/fakes.dart:54:5 • use_null_aware_elements
1 issue found. (ran in 1.6s)          (기준선 info 1건뿐)

$ cd packages/kolbi_ui && flutter --suppress-analytics test && flutter analyze
00:00 +68: All tests passed!
Analyzing kolbi_ui...
No issues found! (ran in 1.0s)

$ cd packages/kolbi_core && dart test && dart analyze
00:00 +27: All tests passed!
Analyzing kolbi_core...
No issues found!
```

테스트 수는 run 시작 기록(§E.2 사전 점검: 앱 `+88`, kolbi_ui `+63`, kolbi_core `+3`)보다 모두 늘었다(AC-021의 "줄지 않음" 충족).

## 3. Functionality — 90, PASS

### 3.1 AC → 증거 연결

progress.md §E.2 E1 표의 21행을 acceptance.md와 하나씩 대조했다. 모든 AC가 이름이 일치하는 테스트(또는 명령)를 가지며, 그 테스트는 위 `+109` / `+68` / `+27` 실행에 들어 있다.

| AC | 증거(테스트·명령) | 이번 감사에서 직접 본 것 |
|---|---|---|
| AC-001 | shell_test "tab bar shows four tabs and the centre assistant button" | 실행 통과 |
| AC-002 | shell_test "re-tapping the current tab pops to its root, then scrolls to top" | 통과. `_onTab`(tab_scaffold.dart)이 다른 탭 → `goBranch(i)`, 같은 탭·쌓인 화면 → `goBranch(i, initialLocation: true)`, 첫 화면 → 맨 위로 스크롤. research R1 결론 6과 같음 |
| AC-003 | shell_test "tasks badge counts approval requests" | 통과 |
| AC-004 | shell_test "legacy and new locations open the expected screens" + 경로 리터럴 grep | grep 결과 없음(아래 3.4) |
| AC-005 | shell_test "opening a task switches to the tasks tab" | 테스트 본문의 (1)~(7) 일곱 경우를 읽음. 아래 3.2 |
| AC-006 | shell_test "centre button opens the assistant over the current tab" | 통과 |
| AC-007 | kolbi_core task_kind_test, inbox_test "rows are drawn through the registered kind" | `TaskKindCatalog.register`가 중복 id에 `DuplicateTaskKindError`, `resolve(null)` → `call`, 미등록 → `UnknownTaskKind` |
| AC-008 | inbox_test "unknown kinds degrade to a placeholder" | 아래 3.3 |
| AC-009 | kolbi_core task_steps_test(16행 + 문구) | 아래 3.3, 표 16행 직접 대조 |
| AC-010 | inbox_test "task detail shows the six steps above the existing detail", kolbi_ui step_timeline_test | 통과 |
| AC-011 | task_groups_test, inbox_test "tasks tab groups approvals, ongoing and routines" | 통과 |
| AC-012 | inbox_test "empty and error states" | 통과 |
| AC-013 | task_groups_test "in-call approvals agree with pending approvals", shell_test "badge, tasks and today agree", 코드 검토 | 아래 3.5 |
| AC-014 | task_groups_test "history groups by Seoul date", history_test | 통과 |
| AC-015 | today_test 두 테스트 | 통과. 인사 경계(05·11·17시, 서울 기준)를 `home_screen.dart:154-159`에서 확인 |
| AC-016 | today_test "today shortcuts" | 통과 |
| AC-017 | shell_test "me tab lists items and opens settings" | 통과, 4절 가림 처리 |
| AC-018 | architecture_test 6개 + grep 3개 | 아래 3.4 |
| AC-019 | 전체 실행 + diff | 아래 3.6 |
| AC-020 | accessibility_test "shell screens meet the accessibility guidelines" | 아래 3.7 |
| AC-021 | `git diff --stat 2fef928..HEAD -- server/` 비어 있음, app/test diff | 아래 3.6 |

### 3.2 AC-005 — `openTask`와 research R1 규칙

`app/lib/shell/navigation.dart`:

```dart
void openTask(GoRouter router, String taskId) {
  // Bounded: a pop that does not take effect must never spin forever.
  for (var i = 0; i < 32 && router.canPop(); i++) {
    router.pop();
  }
  router.goNamed(RouteNames.inbox);
  router.pushNamed(RouteNames.task, pathParameters: {'id': taskId});
}
```

- 규칙 1 "쌓인 화면을 모두 닫는다": `canPop`인 동안 pop(32회 상한). `/assistant`도 루트 내비게이터에 push되어 있으므로 함께 닫힌다(R1 Y2).
- 규칙 2 "`go('/inbox')` 다음 `push('/calls/<id>')`": 이름 경로 `inbox` = `/inbox`, `task` = `/calls/:id`(app_router.dart 업무 갈래). R1 결론 2·5와 같다.
- 규칙 3 "`/assistant` 위에 탭 경로를 push하지 않는다": `openTask`는 먼저 닫는다. `submitFromAssistant`는 `canPop`이면 닫고 `/plan`을 push한다. 비서 화면의 "프로필 없음" 경로도 `pop()` 뒤 `/settings`를 push한다. 일반 흐름은 규칙을 지킨다. 단, 닫을 화면이 없는 경우는 F1에 적었다.
- 탭 바 누름은 `StatefulNavigationShell.goBranch`(R1 X2)이고, 기능 쪽 `openTab`도 Expando에 등록된 같은 셸로 `goBranch`를 부른다.

테스트 본문에서 (1) 오늘 행, (2) 업무 행, (3) 기록 행, (4) 계획 카드 [이대로 시작] 뒤 `tab-today` → 오늘 첫 화면이고 `PlanCardScreen` 없음, (5) 오늘에서 받은 스낵바 [답하기], (6) 계획 카드 → 설정 → 뒤로 → 시작, (7) 다른 탭에 다녀와도 상세 유지, 다시 누르면 `tasks-screen`을 확인했다. 수락 기준의 일곱 경우와 같다.

### 3.3 AC-008·AC-009 — 모르는 종류, 단계 표 16행

- `CallTask.kind`는 `json['kind'] is String`일 때만 값을 갖고 아니면 null이다(`call_models.dart:233`). null은 `call`로, 미등록 id는 `UnknownTaskKind`로 풀리며 이 클래스는 예외를 던지지 않는다(`task_kind.dart`). `TaskDetailRoute`는 작업을 모를 때 call 표시자의 로딩·없음 화면을 쓴다.
- `taskSteps`(`packages/kolbi_core/lib/src/tasks/task_steps.dart`)의 `switch`를 design.md D2.2 표와 행마다 맞췄다.

| 행 | 표 | 코드 분기 | 일치 |
|---|---|---|---|
| 1 | planning → 지금·대기×5 | `planning => [n,w,w,w,w,w]` | 예 |
| 2 | awaitingApproval → 끝남×2·대기×4 | `[d,d,w,w,w,w]` | 예 |
| 3 | dialing·ringing, 대기 승인 없음 → ③ 지금 | 셋째 분기(대기 승인 없으면 답한 승인과 관계없이) `[d,d,n,w,w,w]` | 예 |
| 4 | inProgress, 둘 다 없음 → ③ 지금 | 같은 분기 | 예 |
| 5 | inProgress, 답한 승인 → ⑤ 지금 | `inProgress when answered => [d,d,d,d,n,w]` | 예 |
| 6 | 통화 세 상태 + 대기 승인 → ④ 지금 | `when pending => [d,d,d,n,w,w]`(먼저 검사) | 예 |
| 7·8 | summarizing, ④ = 답했으면 끝남, 아니면 건너뜀 | `[d,d,d,mine,n,w]` | 예 |
| 9·10·11 | completed, ⑥ = 결과 있으면 끝남, 없으면 대기 | `[d,d,d,mine,d, outcome != null ? d : w]` | 예 |
| 12 | failed, 대화 없음 → ③ 실패 | `[d,d,f,w,w,w]` | 예 |
| 13·14 | failed, 대화 있음 → ⑤ 실패 | `[d,d,d,mine,f,w]` | 예 |
| 15 | canceled, 대화 없음 → ③부터 취소 | `[d,d,c,c,c,c]` | 예 |
| 16 | canceled, 대화 있음 → ④부터 취소 | `[d,d,d,c,c,c]` | 예 |

16행 모두 일치한다. 설명 문구는 docs/planning/04_DESIGN_PLAN.md §17.6 구현 메모와도 같다.

### 3.4 AC-004·AC-018 — 구조 grep (이번 감사에서 실행)

```
$ grep -rnE "\.go\(|goNamed\(|goBranch\(" app/lib/features
(출력 없음, exit 1)

$ grep -rnE "'/(calls|plan|settings|inbox|history|me|assistant)" app/lib/features
(출력 없음, exit 1)

$ grep -rn "GoRouter(" app/lib
app/lib/shell/app_router.dart:22:  final router = GoRouter(
```

기능 코드의 화면 이동은 모두 `pushNamed`(경로 이름)·`pop`이다. architecture_test의 허용 목록은 `<String>{}`이고 `core` → `features`/`shell`은 고정 목록의 `lib/core/router/app_router.dart`(다시 내보내기 한 줄)만 허용한다. `core/router/app_router.dart`와 `features/calls/presentation/trust_notice.dart`는 실제로 `export` 한 줄씩이다.

### 3.5 AC-013 — 승인 요청 판정은 한 곳

```
$ grep -rn "awaitingApproval" app/lib packages/*/lib   (모델 정의 제외)
app/lib/features/calls/presentation/call_detail_screen.dart:146, :200, :282   (상태별 화면 분기)
packages/kolbi_core/lib/src/tasks/task_steps.dart:70                          (단계 표)
packages/kolbi_core/lib/src/tasks/task_groups.dart:52                         (isApprovalRequest)
packages/kolbi_ui/lib/src/widgets/status_chip.dart:38                         (칩 범주, SPEC-DESIGN-001)
```

`awaitingApproval`과 대기 승인을 함께 보는 조합은 `task_groups.dart`의 `isApprovalRequest`뿐이다. `call_task_tile.dart:24`의 `pendingApproval != null`은 칩 표시용이고 묶음 판정이 아니다. `ApprovalListener`는 여전히 `pendingApprovalsProvider`(통화 중 승인)만 보므로 b(계획 승인 대기)에 알림을 띄우지 않는다. 배지·업무·오늘 개수는 모두 `taskGroupsProvider`(`shell/task_feed.dart`)에서 나온다.

### 3.6 AC-019·AC-021 — 테스트 변경 범위

```
$ git diff --stat 2fef928..HEAD -- app/test/
 app/test/accessibility_test.dart    |  84 ++++++-
 app/test/approval_card_test.dart    |   3 +-
 app/test/approval_flow_test.dart    |   3 +
 app/test/architecture_test.dart     |  70 +++++-
 app/test/font_overflow_test.dart    |   1 +
 app/test/history_test.dart          | 166 +++++++++++++
 app/test/inbox_test.dart            | 243 +++++++++++++++++++
 app/test/plan_card_test.dart        |   2 +-
 app/test/shell_test.dart            | 460 ++++++++++++++++++++++++++++++++++++
 app/test/support/shell_support.dart | 240 +++++++++++++++++++
 app/test/today_test.dart            | 173 ++++++++++++++
 11 files changed, 1437 insertions(+), 8 deletions(-)
```

기존 파일마다 `git diff -U0`의 변경 덩어리를 확장된 AC-021 표와 맞췄다.

| 파일 | 실제 변경 | 표 행 | 판정 |
|---|---|---|---|
| plan_card_test.dart | `@@ -196 +196` `find.text('CallMate')` → `find.byKey(const Key('tasks-screen'))` | 2행 | 일치 |
| accessibility_test.dart | `@@ -616 +618,0` "최근 통화한 곳" 이동, `@@ -618 +620` "지난 통화" → "최근 통화한 곳" | 1행 | 일치 |
| accessibility_test.dart | `@@ -479,0 +482` `scrollUntilVisible(find.text('다시 걸기'), …)` 한 줄 | 6행(확장) | 일치 |
| accessibility_test.dart | import 두 줄(`:15`, `:24`), 끝에 새 테스트 78줄(`@@ -651,0 +654,78`) | "새 테스트를 끝에 더하기" 허용 | 허용 범위. 단 import는 표에 이름이 없음(C5) |
| approval_flow_test.dart | `@@ -16,0 +17,3` 800×2400·배율 1·`addTearDown(tester.view.reset)` | 3행(확장) | 일치 |
| approval_card_test.dart | import 한 줄 + `@@ -45 +46` 행 누름 → `routerProvider.push('/calls/${task.id}')` | 4행(확장) | 일치 |
| font_overflow_test.dart | `@@ -73,0 +74` `scrollUntilVisible(manual, …)` 한 줄 | 5행(확장) | 일치 |
| architecture_test.dart | 허용 목록 비움, 옛 경로 두 개·다시 내보내기 목록 고정, 새 테스트 | 표에 없음. plan.md §B 행("허용 목록 비우기, `.go(` 검사")과 AC-018 Given이 요구 | 계획된 변경으로 인정(C5) |

AC-019의 "수정 없이" 목록 가운데 `intake_flow_test`, `follow_up_test`, `trust_notice_test`, `outcome_card_test`, `calls_controller_test`, `unit_test`, `theme_test`는 diff에 없다. `approval_flow_test`·`approval_card_test`는 f120cdd로 고친 AC-019 문구대로 표 행만 바뀌었다. 표 밖의 기존 단언 변경은 없다.

### 3.7 AC-020 — 접근성

테스트 본문을 읽었다. 오늘·업무·기록·내 정보·상세(a) 다섯 화면을 밝은·어두운 모드에서 네 지침(`androidTapTargetGuideline`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline`)으로 검사하고, 360×640·2배에서 `takeException()`이 null인지, 탭 라벨 `Text`가 받는 `TextScaler`의 `scale(14)/14 <= 1.5`인지 확인한다. [승인]은 `ensureVisible` 뒤 눌러 `decisions.single.approve == true`를 본다. 코드에서 라벨 배율은 `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3)`로 묶여 있다(tab_scaffold.dart). 지침 검사 화면 크기가 800×2400인 점은 수락 기준에 크기 지정이 없으므로 허용한다.

## 4. Security — 93, PASS

```
$ git diff --stat 2fef928..HEAD -- '*pubspec*' server/
(출력 없음)        → pubspec.yaml·pubspec.lock·server/ 모두 무변경, 새 의존성 없음

$ git diff 2fef928..HEAD | grep -niE "^\+.*(api[_-]?key|secret|password|token|bearer|BEGIN (RSA|PRIVATE)|sk-[a-z0-9]{10})"
157:+| `kolbi_ui`(Flutter) | `theme/tokens.dart`, ...     (디자인 토큰 파일 이름)
186:+테스트(SPEC-DESIGN-001): ... `tokens_contrast_test.dart` ...
5789:+import '../theme/tokens.dart';   (같은 종류 2건 더)
→ 모두 디자인 "tokens" 파일 이름. 비밀 값 없음

$ grep -rnE "kDebugMode|debugPrint|print\(|@visibleForTesting|assert\(" app/lib/shell app/lib/features/{inbox,history,me} app/lib/core/clock.dart app/lib/core/widgets
(출력 없음)
```

- kolbi_core가 쓰는 `package:meta`는 이미 `packages/kolbi_core/pubspec.yaml:15`(`meta: ^1.19.0`)에 있었고 2fef928의 다른 파일도 쓰고 있었다.
- 회신 번호 가림: `maskCallbackNumber`(`app/lib/features/me/me_screen.dart:11-16`)가 숫자만 남긴 뒤 앞 3자리·뒤 4자리만 보이고 나머지는 `*`로 바꾼다. 8자리 미만이면 전부 `*`다. 화면은 `me_screen.dart:80`에서만 번호를 쓰고 그 값은 가린 값이다. shell_test "me tab lists items and opens settings"가 "010-****-5678"을 확인하며 이번 실행에서 통과했다.
- 테스트 전용 처리(Riverpod 재시도 끄기, `CountingCallsRepository`)는 `app/test/support/shell_support.dart`에만 있고 `app/lib`에는 없다.
- `clockProvider`는 시계를 바꿔 끼우는 공급자일 뿐 외부 입력을 받지 않는다.

감점 사유는 위험이 아니라 확인하지 못한 범위다(웹 빌드의 URL 직접 입력 경로, 8절).

## 5. Craft — 84, PASS

### 5.1 셸 코드 검토

- **Expando 등록부**(`navigation.dart`): 키가 `GoRouter`이고 라우터는 `routerProvider`가 수명을 관리하므로(`ref.onDispose(router.dispose)`) 새는 참조는 없다. 매 빌드 마지막 셸 위젯으로 덮어쓰며, go_router의 `StatefulNavigationShell.goBranch`는 셸 상태를 전역 키로 찾으므로 이전 빌드의 위젯 인스턴스여도 동작한다. 대체 경로 `router.go(tab.path)`(`navigation.dart:35`)는 테스트에서 실행되지 않았다(커버리지 0회). 이 경로는 그 탭에 쌓인 화면을 지키지 못하지만 셸이 그려진 뒤에는 도달하지 않는다.
- **BranchStack**: `IndexedStack` + `Offstage` + `TickerMode` + `HeroMode`. 숨은 갈래의 애니메이션을 멈추고 스낵바 hero 태그 중복을 피한다. 단순하고 이유가 주석에 있다.
- **MediaQuery 높이 덮어쓰기**: 탭 화면에 탭 바 위 높이를 `size`로 주고 아래 여백을 지운다. 승인 카드의 ½·⅔ 상한이 보이는 높이 기준이 되게 하는 의도이며 `approval_flow_test:53`이 수정 없이 통과한다. `viewInsets`는 그대로라서 키보드가 열리면 F3의 여지가 있다.
- **TabScrollScope**: 첫 화면(`ModalRoute.isFirst`)에만 컨트롤러를 주고, 컨트롤러 4개는 `_TabScaffoldState.dispose`에서 해제한다. `updateShouldNotify`는 리스트 동일성 비교이며 리스트는 바뀌지 않으므로 맞다.
- `openTask`의 pop 루프 상한 32는 방어 코드로 이유가 주석에 있다.
- 쓰이지 않는 코드는 찾지 못했다. `RouteNames.newCall` 등 모든 이름이 라우터와 기능 코드에서 쓰인다.

### 5.2 서식

```
$ git diff --name-only --diff-filter=A 2fef928..HEAD -- '*.dart' | xargs dart format --output=none --set-exit-if-changed
Changed app/lib/core/widgets/trust_notice.dart
Formatted 32 files (1 changed) in 0.09 seconds.
```

새 파일 32개 가운데 31개가 서식 통과다. 남은 하나는 `features/calls/presentation/trust_notice.dart`를 옮긴 파일로, 옛 파일과 비교하면 import 경로 한 줄만 다르다(`diff` 결과 `5c5`). 옮긴 파일을 그대로 둔 것은 이해되지만 §E.2 E5의 "새 파일은 서식 적용"과는 어긋난다(C6). 고친 기존 파일 14개는 2fef928에서도 서식 밖이었고 손으로 고쳤다고 E5에 기록되어 있다(메모리 규칙 "프로젝트 전체 format 금지"와 일치).

### 5.3 RED 기록

`.moai/state/verify/SPEC-SHELL-001/red/`에 8개 파일(합계 792줄)이 있다. 예: `m2_shell.txt` "Error when reading 'lib/shell/navigation.dart': No such file or directory", `m5.txt` "Some tests failed.". 마일스톤마다 GREEN 전 실패가 남아 있다.

### 5.4 커버리지 (이번 감사에서 측정)

```
$ cd app && flutter --suppress-analytics test --coverage --coverage-package callmate \
    --coverage-package kolbi_core --coverage-package kolbi_ui --coverage-path=<scratchpad>/lcov.info
00:11 +109: All tests passed!
```

| 범위 | 덮인 줄 / 전체 | 비율 |
|---|---|---|
| 앱 `lib` 전체 | 1509 / 1639 | 92.1% |
| `app/lib/shell/` | 262 / 276 | 94.9% |
| `features/inbox/` | 71 / 73 | 97.3% |
| `features/history/` | 40 / 48 | 83.3% |
| `features/me/` | 81 / 81 | 100% |
| kolbi_core `src/tasks/`(앱 실행 기준) | 91 / 97 | 93.8% |
| kolbi_ui `step_timeline.dart` | 45 / 45 | 100% |

덮이지 않은 줄: `history_screen.dart:44-54, 81`(오류·재시도 상태), `assistant_placeholder.dart:41-42`(프로필 없음 → 닫고 설정), `:87`, `:125-129`, `navigation.dart:35`(대체 `go`), `task_feed.dart:33-34`(당겨서 새로고침). 프로필 기준 85%는 앱 전체와 셸에서 넘지만 `history_screen.dart` 한 파일은 밑돈다(F2). kolbi_core `src/kinds/`는 앱 실행 기준 50%로 보이나 이는 kolbi_core 자체 `dart test`(task_kind_test 3개)가 덮는 부분이라 감점하지 않았다.

## 6. Consistency — 82, PASS

- **spec.md**(`git diff 2fef928..HEAD`): `version` 0.3.1 → 0.3.2, `status` draft → implemented, `updated` 2026-11-26 → 2026-11-27, HISTORY 0.3.2 한 줄. 본문 변경 없음. 요청된 범위와 같다.
- **acceptance.md**: AC-021 표 네 행, 표 확장 설명 문단, AC-019 단서 한 문장과 DoD 한 줄(f120cdd). 그 밖의 본문 변경 없음.
- **research.md**: R2 표 네 행과 설명 문단 한 개(+6줄). 그 밖의 변경 없음.
- **§E.4와 git**: run_start `2fef928`, M1~M6 SHA, run 기록 `b67d452`가 `git log`와 같다. 계획 대 실제 파일 수를 직접 셌다. `git diff --name-only 2fef928..5b15c79 | wc -l` → 52. plan.md §B 표 39행(여러 파일 행을 펼치면 44개)과 대조하면 계획 밖은 `spec.md`, `call_task_tile.dart`, `task_feed.dart`, `call_models.dart`, `approval_card_test`·`approval_flow_test`·`font_overflow_test`, `app/test/support/shell_support.dart`, `kolbi_core/test/support/tasks.dart`의 9개이고, 계획했지만 안 바뀐 파일은 `app/lib/app.dart` 하나다. §E.4의 "43 planned + 9 unplanned, app.dart unchanged"와 정확히 같다.
- **문서 주장과 코드**: structure.md·11_ARCHITECTURE.md §2.5의 경로 표(경로·이름·갈래 9행)가 `shell/app_router.dart`와 같다(`/settings`는 내 정보 갈래, `/calls/:id`는 업무 갈래). 네 이동 함수 설명이 `navigation.dart`와 같다. 04_DESIGN_PLAN.md §17.2 인사 경계와 §17.6 단계 문구가 `home_screen.dart:154-159`, `task_steps.dart`와 같다. README의 폴더 트리(`shell/`, `inbox/`, `history/`, `me/`)와 entry-points.md의 `registerKolbiFontLicenses()` 단계가 코드와 같다. 11_ARCHITECTURE의 `task_detail`·`results`는 "아직 없다"고 명시되어 있어 틀린 주장이 아니다.
- **EPIC overview**: SHELL-001 줄과 상태 문장 속 SHELL 표기만 바뀌었다. 같은 문장의 DESIGN-001 `implemented` 표기는 이 SPEC 전부터 있던 것이라 이번 범위 밖이다.
- 감점: C1(tech.md:47), C2(mermaid), C3(문서 머리 버전), C5·C6(표·기록의 문구 빈틈).

## 7. 발견 사항

막는(blocking) 항목은 없다. 확신도는 높음/중간/낮음으로 적는다.

| ID | 심각도 | 차원 | 확신도 | 내용 | 권장 조치 |
|---|---|---|---|---|---|
| F1 | 중간(비차단) | Functionality | 중간(코드 읽기, 실행 안 함) | `/assistant`가 내비게이터의 첫 화면일 때(웹에서 URL 직접 입력, 딥링크) 닫을 화면이 없다. 닫기 버튼 `GoRouter.of(context).pop()`(`assistant_placeholder.dart:63`)과 프로필 없음 경로의 `router.pop()`(`:41`)은 go_router에서 "nothing to pop" 오류가 될 수 있다. `submitFromAssistant`는 `canPop`이 거짓이면 닫지 않고 `/plan`을 push하므로 research R1-G의 assert 조건에 해당한다. 일반 흐름(가운데 버튼)에서는 생기지 않는다 | `canPop`이 거짓이면 먼저 `goNamed(today)`(또는 오늘 갈래)로 보내고 push한다. `/assistant`로 시작하는 위젯 테스트 하나를 더한다. SPEC-ASSIST-001이 이 화면을 바꿀 때 함께 처리해도 된다 |
| F2 | 낮음 | Craft | 높음 | 테스트되지 않은 분기: 비서 화면 프로필 없음 경로(`assistant_placeholder.dart:41-42`), 기록 탭 오류·[다시 시도](`history_screen.dart:44-54`). `history_screen.dart` 줄 커버리지 83.3%로 프로필 기준 85% 밑 | 기록 오류 상태와 비서 프로필 없음 경로의 위젯 테스트를 더한다 |
| F3 | 낮음 | Craft | 낮음(추론, 기기 미확인) | `TabScaffold`는 Scaffold가 아니라서 키보드가 열려도 탭 바 영역이 줄지 않는다. 안쪽 화면 Scaffold는 전체 화면 기준 `viewInsets.bottom`(키보드 높이)을 그대로 빼므로, 키보드 위에 탭 바 높이(약 57px)만큼 빈칸이 생길 수 있다 | 기기에서 입력칸(오늘·직접 입력)에 키보드를 띄워 확인한다. 필요하면 덮어쓴 MediaQuery의 `viewInsets.bottom`에서 탭 바 높이를 뺀다 |
| F4 | 낮음 | Craft | 중간 | `taskGroupsProvider`·`historyDaysProvider`(`shell/task_feed.dart:16-27`)는 다시 계산될 때만 시계를 읽는다. 앱을 켠 채 자정을 넘기면 작업 목록이 바뀔 때까지 "오늘 완료" 수와 기록의 "오늘/어제" 묶음이 전날 기준이다 | 날짜가 바뀔 때 무효화하는 타이머나 앱 재개 시 무효화를 고려한다. 지금 범위에서는 기록만 해도 된다 |
| F5 | 정보 | Craft | 높음 | `openTab`의 대체 경로 `router.go(tab.path)`(`navigation.dart:35`)는 실행되지 않으며, 실행되면 그 탭에 쌓인 화면을 버린다 | 셸 등록 전에는 탭 전환이 없다는 가정을 주석에 적거나 assert로 남긴다 |
| C1 | 중간(비차단) | Consistency | 높음 | `.moai/project/tech.md:47`이 "`registerKolbiFontLicenses()`를 부르는 한 줄은 … 앱에는 아직 들어가지 않았다(`grep -rn registerKolbiFontLicenses app/lib` 결과 없음)"라고 한다. 지금은 `app/lib/main.dart`가 이 함수를 부른다. sync가 tech.md를 고치지 않았다(diff 목록에 없음). SPEC-DESIGN-001 감사 F4가 "SHELL-001 sync에서 확인"하라고 넘긴 항목이다 | tech.md:47을 "main.dart가 `runApp` 전에 호출한다(SPEC-SHELL-001)"로 고친다(modules.md:152와 같은 문구) |
| C2 | 낮음 | Consistency | 높음 | `.moai/project/codemaps/dependencies.md` mermaid `tabs[features/inbox · history · me] --> feed[shell/task_feed · kind_registration]`. `me_screen.dart`는 `shell/routes.dart`·`shell/tab_scaffold.dart`만 가져오고 task_feed·kind_registration은 쓰지 않는다(`grep -rln task_feed app/lib` → tab_scaffold, home_screen, inbox_screen, history_screen). 또 `features/calls/presentation/home_screen.dart`도 task_feed를 쓰는데 그림에 없다 | 노드를 `inbox · history`와 `me`로 나누고, home(calls) → task_feed 선을 더한다 |
| C3 | 낮음 | Consistency | 높음 | acceptance.md 제목이 "(0.3.1)"이고 research.md 제목도 "(0.3.1, plan-phase)"인데, 두 파일 모두 0.3.2 주석이 들어갔고 spec은 0.3.2다 | 두 제목을 0.3.2로 맞춘다 |
| C4 | 정보 | Consistency | 높음 | sync 커밋에서 acceptance.md·research.md 본문을 고쳤다. 스키마의 소유권 규칙상 본문은 manager-spec 몫이며 §E.4에 "acting as manager-spec, owner decision 2026-11-27"로 기록되어 있다. 소유자 결정과 HISTORY가 있으므로 문제로 보지 않으나, 다음부터는 별도 manager-spec 커밋으로 나누면 추적이 쉽다 | 기록만 |
| C5 | 정보 | Consistency | 높음 | AC-021 표에는 `architecture_test.dart` 변경과 `accessibility_test.dart` import 두 줄이 없다. 전자는 plan §B·AC-018이, 후자는 "새 테스트를 끝에 더하기" 허용이 덮는다. 표만 읽으면 범위 밖으로 보인다 | 다음 SPEC부터 표 머리에 "AC-018이 요구하는 architecture_test 변경과 새 테스트용 import는 별도 허용" 한 줄을 둔다 |
| C6 | 정보 | Craft/Consistency | 높음 | §E.2 E5는 새 파일을 서식 적용했다고 하지만 옮긴 `app/lib/core/widgets/trust_notice.dart`는 `dart format`이 바꾸는 상태다(옛 파일 그대로 옮김) | 기록을 "옮긴 파일은 서식 미적용"으로 고치거나, 이 파일만 서식을 적용한다 |

보안(Security) 차원의 발견은 없다.

## 8. 검증하지 않은 것

- 실제 기기 실행(탭 바, 큰 글자, Pretendard 굵기, 키보드). §E.4도 `device_check: pending`이다. F3는 이 때문에 추론으로 남겼다.
- 웹 빌드에서 `/assistant`를 URL로 직접 연 경우(F1). 테스트 파일을 더하는 것은 읽기 전용 범위 밖이라 실행하지 않았다.
- 서버 테스트(`npm test`)는 다시 돌리지 않았다. `server/` diff가 비어 있는 것만 확인했다.
- 오케스트레이터의 브라우저 점검(§E.4 `browser_check_observations`)은 다시 하지 않았다.
- go_router 버전을 올렸을 때의 동작(acceptance 잔여 위험). 이번 감사는 18.1.4 잠금 상태만 봤다.
- 커밋 메시지 형식과 pre-commit 훅 수정(`.git/hooks/pre-commit`, 저장소 밖 파일)은 보지 않았다.
- kolbi_core의 `src/kinds/` 커버리지는 앱 실행 기준으로만 쟀다. kolbi_core 자체 `dart test`의 커버리지는 따로 재지 않았다.

## 9. 점수 계산

- 비가중 조화 평균: 4 / (1/90 + 1/93 + 1/84 + 1/82) = **87.0**
- 가중 조화 평균(참고): 1 / (0.40/90 + 0.25/93 + 0.20/84 + 0.15/82) = **88.2**
- 필수 차원 Functionality 90, Security 93 모두 PASS. Tier L 기준(plan 단계와 같은 0.85)도 넘는다 → **최종 PASS**
- 권장: C1(tech.md 한 줄)은 sync 마무리 커밋에서 고치고, F1은 SPEC-ASSIST-001 또는 후속 작은 수정으로 처리한다. 나머지는 기록으로 충분하다.
