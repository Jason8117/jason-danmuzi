# SPEC-ARCH-001 근거 자료

모든 줄 번호는 커밋 `f4d531e` 기준 작업 트리에서 직접 읽어 확인했다. 앞선 네 SPEC이 구현된 뒤에는 줄 번호가 달라지므로, run-phase 시작 시 다시 확인한다.

## 1. HTTP 계층의 구체 제공자 의존

`server/src/http/app.ts`

- `:12` `import type { KatCallProvider } from "../providers/kat/katProvider.js";`
- `:16-22` `AppDeps { config; calls; bus; kat?: KatCallProvider; logger? }`
- `:68-78` `preParsing` 훅: `if (!request.url.startsWith("/kat/")) return payload;` — 원문 본문 캡처가 KAT 경로 접두어에 묶임.
- `:98-103` 인증 훅은 `/v1/`로 시작하는 경로에만 적용.
- `:107-111` `/v1/config`: `realCalls: config.provider === "kat"`.
- `:162-175` `if (kat) { app.post("/kat/status", …kat.isValidHttpWebhook…kat.handleStatusWebhook(request.body as …)…); app.get("/kat/media", { websocket: true }, …kat.attachMediaStream(socket, request.raw)) }`

연결: `server/src/container.ts:13-17` `Container { calls; bus; kat? }`, `:59` `return { calls, bus, kat }`; `server/src/index.ts:9,12` `buildApp({ config, calls, bus, kat })`.

문서: `.moai/project/structure.md:71`이 "KAT 전용 라우트는 `http/app.ts`에 있으며 KAT 제공자가 활성화된 경우에만 등록된다"고 현재 상태를 기록하고 있다. `:150` "새 통신사·발신 제공자: `CallProvider` 구현 추가 후 `container.ts`, `config.ts`에 선택 조건 추가" — 실제로는 `http/app.ts`도 고쳐야 한다.

## 2. 제공자 → brain 의존

`grep -rn 'from "\.\./brain\|from "\.\./\.\./brain' server/src/providers` 결과(이 세션):

```
src/providers/simulatedProvider.ts:2:import { detectScenario, SCENARIO_TEMPLATES } from "../brain/scenario.js";
src/providers/realtimeBridge.ts:2:import { buildAgentInstructions } from "../brain/prompts.js";
```

- `realtimeBridge.ts:61` `const task = session.task();`, `:142` `instructions: buildAgentInstructions(task)`.
- `simulatedProvider.ts:51` 시나리오 템플릿으로 각본 답변(`calleeAnswers`)과 승인 질문(`approvalAsk`)을 고른다.
- `brain/heuristicBrain.ts:3`도 같은 `scenario.js`를 쓴다(계획 템플릿).
- `brain/prompts.ts:12-47` `buildAgentInstructions(task)` — 순수 함수.

문서화된 방향: `.moai/project/structure.md:50-66` 그림에서 `brain/`과 `providers/`는 나란히 `domain/`을 향하고, 서로를 향하지 않는다.

오케스트레이터가 넘긴 근거에는 `realtimeBridge.ts:2`만 있었다. `simulatedProvider.ts:2`는 이 SPEC 작성 중 위 grep으로 찾은 추가 사례다.

## 3. 외부 JSON의 `any`

`grep -cE 'Record<string, any>|: any\b' …` 결과(이 세션): `katProvider.ts` 4, `realtimeBridge.ts` 2.

- `katProvider.ts:300` `api()` 반환 타입 `Promise<Record<string, any>>`
- `katProvider.ts:314` `let json: Record<string, any> = {};`
- `katProvider.ts:317` `JSON.parse(text) as Record<string, any>`
- `katProvider.ts:330` `return json.result as Record<string, any>;`
- `katProvider.ts:324` 오류 문구 추출 `json.message ?? json.error ?? text.slice(0, 200) ?? response.statusText` — `json`이 배열이나 문자열이면 의미가 어긋난다.
- `katProvider.ts:153-160` `handleStatusWebhook(payload: { data?: {…} })` — 타입만 선언, 실행 시 검증 없음. 호출부 `app.ts:168` `request.body as { data?: Record<string, unknown> }`.
- `katProvider.ts:219-234` 미디어 프레임: 타입 선언 + `JSON.parse`만, 검증 없음.
- `realtimeBridge.ts:159` `let event: Record<string, any>;` (AI 소켓 메시지)
- `realtimeBridge.ts:166-192` 유형별 처리: `event.delta`, `event.transcript`, `event.name`, `event.call_id`, `event.arguments`, `event.error?.message`를 검증 없이 사용. `String(event.transcript ?? "")`은 숫자도 문자열로 바꿔 대화 기록에 넣는다.
- `realtimeBridge.ts:262` `let event: Record<string, any>;` (KAT 미디어 소켓 메시지), `:268` `event.media?.payload`.
- `realtimeBridge.ts:101-110` 도구 인자: `JSON.parse` 후 `typeof args.question === "string"` 검사만.

비교: HTTP 입력은 `server/src/http/schemas.ts:5-55`에서 모두 zod로 검증한다. zod 4.6.7이 이미 의존성이다(`server/node_modules/zod/package.json` 버전 확인).

## 4. 제공자 식별자

- `server/src/domain/types.ts:83` `provider: "simulated" | "kat";`
- `server/src/providers/types.ts:30` `readonly name: "simulated" | "kat";`
- `server/src/config.ts:34-37` `AppConfig.provider: "simulated" | "kat"` — 설정이 고를 수 있는 값.
- `server/src/services/callService.ts:100` `provider: this.provider.name`.
- 앱 `app/lib/features/calls/domain/call_models.dart:202` `isSimulated: json['provider'] == 'simulated'` — 다른 값은 모두 실통화로 본다.

## 5. 테스트 공백

`find server/src -name "*.test.ts"` → `http/app.test.ts`, `domain/domain.test.ts`, `providers/kat/katProvider.test.ts` 세 개. 이 중 `realtimeBridge`, `openaiBrain`/`OpenAiBrain`, `handleStatusWebhook`, `attachMediaStream`, `/v1/stream`을 언급하는 파일은 없다(이 세션 grep; `CallService`를 언급하는 `app.test.ts`만 일치).

- `katProvider.test.ts:1-4` import: `createHmac`, vitest, `toKatPhoneNumber`, 서명 검증 함수 둘. `:39-48` 미디어 업그레이드 서명 계산 방식 — 새 미디어 테스트의 서명 헬퍼로 재사용 가능.
- `app.test.ts:24-43` 시뮬레이션 구성 — `/v1/stream` 테스트에 재사용 가능.

SPEC-OUTCOME-001이 `openaiBrain.test.ts`(요약 경로)와 `heuristicBrain.test.ts`를, SPEC-LIFECYCLE-001이 `callService.test.ts`와 KAT `api()` 시간 제한 테스트를 먼저 만든다.

## 6. 도구 확인

- `server/node_modules/@fastify/websocket/package.json` 버전 11.3.7, `types/index.d.ts:39`에 `injectWS: InjectWSFn<RawRequest>` 선언(이 세션 grep).
- `server/node_modules/vitest/package.json` 버전 5.1.1.
- `server/tsconfig.json` `"exclude": ["src/**/*.test.ts"]` — 테스트 파일은 `npm run typecheck` 대상이 아니다.

## 7. 장기 방향과의 관계

`.moai/project/structure.md:163` — 허브 채널을 제공자로 둘지는 미정. 제공자 중립 라우트 계약과 세션 지시문 주입은 어느 쪽으로 정해지든 HTTP·brain을 다시 고치지 않게 하는 최소 경계다. 작업 소유권 모델이 없다는 점(`CallTask`에 소유자 필드 없음, `domain/types.ts:73-89`)은 허브 연동의 선행 과제로만 기록한다.
