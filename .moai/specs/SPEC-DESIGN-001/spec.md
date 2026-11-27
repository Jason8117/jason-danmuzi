---
id: SPEC-DESIGN-001
title: "Midnight Indigo 디자인 시스템 — 토큰 값 교체, Pretendard, 상태 칩 다섯 범주, 선 카드"
version: "0.2.1"
status: implemented
created: 2026-11-26
updated: 2026-11-27
author: jason
priority: High
phase: "v0.4.0 target"
module: "packages/kolbi_ui/lib/src/theme, packages/kolbi_ui/lib/src/widgets, packages/kolbi_ui/assets/fonts"
lifecycle: spec-anchored
tags: "design-system, tokens, midnight-indigo, theme, contrast, pretendard, font, status-chip, dark-mode, accessibility, flutter"
tier: M
depends_on: [SPEC-MODULE-001]
related_specs: [SPEC-UX-001, SPEC-SHELL-001, SPEC-ASSIST-001, SPEC-SDK-001]
---

# SPEC-DESIGN-001: Midnight Indigo 디자인 시스템 — 토큰 값 교체, Pretendard, 상태 칩 다섯 범주, 선 카드

## HISTORY

| 버전 | 날짜 | 작성 | 변경 |
|------|------|------|------|
| 0.2.1 | 2026-11-26 | jason | plan-audit 2차(FAIL 0.80, `.moai/reports/plan-audit/SPEC-DESIGN-001-review-2.md`) 반영. 어두운 모드 [통화 끊기] 버튼 대비 미달(1.90:1)을 `call_detail_screen.dart`의 버튼 글자색 한 곳(`onError`)으로 고침 — REQ-009의 `app/lib` 무변경에 그 한 줄만 예외(N1), 위험 버튼 짝을 REQ-003에 더함, 추적표 갱신(N2), 칩 아이콘 색(N3) |
| 0.2.0 | 2026-11-26 | jason | plan-audit 1차(FAIL 0.75, `.moai/reports/plan-audit/SPEC-DESIGN-001-review-1.md`) 반영. `primary`를 글자용 `#4F46E5`로, `#635BFF`는 채운 버튼 바탕으로만(D1), 카드는 `Card.shape`의 1px 선과 흰 카드 색(D2·D4), 칩 대응표 18칸 전부와 아이콘 이름(D3), 밝은·어두운 역할 표(D4), SPEC-UX-001과의 관계(D5), AC-004 둘로 나눔(D7), 권장 수정(D6, D8~D12) |
| 0.1.0 | 2026-11-26 | jason | 최초 작성 (draft). SPEC-SHELL-001 0.2.0의 REQ-013(토큰·글꼴·상태 칩)을 plan-audit 1차 권고(`.moai/reports/plan-audit/SPEC-SHELL-001-review-1.md` Tier 권고, D1·D3·D6)에 따라 따로 떼어 낸 SPEC. 에픽 EPIC-KOLBI-APP의 둘째 SPEC |

## 1. 배경과 목적

지금 테마는 씨앗 색 `0xFF1F8A70`(초록)에서 `ColorScheme.fromSeed`로 만든다(`app/lib/core/theme/app_theme.dart:6`, `:24`. SPEC-MODULE-001 이후 `packages/kolbi_ui/lib/src/theme/app_theme.dart`). 분위기 짝 다섯 개(`CardTone`: neutral · attention · positive · caution · critical, `:66`)와 진행 중 짝(`live`)이 대비 4.5:1을 지키도록 정해져 있고(SPEC-UX-001 REQ-002), 공용 카드 `AppCard`는 `Card`(`common.dart:61`, 그림자 없음 `elevation: 0`)이고 카드 색은 `surfaceContainerLow`(`app_theme.dart:39`)다. 상태 칩(`status_chip.dart`)은 상태마다 색을 고르고, 글자는 상태 이름(`TaskStatus.label`)이나 "승인 대기"를 쓴다.

디자인 검토(`docs/planning/06_DESIGN_DECISIONS.md`, 이하 "06")는 색을 Midnight Indigo로 바꾸고(DR-7), 글꼴로 Pretendard를 앱에 넣으며(DR-8), 상태를 다섯 범주로 보이기로 했다(04 CMP-28 개정). 글자용 색 값은 세 바탕 모두 5.0:1 이상으로 계산해 두었다(06 §3.2·§3.3).

이 SPEC은 **보이는 값만** 바꾼다. 분위기 짝의 이름과 쓰임, 글자 크기 체계, 칩 글자와 접근성 라벨, 화면 배치는 그대로 둔다. 그래서 기존 화면 테스트는 씨앗 색을 직접 단언하는 한 줄 말고는 그대로 통과해야 한다.

**SPEC-UX-001과의 관계(plan-audit D5)**: SPEC-UX-001은 씨앗 색 `0xFF1F8A70` 유지(OD-2 DEFAULT)와 시스템 글꼴(OD-4 DEFAULT)을 정했고, 그 인수 기준(`SPEC-UX-001/acceptance.md` AC-002)이 옛 씨앗 색을 단언한다. 소유자가 디자인 검토에서 Midnight Indigo와 Pretendard를 고른 결정(06 DR-7·DR-8)이 이 두 기본값을 대신한다. SPEC-UX-001의 대비·글자 단계·분위기 짝 규칙은 그대로 유효하며, 이 SPEC은 값만 바꾼다. SPEC-UX-001 문서의 고칠 곳은 `plan.md` §G에 적는다.

## 2. 범위

- 주로 `kolbi_ui` 패키지를 고친다(앱은 패키지를 그대로 가져다 씀). 서버와 `/v1`는 바꾸지 않고, 앱 화면 코드는 [통화 끊기] 버튼 글자색 한 곳만 바꾼다(REQ-009).
- 바꾸는 것: 브랜드·의미·무채색 값(06 §3.1~§3.3), 분위기 짝 값, `ColorScheme`의 역할 값(`plan.md` §A.3 표), 카드 색, 채운 버튼 바탕, Pretendard 글꼴 자산과 테마 글꼴, `AppCard`의 1px 선, 상태 칩의 범주 색과 범주 아이콘.
- 바꾸지 않는 것: `CardTone` 이름과 쓰임 규칙, 글자 크기·굵기 단계(SPEC-UX-001), 간격·모서리 값, 칩 글자와 접근성 라벨, 칩의 깜박이는 점, 아이콘 묶음(지금 Material 아이콘 유지, OD-3), Information 색(06 §3.2, 지금 쓰는 화면이 없어 이후 SPEC에서 처음 쓸 때 더함 — plan-audit D8).
- 변경 파일 목록: `plan.md` §B.

## 3. 요구사항 (GEARS)

### 3.1 색

- **REQ-001** [Ubiquitous] 테마는 밝은·어두운 모드 각각에서 `plan.md` §A.3 역할 표의 값을 `ColorScheme`에 명시로 넣어야 하며(**shall**), 글자로 쓰이는 인디고 역할(`primary`, `onPrimaryContainer`, 글자 버튼·테두리 버튼·입력칸 강조)은 밝은 모드 `#4F46E5`, 어두운 모드 `#A6ACFF`다. Electric Indigo `#635BFF`는 씨앗 색과 채운 버튼의 바탕(흰 글자, 4.7:1)과 진행 중 강조에만 쓴다. 앱 배경은 밝은 `#F7F8FC`, 어두운 `#11131F`이고, 카드 색은 밝은 `#FFFFFF`, 어두운 `#1B1F33`이다.
- **REQ-002** [Ubiquitous] 분위기 짝은 이름과 쓰임을 유지한 채 값만 06 §3.2 대응으로 바뀌어야 하며(**shall**), 각 짝의 배경·글자·강조 값은 `plan.md` §A.1 표를 따른다: `live` → 인디고(배경 `#EEEDFC`, 글자 `#4F46E5`, 강조 `#635BFF`), `attention` → Warning(`#FEF3E2`, `#A44A0C`, `#C2650A`), `positive` → Success(`#E9F7EE`, `#157037`, `#159343`), `critical` → Error(`#FDECEC`, `#B91C1C`, `#DC2626`), `neutral`·`caution` → 무채색(`#F1F2F8`, `#5F6478`, `#7A7F94` — `caution`은 `neutral`과 같은 값). 짝마다 어두운 모드 값은 06 §3.3을 따른다.
- **REQ-003** [Ubiquitous] 모든 글자 짝(분위기 짝의 배경 위 글자, 앱 배경·카드 색 위 `onSurface`·`onSurfaceVariant`·`primary`, 채운 버튼 바탕 위 글자, 위험 버튼 `error` 바탕 위 `onError` 글자)은 밝은·어두운 모드에서 대비 4.5:1 이상이어야 하며(**shall**), 강조 값은 그 배경 위에서 3:1 이상이다. `#635BFF`는 글자색으로 쓰지 않는다(`#F7F8FC` 위 4.43:1로 미달).
- **REQ-004** [State-driven] **While** 기기가 어두운 모드이면, 앱은 `plan.md` §A.3 역할 표의 어두운 열(06 §3.3 값)로 만든 `ColorScheme`과 분위기 짝을 써야 한다(**shall**). 앱 안에 다크 모드 선택은 더하지 않는다(지금처럼 기기 설정을 따름).

### 3.2 글꼴

- **REQ-005** [Ubiquitous] `kolbi_ui`는 Pretendard 가변 글꼴 파일 하나와 그 라이선스(SIL Open Font License 1.1) 문서를 자산으로 담아야 하며(**shall**), 테마의 `fontFamily`는 그 글꼴(패키지 글꼴로 등록)이다. 글자 크기·굵기·줄 높이 단계는 지금 테마 값을 바꾸지 않는다.

### 3.3 공용 카드

- **REQ-006** [Ubiquitous] 공용 카드 `AppCard`(`Card`)는 모든 분위기에서 `Card.shape`의 테두리 선을 너비 1로 그려야 하며(**shall**), 선 색은 `attention`이면 지금처럼 그 짝의 강조색, 그 밖에는 `outlineVariant`(밝은 `#E6E8F0`, 어두운 `#2A2E45`)다. 이 선은 꾸밈이며(대비 1.22:1) 카드와 앱 배경의 구분은 카드 색과 배경 색 차이와 함께 본다. 모서리 값, 안쪽 여백, `color:` 인자로 카드 색을 바꾸는 쓰임은 그대로다.

### 3.4 상태 칩

- **REQ-007** [Ubiquitous] 상태 칩은 작업을 다섯 범주(대기 중 · 진행 중 · 승인 필요 · 완료 · 실패) 가운데 하나로 나누어 범주 색으로 그려야 하며(**shall**), 범주와 앞 표시(깜박이는 점 또는 범주 아이콘)는 `plan.md` §A.2 대응표(작업 상태 9개 × 대기 승인 여부 = 18칸)로 정한다. 대기 승인이 있으면 상태와 관계없이 승인 필요 범주·깜박이는 점·"승인 대기"다(지금 코드의 우선순위 그대로). 칩의 글자(`TaskStatus.label`, 대기 승인이면 "승인 대기")와 접근성 라벨("상태: <글자>"), 깜박이는 점이 나오는 조건(진행 중 통화이거나 대기 승인), 생성자 `StatusChip(status, {needsApproval})`와 가져오는 경로는 바꾸지 않는다.
- **REQ-008** [Ubiquitous] 상태 칩은 작업 상태 없이 범주와 글자만 받는 생성자(`StatusChip.category(category, label)`)를 더해야 하며(**shall**), 이후 SPEC(기록의 결과 칩 등)이 결과 종류를 범주로 바꿔 쓸 수 있게 한다. 범주 다섯 개의 아이콘은 서로 모양이 다르다(색에만 의존하지 않음, 04 DP-6).

### 3.5 회귀와 경계

- **REQ-009** [Unwanted] 이 SPEC은 화면 글자·배치·경로·요청·상태 관리를 바꿔서는 안 되며(**shall not**), `app/lib`에서 바꾸는 곳은 [통화 끊기] 버튼의 글자색 한 곳(`call_detail_screen.dart`의 `FilledButton.styleFrom(backgroundColor: danger)`에 `foregroundColor: onError` 추가 — 어두운 모드 흰 글자 on `#FCA5A5`가 1.90:1로 미달, plan-audit 2차 N1)뿐이고, 기존 테스트(앱과 SPEC-MODULE-001이 만든 `packages/kolbi_ui/test/`)는 `acceptance.md` AC-011에 이름을 적은 곳(`theme_test.dart:29`의 씨앗 색 기대값) 외에는 수정 없이 통과해야 한다.
- **REQ-010** [Unwanted] 이 SPEC은 `server/`를 바꿔서는 안 되며(**shall not**), `kolbi_core`도 바꾸지 않는다.
- **REQ-011** [Ubiquitous] 글꼴을 더하기 전후 앱 빌드 크기(SPEC-MODULE-001 기준선 빌드 명령)를 비교해 `progress.md`에 기록해야 한다(**shall**)(10 가정 A-6, 06 Q-2).

## 4. 비기능 제약

- 새 외부 의존 없음. 글꼴은 패키지 자산이다. Pretendard 글꼴 파일은 공식 배포처(GitHub `orioncactus/pretendard` 릴리스)에서 받으며, 받기 전에 파일 이름·크기·출처를 소유자에게 알리고 확인을 받는다(외부 파일 다운로드).
- 대비 계산은 SPEC-UX-001의 `contrastRatio()`(tokens)로 단위 테스트에서 한다.
- 사진 비교(golden) 테스트를 쓰지 않는다.
- 서식은 이 SPEC이 만들거나 고친 파일에만.

## 5. Open Decisions

| ID | 결정 사항 | 상태 | 결정 내용 |
|----|-----------|------|-----------|
| OD-1 | 글자용 색 값 | **DECIDED (2026-11-26)** | 06 §3.2·§3.3 추천 값(소유자 요청으로 계산·추천) |
| OD-2 | 칩 글자를 다섯 범주 이름으로 바꿀지 | **DEFAULT (pending owner review)** | 바꾸지 않는다. 범주는 색·아이콘으로 보이고 글자는 구체적인 상태 이름을 쓴다(04 §2.2 "처리 중 대신 단계 이름"). 기존 테스트 `approval_flow_test.dart:45`("승인 대기"), `accessibility_test.dart:560`("상태: 통화 중")이 그대로 통과한다 |
| OD-3 | 아이콘 묶음(06 Q-4, Lucide 계열) | **DEFAULT (pending owner review)** | 이 SPEC에서는 바꾸지 않고 지금 Material 아이콘(둥근·선 변형)을 쓴다. 선 아이콘 묶음 도입은 별도 결정(패키지·라이선스 확인과 외부 다운로드가 필요) |
| OD-4 | 06 §3.4의 글자 크기 단계·화면 여백 20 | **DEFAULT (pending owner review)** | 이 SPEC 범위 밖. 바꾸면 `theme_test.dart:51-69`와 큰 글자 배치 테스트가 흔들려, 화면을 다시 짜는 SPEC(SHELL-001 이후)에서 화면별로 적용 |

## 6. 제외 범위 (Out of Scope)

### 6.1 Out of Scope — 화면과 문구

- 앱 정보 화면의 글꼴 라이선스 등록 호출(`app/lib` 변경이라 SPEC-SHELL-001이 한 줄 더함). 이 SPEC은 `kolbi_ui`에 등록 함수만 둔다.
- 탭·화면 배치·문구 변경(SPEC-SHELL-001), AI Orb·몰입형 다크 테마(SPEC-ASSIST-001), 워드마크.
- 칩 글자를 범주 이름으로 바꾸기(OD-2), 아이콘 묶음 교체(OD-3), 글자 크기 단계·여백 변경(OD-4).

### 6.2 Out of Scope — 서버와 패키지

- `server/`, `kolbi_core`, SDK 테마 덮어쓰기(SPEC-SDK-001, 에픽의 이후 SPEC으로 아직 작성 전).

## 7. 추적성

| 요구사항 | 인수 기준 |
|----------|-----------|
| REQ-001 | AC-001 |
| REQ-002 | AC-002 |
| REQ-003 | AC-003, AC-013 |
| REQ-004 | AC-004a, AC-004b |
| REQ-005 | AC-005 |
| REQ-006 | AC-006 |
| REQ-007 | AC-007 |
| REQ-008 | AC-008 |
| REQ-009 | AC-009, AC-011 |
| REQ-010 | AC-010 |
| REQ-011 | AC-012 |
