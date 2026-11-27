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

### M5 — 도구 결과·입력 경계 보호 테스트 (AC-007, AC-001)

- 보호 테스트(현행 고정)라 RED 없음. 고정 대상 코드가 run 시작 이후 그대로임을 확인: `git diff --stat cd1f77e -- server/src/http/schemas.ts server/src/http/app.ts server/src/providers/realtimeBridge.ts server/src/domain/types.ts …` → 출력 없음.
- 실행: `npm --prefix server test -- src/providers/realtimeBridge.test.ts src/http/app.test.ts` → `Test Files  2 passed (2)` / `Tests  55 passed (55)`, exit 0 (`m5.txt`)
  - AC-007 "returns every approval decision shape as tool output" 5건: 키가 정확히 `approved`·`instruction`·`reason`·`user_comment`, `user_comment`는 (a)(c)만 문자열, 다섯 경우 문구 + "never share card/password/SSN", 뒤이어 `response.create`. 기존 테스트 (e)는 무수정.
  - AC-001 "counts approval comment length in code points" 6건: (1)(2)(3)(5) 200, (4)(6) 400.
- 첫 실행에서 (4)(6)이 `expected { error: 'invalid_request', …(1) } to deeply equal { error: 'invalid_request' }`로 실패했다. 현재 400 본문은 `{ error: "invalid_request", message: <스키마 메시지> }`(`server/src/http/app.ts:124`)라 AC-001의 `{"error":"invalid_request"}`는 오류 코드 표기로 읽고 `toMatchObject({ error: "invalid_request" })`로 단언했다. 서버 동작은 바꾸지 않았다(현행 고정).
- 파일: `server/src/providers/realtimeBridge.test.ts`, `server/src/http/app.test.ts`(새 테스트만 추가)

### M6 — 회귀 확인 (AC-015), HEAD 594e810 기준

| 항목 | 명령 | 관찰 결과 |
|------|------|-----------|
| 서버 전체 테스트 | `npm --prefix server test` | `Test Files  13 passed (13)` / `Tests  293 passed (293)`, exit 0 (기준선 12/246 → 신규 파일 1·테스트 47) (`m6-server-test.txt`) |
| 타입 검사 | `npm --prefix server run typecheck` | exit 0 (`m6-typecheck.txt`) |
| 테스트 파일 컴파일 | 기준선과 같은 임시 tsconfig로 `npx tsc -p`, 실행 후 삭제 | exit 0, 출력 없음 (`m6-testcompile.txt`) |
| 구조 규칙 | `npm --prefix server test -- src/architecture.test.ts` | `Tests  4 passed (4)`, exit 0. `git diff cd1f77e -- server/src/architecture.test.ts` 출력 없음 (`m6-architecture.txt`) |
| 앱 전체 테스트 | `cd app && flutter --suppress-analytics test` | `00:01 +25: All tests passed!`, exit 0 (기준선 +17 → +25) (`m6-flutter-test.txt`) |
| 앱 분석 | `cd app && flutter --suppress-analytics analyze` | `1 issue found` — 기준선과 같은 `test/support/fakes.dart:53:5 • use_null_aware_elements` (`m6-flutter-analyze.txt`) |
| 변경 범위 | `git diff --stat cd1f77e..HEAD` | 17 files, 800 insertions(+), 20 deletions(-): plan.md §B의 15개 파일 + `spec.md`(frontmatter) + `progress.md`. 그 밖의 파일 없음 |

### AC 판정표

| AC | 판정 | 근거(테스트 / 관찰) | RED |
|----|------|------|-----|
| AC-001 | PASS | `app.test.ts` "counts approval comment length in code points" 6건 통과 (M5) | 보호 테스트(처음부터 통과) |
| AC-002 | PASS | `approvalComment.test.ts` "sanitizes control characters and line breaks" 7건 (M1) | 모듈 없음 `Cannot find module './approvalComment.js'` |
| AC-003 | PASS | 같은 파일 "masks card- and ID-shaped digit runs" 16행 (M1); 앱 `unit_test.dart` "detects sensitive digit runs like the server"가 같은 16행을 씀 (M4) | 위와 같음 / 앱: `Method not found: 'withQuickReply'` |
| AC-004 | PASS | (A) `app.test.ts` "stores the masked approval comment", (B) `callService.test.ts` "resolves the approval with the sanitized comment" 승인·거절 (M2) | 원문 그대로 저장·전달(`expected '카드 1234 5678 9012 3456 말고 계좌이체' to be …`) |
| AC-005 | PASS | `callService.test.ts` "never logs approval comments"; `git diff cd1f77e -- server/src/http/app.ts` 출력 없음 | 보호 테스트 |
| AC-006 | PASS | (1)~(5) `callService.test.ts` "CallService guidance line", (6) `app.test.ts` "records the guidance line once in a simulated call" | (1)(2)(4) `expected [] to deeply equal [ '사용자 안내: …' ]`; (6) 중복 회귀 `to have a length of 1 but got 2`; (3)(5) 보호 |
| AC-007 | PASS | `realtimeBridge.test.ts` "returns every approval decision shape as tool output" 5건 (M5) | 보호 테스트 |
| AC-008 | PASS | `prompts.test.ts` "tells the agent how to follow a user_comment"; 기존 5개 무수정 통과 (M3) | `expected false to be true`(규칙 7 없음) |
| AC-009 | PASS | `approval_card_test.dart` "quick replies fill the comment without sending" (M4) | `Found 0 widgets with text "금액이 더 나오면 거절해 주세요"` |
| AC-010 | PASS | 같은 파일 "comment field starts as one line and counts code points" | `Found 0 widgets with text "조건 덧붙이기 (선택)"` |
| AC-011 | PASS | 같은 파일 "warns about card-shaped numbers without blocking" | `Found 0 widgets with text "카드번호처럼 보이는 숫자는 지우고 보낼게요."` |
| AC-012 | PASS | 같은 파일 "keeps the comment when sending fails" | 보호 테스트 |
| AC-013 | PASS | 같은 파일 "shows the guidance in history and transcript" | 보호 테스트 |
| AC-014 | PASS | `approval_flow_test.dart` 통과; 해당 파일 diff는 라벨 한 줄 교체뿐 | 교체 직후 `Found 0 widgets with text "조건 덧붙이기 (선택)"` |
| AC-015 | PASS | 위 M6 표 | — |

### 커밋

| 마일스톤 | SHA |
|----------|-----|
| M1 | d961e1b82f94f13886a82bb4a4d1170dc84419e9 |
| M2 | 1d8eac47c892f15c64b1d9c74783608a31f21b10 |
| M3 | 8fe99041b1d69166dfc9a6cbca072e0fe7395cc9 |
| M4 | 166d7c3bdd784f1123805157086324c5b4ad2af2 |
| M5 | 594e810d105e8dff5b6a3bd9c079b5213fe78eb1 (마지막 구현 커밋) |
| M6 | 이 기록만 담은 증거 커밋(구현 변경 없음) |

### 검증하지 않은 것

- 실제 OpenAI Realtime·KAT에는 연결하지 않았다. 서버 테스트는 가짜 소켓, `InMemoryTaskStore`, 시뮬레이션 제공자, Fastify `inject`만 썼다.
- AI가 실제 통화에서 `user_comment`와 규칙 7을 따르는지는 자동으로 검증되지 않는다(acceptance.md 잔여 위험). 검증한 것은 지시문 문구와 도구 결과 형태, 대화 기록 안내 줄까지다.
- 실기기(작은 화면, 키보드가 올라온 상태)에서 하단 고정 카드의 높이와 가로 스크롤 칩 동작은 보지 않았다. 위젯 테스트는 800×600(기존 흐름 테스트)과 800×2400(새 테스트) 화면에서만 돌렸다.
- 한국어 IME 조합 중 500 코드 포인트 경계 동작은 위젯 테스트로 재현하지 않았다(조합 중에는 자르지 않고, 다음 편집과 전송 시 자름).

### 계획 감사 권고 메모 (manager-spec 후속용, 이 SPEC 본문은 바꾸지 않음)

- A1-1: plan.md §A.1의 민감 숫자열 판정 항목 머리말이 "두 단계"라고 쓰지만 실제로 (1)(2)(3) 세 단계를 나열한다. 구현은 spec.md REQ-003의 세 단계를 따랐다.
- A1-2 (잔여 위험, 관찰됨): 공백 하나로 이어 쓴 날짜 두 개는 숫자 16개 조각이 되어 가려진다. `sanitizeApprovalComment("2026-11-21 2026-11-22")` → `"[민감정보 삭제]"` (`m1-advisories.txt`).
- A1-3 (잔여 위험, 관찰됨): 카드번호 두 토막 사이에 하이픈 전화번호 토큰이 끼면 양쪽 조각이 각각 8자리라 가려지지 않는다. `sanitizeApprovalComment("4111 1111 010-1234-5678 1111 1111")` → 입력 그대로 (`m1-advisories.txt`). 앱 경고도 같은 규칙이라 뜨지 않는다.

## §E.3 Run-phase Audit-Ready Signal

```yaml
run_complete_at: 2026-11-22
run_start_sha: cd1f77e2f00cb78c355d40b6ff5b1d36b9a4fc51
run_commit_sha: 594e810d105e8dff5b6a3bd9c079b5213fe78eb1  # last implementation commit (M5); the M6 evidence-only commit follows it
run_status: complete
ac_pass_count: 15
ac_fail_count: 0
preserve_list_post_run_count: 0  # plan.md §B "바꾸지 않는 파일" 7개 모두 git diff 출력 없음
l44_pre_commit_fetch: not-run  # isolated worktree, no push by instruction
l44_post_push_fetch: not-applicable  # no push
new_warnings_or_lints_introduced: 0  # flutter analyze 1 info = baseline; tsc exit 0
cross_platform_build:
  server_typecheck: pass
  server_test_files_compile: pass
  flutter_test: pass
  flutter_analyze: baseline-equal
total_run_phase_files: 17  # 15 planned files + spec.md + progress.md
m1_to_mN_commit_strategy: one commit per milestone M1..M5 (code + progress), M6 evidence-only
```

## §E.4 Sync-phase Audit-Ready Signal

```yaml
sync_complete_at: 2026-11-27
sync_commit_sha: "the docs(SPEC-APPROVAL-001) sync commit that adds this section (resolve via git log)"
sync_status: implemented
run_commit_sha: 594e810d105e8dff5b6a3bd9c079b5213fe78eb1   # §E.3 value: last implementation commit (M5) on worktree branch worktree-agent-af5214d1d7c64f509
run_commit_sha_on_main: 9bc7332   # the same M5 landed on main as 9bc7332 (git diff --quiet 594e810 9bc7332 -> exit 0, identical tree); M6 evidence commit 678274e -> 42e2f16 on main
run_start_sha: cd1f77e2f00cb78c355d40b6ff5b1d36b9a4fc51   # on main (git merge-base --is-ancestor cd1f77e 8ad8239 -> true)
sync_evidence_source: orchestrator   # measured by the orchestrator on HEAD 8ad8239 on 2026-11-27, not by this agent; evidence under .moai/state/verify/coverage/ (gitignored, local only)
app_tests_at_sync: "00:08 +84: All tests passed!"   # cd app && flutter --suppress-analytics test --coverage
app_line_coverage_at_sync: "1497/1689 = 88.6% (app + kolbi_core + kolbi_ui, from app tests; combined.lcov)"
server_tests_at_sync: "Tests 387 passed (387); Lines 95.42% (1085/1137), Statements 92.3%, Branches 81.49%, Functions 91.66%"   # npx vitest run --coverage (server.txt)
server_typecheck_exit_at_sync: 0   # npm --prefix server run typecheck
web_build_at_sync: "✓ Built build/web"   # cd app && flutter build web --debug
browser_run_at_sync: "web build against a simulated server (CALL_PROVIDER=simulated, no .env): live call -> approval card (60초, quick replies, comment field, 거절/승인) -> approved -> result card; browser console: no errors"
acceptance_distinct_ac_ids: 15   # grep -oE 'AC-([A-Z0-9]+-)*[0-9]+' acceptance.md | sort -u | wc -l -> 15 = §E.3 ac_pass_count 15
ac_matrix_test_names_at_sync: all-present   # every test name cited in the §E.2 AC matrix found by grep -F in server/src or app/test at HEAD 8ad8239
frontmatter_status_transitions:
  spec.md: in-progress -> implemented   # updated: 2026-11-22 -> 2026-11-27; spec/plan/acceptance bodies unchanged
changelog_entry_position: not-applicable   # repository has no CHANGELOG.md
mx_scan: skipped   # --skip-mx semantics
divergence:
  planned_vs_changed_files: match   # git diff --name-only cd1f77e..42e2f16 = the 15 files of plan.md §B (9 server + 6 app) + spec.md + progress.md; no unplanned file, no planned-but-unchanged file
  deviations: "§E.2 M4 chips moved to one horizontal-scroll row (card 370px -> 318px on the 800x600 test surface); M5 AC-001 400 body asserted with toMatchObject({error}) because the current body also carries message; plan-audit advisories A1-1..A1-3 recorded for manager-spec"
later_changes:   # history not rewritten; paths below are the current locations at 8ad8239
  SPEC-INTAKE-001: "server/src/brain/prompts.ts, server/src/services/callService.ts (+test), server/src/http/app.test.ts, app/test/support/fakes.dart, app/test/unit_test.dart: additions for intake and auto start"
  SPEC-FOLLOWUP-001: "server/src/brain/prompts.ts (summary prompt sentence), app/test/unit_test.dart (appointment parsing)"
  SPEC-UX-001: "app/lib/features/calls/presentation/widgets/approval_card.dart restyled (AppCard, tokens, remaining-seconds clock)"
  SPEC-MODULE-001: "app/lib/features/calls/domain/approval_comment.dart is now a re-export; constants and pure functions live in packages/kolbi_core/lib/src/approval_comment.dart, CodePointLengthLimitingFormatter in packages/kolbi_ui/lib/src/input/code_point_formatter.dart; approval_card.dart stays in the app and imports the barrels"
device_check: deferred   # §E.2 "검증하지 않은 것": pinned card height and chip scrolling with the keyboard up on a small real device, and Korean IME composition at the 500 code-point limit, not run; no Xcode/simulator on this Mac at sync either
residual_risks_carried: "AI following user_comment / rule 7 in a real call is not verified automatically; A1-2 two dates joined by one space are masked; A1-3 a hyphenated phone token between card halves leaves both halves unmasked"
project_docs_synced: [.moai/project/structure.md, .moai/project/codemaps/modules.md, .moai/specs/EPIC-ASSISTANT-UX/overview.md]   # domain/approvalComment.ts rows added; committed once for the three SPECs in the docs(SPEC-ASSISTANT-UX) commit that follows the FOLLOWUP sync commit
tech_md: unchanged   # no new dependency
sync_audit: pending
```
