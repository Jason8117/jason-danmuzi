# SPEC-POLICY-001 근거 자료

모든 줄 번호는 커밋 `f4d531e` 기준 작업 트리에서 직접 읽어 확인했다.

## 1. 정책이 HTTP 핸들러에 있다

`server/src/http/app.ts`

- `:9` `import { isBlockedNumber, normalizePhoneNumber } from "../domain/phone.js";`
- `:13` `import { type CallService, ServiceError } from "../services/callService.js";`
- `:117-125` `POST /v1/tasks`: 스키마 검증 → `normalizePhoneNumber` → 실패 시 `ServiceError(400, "invalid_phone", "전화번호 형식이 올바르지 않습니다.")` → `isBlockedNumber` → 참이면 `ServiceError(400, "blocked_number", "긴급·특수번호에는 전화할 수 없습니다.")` → 회신 번호 정규화(`?? undefined`) → `calls.create(...)` → 201.
- `:80-96` 오류 처리기: `ServiceError`를 `{ error: code, message }`로, `ZodError`를 `invalid_request`로 옮긴다.

## 2. 서비스는 입력을 그대로 믿는다

`server/src/services/callService.ts:91-107` `create(input)` — 입력을 펼쳐 작업을 만들고 바로 `persist`, `plan`. 번호 검사 없음.
`:21-29` `ServiceError(statusCode, code, message)` 정의.

`CallService.create`를 부르는 곳(이 세션에서 grep): `server/src/http/app.ts:123` 하나뿐. 지금은 우회 경로가 없지만, 진입점이 늘면 바로 우회된다.

## 3. 차단 규칙은 현재 도달할 수 없다

`server/src/domain/phone.ts`

- `:1` `const E164 = /^\+[1-9]\d{7,14}$/;` — `+` 뒤 8~15자리.
- `:7-19` `normalizePhoneNumber` — `0`으로 시작하면 `+82`로 바꾸고 E164 검사.
- `:22` 차단 목록 `["112", "119", "113", "114", "117", "118", "122", "125", "182"]`.
- `:24-28` `isBlockedNumber(e164)` — `+82` 뒤 국내 번호가 목록과 **정확히 같을 때만** 참. 즉 입력 길이가 6자(`+82` + 3자리)여야 한다.

6자 값은 E164 검사(최소 9자)를 통과할 수 없으므로, `normalizePhoneNumber`가 돌려준 값에 대해 `isBlockedNumber`는 항상 거짓이다. `app.ts:121`의 차단 분기는 도달 불가능하다.

**실행 확인(manager-spec, 이 세션)**: 스크래치 디렉터리의 스크립트를 `server/node_modules/.bin/tsx`로 실행해 `phone.ts`의 두 함수를 직접 호출했다.

| 입력 | `normalizePhoneNumber` | 차단 여부 |
|------|------------------------|-----------|
| `112` | `null` | 판정 불가 |
| `119` | `null` | 판정 불가 |
| `+82119` | `null` | 판정 불가 |
| `+82 112` | `null` | 판정 불가 |
| `0082119` | `null` | 판정 불가 |
| `0119` | `null` | 판정 불가 |
| `02-112` | `null` | 판정 불가 |
| `+82-182` | `null` | 판정 불가 |
| `182` | `null` | 판정 불가 |

따라서 지금 `119`를 입력하면 `invalid_phone`(문구 "전화번호 형식이 올바르지 않습니다.")으로 거절된다. 긴급번호 발신은 막히지만 차단 규칙 때문이 아니다.

기존 테스트도 이를 반영한다: `server/src/domain/domain.test.ts:16` `it.each(["", "abc", "112", "+12"])("rejects %s", …)` — `"112"` → `null`. `:20-23` `isBlockedNumber("+82119")` → 참(정규화를 거치지 않은 값을 직접 넣은 경우).

## 4. 기존 HTTP 테스트

`server/src/http/app.test.ts`

- `:58-67` "validates phone numbers": `phoneNumber: "12"` → 400, `error: "invalid_phone"`.
- `:69-73` 전체 흐름: `010-1234-5678` → 201, `phoneNumber` `+821012345678`.
- `blocked_number`를 검사하는 HTTP 테스트는 없다.

## 5. 앱의 오류 처리

`app/lib/core/network/api_client.dart:77-83` — 2xx가 아니면 응답의 `error`(없으면 `http_<code>`)와 문구를 `ApiException`에 담는다. 앱 코드에서 `invalid_phone`이나 `blocked_number` 문자열을 찾는 곳은 없다(`grep -rn "blocked_number\|invalid_phone" app/lib` 결과 0건, 이 세션).

`app/lib/core/network/api_client.dart:15-24` `userMessage` — `network`, `unauthorized`, `too_many_active_calls`, `daily_limit`, `approval_closed`, `invalid_state`만 앱 자체 문구로 바꾸고, 나머지 코드(`invalid_phone`, `blocked_number` 포함)는 서버 `message`를 그대로 보여 준다. `app/lib/core/widgets/common.dart:193`이 이 `userMessage`를 쓴다. 따라서 OD-1 RESOLVED(차단 규칙을 실제로 동작하게 함)에 따라 `119` 입력 시 사용자에게 보이는 문구가 "전화번호 형식이 올바르지 않습니다."에서 "긴급·특수번호에는 전화할 수 없습니다."로 바뀌고, 앱 코드는 바꿀 필요가 없다.

## 6. 기타 사용처

- `maskPhoneNumber`는 `server/src/providers/kat/katProvider.ts:4,111`에서 쓴다.
- `toKatPhoneNumber`(`katProvider.ts:47-51`)는 E.164 → 국내 표기 변환으로, 이 SPEC과 무관하다.
- 범위 밖 기록(plan-audit iteration 1 N7, plan-auditor가 직접 실행): `normalizePhoneNumber("1588-1234")` → `+15881234`. `0`으로 시작하지 않는 국내 대표번호가 북미 국가 번호 `+1` 형태로 바뀐다. `toKatPhoneNumber`가 `+82`가 아닌 값의 숫자만 남겨 `15881234`로 되돌리므로 지금 발신에는 영향이 없다. REQ-011이 정규화 결과를 그대로 유지하므로 이 동작도 그대로 남는다. 대표번호 정책(OD-2)을 정할 때 함께 볼 사항이다.

## 6-1. 발신 경로의 재검사 부재

`server/src/services/callService.ts:110-128` `approvePlan`: `:112` 상태 검사 → `:115` `assertWithinLimits()` → `:117` 계획 덮어쓰기 → `:119` `dialing` 전이 → `:123` `provider.start(session)`. 번호를 다시 보지 않는다. 작업은 `create`를 거쳐 만들어질 수도 있지만, 데이터 파일(`tasks.json`)에서 적재되거나 앞으로 다른 경로로 만들어질 수도 있다. 그래서 발신 직전 재검사를 둔다(REQ-007). 계획 승인 본문으로는 전화번호를 바꿀 수 없다(`server/src/http/schemas.ts:15-24`).

## 6-2. 판정 순서에서 `+`를 지우면 안 되는 이유

`normalizePhoneNumber`는 `+` 여부를 원문(`trimmed.startsWith("+")`, `phone.ts:13`)으로 본 뒤 숫자만 남긴다. 차단 판정에서 먼저 숫자만 뽑으면 `+82 112`가 `82112`가 되어 "`+82`로 시작" 규칙에 걸리지 않는다. 그래서 국가 번호 판정은 공백·하이픈·괄호·점만 지우고 맨 앞 `+`는 남긴 값에 대해 한다(REQ-010, plan.md §A).

## 7. 장기 방향과의 관계

`.moai/project/structure.md:163` — 새 연결 경로(허브 채널 등)를 제공자로 추가할 수 있는 구조지만 미정이라고 기록되어 있다. 진입점이 HTTP 밖으로 늘어날 가능성이 있으므로, 안전 규칙은 서비스 계층에 있어야 한다.
