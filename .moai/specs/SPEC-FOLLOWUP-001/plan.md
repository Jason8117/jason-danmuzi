# SPEC-FOLLOWUP-001 구현 계획

검토 순서 안내: 데이터 모델(결과의 `appointment`), 새 의존성(OD-1), 사용자 흐름(재통화·신뢰 안내)을 앞에, 문구·형식 단위 테스트와 회귀를 뒤에 둔다.

## A. 접근 방식

### A.1 데이터 모델 — `appointment` (REQ-001 ~ REQ-004)

- `server/src/domain/types.ts`: `CallOutcome.appointment?: { title: string; startsAt: string; endsAt?: string }`.
- `server/src/brain/openaiBrain.ts`
  - `OutcomeSchema`에 `appointment: z.unknown().optional()`을 더해 형식이 어긋나도 스키마 전체가 실패하지 않게 한다(REQ-002 "결과 전체의 대체를 일으키지 않음"). 검증은 스키마 뒤 별도 함수(순수, 기준 시각·작업 이름을 인자로)가 한다.
  - 요약 요청 본문에 `referenceTime`(작업 `endedAt` 또는 현재 시각의 ISO), `timezone: "Asia/Seoul"` 추가.
  - `result`가 `failed`이면 `appointment`를 버린다.
- `server/src/brain/prompts.ts`: `SUMMARY_SYSTEM_PROMPT`에 `appointment` 설명 한 문장(확정된 날짜·시각이 있을 때만, 아니면 null, `timezone` 기준 ISO 8601에 오프셋 포함).
- `HeuristicBrain`은 바꾸지 않는다(이미 `appointment`를 만들지 않음, 보호 테스트만).

### A.2 새 의존성 (OD-1)

- `app/pubspec.yaml`에 `share_plus` 추가, `pubspec.lock` 갱신(`flutter pub add share_plus`). 이 명령의 출력(해결된 버전, 새로 생긴 전이 패키지)을 M2 첫 증거로 `progress.md`에 원문 기록한다(직접 의존성은 하나, 전이 의존성은 기록으로 드러냄 — plan-audit D17). 버전은 run-phase에서 `sdk: ^3.14.0`과 맞는 최신 안정판을 패키지 문서로 확인해 정한다. 파일 공유는 메모리 바이트로 만든 파일 객체를 쓴다(임시 파일 경로용 `path_provider` 추가 없음 — 필요하면 blocker로 보고).
- 공유·클립보드 호출은 `FollowUpService`(이름은 RED에서 확정) 한 곳에 모으고 Riverpod 공급자로 주입한다. 기본 구현: 클립보드는 `flutter/services.dart`의 `Clipboard`, 공유는 `share_plus`. 테스트는 기록용 가짜로 바꾼다.

### A.3 결과 화면 (REQ-005 ~ REQ-010, REQ-012)

- `call_models.dart`: `CallOutcome.appointment`(방어적 파싱, `DateTime.tryParse`).
- `follow_up.dart`(새, 순수 함수): 공유 문구(시계·날짜 형식 주입), 캘린더 노출 판정, `.ics` 생성.
- `follow_up_actions.dart`(새 위젯): 상태별 버튼 줄. `call_detail_screen.dart`의 끝난 상태 행동(`:245-253`)을 이 위젯으로 바꾼다.
- 다시 걸기: SPEC-INTAKE-001의 `PlanDraft`에 작업에서 만드는 생성자와 번호 출처 값 하나("이전 통화")를 더하고 `/plan`으로 보낸다. 계획 카드의 출처 표시에 "지난번과 같은 번호"를 더한다.

### A.4 신뢰 안내 (REQ-013 ~ REQ-015)

- `trust_notice.dart`(새): 여섯 문장 상수, 안내 시트(확인 버튼), "한 번만" 판정 함수.
- `app_settings.dart`: 안내 확인 기록(불리언 하나)을 읽고 저장하는 메서드. 기존 네 설정 키는 그대로.
- `plan_card_screen.dart`([이대로 시작])와 `call_detail_screen.dart`("이대로 전화 걸기") 앞에 안내 판정을 둔다.
- `settings_screen.dart`: "AI 비서와 기록" 묶음.
- `call_detail_screen.dart`: 통화 중 한 줄.

## B. 변경 파일

서버:

| 파일 | 변경 | 이유 |
|------|------|------|
| `server/src/domain/types.ts` | 수정 | `CallOutcome.appointment` |
| `server/src/brain/openaiBrain.ts` | 수정 | 스키마, 검증, 기준 시각 전송 |
| `server/src/brain/prompts.ts` | 수정 | 요약 프롬프트 한 문장 |
| `server/src/brain/openaiBrain.test.ts` | 수정 | AC-001~AC-004 |
| `server/src/brain/heuristicBrain.test.ts` | 수정 | AC-004 (1) |

앱:

| 파일 | 변경 | 이유 |
|------|------|------|
| `app/pubspec.yaml` | 수정 | `share_plus` (OD-1) |
| `app/pubspec.lock` | 수정(자동) | 의존성 잠금 |
| `app/lib/features/calls/domain/call_models.dart` | 수정 | `appointment` 파싱 |
| `app/lib/features/calls/domain/follow_up.dart` | 신규 | 공유 문구, 노출 판정, `.ics` |
| `app/lib/features/calls/domain/intake_models.dart` | 수정 | `PlanDraft`를 작업에서 만들기, 출처 값 추가 |
| `app/lib/features/calls/presentation/widgets/follow_up_actions.dart` | 신규 | 버튼 줄, 서비스 공급자 |
| `app/lib/features/calls/presentation/call_detail_screen.dart` | 수정 | 후속 행동, 통화 중 한 줄, 안내 판정 |
| `app/lib/features/calls/presentation/plan_card_screen.dart` | 수정 | 출처 표시, 안내 판정 |
| `app/lib/features/calls/presentation/trust_notice.dart` | 신규 | 문구, 시트 |
| `app/lib/core/config/app_settings.dart` | 수정 | 안내 확인 기록 |
| `app/lib/features/settings/settings_screen.dart` | 수정 | "AI 비서와 기록" |
| `app/test/follow_up_test.dart` | 신규 | AC-006~AC-012 |
| `app/test/trust_notice_test.dart` | 신규 | AC-013~AC-015 |
| `app/test/unit_test.dart` | 수정 | AC-005 |
| `app/test/plan_card_test.dart`, `app/test/intake_flow_test.dart` | 수정 | AC-016 의도된 준비 줄 변경 |

합계 21개(서버 5, 앱 16 — 앱은 신규 5·수정 11이며, 그중 테스트 5개, `pubspec.yaml`·`pubspec.lock` 2개, 제품 코드 9개). Tier 판단: 제품 코드는 서버 3·앱 9로, 새 코드는 순수 함수 하나와 작은 위젯 둘이다. 파일 수는 Tier M 안내치(5~15)를 넘지만 크기는 Tier M 범위(300~1000 LOC)로 보고 M을 유지한다. plan-auditor가 Tier L이 맞다고 보면 design.md를 더해 올린다.

## C. 마일스톤 (우선순위 순, 하나씩 순서대로)

### M1 — 서버 `appointment` (Priority High)

RED: AC-001 (2) 타입, AC-002 표, AC-003. 보호: AC-004.

### M2 — 의존성과 앱 모델 (Priority High)

`share_plus` 추가(OD-1). RED: AC-005. 의존성 추가 뒤 `flutter analyze`·`flutter test`가 기준선과 같은지 먼저 확인(추가 자체가 경고를 늘리지 않음).

### M3 — 재통화 → 계획 카드 (Priority High)

RED: AC-007.

### M4 — 신뢰 안내 (Priority Medium)

RED: AC-013(문구), AC-014, AC-015. 함께: AC-016의 기존 테스트 준비 줄 변경(같은 커밋 — 그렇지 않으면 SPEC-INTAKE-001 테스트가 안내 시트 때문에 실패).

### M5 — 복사·공유·캘린더 (Priority Medium)

RED: AC-009, AC-011(순수 함수 먼저), AC-010, AC-006, AC-008, AC-012.

### M6 — 회귀 (Priority Low)

AC-016 전체, AC-013 명령 표 원문 기록.

## D. 위험 요소

| 위험 | 내용 | 대응 |
|------|------|------|
| 새 의존성 | `share_plus` 버전·플랫폼 동작이 확인되지 않음 | OD-1. run-phase에서 문서 확인, 서비스 추상화로 테스트는 기기 기능과 분리. 문제가 생기면 blocker. |
| 거짓 일정 | LLM이 대화를 잘못 읽음 | `llm` + `success`/`partial`만, 범위 검사, 초안 문구, 저장 전 확인. |
| `unverified` 오인 | 검증 안 된 결과를 확정처럼 공유 | 공유 문구에 라벨과 안내 줄(REQ-009), 캘린더 비노출(REQ-010). |
| 안내 시트가 기존 흐름을 막음 | SPEC-INTAKE-001 테스트가 [이대로 시작]을 누름 | AC-016의 준비 줄 변경, M4에서 같은 커밋. |
| 문구의 사실성 | 서버가 바뀌면 신뢰 문구가 거짓이 됨 | AC-013 명령 표를 sync-phase에서도 다시 실행. |
| SPEC-OUTCOME-001 계약 | 스키마 변경이 `result` 검사나 대체 분류를 바꿀 위험 | `appointment`만 `unknown`으로 추가, `result` enum 불변, AC-003의 `unverified` 거부 확인. |

### D.1 에픽 내 파일 겹침

SPEC-INTAKE-001과 `call_models.dart`, `intake_models.dart`, `plan_card_screen.dart`, `call_detail_screen.dart`, `unit_test.dart`, INTAKE 테스트 두 개가 겹친다(INTAKE 완료 뒤 시작). SPEC-UX-001은 `follow_up_actions.dart`, `outcome_card.dart`, `call_detail_screen.dart`, `settings_screen.dart`를 다시 꾸민다.

## E. 하네스·복잡도 지표

| 지표 | 값 |
|------|-----|
| Tier | M (파일 수 초과 사유는 §B) |
| 도메인 수 | 2 (server brain, app UI·모델) |
| 변경 파일 수 | 21 (서버 수정 5, 앱 신규 5·수정 11) |
| REQ / AC | 16 / 16 |
| 외부 연동 | OpenAI(가짜 `fetch`), 기기 공유 시트(가짜 서비스) |
| 새 의존성 | `share_plus` (앱, OD-1) |
| 권장 하네스 | standard |

## F. 자체 검증

- 마일스톤별 RED/GREEN 원문을 `progress.md` §E.2에 기록.
- AC-013 명령 표의 원문 결과를 기록.
- `grep -n "appointment" server/src/brain/heuristicBrain.ts`가 0줄.

## G. sync-phase 문서 항목

- 결과의 `appointment` 필드(확정된 LLM 결과만).
- 결과 화면 후속 행동과 재통화 흐름.
- 신뢰 안내 문구(OD-3, 법률 검토 전).
- 새 의존성 `share_plus`(`.moai/project/tech.md`).
- AC-013 명령 표 재실행 결과.
