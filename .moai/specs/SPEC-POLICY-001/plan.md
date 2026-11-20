# SPEC-POLICY-001 구현 계획

## A. 접근 방식

### 도메인 함수 (가장 먼저 확정할 결정)

`server/src/domain/phone.ts`에 대상 번호 판정 함수를 하나 둔다. 결과는 세 갈래다.

- 입력: 사용자가 입력했거나 저장된 문자열
- 출력: `{ kind: "ok", e164 }` | `{ kind: "invalid" }` | `{ kind: "blocked" }`

기존 `normalizePhoneNumber`, `isBlockedNumber`, `maskPhoneNumber`는 공개 함수로 남긴다(`domain.test.ts`와 `katProvider.ts`가 쓴다).

판정 순서(OD-1 RESOLVED):

1. **원문 정리**: 앞뒤 공백을 지우고, 공백·하이픈·괄호·점을 지운다. 맨 앞 `+`는 **지우지 않는다**. 이 값을 `compact`라 한다(예: `+82 112` → `+82112`, `(119)` → `119`, `0082-112` → `0082112`).
2. **국내 번호 추출**(국가 번호 판정은 `compact`에 대해 한다):
   - `compact`가 `+82`로 시작 → 그 뒤
   - `+82`가 아닌 `+`로 시작 → 국내 번호 없음(차단 판정 건너뜀)
   - `0082`로 시작 → 그 뒤
   - `0`으로 시작 → 첫 `0`을 뗀 나머지
   - 그 밖 → `compact` 그대로
3. 국내 번호가 차단 목록에 있으면 `blocked`.
4. 아니면 기존 `normalizePhoneNumber(원문)` 결과에 따라 `ok` 또는 `invalid`(정규화 규칙은 바꾸지 않음).
5. 방어 차원에서 `ok`일 때도 `isBlockedNumber(e164)`를 한 번 더 확인한다.

숫자만 먼저 뽑으면 `+`가 사라져 `+82 112`가 `82112`가 되고 2단계에서 빠진다. 그래서 1단계는 `+`를 남긴다.

### 서비스 — 생성 시점

`CallService.create(input)`의 첫 단계에서 판정 함수를 호출하고, `invalid`/`blocked`를 `ServiceError`로 바꿔 던진다. 회신 번호는 `normalizePhoneNumber(...) ?? undefined`. 이 처리를 마친 뒤에만 `persist`와 `plan`이 실행된다. 인자 타입(`CallTaskInput`)은 바꾸지 않는다. 이미 E.164인 값을 넘겨도 결과가 같다(정규화는 멱등).

SPEC-LIFECYCLE-001이 `create` 맨 앞에 종료 중 검사(503)를 넣었으므로, 번호 판정은 그 뒤에 둔다.

### 서비스 — 발신 직전

`approvePlan`의 검사 순서: 503 `shutting_down`(SPEC-LIFECYCLE-001 REQ-001 (d)) → 404 `not_found` → 409 `invalid_state` → 400 번호 재검사(이 SPEC) → 429 한도(`assertWithinLimits`). 즉 상태 검사(`awaiting_approval`) 뒤, 한도 검사·`dialing` 전이·`provider.start` 앞에 `task.phoneNumber`를 같은 판정 함수로 다시 확인한다. `invalid`/`blocked`면 작업을 바꾸지 않고 `ServiceError`를 던진다. 계획 승인 본문으로는 전화번호를 바꿀 수 없으므로(`server/src/http/schemas.ts:15-24`) 저장된 값만 보면 된다.

오류 문구 상수는 한 곳(`callService.ts` 또는 도메인 모듈)에만 정의한다.

### HTTP

`POST /v1/tasks` 핸들러는 `CreateTaskBody.parse` → `calls.create(body)` → 201만 남긴다. 기존 오류 처리기(`app.ts:80-96`)가 `ServiceError`를 이미 `{ error: code, message }`로 옮긴다. `normalizePhoneNumber`, `isBlockedNumber` import를 지운다.

## B. 변경 파일

| 파일 | 변경 | 이유 |
|------|------|------|
| `server/src/domain/phone.ts` | 수정 | 대상 번호 판정 함수 추가 |
| `server/src/services/callService.ts` | 수정 | `create`와 `approvePlan`에서 판정·정규화·`ServiceError` |
| `server/src/http/app.ts` | 수정 | 정책 코드와 import 제거 |
| `server/src/services/callService.test.ts` | 수정 | 서비스 단위 정책 테스트(SPEC-LIFECYCLE-001이 생성한 파일 확장) |
| `server/src/domain/domain.test.ts` | 수정 | 판정 함수 테스트 추가. 기존 테스트는 그대로 |
| `server/src/http/app.test.ts` | 수정 | HTTP 수준 `blocked_number` 테스트 1건 추가. 기존 테스트는 수정하지 않음 |

## C. 마일스톤 (우선순위 순, 하나씩 순서대로)

### M1 — 도메인 판정 함수 (Priority High)

RED (`server/src/domain/domain.test.ts`): AC-008(모든 표기 차단), AC-009(일반 번호·형식 오류 불변). 판정 함수가 없어 실패.

### M2 — 생성 시점 강제 (Priority High)

RED (`server/src/services/callService.test.ts`): AC-001(정규화 저장), AC-002(형식 오류 부작용 없음), AC-003(차단 부작용 없음), AC-004(회신 번호). 현재 `create`는 검사하지 않아 실패.

### M3 — 발신 직전 강제 (Priority High)

RED (`callService.test.ts`): AC-010 — 저장소에 직접 넣은 `awaiting_approval` 작업(`phoneNumber: "+82119"`)으로 `approvePlan` → `blocked_number`, 상태 불변, `provider.start` 0회. 현재 코드에서는 `dialing`으로 바뀌고 `start`가 호출되어 실패.

### M4 — HTTP 계층 정리 (Priority Medium)

RED: AC-007 (c)(`phoneNumber: "119"` → 400 `blocked_number`, 현재는 `invalid_phone`), AC-006(grep 현재 5).

### M5 — 회귀 확인 (Priority Low)

AC-005, AC-007 (a)(b)(d), AC-011.

## D. 위험 요소

| 위험 | 내용 | 대응 |
|------|------|------|
| 파일 겹침 | 아래 §D.1 행렬. `callService.ts`는 LIFECYCLE·ARCH, `callService.test.ts`는 LIFECYCLE(생성)·ARCH, `app.ts`는 ARCH, `app.test.ts`는 OUTCOME·ARCH와 겹친다. | LIFECYCLE 뒤에 구현한다(`depends_on`). `create`와 `approvePlan`의 앞부분만 건드리고, LIFECYCLE이 넣은 종료 중 검사·복구·종료 코드는 건드리지 않는다. ARCH가 `app.ts`의 제공자 라우트를 옮기므로, 이 SPEC은 `POST /v1/tasks` 핸들러와 import 줄만 바꾼다. |
| 오류 코드 변경 | `119` 입력의 오류 코드가 `invalid_phone`에서 `blocked_number`로 바뀐다(OD-1 RESOLVED). | 상태 코드는 같다. 앱은 두 코드 모두 서버 문구를 그대로 보여 주므로(`api_client.dart:15-24` — research.md §5) 앱 코드 변경이 없다. |
| 과잉 차단 | `0119`처럼 실제로는 쓰지 않는 표기도 차단된다. | 안전한 방향의 오판이다. 일반 번호는 8자리 이상이라 3자리 단축 번호와 겹치지 않는다. |
| 발신 직전 검사로 인한 오류 | 예전에 저장된 작업 중 판정이 `invalid`인 값이 있으면 승인이 거절된다. | 지금까지 저장된 값은 모두 `normalizePhoneNumber`를 통과한 E.164라 `ok`가 나온다(정규화 멱등). 손으로 고친 값만 영향을 받으며, 그 경우 거절이 맞다. |
| 서비스 시그니처 | `create`가 동기 함수로 예외를 던진다. | 동기 시그니처를 유지한다. 라우트 핸들러는 async라 동기 예외도 오류 처리기로 간다. |

### D.1 다섯 SPEC 파일 겹침 행렬 (plan-audit iteration 1 §3.1 기준)

| 파일 | STORE | LIFECYCLE | POLICY | OUTCOME | ARCH |
|------|:-----:|:---------:|:------:|:-------:|:----:|
| server/src/index.ts | O | O | | | O |
| server/src/services/callService.ts | | O | O | | O |
| server/src/services/callService.test.ts | | 신규 | O | | O |
| server/src/domain/types.ts | | O | | O | O |
| server/src/providers/types.ts | | O | | | O |
| server/src/providers/kat/katProvider.ts (+test) | | O | | | O |
| server/src/providers/simulatedProvider.ts | | 확인 | | | O |
| server/src/container.ts | | O | | | O |
| server/src/http/app.ts | | | O | | O |
| server/src/http/app.test.ts | | | O | O | O |
| server/src/brain/heuristicBrain.ts | | | | O | O |
| server/src/brain/openaiBrain.ts | | | | O | |
| server/src/brain/openaiBrain.test.ts | | | | 신규 | O |
| app/test/unit_test.dart | | O | | O | O |

이 SPEC만 쓰는 파일: `server/src/domain/phone.ts`, `server/src/domain/domain.test.ts`.

## E. 하네스·복잡도 지표

| 지표 | 값 |
|------|-----|
| 도메인 수 | 1 (server) |
| 변경 파일 수 | 6 (모두 수정) |
| REQ / AC | 11 / 11 |
| 위험 성격 | 긴급번호 자동 발신 방지(안전) |
| 권장 하네스 | standard + sync-auditor 검토(안전 규칙) |

## F. 자체 검증

- run 진입 시 HEAD를 `progress.md` §E.2 첫 줄에 `run_start_sha`로 기록(AC-011이 사용).
- 마일스톤별 RED/GREEN 원문을 `progress.md` §E.2에 기록.
- 전체 테스트·타입 검사 통과.

## G. sync-phase 문서 항목

- 차단 번호 입력 시 응답이 `invalid_phone`에서 `blocked_number`로 바뀐다(상태 코드 400 동일, 앱에 보이는 문구가 "긴급·특수번호에는 전화할 수 없습니다."로 바뀜).
- 발신 직전 재검사가 추가되었다.
- OD-2(추가 차단 정책)는 소유자 검토 대기 중인 기본값(추가 안 함)이다.
