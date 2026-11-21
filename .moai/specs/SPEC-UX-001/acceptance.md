# SPEC-UX-001 인수 기준

## 공통 검증 명령

앱(작업 디렉터리 `app/`):

```bash
flutter --suppress-analytics test test/theme_test.dart test/accessibility_test.dart
flutter --suppress-analytics test
flutter --suppress-analytics analyze
```

서버(저장소 루트, 회귀 확인용 — 이 SPEC은 서버를 바꾸지 않음):

```bash
npm --prefix server test
git diff --stat <run_start_sha> -- server/
```

기준선: run-phase 시작 시 manager-develop이 위 명령 결과와 아래 AC-001의 숫자 리터럴 줄 수를 `progress.md` §E.2 첫 부분에 기록한다. SPEC-FOLLOWUP-001이 끝난 상태에서 시작한다(`depends_on`).

공통 준비: 위젯 테스트는 `approval_flow_test.dart`의 `pumpApp` 방식(가짜 저장소, `SharedPreferences` 대역, 안내 확인 기록 있음)으로 네 화면을 띄운다. 네 화면 = (H) 홈(작업 3개: 진행 중 1, 끝난 2, 최근 통화한 곳 2개 표시), (P) 계획 카드(번호 없는 초안과 모든 행이 있는 초안 두 가지), (A) 승인 대기 중인 통화 상세, (R) 결과 화면(`success`, `source llm`, 일정 있음 — 후속 행동 네 개 모두 보임). 밝은 모드가 기본이며, "어두운 모드"는 `MediaQuery(platformBrightness: Brightness.dark)` 또는 `ThemeMode.dark`로 띄운다.

규칙: 사진 비교 테스트를 쓰지 않는다. 테스트 먼저(RED) → 구현(GREEN).

## AC-001 — 토큰 사용 (REQ-001)

- **Given** `plan.md` §B의 대상 Dart 파일 목록
- **When** 다음 명령을 실행하면

  ```bash
  grep -nE "EdgeInsets\.(all|symmetric|only|fromLTRB)\([^)]*[0-9]|BorderRadius\.circular\([0-9]|Duration\(milliseconds: [0-9]" <대상 파일들>
  ```

- **Then** 출력이 없다(0줄). 토큰 파일(`core/theme/tokens.dart`)은 목록에서 제외한다. 그리고 단위 테스트가 토큰 값이 REQ-001과 같음(간격 7개, 둥근 정도 4개, 움직임 3개, 최소 누르는 영역 48)을 단언한다
- 테스트: `app/test/theme_test.dart`(새 파일) — "design tokens have the agreed values"; 위 명령 원문 결과를 `progress.md`에 기록
- RED: 기준선(c664596에서 같은 명령의 줄 수: `home_screen.dart` 10, `call_detail_screen.dart` 5, `common.dart` 5, `app_theme.dart` 4, `transcript_view.dart` 4, `new_call_screen.dart` 3, `approval_card.dart` 2, `status_chip.dart` 2, `settings_screen.dart` 1, `outcome_card.dart` 0 — 앞선 SPEC이 만든 파일은 run-phase 시작 시 다시 셈).

## AC-002 — 상태 색 대비 (REQ-002)

- **Given** 밝은·어두운 테마, WCAG 2.1 대비 계산 함수
- **When** 각 분위기(`neutral`, `attention`, `positive`, `caution`, `critical`)와 진행 중 통화 색의 (배경, 글자) 짝, (배경, 아이콘·테두리) 짝의 대비를 계산하면
- **Then** 두 모드 모두 글자 짝 ≥ 4.5, 아이콘·테두리 짝 ≥ 3.0이다. 씨앗 색은 `0xFF1F8A70`이다. 계산 함수 자체는 `(#000000, #FFFFFF) = 21.0`, `(#D97706, #FFFFFF) ≈ 3.19`(소수 둘째 자리)를 낸다
- 테스트: `theme_test.dart` — "status color pairs meet contrast in light and dark"
- RED: 지금 주의 색 `0xFFD97706`은 흰 배경 대비 3.19, 12% 연한 배경 대비 2.81(`research.md` §2 계산)이라 글자 짝이 실패한다.

## AC-003 — 글자 단계 (REQ-003)

- **Given** 밝은·어두운 테마
- **When** `textTheme`을 읽으면
- **Then** REQ-003 표의 크기·굵기·줄 높이와 같다(8개 스타일, 두 모드 모두)
- 테스트: `theme_test.dart` — "text styles follow the type scale"

## AC-004 — 공용 카드와 분위기 (REQ-004)

- **Given** 네 화면과 결과 카드 다섯 경우(`success`, `partial`, `unverified`, `failed`, 취소)
- **When** 렌더링하면
- **Then** (P)의 행 목록, (A)의 승인 카드, (R)의 결과 카드가 각각 공용 카드 위젯을 하나 이상 포함하고(`find.byType`), 승인 카드의 분위기는 `attention`, 결과 카드는 `positive`/`caution`/`neutral`/`critical`/`neutral`이다. 기존 `SectionCard(...)` 호출은 인자 변경 없이 컴파일되고 공용 카드를 그린다
- 테스트: `app/test/accessibility_test.dart`(새 파일) — "cards share one component and tone"

## AC-005 — 상태 문구 (REQ-005)

- **Given** `TaskStatus` 아홉 값
- **When** 라벨을 읽고, 승인 대기 작업의 상태 칩을 렌더링하면
- **Then** 라벨이 REQ-005 표와 같고(바뀐 셋: "계획 세우는 중", "전화 거는 중", "결과 정리 중"), 상태 칩은 "승인 대기"다. `OutcomeResult` 네 라벨은 그대로("목표 달성", "일부 달성", "달성 못 함", "결과 미확인")
- 테스트: `app/test/unit_test.dart` — "uses plain Korean status labels"
- RED: 세 라벨이 다르다.

## AC-006 — 움직임 줄이기 (REQ-006)

- **Given** 같은 위젯 트리를 `MediaQuery(disableAnimations: true)`와 `false`로 각각 띄움
- **When** 움직임 시간 도우미로 `medium`을 묻고, 진행 중 작업의 상태 칩을 띄운 뒤 1 s를 진행하면
- **Then** 켜짐: 도우미가 `Duration.zero`, 상태 칩의 진행 점 `FadeTransition`의 `opacity` 값이 1 s 동안 변하지 않음(또는 애니메이션 위젯이 없음). 꺼짐: 도우미가 250 ms, 점의 `opacity`가 변함. 켜짐 상태에서 승인 대기 작업이 들어오면 승인 카드가 한 번의 `pump()`로 최종 위치에 있다
- 테스트: `theme_test.dart` — "respects reduce motion"

## AC-007 — 진행 표시와 진동 (REQ-007)

- **Given** 끝나지 않는(`Completer`) 가짜 저장소 호출, `SystemChannels.platform` 호출을 기록하는 대역
- **When** (1) 계획 카드 [이대로 시작], (2) 승인 카드 "승인", (3) 상세 화면 "이대로 전화 걸기", (4) 설정 "연결 테스트"를 누른 직후, 그리고 (1)(2)를 성공으로 끝내면
- **Then** 누른 직후 각 버튼은 `onPressed == null`이고 `CircularProgressIndicator`가 버튼 안에 있다. (1)(2) 성공 뒤 `HapticFeedback.vibrate` 호출이 `HapticFeedbackType.lightImpact`로 정확히 1회. 승인 카드가 처음 나타날 때의 `heavyImpact` 1회는 그대로다
- 테스트: `accessibility_test.dart` — "busy buttons show progress and success gives light haptics"

## AC-008 — 빈 상태 (REQ-008)

- **Given** (1) 작업 없는 홈, (2) `ringing`이고 대화 기록 없는 상세, (3) `in_progress`이고 대화 기록 없는 상세, (4) 목록 오류(가짜 저장소 `list`가 예외), (5) 없는 작업 ID의 상세
- **When** 렌더링하면
- **Then** 다섯 경우 모두 빈 상태 위젯이 정확히 하나 있고, 제목·설명이 `design.md` §5 표와 같으며, (4)에는 "서버 설정"·"다시 시도" 버튼이 있다. 기존 테스트 "shows the empty state with quick-start templates"는 수정 없이 통과한다
- 테스트: `accessibility_test.dart` — "empty states share one widget and wording"

## AC-009 — 누르는 영역 (REQ-009)

- **Given** 네 화면(H, P 두 가지, A, R)
- **When** `expect(tester, meetsGuideline(androidTapTargetGuideline))`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline`을 각각 실행하면
- **Then** 모두 통과한다
- 테스트: `accessibility_test.dart` — "tap targets meet guidelines" (화면 × 지침)
- RED: 실행해 보기 전에는 모른다. run-phase가 RED 실행 결과(실패한 요소 목록)를 기록한다. 처음부터 통과하는 조합은 "처음부터 통과"로 적는다.

## AC-010 — 글자 대비 (REQ-010)

- **Given** 네 화면, 밝은·어두운 모드
- **When** `meetsGuideline(textContrastGuideline)`을 실행하면
- **Then** 여덟 조합(4화면 × 2모드, P는 두 가지 초안 모두) 모두 통과한다
- 테스트: `accessibility_test.dart` — "text contrast meets guidelines"
- RED: 승인 카드의 남은 초·상태 칩 "승인 대기"(주의 색 글자)가 실패할 것으로 예상(AC-002 계산 근거).

## AC-011 — 글자 크기 2.0 (REQ-011)

- **Given** `tester.view.physicalSize = Size(360, 640)`, `devicePixelRatio = 1`, `MediaQuery(textScaler: TextScaler.linear(2.0))`
- **When** 네 화면을 띄우고 `tester.takeException()`을 확인한 뒤, 각 주요 버튼([이대로 시작], 승인, 거절, 다시 걸기)에 `tester.ensureVisible`을 하고 누르면
- **Then** 넘침 예외가 없고(`takeException() == null`), 네 버튼 모두 화면 안으로 스크롤되어 탭이 가짜 저장소에 기록된다. (A)에서 아래 고정 영역의 높이는 화면 높이의 절반(320) 이하다
- 테스트: `accessibility_test.dart` — "survives 2x text scale on a small phone"
- RED: 지금 아래 고정 영역(`call_detail_screen.dart:136-142, 258-283`)은 스크롤되지 않아 승인 카드가 넘칠 것으로 예상.

## AC-012 — 화면 읽기 (REQ-012)

- **Given** (A) 화면(질문 "예약금 1만 원 결제가 필요합니다. 진행할까요?", 남은 90초), (H) 화면
- **When** `tester.getSemantics`로 읽으면
- **Then** 승인 카드 영역의 의미 노드가 `liveRegion` 플래그를 가지고 그 `label`에 질문과 `초 남음`이 들어 있다. 상태 칩의 `label`은 `상태: 통화 중`(또는 해당 라벨). 설정·삭제·보내기·수정 아이콘 버튼은 `tooltip`이 비어 있지 않다(`find.byTooltip('설정')`, `'삭제'`, `'보내기'`, `'수정'`)
- 테스트: `accessibility_test.dart` — "screen reader labels are present"

## AC-013 — 세로 순서 (REQ-013)

- **Given** 네 화면
- **When** 각 기준 요소의 `tester.getTopLeft(...).dy`를 비교하면(필요하면 스크롤하며 측정)
- **Then** (H) 입력칸 < "최근 통화한 곳" < "진행 중" < "지난 통화". (P 번호 없음) 번호 칸 < "전화할 곳" < [이대로 시작]. (A) 머리 카드 < 대화 내용 < 승인 카드 < 승인 버튼. (R) 결과 카드 < 후속 행동("다시 걸기") < "통화 중 결정한 것" < "부탁한 일" < "대화 내용"
- 테스트: `accessibility_test.dart` — "screens follow the wireframe order"

## AC-014 — 동작 불변과 의도된 문구 변경 (REQ-014)

- `git diff --stat <run_start_sha> -- server/ app/lib/features/calls/data/ app/lib/core/network/ app/lib/core/router/`가 비어 있다.
- 앞선 SPEC 테스트(`approval_flow_test.dart`, `approval_card_test.dart`, `intake_flow_test.dart`, `plan_card_test.dart`, `follow_up_test.dart`, `trust_notice_test.dart`, `unit_test.dart`, `outcome_card_test.dart`, `calls_controller_test.dart`)는 새 테스트 추가와 아래 의도된 변경 외에 바뀌지 않는다: 바뀐 세 상태 라벨("계획 중", "연결 중", "정리 중")이나 대화 기록 없음 제목을 단언하는 줄이 있으면 새 문구로 바꾼다. run-phase는 `grep -rn "'계획 중'\|'연결 중'\|'정리 중'" app/test` 결과를 시작 시 기록하고, 바뀐 줄 목록을 `git diff`로 남긴다.

## AC-015 — 회귀 없음

- 앱 `flutter test` 전체 통과, `flutter analyze`가 run-phase 기준선보다 늘지 않음.
- 서버 `npm --prefix server test` 전체 통과(서버 파일 무변경).

## 엣지 케이스

- 웹·태블릿(폭 720 초과): `ResponsiveBody` 최대 폭 유지. 이 SPEC의 자동 기준은 360×640과 기본 테스트 크기(800×600)만 다룬다.
- 어두운 모드에서 진행 중 통화 머리 카드(지금 흰 아이콘 고정, `call_detail_screen.dart:306`)도 대비 짝을 따른다(AC-002).

## 잔여 위험

- `textContrastGuideline`은 그려진 픽셀 기준이 아니라 위젯의 글자·배경 색 추정이므로, 겹친 반투명 배경에서는 실제와 다를 수 있다. AC-002의 직접 계산이 이를 보완한다.
- 실제 화면 읽기 프로그램(TalkBack·VoiceOver)의 읽기 순서·말투는 자동으로 확인하지 않는다.
- 시스템 글꼴은 기기마다 달라 같은 글자 크기에서도 줄바꿈 위치가 다르다.

## 완료 정의 (Definition of Done)

- AC-001 ~ AC-015 충족, RED/GREEN 원문(지침 실패 목록 포함)을 `progress.md` §E.2에 기록.
- OD-1 ~ OD-4 DEFAULT와 소유자 검토 대기를 sync-phase 문서에 기록.
