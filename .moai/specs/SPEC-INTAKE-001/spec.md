---
id: SPEC-INTAKE-001
title: "한 줄 부탁을 계획 카드로 — 번호 찾기, 한 번 확인 후 바로 통화"
version: "0.3.0"
status: draft
created: 2026-11-21
updated: 2026-11-21
author: jason
priority: High
phase: "v0.3.0 target"
module: "server/src/http, server/src/services, server/src/brain, server/src/domain, app/lib/features/calls"
lifecycle: spec-anchored
tags: "intake, plan-card, one-line-request, auto-start, phone-policy, history, llm-fallback, flutter, tdd, assistant-ux"
tier: L
depends_on: [SPEC-APPROVAL-001]
related_specs: [SPEC-POLICY-001, SPEC-OUTCOME-001, SPEC-LIFECYCLE-001, SPEC-STORE-001, SPEC-ARCH-001]
---

# SPEC-INTAKE-001: 한 줄 부탁을 계획 카드로 — 번호 찾기, 한 번 확인 후 바로 통화

## HISTORY

| 버전 | 날짜 | 작성 | 변경 |
|------|------|------|------|
| 0.1.0 | 2026-11-21 | jason (manager-spec) | 최초 작성 (draft). 에픽 EPIC-ASSISTANT-UX의 두 번째 SPEC |
| 0.2.0 | 2026-11-21 | jason (manager-spec) | plan-audit iteration 1 반영: D5 템플릿 칩은 제안 줄 한 곳에서만, D6 LLM에 보내기 전 가리는 번호 모양을 넓히고 범위를 정직하게 적음, D7 LLM 응답 문자열의 번호 모양 제거, D8 후처리는 서비스 한 계층으로, D9 자동 시작 오류 근거 정정, D10 "너무 길어요" 문구를 REQ-021에, D11 의뢰 해석 LLM 제한 시간 15 s, D12 실행 경로·직렬 작업 기록, 자동 시작 첫 인사 템플릿 고정(OD-7). REQ/AC 번호·개수 불변 |
| 0.3.0 | 2026-11-21 | jason (manager-spec) | plan-audit iteration 2 반영: N2 "최근 통화한 곳"은 끝난 작업만, 항목은 한 덩어리 글로 그리고 기존 테스트 이름을 AC-024에 명시, N3 AC-007 (a) 요청 본문 검사를 서비스 테스트로 옮김, N4 REQ-014 "첫 인사 외의 계획 수정값은 없다", A2·A8 잔여 위험 추가, A3 국제 표기 정의에 "숫자로 끝나는". REQ/AC 번호·개수 불변 |

## 1. 배경과 목적

지금 전화를 맡기려면 사용자가 양식의 네 칸(상대 이름, 번호, 목적, 알려줄 정보)과 언어를 직접 채우고(`app/lib/features/calls/presentation/new_call_screen.dart:108-160`), "통화 계획 만들기"를 누른 뒤, 계획이 나오면 상세 화면에서 "이대로 전화 걸기"를 한 번 더 눌러야 한다(`call_detail_screen.dart:222-233`). 같은 식당에 다시 걸어도 번호를 또 입력한다(재통화 버튼만 예외, `call_detail_screen.dart:245-253`). 근거: `research.md` §1~§3.

소유자 방향은 "사용자는 최소한만 입력·선택하고, 에이전트가 할 수 있는 일은 스스로 한다. 위험한 일(돈, 약정, 잘못된 번호로 거는 실제 통화)은 승인 뒤에 둔다"이다. 소유자가 이미 정한 사항:

1. 이 SPEC의 범위는 한 줄 부탁 → 계획 카드 → 한 번 확인 → 통화 시작이다. 연락처 선택, 음성 입력, 장소 검색 API, 계정은 다루지 않는다.
2. 번호는 사용자가 쓴 글과 저장된 통화 기록에서만 찾는다. 그래도 없으면 번호 칸 하나로 **한 번만** 묻는다(외부 검색 없음).
3. 계획 카드가 나오면 사용자가 [이대로 시작]을 한 번 누르고, 통화가 바로 시작된다. 통화 중 승인은 그대로이며, 승인 제한 시간 만료 = 거절이다.

목적은 홈 화면에 입력칸 하나를 두고, 서버가 그 한 줄에서 상대·번호·목적·조건을 뽑아 계획 카드 초안을 만들고, 사용자가 카드에서 고칠 것만 고친 뒤 한 번 눌러 통화를 시작하게 하는 것이다. 번호 정책(`checkTargetNumber`)은 서버가 제안하는 모든 번호에 그대로 적용되고, 서버는 번호를 지어내지 않는다. 기존 양식은 "직접 입력" 경로로 남는다.

## 2. 범위

- 서버: 새 엔드포인트 `POST /v1/intake`(작업을 만들지 않는 초안 해석), 도메인 규칙(번호 후보 찾기, 이름 정규화), brain의 의뢰 해석(LLM + 결정적 대체), 통화 기록에서 번호 찾기, `POST /v1/tasks`의 `autoStart` 선택 필드와 자동 시작 동작.
- 앱: 홈 화면(입력칸 하나 + 제안), 계획 카드 화면(새 화면), 자주 통화한 상대 계산, 자동 시작이 막혔을 때 상세 화면 안내. 시각 디자인은 SPEC-UX-001이 정하며 이 SPEC은 기존 테마·공용 위젯만 쓴다.
- 세부 설계: `design.md`(API 예시, 번호 후보 규칙과 테스트 벡터, 자동 시작 순서, 화면 구성).
- 배포: 서버와 앱을 같은 릴리스로 내보낸다(에픽 공통 결정). 예전 서버·예전 앱과의 조합은 REQ-022, REQ-024로 안전하게 동작한다.

## 3. 요구사항 (GEARS)

### 3.1 의뢰 해석 API (서버)

- **REQ-001** [Ubiquitous] 서버는 `POST /v1/intake`를 제공해야 한다(**shall**). 요청 본문은 `{ text, language? }`이며 `text`는 앞뒤 공백을 지운 뒤 1~1000자(UTF-16 길이, 기존 `CreateTaskBody`와 같은 단위), `language`는 `ko`/`en`이고 없으면 `ko`다. 응답은 200 `{ draft: { targetName: string|null, phoneNumber: string|null, goal: string, conditions: string[], context: string|null, language }, missing: string[], phoneSource: "text"|"history"|null, numberIssue: "blocked"|null, source: "llm"|"heuristic" }`이고 `phoneNumber`는 E.164다. 본문이 스키마를 어기면 400 `invalid_request`, `/v1/*` 토큰 인증은 다른 엔드포인트와 같다.
- **REQ-002** [State-driven] **While** 서버가 종료 중이면, `POST /v1/intake`는 본문 검증 뒤 해석을 시작하기 전에 503 `shutting_down`(문구는 SPEC-LIFECYCLE-001 REQ-001과 같음)을 돌려줘야 한다(**shall**). 검사 순서는 `POST /v1/tasks`와 같다(본문 400 → 503).
- **REQ-003** [Unwanted] 의뢰 해석은 작업을 저장하거나, 이벤트를 발행하거나, 제공자를 부르거나, 저장된 데이터를 바꿔서는 안 되며(**shall not**), 요청 글·전화번호·초안 필드를 로그에 남겨서도 안 된다.

### 3.2 번호 찾기 (서버)

- **REQ-004** [Ubiquitous] 서버는 요청 글에서 한국식 번호 후보(맨 앞 `0` 또는 `+82`, 이어서 국번·식별 번호 1~3자리, 3~4자리, 4자리 묶음. 묶음 사이에는 공백·하이픈·점·괄호 중 하나만 올 수 있고 후보 앞뒤에 다른 숫자가 붙어 있지 않음. 정확한 규칙과 테스트 벡터는 `design.md` §2)를 글 순서대로 찾아 각각 `checkTargetNumber`로 판정하고, 처음으로 `ok`인 후보의 E.164 값을 `draft.phoneNumber`로, `phoneSource`를 `"text"`로 해야 한다(**shall**).
- **REQ-005** [Event-driven] **When** 글에 `ok`인 후보가 없고 차단 판정 후보나 차단 단축 번호(SPEC-POLICY-001의 9개 번호, 앞뒤에 숫자가 붙지 않은 것)가 있으면, 서버는 `phoneNumber: null`, `numberIssue: "blocked"`로 답해야 하며(**shall**), 통화 기록에서 번호를 찾지 않는다.
- **REQ-006** [Event-driven] **When** 글에서 번호를 찾지 못했고(`numberIssue` 없음) `draft.targetName`이 정해졌으면, 서버는 통화 기록에서 번호를 찾아야 한다(**shall**): 저장된 작업 중 `connectedAt`이 있는 것(상대가 받은 적이 있는 번호)을 `createdAt` 최신순으로 보고, 정규화한 `targetName`이 같은 첫 작업의 `phoneNumber`를 `checkTargetNumber`로 다시 판정해 `ok`이면 그 값을 쓰고 `phoneSource`를 `"history"`로 한다(OD-2, OD-3 DEFAULT). 이름 정규화는 소문자로 바꾸고 모든 공백을 지우는 것이다(앱과 같은 규칙, REQ-018).
- **REQ-007** [Unwanted] 서버는 요청 글이나 통화 기록에서 온 것이 아닌 전화번호를 제안해서는 안 되며(**shall not**), 번호 모양의 글을 LLM에 보내거나 LLM에 번호를 요구해서도 안 된다. (a) 가리기 대상(번호 모양)은 REQ-004의 국내 후보, `+`로 시작해 숫자 8개 이상인 국제 표기, `15xx`·`16xx`·`18xx` + 4자리 대표번호 표기이며(정확한 규칙과 벡터는 `design.md` §2), LLM에 보내는 글에서 이들을 `[전화번호]`로 바꾼다. 날짜(`2024. 12. 25`)·시각·인원 같은 짧은 숫자는 가리지 않으므로 LLM에 그대로 간다. 이 세 모양 밖의 드문 번호 표기는 가려지지 않을 수 있다(잔여 위험, acceptance.md). (b) LLM 응답 스키마에는 번호 필드가 없다. (c) LLM이 준 모든 문자열 필드에서 (a)의 번호 모양 부분을 지운다(LLM은 번호를 받지 못했으므로 응답 속 번호는 지어낸 것이다). 따라서 응답 어디에도 요청 글에 없던 번호가 남지 않는다.

### 3.3 내용 정리 (서버 brain + 서비스 후처리)

- **REQ-008** [Event-driven] **When** LLM을 쓸 수 있으면, brain은 서비스가 넘긴 (번호를 가린) 글을 LLM에 보내 `{ targetName: string|null, goal, conditions: string[], context: string|null }`를 받아 스키마(`design.md` §4: 이름 ≤80자, 목적 1~1000자, 조건 최대 5개·각 1~200자, 정보 ≤1000자)로 검증한 값을 `source: "llm"`과 함께 그대로 돌려줘야 한다(**shall**). 후처리는 원문 글을 가진 서비스(`CallService`) 한 곳에서만 한다(brain은 원문을 받지 않는다): 모든 문자열 필드에서 `[전화번호]` 자리표시와 REQ-007 (c)의 번호 모양을 지우고 공백을 정리하며, `targetName`은 정규화한 원문 글이 정규화한 이름을 포함할 때만 쓰고 아니면 `null`로 둔다(지어낸 상대 방지). 결정적 결과(REQ-010)에도 같은 후처리를 한다.
- **REQ-009** [Event-driven] **When** 의뢰 해석용 LLM 호출이 실패하면(SPEC-OUTCOME-001 REQ-006과 같은 실패 분류), brain은 `op: "intake"`, 원인 분류(`reason`), 해당하면 HTTP 상태 코드만 담아 warn 수준으로 한 번 기록하고, REQ-010의 결정적 결과를 `source: "heuristic"`으로 돌려줘야 한다(**shall**). LLM 키가 없을 때도 결정적 결과를 쓴다. 의뢰 해석 LLM 호출의 제한 시간은 15 s다(계획·요약의 30 s와 별도). 앱 요청 제한 시간 20 s(`api_client.dart:39`)보다 짧게 두어, LLM이 느려도 결정적 결과가 앱에 닿게 한다. 시험을 위해 이 값은 주입할 수 있다.
- **REQ-010** [Ubiquitous] 결정적 해석은 다음 규칙을 따라야 한다(**shall**): (a) 목적은 번호 자리표시를 지우고 공백을 한 칸으로 줄인 글, (b) 상대 이름은 (a)의 글이 "이름 + (에|에게|한테|께) + (전화|연락)"으로 시작할 때의 이름(40자 이하), 아니면 `null`, (c) 조건은 빈 목록, 정보는 `null`. 테스트 벡터는 `design.md` §3.
- **REQ-011** [Event-driven] **When** brain이 준 상대 이름이 `null`이면, 서버는 정규화한 요청 글에 포함된 통화 기록 상대 이름(정규화 뒤 2자 이상, REQ-006과 같은 기록 범위) 중 가장 긴 것을 고르고, 표시 이름은 그 상대의 가장 최근 작업의 `targetName`으로 해야 한다(**shall**).
- **REQ-012** [Ubiquitous] 응답의 `missing`은 `targetName`이 `null`이면 `"targetName"`, `phoneNumber`가 `null`이면 `"phoneNumber"`, `goal`이 비면 `"goal"`을 이 순서로 담아야 하고(**shall**), `draft.language`는 요청의 `language`(없으면 `ko`)다. 서버는 언어를 추측하지 않는다.

### 3.4 한 번 확인 후 자동 시작 (서버)

- **REQ-013** [Ubiquitous] `POST /v1/tasks`는 선택 필드 `autoStart`(불리언, 기본 `false`)를 받아야 하며(**shall**), 참이면 작업에 `autoStart: true`를 저장한다. 그 밖의 작업 생성 동작(번호 정책, 201 응답, 오류 코드)은 바뀌지 않는다(OD-1 DEFAULT: 자동 시작은 서버가 한다).
- **REQ-014** [Event-driven] **When** `autoStart: true`인 작업의 계획이 준비되어 `awaiting_approval`이 되면, 서비스는 별도 요청 없이 계획 승인과 같은 검사와 순서(503 `shutting_down` → 409 상태 → 400 번호 재검사 → 429 한도)로 통화를 시작해야 한다(**shall**). 첫 인사 외의 계획 수정값은 없다. 성공하면 수동 승인과 똑같이 `dialing`부터 진행한다. 자동 시작 통화의 첫 인사는 LLM이 만든 값 대신 AI임을 밝히는 템플릿 첫 인사(`brain/prompts.ts`의 `openingLine(task)`)로 계획 수정값을 넣어 고정한다(OD-7 DEFAULT) — 사용자가 계획 본문을 보지 않고 시작하므로, AI 고지 문장을 모델 출력에 맡기지 않기 위해서다.
- **REQ-015** [Event-driven] **When** 자동 시작의 검사 하나라도 실패하면, 서비스는 작업을 `awaiting_approval`로 두고 `autoStartBlocked: { code, message }`(실패한 `ServiceError`의 코드와 문구)를 저장·발행해야 하며(**shall**), 다시 시도하지 않는다. 그 뒤 사용자의 수동 계획 승인이 성공하면 `autoStartBlocked`는 지워진다.
- **REQ-016** [Unwanted] 서비스는 같은 프로세스에서 그 작업의 계획이 막 끝난 순간 외에는 자동 시작해서는 안 된다(**shall not**): 기동 시 불러온 작업, 계획 중 취소된 작업, 계획에 실패한 작업은 자동 시작하지 않으며, 재기동 복구(`recoverInterruptedTasks`)는 어떤 작업도 발신하지 않는다.

### 3.5 홈 화면 (앱)

- **REQ-017** [Ubiquitous] 홈 화면은 맨 위에 입력칸 하나("무엇을 도와드릴까요?")와 보내기 버튼을 보여야 한다(**shall**). 버튼은 공백을 지운 글이 2자 이상일 때만 눌리고, 누르면 `POST /v1/intake`를 부르는 동안 진행 표시와 함께 비활성화된 뒤 계획 카드 화면으로 간다. 내 정보(이름)가 없으면 먼저 설정 화면으로 보내고 입력한 글은 지우지 않는다. 기존 "전화 맡기기" 떠 있는 버튼은 없애고, "직접 입력하기" 링크로 기존 양식(`/calls/new`)을 연다.
- **REQ-018** [Ubiquitous] 홈 화면은 입력칸 아래에 제안을 보여야 한다(**shall**): (a) "최근 통화한 곳" — **끝난 작업**(`completed`/`failed`/`canceled`) 중 상대가 받은 적 있는 작업(`connectedAt` 있음)만 정규화한 이름과 번호로 묶어, 가장 최근 통화 순으로 최대 3개(OD-5 DEFAULT). 진행 중이거나 계획 단계인 작업은 넣지 않는다(목록의 "진행 중" 줄과 같은 이름이 겹치지 않게). 각 항목은 표시 이름(가장 최근 작업의 이름)·번호·통화 횟수를 `<이름> · <번호> · N번 통화` 한 덩어리 글(`Text` 하나, 의미 라벨 하나)로 그린다. 그래서 기존 테스트 "user approves a mid-call request from the live call screen"(`approval_flow_test.dart:41-47`, 진행 중 작업 `라 파스타`로 `find.text('라 파스타')` `findsOneWidget` 단언 뒤 탭)은 수정 없이 통과한다. 누르면 입력칸이 `<이름>에 `로 바뀌고 커서가 끝에 간다. (b) "이런 부탁도 할 수 있어요" — 기존 템플릿 칩, 누르면 입력칸이 템플릿 목적 문장으로 바뀐다(더 이상 `/calls/new`로 가지 않음). 템플릿 칩은 화면 전체에서 이 줄 한 곳에만 그려지며 작업 수와 관계없이 항상 보인다. 작업이 없을 때의 빈 상태는 기존 안내 문구(`MessageView`의 제목·설명)만 남기고 그 아래의 기존 칩 줄(`home_screen.dart:196-208`)은 없앤다. 그래서 기존 테스트 "shows the empty state with quick-start templates"(`approval_flow_test.dart:34-39`, `find.text('식당 예약')` `findsOneWidget`)는 수정 없이 통과한다. 진행 중·지난 통화 목록은 그대로다.

### 3.6 계획 카드 (앱)

- **REQ-019** [Ubiquitous] 계획 카드 화면은 초안을 다음 행으로 보여 줘야 하며(**shall**), 각 행을 누르면 그 자리에서 고칠 수 있다(대화상자나 새 화면 없음): 전화할 곳, 전화번호(표시 형식 + 출처 표시 `"text"` → "말씀하신 번호", `"history"` → "지난번 통화한 번호"), 부탁할 일, 조건(항목별 삭제, 추가), 알려줘도 되는 정보(있을 때), 통화 언어(한 번 눌러 바꿈, 기본 한국어), 내 이름(설정의 값, 누르면 설정). `source`가 `"heuristic"`이면 "AI 없이 간단히 정리했어요. 내용을 확인해 주세요."를 보여 준다.
- **REQ-020** [State-driven] **While** 초안에 번호가 없으면, 계획 카드는 번호 칸 하나를 맨 위에 보여 줘야 한다(**shall**): 자동 초점, 전화 키패드, 도움말 "번호만 알려 주시면 바로 걸게요.". `numberIssue`가 `"blocked"`이면 도움말은 "긴급·특수번호에는 걸 수 없어요. 다른 번호를 알려 주세요."다. 이 밖의 추가 질문·대화상자는 없다. 상대 이름이 없으면 그 행이 고치는 상태로 열린다.
- **REQ-021** [Event-driven] **When** 사용자가 [이대로 시작]을 누르면, 앱은 `autoStart: true`와 함께 작업을 만들고(이름·번호·목적·정보·언어, 목적에는 조건을 `\n조건: a / b` 형식으로 붙임, 요청자 이름·회신 번호는 설정 값) 성공하면 그 작업의 상세 화면으로 바꿔 가야 한다(**shall**). 버튼은 이름이 있고, 번호 숫자가 8개 이상이고, 목적이 5자 이상이고, 조건을 붙인 목적이 1000자(UTF-16 길이) 이하이고, 내 이름이 있을 때만 눌린다. 조건을 붙인 목적이 1000자를 넘으면 "부탁할 일이 너무 길어요."를 부탁할 일 행 아래에 보여 준다. 400 `invalid_phone`/`blocked_number`이면 화면에 남아 번호 칸 아래에 서버 문구를 보여 주고, 그 밖의 오류는 스낵바로 알린 뒤 화면에 남는다.
- **REQ-022** [Event-driven] **When** `POST /v1/intake`가 404로 답하면(이 SPEC 이전 서버), 앱은 목적 = 입력 글, 이름·번호 없음, `source: "heuristic"`인 초안으로 계획 카드를 열어야 한다(**shall**). 그 밖의 오류(네트워크, 401, 503 등)는 스낵바로 알리고 홈 화면에 글을 남긴다.

### 3.7 상세 화면과 호환

- **REQ-023** [State-driven] **While** 작업이 `awaiting_approval`이고 `autoStartBlocked`가 있으면, 통화 상세 화면은 계획 검토 위에 "바로 걸지 못했어요: <이유>" 안내를 보여 줘야 하며(**shall**), 기존 "이대로 전화 걸기" 버튼은 그대로 쓸 수 있다. `<이유>`는 `code`가 앱의 기존 오류 문구 대응표(`api_client.dart:16-25`의 `userMessage`)에 있으면 그 한국어 문구, 없으면 서버가 준 `message`다.
- **REQ-024** [Ubiquitous] 기존 서버·앱 테스트는 수정 없이 통과해야 한다(**shall**). `autoStart`를 보내지 않는 예전 앱은 지금과 같게 동작하고, `autoStart`·`autoStartBlocked`를 모르는 예전 앱은 이 필드를 무시한다(예전 앱에서 자동 시작 작업은 평소처럼 진행 상태로 보인다). 기존 양식 경로(`/calls/new` → 계획 검토 → "이대로 전화 걸기")는 자동 시작 없이 지금과 같다.

## 4. 비기능 제약

- 서버 테스트는 실제 OpenAI 호출 없이 `vi.stubGlobal("fetch", …)` 또는 가짜 brain, `InMemoryTaskStore`, 가짜 제공자만 쓴다(SPEC-OUTCOME-001 방식).
- 새 런타임 의존성을 추가하지 않는다(서버·앱). 계층 규칙(`server/src/architecture.test.ts`)은 그대로 통과한다: HTTP는 서비스만 부르고, 규칙 함수는 `domain/`에, LLM 호출은 `brain/`에 둔다.
- 로그 제약: SPEC-OUTCOME-001 REQ-009와 같은 허용 목록(`op`, `reason`, HTTP 상태 코드)만. 의뢰 해석 로그에는 작업 ID가 없다.
- 저장소: 새 저장소를 만들지 않는다. 통화 기록 조회는 `TaskStore.list()`(메모리 사본, `store/taskStore.ts`)를 요청마다 한 번 훑는다. 단일 JSON 파일·단일 인스턴스 전제(`docs/OPERATIONS.md` "실행 전제")를 바꾸지 않는다. 삭제한 작업은 기록에서도 사라진다.
- 앱 문구는 한국어 해요체. 위젯 테스트는 문구·`Key`·의미로 요소를 찾는다.
- 응답 시간: 의뢰 해석 LLM 호출은 15 s 제한(REQ-009). 앱 요청 제한 20 s(`api_client.dart:39`) 안에 결정적 대체 결과까지 돌아오도록 둔 값이다. 계획·요약 호출의 30 s(`openaiBrain.ts:124`)는 바꾸지 않는다.

## 5. Open Decisions

| ID | 결정 사항 | 상태 | 결정 내용 |
|----|-----------|------|-----------|
| OD-1 | 한 번 확인 뒤 자동 시작을 어디서 할지 | **DEFAULT (pending owner review)** | 서버(`autoStart` 필드). 앱이 계획 완료를 기다렸다가 승인 요청을 보내는 방식은 앱이 닫히거나 연결이 끊기면 사용자가 이미 [이대로 시작]을 눌렀는데도 작업이 멈춘다. 바꾸려면 REQ-013~016을 앱 쪽 연쇄 호출 요구로 바꾸고 AC-013~016을 앱 테스트로 옮긴다(`design.md` §7). |
| OD-2 | 기록에서 번호를 찾을 때 쓸 작업 | **DEFAULT (pending owner review)** | 상대가 실제로 받은 작업(`connectedAt` 있음)만. 잘못 입력해 연결되지 않은 번호를 다시 제안하지 않기 위해서다. |
| OD-3 | 같은 이름에 번호가 여럿일 때 | **DEFAULT (pending owner review)** | 가장 최근 작업의 번호. 계획 카드에 "지난번 통화한 번호"로 보이고 한 번 눌러 고칠 수 있다. 바꾸려면 REQ-006과 AC-006 기대값을 고친다. |
| OD-4 | 의뢰 해석이 찾는 번호 형식 | **DEFAULT (pending owner review)** | `0`/`+82`로 시작하는 국내 형식만(050x 안심번호 포함). `1588-xxxx` 같은 대표번호와 해외 번호는 찾지 않고 번호 칸으로 묻는다. 대표번호는 현재 정규화 규칙(`domain/phone.ts:13-16`)이 `+1588…`로 바꾸는 문제가 있어 이 SPEC에서 제안하지 않는다(`research.md` §4). |
| OD-5 | 홈 제안 개수와 정렬 | **DEFAULT (pending owner review)** | 최근 통화 순 3개. 바꾸려면 상수와 AC-018 기대값만 고친다. |
| OD-6 | 화면 문구 | **DEFAULT (pending owner review)** | REQ-017~023의 문구. 바꾸려면 문구 상수와 해당 AC의 기대 문자열만 고친다. |
| OD-7 | 자동 시작 통화의 첫 인사 | **DEFAULT (pending owner review)** | 템플릿 첫 인사(`openingLine(task)`, "…님을 대신해 전화드린 AI 비서입니다…")로 고정한다(REQ-014). LLM 첫 인사가 더 자연스러울 수 있지만 사용자가 보지 않고 시작하므로 AI 고지를 확실히 하는 쪽을 택했다. 바꾸려면 REQ-014의 마지막 문장과 AC-014 (3)을 뺀다. 수동 경로(`/calls/new` → 계획 검토)는 지금처럼 LLM 첫 인사를 보여 주고 고칠 수 있다. |

## 6. 제외 범위 (Out of Scope)

### Out of Scope — 입력 수단과 외부 검색

- 기기 연락처 선택, 음성 입력(STT), 카메라 OCR은 다루지 않는다.
- 네이버·카카오 등 장소·업체 검색 API로 번호를 찾지 않는다(소유자 결정 2).
- 대표번호(15xx·16xx·18xx)와 해외 번호의 자동 추출은 하지 않는다(OD-4). 사용자는 번호 칸에 직접 입력할 수 있다.

### Out of Scope — 대화형 홈과 기억

- 홈을 채팅 스레드로 바꾸지 않는다. 한 줄 입력 → 계획 카드 한 장이 전부다.
- 선호(알레르기, 회원번호 등)를 기억하는 메모리, 사용자가 저장하는 즐겨찾기 상대, 상대별 별명은 다루지 않는다. "최근 통화한 곳"은 저장된 작업에서 매번 계산한다.
- 계정·기기 간 동기화는 다루지 않는다.

### Out of Scope — 자율성 단계

- 자율성 단계 설정(예: 계획 카드 없이 바로 걸기)은 다루지 않는다. 이 SPEC의 단계는 "계획 카드 한 번 확인 → 시작, 통화 중 위험한 결정은 승인"으로 고정이다.
- 자동 시작 실패 뒤 자동 재시도, 예약 통화(정해진 시각에 걸기)는 다루지 않는다.

### Out of Scope — 시각 디자인

- 홈·계획 카드의 색·간격·움직임은 SPEC-UX-001이 정한다.

## 7. 추적성

| 요구사항 | 인수 기준 |
|----------|-----------|
| REQ-001 | AC-001 |
| REQ-002 | AC-002 |
| REQ-003 | AC-003 |
| REQ-004 | AC-004 |
| REQ-005 | AC-005 |
| REQ-006 | AC-006 |
| REQ-007 | AC-007 |
| REQ-008 | AC-008 |
| REQ-009 | AC-009 |
| REQ-010 | AC-010 |
| REQ-011 | AC-011 |
| REQ-012 | AC-001, AC-012 |
| REQ-013 | AC-013 |
| REQ-014 | AC-014 |
| REQ-015 | AC-015 |
| REQ-016 | AC-016 |
| REQ-017 | AC-017 |
| REQ-018 | AC-018 |
| REQ-019 | AC-019 |
| REQ-020 | AC-020 |
| REQ-021 | AC-021 |
| REQ-022 | AC-022 |
| REQ-023 | AC-023 |
| REQ-024 | AC-024 |
