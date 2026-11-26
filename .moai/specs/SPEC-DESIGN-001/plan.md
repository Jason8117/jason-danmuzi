# SPEC-DESIGN-001 구현 계획 (0.2.1 — plan-audit 1·2차 반영)

검토 순서 안내: 바뀔 가능성이 큰 결정(분위기 짝 값 대응, 칩 범주 대응표)을 앞에, 글꼴 자산·카드 선 같은 기계적 작업과 회귀를 뒤에 둔다. 값의 근거는 `docs/planning/06_DESIGN_DECISIONS.md` §3, 칩은 `docs/planning/04_DESIGN_PLAN.md` §17.3 CMP-28 개정.

## A. 접근 방식

### A.1 분위기 짝 값 (REQ-002, REQ-004)

`CardTone` 이름과 화면의 쓰임은 그대로 두고 `ToneColors` 값만 바꾼다. 대비는 06 §3.2·§3.3에서 계산한 값이며, M1에서 같은 값을 단위 테스트로 다시 확인한다.

| 짝 | 밝은: 배경 / 글자 / 강조 | 어두운: 배경 / 글자 / 강조 |
|---|---|---|
| `live` | `#EEEDFC` / `#4F46E5` / `#635BFF` | `#23264A` / `#A6ACFF` / `#A6ACFF` |
| `attention` | `#FEF3E2` / `#A44A0C` / `#C2650A` | `#3A2A12` / `#FBBF24` / `#FBBF24` |
| `positive` | `#E9F7EE` / `#157037` / `#159343` | `#13301F` / `#4ADE80` / `#4ADE80` |
| `critical` | `#FDECEC` / `#B91C1C` / `#DC2626` | `#3A1820` / `#FCA5A5` / `#FCA5A5` |
| `neutral`, `caution` | `#F1F2F8` / `#5F6478` / `#7A7F94` | `#1B1F33` / `#A3A8C3` / `#A3A8C3` |

`caution`을 무채색으로 합치는 이유: 06의 의미 색은 넷(완료·승인 필요·실패·안내)이고 "일부"는 별도 색이 없다. `caution`의 쓰임(결과 "일부 달성")은 유지되고 색만 무채색이 된다.

강조(아이콘·테두리) 값은 짝의 옅은 배경 위 3:1을 넘어야 해서 원색과 다르다(plan-phase 계산): 원색 `#D97706`·`#16A34A`·`#8A8FA3`은 각 배경 위 2.90·2.98·2.87로 미달이라, `#C2650A`(3.71)·`#159343`(3.59)·`#7A7F94`(3.55)를 쓴다. 인디고 `#635BFF`(4.06)·Error `#DC2626`(4.23)은 원색 그대로다. 원색은 흰 배경·앱 배경 위 아이콘·점·막대에만 쓴다(06 §3.2).

### A.2 상태 칩 범주 대응표 (REQ-007, REQ-008)

작업 상태 9개 × 대기 승인 여부 2개 = 18칸 전부를 정한다(plan-audit D3). 첫 행이 지금 코드의 `_ when needsApproval` 우선순위와 같다(`status_chip.dart:19`).

| 작업 상태 | 대기 승인 | 범주 | 색(짝) | 앞 표시 | 글자(지금 그대로) |
|---|---|---|---|---|---|
| 9개 모두 | 있음 | 승인 필요 | `attention` | 깜박이는 점 | 승인 대기 |
| `dialing`·`ringing`·`inProgress` | 없음 | 진행 중 | `live` | 깜박이는 점 | 전화 거는 중 · 신호 가는 중 · 통화 중 |
| `planning`·`summarizing` | 없음 | 진행 중 | `live` | `Icons.autorenew_rounded` | 계획 세우는 중 · 결과 정리 중 |
| `awaitingApproval` | 없음 | 승인 필요 | `attention` | `Icons.pan_tool_alt_rounded` | 확인 필요 |
| `completed` | 없음 | 완료 | `positive` | `Icons.task_alt_rounded` | 완료 |
| `failed` | 없음 | 실패 | `critical` | `Icons.report_rounded` | 실패 |
| `canceled` | 없음 | 대기 중 | `neutral` | `Icons.pause_circle_rounded` | 취소됨 |

- 깜박이는 점이 나오는 조건은 지금과 같다(`status.isLiveCall || needsApproval`, `status_chip.dart:44`). 점이 있는 칸에는 아이콘을 두지 않고, 점 자리에 아이콘을 둔다(`theme_test.dart:83-103`의 `FadeTransition` 검사 유지).
- 아이콘은 `outcome_card_test`가 세는 `Icons.check_circle_rounded`·`Icons.error_rounded`와 겹치지 않게 골랐다.
- 범주 열거형 `StatusCategory { waiting, active, needsApproval, done, failed }`를 `kolbi_ui`에 둔다. `StatusChip.category(category, label)`는 범주마다 위 표의 색과 아이콘을 쓴다: `waiting` = `pause_circle_rounded`, `active` = `autorenew_rounded`, `needsApproval` = `pan_tool_alt_rounded`, `done` = `task_alt_rounded`, `failed` = `report_rounded`(다섯 모양이 서로 다름). 이 생성자는 점을 그리지 않는다. 아이콘 색은 그 짝의 글자색(`foreground`)이다(글자와 같은 4.5:1 이상, plan-audit 2차 N3). 이 규칙은 18칸 칩과 `StatusChip.category` 모두에 적용한다.
- 지금 칩과 바뀌는 점(plan-audit D10): `awaitingApproval`이 `primaryContainer` → `attention`, `planning`·`summarizing`이 회색 → `live`, `completed`가 `secondaryContainer` → `positive`, `failed`가 `errorContainer` → `critical` 짝, `canceled`가 `surfaceContainerHighest` → `neutral` 짝. 글자와 라벨은 그대로다.

### A.3 ColorScheme 역할 표 (REQ-001, REQ-004)

`ColorScheme.fromSeed(seedColor: #635BFF, brightness:)` 뒤 `copyWith`로 아래 역할을 덮어쓴다(`fromSeed`만으로는 06 값이 나오지 않음). 표에 없는 역할은 `fromSeed` 값 그대로이며, 앱 전체 대비 검사(M1 관문)로 확인한다.

| 역할 | 밝은 | 어두운 | 쓰임 |
|---|---|---|---|
| `primary` | `#4F46E5` | `#A6ACFF` | 글자 버튼·테두리 버튼 글자, 입력칸 강조(글자 대비: 밝은 카드 6.29, 앱 배경 5.92) |
| `onPrimary` | `#FFFFFF` | `#11131F` | `primary` 위 글자(6.29 / 8.77) |
| `primaryContainer` / `onPrimaryContainer` | `#EEEDFC` / `#4F46E5` | `#23264A` / `#A6ACFF` | `live` 짝과 같은 값 |
| `surface` | `#F7F8FC` | `#11131F` | 앱 배경(`scaffoldBackgroundColor`, 앱바 배경) |
| `surfaceContainerLowest` | `#FFFFFF` | `#1B1F33` | 카드 색(`cardTheme.color`를 `surfaceContainerLow`에서 이것으로 바꿈, plan-audit D4) |
| `onSurface` | `#171B2E` | `#F2F3FA` | 기본 글자 |
| `onSurfaceVariant` | `#5F6478` | `#A3A8C3` | 보조 글자 |
| `outlineVariant` | `#E6E8F0` | `#2A2E45` | 카드 선(꾸밈) |
| `error` / `onError` | `#B91C1C` / `#FFFFFF` | `#FCA5A5` / `#11131F` | 오류 글자 |

채운 버튼(`filledButtonTheme`)은 바탕 `#635BFF`·글자 `#FFFFFF`(4.7:1)를 두 모드 모두 명시한다. 이렇게 하면 감사가 찾은 미달(`TextButton` "직접 입력하기" 4.43, `OutlinedButton` "거절" 4.28, `settings_screen.dart:149`, `plan_card_screen.dart:200`)이 모두 `primary` `#4F46E5`로 바뀌어 4.5를 넘는다(plan-audit D1 (b)안). 이 구성에서 감사 2차 실행 결과는 `+79 -1`이었고, 실패한 하나는 어두운 모드 [통화 끊기](`call_detail_screen.dart`, 바탕 `colorScheme.error` `#FCA5A5`에 흰 글자 1.90:1)였다. 그 버튼에 `foregroundColor: onError`(어두운 `#11131F` 9.73:1, 밝은 `#FFFFFF` 6.47:1)를 넣으면 80/80 통과(감사 확인, plan-audit 2차 N1). `kolbi_ui`만으로는 못 고친다: 어두운 채운 버튼 글자를 `#11131F`로 두면 `#635BFF` 위 3.93으로 미달이고, 흰 글자·어두운 배경 글자를 함께 만족하는 어두운 `error` 값이 없다.

### A.4 글꼴 (REQ-005)

- Pretendard 가변 글꼴(`PretendardVariable.ttf`)을 `packages/kolbi_ui/assets/fonts/`에 두고 `pubspec.yaml`의 `flutter: fonts:`에 `family: Pretendard`로 등록한다. 앱은 `fontFamily: 'Pretendard'`와 `package: 'kolbi_ui'`로 쓴다(패키지 글꼴).
- 파일은 공식 배포처에서 받는다. 받기 전에 파일 이름·크기·출처 주소를 소유자에게 알리고 확인을 받는다. 라이선스 문서(`OFL.txt`)를 같은 폴더에 둔다.
- 위젯 테스트 환경은 기본으로 실제 글꼴을 그리지 않으므로(Ahem 글꼴) 기존 큰 글자 넘침 테스트 결과는 글꼴 교체로 바뀌지 않는다. 실제 글꼴의 폭 차이는 M3의 테스트 하나로 본다: `File('../packages/kolbi_ui/assets/fonts/PretendardVariable.ttf').readAsBytesSync()`로 바이트를 읽어 `FontLoader('packages/kolbi_ui/Pretendard')..addFont(...)`로 등록한 뒤(가족 이름이 테마의 `packages/kolbi_ui/Pretendard`와 같아야 Ahem으로 돌아가지 않음, plan-audit D12) 홈 화면을 그린다.
- 라이선스: `kolbi_ui`에 `registerKolbiFontLicenses()`를 두어 `LicenseRegistry.addLicense`로 `OFL.txt`를 등록한다(plan-audit D11). 앱에서 부르는 한 줄은 `app/lib` 변경이라 SPEC-SHELL-001이 맡는다(그 plan 변경 파일 표의 `app/lib/main.dart` 행).
- 파일 크기(약 2MB 예상)는 확인하지 않은 가정이다. 받기 전 소유자 확인 때 실제 크기를 알리고, AC-012에 전후 빌드 크기를 적는다.

### A.5 카드 선 (REQ-006)

`AppCard`는 `Card`이고 그림자는 이미 없다(`elevation: 0`, `app_theme.dart:37`. plan-audit D2). 바꾸는 곳은 둘이다: `cardTheme.shape`에 `side: BorderSide(width: 1, color: outlineVariant)`를 넣고, `AppCard`의 `attention` 분기(`common.dart:63-68`)는 지금처럼 `side: BorderSide(color: colors.accent)`를 쓰되 너비 1을 명시한다. 그 밖의 분위기는 `shape: null`로 테마 값을 따른다. `color:` 인자가 있으면 그 색이 카드 색을 대신한다(지금 그대로).

## B. 변경 파일

| 파일 | 변경 | 이유 |
|------|------|------|
| `packages/kolbi_ui/lib/src/theme/app_theme.dart` | 수정 | 씨앗 색, 역할 표 덮어쓰기, 카드 색·선, 채운 버튼 바탕, 분위기 짝 값, 글꼴(REQ-001~006) |
| `packages/kolbi_ui/lib/src/theme/tokens.dart` | 수정 | 06 색 상수 |
| `packages/kolbi_ui/lib/src/widgets/common.dart` | 수정 | `AppCard` `attention` 선 너비(REQ-006) |
| `packages/kolbi_ui/lib/src/widgets/status_chip.dart` | 수정 | 범주 대응, `StatusChip.category`, `StatusCategory`(REQ-007, REQ-008) |
| `packages/kolbi_ui/lib/src/theme/fonts.dart` | 새 파일 | `registerKolbiFontLicenses()` |
| `packages/kolbi_ui/lib/kolbi_ui.dart` | 수정 | `StatusCategory`, 등록 함수 공개 |
| `packages/kolbi_ui/assets/fonts/PretendardVariable.ttf` | 새 파일 | 글꼴(REQ-005) |
| `packages/kolbi_ui/assets/fonts/OFL.txt` | 새 파일 | 라이선스(REQ-005) |
| `packages/kolbi_ui/pubspec.yaml` | 수정 | 글꼴·라이선스 자산 등록 |
| `packages/kolbi_ui/test/tokens_contrast_test.dart` | 새 파일 | 대비(REQ-003) |
| `packages/kolbi_ui/test/status_chip_test.dart` | 새 파일 | 18칸 대응(REQ-007, REQ-008) |
| `packages/kolbi_ui/test/theme_values_test.dart` | 새 파일 | 역할·짝·카드·글꼴 값(REQ-001, REQ-002, REQ-004~006) |
| `app/test/font_overflow_test.dart` | 새 파일 | 실제 글꼴 넘침(A.4) |
| `app/test/design_contrast_test.dart` | 새 파일 | 앱 화면 대비·어두운 모드(AC-004b, AC-013) |
| `app/test/theme_test.dart` | 수정(한 줄) | `:29` 씨앗 색(AC-011) |
| `app/lib/features/calls/presentation/call_detail_screen.dart` | 수정(한 곳) | [통화 끊기] `foregroundColor: onError`(REQ-009 예외, N1) |

16개 파일(plan-audit D9: 0.1.0의 "12개"는 글꼴 행 두 파일을 하나로 셌음; 2차 N1로 앱 파일 하나 추가). 그중 테스트 6개, 자산 2개.

## C. 마일스톤 (우선순위 순, 하나씩 순서대로)

### M1 — 대비와 값 테스트 먼저 (Priority High)

`tokens_contrast_test.dart`, `theme_values_test.dart`, `design_contrast_test.dart`를 06 값으로 쓰고(RED), 토큰·짝·역할 표 값을 바꾼다(GREEN). `theme_test.dart:29` 수정. **관문**: 앱 전체 테스트와 `design_contrast_test.dart`(밝은·어두운 `textContrastGuideline`)가 통과해야 M2로 간다(plan-audit D1). AC-001~AC-004b, AC-011, AC-013.

### M2 — 상태 칩 범주 (Priority High)

대응표 테스트(RED) → 범주 열거형·`category` 생성자·아이콘. AC-007, AC-008.

### M3 — 글꼴과 카드 선 (Priority Medium)

글꼴 받기(소유자 확인 뒤) → 자산 등록 → 테마 글꼴 → 실제 글꼴 넘침 테스트, 빌드 크기 비교. `AppCard` 선. AC-005, AC-006, AC-012.

### M4 — 회귀 (Priority Low)

앱 전체 테스트·접근성 지침(밝은·어두운), 서버 불변 확인. AC-009, AC-010, AC-011.

## D. 위험 요소

| 위험 | 대응 |
|---|---|
| 새 값으로 기존 `textContrastGuideline` 검사가 실패 | 값은 06에서 5.0:1 이상으로 골랐고 M1 단위 테스트로 먼저 확인. 실패하면 같은 계열의 더 진한 값으로 바꾸고 06에 기록 |
| `fromSeed`가 만든 나머지 색(예: `secondaryContainer`)이 화면 어딘가에서 글자 대비를 깨뜨림 | M4의 앱 전체 접근성 지침 검사(밝은·어두운)로 확인 |
| 실제 Pretendard 폭이 시스템 글꼴과 달라 실기기에서 넘침 | A.4의 실제 글꼴 테스트 한 화면 + 소유자 실기기 확인 |
| 글꼴 파일을 받을 수 없음(네트워크·승인) | 글꼴 없이 나머지를 끝내고 REQ-005를 blocker로 보고 |
| SPEC-MODULE-001의 `packages/kolbi_ui/test/widgets_test.dart`가 토큰 값·카드 모양을 단언 | MODULE-001이 아직 구현 전이라 plan 시점에 확인 못 함(plan-audit D6). run 시작 때 그 파일에서 색·카드 단언을 찾아 progress.md에 적고, 바뀌어야 하는 줄이 있으면 고치기 전에 소유자 확인 |
| SPEC-UX-001 테스트가 칩 색 이름(`primaryContainer` 등)을 직접 단언 | plan-phase에서 확인: `theme_test.dart`는 칩의 `FadeTransition`과 대비를 보며 색 이름을 단언하지 않음. run 시작 시 `grep -rn "primaryContainer\|secondaryContainer" app/test`로 다시 확인 |

## E. 하네스·복잡도 지표

| 지표 | 값 |
|---|---|
| Tier | M(16개 파일) |
| REQ / AC | 11 / 14 |
| 권장 하네스 | standard |
| 방법론 | TDD(값·대비·대응표 테스트 먼저) |
| 모드 | serial |

## F. 자체 검증

run 단계 완료 보고는 다음을 원문 출력과 함께 담는다: AC별 PASS/FAIL 표와 명령, `flutter test`(kolbi_ui), `cd app && flutter --suppress-analytics test` 마지막 줄, `flutter analyze`, `git diff --stat <run_start_sha> -- server/ packages/kolbi_core/`(비어 있음), `git diff <run_start_sha> -- app/test/`(새 파일과 `theme_test.dart:29` 한 줄뿐), 글꼴 출처·크기·라이선스, 빌드 크기 전후.

## G. sync-phase 문서 항목

- `docs/planning/06_DESIGN_DECISIONS.md` §3: 확정 값(바뀐 것이 있으면), §7 Q-1·Q-2 닫음.
- `docs/planning/04_DESIGN_PLAN.md` §4.1 개정 표: `caution` = 무채색, 칩 범주 대응표 링크.
- `.moai/project/tech.md`: 글꼴 자산과 라이선스.
- `SPEC-UX-001`(plan-audit D5): spec.md OD-2(씨앗 색)·OD-4(글꼴)에 "SPEC-DESIGN-001이 대신함"을 적고, acceptance.md AC-002의 씨앗 색 기대값을 `#635BFF`로. 본문 수정이므로 manager-spec이 맡는다.
- `SPEC-SHELL-001`: `registerKolbiFontLicenses()` 호출 한 줄(`app/lib/main.dart`)은 SHELL-001 plan 변경 파일 표에 이미 넣었다(2026-11-26). sync 때 실제로 들어갔는지 확인.
