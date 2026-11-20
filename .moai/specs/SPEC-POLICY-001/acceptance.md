# SPEC-POLICY-001 인수 기준

## 공통 검증 명령

```bash
export PATH=/opt/homebrew/Cellar/node/23.7.0/bin:$PATH
S=/Users/jason/Documents/Jason-Danmuzi/Jason-Danmuzi/server
npm --prefix $S test -- src/services/callService.test.ts src/domain/domain.test.ts src/http/app.test.ts
npm --prefix $S test
npm --prefix $S run typecheck
```

기준선(오케스트레이터 측정, plan-auditor 재측정): typecheck exit 0, 3개 파일 / 33개 테스트 통과. 이 SPEC은 SPEC-STORE-001, SPEC-LIFECYCLE-001 뒤에 구현되므로 실제 기준선에는 그 테스트가 더해진다.

규칙: 테스트를 먼저 작성해 현재 코드에서 실패(RED)하는 것을 확인한 뒤 구현한다.

## 인수 기준

### AC-001 — 서비스가 대상 번호를 정규화한다 (REQ-001)

- **Given** `InMemoryTaskStore`, `EventBus`, 호출을 기록하는 가짜 brain, 가짜 제공자로 만든 `CallService`
- **When** `create({ phoneNumber: "010-1234-5678", … })`를 호출하면
- **Then** 반환·저장된 작업의 `phoneNumber`가 `+821012345678`이다
- 테스트: `server/src/services/callService.test.ts` — "create normalizes the target number"
- RED: 현재 `create`는 원문 `010-1234-5678`을 그대로 저장한다.

### AC-002 — 형식 오류는 부작용 없이 거절 (REQ-002)

- **Given** AC-001과 같은 `CallService`
- **When** `create({ phoneNumber: "12", … })`를 호출하면
- **Then** `ServiceError`(상태 400, 코드 `invalid_phone`, 문구 "전화번호 형식이 올바르지 않습니다.")가 던져지고, `list()`는 빈 배열, 발행된 이벤트 0건, `createPlan` 호출 0회다
- 테스트: "create rejects an invalid number without side effects"
- RED: 현재는 작업이 만들어지고 계획이 시작된다.

### AC-003 — 차단 번호는 부작용 없이 거절 (REQ-003)

- **Given** AC-001과 같은 `CallService`
- **When** `create({ phoneNumber: "119", … })`와 `create({ phoneNumber: "+82 112", … })`를 호출하면
- **Then** 각각 `ServiceError`(400, `blocked_number`, "긴급·특수번호에는 전화할 수 없습니다.")가 던져지고, 저장·이벤트·계획 호출이 0건이다
- 테스트: "create blocks emergency and special numbers" (`it.each`)
- RED: 현재 `create`는 검사하지 않아 작업이 만들어진다.

### AC-004 — 회신 번호 처리 (REQ-004)

- **Given** AC-001과 같은 `CallService`
- **When** `callbackNumber`를 `"010 9999 8888"`, `"abc"`, `""`, 생략으로 각각 넣어 `create`를 호출하면
- **Then** 저장된 `callbackNumber`가 각각 `+821099998888`, `undefined`, `undefined`, `undefined`이고 어느 경우도 예외가 없다
- 테스트: "create normalizes or drops the callback number"
- RED: 현재 `create`는 원문을 저장한다.

### AC-005 — 규칙이 한 곳에 있고 우회 경로가 없다 (REQ-005, REQ-006)

```bash
cd /Users/jason/Documents/Jason-Danmuzi/Jason-Danmuzi/server
grep -n "from \"../domain/phone.js\"" src/services/callService.ts   # 1건 이상
grep -n "^[[:space:]]*create(" src/services/callService.ts          # 정확히 1건: create(input: CallTaskInput)
# 이 세션 기준선 출력: 91:  create(input: CallTaskInput): CallTask {
```

- 기대: 첫 명령 1건 이상(현재 0건 — RED), 두 번째 명령은 인자 하나짜리 `create` 정확히 1건.
- 보조: `domain.test.ts`의 판정 함수 테스트(AC-008, AC-009)가 `phone.ts`에서 함수를 가져온다.

### AC-006 — HTTP 계층에서 정책 코드 제거 (REQ-008)

```bash
grep -c "normalizePhoneNumber\|isBlockedNumber\|invalid_phone\|blocked_number" \
  /Users/jason/Documents/Jason-Danmuzi/Jason-Danmuzi/server/src/http/app.ts
```

- 기대: `0`
- RED: 현재 `5`(이 세션에서 실행해 확인 — `app.ts:9`, `:119`, `:120`, `:121`, `:122`).

### AC-007 — HTTP 외부 동작 (REQ-009)

`server/src/http/app.test.ts`:
- (a) 기존 "plans, calls, pauses for approval and summarizes"가 **수정 없이** 통과(201, `phoneNumber` `+821012345678`)
- (b) 기존 "validates phone numbers"가 **수정 없이** 통과(`phoneNumber: "12"` → 400, `error: "invalid_phone"`)
- (c) 새 테스트 "rejects emergency numbers with blocked_number": `phoneNumber: "119"` → 400, `error: "blocked_number"`, `message: "긴급·특수번호에는 전화할 수 없습니다."`. RED: 현재 `invalid_phone`이 나온다
- (d) 새 테스트 "keeps invalid_request for schema violations": `targetName` 누락 → 400 `invalid_request`(보호)

### AC-008 — 차단 규칙이 모든 표기에서 동작한다 (REQ-010)

- **Given** 도메인 판정 함수
- **When** `119`, `112`, `182`, `(119)`, `+82 119`, `+82-182`, `0082-112`, `0119`를 넣으면
- **Then** 모두 "차단"이다. 또한 `+82 112`처럼 `+` 뒤 국가 번호가 있는 표기가 차단된다는 것은 국가 번호 판정이 `+`를 남긴 원문에 대해 이루어졌음을 보여 준다
- 테스트: `server/src/domain/domain.test.ts` — "classifies Korean emergency and special codes as blocked in every notation"
- RED: 판정 함수가 없다. 참고로 현재 `normalizePhoneNumber`는 위 입력 모두에 `null`을 돌려준다(manager-spec과 plan-auditor가 각각 `tsx`로 실행해 확인 — research.md §3).

### AC-009 — 일반 번호와 차단 목록 불변 (REQ-011)

- **Given** 도메인 판정 함수와 기존 `normalizePhoneNumber`
- **When** `010-1234-5678`, `02 123 4567`, `+1 (415) 555-0100`, `0082 10 1234 5678`, `+1 911`, `""`, `abc`, `+12`를 넣으면
- **Then** 앞의 네 개는 "정상"이고 정규화 값이 기존 테스트(`domain.test.ts:7-14`)와 같으며, `+1 911`과 뒤의 세 개는 "형식 오류"다(`+1 911`은 `+82`가 아니므로 차단 대상이 아님). 기존 `domain.test.ts`의 `normalizePhoneNumber` 테스트(`"112"` → `null` 포함)와 `isBlockedNumber` 테스트는 수정 없이 통과한다
- 테스트: `domain.test.ts` — "keeps normal numbers and the block list unchanged"

### AC-010 — 발신 직전 재검사 (REQ-007)

- **Given** `start` 호출을 기록하는 가짜 제공자로 만든 `CallService`, 그리고 `create`를 거치지 않고 저장소에 직접 넣은 `awaiting_approval` 작업 둘: (1) `phoneNumber: "+82119"`, (2) `phoneNumber: "12"`
- **When** 각각 `approvePlan(id)`를 호출하면
- **Then** (1)은 `ServiceError`(400, `blocked_number`), (2)는 `ServiceError`(400, `invalid_phone`)이고, 두 작업 모두 `status`가 `awaiting_approval` 그대로, `startedAt` 없음, 가짜 제공자 `start` 호출 0회다. 비교로 `+821012345678` 작업은 정상적으로 `dialing`이 된다
- 테스트: `callService.test.ts` — "approvePlan re-checks the number right before dialing"
- RED: 현재 `approvePlan`은 번호를 보지 않아 (1)(2) 모두 `dialing`이 되고 `start`가 호출된다.
- (3) 검사 순서 503 → 404 → 409 → 400 → 429 고정(SPEC-LIFECYCLE-001 REQ-001 (d)): (i) `beginShutdown()` 뒤 차단 번호(`+82119`) `awaiting_approval` 작업 → 503 `shutting_down`(400 아님), (ii) 차단 번호를 가진 `in_progress` 작업 → 409 `invalid_state`(400 아님), (iii) `maxConcurrentCalls`가 이미 가득 찬 상태에서 차단 번호 `awaiting_approval` 작업 → 400 `blocked_number`(429 아님). 존재하지 않는 작업 ID는 종료 중이 아니면 404 `not_found`(현행), 종료 중이면 503이다(SPEC-LIFECYCLE-001 AC-001 (d)(3)) — 테스트: "approvePlan checks in the order shutting_down, state, number, limits". RED: (iii)은 현재 429가 나온다. (i)(ii)는 SPEC-LIFECYCLE-001 구현 뒤 이미 503·409가 나오는 보호 항목이며, 번호 재검사를 넣은 뒤에도 그대로 나와야 한다.

### AC-011 — 회귀 없음

- 서버 `npm test` 전체 통과, `npm run typecheck` exit 0.
- 앱 코드 변경 없음: `git -C /Users/jason/Documents/Jason-Danmuzi/Jason-Danmuzi diff --stat <run_start_sha>..HEAD -- app/` 출력이 비어 있다. `<run_start_sha>`는 run 진입 시 `progress.md` §E.2 첫 줄에 기록한 HEAD다.

## 엣지 케이스

- 이미 E.164인 값(`+821012345678`)을 서비스에 넘겨도 결과가 같다(정규화 멱등).
- 해외 3자리 번호(`+1 911`)는 `+82`가 아니어서 차단 판정을 건너뛰고, E.164 길이 검사에서 `invalid`가 된다. 해외 긴급번호를 차단 목록에 넣지 않는다(OD-2 DEFAULT).

## 완료 정의 (Definition of Done)

- AC-001 ~ AC-011 충족, RED/GREEN 원문을 `progress.md` §E.2에 기록.
- OD-2(추가 차단 정책)가 소유자 검토 대기 중인 기본값임을 sync-phase 문서에 기록(plan.md §G).
