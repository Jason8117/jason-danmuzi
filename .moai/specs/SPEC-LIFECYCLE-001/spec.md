---
id: SPEC-LIFECYCLE-001
title: "실통화 종료·재기동 복구·제공자 호출 제한"
version: "0.3.1"
status: in-progress
created: 2026-11-20
updated: 2026-11-21
author: jason
priority: High
phase: "v0.2.0 target"
module: "server/src/services, server/src/providers/kat"
lifecycle: spec-anchored
tags: "lifecycle, shutdown, recovery, kat, timeout, real-call, tdd"
tier: M
depends_on: [SPEC-STORE-001]
related_specs: [SPEC-ARCH-001]
---

# SPEC-LIFECYCLE-001: 실통화 종료·재기동 복구·제공자 호출 제한

## HISTORY

| 버전 | 날짜 | 작성 | 변경 |
|------|------|------|------|
| 0.1.0 | 2026-11-20 | jason (manager-spec) | 최초 작성 (draft) |
| 0.2.0 | 2026-11-21 | jason (manager-spec) | plan-audit iteration 1 반영: 종료 순서 재설계(통화 종료를 `app.close()` 앞으로), 전체 마감 9 s와 단계별 예산, 두 번째 신호, 주인 없는 스트림 평가 순서, 단일 인스턴스 가정, 소유자 결정 반영 |
| 0.3.0 | 2026-11-21 | jason (manager-spec) | plan-audit iteration 2 반영: `timeLimit` 기대값 정정(5 → 35 등)과 하한 도달 불가 명시, 상한 근처 잔여 위험, 최종 저장 무응답 시 종료 동작, `approvePlan` 검사 순서 |
| 0.3.1 | 2026-11-21 | jason (manager-spec) | plan-audit iteration 3 반영(문구만): 상한 근처 경계를 "14,371 이상 여유 감소, 14,401 이상 KAT 선종료"로 정정, `approvePlan` 검사 순서에 404 `not_found` 위치 명시. REQ/AC 수와 기대값 불변 |

## 1. 배경과 목적

실통화(KAT Cloud + OpenAI Realtime)는 실제 사람에게 걸리고 비용이 든다. 그런데 서버의 수명 주기와 실통화의 수명 주기가 맞물려 있지 않다(근거: `research.md`).

1. 종료 신호(SIGINT/SIGTERM)를 받으면 `app.close()`와 저장만 하고 진행 중인 통화를 끊지 않는다(`server/src/index.ts:30-36`). 게다가 `app.close()`는 `@fastify/websocket`의 기본 `preClose`로 모든 WebSocket을 닫으므로(`node_modules/@fastify/websocket/index.js:245-254`) KAT 미디어 소켓이 먼저 끊기고, 브리지는 AI 소켓만 닫을 뿐 세션을 끝내지 않는다(`realtimeBridge.ts:274`). 상대방은 무음 통화 상태로 남는다.
2. 재기동 뒤 복구(`callService.ts:70-79`)는 중단된 작업을 `failed`로 표시만 한다. KAT 통화 ID는 메모리 맵(`katProvider.ts:61-62`)에만 있어 재기동 뒤에는 알 수 없고, 아직 살아 있는 실통화를 끊을 방법이 없다.
3. KAT API 호출(`katProvider.ts:302`)에 시간 제한이 없다. KAT가 응답하지 않으면 `approvePlan` 요청이 끝나지 않고, 작업은 `dialing`에 머물며 동시 통화 한도를 차지한다. 같은 저장소의 `openaiBrain.ts:80`은 `AbortSignal.timeout(30_000)`을 쓴다.
4. KAT에 보내는 `timeLimit`이 항상 900이다(`katProvider.ts:94`). `MAX_CALL_DURATION_SEC`를 무시한다.

목적은 서버가 어떻게 멈추거나 다시 뜨더라도 실통화가 주인 없이 남지 않게 하고, 외부 API가 멈춰도 작업이 빨리 실패 상태로 빠져나오게 하는 것이다.

## 2. 범위

- 종료 순서: `server/src/index.ts`, 새 종료 모듈, `CallService`의 종료 처리.
- 통화 ID 보존과 재기동 복구: `CallTask` 데이터 모델의 선택 필드 추가, `CallService.recoverInterruptedTasks`, 제공자 인터페이스.
- KAT 제공자의 API 시간 제한, `timeLimit` 계산, 주인 없는 미디어 스트림 처리.
- 앱(Flutter) 모델은 코드 변경 없이 새 필드를 무시해야 하며, 이를 테스트로 고정한다.

## 3. 요구사항 (GEARS)

### 3.1 종료 순서 (전체 마감 9 s)

종료 단계와 예산: (0) 새 작업 차단(즉시) → (1) 통화 종료 요청 3 s → (2) `app.close()` 1 s → (3) 최종 저장 5 s(SPEC-STORE-001 REQ-011) → 종료. 합계 9 s. 근거와 가정은 §4.

- **REQ-001** [Event-driven] **When** 서버가 첫 SIGINT 또는 SIGTERM을 받으면, `CallService`는 즉시 종료 중 상태가 되어야 하며(**shall**), 이 상태에서는 (a) 작업 생성과 (b) 계획 승인(`approvePlan`)을 `ServiceError(503, "shutting_down", "서버가 종료 중입니다. 잠시 후 다시 시도해 주세요.")`로 거절하고, (c) 진행 중 통화의 새 중간 승인 요청은 즉시 거절(`canceled`)로 끝낸다. (d) `approvePlan`의 검사 순서는 503 `shutting_down` → 404 `not_found` → 409 `invalid_state` → 400 번호 재검사(SPEC-POLICY-001 REQ-007) → 429 한도(`too_many_active_calls`/`daily_limit`)로 고정한다. 즉 종료 중에는 없는 작업 ID에도 503이 나온다.
- **REQ-002** [Event-driven] **When** 종료 중 상태가 되면, 서버는 `app.close()`를 호출하기 **전에** `dialing`/`ringing`/`in_progress` 상태인 모든 통화에 대해 제공자 종료를 요청해야 한다(**shall**). `app.close()`가 미디어 WebSocket을 닫기 때문이다.
- **REQ-003** [Ubiquitous] 통화 종료 단계는 3 s로 제한되어야 한다(**shall**). 3 s 안에 끝나지 않은 종료 요청이 있으면 해당 작업 ID 목록을 warn 수준으로 기록하고 다음 단계로 넘어간다.
- **REQ-004** [Event-driven] **When** 통화 종료 단계가 끝나면(완료 또는 3 s 경과), 그 단계에서 다룬 모든 작업은 요약 없이 `failed`로 저장되어야 하며(**shall**), 오류 문구는 "서버가 종료되어 통화를 끊었습니다."이고, 대화 기록과 승인 이력은 보존되며, 대기 중인 승인은 `expired`가 된다(OD-1 RESOLVED).
- **REQ-005** [Ubiquitous] `app.close()` 단계는 1 s로 제한되어야 한다(**shall**). 1 s 안에 끝나지 않으면 warn 수준으로 기록하고 최종 저장 단계로 넘어간다.
- **REQ-006** [Ubiquitous] 종료 처리 전체는 첫 신호부터 9 s 안에 끝나야 한다(**shall**): (a) 단계는 (0)→(1)→(2)→(3) 순서로 실행되고, (b) 모든 단계가 응답하지 않아도 프로세스는 첫 신호 뒤 9 s + 500 ms 이내에 종료되며 — 최종 저장 단계가 5 s 예산 안에 끝나지 않으면 종료 모듈이 그 단계를 실패로 간주해 `"Final store flush failed"` error 기록을 정확히 한 번 남기고 종료 코드 1로 끝낸다 — (c) 종료 코드는 최종 저장이 성공하면 0, 실패하면 1이다(SPEC-STORE-001 REQ-012의 실패 문구와 함께).
- **REQ-007** [Event-driven] **When** 종료 처리 중에 두 번째 SIGINT 또는 SIGTERM이 오면, 프로세스는 남은 단계를 기다리지 않고 즉시 종료 코드 1로 끝나야 한다(**shall**). 운영자가 강제로 끝낼 수 있게 하기 위함이다.

### 3.2 통화 ID 보존과 재기동 복구

- **REQ-008** [Event-driven] **When** 제공자가 외부 통화 ID를 받으면, `CallService`는 그 값을 작업의 선택 필드 `providerCallId`에 저장해야 한다(**shall**). 시뮬레이션 제공자는 이 값을 만들지 않는다.
- **REQ-009** [Event-driven] **When** 기동 시 복구가 `dialing`/`ringing`/`in_progress` 상태로 남은 작업을 찾고, 그 작업에 `providerCallId`가 있으며 작업의 `provider`가 현재 활성 제공자와 같으면, `CallService`는 (a) 작업을 `failed`로 표시하기 전에 제공자에게 그 통화의 종료를 요청해야 하고(**shall**), (b) 종료 요청이 실패하거나 끝나지 않아도 작업을 `failed`로 표시하고 warn 수준으로 기록하며, (c) 복구 전체를 10 s로 제한해 기동을 계속한다.
- **REQ-010** [Event-driven] **When** 복구 대상 작업에 (a) `providerCallId`가 없거나(이전 버전에서 저장된 작업 포함) (b) 작업의 `provider`가 현재 활성 제공자와 다르면, 복구는 종료를 요청하지 않고 작업을 `failed`로 표시하며 원인을 warn 수준으로 기록해야 한다(**shall**).
- **REQ-011** [Ubiquitous] `providerCallId`는 선택 필드여야 한다(**shall**). 이 필드가 없는 기존 `tasks.json`은 그대로 읽히고, 앱의 `CallTask.fromJson`은 필드가 있든 없든 같은 결과를 낸다.

### 3.3 KAT API 시간 제한

- **REQ-012** [Ubiquitous] KAT Cloud로 보내는 모든 HTTP 요청은 요청별 시간 제한(기본 10 s, 생성자 옵션으로 주입 가능)이 지나면 중단되어야 한다(**shall**).
- **REQ-013** [Event-driven] **When** 통화 생성 요청이 시간 제한을 넘기면, (a) `approvePlan`은 시간 제한 + 500 ms 이내에 반환되어야 하고(**shall**), (b) 작업은 `failed`가 되며 오류 문구에 "KAT Cloud가 응답하지 않아"가 포함되고, (c) 그 작업은 더 이상 동시 통화 한도에 세지지 않는다.
- **REQ-014** [Event-driven] **When** 통화 종료 요청이 시간 제한을 넘기거나 실패하면, 제공자는 warn 수준으로 기록하고 예외 없이 끝나야 한다(**shall**).

### 3.4 통화 시간 상한

- **REQ-015** [Ubiquitous] KAT에 보내는 `timeLimit`(초)은 `MAX_CALL_DURATION_SEC + 30`을 10 이상 14,400 이하로 제한한 값이어야 한다(**shall**). 추가 고정 상한은 두지 않는다(OD-3 DEFAULT). `MAX_CALL_DURATION_SEC`는 1 이상의 정수만 허용되므로(`server/src/config.ts:30`) 설정으로 만들 수 있는 최솟값은 31이고 하한 10에는 도달하지 않는다. 하한은 생성자에 직접 주입된 값에 대한 방어 코드로만 남기고 별도 단위 테스트로 검증한다.

### 3.5 주인 없는 실통화 방지

- **REQ-016** [Event-driven] **When** 업그레이드 서명이 유효한 미디어 스트림에 대응하는 활성 세션이 없으면, KAT 제공자는 그 통화 ID로 종료를 요청하고 소켓을 닫아야 한다(**shall**). 평가 시점과 순서는 다음과 같다. (a) 헤더 `x-kat-call-id`가 있으면, 첫 프레임이 도착했을 때 그 프레임을 해석·검증하기 **전에** 헤더 통화 ID로 활성 세션을 찾고, 없으면 종료한다. (b) 헤더 통화 ID가 있는데 10 s 안에 프레임이 하나도 오지 않으면, 시간 초과 시점에 같은 판정을 하고 없으면 종료한다. (c) 헤더 통화 ID가 없으면, 유효한 `start` 프레임의 통화 ID로 같은 판정을 한다. (d) 업그레이드 서명이 무효이면 종료를 요청하지 않고 소켓만 닫는다(위조 연결로 임의 통화를 끊지 못하게).

## 4. 비기능 제약

- **종료 유예 가정**: 배포 플랫폼은 SIGTERM 뒤 최소 10 s를 기다린 다음 강제 종료한다고 가정한다(흔한 기본값 중 가장 짧은 컨테이너 런타임의 `stop` 기본 10 s 기준). 전체 마감 9 s는 여기에 1 s 여유를 둔 값이다. 실제 배포 환경은 확인되지 않았다.
- **단일 인스턴스 가정**: 한 `DATA_FILE`은 한 서버 프로세스만 쓴다고 가정한다. REQ-009(기동 복구 종료)와 REQ-016(세션 없는 스트림 종료)은 이 가정에서만 안전하다. 같은 `DATA_FILE`을 쓰는 두 인스턴스(예: blue/green 배포)가 동시에 떠 있으면 새 인스턴스가 기존 인스턴스의 정상 통화를 끊는다.
- 테스트는 가짜 제공자, 주입한 `fetch`, 가짜 앱·가짜 저장소·가짜 `exit`, 가짜 타이머를 쓴다. 실제 KAT·OpenAI 네트워크 호출은 하지 않는다. 예외: KAT 요청 시간 제한 테스트(AC-010)는 실제 타이머와 짧은 시간 제한을 쓴다(인수 기준 참고).
- 새 환경 변수는 추가하지 않는다. 시간 제한·단계 예산·여유 값은 코드 상수로 두되 생성자·함수 옵션으로 주입할 수 있게 한다.
- 로그에는 전화번호 원문을 남기지 않는다(기존 `maskPhoneNumber` 관례 유지).
- 새 HTTP 응답은 종료 중에만 나오는 `503 shutting_down` 하나다. 그 밖의 엔드포인트 상태 코드와 응답 형식은 바뀌지 않는다. 응답 작업 객체에 `providerCallId` 필드가 추가된다(OD-2 DEFAULT).

## 5. Open Decisions

| ID | 결정 사항 | 상태 | 결정 내용 |
|----|-----------|------|-----------|
| OD-1 | 종료 신호를 받았을 때 진행 중 실통화 처리 | **RESOLVED (owner, 2026-11-21)** | 즉시 끊고 해당 작업을 요약 없이 `failed`로 기록한다. drain(새 통화만 막고 기존 통화가 끝날 때까지 기다리기) 모드는 두지 않는다. 운영 안내 "활성 통화가 없을 때만 배포·재시작"을 sync-phase 문서에 넣는다(plan.md §G). |
| OD-2 | `providerCallId`를 API·스트림 응답에 노출할지 | **DEFAULT (pending owner review)** | 작업 객체 그대로 노출한다(앱은 무시). 바꾸려면 HTTP·스트림 응답에서 필드를 빼는 변환과 AC 하나를 추가한다. |
| OD-3 | KAT `timeLimit`에 추가 고정 상한을 둘지 | **DEFAULT (pending owner review)** | 두지 않는다: `MAX_CALL_DURATION_SEC + 30`을 [10, 14,400]으로 제한한 값만 쓴다. 잔여 위험: 서버가 사라진 뒤 주인 없는 통화의 안전 상한이 설정을 따라 커지고(예: 3,600 → 3,630 s), KAT `timeLimit`이 생성 시점부터 세는지 응답 시점부터 세는지는 확인되지 않았다. 또 `MAX_CALL_DURATION_SEC`가 14,371 이상이면 여유가 30 s보다 줄어들고(14,371에서 `timeLimit`이 14,400에 닿고, 14,400에서 서버 타이머와 같아짐), 14,401 이상이면 KAT 상한(14,400 s)이 서버 자체 통화 시간 타이머보다 먼저 통화를 끊으므로 서버 타이머 경로(끊기 → 정상 요약)를 타지 않고 KAT 상태 웹훅 경로로 끝난다. KAT `timeLimit`의 기준 시점이 확인되지 않았으므로 이 경계는 근사값이다. 바꾸려면 REQ-015에 `min(…, 900)` 같은 상한을 넣고 AC-013 기대값을 고친다. |

## 6. 제외 범위 (Out of Scope)

### Out of Scope — 통화 유지·재개

- drain 모드(종료 시 기존 통화가 끝날 때까지 대기)는 두지 않는다(OD-1 RESOLVED).
- 재기동 뒤 끊긴 통화를 다시 걸거나 이어 가는 기능은 다루지 않는다.
- 통화 생성 요청 시간 초과 뒤 KAT 쪽에서 통화가 실제로 만들어졌는지 조회하는 기능은 다루지 않는다. REQ-016이 미디어 스트림 시점에 막는 것으로 대신한다.

### Out of Scope — 손상·읽기 불가 데이터 파일

- SPEC-STORE-001 OD-1(RESOLVED)에 따라 데이터 파일이 손상되었거나 읽을 수 없으면 기동이 실패한다. 이 경우 복구(REQ-009)가 실행되지 않으므로 그 파일 안의 작업은 복구되지 않고, 그 작업의 실통화도 서버가 끊을 수 없다. 잔여 위험으로 받아들인다.

### Out of Scope — 다중 인스턴스

- 같은 `DATA_FILE`을 쓰는 여러 인스턴스의 동시 운영(인스턴스별 소유권, 잠금)은 지원하지 않는다(§4 단일 인스턴스 가정).

### Out of Scope — 제공자 구조 변경

- HTTP 계층에서 KAT 전용 라우트를 분리하는 작업, 외부 입력 zod 검증, 제공자 식별자 타입 확장은 SPEC-ARCH-001이 다룬다.

### Out of Scope — 설정 확장

- 시간 제한·종료 예산을 환경 변수로 노출하는 작업, `MAX_CALL_DURATION_SEC` 기본값(600) 변경은 하지 않는다.

## 7. 추적성

| 요구사항 | 인수 기준 |
|----------|-----------|
| REQ-001 (a)(b)(c)(d) | AC-001 (a)(b)(c)(d), AC-015 |
| REQ-002 | AC-002 |
| REQ-003 | AC-003 |
| REQ-004 | AC-004, AC-015 |
| REQ-005 | AC-002 |
| REQ-006 (a)(b)(c) | AC-005 (a)(b)(c)(e), AC-015 |
| REQ-007 | AC-005 (d) |
| REQ-008 | AC-006 |
| REQ-009 (a)(b)(c) | AC-007 (a)(b)(c) |
| REQ-010 (a)(b) | AC-008 (a)(b) |
| REQ-011 | AC-009 |
| REQ-012 | AC-010 |
| REQ-013 (a)(b)(c) | AC-011 (a)(b)(c) |
| REQ-014 | AC-012 |
| REQ-015 | AC-013 (a)(b) |
| REQ-016 (a)(b)(c)(d) | AC-014 (a)(b)(c)(d) |
| 전체 회귀 | AC-016 |
