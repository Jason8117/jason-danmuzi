# SPEC-OUTCOME-001 인수 기준

## 공통 검증 명령

```bash
export PATH=/opt/homebrew/Cellar/node/23.7.0/bin:$PATH
S=/Users/jason/Documents/Jason-Danmuzi/Jason-Danmuzi/server
npm --prefix $S test -- src/brain/heuristicBrain.test.ts src/brain/openaiBrain.test.ts src/http/app.test.ts
npm --prefix $S test
npm --prefix $S run typecheck
```

앱(작업 디렉터리 `/Users/jason/Documents/Jason-Danmuzi/Jason-Danmuzi/app`):

```bash
flutter --suppress-analytics test test/unit_test.dart test/outcome_card_test.dart
flutter --suppress-analytics test
flutter --suppress-analytics analyze
```

기준선(오케스트레이터 측정): 서버 typecheck exit 0, 3개 파일 / 33개 테스트. 앱 analyze info 1건(`test/support/fakes.dart:53`), `flutter test` 12개 통과. 앞선 SPEC들의 테스트가 더해진 상태에서 시작한다.

규칙: 테스트를 먼저 작성해 현재 코드에서 실패(RED)하는 것을 확인한 뒤 구현한다. 실제 OpenAI 호출은 하지 않는다(`vi.stubGlobal("fetch", …)` 또는 주입). 결과 값은 OD-1 RESOLVED(`"unverified"` + `source`)를 따른다. 사용자 문구(AC-004, AC-010)는 OD-2 DEFAULT 문구이며, 소유자가 바꾸면 그 문자열만 고친다.

## 인수 기준

### AC-001 — 새 결과는 항상 출처를 가진다 (REQ-001)

- **Given** `HeuristicBrain`과 정상 응답을 돌려주는 가짜 `fetch`를 쓴 `OpenAiBrain`
- **When** 상대 발화가 있는 작업, 없는 작업을 각각 요약하면
- **Then** 네 결과 모두 `source`가 정의되어 있고 값은 `HeuristicBrain` 쪽 `"heuristic"`, `OpenAiBrain` 정상 경로 `"llm"`이다
- 테스트: `server/src/brain/heuristicBrain.test.ts` — "every heuristic outcome declares its source"; `openaiBrain.test.ts` — "a validated LLM outcome is marked as llm"
- RED: 현재 `source` 필드가 없다.

### AC-002 — 휴리스틱은 성공을 주장하지 않는다 (REQ-002, REQ-003)

- **Given** 상대 발화 2줄이 있는 작업 (1) 승인 없음, (2) 거절 승인 1건, (3) 만료 승인 1건
- **When** `HeuristicBrain.summarize`를 호출하면
- **Then** 세 경우 모두 `result`가 `"unverified"`이고 `"success"`가 아니며, (2)(3)은 `followUps`에 "미승인 항목 재검토: <질문>"이 1개씩 있다
- 테스트: `heuristicBrain.test.ts` — "never claims success without LLM verification" (`it.each`)
- RED: 현재 (1)은 `success`, (2)(3)은 `partial`이 나온다.

### AC-003 — 연결되지 않은 통화는 검증된 실패 (REQ-004)

- **Given** 상대 발화가 없는 작업 (1) `connectedAt` 없음, (2) `connectedAt` 있음
- **When** `HeuristicBrain.summarize`를 호출하면
- **Then** 두 경우 모두 `result: "failed"`, `source: "heuristic"`, 요약 문구는 현재 문구(`heuristicBrain.ts:41-47`)와 같다
- 테스트: "keeps a verified failure when the callee never spoke"
- 참고: `result`와 요약은 현재도 통과한다. `source` 단언 때문에 RED.

### AC-004 — 요약 문구가 자동 요약임을 밝힌다 (REQ-005)

- **Given** 상대 발화가 있는 한국어 작업과 영어 작업
- **When** `HeuristicBrain.summarize`를 호출하면
- **Then** 한국어 요약은 "자동 요약(검증되지 않음):"으로, 영어 요약은 "Automatic summary (unverified):"로 시작하고, 각각 "요청한 내용을 확인했습니다." / "The request was handled."를 포함하지 않는다
- 테스트: "labels the heuristic summary as unverified"
- RED: 현재 요약은 "○○과(와) 통화했습니다. 요청한 내용을 확인했습니다."다.

### AC-005 — 요약 LLM 실패는 기록되고 결과에 반영된다 (REQ-001, REQ-006, REQ-009)

- **Given** 다음 각각을 흉내 내는 가짜 `fetch`: (1) 500 응답, (2) `TimeoutError` 이름의 오류, (3) `choices[0].message.content` 없음, (4) `content`가 JSON이 아님, (5) `content`가 `{"result":"great",…}`, (6) `TypeError("fetch failed")`. 그리고 호출을 기록하는 가짜 로거, 상대 발화가 있는 작업(`id: "t-1"`)
- **When** `OpenAiBrain.summarize`를 호출하면
- **Then** 여섯 경우 모두 결과 `source`가 `"heuristic"`이고 `result`가 `"success"`가 아니며, warn 로그가 정확히 1건이고 그 객체에 `op: "summarize"`, `taskId: "t-1"`, 원인 분류(각각 `http_status`(+ `status: 500`), `timeout`, `empty_content`, `invalid_json`, `schema_mismatch`, `network`)가 담긴다. 로그 객체와 메시지를 문자열로 바꾸었을 때 API 키, 대화 문장, 가짜 응답 본문(예: (4)의 `content` 원문), `JSON.parse` 오류 문구(`"Unexpected token"` 등)가 들어 있지 않다. 결과의 `summary`·`keyFacts`에는 대화 내용이 들어 있어도 된다(REQ-009의 금지 대상 아님)
- 테스트: `server/src/brain/openaiBrain.test.ts` — "falls back visibly when the summary LLM fails" (`it.each`)
- RED: 현재 대체 결과는 `success`를 낼 수 있고, 로그에는 `{ err }`만 있다(`openaiBrain.ts:88`).

### AC-006 — 검증된 LLM 결과는 그대로 (REQ-007)

- **Given** `{"result":"success","summary":"7시 예약 완료","keyFacts":["7시"],"followUps":[]}`를 `content`로 돌려주는 가짜 `fetch`
- **When** `OpenAiBrain.summarize`를 호출하면
- **Then** 결과가 `result: "success"`, `source: "llm"`, 나머지 필드는 응답과 같고 warn 로그는 0건이다
- 테스트: "a validated LLM outcome is marked as llm"

### AC-007 — 계획 LLM 실패도 기록된다 (REQ-008, REQ-009)

- **Given** 500을 돌려주는 가짜 `fetch`
- **When** `OpenAiBrain.createPlan`을 호출하면
- **Then** 반환된 계획은 `HeuristicBrain.createPlan` 결과와 같고, warn 로그 1건에 `op: "plan"`과 `reason: "http_status"`가 있으며 API 키가 없다
- 테스트: "logs which operation fell back during planning"
- RED: 현재 로그에 `op`이 없다.

### AC-008 — 서버 타입과 LLM 스키마의 관계 (REQ-010)

- **Given** `content`가 `{"result":"unverified",…}`인 가짜 응답
- **When** `OpenAiBrain.summarize`를 호출하면
- **Then** 스키마가 이를 거부해 대체 경로(`source: "heuristic"`, `reason: "schema_mismatch"`)로 간다. 그리고 `npm run typecheck`가 exit 0이다(도메인 `OutcomeResult`가 네 값을 가짐)
- 테스트: "the LLM schema only accepts the three LLM result values"

### AC-009 — 앱 모델: 새 형태와 예전 형태 (REQ-011, REQ-013)

- **Given** `taskJson(outcome: …)`으로 만든 JSON: (1) `{"result":"unverified","source":"heuristic",…}`, (2) `{"result":"success","source":"llm",…}`, (3) 예전 형태 `{"result":"partial",…}`(source 없음), (4) `{"result":"success","source":"something_new",…}`
- **When** `CallTask.fromJson`으로 파싱하면
- **Then** (1) `unverified`·`heuristic`, (2) `success`·`llm`, (3) `partial`·`unknown`, (4) `success`·`unknown`이고 예외가 없다. 기존 테스트 "parses outcomes"는 수정 없이 통과한다
- 테스트: `app/test/unit_test.dart` — "parses outcome result and source, old and new"
- RED: 현재 (1)은 `failed`로 파싱되고 `source` 필드가 없다.
- 서버 쪽 REQ-013 확인: 서버 코드에 저장된 결과를 다시 쓰는 경로가 없음(`grep -n "outcome" server/src/store/taskStore.ts server/src/services/callService.ts`에서 대입은 `callService.ts`의 `summarize` 한 곳뿐).

### AC-010 — 앱 표시 (REQ-012)

- **Given** `status: "completed"`이고 결과가 (1) `unverified`, (2) `success`인 작업으로 만든 `OutcomeCard`
- **When** 위젯을 렌더링하면
- **Then** (1)에서 "결과 미확인"과 "자동 요약이라 목표를 이뤘는지 확인하지 못했어요. 대화 기록을 직접 확인해 주세요."가 보이고, "목표 달성" 텍스트와 `Icons.check_circle_rounded` 아이콘은 없다. (2)는 지금처럼 "목표 달성"과 `Icons.check_circle_rounded`가 보인다
- 테스트: `app/test/outcome_card_test.dart` — "shows an unverified outcome distinctly", "keeps the success presentation"
- RED: 현재 `OutcomeResult.unverified`가 없어 컴파일 실패 또는 "달성 못 함"이 보인다.

### AC-011 — 서버 통합 흐름 (회귀 + 의도한 변경)

- **Given** `server/src/http/app.test.ts`의 테스트 "plans, calls, pauses for approval and summarizes"(테스트 이름으로 찾는다. f4d531e 기준 결과 단언은 `:95`이지만 POLICY가 같은 파일에 테스트를 먼저 추가하므로 줄 번호가 바뀔 수 있다)
- **When** 이 테스트의 결과 단언 `expect(done.outcome?.result).toBe("success")`를 `.toBe("unverified")`로 바꾸고, 바로 아래에 `expect(done.outcome?.source).toBe("heuristic")` 한 줄을 **추가**한 뒤 테스트를 실행하면
- **Then** 이 테스트가 통과하고, 이 두 줄 외의 단언은 수정되지 않았으며, 다른 `app.test.ts` 테스트는 수정 없이 통과한다
- RED: 두 줄을 바꾼 직후 현재 코드에서는 `success`가 나와 실패한다.

### AC-012 — 회귀 없음

- 서버 `npm test` 전체 통과, `npm run typecheck` exit 0.
- 앱 `flutter test` 전체 통과, `flutter analyze` 결과가 기준선(info 1건)보다 늘지 않음.

## 엣지 케이스

- `result: "unverified"`인 작업에 `task.error`도 있는 경우: 카드가 오류 문구를 지금처럼 함께 보여 준다(`outcome_card.dart:50-53` 동작 유지).
- LLM이 `success`를 냈지만 대화 기록이 비어 있는 경우: 이 SPEC 범위 밖(§6 요약 품질). 다만 `callService.ts:309-315`의 "상대가 말하지 않음" 오류 처리는 그대로 동작한다.

## 잔여 위험

- 업데이트하지 않은 앱은 같은 릴리스 배포 뒤에도 `"unverified"` 결과를 실패 상태("달성 못 함")로 보여 준다(`call_models.dart:145`의 모르는 값 → `failed`). 소유자가 OD-1을 택하면서 함께 수용한 위험이며, 이 SPEC의 인수 기준으로는 검증하지 않는다.
- LLM이 낸 `success` 판정의 정확도는 검증하지 않는다(spec.md §6 요약 품질).

## 완료 정의 (Definition of Done)

- AC-001 ~ AC-012 충족, RED/GREEN 원문을 `progress.md` §E.2에 기록.
- 서버와 앱 변경을 같은 릴리스로 내보낸다는 배포 조건이 sync-phase 문서에 들어감(plan.md §G).
- OD-2, OD-3 기본값이 소유자 검토 대기 중임을 sync-phase 문서에 기록.
