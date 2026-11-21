# SPEC-INTAKE-001 근거 자료

모든 줄 번호는 커밋 `c664596` 기준 작업 트리에서 직접 읽어 확인했다. 이 SPEC 작성 중 테스트는 실행하지 않았다.

## 1. 지금의 시작 흐름

| 위치 | 내용 |
|------|------|
| `app/lib/features/calls/presentation/home_screen.dart:36-42` | 떠 있는 버튼 "전화 맡기기" → 내 정보가 있으면 `/calls/new`, 없으면 `/settings` |
| `home_screen.dart:181-213` | 작업이 없을 때 `MessageView`("귀찮은 전화, 대신 걸어드릴게요") + 템플릿 `ActionChip` |
| `home_screen.dart:92-113` | 진행 중·지난 통화 목록, 시뮬레이션 배너, 내 정보 안내 |
| `app/lib/features/calls/presentation/new_call_screen.dart:108-160` | 양식: 상대 이름, 번호(숫자 8개 이상 검사 `:121-126`), 목적(5자 이상 `:139`), 알려줄 정보, 언어 |
| `new_call_screen.dart:50-73` | `NewCallRequest`로 생성 후 상세 화면으로 교체 이동 |
| `app/lib/features/calls/presentation/call_detail_screen.dart:170-180` | `awaiting_approval`: 목적 카드 + 계획 검토 |
| `call_detail_screen.dart:222-233` | "이대로 전화 걸기" → `approvePlan` |
| `call_detail_screen.dart:245-253` | 끝난 통화의 "다시 걸기" → `/calls/new`에 작업 전달(양식 미리 채움) |
| `app/lib/features/calls/presentation/call_templates.dart:13-44` | 템플릿 5개 |
| `app/lib/core/router/app_router.dart:11-31` | 경로 4개 |
| `app/lib/features/calls/domain/call_models.dart:256-285` | `NewCallRequest.toJson` — 빈 `context`/`callbackNumber`는 생략 |
| `app/lib/core/config/app_settings.dart:11-28` | 설정의 `requesterName`, `callbackNumber`, `hasProfile` |

## 2. 서버의 생성·계획·승인

| 위치 | 내용 |
|------|------|
| `server/src/http/schemas.ts:5-13` | `CreateTaskBody`(zod 객체 — 모르는 키는 버림) |
| `server/src/http/app.ts:159-163` | `POST /v1/tasks` → `calls.create` → 201 |
| `server/src/services/callService.ts:218-241` | `create`: 종료 검사, 번호 정책, 저장, `void this.plan(...)` |
| `callService.ts:244-267` | `approvePlan`: 검사 순서 503 → 404 → 409 → 400 → 429(`:245-254`), `dialing`, `provider.start` 실패는 `session.end({error})` |
| `callService.ts:309-322` | `plan`: 상태가 `planning`이 아니면 끝(`:313`), 성공 시 `awaiting_approval`, 실패 시 `failed` |
| `callService.ts:96-140` | `recoverInterruptedTasks`: `awaiting_approval`은 건너뜀(`:99`) |
| `callService.ts:324-328` | `assertNotShuttingDown` 503 문구 |
| `callService.ts:348-358` | `assertWithinLimits`: `store.list()`를 부름(AC-015 (5)의 대역 근거) |
| `server/src/domain/stateMachine.ts:3-13` | `awaiting_approval`에서 갈 수 있는 상태는 `dialing`, `canceled`뿐 |
| `server/src/brain/types.ts:4-8` | `CallBrain` 인터페이스(계획·요약 두 가지) |
| `server/src/brain/openaiBrain.ts:93-107` | `completeJson`: 실패 시 `{op, reason, status?, taskId?}` warn 1건 |
| `openaiBrain.ts:39-42` | `CallContext.op: "plan" \| "summarize"` |
| `server/src/brain/openaiBrain.ts:59-68` | 계획 요청에는 번호를 보내지 않음(`calleeName`, `goal`, `shareableInfo`만) — 의뢰 해석도 같은 원칙 |
| `server/src/store/taskStore.ts:45-64` | `InMemoryTaskStore.list()`는 `createdAt` 내림차순 |

## 3. 번호 정책

| 위치 | 내용 |
|------|------|
| `server/src/domain/phone.ts:7-19` | `normalizePhoneNumber`: `+` → 그대로, `00` → 국제, `0` → `+82`, 그 밖 → `+` 붙임 |
| `phone.ts:22` | 차단 목록 9개 |
| `phone.ts:57-67` | `checkTargetNumber`: 원문에서 국가 번호 판정 → 차단, 정규화 실패 → invalid |
| `docs/OPERATIONS.md` "알려진 잔여 위험" | `+82`가 아닌 번호는 숫자만 남긴 형태로 KAT에 전달 |

## 4. 대표번호를 자동 추출하지 않는 이유 (OD-4)

`normalizePhoneNumber("1588-1234")`는 숫자 `15881234`가 `0`·`00`·`+`로 시작하지 않으므로 `+15881234`가 된다(`phone.ts:16`). E.164 정규식(`phone.ts:1`)을 통과하므로 `checkTargetNumber`는 `ok`를 낸다. 이 값은 앱에서 `+15881234`로 보이고(`formatters.dart:4`는 `+82`만 국내 형식으로 바꿈), KAT에는 `toDomesticDialString`이 숫자만 남겨 `15881234`로 보낸다(`phone.ts:31-34`). 발신은 될 수 있지만 표시가 미국 번호처럼 보여 사용자가 계획 카드에서 번호를 확인할 수 없다. 이 정규화 문제는 기존 동작이며 이 SPEC 범위가 아니므로, 의뢰 해석은 대표번호를 제안하지 않는다(위 계산은 코드 읽기에 따른 것이며 실행으로 확인하지 않았다).

## 5. 벤치마크

2026-11-21 WebFetch로 확인. 다른 제품의 화면은 확인하지 못했으므로 그리지 않는다.

| 출처 | 확인 | 이 SPEC에 쓴 내용 |
|------|------|------------------|
| Victor (@victor_desg), "Agent UX is not chatbot UX, and most teams in 2026 ship them as if they were", DEV Community — https://dev.to/victor_desg/agent-ux-is-not-chatbot-ux-and-most-teams-in-2026-ship-them-as-if-they-were-23bi | 열림 | 원문 인용: "The chat box is fine for asking. It is not fine for acting." 편집 가능한 계획 패널과 "one approval button to execute the plan" 권고, 오래 걸리는 일은 대화와 분리된 작업 화면("The chat thread is for conversation. The task surface is for state."). → 홈 입력칸 한 줄 + 계획 카드 + [이대로 시작] 한 번, 통화는 상세 화면 |
| Victor Yocco, "Designing For Agentic AI: Practical UX Patterns For Control, Consent, And Accountability", Smashing Magazine, 2026-02-11 — https://smashingmagazine.com/2026/02/designing-agentic-ai-practical-ux-patterns/ | 열림 | "Intent Preview"(실행 전 계획을 쉬운 말로 보여 주고 진행·수정·직접 처리), "Autonomy Dial"(관찰·제안 → 계획·제안 → 확인 후 실행 → 사전 승인 작업 자율 실행), 신뢰는 "a spectrum". → 이 SPEC은 "계획 카드 확인 후 실행" 한 단계로 고정하고 단계 설정은 제외(spec.md §6). 번호 출처 표시는 "Explainable Rationale"("Because you said X, I did Y")과 같은 방향 |
| Pickle 소개 — Carly 블로그, https://www.usecarly.com/blog/pickle-ai/ | 열림, **경쟁사(Carly)가 쓴 글** | 글이 전하는 기능: 온라인으로 안 되면 전화를 건다, 비용을 먼저 보여 주고 동의한 범위 안에서만 진행, 기억("remembers what it learns")을 사용자가 보고 지움, 채팅·음성이 한 대화로 이어짐. **Pickle 앱의 실제 화면은 확인하지 못했다.** → "최근 통화한 곳"(기억의 가장 작은 형태, 저장 없이 기록에서 계산) |
| "Designing for AI Agents: 8 UX Patterns That Build Trust in 2026", Towards AI | **확인 못 함**(HTTP 403) | 근거로 쓰지 않음 |
| "Agent UX design patterns", AgenticWire | **확인 못 함**(HTTP 429) | 근거로 쓰지 않음 |

소유자가 정리한 결론 중 "입력 한 칸 + 제안이 있는 홈"은 위 확인된 출처가 직접 말하지 않는다. 소유자 방향(최소 입력)과 위 dev.to 글의 "묻기는 채팅, 실행은 계획 카드" 구분에서 이 SPEC이 이끌어 낸 설계이며, 외부 근거로 확인된 사실로 표시하지 않는다.

## 6. 앱 오류 처리와 404

- `app/lib/core/network/api_client.dart:72-85`: 2xx가 아니면 본문의 `error`를 코드로, `message`를 문구로 `ApiException`을 던진다. `statusCode`도 담는다.
- Fastify에 없는 경로는 `setErrorHandler`(`server/src/http/app.ts:122-138`)가 아니라 기본 404 처리로 간다. 기본 본문의 `error` 필드는 `"Not Found"`라는 HTTP 사유 문구다(Fastify 기본 동작에 대한 일반 지식이며 이 저장소에서 실행해 확인하지 않았다). 그래서 앱은 예전 서버 판별에 `statusCode == 404`를 쓴다.
- `api_client.dart:39` 앱 요청 제한 시간 20 s, `openaiBrain.ts:124` 서버 LLM 제한 시간 30 s.

## 7. 저장소 한계와 기록 조회 비용

- 저장소는 단일 JSON 파일, 메모리에 전체 사본(`store/taskStore.ts`, `docs/OPERATIONS.md` "실행 전제"). `list()`는 매번 정렬된 배열을 만든다(`InMemoryTaskStore.list`). 의뢰 해석 1건당 `list()` 1회로 충분하다(번호·이름 둘 다 같은 배열 사용).
- 하루 통화 상한 30건(`config.ts:28`) 기준으로 기록은 천천히 늘어난다. 삭제하지 않는 한 쌓인다. 새 저장소는 만들지 않는다.
