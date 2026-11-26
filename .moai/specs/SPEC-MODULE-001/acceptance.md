# SPEC-MODULE-001 인수 기준 (0.2.1)

## 공통 검증 명령

워크스페이스 루트:

```bash
flutter --suppress-analytics pub get
```

앱(작업 디렉터리 `app/`):

```bash
flutter --suppress-analytics test
flutter --suppress-analytics analyze
```

패키지:

```bash
(cd packages/kolbi_core && dart test && dart analyze)
(cd packages/kolbi_ui && flutter --suppress-analytics test && flutter --suppress-analytics analyze)
```

변경 범위(저장소 루트):

```bash
git diff --stat <run_start_sha> -- server/ app/test/
```

선행: SPEC-UX-001 `status: completed`. 기준선: 2026-11-26 작업 트리에서 `cd app && flutter --suppress-analytics test` → `+80: All tests passed!`(plan-phase에서 실행해 확인). run-phase 시작 시 manager-develop이 `run_start_sha`, 위 앱 명령 두 개의 결과, `flutter analyze`의 문제 수, 앱 빌드(`flutter build web --debug`) 결과, 서버 `npm test`·`typecheck` 결과를 `progress.md` §E.2 첫 부분에 다시 기록한다. 빌드가 기준선에서 실패하면 성공하는 다른 플랫폼 빌드 하나를 기준으로 정해 기록한다.

규칙: 서식 도구는 이 SPEC이 새로 만든 파일에만 쓴다. 옮긴 파일 본문은 서식하지 않는다. 방법론은 DDD(기존 테스트를 보존 기준으로 삼음).

## AC-001 — 워크스페이스 (REQ-001)

- **Given** 저장소 루트
- **When** `flutter --suppress-analytics pub get`을 루트에서 실행하면
- **Then** 종료 코드가 0이고, 루트 `pubspec.yaml`의 `workspace:` 목록이 정확히 `app`, `packages/kolbi_core`, `packages/kolbi_ui`이며, 세 구성원의 `pubspec.yaml`에 `resolution: workspace`가 있고, 잠금 파일이 루트에만 있다: `git ls-files -- '*pubspec.lock'`의 결과가 정확히 `pubspec.lock` 한 줄이고, `test ! -e app/pubspec.lock`이 성공한다(`.claude/worktrees/` 아래 다른 작업 트리의 잠금 파일은 검사에서 빠짐 — plan-audit D2). `pub get` 뒤 `git status --porcelain --untracked-files=all | grep -c dart_tool`이 0이다(`packages/`가 아직 추적 전이라 펼쳐 봐야 함, plan-audit 3차 N10)(루트 `.gitignore`의 `.dart_tool/`, plan-audit 2차 N3)
- 확인: 명령 출력과 두 검사 결과를 `progress.md`에 기록

## AC-002 — 앱 명령 유지 (REQ-002)

- **Given** AC-001이 통과한 상태
- **When** `app/`에서 `flutter --suppress-analytics test`, `flutter --suppress-analytics analyze`, 기준선 빌드 명령(기본 `flutter build web --debug`)을 실행하면
- **Then** 세 명령이 지금과 같은 위치에서 성공하고(분석은 기준선 이하), `app/pubspec.yaml`의 `name:`은 `callmate`다
- 확인: 명령 출력, `grep -n '^name:' app/pubspec.yaml`

## AC-003 — kolbi_core는 순수 Dart (REQ-003)

- **Given** `packages/kolbi_core`
- **When** `dart test`를 실행하면(Flutter 테스트 실행기 아님)
- **Then** 통과하고, `packages/kolbi_core/pubspec.yaml`의 `dependencies:`·`dev_dependencies:` 어디에도 `flutter`·`flutter_test`가 없으며 `dependencies:`가 `http`, `web_socket_channel`, `intl`, `meta`, `characters`만 담는다. `lib/`에 Flutter import가 없다(AC-004). `plan.md` §B.1의 옮겨 갈 파일이 모두 있다
- 확인: `dart test` 출력, `pubspec.yaml` 원문, `ls packages/kolbi_core/lib/src/**`

## AC-004 — kolbi_core 금지 import (REQ-004)

- **Given** `packages/kolbi_core/lib/` 아래 모든 `.dart` 파일
- **When** `packages/kolbi_core/test/dependency_rules_test.dart`를 실행하면
- **Then** `package:flutter/`, `dart:ui`, `package:flutter_riverpod/`, `package:riverpod/`, `package:shared_preferences/`, `package:kolbi_ui/`, `package:callmate/`를 담은 import·export 줄이 0줄이고, 테스트가 검사한 파일 수가 1 이상임을 단언한다(빈 목록 통과 방지)
- 보조 확인: `grep -rnE "package:flutter/|dart:ui|package:callmate/" packages/kolbi_core/lib` 출력 없음
- RED: 규칙 테스트를 M2에서 먼저 쓰고, 일부러 금지 import 한 줄을 넣은 임시 파일로 실패를 한 번 확인한 뒤 지운다(실패 출력은 `progress.md`에 기록)

## AC-005 — kolbi_ui 구성 (REQ-005)

- **Given** `packages/kolbi_ui`
- **When** `flutter --suppress-analytics test`를 실행하면
- **Then** 통과하고, `pubspec.yaml`의 `dependencies:`가 `flutter`, `material_ui`, `kolbi_core`만 담으며, `plan.md` §B.2의 옮겨 갈 파일이 모두 있고, 배럴 파일이 `AppCard`, `SectionCard`, `MessageView`, `PulsingDot`, `ResponsiveBody`, `BulletList`, `describeError`, `CardTone`, `AppTheme`, `StatusChip`(파일의 공개 위젯 이름), `OutcomeCard`, `TranscriptView`, `CodePointLengthLimitingFormatter`를 공개한다
- 확인: 테스트 출력, `pubspec.yaml` 원문. 공개 이름은 패키지 테스트 파일이 배럴 하나만 가져와 각 이름을 참조해 컴파일되는 것으로 확인(정확한 위젯 클래스 이름은 옮기기 전 파일의 선언 그대로)

## AC-006 — kolbi_ui 금지 import (REQ-006)

- **Given** `packages/kolbi_ui/lib/` 아래 모든 `.dart` 파일
- **When** `packages/kolbi_ui/test/dependency_rules_test.dart`를 실행하면
- **Then** `package:callmate/`, `package:go_router/`, `package:flutter_riverpod/`, `package:shared_preferences/`, `package:share_plus/`, `package:kolbi_core/src/`를 담은 import·export 줄이 0줄이고, 검사한 파일 수가 1 이상이다

## AC-007 — 배럴만 가져오기 (REQ-007)

- **Given** `app/lib/`, `app/test/`, `packages/kolbi_ui/lib/`
- **When** `app/test/architecture_test.dart`와 AC-006 테스트를 실행하면
- **Then** `package:kolbi_core/src/`와 `package:kolbi_ui/src/`를 가져오는 줄이 0줄이다. 각 패키지의 구현 파일은 모두 `lib/src/` 아래에 있고 `lib/` 바로 아래에는 배럴 파일 하나만 있다
- 확인: 테스트 출력, `ls packages/kolbi_core/lib packages/kolbi_ui/lib`

## AC-008 — 옛 경로 유지 (REQ-008)

- **Given** `plan.md` §B.4의 14개 옛 경로
- **When** 각 파일을 읽으면
- **Then** 주석을 뺀 파일 내용이 `export` 지시문만으로 이루어져 있고(여러 줄 `show` 목록 허용), 기존 테스트가 가져오는 `package:callmate/...` 경로 24개(`grep -h "^import 'package:callmate" app/test/*.dart app/test/support/*.dart | sort -u`)가 모두 존재하는 파일을 가리킨다. 기존 테스트의 컴파일 성공(AC-013)이 공개 이름 유지의 증거다
- 확인: `app/test/architecture_test.dart`의 테스트 "legacy paths only re-export"가 §B.4의 14개 파일(`approval_comment.dart` 포함)을 읽어 주석을 지운 뒤 `;`로 나눈 각 문장이 `export`로 시작함을 단언(줄 단위 grep은 여러 줄 `show` 목록을 잘못 걸러 쓰지 않음 — plan-audit D4). 24개 경로의 `ls` 결과

## AC-009 — 서버 접근 파일 나누기 (REQ-009)

- **Given** 이동 후의 `app/lib/features/calls/data/calls_repository.dart`와 `packages/kolbi_core/lib/src/data/calls_repository.dart`
- **When** 두 파일을 읽으면
- **Then** `class CallsRepository`, `sealed class CallsEvent`, `TasksSnapshot`, `TaskUpdated`, `TaskDeleted` 선언은 `kolbi_core` 파일에만 있고, `apiClientProvider`, `callsRepositoryProvider`, `serverInfoProvider` 선언은 앱 파일에만 있으며, 앱 파일이 옮긴 다섯 이름을 다시 내보낸다. 테스트 대역 `FakeCallsRepository extends CallsRepository`(`app/test/support/fakes.dart:77`)가 고치지 않고 컴파일된다
- 확인: `grep -n "class \|final .*Provider" <두 파일>` 출력

## AC-010 — 승인 코멘트 나누기 (REQ-010)

- **Given** 이동 후의 세 파일(`kolbi_core`의 `approval_comment.dart`, `kolbi_ui`의 `code_point_formatter.dart`, 앱의 옛 경로)
- **When** 세 파일을 읽고 `kolbi_core` 테스트를 실행하면
- **Then** 상수 3개와 함수 4개(`codePointLength`, `truncateToCodePoints`, `withQuickReply`, `hasSensitiveDigits`)는 `kolbi_core`에, `CodePointLengthLimitingFormatter`는 `kolbi_ui`에만 선언되어 있고, 옛 경로가 여덟 이름을 모두 다시 내보낸다. `kolbi_core` 테스트가 `truncateToCodePoints('가나다', 2) == '가나'`와 `hasSensitiveDigits('카드 1234 5678 9012 3456') == true`를 `dart test`로 확인한다(plan-audit에서 지금 함수로 `true`임을 확인)

## AC-011 — 의존 규칙 테스트 셋 (REQ-011)

- **Given** 세 의존 규칙 테스트
- **When** 실행하면
- **Then** 모두 통과한다. 앱 테스트의 기능 간 규칙 허용 목록은 M2~M4에서 두 항목(`settings_screen.dart` → `features/calls/domain/call_models.dart`, → `features/calls/presentation/trust_notice.dart`), M5 이후 정확히 한 항목(`trust_notice.dart`)이고, (1) 허용 목록 밖의 기능 간 import를 임시로 하나 넣으면 실패하고, (2) 허용 목록의 import를 임시로 지우면 "허용 목록 항목이 더 이상 없음"으로 실패한다(두 실패 출력을 `progress.md`에 기록한 뒤 임시 변경을 되돌림)
- 테스트: `app/test/architecture_test.dart` — "features do not import each other", "app does not reach into package src"

## AC-012 — 패키지 테스트 (REQ-012)

- **Given** 두 패키지
- **When** 공통 검증 명령의 패키지 명령을 실행하면
- **Then** `kolbi_core`: `CallTask.fromJson`이 `outcome`·`approvals`가 없는 옛 작업 JSON을 읽어 `TaskStatus`와 빈 목록을 돌려주는 테스트 1건, AC-010의 승인 코멘트 테스트가 통과한다. `kolbi_ui`: 토큰 값(간격 4·8·12·16·20·24·32, 최소 누르는 영역 48)을 단언하는 테스트 1건과 `AppCard`를 띄워 제목 글자를 찾는 위젯 테스트 1건이 통과한다

## AC-013 — 동작 불변 (REQ-013)

- **Given** run 시작 시점의 `app/test/` 내용
- **When** run 끝에 `cd app && flutter --suppress-analytics test`와 `git diff --stat <run_start_sha> -- app/test/`를 실행하면
- **Then** 테스트 결과 마지막 줄이 `+N: All tests passed!`이고 N = 80 + `architecture_test.dart`의 테스트 수다(기존 80개 모두 통과, plan-audit D9), `git diff` 결과에는 새 파일 `app/test/architecture_test.dart`만 있으며 기존 12개 파일의 변경이 없다
- 보조: 화면 문구 변경 없음 — `git diff <run_start_sha> -- app/lib packages | grep -E "^\+.*'[가-힣]"`의 줄마다 같은 문자열의 `-` 줄이 `app/lib` 쪽에 있음을 확인(옮긴 문구가 `packages/`로 갔으므로 둘 다 봄, plan-audit 2차 N5)

## AC-014 — 서버 불변 (REQ-014)

- **Given** run 시작 시점
- **When** run 끝에 `git diff --stat <run_start_sha> -- server/`를 실행하면
- **Then** 출력이 없다

## AC-015 — 서식과 분석 (REQ-015)

- **Given** plan.md §B.6의 "서식 적용"·"서식 금지" 목록과 비교 규칙 표(git의 `--diff-filter=A`는 옛 경로가 다시 내보내기 파일로 남아 이름 바꾸기로 잡히지 않으므로 쓰지 않음 — plan-audit 2차 N1)
- **When** "서식 적용" 목록에만 `dart format`을 적용하고, 비교 규칙 표의 새 파일마다 원래 파일의 해당 줄 범위와 맞대어 비교한 뒤 `flutter analyze`(app), `dart analyze`(kolbi_core), `flutter analyze`(kolbi_ui)를 실행하면
- **Then** 세 분석의 문제 수가 기준선(앱) 이하이고 두 패키지는 0이며, 비교 규칙 표의 모든 새 파일에서 바뀐 줄이 그 행의 허용 차이뿐이고(둘로 나뉘는 세 파일 포함), `dart format`을 "서식 적용" 목록 밖에 실행한 기록이 없다(실행한 명령 원문을 `progress.md`에 기록)

## 엣지 케이스

- 테스트가 옛 경로 둘에서 같은 이름을 가져오는 경우(예: `call_models.dart`와 `approval_comment.dart`가 각각 다시 내보내는 이름이 배럴에서 같은 선언을 가리킴): 같은 선언이므로 충돌하지 않아야 한다(AC-013 컴파일 성공으로 확인). `calls_repository.dart`는 REQ-009의 다섯 이름만 다시 내보낸다.
- `formatRelative`의 한국어 날짜 형식은 지역 데이터 초기화가 필요하다. 앱에서는 `main.dart`가 초기화하므로 앱 동작은 같다. 패키지 테스트에서 이 함수를 쓰면 테스트 안에서 초기화한다.
- 워크스페이스 해석 뒤 직접 의존의 해석 버전이 바뀌면(잠금 파일 이동의 부작용) 동작 불변이 흔들릴 수 있다. 이동 전후 `flutter pub deps --style=compact`의 직접 의존 버전을 비교해 기록한다.

## 잔여 위험

- 다시 내보내기 파일이 남아 있는 동안에는 새 코드가 옛 경로를 가져올 수 있다. 앱 소스(`app/lib`)의 옛 경로 import는 이 SPEC에서 모두 배럴로 바꾸지만, 옛 경로 사용을 금지하는 검사는 SPEC-SHELL-001에서 더한다.
- 의존 규칙 테스트는 import 줄 글자 대조라 조건부 import나 문자열로 만든 경로를 놓칠 수 있다. 지금 코드에는 그런 import가 없다(plan-phase에서 import 줄 전체를 읽어 확인).

## 완료 정의 (Definition of Done)

- [ ] AC-001 ~ AC-015 모두 PASS, 명령 원문과 출력이 `progress.md` §E.2에 있음
- [ ] 기존 테스트 80개 통과, 기존 테스트 파일 무수정
- [ ] `server/` 무변경
- [ ] 서식은 변경 파일에만 적용
- [ ] sync-phase 문서 항목(`plan.md` §G) 목록이 manager-docs에 넘겨짐
