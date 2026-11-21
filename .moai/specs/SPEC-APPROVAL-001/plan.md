# SPEC-APPROVAL-001 구현 계획

검토 순서 안내: 바뀔 가능성이 큰 결정(정제·마스킹 규칙, 안내 줄의 위치)을 앞에, 기계적인 보호 테스트와 회귀 확인을 뒤에 둔다.

## A. 접근 방식

### A.1 정제 규칙 — 도메인 순수 함수 (REQ-002, REQ-003, OD-1, OD-4)

- 새 파일 `server/src/domain/approvalComment.ts`에 정제 함수 하나(예: `sanitizeApprovalComment(raw: string): string | undefined`)와 자리표시 상수 `SENSITIVE_PLACEHOLDER = "[민감정보 삭제]"`를 둔다. 이름은 RED 테스트를 쓰며 확정한다.
- 처리 순서: 제어 문자 삭제·탭 변환 → 줄바꿈 정규화 → 연속 줄바꿈 축소 → 민감 숫자열 치환 → 앞뒤 공백 제거 → 빈 값이면 `undefined`.
- 민감 숫자열 판정(의사 규칙, 두 단계): (1) **최대 사슬**을 먼저 찾는다 — `\d(?:[ -]?\d)*`를 앞뒤로 더 늘릴 수 없게(앞 글자가 숫자도, "숫자 뒤 공백·하이픈 하나"도 아닌 위치에서 시작) 잡는다. 정규식 하나로 `{12,18}` 반복을 쓰면 긴 사슬의 앞부분만 잡히므로 쓰지 않는다(plan-audit D2: `010-1234-5678 010-9876-5432` → `[민감정보 삭제]-5432`가 관찰됨). (2) 사슬을 공백으로 나눈 토큰 중 `^0\d{1,2}-\d{3,4}-\d{4}$`에 맞는 토큰은 전화번호 토큰으로 남긴다. (3) 나머지 연속 토큰을 공백으로 다시 이은 조각마다 숫자가 13개 이상이면(상한 없음) 조각 전체를 `[민감정보 삭제]`로 바꾼다. 상한을 두지 않는 이유: 카드번호 뒤에 유효기간·CVC가 이어진 입력이 통째로 빠져나가는 것을 막기 위해서다(plan-audit iteration 2 N1). 이 의사 구현을 Python으로 돌린 결과가 AC-003 표와 같다.
- 길이 제한(500 코드 포인트)은 지금처럼 HTTP 스키마(`schemas.ts:28-52`)가 정제 전 값으로 검사한다. 마스킹은 항상 문자열을 줄이므로(13자 이상 → 9자) 정제 뒤 길이가 상한을 넘을 일이 없다.

### A.2 서비스 적용과 안내 줄 (REQ-005, REQ-006)

- `CallService.respondToApproval`(`callService.ts:285-298`)에서 `input.comment`를 정제한 값으로 바꿔 `resolveApproval`에 넘긴다. 상태 검사(409)는 정제보다 먼저 해서, 닫힌 승인에는 아무것도 하지 않는다(REQ-010).
- `resolveApproval`(`:436-458`)에서 승인 저장 직후, `pending.resolve(...)`를 부르기 **전에** 안내 줄을 추가한다. 이렇게 하면 결정을 기다리던 제공자(시뮬레이션의 `await session.requestApproval`, Realtime 브리지의 `handleTool`)가 다음 줄을 쓰기 전에 안내 줄이 들어간다(REQ-006 순서). 줄 추가는 통화 진행 중일 때만 한다(`isActiveCall`). 만료·취소 경로(`input.comment` 없음)는 줄을 쓰지 않는다.
- 접두어는 작업 언어로 고른다(`ko` → `사용자 안내:`, `en` → `User guidance:`).
- `server/src/providers/simulatedProvider.ts:83-85`의 자체 안내 줄 세 줄을 지운다. 지우지 않으면 시뮬레이션에서 줄이 두 번 생긴다(AC-006 (6)).

### A.3 통화 지시문 (REQ-008)

- `server/src/brain/prompts.ts`의 "Hard rules"에 7번 규칙을 더한다. 문장은 영어(기존 지시문과 같은 언어). 기존 1~6번 문구는 바꾸지 않는다(`prompts.test.ts`의 기존 단언 보호).

### A.4 Realtime 도구 결과 (REQ-007)

- 코드 변경 없음. `realtimeBridge.ts:126-138, 302-328`의 현재 형태를 `it.each` 보호 테스트로 고정한다. 정제된 코멘트가 서비스에서 오므로 브리지는 그대로 둔다.

### A.5 승인 카드 (REQ-011 ~ REQ-014)

- 새 파일 `app/lib/features/calls/domain/approval_comment.dart`: 코드 포인트 길이 계산, 500 코드 포인트로 자르는 입력 포매터, 민감 숫자열 판정(서버와 같은 규칙, 같은 테스트 벡터), 빠른 답 문구 상수(OD-2).
- `approval_card.dart`
  - 입력칸: `minLines: 1`, `maxLines: 4`, `maxLength` 대신 코드 포인트 포매터. 카운터는 400 이상일 때만.
  - 라벨 "조건 덧붙이기 (선택)", 도움말 고정 문구.
  - 칩 행(`Wrap` + `ActionChip`), 누르면 입력칸에 넣기만 함.
  - 민감 숫자열 경고 줄.
  - 실패 시 코멘트 유지(현행 `:61-62`)는 그대로.
- 색·간격은 기존 테마 값과 `core/widgets/common.dart`만 쓴다(SPEC-UX-001이 나중에 바꿈). 위젯 테스트는 문구로 요소를 찾는다.

### A.6 상세 화면 (REQ-015)

- 코드 변경 없음(현행 `_ApprovalHistory`, `TranscriptView`의 `system` 렌더링). 보호 테스트만 추가.

## B. 변경 파일

서버:

| 파일 | 변경 | 이유 |
|------|------|------|
| `server/src/domain/approvalComment.ts` | 신규 | 정제·마스킹 규칙 |
| `server/src/domain/approvalComment.test.ts` | 신규 | AC-002, AC-003 |
| `server/src/services/callService.ts` | 수정 | 정제 적용, 안내 줄 |
| `server/src/services/callService.test.ts` | 수정 | AC-004 (B), AC-005, AC-006 (1)~(5) |
| `server/src/providers/simulatedProvider.ts` | 수정 | 자체 안내 줄 제거 (`:83-85`) |
| `server/src/brain/prompts.ts` | 수정 | Hard rule 7 |
| `server/src/brain/prompts.test.ts` | 수정 | AC-008 |
| `server/src/providers/realtimeBridge.test.ts` | 수정 | AC-007 |
| `server/src/http/app.test.ts` | 수정 | AC-001, AC-004 (A), AC-006 (6) (새 테스트만 추가) |

앱:

| 파일 | 변경 | 이유 |
|------|------|------|
| `app/lib/features/calls/domain/approval_comment.dart` | 신규 | 코드 포인트·민감 숫자 규칙, 칩 문구 |
| `app/lib/features/calls/presentation/widgets/approval_card.dart` | 수정 | 칩, 한 줄 입력칸, 경고 |
| `app/test/approval_card_test.dart` | 신규 | AC-009 ~ AC-013 |
| `app/test/support/fakes.dart` | 수정 | `decide` 오류 주입 필드 |
| `app/test/approval_flow_test.dart` | 수정 | AC-014 라벨 한 줄 |
| `app/test/unit_test.dart` | 수정 | 앱 민감 숫자 규칙·코드 포인트 단위 테스트(AC-011 규칙과 같은 벡터) |

바꾸지 않는 파일(확인만): `server/src/http/schemas.ts`(길이 규칙 현행 유지), `server/src/http/app.ts`, `server/src/providers/realtimeBridge.ts`, `server/src/domain/types.ts`, `app/lib/features/calls/presentation/call_detail_screen.dart`, `transcript_view.dart`, `calls_repository.dart`.

## C. 마일스톤 (우선순위 순, 하나씩 순서대로)

### M1 — 정제 규칙 (Priority High)

가장 바뀔 가능성이 큰 결정(OD-1 마스킹 vs 거절, OD-4 13자리 이상·상한 없음, 전화번호 토큰 예외)이라 먼저 한다.

RED: `approvalComment.test.ts` — AC-002, AC-003 표 전체. 함수가 없어 실패.

### M2 — 서비스 적용과 안내 줄 (Priority High)

RED (`callService.test.ts`): AC-004 (B), AC-006 (1)(2). 보호: AC-005, AC-006 (3)(4)(5).
RED (`app.test.ts`): AC-004 (A). 보호→회귀 방지: AC-006 (6)(서비스 줄 추가 후 시뮬레이션 줄을 지우기 전에는 2줄이 되어 실패하는 것을 확인하고, 제공자 줄을 지워 GREEN).
함께: `simulatedProvider.ts:83-85` 삭제.

### M3 — 통화 지시문 (Priority Medium)

RED (`prompts.test.ts`): AC-008.

### M4 — 승인 카드 (Priority Medium)

RED (`approval_card_test.dart`): AC-009, AC-010, AC-011. 보호: AC-012, AC-013.
함께: AC-014 라벨 한 줄 교체(같은 커밋, 그렇지 않으면 스위트가 빨갛게 남음).

### M5 — 도구 결과 보호 테스트와 입력 경계 (Priority Low)

보호: AC-007(`realtimeBridge.test.ts`), AC-001(`app.test.ts`, (5)(6) 포함).

### M6 — 회귀 확인 (Priority Low)

AC-015: 서버 전체 테스트·타입 검사, 앱 `flutter test`·`flutter analyze`, `architecture.test.ts` 무수정 통과.

## D. 위험 요소

| 위험 | 내용 | 대응 |
|------|------|------|
| 안내 줄 순서 | `pending.resolve` 뒤에 줄을 쓰면 시뮬레이션 제공자의 다음 줄이 먼저 들어갈 수 있다(마이크로태스크 순서). | 저장 직후·`resolve` 전에 쓴다(A.2). AC-006 (1)이 순서를 단언한다. |
| 중복 줄 | 서비스와 시뮬레이션이 둘 다 쓰면 2줄. | M2에서 제공자 줄 삭제, AC-006 (6). |
| 마스킹 과잉 | 13자리 이상 계좌번호도 가려진다. | OD-4로 소유자 검토. 잔여 위험으로 기록. |
| 앱·서버 규칙 불일치 | 앱 경고와 서버 마스킹이 다른 규칙이면 경고 없이 가려지거나 반대가 된다. | 같은 테스트 벡터(AC-003 표의 행)를 앱 `unit_test.dart`에도 둔다. |
| 기존 테스트 라벨 | `approval_flow_test.dart:55`가 옛 라벨을 찾는다. | AC-014로 한 줄만 바꾼다. |
| SPEC-UX-001과의 겹침 | 승인 카드는 UX가 다시 꾸민다. | 이 SPEC 테스트는 문구·동작만 단언(§4 제약). |

### D.1 에픽 내 파일 겹침

| 파일 | APPROVAL | INTAKE | FOLLOWUP | UX |
|------|:-:|:-:|:-:|:-:|
| `server/src/services/callService.ts` (+test) | O | O | | |
| `server/src/brain/prompts.ts` (+test) | O | O | O | |
| `server/src/http/app.test.ts` | O | O | | |
| `app/lib/features/calls/presentation/widgets/approval_card.dart` | O | | | O |
| `app/test/support/fakes.dart` | O | O | O | |
| `app/test/unit_test.dart` | O | O | O | |

직렬 순서(`depends_on`)로 겹침을 해소한다. 이 SPEC이 먼저 들어가므로 뒤 SPEC은 이 SPEC의 결과 위에서 시작한다.

## E. 하네스·복잡도 지표

| 지표 | 값 |
|------|-----|
| Tier | M |
| 도메인 수 | 2 (server service·domain·brain, app UI) |
| 변경 파일 수 | 15 (서버 신규 2·수정 7, 앱 신규 2·수정 4) |
| REQ / AC | 16 / 15 |
| 외부 연동 | OpenAI Realtime(가짜 소켓으로만 검증) |
| 사용자 영향 | 통화 중 승인 카드, 대화 기록 |
| 권장 하네스 | standard |

## F. 자체 검증

- 마일스톤별 RED/GREEN 원문을 `progress.md` §E.2에 기록.
- 보호 테스트(현행 고정)는 "처음부터 통과"로 기록하고, 그 테스트가 실제로 무엇을 고정하는지 한 줄로 적는다.
- `grep -n "사용자 안내" server/src` 결과가 서비스 한 곳(과 테스트)뿐임을 확인(시뮬레이션 제공자에서 사라짐).

## G. sync-phase 문서 항목

- 승인 코멘트의 정제·마스킹 규칙과 자리표시 문구(OD-1, OD-4 DEFAULT).
- 실통화에서도 대화 기록에 "사용자 안내:" 줄이 남는다는 동작 변경(이전에는 시뮬레이션만).
- 빠른 답 칩 문구(OD-2 DEFAULT)와 입력칸 라벨 변경.
- 서버·앱 같은 릴리스 배포.
