# SPEC-OUTCOME-001 구현 계획

## A. 접근 방식

### 데이터 모델 (OD-1 RESOLVED: `"unverified"` + `source`)

- `server/src/domain/types.ts`
  - `OutcomeResult = "success" | "partial" | "failed" | "unverified"`
  - `CallOutcome`에 `source?: OutcomeSource` 추가, `OutcomeSource = "llm" | "heuristic"`. 저장된 예전 결과를 읽을 때 필드가 없을 수 있으므로 타입에서는 선택 필드로 두고, 새로 만드는 결과는 항상 채운다(REQ-001은 테스트로 강제).
- `server/src/brain/openaiBrain.ts`
  - `OutcomeSchema`(LLM 응답 검증)는 지금처럼 `success`/`partial`/`failed`만 받는다. LLM에게 `unverified`나 `source`를 요구하지 않는다.
  - 검증을 통과하면 서버가 `source: "llm"`을 붙인다.
- `app/lib/features/calls/domain/call_models.dart`
  - `OutcomeResult`에 `unverified('결과 미확인')` 추가.
  - `OutcomeSource { llm, heuristic, unknown }` 추가, `CallOutcome.source` 필드(없거나 모르는 값 → `unknown`).
  - 모르는 `result` 값은 지금처럼 `failed`로 둔다(새 앱 기준으로도 미래 값에 대한 안전한 기본값).

서버와 앱 변경은 같은 릴리스로 내보낸다(OD-1 RESOLVED). sync-phase 문서에 이 배포 조건을 적는다(§G).

### 휴리스틱 요약

- 상대 발화 없음 → 지금과 같은 `failed` 결과 + `source: "heuristic"`.
- 상대 발화 있음 → `result: "unverified"`, `source: "heuristic"`, 요약은 OD-2 접두어 + 사실만 담은 문장("○○과(와) 통화했습니다." + 거절 항목이 있으면 "일부 조건은 승인하지 않아 진행하지 않았습니다."). `keyFacts`와 `followUps` 계산은 지금과 같다.

### OpenAI 대체 경로

`completeJson`의 `catch`에서 실패 원인을 분류해(시간 초과는 `AbortSignal.timeout`의 `TimeoutError` 이름, `res.ok` 거짓은 상태 코드, `JSON.parse` 실패, zod 실패, 빈 내용, 그 밖은 `network`) 작업 이름과 함께 기록한다. 로그에는 분류·상태 코드·`op`·작업 ID만 넣고, 오류 객체의 `message`는 넣지 않는다. `JSON.parse`의 오류 메시지는 입력 일부를 담고, zod 오류는 값 일부를 담을 수 있기 때문이다(REQ-009). 지금의 `{ err: (error as Error).message }`(`openaiBrain.ts:88`)는 이 이유로 없앤다. 작업 ID를 로그에 넣기 위해 `completeJson`에 작업 이름과 작업 ID를 넘긴다(요약은 `task.id`가 있고, 계획은 아직 작업 ID를 받지 않으므로 로그에서 생략).

대체 결과는 `HeuristicBrain.summarize`가 이미 `source: "heuristic"`을 붙이므로 그대로 쓰면 된다.

### 앱 표시

`OutcomeCard`의 `switch`에 `OutcomeResult.unverified` 분기를 더한다: 아이콘(예: `Icons.help_outline_rounded`)과 중립 색(예: `scheme.onSurfaceVariant`), 라벨 "결과 미확인", 요약 아래에 OD-2 안내 문구. `success`·`partial`·`failed` 표시와 취소 카드는 바꾸지 않는다. 홈 화면 목록(`home_screen.dart:250`)은 요약 문구를 보여 주므로 접두어가 그대로 드러난다(추가 변경 없음).

## B. 변경 파일

서버:

| 파일 | 변경 | 이유 |
|------|------|------|
| `server/src/domain/types.ts` | 수정 | `OutcomeResult`에 `unverified`, `OutcomeSource`, `CallOutcome.source?` |
| `server/src/brain/heuristicBrain.ts` | 수정 | 성공 주장 제거, 접두어, `source` |
| `server/src/brain/openaiBrain.ts` | 수정 | `source: "llm"`, 실패 원인 분류 로그(요약·계획) |
| `server/src/brain/heuristicBrain.test.ts` | 신규 | 휴리스틱 요약 단위 테스트 |
| `server/src/brain/openaiBrain.test.ts` | 신규 | 성공·실패 응답(가짜 `fetch`) 테스트, 스키마 관계 테스트 |
| `server/src/http/app.test.ts` | 수정 | 테스트 "plans, calls, pauses for approval and summarizes"의 `expect(done.outcome?.result).toBe("success")`(f4d531e 기준 `:95`)를 `"unverified"`로 바꾸고 `source` 단언 1줄 추가(이 SPEC이 의도한 동작 변경) |

`server/src/brain/types.ts`(`CallBrain` 인터페이스)와 `server/src/services/callService.ts`(`summarize` 호출부)는 바꾸지 않는다. 결과 객체를 그대로 저장·전송하므로 새 필드가 자연히 실린다.

앱:

| 파일 | 변경 | 이유 |
|------|------|------|
| `app/lib/features/calls/domain/call_models.dart` | 수정 | `OutcomeResult.unverified`, `OutcomeSource`, `CallOutcome.source` |
| `app/lib/features/calls/presentation/widgets/outcome_card.dart` | 수정 | 검증되지 않은 결과 표시 |
| `app/test/unit_test.dart` | 수정 | 예전·새 결과 JSON 파싱 |
| `app/test/outcome_card_test.dart` | 신규 | 위젯 표시 테스트 |

## C. 마일스톤 (우선순위 순, 하나씩 순서대로)

### M1 — 도메인 타입과 휴리스틱 (Priority High)

데이터 모델(OD-1 RESOLVED)을 코드에 처음 반영하는 단계이므로 가장 먼저 한다.

RED (`server/src/brain/heuristicBrain.test.ts`):
- 상대 발화 2줄, 승인 없음 → `result` 가 `success`가 아님(`unverified`), `source` `heuristic`. 현재 `success`가 나와 실패.
- 같은 입력에서 요약이 접두어로 시작하고 "요청한 내용을 확인했습니다."를 포함하지 않음. 영어 작업도 같은 방식.
- 거절 승인 1건 → `unverified`, `followUps`에 재검토 항목 1개.
- 상대 발화 없음 → `failed`, `source` `heuristic`, 요약 문구는 현행 유지.

### M2 — OpenAI 대체 경로 (Priority High)

RED (`server/src/brain/openaiBrain.test.ts`, `vi.stubGlobal("fetch", …)`):
- 500 응답, 시간 초과(`TimeoutError` 이름의 오류를 던지는 가짜 `fetch` — 아래 위험 참고), 빈 `content`, 잘못된 JSON, 스키마 불일치(`result: "great"`), 네트워크 오류 각각 → 결과 `source` `heuristic`, `result`는 `success`가 아님, warn 로그 1건에 `op: "summarize"`, 원인 분류, `taskId` 포함, 로그에 API 키·대화 문자열·응답 본문·`JSON.parse` 오류 문구 없음.
- 정상 응답(`result: "success"`) → `result` `success`, `source` `llm`.
- 계획 실패 → warn 로그에 `op: "plan"`, 계획은 휴리스틱 템플릿(현행).
- 스키마 관계: LLM 스키마가 `unverified`를 거부하는지(정상 응답에 `result: "unverified"`를 넣으면 대체 경로로 감).

### M3 — 서버 통합 테스트 갱신 (Priority High)

- 테스트 "plans, calls, pauses for approval and summarizes"의 결과 단언을 `"unverified"`로 바꾸고 `expect(done.outcome?.source).toBe("heuristic")` 1줄을 추가한다. POLICY가 같은 파일에 테스트를 먼저 추가하므로 줄 번호가 아니라 테스트 이름으로 찾는다. 이 변경은 SPEC이 의도한 것이며 기존 동작이 거짓 성공이었음을 기록한다. 같은 테스트의 나머지 단언은 그대로.

### M4 — 앱 모델 (Priority Medium)

RED (`app/test/unit_test.dart`):
- `{"result":"unverified","source":"heuristic",…}` → `OutcomeResult.unverified`, `OutcomeSource.heuristic`. 현재는 `failed`로 파싱되어 실패.
- 예전 형태 `{"result":"partial",…}`(source 없음) → `partial`, `unknown`. 기존 테스트 "parses outcomes"는 수정 없이 통과.
- `source: "something_new"` → `unknown`, 예외 없음.

### M5 — 앱 표시 (Priority Medium)

RED (`app/test/outcome_card_test.dart`):
- `unverified` 결과 → "결과 미확인" 라벨과 안내 문구가 보이고, "목표 달성" 텍스트와 `Icons.check_circle_rounded`가 없다.
- `success` 결과 → 지금처럼 "목표 달성"과 체크 아이콘(보호 테스트).

### M6 — 회귀 확인 (Priority Low)

서버 전체 테스트·타입 검사, 앱 `flutter analyze`·`flutter test`.

## D. 위험 요소

| 위험 | 내용 | 대응 |
|------|------|------|
| 파일 겹침 | 아래 §D.1 행렬. `domain/types.ts`(LIFECYCLE, ARCH), `heuristicBrain.ts`(ARCH가 시나리오 import 경로 수정), `openaiBrain.test.ts`(ARCH가 확장), `app.test.ts`(POLICY, ARCH), `unit_test.dart`(LIFECYCLE, ARCH) | POLICY 뒤에 구현한다(`depends_on`). `domain/types.ts`에서는 결과 관련 타입만 건드린다. ARCH는 이 SPEC이 만든 `openaiBrain.test.ts`를 확장하고 `heuristicBrain.ts`의 import 한 줄만 바꾼다. |
| 기존 테스트 변경 | 테스트 "plans, calls, pauses for approval and summarizes"가 `success`를 기대한다. | 의도한 변경으로 plan·acceptance에 명시. 다른 단언은 수정하지 않는다. |
| 설치된 예전 앱 | 새 값을 `failed`("달성 못 함")로 보여 준다. 같은 릴리스로 내보내도 사용자가 앱을 업데이트하기 전까지는 계속 그렇게 보인다. | 서버와 앱을 같은 릴리스로 내보내 서버만 앞서 나가는 기간을 없앤다(OD-1 RESOLVED, §G). 업데이트 전 기간의 비관적 표시는 소유자가 OD-1과 함께 수용한 잔여 위험이다(spec.md §2). |
| 시간 초과 테스트 | `AbortSignal.timeout(30_000)`은 가짜 타이머로 제어되지 않을 수 있다. | 시간 초과 분류는 `TimeoutError` 이름을 가진 오류를 던지는 가짜 `fetch`로 검증한다(실제 30 s 대기 없음). |
| 위젯 테스트 의존성 | 앱은 `material_ui` 패키지를 쓴다(`outcome_card.dart:1`). | 기존 `approval_flow_test.dart`의 테스트 앱 구성 방식을 따른다. |
| `CallBrain` 반환 타입 | `source`를 선택 필드로 두면 새 결과에서 빠뜨려도 컴파일된다. | REQ-001을 두 brain 테스트에서 단언으로 강제한다. |

### D.1 다섯 SPEC 파일 겹침 행렬 (plan-audit iteration 1 §3.1 기준)

| 파일 | STORE | LIFECYCLE | POLICY | OUTCOME | ARCH |
|------|:-----:|:---------:|:------:|:-------:|:----:|
| server/src/index.ts | O | O | | | O |
| server/src/services/callService.ts | | O | O | | O |
| server/src/services/callService.test.ts | | 신규 | O | | O |
| server/src/domain/types.ts | | O | | O | O |
| server/src/providers/types.ts | | O | | | O |
| server/src/providers/kat/katProvider.ts (+test) | | O | | | O |
| server/src/providers/simulatedProvider.ts | | 확인 | | | O |
| server/src/container.ts | | O | | | O |
| server/src/http/app.ts | | | O | | O |
| server/src/http/app.test.ts | | | O | O | O |
| server/src/brain/heuristicBrain.ts | | | | O | O |
| server/src/brain/openaiBrain.ts | | | | O | |
| server/src/brain/openaiBrain.test.ts | | | | 신규 | O |
| app/test/unit_test.dart | | O | | O | O |

이 SPEC만 쓰는 파일: `heuristicBrain.test.ts`, `call_models.dart`, `outcome_card.dart`, `outcome_card_test.dart`.

## E. 하네스·복잡도 지표

| 지표 | 값 |
|------|-----|
| 도메인 수 | 2 (server brain, app UI·모델) |
| 변경 파일 수 | 10 (서버 신규 2·수정 4, 앱 신규 1·수정 3) |
| REQ / AC | 13 / 12 |
| 외부 연동 | OpenAI(가짜 `fetch`로만 검증) |
| 사용자 영향 | 결과 화면 표시 변경 |
| 권장 하네스 | standard |

## F. 자체 검증

- 마일스톤별 RED/GREEN 원문을 `progress.md` §E.2에 기록.
- 서버: 전체 테스트·타입 검사 통과. 앱: `flutter analyze` 결과가 기준선보다 늘지 않음, `flutter test` 통과.
- 시뮬레이션 모드 전체 흐름(`app.test.ts`)에서 결과가 `unverified` + `source: "heuristic"`임을 확인.

## G. sync-phase 문서 항목

- **배포 조건**: 서버와 앱을 같은 릴리스로 내보낸다. 서버만 먼저 나가면 이미 설치된 앱이 `"unverified"` 결과를 "달성 못 함"으로 보여 준다(OD-1 RESOLVED).
- **잔여 위험(소유자 수용)**: 같은 릴리스여도 업데이트하지 않은 앱은 `"unverified"` 결과를 계속 "달성 못 함"으로 보여 준다. 사용자에게 앱 업데이트를 권하는 안내를 릴리스 노트에 넣는다.
- LLM 없이(또는 LLM 실패로) 만든 결과는 "결과 미확인"으로 표시된다. 문구는 소유자 검토 대기 중인 기본값이다(OD-2 DEFAULT).
- 실패 원인은 로그에만 남는다(OD-3 DEFAULT).
