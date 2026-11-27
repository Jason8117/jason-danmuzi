---
id: SPEC-SHELL-001
title: "5칸 셸과 작업 종류 등록부 — 오늘·업무·기록·내 정보, 가운데 비서 버튼, 업무 실행 단계"
version: "0.3.1"
status: in-progress
created: 2026-11-26
updated: 2026-11-26
author: jason
priority: High
phase: "v0.4.0 target"
module: "app/lib/shell, app/lib/features/inbox, app/lib/features/history, app/lib/features/me, app/lib/features/calls/presentation, packages/kolbi_core, packages/kolbi_ui"
lifecycle: spec-anchored
tags: "shell, navigation, tab-bar, inbox, history, task-kind, registry, task-steps, today, go_router, information-architecture, flutter, accessibility"
tier: L
depends_on: [SPEC-MODULE-001, SPEC-DESIGN-001]
related_specs: [SPEC-UX-001, SPEC-INTAKE-001, SPEC-FOLLOWUP-001, SPEC-ASSIST-001]
---

# SPEC-SHELL-001: 5칸 셸과 작업 종류 등록부 — 오늘·업무·기록·내 정보, 가운데 비서 버튼, 업무 실행 단계

## HISTORY

| 버전 | 날짜 | 작성 | 변경 |
|------|------|------|------|
| 0.1.0 | 2026-11-26 | jason (manager-spec) | 최초 작성 (draft). 3탭 셸 |
| 0.2.0 | 2026-11-26 | jason | 디자인 검토 반영. 5칸 셸, 업무·기록, 토큰·글꼴·칩, 단계, 오늘 |
| 0.3.1 | 2026-11-26 | jason | plan-audit 2차(FAIL 0.80, `.moai/reports/plan-audit/SPEC-SHELL-001-review-2.md`) 반영. `openTask`는 쌓인 화면을 모두 닫은 뒤 업무 탭으로(N1, research R1 보강 실험 X1~X6·Y1~Y3), 탭 누름은 `goBranch`, 이동 함수 네 개로 정리(N3), 승인·진행 중 묶음이 겹치지 않게(N4), 단계 표 빈칸·만료 문구(N5), 데이터 시간대(N6), AC-021 접근성 행(N2), 문서 정리(N7~N11) |
| 0.3.0 | 2026-11-26 | jason | plan-audit 1차(FAIL 0.70, `.moai/reports/plan-audit/SPEC-SHELL-001-review-1.md`) 반영. 소유자 결정으로 토큰·글꼴·상태 칩을 SPEC-DESIGN-001로 떼고 Tier L로 올림(design.md·research.md 추가). go_router 탭 사이 이동을 실험으로 확인(research R1), 단계 기대 표·묶음·결과 칩·오늘 규칙을 design.md로(D2~D5), 기존 테스트 영향 전체 목록(research R2), 묶인 요구사항을 나눔(16 → 21) |

## 1. 배경과 목적

지금 앱은 홈 한 화면에 입력칸·진행 중·지난 통화가 모두 있고(`app/lib/features/calls/presentation/home_screen.dart:217`, `:273`), 경로는 `/`, `/calls/new`, `/plan`, `/calls/:id`, `/settings` 다섯 개다(`app/lib/core/router/app_router.dart:15-34`). 모든 작업은 통화이며 작업 종류라는 개념이 없다. 라우터가 `core/`에 있으면서 모든 화면을 가져오고, 설정 화면이 통화 기능의 화면 조각을 가져온다(`app/lib/features/settings/settings_screen.dart:10`).

디자인 검토(`docs/planning/06_DESIGN_DECISIONS.md`, 이하 "06")는 앱을 5칸 탭(오늘 / 업무 / 가운데 비서 버튼 / 기록 / 내 정보)으로 정했다(06 DR-2·DR-6). 이 SPEC은 그 셸을 만들고, 이후 AI 비서·장소·반복·A2A 같은 작업 종류가 셸을 고치지 않고 꽂히도록 작업 종류 등록부(`TaskKind`)를 둔다. 업무 하나의 진행을 6단계로 보이는 계산과 화면 조각(06 DR-5)도 여기서 만든다. 색·글꼴·상태 칩은 SPEC-DESIGN-001이 먼저 바꾸어 두고, 이 SPEC은 그 결과를 쓴다. 기존 통화 흐름은 새 셸 안에서 그대로 동작해야 한다.

AI 비서 화면(음성·몰입형 다크)은 SPEC-ASSIST-001이 만든다. 이 SPEC의 가운데 버튼은 자리와 경로, 지금 입력칸을 담은 임시 화면만 만든다(OD-6).

## 2. 범위

- 앱과 두 패키지(`kolbi_core`의 계산, `kolbi_ui`의 화면 조각)만. 서버와 `/v1`은 바꾸지 않는다.
- 대상 화면: SCR-H01 오늘(재구성), SCR-T01 업무(신규), SCR-R01 기록(신규), SCR-M01 내 정보(신규), SCR-T02 통화 상세 맨 위 단계 타임라인(추가), 탭 바 CMP-01 개정·가운데 버튼 CMP-36, 임시 비서 화면.
- 설계 표와 규칙: `design.md` D1~D7. 근거: `research.md` R1~R3.
- 변경 파일 목록: `plan.md` §B.

## 3. 요구사항 (GEARS)

### 3.1 탭 바와 경로

- **REQ-001** [Ubiquitous] 앱은 오늘·업무·(가운데 비서 버튼)·기록·내 정보 다섯 칸을 이 순서로 고정한 하단 탭 바(04 CMP-01 개정)를 보여야 하며(**shall**), 네 탭은 아이콘과 글자 라벨을 늘 함께 보이고 선택된 탭은 채운 아이콘과 `onPrimaryContainer` 글자색(SPEC-DESIGN-001의 `#4F46E5`)으로 구분된다. 가운데 버튼은 탭이 아니며(선택 상태 없음) 읽기 문구는 "비서 부르기"다. 탭 바는 네 탭의 첫 화면과 그 위에 쌓인 화면에서 보이고, `/assistant`에서는 보이지 않는다.
- **REQ-002** [Event-driven] **When** 사용자가 이미 선택된 탭을 다시 누르면, 앱은 그 탭의 첫 화면으로 돌아가야 하며(**shall**), 이미 첫 화면이면 맨 위로 스크롤한다.
- **REQ-003** [State-driven] **While** 승인 요청 작업(`design.md` D3)이 하나 이상 있으면, 업무 탭은 그 개수를 배지로 보여야 하며(**shall**) 10 이상은 "9+"로 쓰고, 탭의 읽기 문구는 "업무, 승인 대기 N개"다. 0개이면 배지를 숨기고 읽기 문구는 "업무"다.
- **REQ-004** [Ubiquitous] 지금 경로 `/`, `/calls/new`, `/plan`, `/calls/:id`, `/settings`는 지금과 같은 화면을 지금과 같은 인자(`extra`, 경로 매개변수)로 열어야 하며(**shall**), 새 경로 `/inbox`, `/history`, `/me`, `/assistant`를 더한다(`design.md` D1.1). 경로를 `push`로 열면 지금 탭을 바꾸지 않고 그 위에 쌓는다(research R1-A·D). 기능 간 이동은 경로 이름과 셸의 이동 함수로만 한다.
- **REQ-005** [Event-driven] **When** 사용자가 오늘·업무·기록의 작업 행을 누르거나, 계획 카드 [이대로 시작]·직접 입력 만들기가 성공하거나, 승인 알림의 [답하기]를 누르면, 앱은 지금 쌓인 화면(비서 포함)을 모두 닫고 업무 탭을 선택해 업무 첫 화면 위에 그 작업의 상세를 열어야 하며(**shall**)(`openTask`, research R1 Y1~Y3), 뒤로 가기는 업무 첫 화면으로 간다. 그 뒤 탭 바로 다른 탭에 가도 계획 카드 등 닫힌 화면이 다시 보이지 않는다(research R1 X1과 Y1). 탭 바의 다른 탭 누름은 그 탭에 쌓인 화면을 지키고(`goBranch`), 선택된 탭을 다시 누르면 그 탭의 첫 화면으로 간다(design.md D1.2).
- **REQ-006** [Event-driven] **When** 사용자가 가운데 비서 버튼을 누르면, 앱은 지금 탭의 쌓인 화면을 그대로 둔 채 `/assistant`를 전체 화면으로 열어야 하며(**shall**), 닫으면 원래 탭과 화면으로 돌아간다(research R1-E). 이 SPEC의 `/assistant`는 지금 부탁 입력칸·예시 칩을 담은 밝은 임시 화면이고, 부탁을 보내면 임시 화면을 닫은 뒤 원래 탭 위에 계획 카드를 연다(research R1-G2. 임시 화면 위에 바로 계획 카드를 `push`하면 go_router 오류 — R1-G).

### 3.2 작업 종류와 단계

- **REQ-007** [Ubiquitous] 앱은 작업 종류 등록부를 가져야 하며(**shall**), 각 종류는 헤드리스 서술(종류 id, 상태 문구, 종류별 상세 해석, 단계 목록 — `kolbi_core`)과 화면 기여(아이콘, 작업 행, 상세 화면, 결과 화면 — `kolbi_ui`)로 이루어진다. 셸은 시작할 때 `call` 종류를 등록하고, 오늘·업무·기록·통화 상세는 작업의 종류로 화면 기여를 찾아 그린다. 같은 id를 두 번 등록하면 오류다.
- **REQ-008** [Unwanted] 작업에 종류 값이 없으면 앱은 그 작업을 `call`로 읽어야 하며, 모르는 종류 값이면 행을 "이 앱에서 아직 볼 수 없는 작업이에요"로 보이고 누르면 빈 상태(CMP-29, "이 작업은 앱을 업데이트하면 볼 수 있어요")를 보인다. 어느 경우에도 앱이 오류로 멈춰서는 안 된다(**shall not**).
- **REQ-009** [Ubiquitous] `kolbi_core`는 작업 하나를 6단계(요청 이해 · 연락처 확인 · 가능 여부 확인 · 내 승인 · 확정 · 결과 보고)와 단계 상태(끝남 · 지금 · 대기 · 실패 · 건너뜀 · 취소)로 바꾸는 순수 함수를 가져야 하며(**shall**), 결과는 `design.md` D2.2 기대 표의 모든 행과 같다.
- **REQ-010** [Ubiquitous] 통화 상세 화면은 맨 위에 단계를 업무 단계 타임라인(CMP-34)으로 보여야 하며(**shall**), 각 단계 아래 설명은 `design.md` D2.3의 글자를 쓰고 화면의 다른 글자(승인 질문, 대화 내용, 목표, 상대 이름·번호)를 되풀이하지 않는다. 그 아래의 기존 내용(계획 검토, 승인 카드, 대화 기록, 결과)은 지금 자리와 동작 그대로다.

### 3.3 업무와 기록

- **REQ-011** [Ubiquitous] 업무(SCR-T01)는 제목 "나의 업무" 아래 개수 세 칸(진행 중 · 승인 대기 · 오늘 완료)과 묶음 "승인 요청 / 진행 중 / 반복"을 이 순서로 보여야 하며(**shall**), 묶음 규칙과 순서는 `design.md` D3를 따른다. 작업이 없는 묶음은 제목째 숨기고(반복 제외), 반복 묶음은 "반복할 일을 만들면 여기에 모여요" 한 줄을 보인다. 맨 아래에 "끝난 업무는 기록에서 볼 수 있어요"를 두고 누르면 기록 탭으로 간다.
- **REQ-012** [State-driven] **While** 작업이 하나도 없으면, 업무는 빈 상태 "아직 맡긴 일이 없어요"와 [비서에게 맡기기](가운데 버튼과 같은 동작)를 보여야 하며(**shall**), 목록을 불러오지 못하면 기존 오류 빈 상태(`MessageView`, "다시 시도")를 같은 방식으로 보인다.
- **REQ-013** [Ubiquitous] 업무 묶음·개수, 기록 묶음, 배지 수, 오늘의 "확인이 필요해요"·"진행 중"은 `kolbi_core`의 순수 함수 하나에서 나와야 하며(**shall**), 배지 수 = 업무 "승인 요청" 수 = 오늘 "확인이 필요해요" 전체 수다. 승인 요청 가운데 통화 중 대기 승인 작업 집합은 기존 `pendingApprovalsProvider`와 같고, `ApprovalListener`의 알림 대상은 바꾸지 않는다(`design.md` D3).
- **REQ-014** [Ubiquitous] 기록(SCR-R01)은 끝난 작업을 아시아/서울 날짜 묶음("오늘 · 11월 26일", "어제 · 11월 25일", 그 밖 "11월 24일")으로 최근 순으로 보여야 하며(**shall**), 각 행은 상대 이름 · 결과 칩(`design.md` D4, SPEC-DESIGN-001 `StatusChip.category`) · 결과 한 줄을 보인다. 끝난 작업이 없으면 빈 상태 "아직 끝난 업무가 없어요"를 보인다.

### 3.4 오늘

- **REQ-015** [Ubiquitous] 오늘(SCR-H01)의 세로 순서는 워드마크 줄 → 날짜·인사·부제 → 브리핑 카드(CMP-37) → 비서에게 부탁하기(부탁 입력칸 + 예시 칩 + 바로가기 2×2) → 확인이 필요해요(있을 때만, 처음 두 개) → 진행 중(있을 때만, 처음 두 개) → 최근 통화한 곳이어야 하며(**shall**), 각 요소의 글자 규칙은 `design.md` D5를 따른다. 끝난 작업 목록("지난 통화")은 오늘에서 빼고 기록 탭에서만 보인다. 작업이 하나도 없으면 브리핑 카드·확인·진행 중 대신 지금의 첫 사용 빈 상태를 보인다(OD-2). 시뮬레이션 안내, 실시간 연결 표시, 서버 설정 아이콘 버튼(툴팁 "설정"), 부탁 입력칸 아래 [직접 입력하기] 링크는 지금처럼 보인다(plan-audit 2차 N11).
- **REQ-016** [Event-driven] **When** 사용자가 오늘의 바로가기를 누르면, 앱은 "전화 대신하기"·"정보 찾아보기"면 `/assistant`를 열어야 하며(**shall**), "일정 관리"·"메일 확인"은 "곧 쓸 수 있어요" 라벨과 함께 비활성이라 아무 일도 하지 않는다. 브리핑 카드의 "업무 보기 →"는 업무 탭으로 간다.

### 3.5 내 정보

- **REQ-017** [Ubiquitous] 내 정보(SCR-M01)는 맨 위에 프로필 카드(설정에 저장된 이름과 회신 번호, 회신 번호는 가운데를 가림, 없으면 "내 정보를 입력해 주세요")를, 그 아래 `design.md` D6의 묶음·항목을 보여야 하며(**shall**), 프로필 카드와 "서버 연결(개발용)"만 설정 화면으로 가고 나머지 항목은 숨기지 않은 채 "곧 쓸 수 있어요" 라벨과 함께 비활성이다.

### 3.6 구조와 회귀

- **REQ-018** [Ubiquitous] 라우터와 탭 구성, 이동 함수, 종류 등록은 셸(`app/lib/shell/`)에 있어야 하며(**shall**), 앱 `core/`는 `features/`를 가져오지 않고, 기능 모듈은 다른 기능 모듈을 가져오지 않는다. SPEC-MODULE-001이 남긴 기능 간 허용 목록 한 건(`trust_notice.dart`)을 비우고, 옛 경로 유지를 위한 다시 내보내기 전용 파일만 검사에서 제외하되 그 목록을 테스트에 고정한다.
- **REQ-019** [Ubiquitous] 기존 통화 흐름은 새 셸 안에서 동작이 같아야 한다(**shall**): 한 줄 부탁 → 계획 카드 → [이대로 시작] → 통화 상세 → 고정 승인 카드(빠른 답·코멘트·만료) → 결과 카드 → 후속 행동([다시 걸기]는 계획 카드로), 직접 입력(`/calls/new`), 첫 통화 전 신뢰 안내, 앱 어디서든 승인 요청이 오면 알리는 동작(`ApprovalListener`).
- **REQ-020** [Ubiquitous] 오늘·업무·기록·내 정보·통화 상세 화면은 밝은·어두운 모드에서 `androidTapTargetGuideline`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline`을 통과하고, 글자 크기 배율 2.0·360×640에서 넘침 오류 없이 그려져야 하며(**shall**), 탭 바 라벨의 글자 배율은 1.5배를 넘지 않는다(04 DOD-9).
- **REQ-021** [Unwanted] 이 SPEC은 `server/`와 `/v1`을 바꿔서는 안 되며, 기존 테스트는 `acceptance.md` AC-021의 표(research R2)에 적은 블록 외에는 수정 없이 통과해야 한다(**shall not** 그 밖의 변경).

## 4. 비기능 제약

- 새 외부 의존 없음. go_router 18.1.4의 `StatefulShellRoute`를 쓴다(research R1에서 동작 확인).
- 시각 값(색·글꼴·칩·카드)은 SPEC-DESIGN-001 결과를 쓴다. 작업 종류는 색이 아니라 아이콘으로 구분(04 DOD-3). 아이콘은 지금 Material 아이콘(SPEC-DESIGN-001 OD-3).
- 사진 비교(golden) 테스트를 쓰지 않는다. 검증은 위젯 테스트(글자·`Key`·의미 문구·세로 위치·지침 검사). 탭 라벨과 화면 제목이 같은 글자("기록", "내 정보")이므로 새 테스트는 `Key`로 찾는다.
- 시각(오늘 인사·날짜·기록 날짜 묶음)은 주입 가능한 시계로 계산한다.
- 문구는 해요체 생활어, 04 §2.2 금지 문구를 쓰지 않는다.
- 서식은 이 SPEC이 만들거나 고친 파일에만 적용한다.

## 5. Open Decisions

| ID | 결정 사항 | 상태 | 결정 내용 |
|----|-----------|------|-----------|
| OD-1 | 홈에서 끝난 작업 목록을 뺄지 | **DECIDED (2026-11-26)** | 뺀다. 끝난 작업은 기록 탭(06 DR-6) |
| OD-2 | 첫 사용 빈 상태와 서버 설정 버튼 | **DEFAULT (pending owner review)** | 작업 0개에서 지금의 빈 상태 유지(기존 테스트 `approval_flow_test.dart:36`, `accessibility_test.dart:341`). SPEC-ASSIST-001에서 브리핑 빈 문구로 바꿈. 설정 버튼은 F-SET-06까지 유지 |
| OD-3 | [이대로 시작] 뒤 머무는 곳 | **DECIDED (2026-11-26)** | 업무 탭 상세(04 DOD-1 ②, REQ-005) |
| OD-4 | "최근 통화한 곳" 이름 | **DEFAULT (pending owner review)** | 유지. "최근 장소"는 SPEC-PLACE-001 |
| OD-5 | 기능 폴더 재배치 | **DEFAULT (pending owner review)** | `features/calls`를 나누지 않는다. 새 모듈(`inbox`, `history`, `me`)과 셸만 만든다 |
| OD-6 | 오늘의 입력칸과 임시 비서 화면 | **DEFAULT (pending owner review)** | 과도기로 오늘에 입력칸·예시 칩을 남기고, `/assistant`는 같은 입력칸을 담은 밝은 임시 화면. SPEC-ASSIST-001이 바꿈 |
| OD-7 | 업무 실행 단계의 자리 | **DEFAULT (pending owner review)** | 통화 상세 맨 위에 단계 타임라인만 더함. 통화 중 화면 분리는 SPEC-ASSIST-001 |
| OD-8 | 실패 단계 판정 | **DEFAULT (pending owner review)** | 대화 유무로 근사(`design.md` D2.2 행 12~14). 서버가 실패 단계를 주면 바꿈 |

## 6. 제외 범위 (Out of Scope)

### 6.1 Out of Scope — 새 기능

- AI 비서 화면·Orb 움직임·받아쓰기·몰입형 다크·통화 중 화면(SPEC-ASSIST-001), 장소 선택·상세(SPEC-PLACE-001), 반복 작업(SPEC-ROUTINE-001), A2A 실행 경로(SPEC-HUB-001).
- 브리핑 문장 생성·제안 업무·오늘 일정(F-HOME-01~03), 기록 검색·거르기(F-INBOX-06), 새 결과 점(F-INBOX-03), 작업 삭제 동작(F-INBOX-04의 새 제스처), 스킬 둘러보기(F-SKILL-01).
- 04 §17.5의 업무 카드 안 [승인](바로 승인) — 승인은 지금처럼 상세의 승인 카드에서만.
- 04 §17.2의 오늘 알림 버튼, 04 §17.7 기록 카드의 통화 시간·결정 기록 수 표시.
- 계획 카드 주 버튼 이름 "비서에게 맡기기"(04 §17.8) — 지금 "이대로 시작" 유지(기존 테스트가 찾음).
- 온보딩(SCR-O01~O04), 알림·푸시.

### 6.2 Out of Scope — 시각 값

- 색·글꼴·상태 칩·카드 선(SPEC-DESIGN-001), 06 §3.4의 글자 크기 단계·화면 여백 20(SPEC-DESIGN-001 OD-4), 아이콘 묶음 교체.

### 6.3 Out of Scope — 서버와 데이터

- `server/` 변경, 서버 `kind`·`steps`·실패 단계 필드 추가, 서버 상태 이름 변경(설계서 §3.4, AD-8).

### 6.4 Out of Scope — 이름과 문구

- 앱 패키지 이름·`MaterialApp.title`·OS 표시 이름 변경(10 OD-K1), "최근 통화한 곳" 이름 변경(OD-4), 빈 상태 문구 변경(OD-2).

## 7. 추적성

| 요구사항 | 인수 기준 | 0.2.0 대응 |
|----------|-----------|------------|
| REQ-001 | AC-001 | REQ-001(앞부분) |
| REQ-002 | AC-002 | REQ-001(다시 누름) |
| REQ-003 | AC-003 | REQ-002 |
| REQ-004 | AC-004 | REQ-003 |
| REQ-005 | AC-005 | REQ-011 |
| REQ-006 | AC-006 | REQ-004 |
| REQ-007 | AC-007 | REQ-005(앞부분) |
| REQ-008 | AC-008 | REQ-005(모르는 종류) |
| REQ-009 | AC-009 | REQ-006(계산) |
| REQ-010 | AC-010 | REQ-006(화면) |
| REQ-011 | AC-011 | REQ-007(묶음) |
| REQ-012 | AC-012 | REQ-007(빈·오류) |
| REQ-013 | AC-013 | REQ-008 |
| REQ-014 | AC-014 | REQ-009 |
| REQ-015 | AC-015 | REQ-010 |
| REQ-016 | AC-016 | (신규, plan-audit D10) |
| REQ-017 | AC-017 | REQ-012 |
| REQ-018 | AC-018 | REQ-014 |
| REQ-019 | AC-019 | REQ-015(흐름) |
| REQ-020 | AC-020 | REQ-015(접근성) |
| REQ-021 | AC-021 | REQ-016 |
