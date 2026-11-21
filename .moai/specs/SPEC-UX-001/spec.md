---
id: SPEC-UX-001
title: "친근하고 정돈된 비서 화면 — 디자인 토큰, 공용 카드, 쉬운 상태 문구, 접근성"
version: "0.1.0"
status: draft
created: 2026-11-21
updated: 2026-11-21
author: jason
priority: Medium
phase: "v0.3.0 target"
module: "app/lib/core/theme, app/lib/core/widgets, app/lib/features/calls, app/lib/features/settings"
lifecycle: spec-anchored
tags: "design-system, theme, tokens, accessibility, contrast, tap-target, text-scaling, motion, flutter, assistant-ux"
tier: M
depends_on: [SPEC-FOLLOWUP-001]
related_specs: [SPEC-APPROVAL-001, SPEC-INTAKE-001, SPEC-OUTCOME-001]
---

# SPEC-UX-001: 친근하고 정돈된 비서 화면 — 디자인 토큰, 공용 카드, 쉬운 상태 문구, 접근성

## HISTORY

| 버전 | 날짜 | 작성 | 변경 |
|------|------|------|------|
| 0.1.0 | 2026-11-21 | jason (manager-spec) | 최초 작성 (draft). 에픽 EPIC-ASSISTANT-UX의 마지막 SPEC |

## 1. 배경과 목적

앱의 시각 규칙은 파일마다 흩어져 있다(근거: `research.md` §1). 테마(`app/lib/core/theme/app_theme.dart`)는 씨앗 색 하나와 카드·입력칸·버튼 모양만 정하고, 간격·둥근 정도·글자 크기는 화면마다 숫자로 적혀 있다(예: `EdgeInsets.all(18)`, `BorderRadius.circular(20)`, `fontSize: 12`). 상태 색 `warning`(`0xFFD97706`)은 밝은 배경 위 글자로 쓰이는데, 계산상 흰 배경 대비가 약 3.2:1로 WCAG AA 본문 기준(4.5:1)에 못 미친다(`research.md` §2, 수식 계산이며 도구 측정 아님). 큰 글자 설정에서 화면 아래 고정된 승인 카드가 넘칠 수 있고, 움직임 줄이기 설정을 따르지 않는다. 접근성을 확인하는 테스트는 없다.

앞의 세 SPEC(승인 코멘트, 한 줄 부탁·계획 카드, 통화 후 행동)은 기능을 기존 테마와 공용 위젯으로 만든다. 이 SPEC은 그 완성된 화면들 위에서 디자인 시스템을 한 번에 적용한다: 친근하고 정돈된 테마(색·글자·간격·모양), 움직임과 피드백, 빈 상태, 쉬운 한국어 상태 문구, 접근성(대비, 누르는 영역, 글자 크기), 계획 카드·승인 카드·결과 카드가 같은 구조로 보이게 하는 공용 카드. 화면 배치는 `design.md`.

순서(이 SPEC을 마지막에 두는 이유)는 `plan.md` §A.0과 에픽 개요 §2에 적는다.

## 2. 범위

- 앱만. 서버, 저장소(`calls_repository.dart`), API 클라이언트, 경로, 상태 관리는 바꾸지 않는다.
- 대상 화면: 홈, 계획 카드, 통화 상세(진행 중·승인 카드 포함), 결과(끝난 통화 상세), 설정.
- 대상 파일 목록과 각 파일의 변경 범위: `plan.md` §B.

## 3. 요구사항 (GEARS)

### 3.1 디자인 토큰과 테마

- **REQ-001** [Ubiquitous] 앱은 디자인 토큰을 한 파일(`app/lib/core/theme/tokens.dart`, 새 파일)에 정의해야 하며(**shall**), 대상 파일(`plan.md` §B 목록)의 간격(`EdgeInsets`), 둥근 정도(`BorderRadius.circular`), 움직임 시간(`Duration(milliseconds: …)`)은 숫자를 직접 쓰지 않고 이 토큰을 쓴다. 토큰 값: 간격 4·8·12·16·20·24·32, 둥근 정도 12·16·20·999(알약), 움직임 150·250·400 ms, 최소 누르는 영역 48.
- **REQ-002** [Ubiquitous] 테마는 밝은·어두운 모드 각각에서 상태 색(진행 중 통화, 주의, 긍정, 경고, 위험)을 배경 색과 글자 색 짝으로 제공해야 하며(**shall**), 각 짝의 대비는 글자 4.5:1 이상, 아이콘·테두리 3:1 이상이다(WCAG 2.1 상대 휘도 공식). 씨앗 색은 지금 값(`0xFF1F8A70`)을 유지한다(OD-2 DEFAULT).
- **REQ-003** [Ubiquitous] 테마의 글자 단계는 다음이어야 한다(**shall**)(글꼴은 시스템 기본, OD-4 DEFAULT): `titleLarge` 22/굵기 700, `titleMedium` 18/700, `titleSmall` 16/700, `bodyLarge` 16/줄 높이 1.5, `bodyMedium` 15/1.5, `bodySmall` 13/1.45, `labelLarge` 15/600, `labelSmall` 12/600.

### 3.2 공용 카드와 상태 문구

- **REQ-004** [Ubiquitous] 앱은 공용 카드 위젯 하나(머리줄: 아이콘·제목·오른쪽 요소, 본문, 선택적 행동 줄, 분위기 `neutral`/`attention`/`positive`/`caution`/`critical`)를 제공해야 하며(**shall**), 계획 카드, 승인 카드(`attention`), 결과 카드(`success` → `positive`, `partial` → `caution`, `unverified` → `neutral`, `failed`·결과 없음 → `critical`, 취소 → `neutral`), 기존 `SectionCard` 사용처가 모두 이 위젯으로 그려진다(`SectionCard`는 같은 인자를 받는 얇은 감싸개로 남겨 호출부를 바꾸지 않아도 됨).
- **REQ-005** [Ubiquitous] 작업 상태 라벨은 한 곳(`TaskStatus`의 라벨)에서 다음 쉬운 한국어로 정해져야 한다(**shall**)(OD-3 DEFAULT): `planning` "계획 세우는 중", `awaitingApproval` "확인 필요", `dialing` "전화 거는 중", `ringing` "신호 가는 중", `inProgress` "통화 중", `summarizing` "결과 정리 중", `completed` "완료", `failed` "실패", `canceled` "취소됨". 통화 중 승인을 기다릴 때의 상태 칩 문구 "승인 대기"와 결과 라벨(SPEC-OUTCOME-001 OD-2)은 바꾸지 않는다.

### 3.3 움직임·피드백·빈 상태

- **REQ-006** [State-driven] **While** 기기의 움직임 줄이기 설정(`MediaQuery.disableAnimations`)이 켜져 있으면, 앱의 모든 토큰 기반 움직임 시간은 0이어야 하고(**shall**) 진행 중 표시 점(`PulsingDot`)은 깜박이지 않는다. 꺼져 있으면 상태 칩 바뀜, 승인 카드 나타남, 계획 카드 행 펼침은 토큰 시간(250 ms)으로 움직인다.
- **REQ-007** [Event-driven] **When** 사용자가 비동기 작업 버튼([이대로 시작], 승인·거절, 다시 걸기를 제외한 후속 행동, 이대로 전화 걸기, 연결 테스트)을 누르면, 그 버튼은 끝날 때까지 진행 표시와 함께 비활성이어야 하고(**shall**), [이대로 시작]과 승인·거절이 성공하면 가벼운 진동(`HapticFeedback.lightImpact`)을 한 번 낸다. 승인 요청이 도착할 때의 강한 진동(현행 `approval_card.dart:36`)은 유지한다.
- **REQ-008** [Ubiquitous] 빈 상태(작업 없음, 대화 기록 없음, 서버 연결 실패, 통화를 찾을 수 없음)는 같은 빈 상태 위젯(아이콘, 제목 한 줄, 설명, 행동 최대 2개 — 기존 `MessageView`를 이 역할로 정리)으로 보여야 하며(**shall**), 제목·설명은 지금 문구를 유지하되 제목이 없던 "대화 기록 없음"에만 제목 "대화를 기다리고 있어요"를 더한다(`design.md` §5 표).

### 3.4 접근성

- **REQ-009** [Ubiquitous] 홈, 계획 카드, 승인 카드가 있는 통화 상세, 결과 화면의 모든 누를 수 있는 요소는 Flutter 접근성 지침 `androidTapTargetGuideline`(48×48), `iOSTapTargetGuideline`(44×44), `labeledTapTargetGuideline`을 통과해야 한다(**shall**).
- **REQ-010** [Ubiquitous] 같은 네 화면은 밝은·어두운 모드 각각에서 `textContrastGuideline`을 통과해야 한다(**shall**).
- **REQ-011** [State-driven] **While** 글자 크기 배율이 2.0이면, 같은 네 화면은 360×640 논리 크기에서 넘침 오류 없이 그려져야 하며(**shall**), 화면 아래 고정 영역(승인 카드·행동 버튼)은 화면 높이의 절반을 넘으면 그 안에서 스크롤된다. 주요 버튼([이대로 시작], 승인, 거절, 다시 걸기)은 스크롤로 닿을 수 있다.
- **REQ-012** [Ubiquitous] 화면 읽기 지원이 다음을 갖춰야 한다(**shall**): 승인 카드는 실시간 영역(`liveRegion`)이며 읽기 문구에 질문과 남은 초("N초 남음")가 들어 있다. 상태 칩의 읽기 문구는 "상태: <라벨>"이다. 아이콘만 있는 버튼(설정, 삭제, 계획 카드의 수정, 보내기)은 툴팁이 있다.

### 3.5 배치와 회귀

- **REQ-013** [Ubiquitous] 네 화면의 세로 순서는 `design.md` 와이어프레임과 같아야 한다(**shall**): 홈(입력칸 → 제안 → 진행 중 → 지난 통화), 계획 카드(번호 칸(없을 때) → 행 목록 → [이대로 시작]), 통화 상세(머리 카드 → 내용 → 고정 영역의 승인 카드 → 행동 버튼), 결과(결과 카드 → 후속 행동 → 결정 이력 → 부탁한 일 → 대화 기록).
- **REQ-014** [Unwanted] 이 SPEC은 동작을 바꿔서는 안 된다(**shall not**): 요청 본문, 경로, 상태 관리, 서버는 그대로이며, 앞선 SPEC들의 테스트는 acceptance.md AC-014에 이름을 적은 문구 변경 외에 수정 없이 통과한다.

## 4. 비기능 제약

- 새 의존성 없음. 사진 비교(golden) 테스트를 쓰지 않는다. 검증은 위젯 테스트의 의미·지침 검사(`meetsGuideline`), 테마 값 단언, 대비 계산, 세로 위치 비교로 한다.
- 대비 계산 함수는 테스트 지원 코드(또는 토큰 파일의 순수 함수)로 두고, WCAG 2.1 상대 휘도 정의를 따른다.
- 문구: 한국어 해요체, 전문 용어 대신 생활어. 앞선 SPEC의 문구 결정(OD)을 바꾸지 않는다.
- 웹·태블릿: 기존 `ResponsiveBody`(최대 폭 720)를 유지한다.

## 5. Open Decisions

| ID | 결정 사항 | 상태 | 결정 내용 |
|----|-----------|------|-----------|
| OD-1 | 이 SPEC의 순서 | **DEFAULT (pending owner review)** | 마지막. 이유는 `plan.md` §A.0. 처음으로 옮기려면 앞선 세 SPEC의 `depends_on`과 이 SPEC의 대상 목록을 바꾸고, 계획 카드·후속 행동 재디자인을 각 기능 SPEC으로 넘긴다. |
| OD-2 | 씨앗 색 | **DEFAULT (pending owner review)** | 지금의 초록(`0xFF1F8A70`) 유지. 친근함은 표면 색 단계·둥근 정도·여백으로 만든다. 바꾸려면 상수 하나와 AC-002의 대비 표를 다시 계산한다. |
| OD-3 | 상태 라벨 변경 | **DEFAULT (pending owner review)** | 세 개만 바꾼다(계획 중 → 계획 세우는 중, 연결 중 → 전화 거는 중, 정리 중 → 결과 정리 중). "연결 중"은 홈의 실시간 연결 표시(`home_screen.dart:71`)와 같은 말이라 헷갈린다. |
| OD-4 | 글꼴 | **DEFAULT (pending owner review)** | 시스템 기본 글꼴. 글꼴 파일을 넣으면 앱 크기가 늘고 새 자산 관리가 필요하다. |

## 6. 제외 범위 (Out of Scope)

### Out of Scope — 동작과 서버

- 기능 추가, 흐름 변경, API·서버 변경은 하지 않는다(REQ-014).
- 앞선 SPEC들의 문구 결정(OUTCOME OD-2, APPROVAL OD-2·OD-3, INTAKE OD-6, FOLLOWUP OD-3)은 바꾸지 않는다.

### Out of Scope — 브랜드와 자산

- 앱 이름 변경(코드의 CallMate ↔ 문서의 콜비), 아이콘·스플래시·로고, 일러스트, 맞춤 글꼴은 다루지 않는다.
- 다국어(영어 UI)는 다루지 않는다. 화면 문구는 한국어다.

### Out of Scope — 검증 방식

- 사진 비교 테스트, 실제 기기의 화면 읽기 프로그램(TalkBack·VoiceOver) 수동 점검은 이 SPEC의 자동 인수 기준 밖이다.

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
| REQ-012 | AC-012 |
| REQ-013 | AC-013 |
| REQ-014 | AC-014, AC-015 |
