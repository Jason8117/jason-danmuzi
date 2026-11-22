# SPEC-APPROVAL-001 진행 기록

## §E.1 Plan-phase Audit-Ready Signal

- plan_status: revised after plan-audit iteration 1 (PASS-with-fixes 0.86; D1, D2 fixed, D3, D4 applied) — re-audit pending
- spec_version: 0.3.0 (plan-audit iteration 2: PASS 0.92; N1 fixed — sensitive chains of 13+ digits masked with no upper bound, hyphenated domestic phone tokens exempt)
- plan_complete_at: 2026-11-21
- base_sha: c664596
- tier: M, harness: standard (recommended)
- artifacts: spec.md, plan.md, acceptance.md, research.md, progress.md
- counts: 16 REQ / 15 AC
- depends_on: (none) — first SPEC of EPIC-ASSISTANT-UX; related_specs: SPEC-POLICY-001, SPEC-OUTCOME-001, SPEC-ARCH-001, SPEC-LIFECYCLE-001
- open_decisions: OD-1, OD-2, OD-3, OD-4 DEFAULT (pending owner review)
- note: one existing app test line changes by design (`app/test/approval_flow_test.dart:55`, label text) — AC-014
- release note: server and app ship in the same release
- run-entry note: manager-develop records `run_start_sha` (HEAD at run entry) and the measured test baseline as the first lines of §E.2

## §E.2 Run-phase Evidence

- run_start_sha: cd1f77e2f00cb78c355d40b6ff5b1d36b9a4fc51
- cycle_type: tdd, harness: standard
- 작업 위치: 격리 worktree 브랜치 `worktree-agent-af5214d1d7c64f509` (push 없음)
- 증거 파일: `.moai/state/verify/run-approval/approval/` (아래 명령의 원문 출력)

### 기준선 (run 시작 시점, cd1f77e)

| 항목 | 명령 | 관찰 결과 |
|------|------|-----------|
| 서버 테스트 | `npm --prefix server test` | `Test Files  12 passed (12)` / `Tests  246 passed (246)`, exit 0 (`baseline-server-test.txt`) |
| 타입 검사 | `npm --prefix server run typecheck` | exit 0 (`baseline-typecheck.txt`) |
| 테스트 파일 컴파일 | 임시 `tsconfig.tests.tmp.json`(`extends ./tsconfig.json`, `noEmit`, `exclude: []`)로 `npx tsc -p` 후 임시 파일 삭제 | exit 0, 출력 없음 (`baseline-testcompile.txt`) |
| 앱 테스트 | `cd app && flutter --suppress-analytics test` | `00:00 +17: All tests passed!`, exit 0 (`baseline-flutter-test.txt`) |
| 앱 분석 | `cd app && flutter --suppress-analytics analyze` | `1 issue found` — `info • ... • test/support/fakes.dart:53:5 • use_null_aware_elements` (기준선, exit 1) (`baseline-flutter-analyze.txt`) |

### M1 — 정제 규칙 (AC-002, AC-003)

- RED: `npm --prefix server test -- src/domain/approvalComment.test.ts` → `FAIL src/domain/approvalComment.test.ts` / `Error: Cannot find module './approvalComment.js'` / `Test Files  1 failed (1)`, exit 1 (`m1-red.txt`)
- GREEN: 같은 명령 → `Test Files  1 passed (1)` / `Tests  24 passed (24)`, exit 0 (`m1-green.txt`) — AC-002 7행 + 자리표시 상수·행 수 1건 + AC-003 16행
- 파일: `server/src/domain/approvalComment.ts`(신규), `server/src/domain/approvalComment.test.ts`(신규)
- spec.md frontmatter `status: draft → in-progress`, `updated: 2026-11-22`

### M2 — 서비스 적용과 안내 줄 (AC-004, AC-005, AC-006)

- RED: `npm --prefix server test -- src/services/callService.test.ts src/http/app.test.ts` → `Tests  7 failed | 63 passed (70)`, exit 1 (`m2-red.txt`). 실패 7건: AC-004 (B) 승인·거절 2건(`expected { approved: true, …(2) } to deeply equal …` — 원문 그대로 전달), AC-004 (A) `expected '카드 1234 5678 9012 3456 말고 계좌이체' to be '카드 [민감정보 삭제] 말고 계좌이체'`, AC-006 (1) `expected [] to deeply equal [ '사용자 안내: 1만 원까지만' ]`, (2) `expected [] to deeply equal [ 'User guidance: up to 10,000 won' ]`, (4) 안내 줄 없음, (5) 제어 문자만 있는 코멘트가 그대로 전달됨.
- 처음부터 통과(보호): AC-005 "never logs approval comments"(서비스가 코멘트를 로그에 쓰지 않음을 고정), AC-006 (3) 만료(`comment` 값 `undefined`, `status: expired`, 안내 줄 없음), (5) 코멘트 없는 승인, (6) 시뮬레이션 1줄(당시에는 제공자만 줄을 씀).
- 중복 회귀 확인: 서비스 줄 추가 후 제공자 줄을 지우기 전 같은 명령 → `× records the guidance line once in a simulated call` / `AssertionError: expected [ { …(4) }, { …(4) } ] to have a length of 1 but got 2`, exit 1 (`m2-dup-red.txt`)
- GREEN: `simulatedProvider.ts`의 자체 안내 줄 삭제 후 같은 명령 → `Test Files  2 passed (2)` / `Tests  70 passed (70)`, exit 0 (`m2-green.txt`). 전체 `npm --prefix server test` → `Test Files  13 passed (13)` / `Tests  281 passed (281)`, exit 0 (`m2-full.txt`). typecheck exit 0.
- `grep -rn "사용자 안내" server/src` → 구현은 `server/src/services/callService.ts:69`(접두어 상수) 한 곳, 나머지는 테스트(`app.test.ts:275`, `callService.test.ts:638,639,677`). 시뮬레이션 제공자에서 사라짐.
- `git diff cd1f77e -- server/src/http/app.ts` → 출력 없음(요청 로그 직렬화기 무변경, AC-005 참고).
- 파일: `server/src/services/callService.ts`, `server/src/services/callService.test.ts`, `server/src/providers/simulatedProvider.ts`, `server/src/http/app.test.ts`(새 테스트만 추가)

### M3 — 통화 지시문 규칙 7 (AC-008)

- RED: `npm --prefix server test -- src/brain/prompts.test.ts` → `× tells the agent how to follow a user_comment` / `AssertionError: expected false to be true`(규칙 7 없음), `Tests  1 failed | 5 passed (6)`, exit 1 (`m3-red.txt`)
- GREEN: 같은 명령 → `Tests  6 passed (6)`, exit 0 (`m3-green.txt`). 기존 5개 테스트는 수정 없이 통과. 전체 → `Test Files  13 passed (13)` / `Tests  282 passed (282)`, exit 0 (`m3-full.txt`)
- 규칙 7 문장은 영어, 자리표시는 `SENSITIVE_PLACEHOLDER` 상수를 가져와 쓴다(문구 중복 없음). 규칙 1~6 문구 무변경.
- 파일: `server/src/brain/prompts.ts`, `server/src/brain/prompts.test.ts`

### M4 — 승인 카드 (AC-009 ~ AC-014)

- RED (`cd app && flutter --suppress-analytics test test/approval_card_test.dart test/approval_flow_test.dart test/unit_test.dart`, exit 1, `m4-red.txt`):
  - `unit_test.dart` 컴파일 실패 `Error: Method not found: 'withQuickReply'.`(앱 규칙 파일 없음)
  - AC-009 `Found 0 widgets with text "금액이 더 나오면 거절해 주세요"`, AC-010 `Found 0 widgets with text "조건 덧붙이기 (선택)"`, AC-011 `Found 0 widgets with text "카드번호처럼 보이는 숫자는 지우고 보낼게요."`
  - AC-014 라벨 한 줄 교체 직후 `approval_flow_test.dart`: `Found 0 widgets with text "조건 덧붙이기 (선택)"`
- 처음부터 통과(보호, 옛 카드 코드에서 `approval_card_test.dart`만 다시 실행, `m4-red-card.txt`: `+2 -3`): AC-012(실패 시 코멘트·버튼 유지, 현행 `approval_card.dart` 동작), AC-013(승인 이력 "안내: …"와 `system` 줄이 말풍선 라벨 없이 표시됨).
- AC-012 테스트 주의: 목록 화면이 승인 요청을 12초 스낵바로 알리므로(`approval_listener.dart`), 오류 스낵바가 그 뒤에 줄을 선다. 테스트는 카드 동작만 보도록 알림 스낵바를 먼저 지운다(`scaffoldMessengerKey.currentState!.removeCurrentSnackBar()`).
- 중간 실패와 대응: 칩을 `Wrap`(2줄)으로 두었을 때 하단 고정 카드가 370px로 커져 800×600 기본 테스트 화면에서 기존 `approval_flow_test.dart`가 대화 줄을 찾지 못했다(`Actual: _TextWidgetFinder:<Found 0 widgets with text "네, 라 파스타입니다.": []>`, `+20 -1`; 이 첫 실행 파일은 재실행으로 덮어써져 원문은 여기 인용만 남음). 임시 측정 테스트(`card=Size(688.0, 370.0)`, 상세 목록 높이 92px; 측정 후 파일 삭제)로 원인을 확인하고, 칩을 가로 스크롤 한 줄로 바꿔 카드 318px·목록 144px로 줄였다. 기존 테스트 본문은 바꾸지 않았다.
- GREEN: 같은 명령 → `00:01 +21: All tests passed!`, exit 0 (`m4-green.txt`). 전체 `flutter --suppress-analytics test` → `00:01 +25: All tests passed!`, exit 0 (`m4-flutter-full.txt`). `flutter --suppress-analytics analyze` → `1 issue found`(기준선과 같은 `test/support/fakes.dart:53:5 • use_null_aware_elements` 1건) (`m4-analyze.txt`)
- AC-014: `git diff cd1f77e -- app/test/approval_flow_test.dart` → `-    expect(find.text('조건·안내 (선택)'), findsOneWidget);` / `+    expect(find.text('조건 덧붙이기 (선택)'), findsOneWidget);` 한 줄 교체만. `fakes.dart`·`unit_test.dart`는 추가만.
- 파일: `app/lib/features/calls/domain/approval_comment.dart`(신규), `app/lib/features/calls/presentation/widgets/approval_card.dart`, `app/test/approval_card_test.dart`(신규), `app/test/support/fakes.dart`, `app/test/approval_flow_test.dart`, `app/test/unit_test.dart`

## §E.3 Run-phase Audit-Ready Signal

_<pending run-phase>_

## §E.4 Sync-phase Audit-Ready Signal

_<pending sync-phase>_
