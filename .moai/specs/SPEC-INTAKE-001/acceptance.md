# SPEC-INTAKE-001 인수 기준

## 공통 검증 명령

저장소 루트(작업 트리)에서:

```bash
npm --prefix server test -- src/domain/intake.test.ts src/brain/heuristicBrain.test.ts src/brain/openaiBrain.test.ts src/services/callService.test.ts src/http/app.test.ts
npm --prefix server test
npm --prefix server run typecheck
```

앱(작업 디렉터리 `app/`):

```bash
flutter --suppress-analytics test test/intake_flow_test.dart test/plan_card_test.dart test/unit_test.dart test/approval_flow_test.dart
flutter --suppress-analytics test
flutter --suppress-analytics analyze
```

기준선: run-phase 시작 시 manager-develop이 위 전체 명령 결과를 `progress.md` §E.2 첫 부분에 기록한다(이 SPEC 작성 중에는 실행하지 않음). SPEC-APPROVAL-001이 끝난 상태에서 시작한다(`depends_on`).

규칙: 테스트 먼저(RED) → 구현(GREEN). 실제 OpenAI 호출 없음(`vi.stubGlobal("fetch", …)` 또는 가짜 brain). 문구 기대값은 OD-6 DEFAULT이며 소유자가 바꾸면 그 문자열만 고친다. `design.md`의 벡터 표는 이 문서의 일부로 본다.

## 서버

### AC-001 — 의뢰 해석 API 계약 (REQ-001, REQ-012)

- **Given** 시뮬레이션 모드·LLM 키 없음 서버(`app.test.ts` 구성), 토큰 `Authorization: Bearer test-token`
- **When** (1) `{"text":"라 파스타에 전화해서 02-123-4567로 금요일 7시 2명 예약"}`, (2) `{"text":"금요일 7시 예약","language":"en"}`, (3) `{"text":"   "}`, (4) `{"text":"가"*1001}`, (5) `{"text":"예약","language":"fr"}`, (6) 토큰 없이 (1)을 보내면
- **Then** (1) 200이고 응답 키가 정확히 `draft`, `missing`, `phoneSource`, `numberIssue`, `source`이며 `draft`의 키는 `targetName`, `phoneNumber`, `goal`, `conditions`, `context`, `language`다. 값: `targetName "라 파스타"`, `phoneNumber "+8221234567"`, `phoneSource "text"`, `numberIssue null`, `source "heuristic"`, `language "ko"`, `missing []`. (2) 200, `language "en"`, `missing ["targetName","phoneNumber"]`. (3)(4)(5) 400 `{"error":"invalid_request"}`. (6) 401 `{"error":"unauthorized"}`
- 테스트: `server/src/http/app.test.ts` — "drafts an intake without creating a task" (`it.each`)
- RED: 엔드포인트가 없다(404).

### AC-002 — 종료 중 503 (REQ-002)

- **Given** `beginShutdown()`을 부른 `CallService`로 만든 앱
- **When** (1) 올바른 본문, (2) `{"text":""}`로 `POST /v1/intake`를 보내면
- **Then** (1) 503 `{"error":"shutting_down","message":"서버가 종료 중입니다. 잠시 후 다시 시도해 주세요."}`이고 brain의 해석 함수가 호출되지 않는다(가짜 brain 호출 수 0), (2) 400 `invalid_request`
- 테스트: `app.test.ts` — "refuses intake while shutting down"

### AC-003 — 부작용·로그 없음 (REQ-003)

- **Given** 작업 1개가 저장된 `InMemoryTaskStore`, 이벤트를 기록하는 구독자, 호출을 기록하는 가짜 제공자와 가짜 로거, 실패하는 가짜 `fetch`(500)를 쓴 `OpenAiBrain`
- **When** `draftIntake`를 `"라 파스타에 전화해서 010-1234-5678 예약 비밀문구-Q"`로 부르면
- **Then** 저장소의 작업 수와 각 작업 `version`이 그대로이고, 발행된 이벤트 0건, 제공자 호출 0건이며, 가짜 로거의 모든 기록을 `JSON.stringify`한 값에 `010-1234-5678`, `+821012345678`, `비밀문구-Q`, `라 파스타`가 없다(warn 1건은 있음, AC-009)
- 테스트: `server/src/services/callService.test.ts` — "intake has no side effects and logs no request text"

### AC-004 — 글에서 번호 찾기 (REQ-004)

- **Given** 번호 후보 함수(`server/src/domain/intake.ts`, 새 파일)
- **When** `design.md` §2 표의 각 글을 넣으면
- **Then** 표의 `phoneNumber`·`numberIssue`와 같다(18행 전부)
- 테스트: `server/src/domain/intake.test.ts`(새 파일) — "finds Korean phone numbers in free text" (`it.each`)
- RED: 함수가 없다.

### AC-005 — 차단 번호는 제안하지 않음 (REQ-005)

- **Given** `design.md` §3.4 기록 벡터의 기록 ①②
- **When** 의뢰 해석에 (1) `"라 파스타에 전화해 119로"`, (2) `"119에 전화해 줘"`를 넣으면
- **Then** 두 경우 모두 `phoneNumber: null`, `numberIssue: "blocked"`, `phoneSource: null`이며, (1)은 기록 ②의 번호가 있어도 쓰지 않는다
- 테스트: `callService.test.ts` — "never proposes a blocked number, even from history"

### AC-006 — 기록에서 번호 찾기 (REQ-006)

- **Given** `design.md` §3.4 기록 ①②③을 넣은 저장소, 결정적 brain
- **When** `design.md` §3.4 기록 표의 다섯 글을 넣으면
- **Then** 표의 이름·번호·`phoneSource`와 같다. 추가로 (6) 기록 ②의 `phoneNumber`를 저장소에서 `"119"`로 바꾼 뒤 `"라 파스타에 전화해서 7시 예약"` → `phoneNumber: null`, `phoneSource: null`(기록 ①로 넘어가지 않음)
- 테스트: `callService.test.ts` — "finds the number of a counterparty who answered before" (`it.each`)

### AC-007 — 번호를 지어내지 않고 LLM에 보내지 않음 (REQ-007)

- **Given** 요청 본문을 기록하는 가짜 `fetch`가 `{"targetName":"라 파스타","goal":"010-9999-8888로 예약","conditions":[],"context":"번호 02-555-5555"}`를 돌려주는 `OpenAiBrain`, 빈 저장소
- **When** `"라 파스타에 010-1234-5678로 전화해서 예약"`으로 의뢰 해석을 하면
- **Then** (a) `fetch`가 받은 요청 본문 문자열에 `010-1234-5678`, `01012345678`이 없고 `[전화번호]`가 있다. 가리기 벡터(`design.md` §2 가리기 표 6행: 국내 후보, `1588-1234`, `+1 415 555 0100`은 `[전화번호]`로, `2024. 12. 25`·`금요일 7시 2명`·`119`는 그대로)를 도메인 함수 단위로도 확인한다. (b) `draft.phoneNumber`는 `+821012345678`(글의 번호), `phoneSource "text"`. (c) 응답 JSON을 문자열로 바꿨을 때 `010-9999-8888`, `01099998888`, `+821099998888`, `02-555-5555`, `+82255555555`가 하나도 없고, `draft.goal`은 `"로 예약"`, `draft.context`는 `"번호"`다(번호 모양을 지우고 공백 정리). (d) 같은 가짜 응답에서 원문에 번호가 없는 `"라 파스타에 전화해서 예약"`이면 `phoneNumber: null`, `missing`에 `"phoneNumber"` 포함, (c)와 같은 문자열이 응답에 없음. (e) 가짜 `fetch`가 `content`로 `{"targetName":"1588-9999 고객센터","goal":"+1 202 555 0199로 문의","conditions":["02 777 7777도 가능"],"context":null}`를 줄 때 원문 `"고객센터에 전화해서 문의"` → 응답에 `1588-9999`, `+1 202 555 0199`, `02 777 7777`이 없고, 번호를 지운 뒤 포함 검사를 하므로 `targetName "고객센터"`, `goal "로 문의"`, `conditions ["도 가능"]`
- 테스트: `server/src/domain/intake.test.ts` — "masks number-shaped text before it reaches the LLM" (가리기 벡터); `server/src/brain/openaiBrain.test.ts` — "never sends phone numbers to the LLM" ((a) 요청 본문); `callService.test.ts` — "uses only numbers from the text or history" ((b)~(e), 서비스 + 가짜 `fetch`의 `OpenAiBrain`)
- RED: 해석 경로가 없다.

### AC-008 — LLM 해석 (REQ-008)

- **Given** 가짜 `fetch`가 다음 `content`를 돌려줌
  1. `{"targetName":"라 파스타","goal":"금요일 7시 2명 예약","conditions":["8시도 괜찮음"],"context":null}`
  2. `{"targetName":"강남 맛집","goal":"예약","conditions":[],"context":null}` (원문에 없는 이름)
  3. `{"targetName":null,"goal":"[전화번호]로 예약 문의","conditions":null}`
- **When** 원문 `"라 파스타에 전화해서 금요일 7시 2명 예약해줘. 안 되면 8시도 괜찮아"`(3은 `"02-123-4567로 예약 문의"`)로 해석하면
- **Then (서비스 응답, REQ-008 후처리 포함)** (1) `targetName "라 파스타"`, `goal "금요일 7시 2명 예약"`, `conditions ["8시도 괜찮음"]`, `source "llm"`. (2) `targetName null`(원문에 없음), `missing`에 `"targetName"`. (3) `goal "로 예약 문의"`(자리표시 제거 뒤 공백 정리), `conditions []`, `phoneNumber "+8221234567"`, `source "llm"`
- **Then (brain 단)** `OpenAiBrain.draftIntake`는 세 경우 모두 스키마 검증한 값을 바꾸지 않고 돌려준다: (2)의 `targetName`은 `"강남 맛집"` 그대로, (3)의 `goal`은 `"[전화번호]로 예약 문의"` 그대로, `conditions`는 `null` → `[]`, `source "llm"`. 후처리가 brain에 없음을 고정한다
- 테스트: 서비스 응답은 `callService.test.ts` — "post-processes LLM intake content in the service" (`it.each`, 가짜 `fetch`의 `OpenAiBrain`을 주입한 `CallService`); brain 단은 `openaiBrain.test.ts` — "returns schema-validated intake content unchanged" (`it.each`)

### AC-009 — LLM 실패 시 결정적 해석과 로그 (REQ-009)

- **Given** SPEC-OUTCOME-001 AC-005의 여섯 가지 실패 가짜 `fetch`(500, `TimeoutError`, 빈 `content`, JSON 아님, 스키마 위반 `{"goal":5}`, `TypeError("fetch failed")`), 기록하는 가짜 로거
- **When** `"라 파스타에 전화해서 7시 예약"`으로 `OpenAiBrain.draftIntake`를 부르면
- **Then** 여섯 경우 모두 결과가 `HeuristicBrain.draftIntake`와 같고 `source "heuristic"`이며, warn 로그가 정확히 1건이고 그 객체의 키가 `op`(`"intake"`), `reason`(각각 `http_status`, `timeout`, `empty_content`, `invalid_json`, `schema_mismatch`, `network`), 500일 때만 `status`뿐이다. 로그 문자열에 `라 파스타`가 없다
- (7) 제한 시간: 의뢰 해석 제한 시간을 50 ms로 주입하고, 받은 `signal`이 끊길 때까지 끝나지 않는(끊기면 `TimeoutError` 이름의 오류로 거부하는) 가짜 `fetch` → 결과 `source "heuristic"`, warn 1건 `reason "timeout"`. 주입하지 않은 기본값은 15000 ms이고 계획·요약의 기본값은 30000 ms 그대로다(내보낸 상수 단언)
- 테스트: `openaiBrain.test.ts` — "falls back visibly when the intake LLM fails" (`it.each`), "bounds the intake LLM call below the app timeout"

### AC-010 — 결정적 해석 규칙 (REQ-010)

- **Given** `HeuristicBrain`
- **When** `design.md` §3.4 결정적 이름 표의 여섯 글(번호를 가린 상태로)을 넣으면
- **Then** 표의 이름·목적과 같고, `conditions []`, `context null`, `source "heuristic"`이다
- 테스트: `server/src/brain/heuristicBrain.test.ts` — "drafts intake content without an LLM" (`it.each`)

### AC-011 — 기록 이름 포함 검사 (REQ-011)

- **Given** 기록 ①(`라 파스타`, 연결됨, 11-01), ②(`라파스타`, 연결됨, 11-10), ④(`파스타`, 연결됨, 11-12), ⑤(`A`, 연결됨, 11-13)
- **When** 결정적 해석으로 (1) `"라파스타 금요일 예약"`, (2) `"파스타 집 영업시간"`, (3) `"A 매장 예약"`을 넣으면
- **Then** (1) 이름 `라파스타`(가장 긴 일치 `라파스타`, 표시는 최신 ②의 철자), (2) 이름 `파스타`, (3) 이름 `null`(정규화 이름 `a`는 1자라 제외)
- 테스트: `callService.test.ts` — "matches the longest known counterparty name"

### AC-012 — `missing`과 언어 (REQ-012)

- **Given** 빈 저장소, 결정적 brain
- **When** (1) `"010-1234-5678"`, (2) `"금요일 7시 예약"`, (3) `"엄마한테 전화해 줘"`, (4) (2)에 `language: "en"`
- **Then** (1) `goal ""`, `missing ["targetName","goal"]`, `phoneNumber "+821012345678"`. (2) `missing ["targetName","phoneNumber"]`. (3) `missing ["phoneNumber"]`. (4) `draft.language "en"`, 나머지는 (2)와 같다. (1)~(3)의 `draft.language`는 `"ko"`
- 테스트: `callService.test.ts` — "lists missing fields in a fixed order"

### AC-013 — `autoStart` 필드 (REQ-013)

- **Given** 시뮬레이션 모드 서버
- **When** (1) 일반 생성 본문에 `"autoStart": true`, (2) 필드 없음, (3) `"autoStart": "yes"`, (4) `"autoStart": true`이고 번호가 `"119"`로 `POST /v1/tasks`를 보내면
- **Then** (1) 201, 응답 작업 `autoStart: true`. (2) 201, 응답에 `autoStart` 키 없음. (3) 400 `invalid_request`. (4) 400 `blocked_number`, 작업 저장 없음
- 테스트: `app.test.ts` — "accepts an optional autoStart flag"

### AC-014 — 계획이 끝나면 바로 시작 (REQ-014)

- **Given** `InMemoryTaskStore`, 결정적 brain, `start` 호출을 기록하는 가짜 제공자
- **When** (1) `autoStart: true`로 `create`, (2) `autoStart` 없이 `create` 한 뒤 계획이 끝날 때까지 기다리면
- **Then** (1) 별도 `approvePlan` 호출 없이 작업이 `dialing`(또는 그 뒤 상태)이고 `start`가 정확히 1회, `startedAt`이 있다. (2) `awaiting_approval`이고 `start` 0회
- 추가: 시뮬레이션 서버 전체 흐름 — `autoStart: true`로 만든 작업이 `approve-plan` 요청 없이 승인 대기(`approvals`에 `pending`)까지 간다
- (3) 첫 인사 고정(OD-7): `createPlan`이 `openingLine: "안녕하세요, 김민수입니다."`(AI 고지 없음)를 돌려주는 가짜 brain → (1)의 작업은 `plan.openingLine`이 `openingLine(task)`(`brain/prompts.ts:3-7`)와 같고 `AI 비서`를 포함한다. 같은 가짜 brain으로 `autoStart` 없이 만든 뒤 수동 `approvePlan(id)`을 부르면 `plan.openingLine`은 `"안녕하세요, 김민수입니다."` 그대로다(수동 경로 불변)
- 테스트: `callService.test.ts` — "starts the call once planning finishes when autoStart is set", "auto-started calls open with the template AI disclosure"; `app.test.ts` — "auto-starts a simulated call without approve-plan"

### AC-015 — 자동 시작이 막히면 (REQ-015)

- **Given** AC-014 구성
- **When / Then**
  1. `maxConcurrentCalls: 1`이고 다른 통화 1건이 진행 중일 때 `autoStart: true` 작업 생성 → 계획 뒤 `awaiting_approval`, `autoStartBlocked: { code: "too_many_active_calls", message: "Too many calls are in progress" }`, `start` 0회(새 작업에 대해). 발행된 `task.updated` 중 하나가 `autoStartBlocked`를 담는다
  2. (1) 뒤 진행 중 통화를 끝내고 `approvePlan(id)` → `dialing`, 작업에 `autoStartBlocked` 키 없음
  3. `maxCallsPerDay`를 이미 채운 상태 → `autoStartBlocked.code: "daily_limit"`
  4. 계획을 지연시키는 가짜 brain으로 계획 중 `beginShutdown()` → 계획 완료 뒤 `awaiting_approval`, `autoStartBlocked.code: "shutting_down"`
  5. 계획이 끝난 뒤의 `list()` 호출에서 `new Error("boom")`을 던지는 저장소 대역(`InMemoryTaskStore` 상속, 한도 검사 `assertWithinLimits`가 `list()`를 부름) → `autoStartBlocked: { code: "auto_start_failed", message: "자동으로 통화를 시작하지 못했어요." }`, 작업은 `awaiting_approval`, 처리되지 않은 예외·거부(unhandled rejection)가 없음, `InvalidTransitionError` 없음
- 테스트: `callService.test.ts` — "records why an auto start was blocked" (1~5)
- 참고: 번호 재검사(400)는 같은 `approvePlan`을 쓰므로 SPEC-POLICY-001 AC-010의 기존 테스트가 순서를 덮는다.

### AC-016 — 그 밖에는 자동 시작하지 않음 (REQ-016)

- **Given** AC-014 구성
- **When / Then**
  1. `autoStart: true` 작업을 계획 중에 `cancel` → `canceled`, `start` 0회
  2. 계획에 실패하는 가짜 brain → `failed`, `start` 0회, `autoStartBlocked` 없음
  3. 저장소에 `awaiting_approval`·`autoStart: true` 작업을 미리 넣고 새 `CallService`로 `recoverInterruptedTasks()` → 상태 그대로, `start` 0회, `terminateByProviderCallId` 0회
- 테스트: `callService.test.ts` — "never auto-starts outside the planning completion"

## 앱

### AC-017 — 홈 입력칸 (REQ-017)

- **Given** `approval_flow_test.dart`의 `pumpApp` 방식(가짜 저장소에 의뢰 해석 결과 주입 필드 추가), 내 이름 `김민수`
- **When / Then**
  1. 렌더링 → "무엇을 도와드릴까요?"가 보이고, "전화 맡기기" 떠 있는 버튼이 없으며, "직접 입력하기"가 보인다
  2. 입력 `가` → 보내기 버튼 `onPressed == null`. 입력 `예약` → 눌림
  3. `라 파스타에 전화해서 7시 예약` 입력 후 보내기 → 가짜 저장소의 `intakeCalls`가 `['라 파스타에 전화해서 7시 예약']`이고 계획 카드 화면("이렇게 걸어 볼게요")이 보인다
  4. 내 이름이 비어 있는 상태에서 (3) → 설정 화면이 열리고 `intakeCalls`는 비어 있으며, 돌아오면 입력칸 글이 그대로다
  5. "직접 입력하기" → 기존 양식("통화 계획 만들기" 버튼)이 열린다
- 테스트: `app/test/intake_flow_test.dart`(새 파일) — "home sends one line to intake"
- RED: 입력칸이 없다.

### AC-018 — 홈 제안 (REQ-018)

- **Given** 작업 6개: `라 파스타`(+8221234567, 연결됨, 11-01), `라파스타`(같은 번호, 연결됨, 11-10), `미용실`(+82311112222, 연결됨, 11-05), `세탁소`(+82311113333, 연결 안 됨, 11-12), `치과`(+82311114444, 연결됨, 11-03), `빵집`(+82311115555, 연결됨, 11-02)
- **When** 홈을 렌더링하고, 첫 제안을 누르고, 이어서 "식당 예약" 칩을 누르면
- **Then** "최근 통화한 곳"에 정확히 3개가 위에서부터 `라파스타`(2번), `미용실`(1번), `치과`(1번) 순서로 보이고 `세탁소`는 없다. 첫 제안을 누르면 입력칸 글이 `라파스타에 `이고 커서 위치가 글 끝이다. "식당 예약" 칩을 누르면 입력칸 글이 템플릿 목적 문장(`call_templates.dart:17`)과 같다. 기존 테스트 "shows the empty state with quick-start templates"는 수정 없이 통과한다
- (3) 작업 0개인 홈: "식당 예약" 칩이 정확히 하나(`findsOneWidget`)이고, 누르면 입력칸 글이 템플릿 목적 문장이 되며 기존 양식 화면("통화 계획 만들기")은 열리지 않는다. 빈 상태 안내 "귀찮은 전화, 대신 걸어드릴게요"는 보인다
- 단위: 계산 함수(`counterparties.dart`) — 같은 입력에서 `[('라파스타', '+8221234567', 2), ('미용실', …, 1), ('치과', …, 1)]`; 정규화 벡터 `design.md` §3.1
- 테스트: `intake_flow_test.dart` — "suggests recent counterparties and templates"; `app/test/unit_test.dart` — "derives recent counterparties"
- RED: 제안이 없다.

### AC-019 — 계획 카드 표시와 그 자리 수정 (REQ-019)

- **Given** 초안 `{targetName "라 파스타", phoneNumber "+8221234567", goal "금요일 7시 2명 예약", conditions ["8시도 괜찮음"], context "회원번호 1234", language "ko"}`, `phoneSource "history"`, `source "heuristic"`
- **When** 계획 카드를 렌더링하고, "부탁할 일" 행을 눌러 `토요일 7시 2명 예약`으로 바꾸고, 조건 칩의 삭제를 누르고, 언어 행을 누르면
- **Then** 처음에 `라 파스타`, `02-123-4567`, "지난번 통화한 번호", `금요일 7시 2명 예약`, `8시도 괜찮음`, `회원번호 1234`, `한국어`, `김민수`, "AI 없이 간단히 정리했어요. 내용을 확인해 주세요."가 보인다. 행을 누른 뒤에도 같은 화면이며 `AlertDialog`가 없다(`find.byType(AlertDialog)` 0). 수정 뒤 목적 `토요일 7시 2명 예약`, 조건 칩 0개, 언어 `English`
- 같은 초안에 `phoneSource "text"`, `source "llm"`이면 "말씀하신 번호"가 보이고 heuristic 안내가 없다
- 테스트: `app/test/plan_card_test.dart`(새 파일) — "shows the draft and edits rows in place"

### AC-020 — 번호는 한 번만 묻기 (REQ-020)

- **Given** (1) `phoneNumber null`, `missing ["phoneNumber"]`, `numberIssue null`, (2) 같은데 `numberIssue "blocked"`, (3) `targetName null`도 함께
- **When** 계획 카드를 렌더링하면
- **Then** (1) 번호 칸이 다른 행보다 위에 있고(`getTopLeft`의 y가 "전화할 곳" 행보다 작음) 초점을 가졌으며 키보드 유형이 `TextInputType.phone`, 도움말 "번호만 알려 주시면 바로 걸게요.". (2) 도움말 "긴급·특수번호에는 걸 수 없어요. 다른 번호를 알려 주세요.". (3) "전화할 곳" 행이 입력 상태(`TextField`)로 열려 있다. 세 경우 모두 `AlertDialog`·`BottomSheet`가 없다
- 테스트: `plan_card_test.dart` — "asks for the number once"

### AC-021 — [이대로 시작] (REQ-021)

- **Given** AC-019의 초안(수정 없음), 가짜 저장소의 `create`가 받은 요청을 기록하고 `taskJson(id: 'task-9', status: 'planning')`을 돌려줌
- **When / Then**
  1. [이대로 시작] → 기록된 요청의 `toJson()`이 `{"targetName":"라 파스타","phoneNumber":"+8221234567","goal":"금요일 7시 2명 예약\n조건: 8시도 괜찮음","context":"회원번호 1234","language":"ko","requesterName":"김민수","autoStart":true}`(설정에 회신 번호가 없을 때)와 같고, 화면이 `/calls/task-9` 상세로 바뀐다(뒤로 가면 홈)
  2. 번호를 `0212`(숫자 4개)로 고침 → 버튼 `onPressed == null`
  3. 목적을 `예약`(2자)로 고침 → 버튼 비활성
  4. 조건을 붙인 목적이 1001자 → 버튼 비활성, "부탁할 일이 너무 길어요." 안내
  5. `create`가 `ApiException('blocked_number', '긴급·특수번호에는 전화할 수 없습니다.', statusCode: 400)`를 던짐 → 계획 카드에 남고 번호 칸 아래에 그 문구, 스낵바 없음
  6. `create`가 `ApiException('network', …)`를 던짐 → 스낵바 "서버에 연결할 수 없어요. 설정에서 서버 주소를 확인해 주세요.", 화면에 남음
- 테스트: `plan_card_test.dart` — "starts the call with one tap" (1~6)

### AC-022 — 예전 서버와 오류 (REQ-022)

- **Given** 가짜 저장소의 `intake`가 (1) `ApiException('http_404', …, statusCode: 404)`, (2) `ApiException('shutting_down', '서버가 종료 중입니다. 잠시 후 다시 시도해 주세요.', statusCode: 503)`를 던짐
- **When** 홈에서 `라 파스타 7시 예약`을 보내면
- **Then** (1) 계획 카드가 열리고 목적이 `라 파스타 7시 예약`, 번호 칸과 이름 입력 상태가 열려 있으며 heuristic 안내가 보인다. (2) 스낵바에 서버 문구, 홈에 남고 입력칸 글이 그대로다
- 테스트: `intake_flow_test.dart` — "falls back to a blank plan card on older servers"

### AC-023 — 자동 시작이 막혔다는 안내 (REQ-023)

- **Given** (1) `status: "awaiting_approval"`, `autoStartBlocked: {"code":"too_many_active_calls","message":"Too many calls are in progress"}`인 작업, (2) `autoStartBlocked: {"code":"auto_start_failed","message":"자동으로 통화를 시작하지 못했어요."}`인 작업, (3) 같은 작업에서 `autoStartBlocked`만 뺀 작업
- **When** 통화 상세 화면을 각각 렌더링하면
- **Then** (1) "바로 걸지 못했어요: 이미 진행 중인 통화가 있어요. 끝난 뒤 다시 시도해 주세요."(코드별 한국어 문구, `api_client.dart:16-25`와 같은 대응표)와 "이대로 전화 걸기" 버튼이 보인다. (2) 대응표에 없는 코드는 서버 문구를 그대로 써서 "바로 걸지 못했어요: 자동으로 통화를 시작하지 못했어요.". (3) 안내가 없다
- 단위: `CallTask.fromJson`이 `autoStartBlocked` 유무·모르는 형태(`"autoStartBlocked": 5`)에 예외 없이 동작
- 테스트: `plan_card_test.dart` — "explains a blocked auto start on the detail screen"; `unit_test.dart` — "parses autoStartBlocked defensively"

### AC-024 — 호환과 회귀 (REQ-024)

- 서버 `npm --prefix server test` 전체 통과(기존 테스트 무수정), `npm --prefix server run typecheck` 종료 코드 0, `architecture.test.ts` 무수정 통과.
- 앱 `flutter test` 전체 통과. `git diff <run_start_sha> -- app/test/approval_flow_test.dart server/src/http/app.test.ts`에서 기존 테스트 본문은 바뀌지 않고 새 테스트만 추가된다. `flutter analyze`가 run-phase 기준선보다 늘지 않는다.
- 기존 양식 경로: 위젯 테스트 — `/calls/new`에서 만든 요청의 `toJson()`에 `autoStart` 키가 없다(`intake_flow_test.dart` — "the manual form never auto-starts").

## 엣지 케이스

- 글에 번호가 둘이고 사용자가 "말고"로 첫 번호를 부정한 경우(`010-1234-5678 말고 02-123-4567`) → 결정적 규칙은 첫 번호를 쓴다(`design.md` §2 표). 계획 카드에 보이므로 사용자가 고칠 수 있다(잔여 위험).
- 기록에 같은 이름이 있지만 번호가 차단으로 바뀐 경우 → 번호 없음(AC-006 (6)).
- 계획 카드를 연 채 서버가 재시작 → 작업이 아직 없으므로 영향 없음. [이대로 시작]이 503이면 스낵바.

## 잔여 위험

- 의뢰 해석 LLM 제한(15 s) + 서버 처리 + 네트워크 왕복이 앱 제한(20 s)에 가까우면 여전히 앱이 먼저 끝날 수 있다. 그 경우 앱은 네트워크 오류 스낵바를 보여 주고, 서버는 결과를 버린다(부작용 없음, REQ-003).
- 가리기 집합(국내 후보, `+` 국제 표기, 15xx·16xx·18xx 대표번호) 밖의 드문 번호 표기(예: 지역번호 없는 7~8자리 `123-4567`)는 LLM에 그대로 갈 수 있다. 날짜·시각·인원을 LLM이 받을 수 있게 하려고 좁게 정했다(REQ-007 (a)). LLM 응답에서 같은 집합 밖 숫자는 지우지 않는다.
- 이름 정규화가 NFC를 하지 않아, 자모가 분리된 입력(NFD)은 같은 상대로 묶이지 않는다.
- 결정적 이름 규칙은 "…에 전화/연락"으로 시작하는 글만 잡는다. 그 밖의 글은 기록 이름이나 사용자의 직접 입력에 기댄다.
- `autoStart` 작업은 사용자가 통화 계획(첫 인사·순서·질문)을 보지 않고 시작한다. 소유자 결정 3에 따른 것이며, 위험한 결정은 통화 중 승인이 막는다.
- 서버만 먼저 배포되면 예전 앱은 영향이 없다. 앱만 먼저 배포되면 의뢰 해석은 404 → 빈 계획 카드(REQ-022), `autoStart`는 무시되어 상세 화면에서 수동 승인이 필요하다.

## 완료 정의 (Definition of Done)

- AC-001 ~ AC-024 충족, RED/GREEN 원문을 `progress.md` §E.2에 기록.
- OD-1 ~ OD-6 DEFAULT 구현과 소유자 검토 대기를 sync-phase 문서에 기록.
- 새 엔드포인트 `POST /v1/intake`와 `autoStart`·`autoStartBlocked` 필드를 sync-phase 문서(`.moai/project/structure.md`, 코드맵)에 반영할 항목으로 남김.
