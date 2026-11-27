# Sync 감사 보고서 — SPEC 5건 (2차, 재감사)

- 감사 대상: main HEAD `466c73b`
- 재감사 범위: 1차(`FIVE-SPECS-audit-1.md`)에서 실패한 두 SPEC만 다룬다. SPEC-LIFECYCLE-001(F2)과 SPEC-POLICY-001(F1).
- 검토한 수정 커밋: `f833092`, `50343ad`(SPEC-POLICY-001), `06759af`(SPEC-LIFECYCLE-001)
- 평가 프로필: `.moai/config/evaluator-profiles/default.md`. Functionality 40%, Security 25%, Craft 20%, Consistency 15%이고, Functionality와 Security는 반드시 통과해야 한다.
- 집계 방식: 1차와 같이 네 차원 점수의 단순 조화 평균을 쓴다.
- 증거 위치: 세션 스크래치 디렉터리 `a2/`(아래 명령 출력). 1차 프로브 스크립트(`.moai/state/verify/audit/*.mts`)는 HEAD 소스에 다시 실행했다.
- 감사 방식: 읽기 전용이다. 저장소에서 바꾼 파일은 이 보고서 하나뿐이다. 수정을 되돌린 RED 재현은 스크래치에 푼 `git archive` 사본에서만 했다.
- 상태: 완료

## 1. 판정 요약

| SPEC | Functionality (40%) | Security (25%) | Craft (20%) | Consistency (15%) | 조화 평균 | 판정 |
|------|------|------|------|------|------|------|
| SPEC-LIFECYCLE-001 | 95 PASS | 85 PASS | 90 PASS | 90 PASS | 89.9 | **PASS** |
| SPEC-POLICY-001 | 90 PASS | 90 PASS | 90 PASS | 80 PASS (문서 불일치) | 87.3 | **PASS** |

1차에서 막혔던 결함 F1과 F2는 모두 해소되었다. 남은 지적은 문서 불일치와 잔여 위험 수준이며, 판정을 막지 않는다(§4).

Craft는 1차에서 UNVERIFIED였다. 지금은 `@vitest/coverage-v8`이 설치되어 있어 실제로 측정했다. 서버 전체 구문 커버리지는 92.3%로 85% 기준을 넘는다(§2.5).

## 2. 측정 결과 (이번 실행, HEAD `466c73b`)

### 2.1 전체 테스트와 타입 검사

```
$ npm --prefix server test
 Test Files  14 passed (14)
      Tests  387 passed (387)
test_exit=0

$ npm --prefix server run typecheck
> callmate-server@0.1.0 typecheck
> tsc -p tsconfig.json --noEmit
tc_exit=0
```

### 2.2 F2 회귀 테스트 (shutdown 파일만 실행)

```
$ npx vitest run src/shutdown.integration.test.ts src/shutdown.test.ts --reporter=verbose
 ✓ src/shutdown.integration.test.ts > shutdown with a hang-up that never answers (real app, real JSON store) > saves the shutdown-failed status to the data file 437ms
 Test Files  2 passed (2)
      Tests  9 passed (9)
f2_exit=0
```

수정을 되돌려도 이 테스트가 실패하는지 확인했다. 스크래치 사본(`git archive HEAD server`)에서 `deadlineMs: hangupDeadlineMs`를 예전 값 `budgets.terminateCallsMs`로 바꾸고 실행했다.

```
red_exit=1
-   "status": "failed",
+   "status": "ringing",
 Test Files  1 failed (1)
      Tests  1 failed (1)
```

이 테스트는 1차가 설명한 결함을 실제로 잡아낸다. 수정 전에는 메모리에 `failed`가 있어도 디스크에는 `ringing`이 남았다.

### 2.3 F1 회귀 테스트 (이름으로 골라 실행)

```
$ vitest run src/domain/domain.test.ts src/services/callService.test.ts src/http/app.test.ts src/providers/kat/katProvider.test.ts \
    -t "dialed form|blocked callback|dial-string transformation|keeps regular numbers" --reporter=verbose
 Test Files  4 passed (4)
      Tests  36 passed | 178 skipped (214)
f1_exit=0
```

36건의 내역:
- `domain.test.ts:94`: 차단 5건(`119 1234 5678`, `+119 12345`, `112-0000-0000`, `182 1234 5678`, `+11912345678`), 정상 번호 유지 13건(`010-1191-2345`, `02-112-3456`, `031-119-1234`, `1588-1234`, `+1 (415) 555-0100` 포함)
- `callService.test.ts:554`: `create` 차단 3건, 저장된 `+1…` 번호에 대한 `approvePlan` 재검사 차단 3건. 재검사 차단 시 `start`는 호출되지 않는다.
- `app.test.ts:83`: HTTP 400 `blocked_number` 3건
- `app.test.ts:98`, `callService.test.ts:490`: 차단된 회신 번호를 버리는 경우 4건씩(`112-0000-0000`, `119`, `+82 112`, `119 1234 5678`)
- `katProvider.test.ts:119`: `toKatPhoneNumber === toDomesticDialString`, 즉 정책이 판정하는 함수와 KAT가 쓰는 함수가 같은 객체임을 단언한다.

### 2.4 1차 프로브 재실행 (HEAD 소스)

```
$ tsx .moai/state/verify/audit/probe-shutdown.mts real-app
before signal: ringing
mode=real-app exit=0 elapsed=2759ms in-memory=failed on-disk=failed | 서버가 종료되어 통화를 끊었습니다.
$ tsx .moai/state/verify/audit/probe-shutdown.mts instant-app
mode=instant-app exit=0 elapsed=2758ms in-memory=failed on-disk=failed | 서버가 종료되어 통화를 끊었습니다.
```

1차 결과는 `elapsed=3005ms in-memory=failed on-disk=ringing | undefined`였다. 이번에는 단계 예산 초과 경고도 나오지 않았다.

```
$ tsx .moai/state/verify/audit/probe-policy.mts   (발췌)
"119 1234 5678" | blocked | - | -
"112-0000-0000" | blocked | - | -
"182 1234 5678" | blocked | - | -
"+1 19 1234 5678" | blocked | - | -
"+119 12345" | blocked | - | -
"+11912345678" | blocked | - | -
"02-119-0000" | ok | +8221190000 | 021190000
"010-1234-5678" | ok | +821012345678 | 01012345678
"1588-1234" | ok | +15881234 | 15881234
SERVICE "119 1234 5678" -> rejected 400 blocked_number
SERVICE "+119 12345" -> rejected 400 blocked_number

$ tsx .moai/state/verify/audit/probe-http-policy.mts
"119 1234 5678" -> 400 blocked_number
"112-0000-0000" -> 400 blocked_number
"+119 12345" -> 400 blocked_number
"010-1234-5678" -> 201 +821012345678
callbackNumber "112-0000-0000" -> 201 callbackNumber=undefined
```

1차에서 `dialing` 상태와 `body.to=11912345678`까지 갔던 입력은 이제 모두 생성 단계에서 막힌다. 1차 §4의 A3(회신 번호 `+11200000000` 저장)도 해소되었다.

추가로 경계 입력을 직접 검사했다(스크래치 `probe-extra.mts`).

```
"+1 182 555 0100" | blocked
"+1 125 555 0100" | blocked
"+1 1 2 0 0 0 0 0 0 0 0" | blocked
"00 1 119 1234 5678" | ok | +111912345678 -> 111912345678
"+44 119 123 4567" | ok | +441191234567 -> 441191234567
"+82 112 1234" | ok | +821121234 -> 01121234
"+82-10-1191-2345" | ok | +821011912345 -> 01011912345
```

전달되는 다이얼 문자열이 차단 번호(112/119/182 등)로 시작하는 경우는 하나도 찾지 못했다. `111912345678`은 `11`로 시작하므로 차단 번호에 해당하지 않는다. `01121234`처럼 앞자리가 0이면 국내 지역·이동통신 번호로 해석된다.

### 2.5 커버리지 (보고서는 스크래치에만 저장)

```
$ vitest run --coverage.enabled --coverage.provider=v8 --coverage.reportsDirectory=<scratch>/cov --coverage.reporter=text
File               | % Stmts | % Branch | % Funcs | % Lines
All files          |    92.3 |    81.49 |   91.66 |   95.42
  shutdown.ts      |   87.93 |    83.33 |     100 |      92
  phone.ts         |   97.77 |    96.87 |     100 |     100
  katProvider.ts   |   93.65 |    78.36 |   92.85 |   95.87
  callService.ts   |   91.56 |    86.38 |   96.87 |   95.65
cov_exit=0
```

### 2.6 이후 커밋이 결함을 되살렸는지

```
$ git log --oneline 06759af..HEAD -- server/src
c1196d2 feat(SPEC-FOLLOWUP-001) …  a5480ba / 28e14ef / 2ab289f / ecd5d3c (SPEC-INTAKE-001)
9bc7332 / 1645254 / fdfb3bd / 8546060 (SPEC-APPROVAL-001)
34617cd, 19f9c67, 5c14e83, cffde02, 50343ad, 2e96788, b140218, 9e1b4ae
```

- `server/src/shutdown.ts`는 `06759af` 이후 바뀌지 않았다(`git diff 06759af HEAD --stat`에 없음). `terminateActiveCalls`(`callService.ts:184-227`)도 그대로다. 내부 마감이 지나면 같은 동기 구간에서 `failed`를 표시한다.
- `server/src/domain/phone.ts`는 이후 `50343ad`의 주석 한 줄만 바뀌었다.
- 새 진입점도 번호 규칙을 우회하지 않는다.
  - `autoStart`(SPEC-INTAKE-001)는 `approvePlan`을 거치므로 `checkTargetNumber` 재검사를 받는다.
  - `draftIntake`가 만드는 번호 후보(`findPhoneNumberInText`, `findHistoryNumber`)도 모두 `checkTargetNumber`를 거친다.
  - 그 결과는 초안일 뿐이고 실제 작업 생성은 `create`를 지난다.

## 3. 수정 내용 검토

### F1 [High] SPEC-POLICY-001 — 해소

- 원인 제거: 다이얼 문자열 변환이 `domain/phone.ts`의 `toDomesticDialString` 하나로 합쳐졌다. `katProvider.toKatPhoneNumber`는 그 함수의 별칭이고, `isBlockedNumber`는 변환 결과를 판정한다.
  - 앞자리가 0인 문자열(+82)은 국내 번호 부분이 차단 번호와 정확히 같을 때만 막는다. 이 동작은 이전과 같다.
  - 앞자리가 0이 아닌 문자열(+82가 아닌 번호)은 차단 번호로 시작하면 막는다.
  - 판정 대상과 발신 대상이 같은 함수에서 나오므로, 1차가 지적한 "판정한 번호와 거는 번호가 다르다"는 구조가 사라졌다.
- 1차가 요구한 항목:
  - `119 1234 5678`, `+119 12345`, `112-0000-0000` 행을 테스트로 고정했다(도메인·서비스·HTTP). 저장된 번호에 대한 `approvePlan` 재검사도 추가했다.
  - 1차가 제안한 두 수정 방향 가운데 "제공자가 실제로 거는 형태로 판정"을 택했다.
- 회신 번호(A3): `50343ad`는 소유자 결정에 따라, 차단 번호로 분류된 회신 번호를 오류 없이 `undefined`로 저장한다. 회신 번호로 전화를 걸지는 않으므로 보안 결함은 아니었다. 이번 변경으로 저장 값의 위생 문제도 해소되었다.
- 부작용: 실제 북미 지역번호 가운데 22x/25x/82x(`+1 225 …`, `+1 828 …` 등)가 이제 차단된다. progress.md에 이 결과가 기록되어 있고, KAT가 이 번호를 국내 `122…`/`125…`/`182…`로 걸게 되므로 의도된 과차단이다.

### F2 [High] SPEC-LIFECYCLE-001 — 해소

- 원인 제거: 통화 종료 마감을 `terminateCallsMs - 250 ms`(최소 0)로 넘긴다. 기본값에서 내부 마감은 2,750 ms이고 바깥 단계 예산은 3,000 ms다.
  - `terminateActiveCalls`는 내부 마감에 맞춰 반환하며, 반환 전에 동기적으로 모든 통화에 `failed`와 종료 문구를 표시한다.
  - 그 뒤에야 `app.close()`와 `finalFlush()`가 실행된다.
- 견고성 검토: 이벤트 루프가 250 ms 넘게 막혀 두 타이머가 같은 차례에 만료되더라도, Node는 만료 시각 순서로 타이머를 실행하고 그 사이에 마이크로태스크를 처리한다(Node 11 이상). 따라서 마감이 더 이른 내부 타이머의 표시 작업이 먼저 끝난다. 이 판단은 코드와 런타임 동작에 근거한 추론이며, 실제로 루프를 막아 재현하지는 않았다.
- 1차가 요구한 통합 테스트: 새 테스트는 `createShutdownHandler`에 실제 `CallService`, `JsonFileTaskStore`, Fastify 앱, 끝나지 않는 `hangup`을 조합하고 디스크 내용을 단언한다. 수정을 되돌리면 실패하는 것도 확인했다(§2.2).
- REQ-003의 작업 ID 경고(`"Shutdown hangup did not finish in time"`)는 그대로 남는다. 단계 예산(3 s + 1 s + 5 s)도 바뀌지 않았다.

## 4. 남은 지적 사항 (판정에 영향 없음)

### R1 [Low, 문서] SPEC-POLICY-001 — REQ-004/AC-004 문구가 구현과 다르다

- 위치: `.moai/specs/SPEC-POLICY-001/spec.md:50`(REQ-004 "정규화할 수 없거나 비어 있으면 `undefined`… 새 거절 규칙을 만들지 않음"), `acceptance.md:46-48`
- 지금 동작: 정규화는 되지만 차단 번호로 분류된 회신 번호도 `undefined`가 된다(`50343ad`). 오류가 없으므로 "새 거절 규칙 없음"은 지켜진다. 다만 "차단 번호는 버린다"는 동작이 스펙에 적혀 있지 않다.
- spec.md의 `status: implemented`, `updated: 2026-11-21`은 그대로다. progress.md는 manager-spec 후속 작업이 필요하다고 스스로 적어 두었지만, 아직 반영되지 않았다(`grep -n callback spec.md acceptance.md`).
- 처리: manager-spec이 REQ-004와 AC-004에 차단 번호 행을 추가한다. Consistency를 80으로 매긴 이유다.

### R2 [Low, 문서, 1차 A2 미해소] SPEC-LIFECYCLE-001 OD-3 본문

- `spec.md:98`에는 아직 "14,371에서 `timeLimit`이 14,400에 닿고"라고 적혀 있다. 실측값은 `katTimeLimitSec(14370) = 14400`이다.
- progress.md 부록에 manager-spec 후속 작업으로 기록되어 있다.

### R3 [Low, 잔여 위험, 기존 동작] +82가 아닌 번호는 KAT에 국내 번호 형태로 전달된다

- 예: `+44 119 123 4567` → `441191234567`, `+1 (415) 555-0100` → `14155550100`
- 차단 번호로 시작하지 않으므로 이번 안전 규칙의 범위는 아니다. 그러나 국제 번호가 국내 문자열로 다이얼되는 구조는 남아 있다. progress.md의 residual_risk("non-+82 numbers reach KAT as bare digits")에 이미 기록되어 있다.
- `1588-1234`가 `+15881234`(북미 형식)로 저장되는 문제도 기존 동작으로 남는다.

### R4 [Low, 잔여 위험] 수정 전에 저장된 회신 번호

- 수정 전에 데이터 파일에 저장된 `+11200000000` 같은 회신 번호는 그대로 남는다. `approvePlan`은 대상 번호만 다시 검사한다.
- 회신 번호는 에이전트 프롬프트의 텍스트로만 쓰이고 발신 대상이 되지 않는다(progress.md에 기록).

### R5 [Informational] SPEC-LIFECYCLE-001 — 작은 단계 예산

- `terminateCallsMs`를 250 ms 이하로 설정하면 통화 종료 마감이 0 ms가 되어 종료 요청을 즉시 포기한다. 기본값과 무관하고 설정을 바꿀 때만 생기는 경계다.

## 5. SPEC별 근거와 점수

### SPEC-LIFECYCLE-001 — PASS (조화 평균 89.9)

- Functionality 95: F2를 해소했다. RED/GREEN을 직접 재현했고 1차 프로브 두 모드 모두 `on-disk=failed`였다. 1차에서 확인한 정상 동작(검사 순서, 두 번째 신호 즉시 종료, 9 s 상한)을 다루는 `shutdown.test.ts` 8건도 통과했다. R5 때문에 5점을 뺐다.
- Security 85: 1차와 같다. 수정 범위에 보안 표면이 없다.
- Craft 90: 커버리지는 `shutdown.ts` 구문 87.93%, 전체 92.3%다. 통합 테스트가 실제 저장소와 앱을 쓴다. 바깥 예산이 남는 이유를 주석으로 설명했다.
- Consistency 90: R2(1차 A2)가 남아 있다.

### SPEC-POLICY-001 — PASS (조화 평균 87.3)

- Functionality 90: F1과 A3를 해소했다. REQ-010 표기 6종은 계속 `blocked`이고 정상 국내 번호도 유지된다(1차 프로브와 테스트 13건). 북미 일부 지역번호 과차단은 의도된 부작용이다. 다만 스펙 문구와 어긋나는 R1 때문에 10점을 뺐다.
- Security 90: 판정 대상과 발신 대상이 한 함수로 합쳐졌다. 서비스·HTTP·`approvePlan`·자동 시작·intake 경로 모두 `checkTargetNumber`를 지난다. R3는 차단 번호 경로가 아니므로 이 차원에서 크게 감점하지 않았다.
- Craft 90: `phone.ts` 구문 97.77%, 분기 96.87%다. 정책 함수와 KAT 함수가 같다는 단언이 테스트에 있어 다시 갈라지는 것을 막는다.
- Consistency 80: R1. 스펙 본문이 구현된 동작을 따라가지 못했다.

## 6. progress.md 기록과 git의 일치 여부

- 두 SPEC 모두 progress.md의 "Audit-fix addendum"이 커밋 메시지와 diff 내용(원인, 수정 방식, 250 ms 여유, `allowedCallbackNumber`)과 일치한다.
- 기록에는 "수정 worktree 브랜치의 커밋"이라고 적혀 있다. 실제로는 세 커밋 모두 `main`에 들어 있다(`git branch --contains` → `* main`). `git log --grep`으로 찾으라는 안내는 맞으므로 문제는 없다.
- 기록에 적힌 GREEN 테스트 수(210, 211, 229)는 당시 시점의 값이다. 현재 387건은 이후 SPEC-INTAKE/APPROVAL/FOLLOWUP 커밋으로 늘어난 것으로 보이며, 모순은 없다.
- 기록이 인용한 RED/GREEN 로그(`.moai/state/verify/fix-audit-1/`, `fix-hotfix-1/`)는 열어 보지 않았다. 대신 §2.2에서 F2의 RED를 직접 재현했다.

## 7. 확인하지 못한 것 (Gaps)

- F1의 RED를 직접 재현하지 않았다(F2만 되돌려 보았다). 대신 1차 프로브가 1차 결과(`dialing`, `body.to=11912345678`)와 달리 이제 400을 돌려주는 것을 확인했다.
- 이벤트 루프가 250 ms 넘게 막힌 상황에서의 타이머 순서는 추론으로만 판단했다.
- 실제 통신망에서 `111912345678`이나 `441191234567` 같은 문자열을 어떻게 라우팅하는지는 확인하지 못했다. 실제 KAT 종료 API의 응답 시간 분포도 확인하지 못했다.
- 프로세스 단위 절차(실제 `index.ts`에 SIGTERM 보내기)는 다시 실행하지 않았다. 1차 프로브의 `createShutdownHandler`와 실제 앱 조합으로 갈음했다.
- 교차 모델 감사(codex/glm)는 실행하지 않았다.
- 서버 린터가 없어 Consistency는 `tsc`, grep, 문서 대조로만 평가했다.
- 동시에 진행 중인 SPEC-DESIGN-001 작업 경로(`packages/kolbi_ui`, `app/lib`)는 범위 밖이라 보지 않았다.

## 8. 잔여 위험

- 3 s 안에 끝나지 않은 KAT 종료 요청은 프로세스가 끝난 뒤에도 KAT 쪽 `timeLimit`(기본 630 s)까지 통화로 남을 수 있다. SPEC에 이미 적힌 위험이며 이번 수정으로 바뀌지 않았다.
- 차단 목록 밖의 특수번호(1588 대표번호 등)는 OD-2에 따라 범위 밖이다.
- R3: 국제 번호를 국내 문자열로 다이얼하는 구조는 그대로 남아 있다.
