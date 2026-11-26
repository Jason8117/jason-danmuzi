# SPEC-SHELL-001 구현 계획 (0.3.1, Tier L)

검토 순서 안내: 바뀔 가능성이 큰 결정(종류·단계 계약, 묶음 규칙, 탭 사이 이동, 오늘 배치)을 앞에, 라우터 옮기기·의존 규칙 정리 같은 기계적 작업과 회귀를 뒤에 둔다. 표와 규칙은 `design.md`, 근거는 `research.md`. 화면은 `docs/planning/04_DESIGN_PLAN.md` §6.1 개정·§17, 승인된 목업 https://claude.ai/artifact/Cp7JpXX81GSaEKh5SVUQ7U.

0.2.0 대비: 토큰·글꼴·칩(SPEC-DESIGN-001로), go_router 실험 결과 반영(대안 경로 삭제), 단계 기대 표·결과 칩·오늘 규칙·내 정보 항목을 design.md로, 테스트 영향 목록 확정(research R2).

## A. 접근 방식

### A.0 종류·단계 계약을 먼저 정하는 이유

오늘·업무·기록·상세 화면이 모두 "작업의 종류로 그리는 법을 찾는다"에 기댄다. 그래서 M1에서 계약, `call` 등록, 묶음 함수, 단계 함수를 만들고, 이후 화면은 그 위에서 쓴다. 계약은 설계서 §3.2의 두 층을 따르고 서술자에 `steps(task)`를 더한다. `call` 종류의 화면 기여는 지금 화면을 감싸기만 한다: 작업 행 = 지금 홈의 작업 행(`home_screen.dart:362` `_TaskTile`), 상세·결과 = 지금 통화 상세 화면 맨 위에 단계 타임라인을 더한 것.

### A.1 묶음과 단계 (REQ-009, REQ-011, REQ-013, REQ-014)

`design.md` D2·D3·D4의 표를 그대로 단위 테스트로 옮긴다(RED). 묶음 함수는 작업 목록·현재 시각·시간대(아시아/서울)를 인자로 받는 순수 함수다. 시간대 계산은 `intl` 없이 UTC+9 고정 오프셋으로 한다(대한민국은 서머타임이 없음).

### A.2 탭 사이 이동 (REQ-004, REQ-005, REQ-006)

research R1의 결론대로 한다: 그냥 `push`는 지금 탭 위에 쌓고, "탭 전환 + 푸시"는 `go('/inbox')` 다음 `push`, 비서는 셸 밖 최상위 경로, 임시 비서에서 계획 카드로는 비서를 닫고 `push`. 이 규칙은 `app/lib/shell/navigation.dart`의 네 함수 `openTask`(쌓인 화면을 모두 닫고 `go('/inbox')`+`push`, research R1 Y1~Y3), `openTab`(`goBranch`), `openAssistant`, `submitFromAssistant`에만 둔다(design.md D1.2). 지금 이동 코드(`plan_card_screen.dart:109`의 `pushReplacement`, `new_call_screen.dart:74`, `approval_listener.dart:29`의 상세 이동)는 `openTask`로 바꾼다. M3의 첫 작업은 research의 실험 코드를 앱 셸 구성으로 다시 돌리는 작은 테스트다.

`routerProvider`는 지금 이름 그대로 공개한다(테스트 4개 파일이 `package:callmate/core/router/app_router.dart`에서 가져옴). 라우터 본문은 `app/lib/shell/app_router.dart`로 옮기고 옛 경로는 다시 내보내기 파일로 남긴다.

### A.3 오늘 (REQ-015, REQ-016, OD-2, OD-6)

`design.md` D5의 규칙으로 지금 `home_screen.dart`를 고친다. 입력칸과 예시 칩, 첫 사용 빈 상태는 과도기로 남긴다. 인사·날짜는 주입 가능한 시계 공급자(`clockProvider`)로 계산한다. 이름 끝 받침으로 조사(이/가)를 고르는 함수는 `kolbi_core`의 표시 형식에 둔다.

### A.4 단계 타임라인 (REQ-010)

`KolbiStepTimeline`(`kolbi_ui`)은 단계 목록만 받아 그린다. 통화 상세 맨 위 한 곳에만 넣고 나머지는 건드리지 않는다. 설명 글자는 design.md D2.3의 고정 문구라 상세의 다른 글자와 겹치지 않는다(research R2: `approval_flow_test.dart:52-53` 보호).

### A.5 내 정보 (REQ-017)

`design.md` D6 항목. 신뢰 안내 조각(`trust_notice.dart`)은 앱 공통(`app/lib/core/widgets/trust_notice.dart`)으로 옮기고 옛 경로는 다시 내보내기로 남긴다(D7의 이유). 이것으로 SPEC-MODULE-001이 남긴 기능 간 허용 목록 마지막 한 건이 없어진다.

## B. 변경 파일

| 파일 | 변경 | 이유 |
|------|------|------|
| `packages/kolbi_core/lib/src/kinds/task_kind.dart`, `call_kind.dart` | 새 파일 | 서술자(+`steps`), 등록부(REQ-007, REQ-008) |
| `packages/kolbi_core/lib/src/tasks/task_steps.dart` | 새 파일 | 단계 계산(REQ-009) |
| `packages/kolbi_core/lib/src/tasks/task_groups.dart` | 새 파일 | 묶음·개수·배지·브리핑 수(REQ-011, REQ-013~015) |
| `packages/kolbi_core/lib/src/format/korean_particle.dart` | 새 파일 | 이/가 고르기(D5) |
| `packages/kolbi_core/lib/kolbi_core.dart` | 수정 | 공개 |
| `packages/kolbi_core/test/task_kind_test.dart`, `task_steps_test.dart`, `task_groups_test.dart` | 새 파일 | `dart test` |
| `packages/kolbi_ui/lib/src/kinds/task_kind_presenter.dart` | 새 파일 | 화면 기여 계약, 모르는 종류 행 |
| `packages/kolbi_ui/lib/src/widgets/step_timeline.dart` | 새 파일 | CMP-34(REQ-010) |
| `packages/kolbi_ui/lib/src/widgets/briefing_card.dart` | 새 파일 | CMP-37(REQ-015) |
| `packages/kolbi_ui/lib/src/widgets/tab_badge.dart` | 새 파일 | 배지(REQ-003) |
| `packages/kolbi_ui/lib/kolbi_ui.dart` | 수정 | 공개 |
| `packages/kolbi_ui/test/step_timeline_test.dart` | 새 파일 | 의미 라벨 |
| `app/lib/shell/app_router.dart` | 새 파일(옮김) | 셸 4갈래 + `/assistant`(REQ-004) |
| `app/lib/shell/routes.dart` | 새 파일 | 경로 이름 |
| `app/lib/shell/navigation.dart` | 새 파일 | 이동 함수(D1.2) |
| `app/lib/main.dart` | 수정(한 줄) | SPEC-DESIGN-001의 `registerKolbiFontLicenses()` 호출(글꼴 라이선스를 앱 정보 화면에 등록, DESIGN plan-audit D11) |
| `app/lib/shell/tab_scaffold.dart` | 새 파일 | 탭 바, 가운데 버튼, 다시 누름, 배율 상한(REQ-001~003, REQ-020) |
| `app/lib/shell/assistant_placeholder.dart` | 새 파일 | 임시 비서(REQ-006) |
| `app/lib/shell/kind_registration.dart` | 새 파일 | `call` 등록·표시자 |
| `app/lib/core/router/app_router.dart` | 다시 내보내기로 | 테스트 호환 |
| `app/lib/core/clock.dart` | 새 파일 | 시계 공급자 |
| `app/lib/features/inbox/inbox_screen.dart` | 새 파일 | SCR-T01(REQ-011, REQ-012) |
| `app/lib/features/history/history_screen.dart` | 새 파일 | SCR-R01(REQ-014) |
| `app/lib/features/me/me_screen.dart` | 새 파일 | SCR-M01(REQ-017) |
| `app/lib/features/calls/presentation/home_screen.dart` | 수정 | 오늘(REQ-015, REQ-016), 행 누름 이동, [내 정보 입력] tonal 버튼 색: `style: FilledButton.styleFrom(backgroundColor: scheme.primaryContainer, foregroundColor: scheme.onPrimaryContainer)`(#EEEDFC / #4F46E5 — SPEC-DESIGN-001의 채운 버튼 바탕 #635BFF가 tonal 버튼에도 들어가 주 버튼과 구분되지 않음, DESIGN plan-audit 3차 N6, 소유자 결정 2026-11-26) |
| `app/lib/features/calls/presentation/call_detail_screen.dart` | 수정(맨 위 한 곳) | 단계 타임라인(REQ-010) |
| `app/lib/features/calls/presentation/plan_card_screen.dart` | 수정(두 곳) | [이대로 시작] 뒤 `openTask`(`:109`), 설정 이동 경로 이름(`:271`) |
| `app/lib/features/calls/presentation/new_call_screen.dart` | 수정(한 곳) | `openTask`(`:74`) |
| `app/lib/features/calls/presentation/approval_listener.dart` | 수정(한 곳) | [답하기] → `openTask(ref.read(routerProvider), id)`(`:38`) |
| `app/lib/features/calls/presentation/widgets/follow_up_actions.dart` | 수정(한 곳) | [다시 걸기] 경로 이름(`:89`), tonal 버튼 색: `style: FilledButton.styleFrom(backgroundColor: scheme.primaryContainer, foregroundColor: scheme.onPrimaryContainer)`(#EEEDFC / #4F46E5 — SPEC-DESIGN-001의 채운 버튼 바탕 #635BFF가 tonal 버튼에도 들어가 주 버튼과 구분되지 않음, DESIGN plan-audit 3차 N6, 소유자 결정 2026-11-26) |
| `app/lib/features/calls/presentation/trust_notice.dart` | 다시 내보내기로 | 기능 간 import 제거 |
| `app/lib/core/widgets/trust_notice.dart` | 새 파일(옮김) | 같음 |
| `app/lib/features/settings/settings_screen.dart` | 수정(import 한 줄) | 같음 |
| `app/lib/app.dart` | 수정 | 등록 호출, 제목 |
| `app/test/architecture_test.dart` | 수정 | 허용 목록 비우기, `.go(` 검사(REQ-018) |
| `app/test/shell_test.dart`, `inbox_test.dart`, `history_test.dart`, `today_test.dart` | 새 파일 | AC |
| `app/test/accessibility_test.dart` | 수정(한 블록) + 새 테스트 | AC-021, AC-020 |
| `app/test/plan_card_test.dart` | 수정(한 블록) | AC-021 |

약 40개 파일. Tier L(소유자 결정 2026-11-26).

## C. 마일스톤 (우선순위 순, 하나씩 순서대로)

### M1 — 종류·단계·묶음 계약 (Priority High)

`kolbi_core` 서술자·등록부·`call` 서술자·`taskSteps`·묶음 함수·조사 함수와 `dart test`(RED 먼저, design.md 표 그대로). `kolbi_ui` 표시자 계약, 모르는 종류 행, 배지, 단계 타임라인. AC-007, AC-008(함수), AC-009, AC-011·AC-013·AC-014(함수).

### M2 — 셸 라우터, 탭 바, 이동 함수 (Priority High)

research R1을 앱 셸 구성으로 다시 확인하는 테스트 → 라우터를 셸로 옮기고 4갈래 + `/assistant`, 경로 이름, `navigation.dart`, 다시 누름, 배지, 임시 비서. AC-001~AC-006.

### M3 — 업무와 기록 (Priority High)

업무 묶음·개수·빈 상태·오류, 기록 날짜 묶음·결과 칩. AC-011, AC-012, AC-014.

### M4 — 오늘과 단계 타임라인 (Priority Medium)

오늘 배치(D5), 지난 통화 제거, 바로가기, 통화 상세 맨 위 단계 타임라인, 이동 코드를 `openTask`로. `accessibility_test.dart:614-619`, `plan_card_test.dart:194-196` 수정. AC-010, AC-015, AC-016.

### M5 — 내 정보 (Priority Medium)

프로필 카드, D6 항목, 설정 연결, 신뢰 안내 조각 옮기기. AC-017.

### M6 — 구조 규칙과 회귀 (Priority Low)

의존 규칙 테스트 갱신, 접근성 지침 확대, 전체 회귀, research R2 표와 grep 대조. AC-018~AC-021.

## D. 위험 요소

| 위험 | 대응 |
|---|---|
| 앱 셸 구성에서 go_router 동작이 실험과 다름 | M2 첫 작업으로 실제 셸에서 같은 경우(A·B·E·G2·H와 보강 X1·X2·X5·Y1~Y3)를 경우마다 따로 실행해 다시 확인. 다르면 멈추고 plan으로 되돌림 |
| 탭 바가 아래 고정 영역(승인 카드·행동 버튼, SPEC-UX-001 REQ-011)과 겹쳐 큰 글자에서 넘침 | AC-020의 360×640·배율 2.0 검사 |
| 승인 판정이 두 곳에서 어긋남 | AC-013 (1) 같은 입력 비교 |
| `ApprovalListener`(`app.dart:22`)가 셸 안에서 위치가 바뀌어 스낵바·이동이 깨짐 | `approval_flow_test.dart` 무수정 통과(AC-019), AC-005 (5) |
| research R2 표 밖의 테스트가 깨짐 | 고치지 않고 plan으로 되돌림(AC-021) |
| 숨은 갈래의 글자가 `find`에 걸림 | `IndexedStack` 숨은 갈래는 기본 `skipOffstage`로 빠짐(research R2). 새 테스트는 키 사용 |
| 다른 SPEC과 파일 겹침 | DESIGN-001 다음, ASSIST-001 전에 단독 진행 |

## E. 하네스·복잡도 지표

| 지표 | 값 |
|---|---|
| Tier | L(약 40개 파일, 산출물 5개) |
| REQ / AC | 21 / 21 |
| 권장 하네스 | standard |
| 방법론 | TDD(새 화면·새 함수 테스트 먼저), 기존 흐름은 기존 테스트로 보존 |
| 모드 | serial |

## F. 자체 검증

run 단계 완료 보고는 다음을 원문 출력과 함께 담는다: AC별 PASS/FAIL 표와 명령, `cd app && flutter --suppress-analytics test` 마지막 줄, `dart test`(kolbi_core)·`flutter test`(kolbi_ui), `flutter analyze`, `git diff --stat <run_start_sha> -- server/`(비어 있음), `git diff <run_start_sha> -- app/test/`(AC-021 표의 두 블록과 새 파일·새 테스트만), M2의 go_router 재확인 결과, 서식을 적용한 파일 목록.

## G. sync-phase 문서 항목

- `.moai/project/structure.md`: 앱 배치(`shell/`, `features/inbox`, `features/history`, `features/me`)와 경로 표.
- `docs/product/11_ARCHITECTURE.md` §2.5: 셸 경로와 이동 규칙(research R1), AD-10 보강(셸 밖 경로 위 `push` 금지).
- `docs/planning/04_DESIGN_PLAN.md` §17: 단계 설명 고정 문구(design.md D2.3), 오늘 인사 규칙(D5).
- `README.md`: 화면 구성(5칸 탭) 한 단락.
