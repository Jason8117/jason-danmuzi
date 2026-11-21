# SPEC-APPROVAL-001 인수 기준

## 공통 검증 명령

저장소 루트(작업 트리)에서:

```bash
npm --prefix server test -- src/domain/approvalComment.test.ts src/services/callService.test.ts src/providers/realtimeBridge.test.ts src/brain/prompts.test.ts src/http/app.test.ts
npm --prefix server test
npm --prefix server run typecheck
```

앱(작업 디렉터리 `app/`):

```bash
flutter --suppress-analytics test test/approval_card_test.dart test/approval_flow_test.dart test/unit_test.dart
flutter --suppress-analytics test
flutter --suppress-analytics analyze
```

기준선: 이 SPEC 작성 중에는 테스트를 실행하지 않았다. run-phase 시작 시 manager-develop이 위 전체 명령의 결과(테스트 파일·개수, typecheck 종료 코드, analyze 결과)를 `progress.md` §E.2 첫 부분에 기록하고, 그 값을 기준선으로 쓴다.

규칙: 테스트를 먼저 작성해 현재 코드에서 실패(RED)하는 것을 확인한 뒤 구현한다. "현행 고정"으로 표시한 기준은 현재 코드에서 이미 통과할 수 있으며(보호 테스트), 그 경우 RED 대신 "처음부터 통과"를 기록한다.

## 인수 기준

### AC-001 — 코멘트 입력 규칙 (REQ-001)

- **Given** 시뮬레이션 모드 서버(`app.test.ts`의 구성)에서 승인 대기 중인 작업
- **When** 결정 본문을 각각 (1) `{"decision":"approve"}`, (2) `{"decision":"approve","comment":"   "}`, (3) `comment`가 "가" 500개, (4) "가" 501개, (5) 가족 이모지 `👨‍👩‍👧`(코드 포인트 5개) 100개(=500 코드 포인트), (6) 같은 이모지 101개(=505)로 보내면 (각 경우 새 작업)
- **Then** (1)(2)(3)(5)는 200이고 (1)(2)는 `userComment`가 없으며 (3)(5)는 보낸 값 그대로다. (4)(6)은 400 `{"error":"invalid_request"}`다
- 테스트: `server/src/http/app.test.ts` — "counts approval comment length in code points" (`it.each`)
- 참고: (1)~(4)는 현행 고정. (5)(6)은 문자소와 코드 포인트의 차이를 고정한다.

### AC-002 — 제어 문자 정제 (REQ-002)

- **Given** 정제 함수(`server/src/domain/approvalComment.ts`, 새 파일)
- **When** 다음 입력을 넣으면
- **Then** 결과는 다음과 같다

| 입력(JS 문자열) | 결과 |
|------|------|
| `"a\u0000b"` | `"ab"` |
| `"a\tb"` | `"a b"` |
| `"a\r\nb\rc"` | `"a\nb\nc"` |
| `"a\n\n\n\nb"` | `"a\n\nb"` |
| `"\u0085x"` | `"x"` |
| `"\u0007   "` | 없음(`undefined`) |
| `"  1만 원까지만  "` | `"1만 원까지만"` |

- 테스트: `server/src/domain/approvalComment.test.ts`(새 파일) — "sanitizes control characters and line breaks" (`it.each`)
- RED: 함수가 없다.

### AC-003 — 민감 숫자열 마스킹 (REQ-003)

- **Given** 같은 정제 함수
- **When** 다음 입력을 넣으면
- **Then** 결과는 다음과 같다

| 입력 | 결과 |
|------|------|
| `카드 1234-5678-9012-3456로 결제` | `카드 [민감정보 삭제]로 결제` |
| `주민번호 900101-1234567` | `주민번호 [민감정보 삭제]` |
| `1234 5678 9012 345 입니다` (15자리) | `[민감정보 삭제] 입니다` |
| `4111111111111111` | `[민감정보 삭제]` |
| `010-1234-5678로 연락 주세요` (11자리) | 그대로 |
| `주문 2024-1234-5678` (12자리) | 그대로 |
| `12345678901234567890` (20자리, 상한 없음) | `[민감정보 삭제]` |
| `1234--5678-9012-3456` (하이픈 두 개가 끊음) | 그대로 |
| `카드 1111 2222 3333 4444, 다른 카드 5555-6666-7777-8888` | `카드 [민감정보 삭제], 다른 카드 [민감정보 삭제]` |
| `010-1234-5678 010-9876-5432` (두 토큰 모두 전화번호 토큰) | 그대로 |
| `1234 5678 9012 3456 7890` (20자리, 전화번호 토큰 없음) | `[민감정보 삭제]` |
| `카드 1234-5678-9012-3456 0101` (카드번호 + 유효기간) | `카드 [민감정보 삭제]` |
| `카드 1234 5678 9012 3456 1225 123` (카드번호 + 유효기간 + CVC) | `카드 [민감정보 삭제]` |
| `주민번호 900101-1234567 010-1234-5678` (뒤 토큰만 전화번호) | `주민번호 [민감정보 삭제] 010-1234-5678` |
| `010-1234-5678 1234 5678 9012 3456` (전화번호 + 카드번호) | `010-1234-5678 [민감정보 삭제]` |
| `01012345678 01098765432` (하이픈 없는 전화번호 둘, 예외 아님) | `[민감정보 삭제]` |

위 표의 기대값은 2026-11-21 이 SPEC 작성 중 REQ-003의 세 단계 규칙을 Python으로 구현해 모든 행에 돌린 출력과 같다(구현자는 같은 표로 다시 확인한다).

같은 표의 모든 행을 앱 쪽 판정(AC-011의 경고 규칙)에도 쓴다: 결과가 바뀌는 행은 경고가 보이고, "그대로"인 행은 경고가 없다(`app/test/unit_test.dart` — "detects sensitive digit runs like the server").

- 테스트: `approvalComment.test.ts` — "masks card- and ID-shaped digit runs" (`it.each`)
- RED: 함수가 없다.

### AC-004 — 정제된 값이 저장·전달된다 (REQ-003, REQ-005)

- **Given** (A) 시뮬레이션 모드 서버의 승인 대기 작업, (B) `requestApproval`을 부르고 받은 결정을 기록하는 가짜 제공자를 쓴 `CallService`
- **When** (A) `{"decision":"approve","comment":"카드 1234 5678 9012 3456 말고 계좌이체"}`를 보내고, (B) 같은 코멘트로 `respondToApproval(..., { approve: true, comment })`를 부르면
- **Then** (A) 응답의 `approvals[0]`은 `status: "approved"`, `resolvedAt` 있음, `userComment: "카드 [민감정보 삭제] 말고 계좌이체"`이고, 작업 JSON 전체를 문자열로 바꿨을 때 `1234 5678 9012 3456`이 없다. (B) 가짜 제공자가 받은 결정은 `{ approved: true, comment: "카드 [민감정보 삭제] 말고 계좌이체", reason: "user_approved" }`다. 거절로 같은 시험을 하면 `reason: "user_rejected"`, `approved: false`다
- 테스트: `app.test.ts` — "stores the masked approval comment"; `callService.test.ts` — "resolves the approval with the sanitized comment" (승인·거절 2건)
- RED: 현재 원문 그대로 저장·전달된다.

### AC-005 — 코멘트는 로그에 남지 않는다 (REQ-004)

- **Given** 호출을 기록하는 가짜 로거를 쓴 `CallService`와 AC-004 (B)의 가짜 제공자, 코멘트 `"비밀안내문구-XYZ 1234 5678 9012 3456"`
- **When** 승인 요청 → 결정(코멘트 포함) → 통화 종료까지 실행하면
- **Then** 가짜 로거가 받은 모든 객체와 메시지를 `JSON.stringify`한 문자열 어디에도 `비밀안내문구-XYZ`, `1234 5678 9012 3456`, `[민감정보 삭제]`가 없다
- 테스트: `callService.test.ts` — "never logs approval comments"
- 참고: 현재 코드에서도 통과할 수 있다(보호 테스트). 정제·안내 줄 추가가 로그를 새로 만들지 않음을 고정한다. HTTP 계층 요청 로그는 직렬화기가 `method`와 `url`만 남기므로(`server/src/http/app.ts:102-107`) 본문(코멘트)이 들어가지 않는다. 이 직렬화기는 이 SPEC에서 바꾸지 않으며, `git diff <run_start_sha> -- server/src/http/app.ts`가 비어 있음을 함께 기록한다.

### AC-006 — 안내 줄은 제공자와 무관하게 한 줄 (REQ-006, REQ-009, REQ-010)

- **Given** 결정을 받은 뒤 `appendTranscript("agent", "확인했습니다")`를 쓰는 가짜 제공자를 쓴 `CallService`
- **When / Then**
  1. 작업 언어 `ko`, 코멘트 `1만 원까지만`으로 승인 → `system` 줄이 정확히 하나이고 `사용자 안내: 1만 원까지만`이며, 그 줄이 `확인했습니다` 줄보다 앞에 있다
  2. 작업 언어 `en`, 코멘트 `up to 10,000 won` → `User guidance: up to 10,000 won`
  3. 가짜 타이머로 `approvalTimeoutMs`만큼 진행(만료) → 안내 줄 없음, 결정의 `approved`가 `false`, `reason`이 `"expired"`, `comment`가 `undefined`(`expect(decision.comment).toBeUndefined()` — 키 유무는 단언하지 않음, 현재 `callService.ts:453-457`은 키를 넣고 값만 비움), 승인 `status: "expired"`, `userComment` 없음
  4. (1) 뒤 같은 승인에 `{ approve: false, comment: "취소" }`를 다시 보냄 → `ServiceError` 409 `approval_closed`, `userComment`는 `1만 원까지만` 그대로, `system` 줄 수 그대로(1)
  5. 코멘트 없이 승인 → 안내 줄 없음
  6. 시뮬레이션 서버 전체 흐름(`app.test.ts`)에서 코멘트 `1만 원까지만`으로 승인한 작업이 `completed`가 되면 `사용자 안내: 1만 원까지만` 줄이 정확히 하나다(시뮬레이션 제공자 중복 제거 확인)
- 테스트: `callService.test.ts` — "appends one guidance line per commented decision" (1~5); `app.test.ts` — "records the guidance line once in a simulated call" (6)
- RED: 현재 서비스는 안내 줄을 쓰지 않아 (1)(2) 실패, (6)은 시뮬레이션 제공자만 쓰므로 현재 통과할 수 있으나 서비스가 줄을 쓰게 된 뒤 제공자 줄을 지우지 않으면 2줄이 되어 실패한다(중복 회귀 방지). (3)(4)(5)는 보호 테스트.

### AC-007 — Realtime 도구 결과 형태 (REQ-007, REQ-009)

- **Given** `realtimeBridge.test.ts`의 가짜 소켓과 결정을 돌려주는 가짜 세션
- **When** `request_user_approval` 호출에 대해 세션이 다음 결정을 돌려주면: (a) `{approved:true, comment:"1만 원까지만", reason:"user_approved"}`, (b) `{approved:true, reason:"user_approved"}`, (c) `{approved:false, comment:"다음 주로 물어봐 주세요", reason:"user_rejected"}`, (d) `{approved:false, reason:"expired"}`, (e) `{approved:false, reason:"canceled"}`
- **Then** 보낸 `function_call_output`의 `output`을 JSON으로 해석하면 키가 정확히 `approved`, `reason`, `user_comment`, `instruction` 넷이고, `user_comment`는 (a) `"1만 원까지만"`, (c) `"다음 주로 물어봐 주세요"`, 나머지는 `null`이며, `instruction`은 (a) "approved with these conditions"와 "1만 원까지만", (b) "Proceed with exactly what was asked", (c) "declined", "without agreeing to the declined item", "다음 주로 물어봐 주세요", (d) "did not answer in time", (e) "Politely decline"을 포함하고, 다섯 모두 "never share card/password/SSN"을 포함한다. 각 경우 뒤이어 `{type:"response.create"}`를 보낸다
- 테스트: `realtimeBridge.test.ts` — "returns every approval decision shape as tool output" (`it.each`)
- 참고: 보호 테스트(현행 고정). 기존 테스트 "(e) turns the approval tool into a user approval…"는 수정하지 않는다.

### AC-008 — 통화 지시문의 코멘트 규칙 (REQ-008)

- **Given** 계획이 있는 작업
- **When** `buildAgentInstructions(task)`를 부르면
- **Then** 결과에 `user_comment`와 `[민감정보 삭제]`가 들어 있고, 그 규칙 문단에 "card numbers", "passwords"가 함께 나온다. 기존 `prompts.test.ts` 테스트 5개는 수정 없이 통과한다
- 테스트: `server/src/brain/prompts.test.ts` — "tells the agent how to follow a user_comment"
- RED: 현재 지시문에 `user_comment`가 없다.

### AC-009 — 빠른 답 칩 (REQ-011)

- **Given** 대기 중인 승인이 있는 작업으로 연 통화 상세 화면(가짜 저장소, `approval_flow_test.dart`의 `pumpApp` 방식)
- **When** (1) 칩 세 개를 찾고, (2) "금액이 더 나오면 거절해 주세요"를 누르고, (3) "다른 날짜·시간도 물어봐 주세요"를 누르고, (4) 같은 칩을 한 번 더 누르고, (5) "승인"을 누르면
- **Then** (1) 세 문구가 각각 한 번씩 보인다. (2) 뒤 입력칸 글은 칩 1 문구와 같고 `repo.decisions`는 비어 있다. (3) 뒤 `금액이 더 나오면 거절해 주세요 다른 날짜·시간도 물어봐 주세요`. (4) 뒤 변화 없음. (5) 뒤 `repo.decisions.single`은 `(approvalId: 'approval-1', approve: true, comment: '금액이 더 나오면 거절해 주세요 다른 날짜·시간도 물어봐 주세요')`다
- 테스트: `app/test/approval_card_test.dart`(새 파일) — "quick replies fill the comment without sending"
- RED: 칩이 없다.

### AC-010 — 한 줄 입력칸과 글자 수 (REQ-012)

- **Given** AC-009와 같은 화면
- **When / Then**
  1. 처음 렌더링 → 라벨 "조건 덧붙이기 (선택)"과 도움말 "카드번호·비밀번호·주민번호는 적지 마세요."가 보이고, 입력칸 `TextField`의 `minLines`가 1, `maxLines`가 4다
  2. "가" 399개 입력 → `/ 500`을 포함한 글이 없다
  3. "가" 400개 입력 → `400 / 500`이 보인다
  4. "가" 501개 입력 → 입력칸 글의 코드 포인트 수(`runes.length`)가 500이다
  5. `👨‍👩‍👧` 101개 입력 → 입력칸 글의 코드 포인트 수가 500 이하이고, 승인 시 보낸 `comment`의 코드 포인트 수도 500 이하다
- 테스트: `approval_card_test.dart` — "comment field starts as one line and counts code points"
- RED: 현재 `minLines` 2, 라벨 문구 다름, 글자 수가 문자소 기준이라 (5)에서 500 코드 포인트를 넘는다.

### AC-011 — 민감 숫자 경고 (REQ-013)

- **Given** AC-009와 같은 화면
- **When** (1) `1234-5678-9012-3456`을 입력하고 "승인"을 누르면, (2) 새로 연 화면에 `010-1234-5678로 연락`을 입력하면
- **Then** (1) "카드번호처럼 보이는 숫자는 지우고 보낼게요."가 보이고 "승인" 버튼이 눌리며, `repo.decisions.single.comment`는 `1234-5678-9012-3456`(앱은 마스킹하지 않음). (2) 경고가 없다
- 테스트: `approval_card_test.dart` — "warns about card-shaped numbers without blocking"
- RED: 경고가 없다.

### AC-012 — 실패 시 코멘트 유지 (REQ-014)

- **Given** `decide`가 `ApiException('approval_closed', …, statusCode: 409)`를 던지도록 설정한 가짜 저장소(`test/support/fakes.dart`에 오류 주입 필드 추가)
- **When** 코멘트 `1만 원까지만`을 입력하고 "승인"을 누르면
- **Then** 스낵바에 "이미 처리되었거나 시간이 지난 요청이에요."가 보이고, 입력칸 글은 `1만 원까지만` 그대로이며, "승인"·"거절" 버튼이 다시 눌린다(`onPressed != null`)
- 테스트: `approval_card_test.dart` — "keeps the comment when sending fails"
- 참고: 보호 테스트(현행 `approval_card.dart:61-62` 동작).

### AC-013 — 상세 화면에서 안내 확인 (REQ-015)

- **Given** `status: "completed"`, 승인 1건(`status: "approved"`, `userComment: "1만 원까지만"`), 대화 기록에 `system` 줄 `사용자 안내: 1만 원까지만`이 있는 작업
- **When** 통화 상세 화면을 렌더링하면
- **Then** 승인 이력에 `안내: 1만 원까지만`을 포함한 글이 보이고, 대화 기록에 `사용자 안내: 1만 원까지만`이 보이며, 그 글은 "AI 비서"·상대 이름 라벨이 붙은 말풍선 안에 있지 않다
- 테스트: `approval_card_test.dart` — "shows the guidance in history and transcript"
- 참고: 보호 테스트.

### AC-014 — 의도된 기존 테스트 변경 (REQ-016)

- **Given** `app/test/approval_flow_test.dart`의 테스트 "user approves a mid-call request from the live call screen"
- **When** 단언 `expect(find.text('조건·안내 (선택)'), findsOneWidget);` 한 줄을 `expect(find.text('조건 덧붙이기 (선택)'), findsOneWidget);`로 바꾸고 실행하면
- **Then** 이 테스트가 통과하고, `git diff <run_start_sha> -- app/test/approval_flow_test.dart`가 이 한 줄 교체만 보여 준다. 다른 기존 테스트 파일은 새 테스트 추가 외에 기존 단언이 바뀌지 않는다
- RED: 한 줄을 바꾼 직후 현재 코드에서 실패한다.

### AC-015 — 회귀 없음

- 서버 `npm --prefix server test` 전체 통과, `npm --prefix server run typecheck` 종료 코드 0.
- 앱 `flutter test` 전체 통과, `flutter analyze` 결과가 run-phase 기준선보다 늘지 않음.
- `server/src/architecture.test.ts`가 수정 없이 통과(새 도메인 파일은 `domain/` 아래이며 다른 계층을 가져오지 않음).

## 엣지 케이스

- 코멘트가 마스킹만 남는 경우(`1234567890123456`) → 저장값 `[민감정보 삭제]`, 안내 줄 `사용자 안내: [민감정보 삭제]`. 지시문 규칙(REQ-008)에 따라 AI는 그 정보를 요청자가 직접 전한다고 말한다.
- 결정과 통화 종료가 겹쳐 통화가 이미 `summarizing`이면 → 승인 상태·`userComment`는 저장되지만 안내 줄은 추가되지 않는다(REQ-006의 "통화 진행 중" 조건). 별도 AC 없이 AC-006 (1)의 구현 조건(`isActiveCall`)으로 다룬다.
- 종료 중(`shuttingDown`)에는 새 승인 요청 자체가 `canceled`로 즉시 끝난다(SPEC-LIFECYCLE-001 REQ-001 (c)). 이 SPEC은 그 동작을 바꾸지 않는다.

## 잔여 위험

- 하이픈 없이 쓰거나 공백으로 나눠 쓴 전화번호가 공백으로 이어지면 숫자 13개 이상 조각이 되어 함께 가려진다(예: `01012345678 01098765432`, `010 1234 5678 010 9876 5432`). 예외는 하이픈으로 쓴 국내 전화번호 토큰뿐이다(OD-1).
- 하이픈 두 개처럼 사슬을 끊는 표기(`1234--5678-9012-3456`)는 조각마다 12자리 이하가 되어 가려지지 않는다.
- 13자리 이상 계좌번호도 가려진다(OD-4). 환불 계좌를 코멘트로 알려 주려는 경우 AI는 "요청자가 직접 전한다"고 말한다.
- 비밀번호·인증번호처럼 형태가 없는 정보는 감지하지 못한다. 도움말(REQ-012)과 지시문(REQ-008)만으로 막는다.
- AI가 코멘트를 따르는지는 실제 Realtime 모델 동작에 달려 있고 자동 테스트로 검증하지 않는다. 대화 기록의 안내 줄(REQ-006)로 사용자가 사후에 확인할 수 있게 하는 것까지가 이 SPEC의 범위다.
- 앱 업데이트 전 예전 앱은 문자소 기준으로 세므로 AC-001 (6) 같은 입력에서 400을 받는다(서버 동작은 지금과 같음).

## 완료 정의 (Definition of Done)

- AC-001 ~ AC-015 충족, 각 AC의 RED(또는 "처음부터 통과") / GREEN 원문을 `progress.md` §E.2에 기록.
- OD-1 ~ OD-4가 DEFAULT로 구현되었고 소유자 검토 대기임을 sync-phase 문서에 기록.
- 서버와 앱을 같은 릴리스로 내보낸다는 배포 조건을 sync-phase 문서에 기록.
