# SPEC-OUTCOME-001 근거 자료

모든 줄 번호는 커밋 `f4d531e` 기준 작업 트리에서 직접 읽어 확인했다.

## 1. 조용한 대체 경로

`server/src/brain/openaiBrain.ts`

- `:15-20` `OutcomeSchema = z.object({ result: z.enum(["success","partial","failed"]), summary, keyFacts, followUps })`
- `:26` 클래스 주석: "Any API or validation failure degrades to the heuristic brain instead of failing the task."
- `:29` `private readonly fallback = new HeuristicBrain();` (`:28`은 `readonly name = "openai" as const;`)
- `:62-91` `completeJson`: `fetch`(`:80` `AbortSignal.timeout(30_000)`), `res.ok` 검사(`:82`), 빈 내용 검사(`:85`), `schema.parse(JSON.parse(content))`(`:86`).
- `:87-89` `catch` → `this.log.warn({ err: (error as Error).message }, "LLM call failed, using heuristic fallback")` → `return fallback()`.

로그에는 실패 원인 메시지만 있고, 계획인지 요약인지, 어떤 작업인지가 없다. 결과에는 대체 여부가 남지 않는다.

`server/src/container.ts:23-26` — `OPENAI_API_KEY`가 없으면 처음부터 `HeuristicBrain`을 쓴다(이 경우도 결과는 LLM 검증을 받지 않음).

## 2. 휴리스틱의 성공 주장

`server/src/brain/heuristicBrain.ts:32-64` `summarize`

- `:34` 상대 발화 목록, `:35` 거절·만료 승인 목록.
- `:37-51` 상대 발화가 없으면 `failed` + 연결 실패 문구.
- `:53` `const result = rejected.length > 0 ? "partial" : "success";`
- `:54-56` 요약: ko "`${targetName}`과(와) 통화했습니다. 요청한 내용을 확인했습니다." / en "Spoke with … The request was handled."
- `:61` `keyFacts`: 첫 상대 발화를 제외한, 맞장구가 아닌 문장들.

목표(`task.goal`)와 대화 내용을 대조하는 부분이 없다. 상대가 "그 시간엔 자리가 없습니다"라고 해도 `success`다.

**관찰(오케스트레이터, 이 세션)**: API 키 없이 시뮬레이션 모드 서버에서 전체 흐름을 실행했을 때 `outcome.result`가 `"success"`였다. 이 SPEC 작성자는 이 실행을 다시 하지 않았다.

기존 테스트도 이 동작을 고정하고 있다: `server/src/http/app.test.ts:94-95`

```
const done = await waitFor(app, id, (t) => t.status === "completed");
expect(done.outcome?.result).toBe("success");
```

이 테스트는 `HeuristicBrain`(`:29`)과 시뮬레이션 제공자를 쓴다. 이 SPEC을 구현하면 이 단언은 반드시 바뀐다.

## 3. 요약 호출부

`server/src/services/callService.ts:306-322` `summarize`

- `:309` 상대 또는 에이전트 발화 여부.
- `:311-315` 말한 기록이 없으면 오류 문구 설정.
- `:317` `task.outcome = await this.brain.summarize(task);` — 결과를 그대로 저장.
- `:321` 상태 결정: 오류가 있고 발화가 없으면 `failed`, 아니면 `completed`.

결과 객체를 그대로 저장하고 `persist`로 HTTP·스트림에 내보내므로, `source` 필드를 brain에서 붙이면 서비스 코드 변경 없이 앱까지 전달된다.

## 4. 도메인 타입

`server/src/domain/types.ts:54-61`

```
export type OutcomeResult = "success" | "partial" | "failed";
export interface CallOutcome { result: OutcomeResult; summary: string; keyFacts: string[]; followUps: string[]; }
```

`server/src/brain/types.ts:4-8` `CallBrain.summarize(task): Promise<CallOutcome>`.

## 5. 앱 모델과 화면

`app/lib/features/calls/domain/call_models.dart`

- `:16` `awaitingApproval('확인 필요')` — 작업 상태 라벨. 결과 라벨로 "확인 필요"를 쓰면 겹친다.
- `:51-58` `enum OutcomeResult { success('목표 달성'), partial('일부 달성'), failed('달성 못 함') }`
- `:60-61` `_enumByName(values, name, fallback)` — 모르는 이름은 기본값.
- `:144-149` `CallOutcome.fromJson`: `result`는 `_enumByName(OutcomeResult.values, json['result'], OutcomeResult.failed)` — 모르는 값은 `failed`. 이미 설치된 앱이 `"unverified"`를 받으면 "달성 못 함"으로 보인다.

`app/lib/features/calls/presentation/widgets/outcome_card.dart`

- `:25-29` `switch (outcome?.result)`: `success` → 체크 아이콘 + `scheme.primary`, `partial` → 주황, 그 밖 → 오류 아이콘 + `scheme.error`.
- `:40` 라벨 `outcome?.result.label ?? '통화 실패'`.
- `:47` 요약 문구.
- `:50-53` 오류가 있으면 함께 표시.

`app/lib/features/calls/presentation/home_screen.dart:250` — 목록에서 `task.outcome?.summary ?? task.goal`을 보여 준다.

## 6. 기존 앱 테스트

- `app/test/unit_test.dart:30-38` "parses outcomes": `{'result': 'partial', 'summary': '요약', 'keyFacts': ['7시 가능'], 'followUps': []}` → `partial`.
- `app/test/support/fakes.dart:8-43` `taskJson({…, outcome})` — 결과 JSON을 넣을 수 있다.
- `app/test/approval_flow_test.dart` — 위젯 테스트 구성 참고(`testWidgets` 2개).
- 기준선: `flutter test` 12개 통과, `flutter analyze` info 1건 — 오케스트레이터 측정, 이 SPEC 작성 중 재실행하지 않음.

## 7. 테스트 공백

`OpenAiBrain`, `HeuristicBrain.summarize`를 직접 다루는 서버 테스트는 없다. `server/src/domain/domain.test.ts:2`는 `heuristicBrain.ts`에서 `isFiller`만 가져와 테스트한다.
