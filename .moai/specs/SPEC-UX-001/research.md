# SPEC-UX-001 근거 자료

줄 번호와 개수는 커밋 `c664596` 기준 작업 트리에서 확인했다. 앞선 세 SPEC이 만들 파일(계획 카드, 후속 행동, 신뢰 안내)은 아직 없으므로 run-phase 시작 시 다시 센다. 이 SPEC 작성 중 Flutter 테스트는 실행하지 않았다.

## 1. 흩어진 시각 규칙

- 테마: `app/lib/core/theme/app_theme.dart:3-46` — 씨앗 색 `0xFF1F8A70`(`:4`), 카드 둥근 정도 20(`:25`), 입력칸 14(`:30`), 버튼 최소 높이 52·둥근 정도 16(`:32-44`). 글자 단계는 정하지 않음(Material 기본). 상태 색은 밝기와 무관한 고정 값 `callLive 0xFF16A34A`, `warning 0xFFD97706`(`:50-53`).
- 숫자로 적은 간격·둥근 정도·움직임 시간(AC-001의 grep 명령, 파일별 일치 줄 수): `home_screen.dart` 10, `call_detail_screen.dart` 5, `common.dart` 5, `app_theme.dart` 4, `transcript_view.dart` 4, `new_call_screen.dart` 3, `approval_card.dart` 2, `status_chip.dart` 2, `settings_screen.dart` 1, `outcome_card.dart` 0.
- 글자 크기를 숫자로 적은 곳: `app/lib`에서 `fontSize` 4곳(예: `status_chip.dart:34` 12, `home_screen.dart:149` 13).
- 카드 모양: `SectionCard`(`common.dart:25-63`, 안쪽 여백 18), 승인 카드는 별도 `Card`(`approval_card.dart:73-78`, 둥근 정도 20, 주의 색 테두리), 머리 카드는 또 다른 `Card`(`call_detail_screen.dart:295-297`).
- 빈 상태: `MessageView`(`common.dart:99-145`)를 홈 빈 상태·오류·없는 작업에서 쓰지만, 대화 기록 없음은 `SectionCard` 안의 글 한 줄(`call_detail_screen.dart:195-200`).

## 2. 대비 계산 (WCAG 2.1 상대 휘도)

2026-11-21 이 SPEC 작성 중 Python으로 공식을 계산했다(앱에서 측정한 값이 아니며, 실제 배경은 씨앗에서 만든 표면 색이라 흰색보다 조금 어두워 대비가 더 낮을 수 있다).

| 글자 색 | 배경 | 대비 | 쓰는 곳 |
|---------|------|------|---------|
| `#D97706`(주의) | `#FFFFFF` | 3.19 | 승인 카드 남은 초(`approval_card.dart:91`), 상태 칩 "승인 대기"(`status_chip.dart:17`, `:34-36`) |
| `#D97706` | 흰 바탕 위 12% 주의 색(`#FAEFE1`) | 2.81 | 승인 카드 배경(`approval_card.dart:74`) 위 남은 초 |
| `#16A34A`(진행 중) | `#FFFFFF` | 3.30 | 상태 칩 진행 중 글자 |
| `#16A34A` | 흰 바탕 위 14% 진행 중 색 | 2.82 | 상태 칩 배경(`status_chip.dart:18`) 위 글자 |

본문 글자 기준 4.5:1, 굵은 큰 글자 기준 3:1(18.66px 굵게 이상). 상태 칩 글자(12, 굵게)와 남은 초(`labelLarge` 굵게)는 큰 글자가 아니므로 4.5:1이 적용된다.

## 3. 글자 크기와 움직임

- 통화 상세는 승인 카드를 `Scaffold.bottomNavigationBar`(`call_detail_screen.dart:136-142`)의 `_ActionBar`(`:258-283`)에 둔다. 이 영역은 스크롤되지 않는 `Column`이다. 승인 카드는 제목·질문·안내·입력칸·버튼(앞선 SPEC 뒤에는 칩 세 개 추가)을 가지므로, 글자 크기 2.0과 작은 화면에서 넘칠 것으로 예상한다(실행으로 확인하지 않음 → AC-011 RED에서 확인).
- `PulsingDot`(`common.dart:147-180`)은 `repeat(reverse: true)`로 계속 움직이며 `MediaQuery.disableAnimations`를 보지 않는다. 그 밖의 움직임: 결과로 올라가는 스크롤 400 ms(`call_detail_screen.dart:44`), 대화 따라가기 스크롤 300 ms(`:55`). 1100 ms(`common.dart:159`)는 `pulse` 토큰으로, 300 ms는 `medium`(250 ms)으로, 400 ms는 `slow`로 바꾼다(REQ-001, plan-audit D19).
- 승인 카드는 `Timer.periodic` 1초마다 `setState`로 다시 그린다(`approval_card.dart:37`). 남은 초를 실시간 영역 라벨에 넣으면 라벨이 매초 바뀌므로 REQ-012는 남은 초를 라벨에서 빼고 30초·10초에만 알린다(plan-audit D18; 화면 읽기 프로그램의 실제 재낭독 동작은 확인하지 않음).
- 진동: 승인 카드가 뜰 때 `HapticFeedback.heavyImpact()`(`approval_card.dart:36`), 다른 화면에서 승인 요청 알림 때도(`approval_listener.dart:32`).

## 4. 화면 읽기와 누르는 영역

- 아이콘 버튼 툴팁: 설정(`home_screen.dart:30`), 삭제(`call_detail_screen.dart:120`), 토큰 보기(`settings_screen.dart:129`)는 있다. 실시간 연결 점은 `Tooltip`으로 감싼 장식(`home_screen.dart:74-80`).
- 상태 칩은 `Container` + `Text`(`status_chip.dart:28-38`)로 별도 의미 문구가 없다.
- 승인 카드는 1초마다 다시 그리지만 실시간 영역 표시가 없다(`approval_card.dart:37`, `:73`).
- 템플릿 `ActionChip`(`home_screen.dart:202-206`) 등 칩의 실제 높이는 Material 기본(밀도에 따라 48 미만일 수 있음). 지침 검사 결과는 실행해야 안다(AC-009 RED).

## 5. 상태 문구

- `app/lib/features/calls/domain/call_models.dart:14-45` `TaskStatus` 라벨: 계획 중 / 확인 필요 / 연결 중 / 신호 가는 중 / 통화 중 / 정리 중 / 완료 / 실패 / 취소됨.
- 홈의 실시간 연결 표시도 "연결 중"(`home_screen.dart:71`)이라 통화 상태 "연결 중"과 같은 말이다.
- 앱 테스트에서 바꿀 세 라벨을 단언하는 곳은 없다(`grep -rn "계획 중\|연결 중\|정리 중" app/test` → 없음, c664596 기준). 앞선 SPEC이 추가할 테스트는 run-phase에서 다시 확인한다(AC-014).

## 6. Flutter 접근성 검사 도구

`flutter_test`의 `meetsGuideline`과 `androidTapTargetGuideline`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline`을 쓴다(Flutter SDK 기본 제공 지침이라는 일반 지식에 따름. 이 저장소에서는 아직 쓰인 적이 없고, 이 SPEC 작성 중 실행하지 않았다). 새 의존성이 필요 없다.

## 7. 벤치마크

2026-11-21 WebFetch로 확인. 다른 제품의 화면은 확인하지 못했으므로 옮기지 않는다.

| 출처 | 확인 | 이 SPEC에 쓴 내용 |
|------|------|------------------|
| Victor Yocco, Smashing Magazine, 2026-02-11 — https://smashingmagazine.com/2026/02/designing-agentic-ai-practical-ux-patterns/ | 열림 | 되돌리기 어려운 일에만 두는 "speed bump", "Confidence Signal"(확신 정도와 범위를 보여 줌). → 주의 색은 승인 카드에만(설계 원칙 3), 결과 미확인은 중립 분위기로 확정처럼 보이지 않게 |
| Victor (@victor_desg), DEV Community — https://dev.to/victor_desg/agent-ux-is-not-chatbot-ux-and-most-teams-in-2026-ship-them-as-if-they-were-23bi | 열림 | 승인 단계가 빠르고 정확해야 한다, 작업 상태는 대화와 분리된 화면에. → 한 화면 한 결정, 상태 칩·결과 카드 |
| Towards AI "8 UX Patterns…", AgenticWire "Agent UX design patterns" | **확인 못 함**(403 / 429) | 근거로 쓰지 않음 |
| Pickle(Carly 블로그, 경쟁사 작성), 익시오(전자신문·뉴시스) | 열림, 화면 미확인 | 화면 디자인 근거로 쓰지 않음 |
