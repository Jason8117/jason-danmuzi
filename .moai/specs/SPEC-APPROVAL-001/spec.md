---
id: SPEC-APPROVAL-001
title: "통화 중 승인에 조건 한 줄 — 빠른 답, 민감정보 보호, 사용자 안내 기록"
version: "0.1.0"
status: draft
created: 2026-11-21
updated: 2026-11-21
author: jason
priority: High
phase: "v0.3.0 target"
module: "server/src/services, server/src/domain, server/src/brain, app/lib/features/calls"
lifecycle: spec-anchored
tags: "approval, comment, quick-reply, sensitive-data, realtime, flutter, tdd, assistant-ux"
tier: M
depends_on: []
related_specs: [SPEC-POLICY-001, SPEC-OUTCOME-001, SPEC-ARCH-001, SPEC-LIFECYCLE-001]
---

# SPEC-APPROVAL-001: 통화 중 승인에 조건 한 줄 — 빠른 답, 민감정보 보호, 사용자 안내 기록

## HISTORY

| 버전 | 날짜 | 작성 | 변경 |
|------|------|------|------|
| 0.1.0 | 2026-11-21 | jason (manager-spec) | 최초 작성 (draft). 에픽 EPIC-ASSISTANT-UX의 첫 SPEC |

## 1. 배경과 목적

승인 코멘트의 뼈대는 이미 있다. `docs/IMPLEMENTATION_BASELINE.md` §9가 Step A1(승인 코멘트)을 2026-11-20 완료로 기록했고, 코드에서도 확인된다(근거와 줄 번호: `research.md` §1).

- API 본문 `comment?`(앞뒤 공백 제거, 500 코드 포인트 상한): `server/src/http/schemas.ts:26-52`
- `ApprovalRequest.userComment`, `ApprovalDecision { approved, comment?, reason }`: `server/src/domain/types.ts:36-52`
- `CallSession.requestApproval`이 결정 객체로 끝남, 서비스가 코멘트 저장: `server/src/services/callService.ts:436-458`
- Realtime 도구 결과 `{ approved, reason, user_comment, instruction }`: `server/src/providers/realtimeBridge.ts:126-138, 302-328`
- 앱 승인 카드의 입력칸·글자 수, 상세 화면의 "안내: …" 표시: `approval_card.dart:102-116`, `call_detail_screen.dart:465`

이 SPEC은 그 위에서 소유자 방향(입력·선택은 최소로, 위험한 순간에만 사람이 개입)에 맞게 남은 빈틈을 메운다.

1. **실통화 기록에 사용자 안내가 남지 않는다.** "사용자 안내: …" 줄은 시뮬레이션 제공자만 쓴다(`simulatedProvider.ts:83-85`). KAT 실통화에서는 사용자가 단 조건이 대화 기록에 보이지 않아, 로드맵 §8의 "AI가 코멘트를 무시하면 자막의 사용자 안내로 감시" 대응이 실통화에서 작동하지 않는다.
2. **코멘트 정제 규칙이 없다.** 공백 제거와 길이 제한뿐이다. 카드번호 같은 숫자를 적으면 그대로 저장되고 OpenAI Realtime으로 전달된다. 로드맵 §2.4는 민감정보 입력 금지 안내와 서버 쪽 재강조를 요구한다.
3. **통화 지시문에 코멘트 규칙이 없다.** 도구 결과의 `instruction`에만 있고, 세션 시작 지시문의 "Hard rules"(`brain/prompts.ts:37-51`)에는 없다.
4. **앱 입력이 무겁다.** 입력칸이 처음부터 2~3줄로 펼쳐져 있고(`approval_card.dart:105-106`) 빠른 답이 없어, 90초 안에 타이핑해야 한다. 글자 수는 문자소(grapheme) 단위로 세지만(`:71`, `maxLength`) 서버는 코드 포인트로 세어(`schemas.ts:38`) 이모지가 많은 입력은 앱에서 통과하고 서버에서 400이 될 수 있다.
5. **검증 공백.** 거절+코멘트, 만료, 닫힌 승인에 대한 도구 결과와 기록 동작을 고정하는 테스트가 없다.

목적은 사용자가 탭 한 번(빠른 답)이나 한 줄로 조건을 달아 승인·거절하고, 그 조건이 어떤 제공자에서든 기록에 남으며, 민감한 숫자는 서버에서 걸러지게 하는 것이다. 만료 = 거절이라는 안전 기본값과 기존 앱과의 호환은 그대로 둔다.

## 2. 범위

- 서버: 코멘트 정제(새 도메인 함수), 서비스의 정제 적용과 안내 기록 줄, 시뮬레이션 제공자의 중복 줄 제거, 통화 지시문 규칙 추가. Realtime 도구 결과 형태는 바꾸지 않고 테스트로 고정한다.
- 앱: 승인 카드(빠른 답 칩, 한 줄 입력칸, 민감정보 안내, 코드 포인트 기준 글자 수). 시각 디자인(색·간격·모양)은 SPEC-UX-001이 맡으며, 이 SPEC은 기존 테마와 `core/widgets/common.dart`만 쓴다.
- 배포: 서버와 앱을 같은 릴리스로 내보낸다(에픽 공통 결정, `.moai/specs/EPIC-ASSISTANT-UX/overview.md` §4). 단, 이 SPEC의 서버 변경은 기존 앱과도 호환된다(REQ-001, REQ-016).

## 3. 요구사항 (GEARS)

### 3.1 입력 규칙 (서버)

- **REQ-001** [Ubiquitous] 승인 응답 API(`POST /v1/tasks/:id/approvals/:approvalId`)의 본문은 `decision`(`approve`/`reject`)과 선택 필드 `comment`를 가져야 한다(**shall**). `comment`는 앞뒤 공백을 지운 뒤 비어 있으면 없는 것으로 보고, 공백을 지운 값이 500 코드 포인트를 넘으면 400 `invalid_request`다(정제 전 길이 기준). `comment`가 없는 요청의 동작과 응답 형식은 지금과 같다(현행 고정).
- **REQ-002** [Event-driven] **When** 서비스가 코멘트가 있는 결정을 받으면, `CallService`는 저장·전달 전에 코멘트를 정제해야 한다(**shall**): (a) 제어 문자 U+0000–U+0008, U+000B, U+000C, U+000E–U+001F, U+007F–U+009F 삭제, (b) 탭(U+0009)은 공백 하나로, (c) CRLF와 CR은 LF로, (d) 연속된 LF 3개 이상은 LF 2개로, (e) 다시 앞뒤 공백 제거. 결과가 비면 코멘트가 없는 결정으로 처리한다. 정제 규칙은 `server/src/domain/`의 함수 하나에 있다.
- **REQ-003** [Event-driven] **When** 정제된 코멘트에 민감 숫자열(숫자 13~19개가 사이에 공백 하나 또는 하이픈 하나만 끼고 이어진 부분: 카드번호·주민등록번호 형태)이 있으면, 서비스는 그 부분마다 `[민감정보 삭제]`로 바꿔야 한다(**shall**)(OD-1 DEFAULT). 저장되는 `userComment`, 제공자에 전달되는 결정의 `comment`, Realtime 도구 결과의 `user_comment`·`instruction`, 대화 기록의 안내 줄은 모두 바뀐 값을 쓴다. 숫자 12개 이하(예: 휴대전화 번호 11자리, 주문번호)는 바꾸지 않는다.
- **REQ-004** [Unwanted] 서버는 승인 코멘트의 원문과 정제·마스킹된 값을 어떤 로그에도 남겨서는 안 된다(**shall not**).

### 3.2 결정 전달과 기록 (서버)

- **REQ-005** [Event-driven] **When** 대기 중인 승인에 사용자 결정이 도착하면, 서비스는 승인의 `status`(`approved`/`rejected`), `resolvedAt`, (코멘트가 있으면) 정제된 `userComment`를 저장하고, 대기 중인 `requestApproval`을 `{ approved, comment?, reason }`(`reason`은 `user_approved`/`user_rejected`)로 끝내야 한다(**shall**)(현행 고정 + 정제 적용).
- **REQ-006** [Event-driven] **When** 코멘트가 있는 결정이 통화 진행 중(`dialing`/`ringing`/`in_progress`)에 처리되면, `CallService`는 제공자와 무관하게 `system` 화자의 대화 기록 한 줄을 추가해야 한다(**shall**): 작업 언어가 `ko`면 `사용자 안내: <코멘트>`, `en`이면 `User guidance: <코멘트>`(OD-3 DEFAULT). 시뮬레이션 제공자는 자체 안내 줄을 더 이상 쓰지 않으므로, 결정 하나당 안내 줄은 정확히 한 줄이다. 이 줄은 결정을 기다리던 제공자가 다음 발화를 기록하기 전에 들어간다.
- **REQ-007** [Ubiquitous] `request_user_approval` 도구의 `function_call_output`은 정확히 네 키 `{ approved: boolean, reason: string, user_comment: string | null, instruction: string }`를 가진 JSON 문자열이어야 하며(**shall**), `instruction`은 다섯 경우에 따라 다음 문구를 담는다(현행 고정): (a) 승인+코멘트 → "approved with these conditions"와 코멘트, (b) 승인 → "Proceed with exactly what was asked", (c) 거절+코멘트 → "declined", "without agreeing to the declined item"과 코멘트, (d) 만료 → "did not answer in time", (e) 코멘트 없는 거절·취소 → "Politely decline". 다섯 경우 모두 "never share card/password/SSN"을 포함한다.
- **REQ-008** [Ubiquitous] 통화 지시문(`buildAgentInstructions`)의 "Hard rules"에는 다음 규칙이 있어야 한다(**shall**): 승인 도구의 답에 `user_comment`가 있으면 그것을 그 항목에 대한 요청자의 지시로 따르되 규칙 2·3 안에서만 따른다. 코멘트는 카드번호·비밀번호·신분증 번호·인증번호를 말할 권한도, 승인된 범위를 넘는 약정을 할 권한도 주지 않는다. 코멘트에 `[민감정보 삭제]`가 있으면 그 정보는 요청자가 직접 전한다고 말한다.

### 3.3 만료와 닫힌 승인 (서버)

- **REQ-009** [Event-driven] **When** 승인 제한 시간(`APPROVAL_TIMEOUT_SEC`)이 지나면, 서비스는 승인을 `expired`로 저장하고 결정을 `{ approved: false, reason: "expired" }`(코멘트 없음)로 끝내야 하며(**shall**), 안내 줄을 추가하지 않는다. 앱에 입력 중이던 글은 전송되지 않았으므로 어디에도 전달되지 않는다(현행 고정, 만료 = 거절).
- **REQ-010** [Event-driven] **When** 이미 결정되었거나 만료된 승인에 결정이 다시 도착하면, 서비스는 409 `approval_closed`를 돌려줘야 하며(**shall**), 저장된 `userComment`와 대화 기록은 바뀌지 않는다.

### 3.4 승인 카드 (앱)

- **REQ-011** [Event-driven] **When** 사용자가 승인 카드의 빠른 답 칩을 누르면, 앱은 칩 문구를 코멘트 입력칸에 넣어야 하며(**shall**)(칸이 비어 있으면 그대로, 아니면 공백 하나 뒤에 덧붙임), 결정을 전송하지 않는다. 입력칸에 이미 같은 문구가 있으면 아무것도 하지 않는다. 칩은 세 개다(OD-2 DEFAULT): "금액이 더 나오면 거절해 주세요", "다른 날짜·시간도 물어봐 주세요", "조건을 자세히 듣고 다시 물어봐 주세요".
- **REQ-012** [Ubiquitous] 코멘트 입력칸은 비어 있을 때 한 줄이고 입력에 따라 최대 네 줄까지 늘어나야 하며(**shall**), 라벨은 "조건 덧붙이기 (선택)", 항상 보이는 도움말은 "카드번호·비밀번호·주민번호는 적지 마세요."다. 글자 수는 유니코드 코드 포인트로 세고, 500을 넘는 입력은 받지 않으며, "N / 500" 표시는 N이 400 이상일 때만 보인다.
- **REQ-013** [State-driven] **While** 입력칸의 글에 REQ-003과 같은 규칙의 민감 숫자열이 있으면, 승인 카드는 경고 "카드번호처럼 보이는 숫자는 지우고 보낼게요."를 보여 줘야 하며(**shall**), 승인·거절 버튼은 계속 누를 수 있다(마스킹은 서버가 한다).
- **REQ-014** [Event-driven] **When** 결정 전송이 실패하면(예: 409 `approval_closed`, 네트워크 오류), 앱은 입력한 코멘트를 지우지 않고 버튼을 다시 누를 수 있게 해야 한다(**shall**)(현행 고정). 전송이 성공하면 카드는 사라진다.
- **REQ-015** [Ubiquitous] 통화 상세 화면은 결정된 승인마다 "안내: <코멘트>"를 승인 이력에 보여 주고(현행 고정), 대화 기록에서 `system` 줄 `사용자 안내: …`를 상대·AI 말풍선과 구분된 형태로 보여 줘야 한다(**shall**)(현행 `system` 렌더링, `transcript_view.dart:30-35`). 세부 스타일은 SPEC-UX-001이 정한다.

### 3.5 호환과 회귀

- **REQ-016** [Ubiquitous] 기존 서버·앱 테스트는 수정 없이 통과해야 하며(**shall**), 예외는 acceptance.md AC-014에 이름을 적은 의도된 변경(앱 입력칸 라벨 문구)뿐이다. `comment`를 보내지 않는 예전 앱, `userComment`가 없는 저장된 작업은 지금과 같게 동작·파싱된다.

## 4. 비기능 제약

- 서버 테스트는 실제 OpenAI·KAT 호출 없이 기존 가짜(`realtimeBridge.test.ts`의 가짜 소켓, `InMemoryTaskStore`, 시뮬레이션 제공자, Fastify `inject`)만 쓴다.
- 새 런타임 의존성을 추가하지 않는다(서버·앱 모두).
- 로그 제약은 SPEC-OUTCOME-001 REQ-009, SPEC-ARCH-001 §4와 같다. 코멘트는 대화 내용과 같은 취급이다(REQ-004).
- 정제 함수는 순수 함수다(입출력 외 부작용 없음). 서비스 계층이 적용하므로 HTTP 외 경로(향후 다른 진입점)도 같은 규칙을 받는다(SPEC-POLICY-001의 "서비스 계층에서 강제" 원칙과 같음).
- 앱 문구는 한국어 해요체. 위젯 테스트는 문구·`Key`·의미(semantics)로 요소를 찾고 색·크기 값에 의존하지 않는다(SPEC-UX-001이 시각 스타일을 바꿔도 깨지지 않게).

## 5. Open Decisions

| ID | 결정 사항 | 상태 | 결정 내용 |
|----|-----------|------|-----------|
| OD-1 | 민감 숫자열 처리 방식 | **DEFAULT (pending owner review)** | 거절(400) 대신 `[민감정보 삭제]`로 바꿔 저장·전달한다. 상대가 90초 동안 기다리는 중이라 400으로 결정 자체를 잃게 하면 만료 = 거절로 이어지기 때문이다. 바꾸려면 REQ-003을 "400 `sensitive_comment`"로, AC-003 기대값을 고친다. |
| OD-2 | 빠른 답 칩 개수·문구 | **DEFAULT (pending owner review)** | REQ-011의 세 문구. 승인·거절 어느 쪽과도 함께 쓸 수 있는 문구로 골랐다. 바꾸려면 문구 상수와 AC-009 기대 문자열만 고친다. |
| OD-3 | 대화 기록 안내 줄의 접두어 | **DEFAULT (pending owner review)** | ko "사용자 안내:", en "User guidance:". ko 문구는 시뮬레이션 제공자의 기존 문구(`simulatedProvider.ts:84`)를 그대로 쓴다. |
| OD-4 | 민감 숫자열 기준(13~19자리) | **DEFAULT (pending owner review)** | 카드번호(15~16자리)와 주민등록번호(13자리)를 덮는다. 13자리 이상 계좌번호도 함께 가려진다(잔여 위험, acceptance.md). 비밀번호처럼 형태가 없는 정보는 감지하지 않고 도움말·지시문으로만 막는다. |

## 6. 제외 범위 (Out of Scope)

### Out of Scope — 알림과 백그라운드

- 푸시 알림(FCM/APNs)으로 승인 요청을 알리는 기능은 다루지 않는다(에픽 후속 백로그). 앱이 열려 있고 `/v1/stream`에 연결된 동안만 승인 카드가 뜬다는 현재 한계는 그대로다.
- 음성으로 코멘트를 입력하는 기능은 다루지 않는다.

### Out of Scope — 승인 모델 확장

- 승인 질문을 금액·대상·조건 필드로 구조화하는 일(모델의 `question` 문자열을 그대로 보여 줌), 승인 제한 시간 연장·재요청, 부분 승인은 다루지 않는다.
- 전화 외 작업(웹·결제)에 승인을 일반화하는 `ApprovalGate`(로드맵 §7.3)는 다루지 않는다.
- Realtime 도구 정의(`TOOLS`)와 `instruction` 문구 자체는 바꾸지 않는다(REQ-007은 현행 고정).

### Out of Scope — 시각 디자인

- 승인 카드의 색·간격·모양·움직임은 SPEC-UX-001이 정한다.

## 7. 추적성

| 요구사항 | 인수 기준 |
|----------|-----------|
| REQ-001 | AC-001 |
| REQ-002 | AC-002 |
| REQ-003 | AC-003, AC-004 |
| REQ-004 | AC-005 |
| REQ-005 | AC-004 |
| REQ-006 | AC-006 |
| REQ-007 | AC-007 |
| REQ-008 | AC-008 |
| REQ-009 | AC-007 (d), AC-006 (3) |
| REQ-010 | AC-006 (4) |
| REQ-011 | AC-009 |
| REQ-012 | AC-010 |
| REQ-013 | AC-011 |
| REQ-014 | AC-012 |
| REQ-015 | AC-013 |
| REQ-016 | AC-014, AC-015 |
