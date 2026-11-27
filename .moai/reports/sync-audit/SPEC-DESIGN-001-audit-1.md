# Sync 감사 보고서 — SPEC-DESIGN-001 (1차)

- 감사 대상: main HEAD `8d6770f`(SPEC-UX-001 대체 표시, DESIGN plan §G). run 시작 `466c73b`, 구현 커밋 `7687615`(M1 색·대비 관문)·`4430e31`(M2 상태 칩 범주)·`3de1cee`(M3 Pretendard·1px 카드 선), run 기록 커밋 `5ee6eef`, 다른 SPEC 커밋 `797c0da`(무관), sync 커밋 `e47e099`
- 평가 프로필: `.moai/config/evaluator-profiles/default.md` (Functionality 40%, Security 25%, Craft 20%, Consistency 15%. 필수 통과 차원은 Functionality와 Security)
- 집계: 차원 점수의 조화 평균(선례 `SPEC-MODULE-001-audit-1.md`와 같은 비가중 방식). 참고용으로 가중 조화 평균도 적는다.
- 감사 방식: 읽기 전용. 아래 명령은 모두 이번 감사에서 이 트리에 직접 실행했다. 임시 파일은 세션 scratchpad에만 두었고, 저장소에 작성한 파일은 이 보고서 하나다.
- 상태: 완료

## 1. 판정 요약

| 차원 | 점수 | 판정 | 근거 요약 |
|------|------|------|-----------|
| Functionality (40%) | 93 | PASS | 다섯 테스트·분석 명령을 다시 실행해 모두 기대 결과(앱 `+88`, kolbi_ui `+61`). AC 14개 모두 테스트·명령에 연결됨. 코드의 색 값이 plan §A.1·§A.2·§A.3, 06 §3과 한 칸도 다르지 않음. 직접 계산한 대비에서 글자 짝 최저 4.70, 강조 짝 최저 3.55로 미달 없음. 칩 글자는 466c73b와 같음 |
| Security (25%) | 94 | PASS | 글꼴·라이선스 sha256이 progress §F와 일치, OFL.txt는 SIL OFL 1.1 전문. 추가된 줄에 비밀 값 없음. 새 pub 의존성 없음(바뀐 pubspec은 kolbi_ui의 `flutter:` 자산 블록뿐, `pubspec.lock` 무변경) |
| Craft (20%) | 84 | PASS | 범위 diff가 계획과 정확히 일치(16개 파일). 새 파일만 서식 적용, 고친 기존 파일은 466c73b부터 이미 서식 밖. RED 기록 있음. 앱 테스트 기준 kolbi_ui 줄 커버리지 98.3%. 감점: 가변 글꼴 굵기 축 미지정(F1), 어두운 무채색 칩 바탕 = 카드 색(F2) |
| Consistency (15%) | 89 | PASS | spec.md는 frontmatter 두 줄만 바뀜. §E.4의 16개 파일·SHA가 git과 일치. tech/structure/codemaps/06/04 주장이 코드와 맞음. SPEC-UX-001·EPIC 변경은 허용 범위 안. 감점: 06 §3 메모의 "계획에 없던 값" 표현(C1), §E.4 `sync_commit_sha` 미기재와 UX-001 항목 미갱신(C2) |
| **조화 평균** | **89.8** (가중 90.7) | | |
| **최종 판정** | | **PASS** | 필수 차원(Functionality, Security) 모두 통과 |

## 2. 기준 측정 (이번 감사, 이 트리)

```
$ dart test                                   (저장소 루트)
00:00 +2: All tests passed!

$ cd app && flutter --suppress-analytics test
00:08 +88: All tests passed!

$ cd app && flutter --suppress-analytics analyze
   info • Use the null-aware marker '?' rather than a null check via an 'if'. Try using '?' • test/support/fakes.dart:54:5 • use_null_aware_elements
1 issue found. (ran in 1.7s)          (기준선 info 1건뿐)

$ cd packages/kolbi_ui && flutter --suppress-analytics test && flutter --suppress-analytics analyze
00:01 +61: All tests passed!
Analyzing kolbi_ui...
No issues found! (ran in 1.4s)

$ cd packages/kolbi_core && dart test && dart analyze
00:00 +3: All tests passed!
No issues found!

$ flutter --version
Flutter 3.50.1 • channel stable
```

`flutter build web --debug`(AC-012)는 다시 실행하지 않았다. 빌드 크기는 progress §E.2 기록으로만 대조했다.

## 3. Functionality — 93, PASS

### 3.1 AC → 증거 연결

| AC | 증거 | 이번 감사에서 직접 확인한 것 |
|----|------|------------------------------|
| AC-001 | `theme_values_test.dart` "seed, roles, background, card and filled button follow plan §A.3" | kolbi_ui `+61` 안에서 통과. 테스트의 역할 표 리터럴(`theme_values_test.dart:10-20`)이 plan §A.3과 같고, `app_theme.dart`의 `copyWith`·`filledButtonTheme`(바탕 `seed`, 글자 `AppColors.white`)이 같은 값 |
| AC-002 | 같은 파일 "tone pairs follow plan §A.1 and keep their names" | 리터럴(`:40-57`)이 §A.1 표 10칸과 같음. `CardTone` = `neutral, attention, positive, caution, critical` |
| AC-003 | `tokens_contrast_test.dart`(48쌍 + `#635BFF` 글자 금지 2개 = 50) | 짝 값을 테마에서 직접 읽고(하드코딩 아님) 테스트 이름에 hex와 비율을 넣음. 모드당 글자 18쌍·강조 6쌍. 직접 계산 결과는 §3.3 |
| AC-004a | 같은 패키지 "dark scheme uses the 06 dark roles" | 통과 |
| AC-004b | `app/test/design_contrast_test.dart` "app follows the device dark mode" | `platformBrightnessTestValue`(`:29`) 사용 확인, 앱 `+88` 안에서 통과 |
| AC-005 | pubspec, `theme_values_test.dart`, `app/test/font_overflow_test.dart` | pubspec에 `family: Pretendard` + 자산 하나 + `assets/fonts/OFL.txt`. 테스트가 실제 TTF 바이트를 `FontLoader('packages/kolbi_ui/Pretendard')`로 올리고 360×640·글자 배율 2에서 `fontFamily == 'packages/kolbi_ui/Pretendard'`와 `takeException() == null`을 단언. `theme_test.dart:51-69`는 diff 없음 |
| AC-006 | `theme_values_test.dart` "every AppCard draws a 1px border" | `cardTheme.shape`에 `BorderSide(width: 1, color: outlineVariant)`, `common.dart` attention 분기 `width: 1` 확인 |
| AC-007 | `status_chip_test.dart` 18칸 × 두 모드 | 테스트 대응표(`:8-18`)가 plan §A.2와 같음. 칩 색은 `scheme.tone()`과 비교하고, 그 값은 AC-002가 hex로 고정하므로 간접적으로 고정됨. `check_circle_rounded`·`error_rounded` 부재 단언 있음 |
| AC-008 | 같은 파일 "category chips use the category tone and five distinct icons" | codePoint 다섯 개 `hasLength(5)` |
| AC-009 | `git diff 466c73b..HEAD -- app/lib` | `call_detail_screen.dart:299` 한 줄(`foregroundColor: Theme.of(context).colorScheme.onError`)뿐. 앱 `+88` |
| AC-010 | `git diff --stat 466c73b..HEAD -- server/ packages/kolbi_core/` | 출력 없음 |
| AC-011 | `git diff 466c73b..HEAD -- app/test/` | 기존 파일 변경은 `theme_test.dart:29` `0xFF1F8A70` → `0xFF635BFF` 한 줄. 새 파일 둘. `widgets_test.dart`·`dependency_rules_test.dart` diff 없음 |
| AC-012 | progress §E.2 | 기록만 대조(53,288 KB → 59,888 KB). 재측정 안 함 |
| AC-013 | `design_contrast_test.dart` "text contrast meets guidelines on design screens" | `meetsGuideline(textContrastGuideline)`(`:137`) 확인, 통과. `accessibility_test.dart`는 diff 없음 |

14 / 14 연결됨.

### 3.2 색 값 대조 (코드 ↔ plan ↔ 06)

- `tokens.dart` `AppColors` 16개 상수와 `app_theme.dart`의 역할 덮어쓰기 11개가 plan §A.3 표와 모두 같다(`primary` `#4F46E5`/`#A6ACFF`, `onPrimary` `#FFFFFF`/`#11131F`, `primaryContainer` `#EEEDFC`/`#23264A`, `surface` `#F7F8FC`/`#11131F`, `surfaceContainerLowest` `#FFFFFF`/`#1B1F33`, `onSurface` `#171B2E`/`#F2F3FA`, `onSurfaceVariant` `#5F6478`/`#A3A8C3`, `outlineVariant` `#E6E8F0`/`#2A2E45`, `error`·`onError` `#B91C1C`·`#FFFFFF` / `#FCA5A5`·`#11131F`).
- `StatusColors.tone()`·`live`의 10칸이 plan §A.1과 같고, 06 §3.1~§3.3의 글자용 값·칩 바탕·강조 값과도 같다.
- `status_chip.dart`의 범주 대응과 아이콘이 plan §A.2 18칸과 같다. 점 조건 `(status?.isLiveCall ?? false) || needsApproval`은 466c73b와 같은 조건이고, 점 칸에는 아이콘이 없다.
- 칩 글자: 466c73b `final label = needsApproval ? '승인 대기' : status.label;` → HEAD `final label = _label ?? (needsApproval ? '승인 대기' : status!.label);`. 상태 칩 경로는 같고, `StatusChip.category`에서만 `_label`을 쓴다. 라벨 `'상태: $label'`, 글자 스타일 `labelSmall` w700도 그대로다.

### 3.3 직접 계산한 WCAG 대비 (python, WCAG 2.1 상대 휘도)

```
text  #4F46E5 on #F7F8FC: 5.92        text  #4F46E5 on #FFFFFF: 6.29
text  #A6ACFF on #11131F: 8.77        text  #A6ACFF on #1B1F33: 7.72
text  #FFFFFF on #635BFF: 4.70        (채운 버튼, 전체 최저 글자 짝)
text  #5F6478 on #FFFFFF: 5.86        text  #5F6478 on #F7F8FC: 5.53
text  #A3A8C3 on #11131F: 7.87        text  #A3A8C3 on #1B1F33: 6.93
text  #FFFFFF on #B91C1C: 6.47        text  #11131F on #FCA5A5: 9.73   ([통화 끊기])
live L  fg #4F46E5 on #EEEDFC: 5.44 | accent #635BFF: 4.06
attn L  fg #A44A0C on #FEF3E2: 5.37 | accent #C2650A: 3.71
pos L   fg #157037 on #E9F7EE: 5.58 | accent #159343: 3.59
crit L  fg #B91C1C on #FDECEC: 5.66 | accent #DC2626: 4.23
neu L   fg #5F6478 on #F1F2F8: 5.25 | accent #7A7F94: 3.55
live D  fg #A6ACFF on #23264A: 6.88 | accent #A6ACFF: 6.88
attn D  fg #FBBF24 on #3A2A12: 8.28 | accent #FBBF24: 8.28
pos D   fg #4ADE80 on #13301F: 8.20 | accent #4ADE80: 8.20
crit D  fg #FCA5A5 on #3A1820: 8.31 | accent #FCA5A5: 8.31
neu D   fg #A3A8C3 on #1B1F33: 6.93 | accent #A3A8C3: 6.93
attn accent L on card #FFFFFF 4.07 / attn D on #1B1F33 9.75
neutral chip bg D vs card D 1.0 / neutral chip bg L vs card 1.12
```

- 글자 짝 4.5 미만: 없음(최저 4.70). 강조 짝 3.0 미만: 없음(최저 3.55). 06 §3.2·§3.3 표의 숫자와 소수 둘째 자리까지 같다.
- 칩 아이콘 색은 짝의 글자색이므로 아이콘도 글자 기준(≥ 5.25)을 넘는다.
- `caution`은 `neutral`과 같은 값이라 별도 위험 없음.

### 3.4 `fontVariations`와 가변 글꼴 굵기

- `grep -rn "fontVariations\|FontVariation" packages app/lib app/test` → 결과 없음.
- TTF 테이블 직접 읽기: `fvar` 축 `wght` 최소 45 · 기본 400 · 최대 930, `OS/2` 굵기 400. 파일은 가변 글꼴 하나이고 pubspec에 `weight:` 항목이 없다.
- 테마는 w600(`labelLarge`·`labelSmall`), w700(제목 셋, 칩 글자)을 쓴다. Flutter는 단일 가변 글꼴에서 `FontWeight`를 `wght` 축에 자동으로 옮겨 준다고 보장하지 않는다. 플랫폼·렌더러에 따라 기본 인스턴스(400)로 그려지거나 합성 굵게(fake bold)로 그려질 수 있다. 위젯 테스트는 글리프 굵기를 보지 않으므로 이 위험은 테스트로 잡히지 않는다(F1).

## 4. Security — 94, PASS

```
$ shasum -a 256 packages/kolbi_ui/assets/fonts/*
d31ddd9f2bed32fd7e302a205cf2380ba0de6529152d239ef99cfb6f261bfc04  packages/kolbi_ui/assets/fonts/OFL.txt
3090ccde0442bb347aa7685d9ba8b17436a60682df6e8f92a9a670de14056e22  packages/kolbi_ui/assets/fonts/PretendardVariable.ttf
```

- progress §F(`progress.md:242`)·§E.2(`:53`)·tech.md의 값과 두 파일 모두 일치. 크기 6,739,336 B는 `git diff --stat`의 `Bin 0 -> 6739336 bytes`와 같다.
- OFL.txt: 94줄, 첫 줄 `Copyright (c) 2021, Kil Hyung-jin (https://github.com/orioncactus/pretendard), with Reserved Font Name Pretendard.`, 본문 머리 `SIL OPEN FONT LICENSE Version 1.1 - 26 February 2007`, 절 `PREAMBLE`(13)·`DEFINITIONS`(29)·`PERMISSION & CONDITIONS`(48)·`TERMINATION`(81)·`DISCLAIMER`(85)이 모두 있다.
- 비밀 값: `git diff 466c73b..HEAD | grep -inE "api[_-]?key|secret|token\s*[:=]|password|BEGIN (RSA|PRIVATE)|sk-[A-Za-z0-9]{10}|AKIA"` → 결과 없음.
- 의존성: `git diff 466c73b..HEAD --name-only -- '*pubspec*'` → `packages/kolbi_ui/pubspec.yaml` 하나. 바뀐 내용은 `flutter: assets:`(OFL.txt)와 `fonts:` 블록뿐이고 `dependencies:`·`dev_dependencies:`는 그대로. `pubspec.lock`·`app/pubspec.yaml`·`kolbi_core/pubspec.yaml` diff 없음.
- `fonts.dart`는 번들 자산을 `rootBundle.loadString`으로 읽기만 한다. 네트워크·파일 시스템 접근 없음.
- 감점 사유(정보): 출처가 GitHub 태그 v1.3.9라는 것은 기록으로만 확인했다. 상위 배포본의 해시와 대조하지는 않았다(네트워크 미사용). 라이선스 화면 등록 호출이 아직 앱에 없다(F4). OFL 조건 2(라이선스 동봉)는 `OFL.txt`가 번들 자산으로 함께 배포되므로 충족된다.

## 5. Craft — 84, PASS

- 범위:
  - `git diff --stat 466c73b..HEAD -- server/ packages/kolbi_core/` → 출력 없음.
  - `app/lib` → `call_detail_screen.dart` 한 줄.
  - `app/test` → `theme_test.dart:29` 한 줄 + 새 파일 `design_contrast_test.dart`(167줄)·`font_overflow_test.dart`(98줄).
  - `git diff --name-only 466c73b..3de1cee` → 16개, plan §B 표와 같음.
- 서식(`dart format -o none --set-exit-if-changed`, 파일별): 새 파일 6개(`fonts.dart`, kolbi_ui 테스트 3개, 앱 테스트 2개)와 `kolbi_ui.dart`는 깨끗하다. 손으로 고친 기존 파일 6개(`app_theme.dart`, `tokens.dart`, `common.dart`, `status_chip.dart`, `theme_test.dart`, `call_detail_screen.dart`)는 서식 밖이지만, 466c73b 판도 같은 명령에서 이미 서식 밖이었다. 따라서 이번 SPEC이 만든 서식 차이가 아니며, "변경 파일에만 서식" 규칙과 §E.2 E6 기록에 맞는다.
- 테스트의 의미:
  - 대비 테스트는 테마에서 값을 읽으므로 값이 바뀌면 바로 실패한다.
  - 값 테스트는 hex 리터럴로 고정한다.
  - 칩 테스트는 18칸 전부와 두 모드를 돈다.
  - 글꼴 테스트는 실제 TTF를 올려 Ahem으로 돌아가는 일을 막는다.
  - RED 기록(progress §E.2 `:55-90`)에 실패 줄 원문이 있고, [통화 끊기] 수정이 없으면 `1.90` 미달로 실패한다는 기록도 있다(`:73`).
- 커버리지(선택 항목, 직접 측정): `cd app && flutter test --coverage --coverage-package kolbi_ui` → `00:10 +88: All tests passed!`, kolbi_ui 287/292줄 = **98.3%**. `app_theme.dart` 39/39, `fonts.dart` 4/4, `status_chip.dart` 47/48, `tokens.dart` 14/15.
- 감점: F1(가변 글꼴 굵기), F2(어두운 무채색 칩 윤곽 없음), F3(글꼴 6.7MB, 계획 가정의 3배 이상. 소유자 승인 있음).

## 6. Consistency — 89, PASS

- `git show e47e099 -- .moai/specs/SPEC-DESIGN-001/spec.md` → `status: draft → implemented`, `updated: 2026-11-26 → 2026-11-27` 두 줄뿐. 본문 변경 없음.
- §E.4 `planned_vs_changed_files` "16개, 계획 밖 파일 없음"이 git과 일치. `run_start_sha 466c73b`, `run_commit_sha 3de1cee`, M1 `7687615`, M2 `4430e31`, `run_evidence_commit_sha 5ee6eef`, `head_before_sync 797c0da`가 `git log`와 같다. `797c0da`는 LIFECYCLE·POLICY·FIVE-SPECS 파일 5개뿐이고 이 SPEC 경로와 겹치지 않는다.
- tech.md: 크기·sha256·출처·`registerKolbiFontLicenses()` 미호출(`grep -rn registerKolbiFontLicenses app/lib` → 결과 없음, 이번 감사에서도 확인)·빌드 크기·`fontVariations` 미지정이 모두 사실이다.
- structure.md·codemaps/modules.md: `assets/fonts/`, `fonts.dart`, `StatusCategory`, `StatusChip.category`·`iconOf`, 내부 `AppColors`(배럴 `kolbi_ui.dart`에 없음 확인), "대비 48쌍"(모드당 24 × 2 = 48 확인)이 코드와 맞는다.
- 06 §3 "구현 확정" 메모에서 sync 에이전트가 코드에서 끌어낸 두 사실:
  - 무채색 칩 바탕 밝은 `#F1F2F8`, 어두운 `#1B1F33`: `app_theme.dart`의 `CardTone.neutral || CardTone.caution` 분기와 일치. **확인됨.**
  - `caution` = 무채색: 같은 분기가 두 값을 함께 처리. **확인됨.**
  - "가장 낮은 글자 짝 4.70, 그다음 5.25": 직접 계산과 일치.
  - 다만 메모가 이 두 값을 "계획에 없던 값"이라 부르는 것은 부정확하다(C1).
- 04 §4 개정 블록: `caution` = 무채색, plan §A.2 링크, 씨앗 색 `#635BFF`. 코드와 맞는다.
- `8d6770f`(SPEC-UX-001)이 바꾼 것:
  - spec.md: `version 0.3.0 → 0.3.1`, HISTORY 한 행, OD-2·OD-4 두 행.
  - acceptance.md: AC-002 한 줄(`0xFF635BFF`, 구현 당시 값 병기).
  - 2파일, +5/−4. 그 밖의 REQ·AC 본문은 바뀌지 않았고, `updated`는 이미 2026-11-27이었다. 허용 범위 안이다.
- EPIC overview: 상태 줄의 `DESIGN-001 implemented`와 표 2행만 바뀌었다. 다른 SPEC 상태는 그대로다.
- 감점: C1, C2.

## 7. 발견 사항

| ID | 심각도 | 차원 | 내용 | 권고 |
|----|--------|------|------|------|
| F1 | Medium | Craft (Functionality 인접) | 가변 글꼴 하나(`wght` 45–930, 기본 400)를 `weight:` 항목과 `fontVariations` 없이 등록했다. w600·w700 글자(제목·버튼·칩)가 실기기에서 400으로 그려지거나 합성 굵게로 그려질 수 있다. 위젯 테스트로는 잡히지 않는다. run이 스스로 밝힌 위험이며 `device_check: pending`. | SPEC-SHELL-001 착수 전 소유자 실기기 확인. 굵기가 따라오지 않으면 테마 `TextStyle`에 `fontVariations: [FontVariation.weight(...)]`를 넣거나, 정적 굵기 파일을 `weight:`로 등록 |
| F2 | Low | Craft | 어두운 모드에서 무채색 칩 바탕 `#1B1F33`이 카드 색과 같다(대비 1.00). 카드 위의 "취소됨" 칩은 윤곽이 보이지 않는다. 밝은 모드도 1.12. 글자 대비(6.93)는 충분하다. N4로 이월됨. | 칩 바탕을 한 단계 밝히거나(`#23263A` 계열) 1px 선을 두는 방안을 SHELL 또는 후속 SPEC에서 결정 |
| F3 | Low | Craft | 글꼴 6.7MB, web 디버그 빌드 +6,600 KB. 계획 가정(약 2MB)의 3배 이상. 소유자 승인 있음. | 배포 전 한글 서브셋 또는 동적 서브셋 검토 |
| F4 | Low | Security(정보) | `registerKolbiFontLicenses()`가 `app/lib`에서 호출되지 않아 앱 라이선스 화면에 Pretendard OFL이 아직 없다. 자산 동봉으로 OFL 조건 2는 충족. SHELL-001로 이월됨. | SHELL-001 sync에서 호출 여부 확인 |
| C1 | Low | Consistency | 06 §3 메모가 무채색 칩 바탕 두 값을 "계획에 없던 값"이라 적었다. 두 값 모두 plan §A.1 표에 있고, `#F1F2F8`은 06 §3.2 대비 표에도 있다. 06 §3.1~§3.3 본 표에 행이 없다는 뜻이라면 그렇게 적는 편이 정확하다. 값 자체는 코드와 맞다. | 다음 06 수정 때 "06 표에 행이 없던 값(plan §A.1에서 정함)"으로 고침 |
| C2 | Info | Consistency | §E.4 `sync_commit_sha`가 실제 SHA(`e47e099`) 대신 "see git log"이다. `plan_g_items.SPEC-UX-001`이 "이 커밋에서 하지 않음"인 채로 남았다. 실제로는 `8d6770f`이 처리했다. | 완료 승격 때 §E.4에 `e47e099`, `8d6770f`을 적음 |

Critical·High 없음.

## 8. 검증하지 않은 것

- 실기기·실제 렌더러에서의 Pretendard 굵기와 글자 폭(F1). 위젯 테스트는 Ahem 또는 단일 화면 실글꼴 검사만 한다.
- `flutter build web --debug` 전후 크기(AC-012)는 다시 재지 않고 기록과만 대조했다.
- 글꼴 파일이 상위 저장소(orioncactus/pretendard v1.3.9) 배포본과 같은지. 네트워크를 쓰지 않았으므로 로컬 해시와 progress 기록의 일치만 확인했다.
- 서버 테스트. `server/` diff가 비어 있어 실행하지 않았다.
- `fromSeed`가 만든 덮어쓰지 않은 역할(N5)이 앞으로의 화면에서 쓰일 때의 대비. 현재 화면은 앱 전체 `textContrastGuideline` 검사가 덮는다.

## 9. 점수 계산

- 비가중 조화 평균: 4 / (1/93 + 1/94 + 1/84 + 1/89) = **89.8**
- 가중 조화 평균(참고): 1 / (0.40/93 + 0.25/94 + 0.20/84 + 0.15/89) = **90.7**
- 필수 차원 Functionality 93, Security 94 모두 PASS → **최종 PASS**
