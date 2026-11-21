# SPEC-INTAKE-001 구현 계획

검토 순서 안내: 데이터 모델·인터페이스 결정(자동 시작 필드, brain 인터페이스, 응답 형태)과 사용자 흐름을 앞에, 기계적인 회귀 확인을 뒤에 둔다. 세부 구조는 `design.md`.

## A. 접근 방식

### A.1 데이터 모델 변경 (가장 먼저 검토할 결정)

- `server/src/domain/types.ts`: `CallTask`에 `autoStart?: boolean`, `autoStartBlocked?: { code: string; message: string }`. `CallTaskInput`은 그대로 두고, 생성 입력에만 `autoStart`를 받는다(작업 입력과 실행 옵션을 섞지 않음). 의뢰 해석 결과 타입(`IntakeDraft`, `IntakeResult`)도 여기에 둔다.
- `server/src/brain/types.ts`: `CallBrain.draftIntake(maskedText, language)` 추가(`design.md` §4).
- 앱 `call_models.dart`: `NewCallRequest.autoStart`(참일 때만 직렬화), `CallTask.autoStartBlocked`(방어적 파싱).
- 앱 새 모델 `intake_models.dart`: `PlanDraft`(초안 + 출처 + 안내).

### A.2 자동 시작 (REQ-013 ~ REQ-016, OD-1)

`design.md` §5의 순서. 핵심은 같은 `approvePlan`을 재사용해 검사 순서를 한 곳에 두는 것, 그리고 자동 시작 경로의 어떤 오류도 `plan()`의 `catch`로 새지 않게 하는 것.

### A.3 번호·이름 규칙 (REQ-004 ~ REQ-007, REQ-010, REQ-011)

새 순수 모듈 `server/src/domain/intake.ts`: 번호 후보 찾기, 단축 번호 감지, 가리기, 이름 정규화, 기록 이름 포함 검사, 기록 번호 찾기(작업 목록을 인자로 받음 — 저장소를 직접 모름). 테스트 벡터는 `design.md` §2·§3 표를 그대로 옮긴다.

### A.4 brain (REQ-008, REQ-009)

- `HeuristicBrain.draftIntake`: 결정적 규칙.
- `OpenAiBrain.draftIntake`: `completeJson`을 `op: "intake"`로. 실패 분류·로그 형식은 기존 그대로(SPEC-OUTCOME-001 REQ-009 허용 목록). `CallContext.op`에 `"intake"`만 추가. 제한 시간 15 s(주입 가능, `design.md` §4). 스키마 검증한 값을 그대로 돌려주며 후처리는 하지 않는다(REQ-008: 후처리는 서비스 한 곳).
- `brain/prompts.ts`: 의뢰 해석 시스템 프롬프트 상수.

### A.5 서비스·HTTP (REQ-001 ~ REQ-003, REQ-012)

- `CallService.draftIntake(text, language)`: 종료 검사 → 번호 → brain → 이름 보정 → 기록 번호 → `missing`. 저장·발행·제공자 호출 없음.
- `http/schemas.ts`: `IntakeBody`, `CreateTaskBody.autoStart`.
- `http/app.ts`: `POST /v1/intake` 라우트 한 개(서비스 호출만, 규칙 없음 — SPEC-POLICY-001 REQ-008과 같은 원칙).

### A.6 앱 (REQ-017 ~ REQ-023)

- `calls_repository.dart`: `intake(text, language)` → `IntakeResult`. 404는 `statusCode == 404`로 판별해 호출부(홈)에서 빈 초안으로 바꾼다. Fastify 기본 404 본문의 `error`는 `"Not Found"`이므로 코드 문자열로 판별하지 않는다(`research.md` §6).
- `counterparties.dart`: 최근 통화한 곳 계산(서버와 같은 정규화).
- `home_screen.dart`: 맨 위 입력칸 + 보내기, "직접 입력하기", 제안 두 묶음. 템플릿 칩은 제안 줄 한 곳에만 두고, 빈 상태(`_EmptyState`)에서는 기존 칩 줄(`home_screen.dart:196-208`)을 지워 `MessageView` 문구만 남긴다(REQ-018 (b)). 기존 목록·배너·내 정보 안내 유지. 떠 있는 버튼 제거.
- `plan_card_screen.dart`(새): 행 목록 + 그 자리 수정 + 번호 칸 + [이대로 시작].
- `app_router.dart`: `/plan` 경로.
- `call_detail_screen.dart`: `awaiting_approval` 분기에 막힘 안내 한 장.
- 시각 요소는 기존 테마와 `SectionCard`·`BulletList`만 쓴다. SPEC-UX-001이 다시 꾸민다.

## B. 변경 파일

서버:

| 파일 | 변경 | 이유 |
|------|------|------|
| `server/src/domain/types.ts` | 수정 | `autoStart`, `autoStartBlocked`, 의뢰 해석 타입 |
| `server/src/domain/intake.ts` | 신규 | 번호·이름·기록 규칙 |
| `server/src/domain/intake.test.ts` | 신규 | AC-004, AC-007 (a) 가리기 벡터 |
| `server/src/brain/types.ts` | 수정 | `draftIntake` |
| `server/src/brain/heuristicBrain.ts` | 수정 | 결정적 해석 |
| `server/src/brain/heuristicBrain.test.ts` | 수정 | AC-010 |
| `server/src/brain/openaiBrain.ts` | 수정 | LLM 해석·대체 |
| `server/src/brain/openaiBrain.test.ts` | 수정 | AC-007 (a) brain 단(받은 글을 그대로 보냄), AC-008 (brain 단: 검증된 원값 반환), AC-009 |
| `server/src/brain/prompts.ts` | 수정 | 의뢰 해석 프롬프트 |
| `server/src/services/callService.ts` | 수정 | `draftIntake`, 자동 시작, `autoStartBlocked` 지우기 |
| `server/src/services/callService.test.ts` | 수정 | AC-003, AC-005, AC-006, AC-007 (a) 요청 본문·(b)~(e), AC-008 (서비스 후처리), AC-011, AC-012, AC-014~AC-016 |
| `server/src/http/schemas.ts` | 수정 | `IntakeBody`, `autoStart` |
| `server/src/http/app.ts` | 수정 | `POST /v1/intake` |
| `server/src/http/app.test.ts` | 수정 | AC-001, AC-002, AC-013, AC-014 (통합) — 새 테스트만 추가 |

앱:

| 파일 | 변경 | 이유 |
|------|------|------|
| `app/lib/features/calls/domain/call_models.dart` | 수정 | `NewCallRequest.autoStart`, `CallTask.autoStartBlocked` |
| `app/lib/features/calls/domain/intake_models.dart` | 신규 | `PlanDraft`, `IntakeResult` |
| `app/lib/features/calls/domain/counterparties.dart` | 신규 | 최근 통화한 곳, 이름 정규화 |
| `app/lib/features/calls/data/calls_repository.dart` | 수정 | `intake()` |
| `app/lib/features/calls/presentation/home_screen.dart` | 수정 | 입력칸, 제안 |
| `app/lib/features/calls/presentation/plan_card_screen.dart` | 신규 | 계획 카드 |
| `app/lib/core/router/app_router.dart` | 수정 | `/plan` |
| `app/lib/features/calls/presentation/call_detail_screen.dart` | 수정 | 막힘 안내 |
| `app/test/support/fakes.dart` | 수정 | `intake` 대역, `create` 요청 기록 |
| `app/test/intake_flow_test.dart` | 신규 | AC-017, AC-018, AC-022, AC-024(양식) |
| `app/test/plan_card_test.dart` | 신규 | AC-019~AC-021, AC-023 |
| `app/test/unit_test.dart` | 수정 | AC-018 단위, AC-023 파싱, 정규화 벡터 |

확인만 하는 파일: `app/lib/features/calls/application/calls_controller.dart`(`create`가 이미 `NewCallRequest`를 받음, 변경 불필요할 것으로 봄 — run-phase에서 확인), `app/lib/core/network/api_client.dart`(오류 문구 대응표 재사용, 변경 없음), `server/src/store/taskStore.ts`(변경 없음), `server/src/container.ts`(변경 없음 — brain은 이미 주입됨).

합계 26개(서버 14, 앱 12) → Tier L.

## C. 마일스톤 (우선순위 순, 하나씩 순서대로)

### M1 — 자동 시작 (Priority High)

데이터 모델과 소유자 결정 3의 핵심이므로 먼저 한다.
RED: AC-013(`app.test.ts`), AC-014, AC-015, AC-016(`callService.test.ts`). 통합: AC-014 추가 항목.

### M2 — 번호·이름 규칙 (Priority High)

RED: AC-004(`intake.test.ts`, `design.md` §2 표 18행), 정규화 벡터(§3.1).

### M3 — brain 의뢰 해석 (Priority High)

RED: AC-010(`heuristicBrain.test.ts`), AC-008 brain 단·AC-009·AC-007 (a) brain 단(`openaiBrain.test.ts`). AC-007 (a)의 "요청 본문에 원문 번호 없음"은 가리기가 서비스에 있으므로 M4의 `callService.test.ts`에서 본다.

### M4 — 서비스와 엔드포인트 (Priority High)

RED: AC-001, AC-002(`app.test.ts`), AC-003, AC-005, AC-006, AC-007 (a) 요청 본문·(b)~(e), AC-008 서비스 후처리, AC-011, AC-012(`callService.test.ts`).

### M5 — 앱 모델과 계획 카드 (Priority Medium)

RED: AC-019, AC-020, AC-021, AC-023(`plan_card_test.dart`), `unit_test.dart`의 파싱.

### M6 — 홈 화면 (Priority Medium)

RED: AC-017, AC-018, AC-022(`intake_flow_test.dart`), `unit_test.dart`의 최근 통화 계산. 기존 "shows the empty state with quick-start templates"가 무수정 통과하는지 확인.

### M7 — 회귀와 호환 (Priority Low)

AC-024: 서버·앱 전체, `architecture.test.ts`, 기존 테스트 무수정 확인(`git diff`), 양식 경로 무자동시작.

## D. 위험 요소

| 위험 | 내용 | 대응 |
|------|------|------|
| 자동 시작 오류 누수 | `approvePlan` 오류가 `plan()`의 `catch`로 가면, 그 `catch`는 상태가 `planning`이 아니라서 바로 끝나(`callService.ts:316-318`) 오류가 조용히 삼켜지고 막힘 기록이 남지 않는다 | 자동 시작 함수가 모든 오류를 잡아 `autoStartBlocked`로 남긴다(`design.md` §5). AC-015 (5). |
| 계획 승인 없이 전화 | 소유자 결정 3. 사용자는 상대·번호·목적만 확인한다 | 번호는 정책 재검사, 통화 중 승인 유지, 계획 카드에 번호 출처 표시. 잔여 위험 기록. |
| 잘못된 기록 번호 | 같은 이름의 다른 가게 | 연결된 작업만(OD-2), 최신(OD-3), 출처 표시("지난번 통화한 번호"), 한 번 눌러 수정. |
| 번호 후보 오탐 | 날짜·주문번호를 번호로 착각 | 국내 형식만(OD-4), 앞뒤 숫자 경계, 벡터 표(`2024. 12. 25`, `12345678901234`). |
| LLM으로 번호 유출 | 사용자가 쓴 번호가 외부로 감 | 보내기 전 가리기(REQ-007), AC-007 (a). |
| 응답 지연 | 계획·요약 LLM 30 s > 앱 20 s | 의뢰 해석만 15 s 제한(REQ-009)으로 결정적 결과가 앱에 닿게 한다. AC-009 (7). |
| LLM 지어낸 번호 | 목적·정보 글에 LLM이 번호를 넣음 | 서비스 후처리에서 번호 모양 제거(REQ-007 (c)), AC-007 (c). |
| 기존 테스트 | 홈 빈 상태 테스트가 `find.text('식당 예약')` `findsOneWidget`을 단언(`approval_flow_test.dart:37`) | 템플릿 칩을 제안 줄 한 곳에서만 그리고 빈 상태의 칩 줄을 지워 칩이 정확히 하나(REQ-018 (b), AC-018 (3)). 안내 문구·시뮬레이션 배너 유지. |
| 파일 수 | Tier L, 26개 | 마일스톤 7개를 순서대로. 오케스트레이터 판단으로 `manager-lead` 경로 가능(Tier L 조건: 마일스톤 3개 이상 + 파일 10개 이상). |

### D.1 에픽 내 파일 겹침

SPEC-APPROVAL-001과 `callService.ts`(+test), `prompts.ts`, `app.test.ts`, `fakes.dart`, `unit_test.dart`가 겹친다. APPROVAL이 먼저 끝난 상태(`depends_on`)에서 시작하므로 APPROVAL의 안내 줄·정제 코드를 건드리지 않는다. SPEC-FOLLOWUP-001은 이 SPEC의 `plan_card_screen.dart`와 `PlanDraft`를 재사용한다(재통화). SPEC-UX-001은 `home_screen.dart`, `plan_card_screen.dart`를 다시 꾸민다.

## E. 하네스·복잡도 지표

| 지표 | 값 |
|------|-----|
| Tier | L |
| 도메인 수 | 3 (server http·service, server brain·domain, app UI) |
| 변경 파일 수 | 26 (서버 신규 2·수정 12, 앱 신규 5·수정 7) |
| REQ / AC | 24 / 24 |
| 외부 연동 | OpenAI Chat Completions(가짜 `fetch`로만 검증) |
| 사용자 영향 | 홈 화면, 새 계획 카드 화면, 통화 시작 흐름 |
| 권장 하네스 | thorough |
| 실행 경로 | Tier L → `spec-workflow.md`의 Route B(PR 경로: `feat/SPEC-INTAKE-001` 브랜치, 단계별 PR). 앱 화면이 있으므로 조건부 design 단계 대상이지만, 시각 디자인은 SPEC-UX-001이 맡으므로 design 단계를 건너뛸지는 오케스트레이터가 Implementation Kickoff Approval에서 정한다 |
| 작업 방식 | 쓰기 작업자는 직렬. `callService.ts`(+test)를 M1·M4가, `app.test.ts`를 M1·M4가 함께 고치므로 마일스톤을 순서대로 한 작업자가 진행한다. `manager-lead` 조건(마일스톤 3개 이상 + 파일 10개 이상)은 충족하지만 병렬 쓰기 작업자를 두지 않는다 |

## F. 자체 검증

- 마일스톤별 RED/GREEN 원문을 `progress.md` §E.2에 기록.
- `grep -n "phoneNumber" server/src/brain/openaiBrain.ts`에 의뢰 해석 스키마의 번호 필드가 없음을 확인.
- `grep -n "/v1/intake" server/src/http/app.ts`가 한 줄(라우트 등록)이고, 그 핸들러가 서비스 호출 외 규칙을 담지 않음.

## G. sync-phase 문서 항목

- 새 엔드포인트 `POST /v1/intake`(작업을 만들지 않음, 종료 중 503).
- `POST /v1/tasks`의 `autoStart`, 작업의 `autoStartBlocked`.
- 홈 화면 흐름 변경(입력칸 하나, 계획 카드, [이대로 시작] 한 번).
- 번호 제안 원칙(글·기록에서만, 정책 재검사, LLM에 번호를 보내지 않음).
- OD-1 ~ OD-6 기본값 소유자 검토 대기.
