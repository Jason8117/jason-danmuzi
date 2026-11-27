---
id: SPEC-MODULE-001
title: "워크스페이스와 패키지 분리 — kolbi_core(헤드리스)·kolbi_ui(공용 UI) 추출, 동작 불변"
version: "0.2.2"
status: implemented
created: 2026-11-26
updated: 2026-11-27
author: jason
priority: High
phase: "v0.4.0 target"
module: "pubspec.yaml, packages/kolbi_core, packages/kolbi_ui, app/lib, app/test/architecture_test.dart"
lifecycle: spec-anchored
tags: "workspace, modularization, packages, kolbi_core, kolbi_ui, sdk-foundation, dependency-rules, flutter, dart, no-behavior-change"
tier: M
depends_on: [SPEC-UX-001]
related_specs: [SPEC-UX-001, SPEC-DESIGN-001, SPEC-SHELL-001, SPEC-SDK-001]
---

# SPEC-MODULE-001: 워크스페이스와 패키지 분리 — kolbi_core(헤드리스)·kolbi_ui(공용 UI) 추출, 동작 불변

## HISTORY

| 버전 | 날짜 | 작성 | 변경 |
|------|------|------|------|
| 0.1.0 | 2026-11-26 | jason (manager-spec) | 최초 작성 (draft). 에픽 EPIC-KOLBI-APP의 첫 SPEC |
| 0.1.1 | 2026-11-26 | jason | 디자인 검토 반영에 따른 문구 정리(`docs/planning/06_DESIGN_DECISIONS.md`). 범위 변경 없음: 토큰은 지금 값 그대로 옮기고, Midnight Indigo 값·Pretendard·Agent 컴포넌트는 SPEC-SHELL-001·SPEC-ASSIST-001이 `kolbi_ui`에 더한다 |
| 0.2.0 | 2026-11-26 | jason | plan-audit 1차(FAIL 0.77, `.moai/reports/plan-audit/SPEC-MODULE-001-review-1.md`) 반영. 기능 간 위반 두 건(D1), 잠금 파일 확인 방법(D2), 옮긴 파일 본문 서식 금지(D3), 다시 내보내기 검사 방식(D4), SPEC-UX-001 완료 선행(D5), REQ-003 문구(D7), 빌드 확인(D8), 테스트 수 기대값(D9), 그 밖의 권장 수정(D6, D10~D13, D16) |
| 0.2.1 | 2026-11-26 | jason | plan-audit 2차(FAIL 0.81, `.moai/reports/plan-audit/SPEC-MODULE-001-review-2.md`) 반영. 서식 대상·비대상 파일을 명시 목록으로(N1), 둘로 나뉘는 파일의 비교 규칙(N2), 루트 `.gitignore`에 `.dart_tool/` 추가(N3 — 0.2.0의 "이미 덮음"은 사실과 달랐음), progress 정리(N6), SPEC-DESIGN-001 언급(N4), 화면 문구 검사에 `packages/` 포함(N5) |
| 0.2.2 | 2026-11-26 | jason | plan-audit 3차(0.86, 한 건 FAIL, `.moai/reports/plan-audit/SPEC-MODULE-001-review-3.md`) 반영. 옮긴 파일 수 13·16으로 바로잡고 이름 명시(N7), 비교에서 빈 줄 차이 허용(N8), §B.5 표에서 떨어진 README 행 정리(N9), `.dart_tool` 검사에 `--untracked-files=all`(N10), HISTORY 순서·progress 정리(N11) |

## 1. 배경과 목적

앱은 패키지 하나(`name: callmate`, `app/pubspec.yaml:1`)이고, 다른 앱이 다시 쓸 도메인 로직과 앱 전용 화면이 섞여 있다(설계서 `docs/product/11_ARCHITECTURE.md` §1.1). 도메인 모델은 `@immutable` 하나 때문에 Flutter를 가져오고(`app/lib/features/calls/domain/call_models.dart:1`, `:73`), 승인 코멘트의 순수 함수와 입력 포매터가 한 파일에 있으며(`approval_comment.dart:17`, `:34`), 서버 접근 클래스와 Riverpod 공급자가 한 파일에 있다(`calls_repository.dart:29`, `:91`).

콜비는 이후 헤드리스 SDK·임베디드 UI SDK를 내놓고(10_PRODUCT_PLAN §5), 작업 종류·장소·반복 기능을 더한다. 그 전에 코드를 순수 Dart 패키지(`kolbi_core`), Flutter UI 패키지(`kolbi_ui`), 앱 셸(`app/`)로 나누고 경계를 테스트로 지킨다. 이 SPEC은 **옮기기만** 한다. 화면·문구·요청·상태 관리는 바뀌지 않으며, 기존 테스트 80개가 수정 없이 통과하는 것으로 이를 증명한다.

## 2. 범위

- 저장소 루트에 Dart pub 워크스페이스를 만들고, `packages/kolbi_core`와 `packages/kolbi_ui`를 새로 만든다.
- 옮길 파일과 옮겨 갈 곳: `plan.md` §B. 옛 경로에는 다시 내보내기 파일을 남긴다.
- 의존 규칙 테스트 셋(패키지 둘, 앱 하나)을 더한다.
- `server/`, `/v1`, 기존 테스트 파일은 바꾸지 않는다.

## 3. 요구사항 (GEARS)

### 3.1 워크스페이스

- **REQ-001** [Ubiquitous] 저장소는 루트 `pubspec.yaml` 하나로 `app`, `packages/kolbi_core`, `packages/kolbi_ui`를 구성원으로 묶는 Dart pub 워크스페이스여야 하며(**shall**), 각 구성원의 `pubspec.yaml`은 `resolution: workspace`를 가진다. 의존성 잠금 파일은 루트에 하나만 있다.
- **REQ-002** [Ubiquitous] `app/`에서 지금과 같은 명령(`flutter --suppress-analytics test`, `flutter --suppress-analytics analyze`)과 앱 빌드(run 시작 때 기준선에서 성공하는 플랫폼 빌드 하나, 기본 `flutter build web --debug`)가 그대로 성공해야 한다(**shall**). 앱 패키지 이름은 `callmate`로 유지한다(OD-1).

### 3.2 kolbi_core

- **REQ-003** [Ubiquitous] `kolbi_core`는 `pubspec.yaml`과 `lib/` 어디에도 Flutter 의존이 없고 `dart test`(Flutter 테스트 실행기 아님)로 시험하는 순수 Dart 패키지여야 하며(**shall**)(워크스페이스 의존성 해석에는 Flutter SDK에 딸린 `dart`를 쓴다), `plan.md` §B.1의 파일(작업·계획·승인·결과·초안 모델과 JSON 해석, 최근 장소 계산, 공유 문구·일정 파일 생성, 승인 코멘트 순수 함수와 상수, HTTP 클라이언트와 오류 타입, 실시간 채널, 서버 접근 클래스와 이벤트 타입, 전화번호·시간 표시 형식)을 담는다. 런타임 의존은 `http`, `web_socket_channel`, `intl`, `meta`, `characters`로 한정한다.
- **REQ-004** [Unwanted] `kolbi_core`의 `lib/` 아래 파일은 `package:flutter/`, `dart:ui`, `package:flutter_riverpod/`, `package:riverpod/`, `package:shared_preferences/`, `package:kolbi_ui/`, `package:callmate/`를 가져와서는 안 된다(**shall not**). 도메인 모델의 `@immutable`은 `package:meta`의 같은 주석으로 바꾼다.

### 3.3 kolbi_ui

- **REQ-005** [Ubiquitous] `kolbi_ui`는 `plan.md` §B.2의 파일(디자인 토큰, 테마와 `CardTone`, 공용 위젯 `AppCard`·`SectionCard`·`MessageView`·`PulsingDot`·`ResponsiveBody`·`BulletList`·`describeError`, 상태 칩, 결과 카드, 대화 기록, 코드 포인트 길이 제한 입력 포매터)을 담는 Flutter 패키지여야 하며(**shall**), 런타임 의존은 `flutter`, `material_ui`, `kolbi_core`로 한정한다.
- **REQ-006** [Unwanted] `kolbi_ui`의 `lib/` 아래 파일은 `package:callmate/`, `package:go_router/`, `package:flutter_riverpod/`, `package:shared_preferences/`, `package:share_plus/`를 가져와서는 안 된다(**shall not**).

### 3.4 공개 표면과 옛 경로

- **REQ-007** [Ubiquitous] 각 패키지는 공개 표면을 배럴 파일 하나(`lib/kolbi_core.dart`, `lib/kolbi_ui.dart`)로 내보내야 하며(**shall**), 구현 파일은 `lib/src/` 아래에 둔다. 배럴의 `show` 목록은 옮긴 파일의 최상위 공개 선언(클래스·함수·상수·확장 이름 포함, 예: `runWithFeedback`, `outcomeTone`, `ToneColors`, `StatusColors` 확장)을 기계적으로 뽑아 만든다. 앱과 다른 패키지는 `package:kolbi_core/src/…`, `package:kolbi_ui/src/…`를 가져오지 않는다.
- **REQ-008** [Ubiquitous] 옮긴 파일의 옛 경로(`app/lib/...`)에는 주석을 빼면 다시 내보내기 지시문(`export`, 여러 줄 `show` 목록 포함)만 있는 파일을 남겨야 하며(**shall**), 이 파일은 옛 파일이 공개하던 이름을 모두 공개한다. 그래서 기존 `package:callmate/...` import(테스트 12개 파일 포함)가 고치지 않고 그대로 해석된다.
- **REQ-009** [Ubiquitous] 서버 접근 파일(`app/lib/features/calls/data/calls_repository.dart`)은 둘로 나뉘어야 한다(**shall**): `CallsRepository` 클래스와 이벤트 타입(`CallsEvent`, `TasksSnapshot`, `TaskUpdated`, `TaskDeleted`)은 `kolbi_core`로, Riverpod 공급자(`apiClientProvider`, `callsRepositoryProvider`, `serverInfoProvider`)는 옛 경로 파일에 남고 그 파일이 옮긴 이름을 다시 내보낸다.
- **REQ-010** [Ubiquitous] 승인 코멘트 파일(`app/lib/features/calls/domain/approval_comment.dart`)은 둘로 나뉘어야 한다(**shall**): 상수와 순수 함수(`kMaxApprovalCommentCodePoints`, `kApprovalCommentCounterFrom`, `kApprovalQuickReplies`, `codePointLength`, `truncateToCodePoints`, `withQuickReply`, `hasSensitiveDigits`)는 `kolbi_core`로, `CodePointLengthLimitingFormatter`는 `kolbi_ui`로 간다. 옛 경로 파일은 두 곳의 이름을 모두 다시 내보낸다.

### 3.5 의존 규칙 검사

- **REQ-011** [Ubiquitous] 의존 규칙은 테스트 셋으로 검사되어야 한다(**shall**): `packages/kolbi_core/test/dependency_rules_test.dart`(REQ-004), `packages/kolbi_ui/test/dependency_rules_test.dart`(REQ-006, `/src/` 규칙), `app/test/architecture_test.dart`(앱이 패키지 `/src/`를 가져오지 않음, 기능 모듈 `features/<a>/`가 다른 기능 모듈 `features/<b>/`를 가져오지 않음). 검사는 소스의 import·export 줄을 글자로 읽어 대조한다(서버 `server/src/architecture.test.ts`와 같은 방식). 기능 간 규칙의 허용 목록은 지금 있는 위반 두 건(`features/settings/settings_screen.dart:9` → `features/calls/domain/call_models.dart`, `:10` → `features/calls/presentation/trust_notice.dart`)으로 시작하고, 앱 import 정리(M5)에서 `:9`를 `kolbi_core` 배럴 import로 바꾸며 그 항목을 같이 지운다. 이 SPEC이 끝날 때 허용 목록은 `trust_notice.dart` 한 건이다(그 항목은 SPEC-SHELL-001이 지움). 허용 목록 항목이 실제 위반과 다르면(없어졌거나 새로 생겼으면) 테스트가 실패한다.
- **REQ-012** [Ubiquitous] 각 패키지는 자기 테스트를 가져야 한다(**shall**): `kolbi_core`는 `dart test`로 작업 JSON 해석 한 건(필드가 빠진 옛 작업 포함)과 승인 코멘트 함수 한 건을, `kolbi_ui`는 `flutter test`로 토큰 값과 공용 카드 렌더링 한 건을 시험한다. 앱의 기존 테스트는 옮기지 않는다.

### 3.6 동작 불변

- **REQ-013** [Unwanted] 이 SPEC은 동작을 바꿔서는 안 된다(**shall not**): 화면 배치·문구·경로, 요청 본문과 헤더, 상태 관리, 알림 동작이 그대로이며, `app/test/` 아래 기존 파일(11개 테스트 파일과 `support/fakes.dart`)을 한 줄도 고치지 않고 기존 테스트 80개가 모두 통과한다.
- **REQ-014** [Unwanted] 이 SPEC은 `server/` 아래 어떤 파일도 바꿔서는 안 된다(**shall not**). `/v1` 계약은 그대로다.
- **REQ-015** [Ubiquitous] 서식 도구는 `plan.md` §B.6의 "서식 적용" 목록(배럴, 다시 내보내기 파일, 새 테스트)에만 적용되어야 하며(**shall**), "서식 금지" 목록(옮긴 파일과 import만 고친 앱 파일)에는 적용하지 않는다. 옮긴 파일은 import·export 줄과 `@immutable`·`characters` 대체 줄 말고는 본문을 바이트 그대로 두고, 둘로 나뉘는 세 파일(`approval_comment.dart`, `calls_repository.dart`의 두 쪽, `code_point_formatter.dart`)은 원래 파일의 정해진 줄 범위와 같다(§B.6 비교 규칙)(서식 적용 금지: 기본 줄 폭 80에서 옮긴 13개 파일이 모두 다시 줄바꿈되어 "옮기기만"이 깨짐 — plan-audit D3). `flutter analyze`(app)와 `dart analyze`(두 패키지)는 기준선 대비 새 문제를 내지 않는다.

## 4. 비기능 제약

- 새 외부 의존은 `meta`, `characters`(둘 다 지금 Flutter SDK를 통해 이미 잠금 파일에 있는 전이 의존, `app/pubspec.lock`의 `characters` 항목)와 패키지 테스트용 `test`뿐이다.
- 선행 조건: SPEC-UX-001이 `completed`(sync 끝)여야 `run_start_sha`를 잡는다. UX-001의 모듈이 이 SPEC이 옮기는 `core/theme`·`core/widgets`·`features/calls`와 같기 때문이다(plan-audit D5, 2026-11-26 기준 UX-001은 `in-progress`, sync 대기).
- Tier: 옮기는 줄 약 1,678줄·파일 15개 이상으로 Tier L 범위에 걸친다(plan-audit D15). 새 로직이 적어 M으로 둔다(OD-5, 소유자 결정).
- 패키지 버전은 `0.1.0`, `publish_to: none`(외부 배포는 SPEC-SDK-001 이후 결정).
- 문서: 코드 주석은 영어(프로젝트 설정 `code_comments: en`).
- 다시 내보내기 파일은 이 SPEC 이후 SPEC-SHELL-001·SPEC-SDK-001에서 import를 새 경로로 바꾸면서 줄여 간다. 이 SPEC은 지우지 않는다.

## 5. Open Decisions

| ID | 결정 사항 | 상태 | 결정 내용 |
|----|-----------|------|-----------|
| OD-1 | 앱 패키지 이름 | **DEFAULT (pending owner review)** | `callmate` 유지. `kolbi_app`으로 바꾸는 일은 별도 SPEC(테스트 12개 파일의 import를 바꾸는 기계적 작업). 설계서 §2.2 |
| OD-2 | 새 패키지 이름 | **DEFAULT (pending owner review)** | `kolbi_core`, `kolbi_ui`. SDK 제안 문서의 `callmate_dart`, `callmate_flutter`를 대신한다. 설계서 §2.2 |
| OD-3 | 기존 테스트 위치 | **DEFAULT (pending owner review)** | 앱에 그대로 둔다. 순수 로직 테스트(`unit_test.dart` 일부)를 `kolbi_core`로 옮기면 패키지 테스트가 늘지만 REQ-013(테스트 파일 무수정)과 충돌하므로 후속 SPEC에서 한다 |
| OD-5 | Tier | **DECIDED (2026-11-26, 소유자)** | M 유지(새 로직은 의존 규칙 테스트와 패키지 테스트뿐) |
| OD-4 | 승인 카드·후속 행동 줄 추출 | **DEFAULT (pending owner review)** | 이 SPEC에서 옮기지 않는다. 앱 상태(`calls_controller.dart`)·go_router·share_plus에 묶여 있어 옮기려면 API를 바꿔야 한다. SPEC-SDK-001에서 콜백 모양으로 추출 |

## 6. 제외 범위 (Out of Scope)

### Out of Scope — 동작과 서버

- 화면·문구·경로·요청 변경, 새 기능은 다루지 않는다(REQ-013).
- `server/`와 `/v1` 변경은 다루지 않는다(REQ-014).

### Out of Scope — 이후 SPEC의 일

- 디자인 토큰 값 교체(Midnight Indigo), Pretendard, 상태 칩 범주는 SPEC-DESIGN-001. 5칸 셸, 경로 이름, `TaskKind` 등록부, 기능 폴더 재배치는 SPEC-SHELL-001. AI Orb와 몰입형 다크 테마는 SPEC-ASSIST-001.
- `KolbiClient` 공개 API, `AuthTokenProvider`, 승인 카드 추출, `/platform/v1`, 예제 앱은 SPEC-SDK-001.
- 앱 패키지 이름·화면 제목 변경(OD-1), 패키지 외부 배포.

### Out of Scope — 정리 작업

- 다시 내보내기 파일 삭제, 기존 테스트의 import 경로 정리, 저장소 전체 서식 정리.

## 7. 추적성

| 요구사항 | 인수 기준 |
|----------|-----------|
| REQ-001 | AC-001 |
| REQ-002 | AC-002 |
| REQ-003 | AC-003 |
| REQ-004 | AC-004 |
| REQ-005 | AC-005 |
| REQ-006 | AC-006 |
| REQ-007 | AC-007 |
| REQ-008 | AC-008 |
| REQ-009 | AC-009 |
| REQ-010 | AC-010 |
| REQ-011 | AC-011 |
| REQ-012 | AC-012 |
| REQ-013 | AC-013 |
| REQ-014 | AC-014 |
| REQ-015 | AC-015 |
