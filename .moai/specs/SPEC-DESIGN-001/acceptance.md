# SPEC-DESIGN-001 인수 기준 (0.2.1)

## 공통 검증 명령

```bash
(cd packages/kolbi_ui && flutter --suppress-analytics test && flutter --suppress-analytics analyze)
(cd app && flutter --suppress-analytics test && flutter --suppress-analytics analyze)
git diff --stat <run_start_sha> -- server/ packages/kolbi_core/
git diff <run_start_sha> -- app/test/
```

기준선: SPEC-MODULE-001이 `completed`된 상태에서 시작한다. run-phase 시작 시 manager-develop이 `run_start_sha`, 위 명령 결과, 기준선 빌드 크기(SPEC-MODULE-001의 빌드 명령)를 `progress.md` §E.2 첫 부분에 기록한다.

규칙: 사진 비교 테스트를 쓰지 않는다. 테스트 먼저(RED) → 구현(GREEN). 서식은 이 SPEC이 만들거나 고친 파일에만.

## AC-001 — 씨앗 색과 역할 값 (REQ-001)

- **Given** 밝은·어두운 테마
- **When** `packages/kolbi_ui/test/theme_values_test.dart`를 실행하면
- **Then** `AppTheme.seed == Color(0xFF635BFF)`이고, 두 모드에서 `plan.md` §A.3 표의 역할 값이 모두 같으며(`primary`는 밝은 `#4F46E5`, 어두운 `#A6ACFF`), `scaffoldBackgroundColor`가 밝은 `#F7F8FC`·어두운 `#11131F`, `cardTheme.color`가 밝은 `#FFFFFF`·어두운 `#1B1F33`, 채운 버튼 바탕이 두 모드 모두 `#635BFF`·글자 `#FFFFFF`다

## AC-002 — 분위기 짝 값 (REQ-002)

- **Given** 밝은·어두운 테마
- **When** `theme_values_test.dart`를 실행하면
- **Then** `live`·`attention`·`positive`·`critical`·`neutral`·`caution` 짝의 배경·글자·강조가 plan.md §A.1 표와 같고(어두운 모드 포함), `CardTone` 열거값 목록이 `neutral, attention, positive, caution, critical` 그대로다

## AC-003 — 대비 (REQ-003)

- **Given** REQ-003의 모든 글자 짝과 강조 짝, 밝은·어두운 모드
- **When** `packages/kolbi_ui/test/tokens_contrast_test.dart`를 실행하면
- **Then** 모든 글자 짝이 `contrastRatio() >= 4.5`, 모든 강조 짝이 `>= 3.0`이다. 각 짝의 실제 값을 테스트 이름이나 실패 메시지에 넣어, 미달 시 어느 짝인지 바로 보인다. 그리고 `#635BFF`가 글자색으로 쓰이는 짝이 없다(짝 목록에 `#635BFF` 글자 없음)

## AC-004a — 어두운 역할 값 (REQ-004)

- **When** `packages/kolbi_ui/test/theme_values_test.dart`의 "dark scheme uses the 06 dark roles"를 실행하면
- **Then** `AppTheme.dark().colorScheme`의 역할 값이 §A.3 어두운 열과 같고, 분위기 짝 여섯 개의 어두운 값이 §A.1 표와 같다(plan-audit D7: 패키지 테스트는 값만 본다)

## AC-004b — 앱이 기기 어두운 모드를 따름 (REQ-004)

- **Given** `tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark`로 앱을 띄움
- **When** `app/test/design_contrast_test.dart`의 "app follows the device dark mode"에서 오늘 화면과 설정 화면을 보면
- **Then** 오늘 화면 `Scaffold` 배경이 `#11131F`이고, 설정 화면의 글자 목록(`find.byType(Text)`로 모은 글자)이 밝은 모드에서 모은 목록과 같다(다크 모드 선택 항목이 새로 생기지 않음)

## AC-005 — Pretendard (REQ-005)

- **Given** `kolbi_ui` 패키지
- **When** `pubspec.yaml`과 테마를 확인하고 `app/test/font_overflow_test.dart`를 실행하면
- **Then** `flutter: fonts:`에 `family: Pretendard`가 글꼴 자산 하나와 함께 등록되어 있고, 같은 폴더에 `OFL.txt`가 있으며, 테마 `textTheme.bodyMedium.fontFamily`가 `packages/kolbi_ui/Pretendard`이고, 글자 크기·굵기 단계 값이 run 시작 시점과 같다(`theme_test.dart:51-69`가 수정 없이 통과). 실제 글꼴을 읽은 테스트에서 홈 화면을 360×640·글자 배율 2.0으로 그려도 넘침 오류가 없다

## AC-006 — 카드 선 (REQ-006)

- **Given** `AppCard`를 다섯 분위기(`neutral`·`attention`·`positive`·`caution`·`critical`)로 하나씩, 그리고 `AppCard(color: Colors.amber)` 하나, 밝은·어두운 모드
- **When** `theme_values_test.dart`에서 각 `tester.widget<Card>()`의 `shape`(없으면 `cardTheme.shape`)를 `RoundedRectangleBorder`로 읽으면
- **Then** 모두 `side.width == 1`이고, `attention`은 `side.color`가 그 짝의 강조색, 나머지는 `outlineVariant`(밝은 `#E6E8F0`, 어두운 `#2A2E45`)다. 모서리 반지름은 `AppRadius.lg` 그대로이고, `color:` 인자를 준 카드는 배경이 그 색이다

## AC-007 — 상태 칩 범주 (REQ-007)

- **Given** `TaskStatus`의 9개 값 × `needsApproval` 참·거짓 = 18칸
- **When** `packages/kolbi_ui/test/status_chip_test.dart`가 18칸을 하나씩 띄우면
- **Then** 칸마다 칩 배경이 `plan.md` §A.2 표의 짝 배경, 글자가 표의 글자, 접근성 라벨이 "상태: <글자>"이고, `needsApproval`이 참인 9칸과 진행 중 통화 3칸에만 `PulsingDot`이 있으며 아이콘이 없고, 나머지 칸에는 표에 적은 `IconData` 하나가 있고 그 아이콘 색이 짝의 글자색과 같다. `Icons.check_circle_rounded`·`Icons.error_rounded`는 어느 칸에도 없다. 생성자 `StatusChip(TaskStatus.inProgress)`가 그대로 컴파일되고 `theme_test.dart:83-103`이 수정 없이 통과한다

## AC-008 — 범주 생성자 (REQ-008)

- **Given** `StatusCategory`의 다섯 값
- **When** `StatusChip.category(c, '라벨')`을 각각 띄우면
- **Then** 각 칩의 색이 AC-007의 같은 범주와 같고, 다섯 아이콘의 `IconData.codePoint`가 서로 다르고 각 아이콘 색이 그 짝의 글자색이며, 접근성 라벨이 "상태: 라벨"이다

## AC-009 — 화면 불변 (REQ-009)

- **Given** run 시작 시점
- **When** run 끝에 `git diff <run_start_sha> -- app/lib/`와 `cd app && flutter --suppress-analytics test`를 실행하면
- **Then** `app/lib/` 변경은 `call_detail_screen.dart`의 [통화 끊기] 버튼 `foregroundColor: onError` 한 곳뿐이고(REQ-009 예외), 앱 테스트 전체가 통과한다. 접근성 지침 검사(밝은·어두운)를 하는 기존 테스트가 모두 통과한다

## AC-010 — 서버·코어 불변 (REQ-010)

- **When** `git diff --stat <run_start_sha> -- server/ packages/kolbi_core/`
- **Then** 출력이 없다

## AC-011 — 의도한 테스트 변경 (REQ-009)

- **When** `git diff <run_start_sha> -- app/test/`
- **Then** 기존 파일에서 바뀐 곳은 `theme_test.dart:29`의 `const Color(0xFF1F8A70)` → `const Color(0xFF635BFF)` 한 줄뿐이고, 새 파일은 `font_overflow_test.dart`와 `design_contrast_test.dart` 둘이다. `git diff <run_start_sha> -- packages/kolbi_ui/test/`에서 SPEC-MODULE-001이 만든 기존 파일(`widgets_test.dart`, `dependency_rules_test.dart`)은 바뀌지 않았다(plan-audit D6). plan-phase에서 확인한 그대로 통과하는 기존 단언: `approval_flow_test.dart:45`("승인 대기"), `accessibility_test.dart:560`("상태: 통화 중"), `theme_test.dart:51-69`(글자 단계), `theme_test.dart:83-103`(깜박이는 점). 표 밖에서 깨지는 단언이 나오면 고치기 전에 소유자 확인을 받는다

## AC-012 — 빌드 크기 (REQ-011)

- **When** 글꼴을 더하기 전과 후에 기준선 빌드 명령을 실행하면
- **Then** 두 결과물 크기와 차이가 `progress.md`에 있다(판정 기준 없음, 기록만. 10 가정 A-6 확인용)

## AC-013 — 앱 화면 대비 (REQ-003)

- **Given** 밝은·어두운 모드, 감사가 찾은 글자 버튼이 있는 화면: 오늘("직접 입력하기"), 승인 카드("거절"), 통화 상세의 [통화 끊기], 설정(연결 확인 버튼을 누른 뒤의 결과 글자 `settings_screen.dart:149` — 설정 화면이 `ApiClient`를 직접 만들어(`:52`) 가짜를 넣을 수 없고, 위젯 테스트 환경은 HTTP 요청에 400을 돌려주므로 실패 결과 글자를 본다. plan-audit 3차 N8), 계획 카드(`plan_card_screen.dart:200`)
- **When** `app/test/design_contrast_test.dart`의 "text contrast meets guidelines on design screens"가 화면마다 `expectLater(tester, meetsGuideline(textContrastGuideline))`를 실행하면
- **Then** 열 경우(5화면 × 2모드) 모두 통과한다. 기존 `accessibility_test.dart:388` "text contrast meets guidelines"도 수정 없이 통과한다(plan-audit D1)

## 엣지 케이스

- 사용자가 기기 글꼴 크기를 키움: 글자 크기 단계는 그대로이므로 지금 큰 글자 규칙(SPEC-UX-001)이 적용된다.
- 고대비 모드(iOS "대비 증가"): 이번 범위에서 따로 다루지 않는다. 모든 글자 짝이 이미 5.0:1 이상이다.

## 잔여 위험

- 위젯 테스트는 기본으로 실제 글꼴을 그리지 않는다. 실기기에서의 글자 폭은 AC-005의 한 화면과 소유자 확인으로만 본다.
- `fromSeed`가 만든 색 가운데 덮어쓰지 않은 색이 다른 SPEC의 새 화면에서 쓰일 수 있다. 새 화면은 06 값과 분위기 짝만 쓰도록 이후 SPEC에서 확인한다.

## 완료 정의 (Definition of Done)

- [ ] AC-001 ~ AC-013(AC-004a·b 포함, 14개) 모두 PASS, 명령 원문과 출력이 `progress.md` §E.2에 있음
- [ ] 의도한 기존 테스트 변경은 `theme_test.dart:29` 한 줄뿐
- [ ] `server/`·`kolbi_core` 무변경, `app/lib`는 [통화 끊기] 버튼 글자색 한 곳만
- [ ] 글꼴 출처·크기·라이선스와 소유자 확인 기록
- [ ] 서식은 변경 파일에만 적용
