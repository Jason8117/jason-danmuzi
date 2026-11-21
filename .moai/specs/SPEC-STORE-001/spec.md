---
id: SPEC-STORE-001
title: "작업 저장소 내구성 — 쓰기 실패 격리, 제한된 재시도, 종료 시 저장 결과 보고"
version: "0.2.0"
status: implemented
created: 2026-11-20
updated: 2026-11-21
author: jason
priority: High
phase: "v0.2.0 target"
module: "server/src/store"
lifecycle: spec-anchored
tags: "persistence, durability, store, fault-tolerance, tdd"
tier: M
related_specs: [SPEC-LIFECYCLE-001]
---

# SPEC-STORE-001: 작업 저장소 내구성

## HISTORY

| 버전 | 날짜 | 작성 | 변경 |
|------|------|------|------|
| 0.1.0 | 2026-11-20 | jason (manager-spec) | 최초 작성 (draft) |
| 0.2.0 | 2026-11-21 | jason (manager-spec) | plan-audit iteration 1 반영: 손상 파일 격리 제거(소유자 결정), 다중 동작 REQ 분리, 최종 저장 실패 문구 고정, 종료 마감 산술을 SPEC-LIFECYCLE-001과 일치 |

## 1. 배경과 목적

`JsonFileTaskStore`(`server/src/store/taskStore.ts`)는 모든 통화 작업을 메모리에 두고 300 ms 디바운스로 JSON 파일에 저장한다. 현재 구조의 결함은 두 가지다(근거: `research.md`).

1. 쓰기 체인(`this.writing`)이 한 번 거부되면 그 Promise가 거부 상태로 남아 이후 모든 `flush()`가 실패한다(`taskStore.ts:73-79`).
2. 디바운스 타이머가 `void this.flush()`로 호출되어 거부가 처리되지 않은 채 남고(`taskStore.ts:84`), 프로세스가 종료된다. 데이터 디렉터리를 `chmod 555`로 바꾼 뒤 `POST /v1/tasks`가 201을 반환하고 약 300 ms 뒤 프로세스가 `EACCES`로 죽었으며, 이후 `/health`가 응답하지 않았다(오케스트레이터와 plan-auditor가 각각 관찰).

이 SPEC의 목적은 저장 실패가 서버 가용성을 무너뜨리지 않게 하고, 실패가 지나간 뒤에는 현재 상태 전체가 반드시 디스크에 반영되게 하며, 종료 시 최종 저장이 결과를 알리고 멈추지 않게 하는 것이다.

## 2. 범위

- 대상: `server/src/store/taskStore.ts`의 `JsonFileTaskStore`, 그리고 저장소를 여닫는 `server/src/index.ts`의 종료 경로(최종 저장 결과 → 종료 코드).
- `TaskStore` 인터페이스(`list/get/save/delete/flush`)의 호출 측 의미는 유지한다. `CallService`와 HTTP 계층은 바꾸지 않는다.
- 파일 형식(작업 배열 JSON, 2칸 들여쓰기)과 원자적 쓰기 방식(임시 파일 작성 후 rename)은 유지한다.
- 기동 시 데이터 파일 처리는 지금 동작을 그대로 유지한다(손상·읽기 불가 시 기동 실패). 이를 바꾸지 않는다는 것을 보호 테스트로 고정한다.

## 3. 요구사항 (GEARS)

### 3.1 쓰기 실패 격리

- **REQ-001** [Unwanted] `JsonFileTaskStore`는 디스크 쓰기 실패 때문에 프로세스가 종료되게 해서는 안 된다(**shall not**). 디바운스 타이머나 재시도 타이머가 시작한 저장에서 생긴 실패도 처리되지 않은 Promise 거부로 남기지 않는다.
- **REQ-002** [Unwanted] 한 번의 쓰기 실패가 이후 쓰기 시도를 그 자체로 실패시켜서는 안 된다(**shall not**). 이전 시도의 거부 상태가 다음 시도에 전파되지 않으며, 쓰기는 계속 하나씩 직렬로 실행된다.
- **REQ-003** [Ubiquitous] 쓰기 실패 중에도 `JsonFileTaskStore`는 메모리에 있는 작업에 대한 `list/get/save/delete`를 정상적으로 제공해야 한다(**shall**).

### 3.2 재시도와 복구

- **REQ-004** [Event-driven] **When** 쓰기가 실패하면, `JsonFileTaskStore`는 메시지 `"Store write failed"`, 파일 경로, 오류 코드, 연속 실패 횟수를 담아 error 수준으로 한 번 기록해야 한다(**shall**).
- **REQ-005** [Event-driven] **When** 쓰기가 실패하면, `JsonFileTaskStore`는 다음 시도를 예약해야 하며(**shall**), 지연은 초기값(기본 1 s)에서 시작해 실패할 때마다 두 배가 되고 상한(기본 30 s)을 넘지 않는다. 저장되지 않은 변경이 있는 동안 재시도 횟수에는 상한을 두지 않는다.
- **REQ-006** [State-driven] **While** 재시도가 예약되어 있는 동안, 추가 `save/delete` 호출은 별도의 타이머나 병렬 쓰기를 만들지 않고 예약된 다음 시도에 합쳐져야 한다(**shall**).
- **REQ-007** [Event-driven] **When** 실패 뒤의 쓰기가 성공하면, 파일에는 그 쓰기 시점의 메모리 상태 전체가 담겨야 한다(**shall**)(실패한 시도의 오래된 스냅숏이 아님).
- **REQ-008** [Event-driven] **When** 실패 뒤의 쓰기가 성공하면, `JsonFileTaskStore`는 메시지 `"Store write recovered"`로 info 수준 기록을 정확히 한 번 남기고 다음 실패의 지연을 초기값으로 되돌려야 한다(**shall**).
- **REQ-009** [Ubiquitous] 쓰기가 실패해도 기존 데이터 파일은 직전 성공 시점의 내용 그대로 남아야 한다(**shall**).

### 3.3 종료 시 최종 저장

- **REQ-010** [Event-driven] **When** 종료 경로가 최종 저장을 요청하면, `JsonFileTaskStore`는 예약된 디바운스·재시도 타이머를 모두 취소해야 한다(**shall**).
- **REQ-011** [Event-driven] **When** 종료 경로가 최종 저장을 요청하면, `JsonFileTaskStore`는 마감 시간(기본 5 s) 안에서 마지막 쓰기를 한 번 시도하고, 거부하지 않고 성공/실패(시간 초과 포함) 결과를 돌려줘야 한다(**shall**). 이 5 s는 SPEC-LIFECYCLE-001이 정하는 전체 종료 마감 9 s의 마지막 단계 예산이다.
- **REQ-012** [Event-driven] **When** 최종 저장 결과가 실패이면, 서버 프로세스는 메시지 `"Final store flush failed"`로 error 수준 기록을 정확히 한 번 남기고 종료 코드 1로 끝나야 한다(**shall**). 성공이면 종료 코드 0이다. 이 메시지 문자열은 코드 상수로 한 곳에서 정의하며, 로거가 JSON 한 줄의 `"msg"` 필드로 출력하므로 `grep -c '"msg":"Final store flush failed"'`로 셀 수 있다.

### 3.4 기동 동작 유지

- **REQ-013** [Event-driven] **When** 기동 시 데이터 파일을 읽을 수 없거나(`ENOENT`가 아닌 입출력 오류) JSON으로 해석할 수 없으면, `JsonFileTaskStore.open`은 지금처럼 오류로 거부해 기동을 실패시켜야 하며(**shall**), 데이터 파일을 수정·이동·삭제하지 않는다.
- **REQ-014** [Ubiquitous] 정상 데이터 파일과 `version` 필드가 없는 예전 작업 항목은 지금과 똑같이 읽혀야 하고(`version ?? 0` 보정), 파일이 없으면 빈 저장소로 열려야 한다(**shall**).

## 4. 비기능 제약

- 재시도 지연의 초기값·배수·상한, 최종 저장 마감 시간은 테스트에서 주입할 수 있어야 한다.
- 테스트는 실제 디스크 고장 대신 주입한 파일 시스템 계층 또는 임시 디렉터리를 쓴다. 네트워크는 쓰지 않는다.
- 로그에는 작업 내용(전화번호, 대화 내용)을 남기지 않는다. 메시지, 경로, 오류 코드, 횟수만 남긴다.
- 한 데이터 파일은 한 서버 프로세스만 쓴다고 가정한다(여러 인스턴스가 같은 `DATA_FILE`을 공유하는 배포는 지원하지 않음).

## 5. Open Decisions

| ID | 결정 사항 | 상태 | 결정 내용 |
|----|-----------|------|-----------|
| OD-1 | 손상된 데이터 파일을 만났을 때의 기동 정책 | **RESOLVED (owner, 2026-11-21)** | 이 SPEC에서 손상 파일 격리를 하지 않는다. 지금 동작(읽을 수 없거나 손상된 파일이면 기동이 큰 소리로 실패)을 유지한다(REQ-013). |
| OD-2 | 저장 실패 상태를 `/health`에 노출할지 | **DEFAULT (pending owner review)** | 노출하지 않는다. 이번에는 로그만 남긴다. 바꾸려면 `/health` 응답에 필드를 더하는 REQ 하나와 AC 하나를 추가하면 된다. |

## 6. 제외 범위 (Out of Scope)

### Out of Scope — 손상 데이터 파일 복구

- 손상되었거나 읽을 수 없는 데이터 파일의 격리·백업·빈 저장소 기동은 하지 않는다(OD-1 RESOLVED). 그런 파일이 있으면 기동은 지금처럼 실패한다.
- 잔여 위험: 그 파일 안에 있던 진행 중 작업은 복구할 수 없고, SPEC-LIFECYCLE-001의 재기동 복구도 실행되지 않으므로 그 작업의 실통화를 서버가 끊을 수 없다. 운영자가 파일을 고치거나 치운 뒤 다시 기동해야 한다.

### Out of Scope — 저장 방식 교체

- SQLite 등 다른 저장소로의 이전, 작업 단위 증분 저장, 저널링은 다루지 않는다.
- 여러 프로세스가 같은 데이터 파일을 공유하는 상황(파일 잠금)은 다루지 않는다.

### Out of Scope — 상태 노출과 알림

- `/health` 응답 변경, 앱 화면 경고, 외부 알림은 다루지 않는다(OD-2 DEFAULT).

### Out of Scope — 종료 순서 전체

- 종료 신호를 받았을 때 통화 종료 → HTTP 종료 → 최종 저장 순서와 전체 마감 9 s는 SPEC-LIFECYCLE-001이 다룬다. 이 SPEC은 최종 저장 단계(5 s 예산, 결과 보고, 종료 코드, 실패 문구)까지만 책임진다.

## 7. 추적성

| 요구사항 | 인수 기준 |
|----------|-----------|
| REQ-001 | AC-001, AC-002, AC-013 |
| REQ-002 | AC-003 |
| REQ-003 | AC-004 |
| REQ-004 | AC-005 |
| REQ-005 | AC-006 |
| REQ-006 | AC-007 |
| REQ-007 | AC-008 |
| REQ-008 | AC-009 |
| REQ-009 | AC-010 |
| REQ-010 | AC-011 |
| REQ-011 | AC-012 |
| REQ-012 | AC-013 |
| REQ-013 | AC-014 |
| REQ-014 | AC-014 |
| 전체 회귀 | AC-015 |
