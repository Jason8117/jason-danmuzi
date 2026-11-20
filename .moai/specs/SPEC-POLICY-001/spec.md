---
id: SPEC-POLICY-001
title: "통화 안전 정책을 서비스 계층에서 강제"
version: "0.3.0"
status: draft
created: 2026-11-20
updated: 2026-11-21
author: jason
priority: High
phase: "v0.2.0 target"
module: "server/src/services, server/src/domain"
lifecycle: spec-anchored
tags: "policy, safety, emergency-number, phone, service-layer, tdd"
tier: M
depends_on: [SPEC-LIFECYCLE-001]
related_specs: [SPEC-LIFECYCLE-001, SPEC-ARCH-001]
---

# SPEC-POLICY-001: 통화 안전 정책을 서비스 계층에서 강제

## HISTORY

| 버전 | 날짜 | 작성 | 변경 |
|------|------|------|------|
| 0.1.0 | 2026-11-20 | jason (manager-spec) | 최초 작성 (draft) |
| 0.2.0 | 2026-11-21 | jason (manager-spec) | plan-audit iteration 1 반영: OD-1 소유자 결정(a) 반영, 발신 직전 재검사 추가, 국가 번호 판정을 원문 기준으로 명시, `depends_on` 추가 |
| 0.3.0 | 2026-11-21 | jason (manager-spec) | plan-audit iteration 2·3 반영(문구만): `approvePlan` 검사 순서(503 → 404 → 409 → 400 → 429)를 plan·AC-010 (3)에 고정하고 REQ-007에 "한도 검사보다 먼저" 명시. REQ/AC 수와 기대값 불변 |

## 1. 배경과 목적

긴급·특수번호(112, 119, 113, 114, 117, 118, 122, 125, 182 — `server/src/domain/phone.ts:22`)에 자동 전화를 걸지 않는 규칙과 전화번호 정규화는 지금 `POST /v1/tasks` 라우트 핸들러 안에서만 실행된다(`server/src/http/app.ts:117-125`). `CallService.create`(`callService.ts:91-107`)와 발신 경로인 `approvePlan`(`callService.ts:110-128`)은 번호를 다시 보지 않는다. 따라서 HTTP가 아닌 다른 진입점(내부 호출, 앞으로의 SDK·허브 연동)이나 데이터 파일에서 적재된 작업은 차단 규칙을 거치지 않는다.

또한 차단 규칙은 현재 **실제로는 한 번도 적용되지 않는다**(`research.md` §3). `isBlockedNumber`는 국내 번호 부분이 정확히 3자리인 E.164 값에만 참을 돌려주는데, `normalizePhoneNumber`는 `+` 뒤 8~15자리인 값만 통과시키므로 그런 값을 만들지 않는다. "119"를 입력하면 `blocked_number`가 아니라 `invalid_phone`으로 거절된다.

목적은 이 규칙을 원래 의도대로 실제로 동작하게 하고, 비즈니스 규칙이 사는 곳(서비스와 서비스가 호출하는 도메인 함수)에서 **작업 생성 시점과 발신 직전 두 곳**에 적용해, 어떤 진입점으로 들어온 작업도 규칙을 거치지 않고는 전화가 걸리지 않게 하는 것이다. HTTP 계층은 오류를 응답으로 옮기는 역할만 한다.

## 2. 범위

- `CallService.create`와 `CallService.approvePlan`의 번호 검사, `server/src/domain/phone.ts`의 대상 번호 판정 함수.
- `server/src/http/app.ts`의 `POST /v1/tasks` 핸들러에서 정책 코드 제거.
- HTTP 상태 코드는 그대로 둔다(모두 400). `119` 같은 차단 번호의 오류 코드는 `invalid_phone`에서 `blocked_number`로 바뀐다(OD-1 RESOLVED). 앱(Flutter) 코드는 바뀌지 않는다.

## 3. 요구사항 (GEARS)

### 3.1 서비스 계층 강제 — 작업 생성 시점

- **REQ-001** [Ubiquitous] `CallService.create`는 작업을 저장하거나 계획을 세우기 전에 대상 전화번호를 E.164로 정규화해야 한다(**shall**). 저장되는 `phoneNumber`는 정규화된 값이다.
- **REQ-002** [Event-driven] **When** 대상 전화번호를 정규화할 수 없으면, `CallService.create`는 `ServiceError(400, "invalid_phone", "전화번호 형식이 올바르지 않습니다.")`를 던져야 하고(**shall**), 작업 저장·이벤트 발행·`brain.createPlan` 호출이 하나도 일어나지 않아야 한다.
- **REQ-003** [Event-driven] **When** 대상 전화번호가 차단 번호로 판정되면(REQ-009), `CallService.create`는 `ServiceError(400, "blocked_number", "긴급·특수번호에는 전화할 수 없습니다.")`를 던져야 하고(**shall**), 작업 저장·이벤트 발행·`brain.createPlan` 호출이 하나도 일어나지 않아야 한다.
- **REQ-004** [Ubiquitous] `CallService.create`는 회신 번호(`callbackNumber`)를 정규화해야 하며(**shall**), 정규화할 수 없거나 비어 있으면 `undefined`로 저장한다(현재 HTTP 핸들러의 동작을 그대로 옮김. 새 거절 규칙을 만들지 않음).
- **REQ-005** [Ubiquitous] 정규화·차단 판정은 `server/src/domain/`의 함수 하나로 묶여 있어야 하며(**shall**), 서비스는 그 함수의 결과를 `ServiceError`로 옮긴다. 같은 규칙이 두 곳에 따로 구현되지 않는다.
- **REQ-006** [Unwanted] `CallService.create`에는 정규화·차단 검사를 건너뛰는 인자나 경로가 있어서는 안 된다(**shall not**).

### 3.2 서비스 계층 강제 — 발신 직전

- **REQ-007** [Event-driven] **When** `approvePlan`이 호출되면, `CallService`는 작업을 `dialing`으로 바꾸기 전이자 `provider.start`를 부르기 전에 저장된 `phoneNumber`를 REQ-005의 같은 도메인 함수로 다시 판정해야 하며(**shall**), 차단이면 `ServiceError(400, "blocked_number", …)`, 형식 오류이면 `ServiceError(400, "invalid_phone", …)`를 던지고, 작업은 `awaiting_approval` 그대로 두며 `provider.start`는 호출되지 않는다. 이 재검사는 한도 검사(`assertWithinLimits`)보다 먼저 실행된다(SPEC-LIFECYCLE-001 REQ-001 (d)의 순서 503 → 404 → 409 → 400 → 429). 데이터 파일에서 적재된 작업이나 `create`를 거치지 않은 작업도 이 검사를 받는다.

### 3.3 HTTP 계층

- **REQ-008** [Unwanted] `server/src/http/app.ts`는 `normalizePhoneNumber`나 `isBlockedNumber`를 가져와서는 안 되고, 이 규칙을 위해 `ServiceError`를 직접 만들어서도 안 된다(**shall not**).
- **REQ-009** [Ubiquitous] `POST /v1/tasks`의 외부 동작은 다음과 같아야 한다(**shall**): (a) 유효한 입력은 201과 작업 객체(정규화된 `phoneNumber`), (b) 정규화 실패는 400 + `{"error":"invalid_phone"}`, (c) 차단 번호는 400 + `{"error":"blocked_number"}`, (d) 스키마 위반은 400 + `{"error":"invalid_request"}`. 오류 문구는 지금과 같다.

### 3.4 차단 규칙의 실효성 (OD-1 RESOLVED)

- **REQ-010** [Event-driven] **When** 입력 번호가 차단 목록의 단축 번호를 어떤 표기로든 가리키면, 도메인 판정은 형식 오류가 아니라 "차단"을 돌려줘야 한다(**shall**). 판정 대상 표기: 숫자만 쓴 단축 번호(`119`), 괄호·공백·하이픈이 섞인 단축 번호(`(119)`), 한국 국가 번호 표기(`+82 119`, `+82-182`, `0082-112`), 맨 앞 `0`을 붙인 표기(`0119`). 국가 번호 판정은 공백·하이픈·괄호·점만 지운 원문(맨 앞 `+` 유지)에 대해 한다. `+`로 시작하지만 `+82`가 아닌 번호는 차단 대상이 아니다.
- **REQ-011** [Ubiquitous] 차단 목록 자체(9개 번호)는 바뀌지 않아야 하고(**shall**), 일반 번호(예: `010-1234-5678`, `02 123 4567`, `+1 (415) 555-0100`)의 정규화 결과도 지금과 같다.

## 4. 비기능 제약

- 서비스 단위 테스트는 HTTP를 거치지 않고 `CallService`를 직접 만든다(가짜 brain, `InMemoryTaskStore`, 가짜 제공자).
- 기존 `server/src/http/app.test.ts`와 `server/src/domain/domain.test.ts`의 기존 테스트는 수정 없이 통과해야 한다.
- 오류 문구는 한 곳에서 정의한다(서비스 또는 도메인 상수).

## 5. Open Decisions

| ID | 결정 사항 | 상태 | 결정 내용 |
|----|-----------|------|-----------|
| OD-1 | 지금은 적용되지 않는 차단 규칙을 실제로 동작하게 할지 | **RESOLVED (owner, 2026-11-21)** | 실제로 동작하게 한다. `112`/`119`/`182` 등은 `blocked_number`(HTTP 400)로 거절한다. 상태 코드는 그대로이고 앱 코드는 바꾸지 않는다(앱은 서버 문구를 그대로 보여 줌 — `research.md` §5). |
| OD-2 | 추가 차단 정책(유료 정보 서비스 060 등, 해외 번호, 대표번호 1588 등, 시간대) | **DEFAULT (pending owner review)** | 추가하지 않는다. 이 SPEC 범위 밖으로 둔다. 추가하려면 차단 목록 또는 판정 함수에 규칙 하나와 그 AC를 더하는 별도 SPEC으로 한다. |

## 6. 제외 범위 (Out of Scope)

### Out of Scope — 새 차단 정책

- 유료 정보 서비스 번호, 해외 번호, 대표번호, 시간대 제한 등 새 차단 규칙은 추가하지 않는다(OD-2 DEFAULT).
- 차단 목록의 설정 파일화나 사용자별 허용·차단 목록은 다루지 않는다.
- 참고(범위 밖): 현재 정규화는 `1588-1234`를 `+15881234`(북미 번호 형태)로 바꾼다. `toKatPhoneNumber`가 `15881234`로 되돌리므로 지금은 무해하지만, 대표번호 정책을 정할 때 함께 볼 사항으로 기록한다(`research.md` §6).

### Out of Scope — 다른 입력 검증

- 회신 번호가 잘못되었을 때 요청을 거절하는 새 규칙은 만들지 않는다(지금처럼 조용히 버림).
- 목표·맥락 텍스트의 내용 검사(개인정보, 금지 요청 탐지)는 다루지 않는다.

### Out of Scope — 진입점 추가

- SDK·허브·내부 API 같은 새 진입점을 만들지 않는다. 이 SPEC은 그런 진입점이 생겨도 생성 시점과 발신 직전 검사를 건너뛰지 못하게 하는 것까지만 책임진다.

## 7. 추적성

| 요구사항 | 인수 기준 |
|----------|-----------|
| REQ-001 | AC-001 |
| REQ-002 | AC-002 |
| REQ-003 | AC-003 |
| REQ-004 | AC-004 |
| REQ-005 | AC-005 |
| REQ-006 | AC-005 |
| REQ-007 | AC-010 |
| REQ-008 | AC-006 |
| REQ-009 (a)(b)(c)(d) | AC-007 (a)(b)(c)(d) |
| REQ-010 | AC-008 |
| REQ-011 | AC-009 |
| 전체 회귀 | AC-011 |
