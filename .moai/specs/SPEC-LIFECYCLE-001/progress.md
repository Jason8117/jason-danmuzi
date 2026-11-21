# SPEC-LIFECYCLE-001 진행 기록

## §E.1 Plan-phase Audit-Ready Signal

- plan_status: revised after plan-audit iteration 2 (FAIL 0.88) — re-audit pending
- plan_complete_at: 2026-11-21
- artifacts: spec.md, plan.md, acceptance.md, research.md
- counts: 16 REQ / 16 AC
- depends_on: SPEC-STORE-001
- open_decisions: OD-1 RESOLVED (owner); OD-2, OD-3 DEFAULT (pending owner review)
- run-entry note: manager-develop records `run_start_sha` (HEAD at run entry) as the first line of §E.2

## §E.2 Run-phase Evidence

run_start_sha: f17a1880b334a5d24c554f67de8ee763fdd512c8

- 실행 위치: L1 worktree `.claude/worktrees/agent-a2f3302bb2cbff307` (브랜치 `worktree-agent-a2f3302bb2cbff307`, `git merge --ff-only f17a188` 후 시작)
- cycle_type: tdd, harness: thorough
- 증거 파일: `.moai/state/verify/run-lifecycle/lifecycle/` (worktree 내부)

### 기준선 (코드 변경 전, 이 트리, HEAD f17a188)

```
$ npm --prefix server test
 Test Files  4 passed (4)
      Tests  46 passed (46)
$ npm --prefix server run typecheck   → exit 0
$ (app) flutter --suppress-analytics test   → exit 0, "00:01 +12: All tests passed!"
$ (app) flutter --suppress-analytics analyze → exit 1, "info • Use the null-aware marker '?' … • test/support/fakes.dart:53:5 • use_null_aware_elements" / "1 issue found."
```

### 마일스톤 기록

_(마일스톤마다 아래에 RED/GREEN 원문을 추가한다)_

#### M1 — 데이터 모델과 통화 ID 저장 (AC-006, AC-009)

RED (`npm --prefix server test -- src/services/callService.test.ts src/providers/kat/katProvider.test.ts`, exit 1):

```
     × stores the provider call id on the task 6ms
     × reports the KAT callId to the session 56ms
 FAIL  src/services/callService.test.ts > CallService provider call id (AC-006) > stores the provider call id on the task
AssertionError: expected undefined to be 'c-1' // Object.is equality
 FAIL  src/providers/kat/katProvider.test.ts > KatCallProvider call id (AC-006) > reports the KAT callId to the session
TypeError: fetch failed
Caused by: Error: getaddrinfo ENOTFOUND kat.test
      Tests  2 failed | 5 passed (7)
```

(RED의 KAT 실패는 `fetch` 주입이 없어 전역 `fetch`가 가짜 호스트 `kat.test`의 DNS 조회에서 실패한 것이다. 실제 KAT로는 요청이 나가지 않았다.)

GREEN (같은 명령, exit 0): `Tests  7 passed (7)`; `npm --prefix server run typecheck` exit 0.

AC-009 (앱 보호 테스트): `flutter --suppress-analytics test test/unit_test.dart` exit 0, `00:00 +6: CallTask.fromJson ignores providerCallId when parsing tasks` / `00:00 +9: All tests passed!`. 앱 코드를 바꾸지 않는다는 계약을 고정하는 테스트이므로 구현 전 RED가 존재하지 않는다(설계상 첫 실행부터 통과). 서버 쪽 "필드 없는 작업 적재"는 AC-008 (a)가 함께 검증한다.

## §E.3 Run-phase Audit-Ready Signal

_<pending run-phase>_

## §E.4 Sync-phase Audit-Ready Signal

_<pending sync-phase>_
