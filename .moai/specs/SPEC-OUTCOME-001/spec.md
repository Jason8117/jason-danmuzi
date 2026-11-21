---
id: SPEC-OUTCOME-001
title: "LLM 미사용·실패 시 통화 결과를 정직하게 보고"
version: "0.3.0"
status: implemented
created: 2026-11-20
updated: 2026-11-21
author: jason
priority: High
phase: "v0.2.0 target"
module: "server/src/brain, app/lib/features/calls"
lifecycle: spec-anchored
tags: "outcome, honesty, llm-fallback, heuristic, flutter, tdd"
tier: M
depends_on: [SPEC-POLICY-001]
related_specs: [SPEC-ARCH-001]
---

# SPEC-OUTCOME-001: LLM 미사용·실패 시 통화 결과를 정직하게 보고

## HISTORY

| 버전 | 날짜 | 작성 | 변경 |
|------|------|------|------|
| 0.1.0 | 2026-11-20 | jason (manager-spec) | 최초 작성 (draft) |
| 0.2.0 | 2026-11-21 | jason (manager-spec) | plan-audit iteration 1 반영: OD-1 소유자 결정 반영, REQ-009 금지 범위를 로그·실패 메타데이터로 좁힘, 같은 릴리스 배포 명시, `depends_on` 추가 |
| 0.3.0 | 2026-11-21 | jason (manager-spec) | plan-audit iteration 2 반영: 업데이트하지 않은 앱의 비관적 표시를 소유자 수용 잔여 위험으로 명시 |

## 1. 배경과 목적

이 제품의 목적은 실제 용무(예약, 문의)를 끝내 주는 것이다. 그러므로 가장 나쁜 실패는 "통화는 했지만 목표를 이뤘는지 모르는데 성공이라고 알려 주는 것"이다. 지금 그런 일이 일어난다(근거: `research.md`).

- `OpenAiBrain`은 LLM 호출이 어떤 이유로든 실패하면 조용히 `HeuristicBrain`으로 넘어간다(`server/src/brain/openaiBrain.ts:87-89`). warn 로그는 남지만 결과에는 흔적이 없다.
- `HeuristicBrain.summarize`는 상대가 한 마디라도 했으면 거절된 승인이 없는 한 `result: "success"`를 돌려주고, 요약에 "요청한 내용을 확인했습니다."라고 쓴다(`server/src/brain/heuristicBrain.ts:53-56`). 목표를 이뤘다는 근거는 전혀 보지 않는다.
- 오케스트레이터가 시뮬레이션 모드(API 키 없음 → `HeuristicBrain`)에서 `outcome.result: "success"`가 나오는 것을 관찰했다. 기존 통합 테스트도 이 값을 기대한다(`server/src/http/app.test.ts:95`).
- 앱은 `success`를 "목표 달성"으로 초록 체크 아이콘과 함께 보여 준다(`app/lib/features/calls/domain/call_models.dart:51-58`, `presentation/widgets/outcome_card.dart:25-41`).

목적은 LLM 검증 없이 만든 결과가 성공을 주장하지 못하게 하고, 결과가 어떻게 만들어졌는지(출처)를 결과 자체에 담아 앱이 이를 구분해 보여 주게 하는 것이다. 이미 저장된 작업도 계속 읽혀야 한다.

## 2. 범위

- 서버: `CallOutcome` 도메인 타입, `HeuristicBrain.summarize`, `OpenAiBrain`의 대체 경로와 로그.
- 앱: `CallOutcome`·`OutcomeResult` 모델 파싱, `OutcomeCard` 표시.
- 계획 생성(`createPlan`)의 대체 경로는 로그만 보강하고 계획 결과는 바꾸지 않는다.
- 배포: 서버와 앱 변경은 같은 릴리스로 내보낸다(OD-1 RESOLVED). 서버만 먼저 나가면 이미 설치된 앱이 `"unverified"`를 "달성 못 함"으로 보여 주기 때문이다(`call_models.dart:145`).
- 잔여 위험(소유자 수용, OD-1 RESOLVED에 포함): 같은 릴리스로 내보내도, 사용자가 앱을 업데이트하기 전까지는 기존 앱이 `"unverified"`를 계속 실패 상태("달성 못 함", 오류 아이콘)로 보여 준다. 서버는 앱 버전을 구분하지 않으므로 이 기간을 줄일 수단이 이 SPEC에는 없다. 거짓 성공보다 비관적 표시가 안전하다는 판단으로 소유자가 OD-1을 택하면서 함께 받아들인 위험이다.

## 3. 요구사항 (GEARS)

### 3.1 결과의 출처와 성공 주장 제한 (서버)

- **REQ-001** [Ubiquitous] 서버가 새로 만드는 모든 `CallOutcome`은 출처 필드 `source`(`"llm"` 또는 `"heuristic"`)를 가져야 한다(**shall**).
- **REQ-002** [Unwanted] 출처가 `heuristic`인 결과는 `result: "success"`를 가져서는 안 된다(**shall not**).
- **REQ-003** [Event-driven] **When** `HeuristicBrain`이 상대가 말한 기록이 있는 통화를 요약하면, 결과의 `result`는 `"unverified"`여야 한다(**shall**). 거절·만료된 승인은 지금처럼 `followUps`에 "미승인 항목 재검토: …"로 남는다.
- **REQ-004** [Event-driven] **When** `HeuristicBrain`이 상대가 말한 기록이 없는 통화를 요약하면, 결과는 지금처럼 `result: "failed"`여야 한다(**shall**). 연결되지 않았다는 사실은 기록으로 확인되므로 검증된 실패로 본다. `source`는 `heuristic`.
- **REQ-005** [Ubiquitous] `HeuristicBrain`의 요약 문구는 검증되지 않은 자동 요약임을 맨 앞에서 밝혀야 하며(**shall**), "요청한 내용을 확인했습니다." / "The request was handled." 같은 달성 주장을 담지 않는다. 접두어는 ko "자동 요약(검증되지 않음):", en "Automatic summary (unverified):"다(OD-2 DEFAULT).

### 3.2 LLM 대체 경로의 가시성 (서버)

- **REQ-006** [Event-driven] **When** 요약용 LLM 호출이 실패하면(네트워크 오류, 2xx가 아닌 응답, 빈 내용, JSON 해석 실패, 스키마 불일치, 시간 초과), `OpenAiBrain`은 작업(`op: "summarize"`), 실패 원인 분류(`reason`), 작업 ID를 담아 warn 수준으로 한 번 기록하고, `source: "heuristic"`인 결과를 돌려줘야 한다(**shall**). 따라서 REQ-002가 그대로 적용된다.
- **REQ-007** [Event-driven] **When** 요약용 LLM 호출이 성공하고 응답이 스키마를 통과하면, 결과는 LLM이 정한 `result`(`success`/`partial`/`failed`)와 `source: "llm"`을 가져야 한다(**shall**).
- **REQ-008** [Event-driven] **When** 계획용 LLM 호출이 실패하면, `OpenAiBrain`은 `op: "plan"`과 실패 원인 분류를 담아 warn 수준으로 기록해야 한다(**shall**). 계획 내용과 작업 상태 흐름은 지금과 같다.
- **REQ-009** [Unwanted] 대체 경로의 **실패 로그와 실패 원인 메타데이터**에는 OpenAI 응답 본문, API 키, 대화 내용, 그리고 `JSON.parse`·zod 오류 메시지 원문(입력 일부를 담을 수 있음)을 넣어서는 안 된다(**shall not**). 허용되는 것은 원인 분류(`timeout`, `http_status`, `invalid_json`, `schema_mismatch`, `empty_content`, `network`), HTTP 상태 코드, `op`, 작업 ID뿐이다. 결과 객체의 `summary`와 `keyFacts`는 이 금지 대상이 아니며 지금처럼 대화 내용을 담을 수 있다.

### 3.3 타입 일관성 (서버·앱)

- **REQ-010** [Ubiquitous] 도메인 타입 `OutcomeResult`는 `success`/`partial`/`failed`/`unverified` 네 값을 가져야 하고(**shall**), LLM 응답 검증 스키마(`openaiBrain.ts`의 `OutcomeSchema`)는 LLM이 낼 수 있는 세 값(`success`/`partial`/`failed`)만 받는다. `source`는 서버가 붙이며 LLM에게 요구하지 않는다. 이 관계를 테스트로 고정한다.

### 3.4 앱 표시와 하위 호환

- **REQ-011** [Ubiquitous] 앱의 `CallOutcome.fromJson`은 `result: "unverified"`와 `source` 필드를 해석해야 하며(**shall**), `source`가 없거나 모르는 값이면 "알 수 없음"으로 둔다. `source`와 새 값이 없는 예전 작업 JSON은 지금과 같은 결과로 파싱된다.
- **REQ-012** [State-driven] **While** 결과의 `result`가 `unverified`이면, `OutcomeCard`는 성공 표시(초록 체크, "목표 달성")와 구분되는 아이콘·색·라벨 "결과 미확인"으로 보여 주고, 안내 문구 "자동 요약이라 목표를 이뤘는지 확인하지 못했어요. 대화 기록을 직접 확인해 주세요."를 함께 보여 줘야 한다(**shall**)(문구는 OD-2 DEFAULT).
- **REQ-013** [Unwanted] 서버는 이미 저장된 작업의 결과를 다시 쓰거나 일괄 변환해서는 안 된다(**shall not**). 예전 결과는 `source` 없이 그대로 남는다.

## 4. 비기능 제약

- 서버 테스트는 실제 OpenAI 호출 없이 전역 `fetch`를 대체하거나(`vi.stubGlobal`) 주입해 실패·성공 응답을 흉내 낸다.
- 앱 위젯 테스트는 실제 서버 없이 `taskJson()` 생성기(`app/test/support/fakes.dart:8-43`)로 만든 작업을 쓴다.
- 앱 라벨 "확인 필요"는 이미 작업 상태 `awaitingApproval`의 라벨이므로(`call_models.dart:16`) 결과 라벨로 쓰지 않는다.
- 서버와 앱은 같은 릴리스로 배포한다(§2).

## 5. Open Decisions

| ID | 결정 사항 | 상태 | 결정 내용 |
|----|-----------|------|-----------|
| OD-1 | 검증되지 않은 결과의 표현 방식 | **RESOLVED (owner, 2026-11-21)** | `result`에 새 값 `"unverified"`를 추가하고 `source: "llm" \| "heuristic"` 필드를 둔다. 서버와 앱을 같은 릴리스로 내보낸다. |
| OD-2 | 사용자에게 보이는 문구 | **DEFAULT (pending owner review)** | 라벨 "결과 미확인", 안내 "자동 요약이라 목표를 이뤘는지 확인하지 못했어요. 대화 기록을 직접 확인해 주세요.", 요약 접두어 ko "자동 요약(검증되지 않음):", en "Automatic summary (unverified):". 바꾸려면 문구 상수와 AC-004·AC-010의 기대 문자열만 고친다. |
| OD-3 | LLM 실패 원인을 결과에 노출할지 | **DEFAULT (pending owner review)** | 노출하지 않는다(로그에만 남김). 바꾸려면 `CallOutcome`에 선택 필드 하나와 그 AC를 추가한다. |

## 6. 제외 범위 (Out of Scope)

### Out of Scope — 요약 품질

- LLM 프롬프트(`SUMMARY_SYSTEM_PROMPT`) 개선, LLM이 낸 `success` 판정의 정확도 검증은 다루지 않는다.
- 휴리스틱으로 목표 달성 여부를 추론하는 새 규칙(키워드 매칭 등)은 만들지 않는다.

### Out of Scope — 과거 데이터

- 이미 저장된 작업의 결과 재분류·마이그레이션은 하지 않는다(REQ-013).

### Out of Scope — 계획 단계

- 계획 생성 대체 경로의 결과를 앱에 표시하는 기능은 다루지 않는다(로그만 보강, REQ-008).
- 계획 경로 테스트 전체(스키마 경계)는 SPEC-ARCH-001이 이어서 다룬다. 이 SPEC은 요약 경로와 계획 실패 로그까지만 만든다.

## 7. 추적성

| 요구사항 | 인수 기준 |
|----------|-----------|
| REQ-001 | AC-001, AC-005 |
| REQ-002 | AC-002 |
| REQ-003 | AC-002 |
| REQ-004 | AC-003 |
| REQ-005 | AC-004 |
| REQ-006 | AC-005 |
| REQ-007 | AC-006 |
| REQ-008 | AC-007 |
| REQ-009 | AC-005, AC-007 |
| REQ-010 | AC-008 |
| REQ-011 | AC-009 |
| REQ-012 | AC-010 |
| REQ-013 | AC-009 |
| 전체 회귀 | AC-011, AC-012 |
