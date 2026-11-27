# Sync 감사 보고서 — SPEC-APPROVAL-001 · SPEC-INTAKE-001 · SPEC-FOLLOWUP-001 (1차)

- 감사 대상: main HEAD `a10899d`. sync 커밋 `860b9b6`(APPROVAL), `d5addd3`(INTAKE), `6901fff`(FOLLOWUP), `a10899d`(에픽·프로젝트 문서). 기준 `8ad8239`
- 구현 범위: `cd1f77e..ba1ee17`(세 SPEC의 run-phase 19커밋, 51파일)
- 평가 프로필: `.moai/config/evaluator-profiles/default.md` (Functionality 40%, Security 25%, Craft 20%, Consistency 15%; 필수 통과 차원: Functionality + Security)
- 집계: SPEC마다 따로 매기고, 차원 점수의 비가중 조화 평균을 판정 값으로 쓴다(선례 `SPEC-UX-001-audit-1.md`와 같은 방식). 가중 조화 평균은 참고로 함께 적는다.
- 감사 방식: 읽기 전용. 아래 명령은 모두 이번 감사에서 이 트리(`a10899d`)에 직접 실행했다. 작성한 파일은 이 보고서 하나다.
- 상태: 완료

## 1. 판정 요약

| SPEC | Functionality | Security | Craft | Consistency | 조화 평균 (가중) | 판정 |
|------|---------------|----------|-------|-------------|------------------|------|
| SPEC-APPROVAL-001 | 92 PASS | 92 PASS | 85 PASS | 88 PASS | **89.2** (89.9) | **PASS** |
| SPEC-INTAKE-001 | 90 PASS | 90 PASS | 85 PASS | 82 PASS | **86.6** (87.7) | **PASS** |
| SPEC-FOLLOWUP-001 | 87 PASS | 92 PASS | 85 PASS | 85 PASS | **87.2** (87.5) | **PASS** |

세 SPEC 모두 필수 차원(Functionality, Security)을 통과했다. 차단 결함은 없고, 비차단 결함 6건(Medium 1, Low 5)을 §7에 적었다.

## 2. 기준 측정 (이번 감사, `a10899d`)

sync 커밋 네 개는 `.moai/` 아래 파일만 바꿨다. 코드 트리가 측정 기준점과 같음을 먼저 확인했다.

```
$ git diff --stat 8ad8239 HEAD -- . ':!.moai'
(출력 없음 — 코드 트리 = 8ad8239)
```

```
$ cd app && flutter --suppress-analytics test
00:07 +84: All tests passed!
exit=0

$ cd app && flutter --suppress-analytics analyze
   info • Use the null-aware marker '?' rather than a null check via an 'if'. Try using '?' • test/support/fakes.dart:54:5 • use_null_aware_elements
1 issue found. (ran in 1.9s)
exit=1   (기준선 info 1건뿐)

$ npm --prefix server test
 Test Files  14 passed (14)
      Tests  387 passed (387)
exit=0

$ npm --prefix server run typecheck
> callmate-server@0.1.0 typecheck
> tsc -p tsconfig.json --noEmit
exit=0

$ cd packages/kolbi_core && flutter --suppress-analytics test   → 00:00 +3: All tests passed!
$ cd packages/kolbi_ui   && flutter --suppress-analytics test   → 00:00 +4: All tests passed!
```

앱 `+84`, 서버 `387`은 세 SPEC §E.4의 `app_tests_at_sync`·`server_tests_at_sync` 값과 같다.

### 2.1 worktree SHA ↔ main SHA (§E.4 주장)

worktree SHA는 이 저장소에 있다(`git cat-file -t` → 모두 `commit`, 해당 `worktree-agent-*` 브랜치가 아직 남아 있음).

```
$ git diff --quiet 594e810 9bc7332; echo $?   → 0   (APPROVAL M5)
$ git diff --quiet ab029ec e34808a; echo $?   → 0   (INTAKE M6)
$ git diff --quiet 36a926e fad4e60; echo $?   → 0   (FOLLOWUP M5)
$ git diff --quiet 678274e 42e2f16; echo $?   → 0   (APPROVAL M6 증거 커밋)
$ git diff --quiet 52a6a1d d161cab; echo $?   → 0   (INTAKE M7 증거 커밋, worktree 브랜치 끝)
$ git diff --quiet 5ca5c54 ba1ee17; echo $?   → 0   (FOLLOWUP M6 증거 커밋, worktree 브랜치 끝)
$ git merge-base --is-ancestor cd1f77e HEAD; echo $?   → 0
```

§E.4의 "트리 동일" 주장 세 건과 증거 커밋 대응 세 건이 모두 맞다.

## 3. Functionality

### 3.1 AC 개수

```
$ grep -oE 'AC-([A-Z0-9]+-)*[0-9]+' acceptance.md | sort -u | wc -l ; grep -cE '^##+ AC-' acceptance.md
APPROVAL  ids=15  headings=15
INTAKE    ids=24  headings=24
FOLLOWUP  ids=17  headings=16
```

FOLLOWUP의 17번째 id는 `AC-021` 한 번뿐이며, `acceptance.md:202` "계획 카드(SPEC-INTAKE-001 AC-021의 초안)"라는 다른 SPEC 참조다. 이 SPEC 자신의 AC 제목은 AC-001~AC-016의 16개다. §E.4 `ac_count_note`가 맞다.

### 3.2 AC → 테스트 연결

각 progress.md §E.2 AC 표가 인용한 테스트 이름을 `grep -rlF "<이름>" app/test packages/*/test server/src`로 하나씩 찾았다. 결과는 MISSING 0건이다.

**SPEC-APPROVAL-001** (16개 이름, AC-015는 전체 회귀)

| AC | 테스트 이름 | 파일 |
|----|-------------|------|
| AC-001 | counts approval comment length in code points | app.test.ts |
| AC-002 | sanitizes control characters and line breaks | approvalComment.test.ts |
| AC-003 | masks card- and ID-shaped digit runs / detects sensitive digit runs like the server | approvalComment.test.ts / unit_test.dart |
| AC-004 | stores the masked approval comment / resolves the approval with the sanitized comment | app.test.ts / callService.test.ts |
| AC-005 | never logs approval comments | callService.test.ts |
| AC-006 | CallService guidance line / records the guidance line once in a simulated call | callService.test.ts / app.test.ts |
| AC-007 | returns every approval decision shape as tool output | realtimeBridge.test.ts |
| AC-008 | tells the agent how to follow a user_comment | prompts.test.ts |
| AC-009~013 | quick replies… / comment field starts as one line… / warns about card-shaped numbers… / keeps the comment when sending fails / shows the guidance in history and transcript | approval_card_test.dart |
| AC-014 | approval_flow_test.dart 전체 | approval_flow_test.dart |
| AC-015 | 전체 스위트(§2) | — |

**SPEC-INTAKE-001** (37개 이름 모두 존재)

| AC | 파일(이름 수) |
|----|---------------|
| AC-001, 002, 013 | app.test.ts |
| AC-003, 005, 006, 011, 012, 014~016 | callService.test.ts (+ AC-014 app.test.ts "auto-starts a simulated call without approve-plan") |
| AC-004, 007 | intake.test.ts, callService.test.ts, openaiBrain.test.ts |
| AC-008, 009 | callService.test.ts, openaiBrain.test.ts |
| AC-010 | heuristicBrain.test.ts |
| AC-017, 018, 022 | intake_flow_test.dart, unit_test.dart |
| AC-019~021, 023 | plan_card_test.dart, unit_test.dart |
| AC-024 | 전체 스위트 + intake_flow_test.dart "the manual form never auto-starts" |

**SPEC-FOLLOWUP-001** (16개 이름 모두 존재)

| AC | 파일 |
|----|------|
| AC-001~003 | openaiBrain.test.ts |
| AC-004 | heuristicBrain.test.ts, openaiBrain.test.ts |
| AC-005 | unit_test.dart ("parses appointments defensively"), follow_up_test.dart |
| AC-006~012 | follow_up_test.dart |
| AC-013~015 | trust_notice_test.dart |
| AC-016 | 전체 스위트 + 의존성 diff |

모든 테스트는 §2 실행에서 통과했다(앱 `+84`, 서버 `387`, 실패 0).

### 3.3 계획 파일 ↔ 실제 변경

```
$ git diff --name-only cd1f77e..42e2f16 | wc -l   → 17   (APPROVAL: 15 + spec.md + progress.md)
$ git diff --name-only 42e2f16..e34808a | wc -l   → 28   (INTAKE: 26 + spec.md + progress.md)
$ git diff --name-only d161cab..fad4e60 | wc -l   → 23   (FOLLOWUP: 21 + spec.md + progress.md)
$ git diff --name-only d161cab..fad4e60 | grep -c intake_flow_test   → 0
```

세 값 모두 §E.4 `planned_vs_changed_files`와 같다. FOLLOWUP의 `planned_but_unchanged: [app/test/intake_flow_test.dart]`도 확인된다.

### 3.4 감점 이유

- APPROVAL(−8): AI가 실제 통화에서 `user_comment`·규칙 7을 따르는지는 자동 검증 범위 밖이다(문구와 도구 결과 형태까지만 검증). 실기기 키보드·IME 500 코드 포인트 경계는 돌리지 않았다.
- INTAKE(−10): AC-006 4행이 설계 문서 벡터(`+82299999999`)가 아니라 정책 함수 값(`+8229999999`)을 단언한다. 근거가 테스트 주석(`callService.test.ts:998-1001`)과 §E.2에 있고 값 자체는 정책상 맞지만, SPEC 벡터와 테스트가 어긋난 채 남아 있다(C3). 과잉 마스킹(`15000000원`, 0으로 시작하는 주문번호)은 테스트가 없다.
- FOLLOWUP(−13): AC-008·AC-012는 주입한 가짜 공유 서비스로만 통과했다. 실제 공유 시트, 기본 캘린더의 `.ics` 수락, 기기 클립보드는 기기 확인(DoD)으로 미뤄졌다.

## 4. Security

### 4.1 비밀 값 스캔

```
$ git diff cd1f77e..ba1ee17 | grep -E '^\+' | grep -inE 'api[_-]?key|secret|password|bearer |sk-[A-Za-z0-9]{10}|AKIA|-----BEGIN|token\s*[:=]\s*["'"'"'][A-Za-z0-9]{8}|https?://[^ ]*@'
```

맞은 줄은 모두 테스트 데이터나 지시문 문구다: 테스트 지역 변수 이름 `secret`(앱·서버 로그 비노출 단언), 지시문의 "Never give card numbers, passwords", `OpenAiBrain(API_KEY, …)` 호출. `API_KEY`는 `server/src/brain/openaiBrain.test.ts:9`의 `"sk-test-DO-NOT-LOG-1234"`로, 로그 비노출을 확인하려는 가짜 값이다. 실제 자격 증명은 없다.

```
$ git diff cd1f77e..ba1ee17 | grep -E '^\+' | grep -oE 'https?://[^ )"'"'"'`]+' | sort -u
https://pub.dev          (pubspec.lock 메타데이터)
$ git diff --name-only cd1f77e..ba1ee17 | grep -iE '\.env|secret|cred'
(출력 없음)
$ git diff cd1f77e..ba1ee17 -- server/package.json app/pubspec.yaml | grep -E '^[-+][^-+]'
+  share_plus: ^13.3.1
```

새 의존성은 `share_plus` 하나이며 FOLLOWUP OD-1로 계획된 것이다. `packages/kolbi_ui/test/dependency_rules_test.dart:12`가 `package:share_plus/`를 kolbi_ui에서 금지하고, 그 테스트는 §2에서 통과했다.

### 4.2 APPROVAL — 13자리 이상 숫자 사슬 가리기

- 구현: `server/src/domain/approvalComment.ts:5` `SENSITIVE_MIN_DIGITS = 13`, 앱 경고는 `packages/kolbi_core/lib/src/approval_comment.dart:44,60` `_sensitiveMinDigits = 13`.
- 테스트: `server/src/domain/approvalComment.test.ts:24-41`의 16행 벡터 표와 `toHaveLength(16)` 단언. 13자리(`900101-1234567`), 15자리(`1234 5678 9012 345`), 20자리, 카드번호 + 유효기간·CVC, 하이픈 전화번호 예외, 12자리 이하 비마스킹(`주문 2024-1234-5678` → 그대로)이 모두 들어 있다. 앱의 `unit_test.dart` "detects sensitive digit runs like the server"가 같은 표를 쓴다.
- 로그 비노출: callService.test.ts "never logs approval comments" 존재·통과.
- 알려진 구멍(§E.2 A1-3): 카드번호 두 토막 사이에 하이픈 전화번호가 끼면 양쪽 8자리 조각이 각각 남는다. 결정적 규칙의 귀결이며 기록되어 있다(C5).

### 4.3 INTAKE — `POST /v1/intake` 입력 검증

`server/src/http/app.ts:167-170`:

```ts
app.post("/v1/intake", async (request) => {
  const { text, language } = IntakeBody.parse(request.body);
  return calls.draftIntake(text, language);
});
```

`server/src/http/schemas.ts:18-21`:

```ts
export const IntakeBody = z.object({
  text: text(1000),                       // z.string().trim().min(1).max(1000)
  language: z.enum(["ko", "en"]).default("ko"),
});
```

- 스키마 검증이 있다. 본문이 없거나 형식이 틀리면 `ZodError` → `app.ts:122-124` 오류 처리기가 400 `invalid_request`로 바꾼다.
- 인증: `app.ts:140-145` `onRequest` 훅이 `/v1/` 전체에 토큰을 요구하므로 `/v1/intake`도 덮인다(AC-001 (6) 401 테스트).
- 종료 중 차단: `callService.ts:275` `this.assertNotShuttingDown()`(AC-002 503).
- LLM 전송 전 마스킹: `callService.ts:277` `maskPhoneNumbers(text)` 결과만 `brain.draftIntake`에 넘긴다(AC-007 테스트 3종).
- 요청 원문 비로그: "intake has no side effects and logs no request text" 존재·통과.

### 4.4 FOLLOWUP

새 서버 엔드포인트는 없다. 요약 결과의 `appointment`는 확정되고 형식이 맞는 값만 남긴다(AC-002 13행 테스트). 공유는 사용자 기기 공유 시트로만 나간다.

### 4.5 감점 이유

- 세 SPEC 공통: OWASP 항목별 점검은 따로 하지 않았다.
- APPROVAL(−8): OD-1·OD-4가 여전히 "DEFAULT (pending owner review)"이고, A1-2·A1-3 마스킹 경계가 남아 있다.
- INTAKE(−10): 0으로 시작하는 주문번호가 전화번호로 제안될 수 있다(계획 카드에서 보이고 고칠 수 있지만 테스트 없음). 정책 검사(`checkTargetNumber`)가 최종 관문이라 위험은 제한적이다.
- FOLLOWUP(−8): 플랫폼이 실패 뒤 `unavailable`을 돌려주면 사용자에게 알림이 없다(§E.2 부록).

## 5. Craft — 세 SPEC 모두 85

### 5.1 analyze

§2: info 1건 `test/support/fakes.dart:54:5`. 세 SPEC의 run 기준선(§E.3 `app_analyze: 1 info (baseline info, fakes.dart:54)`)과 같고 새 경고는 없다.

### 5.2 커버리지 증거 (`.moai/state/verify/coverage/`, 오케스트레이터 측정)

```
$ ls .moai/state/verify/coverage
app.lcov app.txt combined.lcov combined.txt core.lcov core.txt server/ server.txt ui.lcov ui.txt web-build.txt

$ awk -F: '/^LF:/{lf+=$2}/^LH:/{lh+=$2}END{...}' combined.lcov
combined LH/LF=1497/1689=88.63%
$ grep -c '^SF:' combined.lcov   → 31  (app lib 15개 + ../packages/kolbi_core 9개 + ../packages/kolbi_ui 7개)

$ tail server.txt
Lines        : 95.42% ( 1085/1137 )
Statements   : 92.3% ( 1199/1299 )
Branches     : 81.49% ( 665/816 )
Functions    : 91.66% ( 242/264 )
$ python3 … server/coverage-summary.json → {'total': 1137, 'covered': 1085, 'pct': 95.42}

$ tail -1 combined.txt → 00:08 +84: All tests passed!
$ tail -1 web-build.txt → ✓ Built build/web

$ git check-ignore -v .moai/state/verify/coverage/combined.lcov
.gitignore:205:.moai/state/	…   (git에 올라가지 않음)
```

§E.4의 `1497/1689 = 88.6%`와 `Lines 95.42% (1085/1137)`, 그 밖의 서버 수치가 증거 파일과 정확히 같다. 측정 기준점 `8ad8239`의 코드 트리는 현재 HEAD와 같다(§2). 다만 이 수치는 이번 감사가 다시 측정한 것이 아니라 오케스트레이터가 남긴 파일을 대조한 것이다(§8).

참고: 공용 패키지 자체 테스트만으로 잰 값은 `core.lcov` 54/342 = 15.79%, `ui.lcov` 49/263 = 18.63%로 낮다. 패키지 코드는 앱 테스트로 실행되며 combined에 포함되므로 이 세 SPEC의 결함으로 보지 않는다. 서버 분기 커버리지 81.49%도 85% 미만이지만 TRUST 기준(라인 85%)은 충족한다.

### 5.3 TDD 기록

세 SPEC 모두 §E.2 AC 표에 RED 출력을 AC마다 적었다(예: APPROVAL AC-002 `Cannot find module './approvalComment.js'`, INTAKE AC-002 `expected 404 to be 503`, FOLLOWUP AC-001 `TS2353 'appointment' does not exist in type 'CallOutcome'`). 처음부터 통과한 보호 테스트도 그렇다고 구분해 적었다. 이 기록은 커밋된 텍스트이며, 이번 감사에서 RED를 재현하지는 않았다.

### 5.4 감점 이유

- 커버리지가 감사자 재측정이 아니라 증거 파일 대조다.
- 서버 분기 81.49%, 패키지 자체 테스트 커버리지가 낮다.
- INTAKE의 홈 화면은 기존 테스트를 고치지 않으려고 라우트가 현재가 아닐 때 TextField 모양 위젯을 그린다(§E.4 deviations). 테스트 형편에 맞춘 구현 분기라 유지 비용이 남는다.

## 6. Consistency

### 6.1 spec.md 변경은 frontmatter뿐

```
$ git show <c> -- '.moai/specs/*/spec.md' '.moai/specs/*/plan.md' '.moai/specs/*/acceptance.md' '.moai/specs/*/design.md' | grep -E '^[-+][^-+]'
860b9b6 / d5addd3 / 6901fff 각각:
-status: in-progress
+status: implemented
-updated: 2026-11-22
+updated: 2026-11-27
a10899d: (출력 없음)
```

sync 커밋 세 개는 각자 `progress.md`(+35~36줄)와 `spec.md` 4줄만 바꿨다. 본문 변경은 없다.

### 6.2 §E.4 값 ↔ git

| §E.4 항목 | 확인 | 일치 |
|-----------|------|------|
| `run_commit_sha_on_main` 3건 + 트리 동일 | §2.1 exit 0 ×3 | 예 |
| 증거 커밋 대응(678274e→42e2f16, INTAKE M7→d161cab, FOLLOWUP M6→ba1ee17) | §2.1 exit 0 ×3 | 예 |
| `run_start_sha` (cd1f77e / 42e2f16 / d161cab) | `git log -1`: 각각 에픽 문서 커밋 / APPROVAL M6 / INTAKE M7 | 예 |
| `planned_vs_changed_files` 17 / 28 / 23 | §3.3 | 예 |
| `acceptance_distinct_ac_ids` 15 / 24 / 17, `ac_count_note` | §3.1 | 예 |
| `ac_matrix_test_names_at_sync: all-present` | §3.2 MISSING 0 | 예 |
| 테스트·커버리지 수치 | §2, §5.2 | 예 |

### 6.3 프로젝트 문서 ↔ 실제 코드 (`a10899d`의 추가 줄)

| 문서 기재 | 실제 코드 | 일치 |
|-----------|-----------|------|
| modules.md·structure.md `approvalComment.ts`: `SENSITIVE_PLACEHOLDER`, `sanitizeApprovalComment`; 사용처 callService·prompts | approvalComment.ts:2,19; `callService.ts:5`, `prompts.ts:1` import | 예 |
| `intake.ts`: `PHONE_PLACEHOLDER` … `findHistoryNumber` 9개; 사용처 callService·heuristicBrain | intake.ts:5,31,35,44,56,64,71,79,94; `heuristicBrain.ts:3` | 예 |
| `types.ts` `draftIntake?(maskedText, language)` | types.ts:12 | 예 |
| `openaiBrain.ts` `OpenAiBrainOptions`, `LLM_TIMEOUT_MS`(30 s), `INTAKE_LLM_TIMEOUT_MS`(15 s), `SUMMARY_TIMEZONE` | openaiBrain.ts:102, 94 `30_000`, 96 `15_000`, 33 | 예 |
| `prompts.ts` `INTAKE_SYSTEM_PROMPT` | prompts.ts:64 | 예 |
| `CallService.draftIntake`, `create(…, { autoStart })` | callService.ts:274; app.ts:161-162 | 예 |
| entry-points.md `POST /v1/intake`: `IntakeBody` → `calls.draftIntake()`, 종료 중 503 | app.ts:167-170, schemas.ts:18, callService.ts:275 | 예 |
| `app_settings.dart` `trustNoticeAcknowledged`, `acknowledgeTrustNotice`, `save` | app_settings.dart:17,26,62,74,79,84 | 예 |
| `trust_notice.dart` `trustStatements`, `agentRulesNotice`, `liveCallTrustLine`, `ensureTrustAcknowledged`, `TrustStatementList`; settings_screen도 가져옴 | trust_notice.dart:9,20,23,27,41; `settings_screen.dart`가 import | 예 |
| `follow_up_actions.dart` `FollowUpService`, `DeviceFollowUpService`, `followUpServiceProvider`, `followUpClockProvider`, `FollowUpActions` | follow_up_actions.dart:12,19,40,43,47 | 예 |
| `plan_card_screen.dart` `PlanCardScreen`, 라우트 `/plan` | plan_card_screen.dart:19; app_router.dart:9,25 | 예 |
| tech.md·dependencies.md `share_plus` ^13.3.1, 사용처 follow_up_actions.dart | app/pubspec.yaml:21; `lib/`에서 import는 follow_up_actions.dart:9 하나 | 예 |
| 에픽 overview: 네 SPEC 모두 `implemented`, 버전 0.3.0, main 구현 커밋 9bc7332·e34808a·fad4e60 | 네 spec.md frontmatter 확인, §2.1 | 예 |

### 6.4 감점 이유

- 공통: 에픽 overview §2와 각 SPEC의 `depends_on` 조건은 "앞 SPEC이 `completed`가 된 뒤 시작"인데, 실제로는 앞 SPEC이 `in-progress`인 채 run이 시작됐다. overview와 INTAKE·FOLLOWUP §E.4 `depends_on_note`가 이 사실을 솔직히 적었지만, 규칙이 요구하는 `--ignore-deps` 기록(`.moai/logs/depends-on-override.log`)은 없다(C1).
- INTAKE: design.md §3.4 벡터 오타가 열린 채다(C3).
- FOLLOWUP: AC-016 문구와 실제 변경(intake_flow_test.dart 미변경) 차이, 감사 권고 A3-2가 manager-spec에게 넘겨진 채다.

## 7. 결함 목록

### C1 [Medium] [non-blocking] `depends_on` 미충족 상태로 run을 시작했는데 우회 기록이 없다

- 위치: INTAKE·FOLLOWUP `progress.md` §E.4 `depends_on_note`, `EPIC-ASSISTANT-UX/overview.md:3,17`
- 사실: INTAKE run 시작 `42e2f16` 시점 APPROVAL은 `in-progress`, FOLLOWUP run 시작 `d161cab` 시점 INTAKE도 `in-progress`였다(§E.4 자체 기록). `.claude/rules/moai/workflow/spec-workflow.md` § Depends_on Pre-flight Check는 `completed`만 충족으로 보고, 우회하려면 `--ignore-deps`와 근거를 `.moai/logs/depends-on-override.log`에 남기라고 한다.
- 관찰: `ls .moai/logs/depends-on-override.log` → `No such file or directory`.
- 의미: sync 문서는 사실을 정확히 적었으므로 sync 품질 결함이 아니라 run 진입 절차의 기록 누락이다. 또 네 SPEC이 모두 `implemented`에서 멈춰 있어, 규칙을 문자 그대로 적용하면 앞으로 이들에 `depends_on`을 거는 SPEC은 계속 막힌다(SPEC-UX-001 감사 C1과 같은 문제).
- 필요한 조치: 사용자가 (가) 종료 상태를 `completed`로 올릴지, (나) 이 저장소의 종료 상태를 `implemented`로 정하고 에픽·SPEC 문구를 manager-spec이 고칠지 정한다.

### C2 [Low] 커버리지는 감사자 재측정이 아니다

- §E.4 `sync_evidence_source: orchestrator`. 이번 감사는 파일 수치 대조만 했다(§5.2). 파일은 gitignore 대상이라 이 기계에만 있다.

### C3 [Low] INTAKE design.md §3.4 벡터 오타가 남아 있다

- `design.md:142` `02-999-9999` → `+82299999999`, 테스트 `callService.test.ts:1001` → `+8229999999`. 테스트 주석이 근거를 설명하고, 값은 정책 함수 결과와 같다. SPEC 본문 수정은 manager-spec 몫이며 sync는 손대지 않았다(올바른 처리).

### C4 [Low] FOLLOWUP 공유·캘린더는 가짜 서비스로만 검증됐다

- AC-008·AC-012 PASS는 주입한 가짜 서비스 기준이다. 실제 공유 시트와 기본 캘린더 앱의 `.ics` 수락은 기기 확인으로 미뤄졌다(§E.4 `device_check: deferred`).

### C5 [Low] APPROVAL 마스킹 경계 두 건이 OD 결정 대기다

- A1-2(공백 하나로 이은 날짜 두 개가 가려짐), A1-3(카드 두 토막 사이에 하이픈 전화번호가 끼면 가려지지 않음). OD-1·OD-4는 "pending owner review" 상태다.

### C6 [Low] 첫 통화에서 확인이 두 번 필요하다

- 계획 카드 [이대로 시작] + 신뢰 안내 [확인했어요]. owner 결정 3("한 번 누르면 시작")과 작은 차이가 있다. INTAKE·FOLLOWUP §E.4 `residual_risks_carried`에 적혀 있다.

## 8. 검증하지 않은 것

- 커버리지 재측정(`flutter test --coverage`, `vitest --coverage`)과 `flutter build web`, 브라우저 실행. 오케스트레이터 증거 파일과 대조만 했다.
- TDD RED 재현. §E.2의 RED 출력은 커밋된 기록으로만 읽었다.
- 실기기(Android·iOS) 공유 시트, 캘린더, 클립보드, 스크린 리더, 햅틱, 한국어 IME 조합.
- 실제 OpenAI Realtime·KAT 연결과, AI가 `user_comment`·규칙 7을 실제 통화에서 따르는지.
- OWASP 항목별 점검. 비밀 값 스캔은 정규식 기반이므로 패턴 밖의 형식은 잡지 못한다.
- 과잉 마스킹(`15000000원`, 0으로 시작하는 주문번호) 동작은 테스트가 없어 확인하지 않았다.

## 9. 잔여 위험

- 마스킹 규칙은 결정적이라 사람이 일부러 끼워 쓴 형식(C5)을 통과시킬 수 있다. 서버·앱이 같은 16행 표를 쓰므로 한쪽만 바뀌는 회귀는 테스트가 잡는다.
- 공용 패키지 자체 테스트 커버리지가 낮아, 패키지를 다른 앱에서 쓰게 되면 앱 테스트가 주던 보호가 사라진다.
- `worktree-agent-*` 브랜치와 worktree가 남아 있다. §E.4가 인용하는 worktree SHA는 지금은 해석되지만, 정리 뒤에는 main SHA만 남는다.
