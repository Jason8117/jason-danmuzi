# SPEC-UX-001 구현 계획

검토 순서 안내: 바뀔 가능성이 큰 결정(이 SPEC의 순서, 색·분위기 체계, 공용 카드 구조)을 앞에, 토큰 치환 같은 기계적 작업과 회귀를 뒤에 둔다. 배치·토큰 값은 `design.md`.

## A. 접근 방식

### A.0 이 SPEC을 마지막에 두는 이유 (OD-1 DEFAULT)

| 기준 | 마지막(선택) | 처음(대안) |
|------|-------------|-----------|
| 디자인할 대상 | 계획 카드, 빠른 답 칩, 후속 행동 줄, 신뢰 안내가 실제로 있는 상태에서 한 번에 다듬는다 | 아직 없는 화면(계획 카드·후속 행동)의 껍데기를 먼저 만들어야 하고, 기능 SPEC이 그 껍데기에 맞춰 다시 바뀐다 |
| 검증 범위 | 접근성 지침·대비·글자 크기 검사를 완성된 네 화면 전체에 한 번에 건다(AC-009~AC-011) | 처음에 건 검사를 기능 SPEC마다 다시 확인해야 한다 |
| 기능 SPEC의 테스트 | 앞선 SPEC 테스트는 문구·`Key`·의미로만 찾도록 정해 두었으므로(각 spec.md §4) 재디자인이 깨뜨리지 않는다 | 기능 SPEC 테스트가 이미 정해진 시각 구조에 묶인다 |
| 사용자 가치 | 승인 칩·한 줄 부탁이 먼저 쓰일 수 있다 | 눈에 보이는 기능이 늦게 나온다 |
| 비용 | 기능 SPEC이 기존 테마로 만든 부분을 한 번 다시 꾸민다(토큰 치환 위주) | 공용 카드 구조를 먼저 고정하면 이 비용은 줄지만 위의 단점이 생긴다 |

앞선 세 SPEC은 새 색·간격 값을 만들지 않고 기존 테마와 `core/widgets/common.dart`만 쓴다(각 spec.md §2). 그래서 이 SPEC의 재디자인은 대부분 "숫자 → 토큰", "개별 `Card` → 공용 카드" 치환이다.

### A.1 색과 분위기 (REQ-002, REQ-004)

- `app_theme.dart`: `StatusColors` 확장을 밝기별 값으로 바꾸고, 분위기 다섯 개의 (배경, 글자, 테두리) 짝을 돌려주는 확장을 둔다. 값은 AC-002 대비 테스트를 통과하도록 정한다.
- `common.dart`: 공용 카드(분위기 인자). `SectionCard`는 같은 인자를 받아 공용 카드를 부르는 감싸개로 남긴다. `MessageView`는 빈 상태 위젯 역할로 정리(REQ-008).

### A.2 토큰과 글자 (REQ-001, REQ-003)

- 새 `tokens.dart`: 간격·둥근 정도·움직임·최소 누르는 영역, 움직임 시간 도우미(움직임 줄이기 → 0).
- `app_theme.dart`: 글자 단계, 버튼 최소 높이 52 유지, 칩 최소 높이 48.

### A.3 화면별 적용 (REQ-005 ~ REQ-013)

- 상태 라벨 세 개(`call_models.dart`), 상태 칩 읽기 문구·전환 움직임(`status_chip.dart`).
- 승인 카드: 분위기 `attention`, 실시간 영역, 남은 초 대비, 카드 내부 스크롤(글자 크기 2.0).
- 통화 상세 아래 고정 영역: 화면 높이 절반 상한 + 내부 스크롤(`call_detail_screen.dart`의 `_ActionBar`).
- 결과 화면: 후속 행동을 결과 카드의 행동 줄로 옮김(`design.md` §7.4, 동작 불변).
- 대화 기록: 사용자 안내 줄을 알약으로(`transcript_view.dart`).
- 홈·계획 카드·설정·신뢰 안내: 토큰 치환, 누르는 영역 48, 아이콘 버튼 툴팁.

## B. 변경 파일

대상 Dart 파일(AC-001의 grep 대상 — 토큰 파일 제외):

| 파일 | 변경 | 이유 |
|------|------|------|
| `app/lib/core/theme/app_theme.dart` | 수정 | 색·분위기·글자 단계 |
| `app/lib/core/widgets/common.dart` | 수정 | 공용 카드, 빈 상태, 진행 점 움직임 줄이기 |
| `app/lib/features/calls/presentation/home_screen.dart` | 수정 | 토큰, 배치, 툴팁 |
| `app/lib/features/calls/presentation/plan_card_screen.dart` | 수정 | 공용 카드, 행 높이, 수정 툴팁 |
| `app/lib/features/calls/presentation/call_detail_screen.dart` | 수정 | 고정 영역 스크롤, 결과 배치, 빈 상태 |
| `app/lib/features/calls/presentation/new_call_screen.dart` | 수정 | 토큰만 |
| `app/lib/features/calls/presentation/widgets/approval_card.dart` | 수정 | `attention`, 실시간 영역, 대비 |
| `app/lib/features/calls/presentation/widgets/outcome_card.dart` | 수정 | 분위기 |
| `app/lib/features/calls/presentation/widgets/status_chip.dart` | 수정 | 대비, 읽기 문구, 전환 |
| `app/lib/features/calls/presentation/widgets/transcript_view.dart` | 수정 | 안내 줄 알약, 토큰 |
| `app/lib/features/calls/presentation/widgets/follow_up_actions.dart` | 수정 | 행동 줄, 누르는 영역 |
| `app/lib/features/calls/presentation/trust_notice.dart` | 수정 | 토큰, 공용 카드 |
| `app/lib/features/settings/settings_screen.dart` | 수정 | 토큰 |

그 밖:

| 파일 | 변경 | 이유 |
|------|------|------|
| `app/lib/core/theme/tokens.dart` | 신규 | 토큰, 움직임 도우미, 대비 계산 함수 |
| `app/lib/features/calls/domain/call_models.dart` | 수정 | 상태 라벨 세 개 |
| `app/test/theme_test.dart` | 신규 | AC-001~AC-003, AC-006 |
| `app/test/accessibility_test.dart` | 신규 | AC-004, AC-007~AC-013 |
| `app/test/unit_test.dart` | 수정 | AC-005 |
| `app/test/support/fakes.dart` | 수정 | 목록 오류·끝나지 않는 호출 주입(AC-007, AC-008 (4)) |

합계 19개(신규 3, 수정 16). 제품 코드 변경의 대부분은 숫자 → 토큰 치환이라 크기는 Tier M 범위(300~1000 LOC)로 보고 M을 유지한다. 파일 수는 Tier M 안내치(5~15)를 넘으며, plan-auditor가 Tier L이 맞다고 보면 올린다(design.md·research.md는 이미 있음).

바꾸지 않는 파일(AC-014로 확인): `server/**`, `app/lib/features/calls/data/**`, `app/lib/core/network/**`, `app/lib/core/router/**`, `app/lib/features/calls/application/**`.

## C. 마일스톤 (우선순위 순, 하나씩 순서대로)

### M1 — 색·분위기·글자·토큰 정의 (Priority High)

RED: AC-002(대비, 지금 실패), AC-003, AC-001의 토큰 값 단위 테스트, AC-006 도우미 부분.

### M2 — 공용 카드와 빈 상태 (Priority High)

RED: AC-004, AC-008.

### M3 — 화면 적용: 승인 카드·통화 상세 (Priority High)

RED: AC-011의 (A), AC-012의 승인 카드, AC-010의 (A). 고정 영역 스크롤.

### M4 — 화면 적용: 홈·계획 카드·결과·설정 (Priority Medium)

RED: AC-009, AC-010 나머지, AC-011 나머지, AC-012 나머지, AC-013. AC-001 grep 0줄.

### M5 — 상태 문구·움직임·진동 (Priority Medium)

RED: AC-005, AC-006 나머지, AC-007. AC-014의 문구 단언 교체(같은 커밋).

### M6 — 회귀 (Priority Low)

AC-014, AC-015.

## D. 위험 요소

| 위험 | 내용 | 대응 |
|------|------|------|
| 지침 검사 실패가 많음 | 처음 실행 때 많은 요소가 걸릴 수 있다 | M3·M4에서 화면별로 나눠 고친다. 실패 목록을 RED 증거로 기록. |
| 동작 회귀 | 결과 화면 배치를 옮기며 버튼 동작이 바뀔 위험 | 앞선 SPEC 테스트(문구·동작 기준)가 그대로 통과해야 한다(AC-014). |
| 색 값 결정 | 대비를 맞추며 브랜드 느낌이 바뀜 | 씨앗 유지(OD-2), 분위기 짝만 조정. |
| 글자 크기 2.0 | 고정 영역이 화면을 덮음 | 높이 상한 + 내부 스크롤(REQ-011). |
| 지침 검사 한계 | `textContrastGuideline`은 반투명 겹침을 정확히 못 잼 | AC-002의 직접 계산으로 보완. |

### D.1 에픽 내 파일 겹침

앞선 세 SPEC이 만든·바꾼 화면 파일 대부분을 다시 연다(위 §B). 직렬 순서로 해소한다(`depends_on: [SPEC-FOLLOWUP-001]`).

## E. 하네스·복잡도 지표

| 지표 | 값 |
|------|-----|
| Tier | M (파일 수 초과 사유는 §B) |
| 도메인 수 | 1 (app UI) |
| 변경 파일 수 | 19 (신규 3, 수정 16) |
| REQ / AC | 14 / 15 |
| 새 의존성 | 없음 |
| 권장 하네스 | standard |

## F. 자체 검증

- 마일스톤별 RED/GREEN 원문(지침 실패 요소 목록 포함)을 `progress.md` §E.2에 기록.
- AC-001 grep 명령의 시작·끝 원문 결과를 기록.
- `git diff --stat <run_start_sha> -- server/ app/lib/features/calls/data/ app/lib/core/network/ app/lib/core/router/` 결과(빈 출력)를 기록.

## G. sync-phase 문서 항목

- 디자인 토큰·분위기 체계와 공용 카드(`.moai/project/structure.md`의 앱 구조).
- 상태 라벨 세 개 변경(OD-3).
- 접근성 검사 항목(테스트 파일 이름과 지침).
