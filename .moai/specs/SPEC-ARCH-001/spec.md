---
id: SPEC-ARCH-001
title: "모듈 경계 정리와 외부 입력 검증"
version: "0.3.0"
status: completed
created: 2026-11-20
updated: 2026-11-27
author: jason
priority: Medium
phase: "v0.2.0 target"
module: "server/src/http, server/src/providers, server/src/domain"
lifecycle: spec-anchored
tags: "architecture, module-boundary, provider-seam, zod, validation, tests, tdd"
tier: L
depends_on: [SPEC-STORE-001, SPEC-LIFECYCLE-001, SPEC-POLICY-001, SPEC-OUTCOME-001]
related_specs: [SPEC-LIFECYCLE-001, SPEC-POLICY-001, SPEC-OUTCOME-001]
---

# SPEC-ARCH-001: 모듈 경계 정리와 외부 입력 검증

## HISTORY

| 버전 | 날짜 | 작성 | 변경 |
|------|------|------|------|
| 0.1.0 | 2026-11-20 | jason (manager-spec) | 최초 작성 (draft) |
| 0.2.0 | 2026-11-21 | jason (manager-spec) | plan-audit iteration 1 반영: `depends_on` 추가, 브리지 재시도 기대값 정정, REQ-011에 주인 없는 스트림 판정 예외 추가, 다중 동작 REQ를 하위 항목으로 나눠 AC 불릿과 대응, Open Decision 기본값 표기 |
| 0.3.0 | 2026-11-21 | jason (manager-spec) | plan-audit iteration 2 반영: Realtime 핸드셰이크 거절 로그의 본문 400자 기록을 §4 로그 제약의 명시적 예외로 둠 |

## 1. 배경과 목적

문서화된 계층(`http → services → brain/providers/store → domain`, `.moai/project/structure.md:50-66`)과 실제 코드가 어긋난 곳이 있고, 외부에서 들어오는 JSON 일부는 검증 없이 쓰인다(근거: `research.md`).

1. **HTTP가 구체 제공자를 안다.** `server/src/http/app.ts:12,20,162-175`가 `KatCallProvider`를 가져와 `isValidHttpWebhook`, `handleStatusWebhook`, `attachMediaStream`을 직접 부른다. `:70`의 원문 본문 캡처는 `/kat/` 접두어에 묶여 있고, `:110`은 `config.provider === "kat"`로 실통화 여부를 정한다.
2. **제공자가 brain에 의존한다.** `server/src/providers/realtimeBridge.ts:2`가 `../brain/prompts.js`를, `server/src/providers/simulatedProvider.ts:2`가 `../brain/scenario.js`를 가져온다.
3. **외부 JSON이 `any`로 다뤄진다.** KAT API 응답(`katProvider.ts:300,314,317,330`), OpenAI Realtime 이벤트와 KAT 미디어 프레임(`realtimeBridge.ts:159,262`)이 `Record<string, any>`다. KAT 상태 웹훅 본문도 타입 단언(`app.ts:168`)만 있다. 반면 HTTP 입력은 모두 zod로 검증한다(`http/schemas.ts`).
4. **제공자 식별자가 두 값으로 고정되어 있다.** `server/src/domain/types.ts:83`, `providers/types.ts:30`.
5. **테스트 공백.** `realtimeBridge.ts`, `KatCallProvider.handleStatusWebhook`·`attachMediaStream`, `openaiBrain.ts` 계획 경로, `/v1/stream` WebSocket을 다루는 테스트가 없다.

목적은 제공자를 늘리거나 바꿀 때 HTTP 계층과 brain을 건드리지 않아도 되게 하고, 외부 입력이 형식을 어겨도 안전하게 무시되게 하며, 검증되지 않은 경로에 테스트를 붙이는 것이다. 모든 엔드포인트의 외부 동작과 전송 형식은 바뀌지 않는다. 이 SPEC은 앞선 네 SPEC의 산출물(시간 제한·`fetch` 주입, `callService.test.ts`, 서비스 정책, 결과 출처와 로그 형식) 위에서 시작하므로 그 넷에 의존한다.

## 2. 범위

- `server/src/http/app.ts`, `server/src/providers/**`, `server/src/brain/prompts.ts`·`scenario.ts`의 위치·사용 방식, `server/src/domain/types.ts`의 제공자 식별자 타입, `server/src/container.ts`·`index.ts`의 연결.
- 새 테스트: 제공자 라우트 등록, `realtimeBridge`, KAT 웹훅·미디어 스트림, `openaiBrain` 계획 경로, `/v1/stream`, 의존 규칙 검사.
- 앱(Flutter)은 코드 변경 없이 모르는 제공자 값을 견디는지 테스트로 고정한다.
- 세부 설계: `design.md`.

## 3. 요구사항 (GEARS)

### 3.1 제공자 라우트 연결 지점

- **REQ-001** [Unwanted] `server/src/http/app.ts`는 `server/src/providers/` 아래의 구체 제공자 모듈(`kat/**`, `simulatedProvider.ts`, `realtimeBridge.ts`)을 가져와서는 안 되고, 제공자 이름 문자열(`"kat"`, `"/kat/"`)로 분기해서도 안 된다(**shall not**).
- **REQ-002** [Ubiquitous] 제공자는 자신에게 필요한 HTTP 웹훅 라우트와 WebSocket 라우트를 제공자 중립 계약(`server/src/providers/types.ts`)으로 선언할 수 있어야 하고(**shall**), HTTP 계층은 선언된 라우트를 그대로 등록한다. 계약은 Fastify 타입에 의존하지 않는다(`design.md` §1).
- **REQ-003** [Where] **Where** 활성 제공자가 라우트를 선언하지 않으면(시뮬레이션), HTTP 계층은 제공자 라우트를 하나도 등록하지 않아야 한다(**shall**). 지금처럼 시뮬레이션 모드에서 `POST /kat/status`는 404다.
- **REQ-004** [Ubiquitous] 서명 검증용 원문 본문 캡처는 원문 본문이 필요하다고 선언된 라우트에만 적용되어야 하며(**shall**), 캡처된 바이트는 지금과 같다.
- **REQ-005** [Ubiquitous] KAT 모드의 `POST /kat/status`와 `GET /kat/media`의 외부 동작은 바뀌지 않아야 한다(**shall**): (a) 서명 무효 401 `{"error":"invalid_signature"}`, (b) 서명 유효 204, (c) `/v1/*` 인증 훅은 제공자 라우트에 적용되지 않음.
- **REQ-006** [Ubiquitous] `GET /v1/config` 응답(`provider`, `brain`, `realCalls`)은 지금과 같은 값이어야 하며(**shall**), `realCalls`는 HTTP 계층이 제공자 이름을 비교해 정하지 않고 연결 단계(`container.ts`)가 넘겨준 값을 쓴다.

### 3.2 의존 방향

- **REQ-007** [Unwanted] `server/src/providers/` 아래 모듈은 `server/src/brain/` 아래 모듈을 가져와서는 안 된다(**shall not**). 시뮬레이션 각본이 쓰는 시나리오 템플릿은 두 쪽이 함께 쓸 수 있는 중립 위치로 옮긴다(`design.md` §3).
- **REQ-008** [Ubiquitous] 실시간 음성 세션에 쓰는 에이전트 지시문은 서비스 계층이 만들어 `CallSession`을 통해 제공자에 전달해야 하며(**shall**), 내용은 지금의 `buildAgentInstructions(task)` 결과와 글자 단위로 같다.

### 3.3 외부 입력 검증 (zod, 실패 시 안전하게 무시)

- **REQ-009** [Ubiquitous] KAT API 응답 본문은 zod 스키마로 해석되어야 한다(**shall**): (a) 통화 생성 응답은 최상위 또는 `result` 안의 비어 있지 않은 `callId`를 요구하며, 없으면 지금과 같은 오류("KAT Cloud did not return a callId")를 낸다. (b) 오류 응답의 문구 추출(`message`/`error`/원문 앞 200자)은 본문 형식이 어긋나도 예외를 내지 않는다.
- **REQ-010** [Event-driven] **When** 서명이 유효한 KAT 상태 웹훅 본문이 스키마를 통과하지 못하면, 제공자는 본문을 무시하고 warn 수준으로 기록해야 하며(**shall**), HTTP 응답은 지금처럼 204다(OD-2 DEFAULT). 로그에는 본문 원문을 넣지 않는다.
- **REQ-011** [Event-driven] **When** KAT 미디어 스트림의 `start` 프레임이 스키마를 통과하지 못하면, 제공자는 그 프레임을 무시하고 warn 수준으로 기록한 뒤 다음 프레임을 기다려야 한다(**shall**)(10 s 대기 제한은 현행 유지). JSON이 아니거나 형식이 어긋난 `media`/`stop` 프레임은 로그 없이 무시한다. **예외**: SPEC-LIFECYCLE-001 REQ-016의 주인 없는 스트림 판정(헤더 통화 ID에 활성 세션이 없으면 종료)은 프레임 해석·검증보다 **먼저** 실행된다. 따라서 활성 세션이 없는 연결에서는 형식이 어긋난 첫 프레임도 무시되지 않고 통화 종료로 이어지며, 10 s 시간 초과 시점에도 같은 판정이 실행된다.
- **REQ-012** [Event-driven] **When** OpenAI Realtime 이벤트 중 처리 대상 유형(음성 조각, 발화 시작, 전사 완료, 함수 호출 인자 완료, 오류)이 스키마를 통과하지 못하면, 브리지는 그 이벤트를 무시하고 warn 수준으로 기록해야 한다(**shall**). 처리 대상이 아닌 유형은 지금처럼 조용히 무시한다. 함수 호출 인자(`request_user_approval`의 `question`)도 스키마로 해석하고, 어긋나면 지금의 기본 질문을 쓴다.
- **REQ-013** [Unwanted] `server/src/providers/kat/katProvider.ts`와 `server/src/providers/realtimeBridge.ts`에는 외부 데이터에 대한 `any` 타입이 남아 있어서는 안 된다(**shall not**). (측정: `Record<string, any>|: any|as any` 일치 줄 수 각각 4, 2.)

### 3.4 제공자 식별자 타입

- **REQ-014** [Ubiquitous] 작업의 `provider` 필드와 `CallProvider.name`은 두 값 고정 합집합이 아니라 문자열 기반 제공자 식별자 타입이어야 하며(**shall**), 기존 저장값 `"simulated"`, `"kat"`은 그대로 유효하다. 설정의 제공자 선택(`config.ts`의 `CALL_PROVIDER` 열거형)은 바꾸지 않는다.
- **REQ-015** [Ubiquitous] 앱의 `CallTask.fromJson`은 모르는 `provider` 값을 예외 없이 파싱해야 하며(**shall**), `isSimulated`는 `provider == "simulated"`일 때만 참이다(현행 동작을 테스트로 고정, OD-1 DEFAULT).

### 3.5 테스트 공백 해소

- **REQ-016** [Ubiquitous] `realtimeBridge.ts`는 가짜 WebSocket으로 다음 동작이 각각 검증되어야 한다(**shall**). 이를 위해 브리지에 WebSocket 생성 주입 지점을 둔다.
  - (a) AI 소켓이 열리면 지시문·음성 형식·도구를 담은 세션 설정과 응답 생성 요청을 보낸다
  - (b) KAT 음성 프레임을 AI로, AI 음성 조각을 KAT로 전달한다
  - (c) 상대 발화 시작 시 KAT에 재생 중단(`clear`)을 보낸다
  - (d) 상대·에이전트 전사 완료를 대화 기록에 넣는다
  - (e) 승인 도구 호출을 사용자 승인 요청으로 바꾸고 결과를 도구 출력으로 돌려준다
  - (f) 통화 종료 도구 호출 뒤 2,500 ms 유예 후 통화를 끊는다
  - (g) 과금·인증 오류 이벤트에서 실패를 기록하고 세션을 끝내며 통화를 끊는다
  - (h) 연결 거절 시 첫 거절 뒤 한 번만 다시 연결하고, 두 번째 거절에서 실패 처리한다(`REALTIME_CONNECT_RETRIES = 2`, 첫 시도 포함 총 2회)
  - (i) KAT `stop` 프레임에서 AI 소켓을 닫는다
- **REQ-017** [Ubiquitous] `KatCallProvider.handleStatusWebhook`은 다음 동작이 각각 검증되어야 한다(**shall**): (a) 신호 감 → 벨 울림 표시, (b) 응답 → 연결 표시, (c) 음성 연결 전 종료 → 미디어 실패 문구로 종료, (d) 음성 연결 뒤 정상 종료 → 오류 없이 종료, (e) 실패 상태별 문구, (f) 모르는 작업 무시.
- **REQ-018** [Ubiquitous] `KatCallProvider.attachMediaStream`은 다음 동작이 각각 검증되어야 한다(**shall**): (a) 서명 무효 시 닫기, (b) 정상 `start` 시 연결 표시와 브리지 연결, (c) 토큰 불일치 시 거부·세션 종료·종료 요청, (d) `start`가 오지 않을 때 10 s 뒤 닫기.
- **REQ-019** [Ubiquitous] `openaiBrain.ts`는 SPEC-OUTCOME-001의 요약 경로 테스트에 더해 계획 경로(정상 응답 통과, 스키마 경계 위반 시 대체)를 검증해야 한다(**shall**).
- **REQ-020** [Ubiquitous] `/v1/stream` WebSocket은 다음이 검증되어야 한다(**shall**): (a) 연결 직후 `snapshot`, (b) 작업 생성 뒤 `task.updated`, (c) 헤더 토큰과 `?token=` 쿼리 토큰 인증 허용, (d) 토큰 없는 연결 거부(401).
- **REQ-021** [Ubiquitous] 제공자 라우트 등록은 테스트로 검증되어야 한다(**shall**): (a) 라우트를 선언한 가짜 제공자의 라우트가 등록되고 원문 본문을 받으며, (b) 라우트가 없는 제공자에서는 `/kat/*`가 404다.

### 3.6 회귀

- **REQ-022** [Ubiquitous] 기존 서버 테스트와 앱 테스트는 수정 없이 통과해야 하며(**shall**), 모든 HTTP 엔드포인트의 상태 코드·응답 본문 형식과 `/v1/stream` 이벤트 형식(`snapshot`, `task.updated`, `task.deleted`)은 바뀌지 않는다. 앞선 SPEC들이 의도적으로 바꾼 기대값은 그 SPEC의 결과를 기준으로 한다.

## 4. 비기능 제약

- 실제 KAT·OpenAI 네트워크를 쓰지 않는다. 가짜 WebSocket, 주입 `fetch`, 가짜 타이머, Fastify `inject`/`injectWS`만 쓴다.
- 새 런타임 의존성을 추가하지 않는다(zod는 이미 의존성에 있다 — `server/package.json`).
- 로그에 전화번호 원문, 대화 내용, 웹훅·이벤트 본문 원문을 넣지 않는다. **예외(현행 유지)**: Realtime 핸드셰이크 거절 로그(`realtimeBridge.ts:198-204`, `"Realtime handshake rejected"`)는 지금처럼 응답 본문 앞 400자를 남긴다. 이 본문은 통화 상대나 웹훅이 보낸 것이 아니라 OpenAI가 연결을 거절한 이유(인증·과금 오류 문구)이고, 운영자가 원인을 알 수 있는 유일한 단서다. 이 동작은 AC-015 (h)의 보호 대상이다. 상태 코드만 남기도록 바꾸는 것은 동작 변경이므로 이 SPEC에서는 하지 않는다(더 작은 변경을 택함).
- 이 SPEC은 대부분 동작을 바꾸지 않는 구조 변경이므로, 각 마일스톤은 "보호 테스트 먼저(현재 동작 고정) → 구조 변경 → 같은 테스트 통과" 순서를 따른다. 새 동작(형식 오류 무시·로그, 라우트 계약, 의존 규칙)만 RED에서 실패해야 한다.

## 5. Open Decisions

| ID | 결정 사항 | 상태 | 결정 내용 |
|----|-----------|------|-----------|
| OD-1 | 앱이 모르는 제공자 값을 어떻게 보여 줄지 | **DEFAULT (pending owner review)** | 지금처럼 실통화로 취급한다(`isSimulated == false`). 모르는 연결을 시뮬레이션으로 보여 주면 실제 사람에게 걸린 통화를 연습으로 오해할 수 있다. 바꾸려면 앱 모델에 "알 수 없는 연결" 표시 하나와 AC-014 기대값을 고친다. |
| OD-2 | 서명은 유효하지만 형식이 어긋난 KAT 상태 웹훅에 대한 응답 | **DEFAULT (pending owner review)** | 지금처럼 204로 받고 무시한다. KAT의 재전송 정책(2xx가 아니면 재시도하는지)이 확인되지 않아 400이 재전송 폭주를 부를 수 있다. 바꾸려면 REQ-010의 상태 코드와 AC-009 기대값만 고친다. |

## 6. 제외 범위 (Out of Scope)

### Out of Scope — 허브·SDK·프로토콜

- 외부 허브 발신 에이전트, SDK·애드온, A2A·MCP·OAuth 연동은 다루지 않는다. 이 SPEC은 그 방향을 어렵게 만들지 않는 경계(제공자 중립 라우트 계약, 서비스 계층 지시문 주입)까지만 만든다.
- 두 번째 통신 제공자 구현은 하지 않는다.

### Out of Scope — 소유권·다중 사용자

- 작업 소유자(사용자·조직) 모델, 다중 사용자 인증, 작업별 접근 제어는 다루지 않는다. 앞으로 허브 연동을 하려면 먼저 필요한 선행 작업으로 기록만 한다.

### Out of Scope — 동작 변경

- 엔드포인트 추가·삭제, 응답 형식 변경, 오류 코드 변경은 하지 않는다.
- 실시간 대화 프롬프트 내용, 도구 정의(`TOOLS`), 재시도 횟수·대기 값 변경은 하지 않는다.
- SPEC-LIFECYCLE-001이 다루는 종료·복구·시간 제한·주인 없는 스트림 동작은 다시 설계하지 않는다(그 결과를 그대로 유지).

## 7. 추적성

| 요구사항 | 인수 기준 |
|----------|-----------|
| REQ-001 | AC-001 |
| REQ-002 | AC-002 |
| REQ-003 | AC-003 |
| REQ-004 | AC-002, AC-004 |
| REQ-005 (a)(b)(c) | AC-004 (1)(2)(3) |
| REQ-006 | AC-005 |
| REQ-007 | AC-006 |
| REQ-008 | AC-007 |
| REQ-009 (a)(b) | AC-008 |
| REQ-010 | AC-009 |
| REQ-011 | AC-010 |
| REQ-012 | AC-011 |
| REQ-013 | AC-012 |
| REQ-014 | AC-013 |
| REQ-015 | AC-014 |
| REQ-016 (a)~(i) | AC-015 (a)~(i) |
| REQ-017 (a)~(f) | AC-016 (a)~(f) |
| REQ-018 (a)~(d) | AC-017 (a)~(d) |
| REQ-019 | AC-018 |
| REQ-020 (a)~(d) | AC-019 (a)~(d) |
| REQ-021 (a)(b) | AC-002, AC-003 |
| REQ-022 | AC-020 |
