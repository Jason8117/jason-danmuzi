# SPEC-MODULE-001 구현 계획 (0.2.1 — plan-audit 2차 반영)

검토 순서 안내: 바뀔 가능성이 큰 결정(패키지 이름과 경계, 둘로 나누는 파일, 옛 경로 처리)을 앞에, 파일 이동·import 바꾸기 같은 기계적 작업과 회귀를 뒤에 둔다. 전체 구조는 `docs/product/11_ARCHITECTURE.md` §2.

## A. 접근 방식

### A.0 왜 옮기기만 하는가

동작을 바꾸지 않는 추출을 먼저 끝내면, 기존 테스트 80개가 그대로 회귀 검사가 된다. API를 다듬는 일(콜백 모양 위젯, `KolbiClient`, 토큰 공급자)은 SPEC-SDK-001로 미룬다. 두 가지를 섞으면 테스트가 깨졌을 때 원인이 "옮김"인지 "바꿈"인지 가릴 수 없다.

### A.1 경계 결정

| 결정 | 내용 | 근거 |
|---|---|---|
| 순수 Dart 경계 | Flutter 결합은 `@immutable`(→ `package:meta`)과 `String.characters`(→ `package:characters`, Flutter `widgets.dart`가 다시 내보내던 것)뿐이다 | `call_models.dart:1`, `counterparties.dart:1`, `intake_models.dart:1`, `approval_comment.dart:2` |
| 서버 접근 클래스 | `CallsRepository`는 `ApiClient`·`LiveChannel`·모델만 쓰므로 `kolbi_core`로. 공급자는 `settingsProvider`(앱 설정)에 기대므로 앱에 남김 | `calls_repository.dart:1-7`, `:91-100` |
| 표시 형식 | `formatPhone`·`formatDuration`·`formatRelative`·`formatClock`은 `intl`만 쓰는 순수 함수라 `kolbi_core` | `app/lib/core/utils/formatters.dart:1` |
| UI로 가는 것 | 토큰·테마·공용 위젯·상태 칩·결과 카드·대화 기록은 테마·토큰·모델만 쓴다 | 각 파일의 import(§B.2 근거 열) |
| 남는 것 | 앱 상태·라우터·설정 저장·share_plus에 묶인 파일 | §B.3 |

### A.2 옛 경로 처리

옮긴 파일의 옛 경로에는 `export` 지시문만 있는 파일을 남긴다. 예:

```dart
// app/lib/features/calls/domain/call_models.dart (after the move)
export 'package:kolbi_core/kolbi_core.dart'
    show CallLanguage, TaskStatus, Speaker, ApprovalStatus, OutcomeResult, OutcomeSource,
        TranscriptEntry, CallPlan, ApprovalRequest, CallOutcome, Appointment, CallTask,
        AutoStartBlocked, NewCallRequest, ServerInfo;
```

`show` 목록은 옛 파일의 공개 이름과 같게 한다(run 단계에서 옮기기 전 파일의 최상위 공개 선언을 세어 대조). 같은 선언을 여러 경로로 가져와도 Dart에서는 충돌이 아니므로, 테스트가 옛 경로 둘 이상을 함께 가져와도 문제없다.

앱 안의 소스 파일(`app/lib/**`)은 옛 경로 대신 배럴(`package:kolbi_core/kolbi_core.dart`, `package:kolbi_ui/kolbi_ui.dart`)을 가져오도록 바꾼다. 다시 내보내기 파일은 테스트와 이후 SPEC 이행을 위한 것이다.

### A.3 import 바꾸기 순서

1. 패키지 안: 옮긴 파일끼리의 상대 경로 import를 패키지 안 상대 경로(`src/...`)로.
2. 앱 소스: 옮긴 파일을 가리키던 상대 import(`../../../core/theme/tokens.dart` 등)를 배럴 import로. 한 파일이 배럴과 옛 상대 경로를 함께 가져오지 않게 한다.
3. 테스트: 고치지 않는다(REQ-013).

## B. 파일 배치

### B.1 kolbi_core로 옮기는 파일

| 지금 | 옮겨 갈 곳 | 바꾸는 것 | 근거(지금 import) |
|---|---|---|---|
| `app/lib/features/calls/domain/call_models.dart` | `packages/kolbi_core/lib/src/models/call_models.dart` | `flutter/foundation.dart` → `package:meta/meta.dart` | `:1` foundation(`@immutable`만 사용) |
| `app/lib/features/calls/domain/intake_models.dart` | `packages/kolbi_core/lib/src/models/intake_models.dart` | 같음 | foundation, `call_models.dart` |
| `app/lib/features/calls/domain/counterparties.dart` | `packages/kolbi_core/lib/src/models/counterparties.dart` | 같음 | foundation, `call_models.dart` |
| `app/lib/features/calls/domain/follow_up.dart` | `packages/kolbi_core/lib/src/follow_up.dart` | 없음 | `dart:convert`, `intl`, `call_models.dart` |
| `app/lib/features/calls/domain/approval_comment.dart`(포매터 제외 부분) | `packages/kolbi_core/lib/src/approval_comment.dart` | `flutter/widgets.dart show StringCharacters` → `package:characters/characters.dart` | `:1-2` |
| `app/lib/core/network/api_client.dart` | `packages/kolbi_core/lib/src/network/api_client.dart` | 없음 | `http`만 |
| `app/lib/core/network/live_channel.dart` | `packages/kolbi_core/lib/src/network/live_channel.dart` | 없음 | `web_socket_channel`만 |
| `app/lib/core/utils/formatters.dart` | `packages/kolbi_core/lib/src/format/formatters.dart` | 없음 | `intl`만 |
| `app/lib/features/calls/data/calls_repository.dart`(클래스·이벤트 부분) | `packages/kolbi_core/lib/src/data/calls_repository.dart` | 공급자 세 개를 떼어 냄 | `:9-89` |
| (새 파일) | `packages/kolbi_core/lib/kolbi_core.dart` | 배럴 | — |
| (새 파일) | `packages/kolbi_core/pubspec.yaml` | `resolution: workspace`, 의존 5개 + dev `test` | — |
| (새 파일) | `packages/kolbi_core/test/dependency_rules_test.dart`, `test/models_test.dart` | REQ-011, REQ-012 | — |

### B.2 kolbi_ui로 옮기는 파일

| 지금 | 옮겨 갈 곳 | 근거(지금 import) |
|---|---|---|
| `app/lib/core/theme/tokens.dart` | `packages/kolbi_ui/lib/src/theme/tokens.dart` | `dart:math`, `material_ui` |
| `app/lib/core/theme/app_theme.dart` | `packages/kolbi_ui/lib/src/theme/app_theme.dart` | `material_ui`, `tokens.dart` |
| `app/lib/core/widgets/common.dart` | `packages/kolbi_ui/lib/src/widgets/common.dart` | `material_ui`, `api_client.dart`(→ `kolbi_core`), `app_theme`, `tokens` |
| `app/lib/features/calls/presentation/widgets/status_chip.dart` | `packages/kolbi_ui/lib/src/widgets/status_chip.dart` | 테마·토큰·common·`call_models` |
| `app/lib/features/calls/presentation/widgets/outcome_card.dart` | `packages/kolbi_ui/lib/src/widgets/outcome_card.dart` | 같음 |
| `app/lib/features/calls/presentation/widgets/transcript_view.dart` | `packages/kolbi_ui/lib/src/widgets/transcript_view.dart` | 토큰·`call_models` |
| `approval_comment.dart`의 `CodePointLengthLimitingFormatter` | `packages/kolbi_ui/lib/src/input/code_point_formatter.dart` | `flutter/services.dart` |
| (새 파일) | `packages/kolbi_ui/lib/kolbi_ui.dart`, `pubspec.yaml`, `test/dependency_rules_test.dart`, `test/widgets_test.dart` | — |

### B.3 앱에 남는 파일(import만 배럴로 바꿈)

`app/lib/main.dart`, `app/lib/app.dart`, `app/lib/core/config/app_settings.dart`, `app/lib/core/router/app_router.dart`, `app/lib/features/calls/application/calls_controller.dart`, `app/lib/features/calls/data/calls_repository.dart`(공급자 + 다시 내보내기), `app/lib/features/calls/presentation/{approval_listener, call_detail_screen, call_templates, home_screen, new_call_screen, plan_card_screen, trust_notice}.dart`, `app/lib/features/calls/presentation/widgets/{approval_card, follow_up_actions}.dart`, `app/lib/features/settings/settings_screen.dart`.

남는 이유: 승인 카드는 `calls_controller.dart`를 읽고(`approval_card.dart:11`), 후속 행동 줄은 go_router·share_plus·Riverpod을 쓰며, 신뢰 안내는 `app_settings`(Riverpod)를 읽는다. 통화 템플릿은 앱 문구 묶음이다.

### B.4 옛 경로의 다시 내보내기 파일(14개)

`app/lib/core/network/api_client.dart`, `app/lib/core/network/live_channel.dart`, `app/lib/core/theme/app_theme.dart`, `app/lib/core/theme/tokens.dart`, `app/lib/core/utils/formatters.dart`, `app/lib/core/widgets/common.dart`, `app/lib/features/calls/domain/{call_models, intake_models, counterparties, follow_up, approval_comment}.dart`, `app/lib/features/calls/presentation/widgets/{status_chip, outcome_card, transcript_view}.dart`. 이 가운데 `approval_comment.dart`는 두 패키지의 이름을 함께 다시 내보낸다. `calls_repository.dart`는 다시 내보내기와 공급자를 함께 가진 일반 파일로 남으므로 이 목록에 넣지 않는다(§B.3). 테스트가 가져오는 옛 경로 24개(`grep -h "^import 'package:callmate" app/test/*.dart app/test/support/*.dart | sort -u`)가 모두 해석되는지 run 단계 첫 확인으로 센다.

### B.5 그 밖

| 파일 | 변경 | 이유 |
|---|---|---|
| `pubspec.yaml`(루트, 새 파일) | 워크스페이스 루트 | REQ-001 |
| `pubspec.lock`(루트) | `flutter pub get`이 만듦 | REQ-001 |
| `app/pubspec.yaml` | `resolution: workspace`, `kolbi_core`·`kolbi_ui` 의존 추가 | REQ-001, REQ-002 |
| `app/pubspec.lock` | 지움(루트 잠금 파일로 대체) | 워크스페이스 규칙 |
| `app/test/architecture_test.dart`(새 파일) | 앱 의존 규칙, 다시 내보내기 파일 검사(AC-008) | REQ-011, REQ-008 |
| `.gitignore`(루트) | `.dart_tool/` 한 줄 추가 | 지금은 `app/.gitignore:29`에만 있어 루트·`packages/*`의 `.dart_tool/`이 추적 대상이 됨(plan-audit 2차 N3, `git check-ignore`로 확인) |

### B.6 서식과 비교 규칙

**서식 적용**(`dart format <파일>`, 새로 만든 파일만): `packages/kolbi_core/lib/kolbi_core.dart`, `packages/kolbi_ui/lib/kolbi_ui.dart`, §B.4의 다시 내보내기 파일 14개, `packages/kolbi_core/test/{dependency_rules_test,models_test}.dart`, `packages/kolbi_ui/test/{dependency_rules_test,widgets_test}.dart`, `app/test/architecture_test.dart`.

**서식 금지**: §B.1·§B.2로 옮긴 파일의 새 위치 16개(원래 파일 15개에서 — `approval_comment.dart`가 두 개로 나뉨), §B.3에서 import만 고친 앱 파일, `app/lib/features/calls/data/calls_repository.dart`(공급자 + 다시 내보내기로 남는 일반 파일).

**비교 규칙**(AC-015):

| 새 파일 | 원래 파일의 비교 범위(run_start_sha 기준) | 허용 차이 |
|---|---|---|
| 통째로 옮긴 13개: kolbi_core의 `call_models`, `intake_models`, `counterparties`, `follow_up`, `api_client`, `live_channel`, `formatters`와 kolbi_ui의 `tokens`, `app_theme`, `common`, `status_chip`, `outcome_card`, `transcript_view` | 파일 전체 | import·export 줄, `@immutable`(→ `package:meta`)·`characters` import 대체 |
| kolbi_core `approval_comment.dart` | 원래 `approval_comment.dart`에서 포매터를 뺀 두 범위(지금 `:1-32`와 `:50-82`)를 이어 붙인 것 | import 줄, `characters` import 대체 |
| kolbi_ui `code_point_formatter.dart` | 원래 `approval_comment.dart`의 포매터 범위(지금 `:33-49`, 문서 주석 포함) | import 줄 |
| kolbi_core `calls_repository.dart` | 원래 `calls_repository.dart`의 클래스·이벤트 부분(지금 `:9-89`) | import 줄 |
| 앱 `calls_repository.dart` | 원래 파일의 공급자 부분(지금 `:91-100`) | import·export 줄 |

줄 범위는 run 시작 때 파일을 다시 읽어 확정하고 progress.md에 적는다. 비교는 원래 범위를 잘라낸 임시 파일과 새 파일을 `git diff --no-index --ignore-blank-lines -U0`으로 맞대어, 바뀐 줄이 허용 차이뿐인지 본다. 빈 줄 차이는 모든 행에서 허용한다(나눈 파일의 이음새 빈 줄, plan-audit 3차 N8). 위 표의 새 파일은 모두 16개이며(통째로 13 + kolbi_core `approval_comment` + kolbi_ui `code_point_formatter` + kolbi_core `calls_repository`), 앱 `calls_repository.dart`는 옛 경로에 남는 일반 파일이라 수에 넣지 않는다. AC-015는 16개를 모두 비교했음을 파일 이름 목록으로 기록한다.

## C. 마일스톤 (우선순위 순, 하나씩 순서대로)

### M1 — 워크스페이스 뼈대와 빈 패키지 (Priority High)

루트 `pubspec.yaml`, 두 패키지의 `pubspec.yaml`·빈 배럴, 앱 `pubspec.yaml` 수정. `flutter pub get` 후 `cd app && flutter test`가 그대로 80개 통과하는지 확인(가정 A-1: Flutter 3.50.1이 워크스페이스를 지원). 지원하지 않으면 멈추고 blocker로 보고한다(대안: 패키지를 `path:` 의존으로 두는 방식, 잠금 파일 위치만 다름).

### M2 — 의존 규칙 테스트 먼저 (Priority High)

세 의존 규칙 테스트를 쓴다. 이 시점에는 패키지가 비어 있어 통과하고, 앱 테스트의 기능 간 허용 목록 2건(`settings_screen.dart:9` → `call_models.dart`, `:10` → `trust_notice.dart`)이 실제 위반과 일치함을 확인한다. M3에서 `call_models.dart`가 다시 내보내기로 바뀌어도 그 파일은 여전히 `features/calls/` 안이므로 항목은 M5까지 유지된다. 이후 마일스톤에서 규칙을 어기면 바로 실패한다.

### M3 — kolbi_core 이동 (Priority High)

§B.1 순서: 모델 → 표시 형식·순수 계산 → 네트워크 → 서버 접근 클래스. 파일마다 옛 경로를 다시 내보내기로 바꾸고 `cd app && flutter test`를 돌린다. `kolbi_core` 테스트(REQ-012)를 쓰고 `dart test`로 돌린다.

### M4 — kolbi_ui 이동 (Priority High)

§B.2 순서: 토큰 → 테마 → 공용 위젯 → 상태 칩·결과 카드·대화 기록 → 포매터. 같은 방식으로 확인. `kolbi_ui` 테스트를 쓴다.

### M5 — 앱 import 정리 (Priority Medium)

§B.3 파일의 import를 배럴로. `settings_screen.dart:9`를 `package:kolbi_core/kolbi_core.dart`로 바꾸고 허용 목록에서 그 항목을 지운다. 서식은 §B.6 "서식 적용" 목록에만 `dart format <파일…>`. 옮긴 파일과 import만 고친 파일은 손으로 고치고 서식하지 않는다(REQ-015).

### M6 — 회귀와 기록 (Priority Low)

`acceptance.md` 공통 검증 명령 전체, `git diff --stat <run_start_sha> -- server/ app/test/` 비어 있음 확인, 결과를 `progress.md` §E.2에 기록.

## D. 위험 요소

| 위험 | 대응 |
|---|---|
| Flutter 3.50.1의 워크스페이스 동작이 가정과 다름(가정 A-1) | M1에서 먼저 확인하고, 안 되면 `path:` 의존 대안으로 blocker 보고 |
| 다시 내보내기 `show` 목록이 옛 공개 이름과 어긋나 테스트 컴파일 실패 | 옮기기 전 옛 파일의 최상위 공개 선언 목록을 뽑아 대조(M3·M4 각 파일) |
| `CallsRepository`를 상속하는 테스트 대역(`app/test/support/fakes.dart:77`)이 생성자·메서드 공개 여부에 기댐 | 클래스 본문을 바꾸지 않고 옮긴다. 비공개 멤버(`_api`, `_task`)를 대역이 쓰지 않는지 run 시작 시 확인 |
| `intl` 날짜 지역 데이터 초기화(`main.dart`의 `initializeDateFormatting`)가 패키지 테스트에서 빠짐 | `kolbi_core`의 `formatRelative` 테스트가 필요하면 테스트 안에서 초기화 |
| 루트 잠금 파일로 의존 버전이 바뀜 | `flutter pub get` 전후 직접 의존 버전 비교를 `progress.md`에 기록, 바뀌면 원래 범위로 고정 |
| 옮긴 파일에 서식을 적용해 본문이 바뀜 | 서식 명령에 옮긴 파일을 넣지 않음. AC-015가 옮긴 파일의 diff가 import·대체 줄뿐임을 확인 |
| 앱 전체 서식 실행 실수 | 서식 명령은 파일 목록을 명시해서만(D-5, 프로젝트 기억 "No project-wide dart format") |

## E. 하네스·복잡도 지표

| 지표 | 값 |
|---|---|
| Tier | M(옮기는 파일 15개 + 새 파일 10여 개로 파일 수는 L 기준에 가깝지만, 새 로직은 의존 규칙 테스트와 패키지 테스트뿐이고 나머지는 이동이다. SPEC-UX-001이 같은 근거로 M을 택한 선례) |
| REQ / AC | 15 / 15 |
| 권장 하네스 | standard |
| 방법론 | DDD(ANALYZE-PRESERVE-IMPROVE): 기존 테스트 80개가 PRESERVE 단계의 성격 테스트 역할 |
| 모드 | serial(하나의 manager-develop, 마일스톤 순서대로) |

## F. 자체 검증

run 시작 전 SPEC-UX-001이 `completed`인지 확인한다(`grep '^status' .moai/specs/SPEC-UX-001/spec.md`). 서버 기준선(`npm --prefix server test`, `npm --prefix server run typecheck`)도 run 시작 때 기록한다(12 §2.1, plan-audit D11).

run 단계 완료 보고는 다음을 원문 출력과 함께 담는다: `acceptance.md`의 AC별 PASS/FAIL 표와 실행 명령, `cd app && flutter --suppress-analytics test` 마지막 줄, `dart test`(kolbi_core)·`flutter test`(kolbi_ui) 결과, 세 의존 규칙 테스트 결과, `flutter analyze`·`dart analyze` 결과(기준선과 비교), `git diff --stat <run_start_sha> -- server/ app/test/` 출력(비어 있어야 함), 서식을 적용한 파일 목록.

## G. sync-phase 문서 항목

- `README.md`: 워크스페이스 구조와 테스트 명령(앱 `flutter test`, 패키지 `dart test`/`flutter test`).
- `.moai/project/structure.md`: 최상위 디렉터리에 `packages/`, 루트 `pubspec.yaml` 반영.
- `docs/product/11_ARCHITECTURE.md` §1.1: "지금 코드의 모양"을 분리 뒤 상태로 갱신(기능 간 위반 두 건과 정리 결과, `approval_card.dart:11`).
- `docs/product/11_ARCHITECTURE.md` §2.3·§2.4: `kolbi_core` 의존에 `characters`, 금지 목록에 `package:riverpod/`·`package:share_plus/` 반영.
- `docs/product/12_IMPLEMENTATION_PLAN.md` R-3: 허용 목록 두 건으로 시작함.
