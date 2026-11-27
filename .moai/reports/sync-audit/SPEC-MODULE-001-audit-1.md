# Sync 감사 보고서 — SPEC-MODULE-001 (1차)

- 감사 대상: main HEAD `2f9835d`(sync 커밋, 아직 push 전). run 시작 `9814f24`, 구현 커밋 `509f972`·`96203c5`·`128af3e`·`84ef98a`·`09ac0aa`(M1~M5), run 기록 커밋 `6cdf8af`(push 완료)
- 평가 프로필: `.moai/config/evaluator-profiles/default.md` (Functionality 40%, Security 25%, Craft 20%, Consistency 15%. 필수 통과 차원은 Functionality와 Security)
- 집계: 차원 점수의 조화 평균(선례 `SPEC-UX-001-audit-1.md`와 같은 비가중 방식). 참고용으로 가중 조화 평균도 적는다.
- 감사 방식: 읽기 전용. 아래 명령은 모두 이번 감사에서 이 트리에 직접 실행했다. 작성한 파일은 이 보고서 하나다.
- 상태: 완료

## 1. 판정 요약

| 차원 | 점수 | 판정 | 근거 요약 |
|------|------|------|-----------|
| Functionality (40%) | 92 | PASS | 다섯 테스트·분석 명령을 다시 실행해 모두 기대 결과를 얻음(앱 `+84` = 80 + 4). AC 15개 모두 증거에 연결됨. 금지 import grep 0줄, `app/test/` 변경은 `architecture_test.dart` 하나, `server/` diff 없음, 옮긴 파일 4개 대조 결과 import 줄만 다름 |
| Security (25%) | 95 | PASS | 추가된 줄에 비밀 값 없음(`Bearer $token`은 옮긴 기존 코드). 기존 잠금 버전은 하나도 바뀌지 않았고, 새 항목은 `test` 1.32.0과 그 전이 의존 22개뿐 |
| Craft (20%) | 80 | UNVERIFIED (커버리지) | 규칙 테스트가 "검사 파일 0개" 통과를 막고 허용 목록의 양방향 차이를 단언하며, RED 기록도 있음. 커버리지는 측정하지 않음. 패키지에 `analysis_options.yaml` 없음 |
| Consistency (15%) | 88 | PASS | spec.md는 frontmatter 두 줄만 바뀜. §E.4의 56개 파일과 커밋 SHA가 git 이력과 일치. 문서의 의존·파일 수·줄 번호·허용 목록이 실제와 맞음. 사소한 표현 차이 2건(C1·C2) |
| **조화 평균** | **88.4** (가중 89.4) | | |
| **최종 판정** | | **PASS** | 필수 차원(Functionality, Security) 모두 통과 |

## 2. 기준 측정 (이번 감사, 이 트리)

```
$ dart test                                   (저장소 루트)
00:00 +2: All tests passed!
root exit=0

$ cd packages/kolbi_core && dart test && dart analyze
00:00 +3: All tests passed!
Analyzing kolbi_core...
No issues found!

$ cd packages/kolbi_ui && flutter --suppress-analytics test && flutter --suppress-analytics analyze
00:00 +4: All tests passed!
Analyzing kolbi_ui...
No issues found! (ran in 1.5s)

$ cd app && flutter --suppress-analytics test
00:07 +84: All tests passed!
app test exit=0

$ cd app && flutter --suppress-analytics analyze
   info • Use the null-aware marker '?' rather than a null check via an 'if'. Try using '?' • test/support/fakes.dart:54:5 • use_null_aware_elements
1 issue found. (ran in 1.7s)
app analyze exit=1   (기준선 info 1건뿐)

$ grep -c "^\s*test(\|^\s*testWidgets(" app/test/architecture_test.dart
4                    (84 = 80 + 4, AC-013의 N 계산과 일치)
```

서버 테스트와 `flutter build web --debug`는 다시 실행하지 않았다. 서버 파일이 바뀌지 않았음은 diff로 확인했고(§3.3), 빌드 결과는 progress.md §E.2 기록으로만 대조했다.

## 3. Functionality — 92, PASS

### 3.1 AC → 증거 연결

| AC | 증거 | 이번 감사에서 직접 확인한 것 |
|----|------|------------------------------|
| AC-001 | 루트 `test/workspace_test.dart`(2개) | `dart test` `+2`. 루트 `workspace:` = `app`, `packages/kolbi_core`, `packages/kolbi_ui`. `git ls-files -- '*pubspec.lock'` → `pubspec.lock` 한 줄, `test ! -e app/pubspec.lock` 성공 |
| AC-002 | 앱 test·analyze, `name: callmate` | `+84`, 기준선 info 1건, `app/pubspec.yaml:1` `name: callmate`. 빌드는 기록으로만 확인 |
| AC-003 | kolbi_core `dart test`, pubspec | `+3`. `dependencies:` = `characters`, `http`, `intl`, `meta`, `web_socket_channel`. Flutter 의존 없음. `src/` 9개 파일 |
| AC-004 | `packages/kolbi_core/test/dependency_rules_test.dart` | 통과. 금지 목록 7개가 AC 문구와 같고 `expect(files, isNotEmpty)`가 있음. grep 0줄(§3.2) |
| AC-005 | `packages/kolbi_ui/test/widgets_test.dart` | `+4`. `dependencies:` = `flutter`, `kolbi_core`, `material_ui`. "the barrel exposes the shared UI names" 테스트가 통과 |
| AC-006 | `packages/kolbi_ui/test/dependency_rules_test.dart` | 통과. 금지 목록 6개가 AC 문구와 같음. grep 0줄 |
| AC-007 | architecture_test "app does not reach into package src" | 통과. `ls packages/kolbi_*/lib` → 각 패키지에 배럴 하나와 `src/`만 있음 |
| AC-008 | architecture_test "legacy paths only re-export", "every package:callmate import in the tests points at a file" | 통과. `legacyPaths` 14개가 plan §B.4와 같음(`approval_comment.dart` 포함) |
| AC-009 | 두 `calls_repository.dart`의 선언 grep | 클래스·이벤트는 kolbi_core 파일 `:6,:10,:15,:20,:26`에만, 공급자는 앱 파일 `:8,:15,:17`에만 있음. 앱 파일이 다섯 이름을 `show`로 다시 내보냄 |
| AC-010 | kolbi_core `models_test.dart` "approval comment helpers…" | 통과. `CodePointLengthLimitingFormatter`는 kolbi_core 쪽 파일에서 빠짐(§3.4 diff) |
| AC-011 | 세 규칙 테스트, 허용 목록 | 통과. `allowedCrossFeature`는 `settings_screen.dart -> trust_notice.dart` 한 항목. 양방향 `difference` 단언이 있음. RED (1)(2)는 progress 기록으로 확인 |
| AC-012 | `models_test.dart`의 옛 JSON 테스트, `widgets_test.dart`의 토큰·AppCard 테스트 | 세 테스트가 존재하고 통과. 토큰 `[4, 8, 12, 16, 20, 24, 32]`, `kMinTapTarget` 48 |
| AC-013 | 앱 `+84`, `app/test/` diff | §3.3 |
| AC-014 | `server/` diff | §3.3 |
| AC-015 | 세 분석기, 옮긴 파일 대조 | 세 분석 결과는 §2. 옮긴 파일 대조는 표본 5개(§3.4) |

### 3.2 금지 import grep (AC-003/004/006/007)

```
$ grep -rnE "package:(flutter|flutter_riverpod|riverpod|go_router|share_plus|shared_preferences|kolbi_ui|callmate)/|dart:ui" packages/kolbi_core/lib
exit=1   (출력 0줄)

$ grep -rnE "package:(flutter_riverpod|riverpod|go_router|share_plus|shared_preferences|callmate)/|package:kolbi_core/src/" packages/kolbi_ui/lib
exit=1   (출력 0줄)

$ grep -rnE "package:kolbi_(core|ui)/src/" app/lib app/test
app/test/architecture_test.dart:64:          if (uri.startsWith('package:kolbi_core/src/') ||
app/test/architecture_test.dart:65:              uri.startsWith('package:kolbi_ui/src/'))
         (규칙 테스트 안의 문자열뿐, 실제 import 0줄)
```

앱 소스에서 옛 경로를 가져오는 import·export 줄도 없다(`grep -rnE "^(import|export) .*(core/network/|core/theme/|…)" app/lib` 출력 0줄). 앱의 `package:kolbi_*` 참조 중 배럴이 아닌 것은 다시 내보내기 파일 첫 줄의 주석뿐이다.

### 3.3 변경 범위 (AC-013, AC-014)

```
$ git diff --stat 9814f24..HEAD -- app/test/
 app/test/architecture_test.dart | 126 ++++++++++++++++++++++++++++++++++++++++
 1 file changed, 126 insertions(+)

$ git diff --stat 9814f24..HEAD -- server/
(출력 없음)
```

화면 문구 보조 확인: `git diff 9814f24..HEAD -- app/lib packages`에서 한글 문자열이 든 `+` 줄 48개, `-` 줄 40개. `comm -23`으로 `-` 쪽에 짝이 없는 `+` 줄을 뽑으면 8줄이 나오고, 모두 새 패키지 테스트(`'가나다'`, `'통화 결과'`, `'동네 치과'` 등)다. 제품 코드의 문구는 바뀌지 않았다.

### 3.4 동작 보존 표본 대조 (9814f24 원본 → 새 위치)

```
=== app/lib/core/network/api_client.dart -> packages/kolbi_core/lib/src/network/api_client.dart
exit=0   (완전히 같음)
=== app/lib/features/calls/domain/call_models.dart -> packages/kolbi_core/lib/src/models/call_models.dart
1c1
< import 'package:flutter/foundation.dart';
---
> import 'package:meta/meta.dart';
=== app/lib/core/widgets/common.dart -> packages/kolbi_ui/lib/src/widgets/common.dart
3c3
< import '../network/api_client.dart';
---
> import 'package:kolbi_core/kolbi_core.dart';
=== app/lib/features/calls/presentation/widgets/outcome_card.dart -> packages/kolbi_ui/lib/src/widgets/outcome_card.dart
3,6c3,6   (상대 경로 import 4줄 → 패키지 안 상대 경로 3줄 + kolbi_core 배럴 1줄)
=== app/lib/features/calls/domain/approval_comment.dart -> packages/kolbi_core/lib/src/approval_comment.dart
1,2c1     flutter/services + flutter/widgets show StringCharacters → package:characters/characters.dart
31,47d29  CodePointLengthLimitingFormatter 블록 삭제(kolbi_ui로 이동, AC-010)
```

다섯 파일 모두 import 줄과 계획된 분리만 다르고 본문은 같다.

### 3.5 감점 이유

- 앱 빌드(`flutter build web --debug`)와 서버 `npm test`·`typecheck`는 다시 실행하지 않고 기록으로만 확인했다.
- 옮긴 파일 16개 중 5개만 직접 대조했다. 나머지는 progress §E.2의 `ac015-compare.txt`(`compared=16 … bad=0`) 기록에 기댄다.

## 4. Security — 95, PASS

```
$ git diff 9814f24..HEAD | grep -E '^\+' | grep -inE 'api[_-]?key|secret|password|bearer |sk-[A-Za-z0-9]{10}|AKIA|-----BEGIN|https?://[^ ]*@|token\s*[:=]\s*["'"'"'][A-Za-z0-9]{8}'
1440:+        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
```

이 한 줄은 옮긴 `api_client.dart`의 기존 코드다(`git show 9814f24:app/lib/core/network/api_client.dart`의 43행과 같다). 값을 박아 넣은 것이 아니다. 추가된 URL은 잠금 파일의 `https://pub.dev`뿐이다.

의존성:

```
$ git diff 9814f24..HEAD -- app/pubspec.yaml
+resolution: workspace
+  kolbi_core: ^0.1.0
+  kolbi_ui: ^0.1.0
```

- 새 pubspec: kolbi_core는 `characters`, `http`, `intl`, `meta`, `web_socket_channel`과 dev `test`, kolbi_ui는 `flutter`, `kolbi_core`, `material_ui`와 dev `flutter_test`, 루트는 dev `test ^1.29.0`(소유자 승인). 모두 AC-003·AC-005와 기록된 결정에 맞는다.
- 잠금 파일(`app/pubspec.lock` → `pubspec.lock`, R078): 9814f24의 옛 잠금과 패키지별 버전을 맞대 본 결과는 "버전 바뀜 0, 빠짐 0, 추가 22"다. 추가된 22개는 `test` 1.32.0, `test_core`, `analyzer`, `coverage`, `shelf*`, `watcher` 등 `test`의 전이 의존이다. 기존 직접·전이 의존 버전은 하나도 바뀌지 않았다.
- 네트워크 코드는 옮기기만 했고 본문이 같다(§3.4).

5점 감점은 OWASP 항목별 점검을 따로 하지 않았기 때문이다(구조 이동만 있는 변경이라 해당 범위가 좁다).

## 5. Craft — 80, UNVERIFIED (커버리지)

- 규칙 테스트의 품질: 세 규칙 테스트 모두 `expect(files, isNotEmpty, reason: 'no files checked')`로 빈 목록 통과를 막는다. `architecture_test.dart`는 허용 목록을 `found.difference(allowed)`와 `allowed.difference(found)`로 양쪽에서 단언해, 낡은 허용 항목도 실패로 잡는다. RED 기록(AC-004, AC-006, AC-011 (1)(2), 루트 워크스페이스, M5의 낡은 `call_models.dart` 항목)이 progress §E.2에 실패 메시지 원문과 함께 있다.
- 한계(Info): 규칙 테스트는 한 줄짜리 `import`/`export` 지시문을 글자로 대조한다. 여러 줄에 걸친 지시문과 조건부 import는 놓칠 수 있다. acceptance.md의 잔여 위험에 이미 적혀 있다.
- 금지 목록의 범위(Low, K1): kolbi_ui 규칙 테스트는 `package:riverpod/`를, kolbi_core 규칙 테스트는 `package:go_router/`·`package:share_plus/`를 금지하지 않는다. AC 문구가 정한 목록과는 정확히 같고, 지금 코드의 grep 결과도 0줄이며, 해당 패키지가 pubspec에 없어 실제로 가져올 수도 없다. 다만 나중에 의존이 추가되면 테스트로는 잡히지 않는다.
- 분석 설정(Low, K2): `find packages -name analysis_options.yaml` 출력이 없다. 두 패키지의 `No issues found!`는 기본 규칙 기준이며, 앱의 `flutter_lints` 규칙보다 느슨하다. progress §E.2 Deviations 5에 기록되어 있다.
- 커버리지: 이번 감사에서 측정하지 않았고 run·sync 기록에도 수치가 없다(`coverage: not-measured`). 85% 기준 충족 여부는 **UNVERIFIED**다. 필수 차원이 아니므로 판정을 바꾸지 않는다.

## 6. Consistency — 88, PASS

### 6.1 spec.md와 EPIC 개요

```
$ git diff 9814f24..HEAD -- .moai/specs/SPEC-MODULE-001/spec.md | grep -E '^[+-][^+-]'
-status: draft
+status: implemented
-updated: 2026-11-26
+updated: 2026-11-27
```

spec.md는 frontmatter 두 줄만 바뀌었다. `.moai/specs/` 아래에서 바뀐 파일은 이 SPEC의 spec.md·progress.md와 `EPIC-KOLBI-APP/overview.md` 셋이다. overview 변경은 두 줄이고, 둘 다 SPEC-MODULE-001의 상태(`implemented(0.2.2, 2026-11-27)`)만 고쳤다. 다른 SPEC 행은 그대로다. `.moai/config/` diff는 없다.

### 6.2 progress.md §E.4와 git 이력

| §E.4 주장 | 실제 |
|-----------|------|
| `git diff --name-only 9814f24..09ac0aa -> 56 files` | `56` (이름 바꾸기 감지 여부와 무관, `--no-renames`면 57) |
| `run_commit_sha: 09ac0aa`, M1 `509f972` .. M5 `09ac0aa` | `git log --oneline 9814f24..HEAD`의 순서와 같음 |
| `run_evidence_commit_sha: 6cdf8af`, push 완료, sync 커밋은 미push | `git rev-list --left-right --count origin/main...HEAD` → `0	1` |
| 루트 `+2`, 앱 `+84`, kolbi_core `+3`, kolbi_ui `+4` | 이번 감사 결과와 같음(§2) |
| 보호 경로 diff = `architecture_test.dart \| 126 +`만 | 같음(§3.3) |
| 잠금 변경은 `test` 1.32.0의 표시가 transitive → direct dev로 바뀐 것뿐 | 루트 dev 의존 추가 전후 비교로서는 맞다. 9814f24와 비교하면 kolbi_core dev `test`로 22개가 추가되었고, §E.2 "Dependency versions"가 이를 따로 적고 있다 |

### 6.3 프로젝트 문서와 실제

| 문서 주장 | 확인 |
|-----------|------|
| codemaps/dependencies.md: kolbi_core `characters ^1.4.1, http ^1.6.0, intl ^0.20.3, meta ^1.19.0, web_socket_channel ^3.0.3; dev test ^1.29.0`, kolbi_ui `flutter, kolbi_core ^0.1.0, material_ui ^1.1.0; dev flutter_test`, 루트 dev `test ^1.29.0` | 세 pubspec 원문과 같음 |
| 11 §1.1: `app/lib` 30개 파일(다시 내보내기 14), `packages/*/lib` 18개(배럴 2 + `src/` 16) | `find` 결과 30 / 18 / 16 |
| 11 §1.1: `flutter_riverpod: ^3.5.0`, Flutter 3.50.1 | `app/pubspec.yaml:14`, `flutter --version` → `Flutter 3.50.1` |
| 11 §1.1 줄 번호: `settings_screen.dart:8`, `app_router.dart:5-10`, `approval_card.dart:10`, `common.dart:3`, `:269` | 각 줄이 문서가 말한 import·선언과 같음 |
| 11 §2.4 R-1·R-2 금지 목록, structure.md의 규칙 테스트 표 | 두 규칙 테스트의 `forbidden` 상수와 글자 단위로 같음 |
| R-3, 12 §3, structure.md: 허용 목록 1건(`trust_notice.dart`), 2건에서 시작 | `allowedCrossFeature` 한 항목. M5의 낡은 항목 RED 기록과 일치 |
| README: 루트·앱·패키지 테스트 명령 | 이번 감사에서 같은 명령으로 실행해 통과 |
| modules.md 「공용 패키지」 절의 `lib/src/` 파일 목록 | `git diff --name-status`의 `A` 항목과 같음 |

### 6.4 발견

- **C1 (Low)**: `codemaps/modules.md` 표의 `network/api_client.dart` 사용처 열에 `core/widgets/common.dart`가 그대로 남아 있다. 지금 `ApiClient`를 쓰는 곳은 `packages/kolbi_ui/lib/src/widgets/common.dart`이고, 앱 쪽 `common.dart`는 다시 내보내기 파일이다. 사용처 열 전반이 옛 경로 기준이라 독자가 헷갈릴 수 있다.
- **C2 (Info)**: §E.4의 `sync_commit_sha`는 SHA 대신 "see git log"다. 커밋이 자기 SHA를 담을 수 없으므로 피할 수 없고, 실제 sync 커밋은 `2f9835d`다.
- **C3 (Info)**: acceptance.md 제목은 `0.2.1`, spec.md는 `0.2.2`다. 9814f24 이전부터 그랬고 이번 sync에서 생긴 차이가 아니다.

## 7. 발견 목록

| ID | 심각도 | 차원 | 내용 |
|----|--------|------|------|
| K1 | Low | Craft | 규칙 테스트 금지 목록이 AC 문구에만 맞춰져 있다(kolbi_ui에 `package:riverpod/`, kolbi_core에 `go_router`·`share_plus` 없음). 지금은 pubspec에 해당 의존이 없어 실제 위험은 없다 |
| K2 | Low | Craft | 패키지에 `analysis_options.yaml`이 없어 분석이 앱보다 느슨하다(기록된 편차) |
| K3 | Info | Craft | 커버리지 미측정 — UNVERIFIED |
| K4 | Info | Craft | 글자 대조 방식 규칙 테스트의 한계(여러 줄·조건부 import). 잔여 위험으로 기록됨 |
| C1 | Low | Consistency | modules.md 사용처 열에 옛 경로 `core/widgets/common.dart`가 남아 있음 |
| C2 | Info | Consistency | §E.4 `sync_commit_sha` 자리표시(불가피) |
| C3 | Info | Consistency | acceptance 0.2.1 / spec 0.2.2 차이(이전부터 있던 것) |

Critical·High·Medium은 없다.

## 8. 확인하지 않은 것

- 테스트 커버리지(`--coverage` 미실행).
- 앱 빌드(`flutter build web --debug`)와 서버 `npm test`·`npm run typecheck` 재실행. progress 기록으로만 확인했다.
- RED 기록(임시 위반 파일로 테스트가 실패하는지)의 재현. progress의 실패 메시지 원문만 읽었다.
- 옮긴 파일 16개 중 11개의 줄 단위 대조. 5개 표본만 직접 diff했다.
- 루트에서 `flutter pub get`을 다시 실행하는 것(트리를 바꿀 수 있어 하지 않음). 잠금 파일은 git 내용으로만 비교했다.
- 실기기·시뮬레이터 실행.
