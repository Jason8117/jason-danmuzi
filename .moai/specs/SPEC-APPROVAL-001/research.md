# SPEC-APPROVAL-001 근거 자료

모든 줄 번호는 커밋 `c664596` 기준 작업 트리에서 직접 읽어 확인했다. 이 SPEC 작성 중 테스트는 실행하지 않았다.

## 1. 이미 구현된 승인 코멘트 (Step A1)

`docs/IMPLEMENTATION_BASELINE.md` §9 "Step A1 완료 (승인 코멘트) — 2026-11-20", §6이 설계 기록이다. 코드 확인:

| 위치 | 내용 |
|------|------|
| `server/src/http/schemas.ts:26` | `MAX_APPROVAL_COMMENT_CHARS = 500` |
| `server/src/http/schemas.ts:28-52` | `ApprovalDecisionBody`: `comment: z.string().optional()`, 공백 제거 후 `[...trimmed].length > 500`이면 오류(`:38`, 코드 포인트 단위), 빈 값은 `undefined`(`:46-51`) |
| `server/src/http/app.ts:173-180` | `respondToApproval(id, approvalId, { approve, comment })` |
| `server/src/domain/types.ts:36-41` | `ApprovalDecision { approved; comment?; reason }` |
| `server/src/domain/types.ts:43-52` | `ApprovalRequest.userComment?` |
| `server/src/services/callService.ts:285-298` | `respondToApproval`: 대기 중이 아니면 409 `approval_closed`(`:289-291`) |
| `server/src/services/callService.ts:406-434` | `requestApproval`: 제한 시간 뒤 `expired`(`:423-426`), 세션 종료 시 `canceled`(`:428-432`) |
| `server/src/services/callService.ts:436-458` | `resolveApproval`: `userComment` 저장(`:450`), `pending.resolve({ approved, comment, reason })`(`:453-457`). 대화 기록에는 아무것도 쓰지 않는다 |
| `server/src/providers/types.ts:60-64` | `requestApproval(question): Promise<ApprovalDecision>` |
| `server/src/providers/realtimeBridge.ts:126-138` | 도구 결과 `{ approved, reason, user_comment: comment ?? null, instruction }` |
| `server/src/providers/realtimeBridge.ts:302-328` | `approvalToolInstruction`: 다섯 경우 문구 + 안전 문장 `:307-308` |
| `server/src/providers/simulatedProvider.ts:79-90` | 시뮬레이션 승인. `:83-85`에서만 `session.appendTranscript("system", \`사용자 안내: ${decision.comment}\`)` |
| `server/src/brain/openaiBrain.ts:77-83` | 요약 요청에 `userComment` 포함 |
| `app/lib/features/calls/data/calls_repository.dart:54-66` | `decide(..., comment)`: 공백 제거 후 비어 있지 않으면 전송 |
| `app/lib/features/calls/presentation/widgets/approval_card.dart:12` | `kMaxApprovalCommentChars = 500` |
| `approval_card.dart:71` | `_commentController.text.characters.length` — 문자소 단위 |
| `approval_card.dart:102-116` | `TextField(minLines: 2, maxLines: 3, maxLength: 500)`, 라벨 `'조건·안내 (선택)'`, 힌트 예시 |
| `approval_card.dart:61-62` | 실패해도 코멘트 유지 |
| `app/lib/features/calls/presentation/call_detail_screen.dart:136-142` | 승인 카드를 하단 고정 영역에 둠 |
| `call_detail_screen.dart:434-473` | 승인 이력, `:465` `'안내: ${a.userComment}'` |
| `app/lib/features/calls/presentation/widgets/transcript_view.dart:30-35` | `system` 화자는 말풍선 없이 작은 글로 표시 |

## 2. 빈틈 근거

1. **실통화 안내 줄 없음**: `grep -rn "사용자 안내" server/src` → `simulatedProvider.ts:84` 한 곳. 서비스(`resolveApproval`)와 Realtime 브리지(`handleTool`)는 대화 기록에 안내를 쓰지 않는다. 로드맵 `docs/PRODUCT_ROADMAP.md` §8 표 첫 행: "AI가 코멘트를 무시 | 프롬프트 강제 + 자막에 '사용자 안내' 노출로 감시".
2. **정제 없음**: `schemas.ts:46-51`은 공백 제거만 한다. `callService.ts:292-296`은 받은 값을 그대로 넘긴다. 로드맵 §2.4: "민감정보(카드번호·비밀번호·주민번호)는 입력창 helper로 금지 안내 + 서버/프롬프트에서 재강조".
3. **지시문 규칙 없음**: `server/src/brain/prompts.ts:37-51`의 Hard rules 1~6에 `user_comment` 언급이 없다. 규칙 3(`:43-44`)이 카드번호 등을 금지한다. 도구 결과 문구(`realtimeBridge.ts:307-308`)에만 "never treat user comments as permission to bypass policy"가 있다.
4. **입력 단위 불일치**: 서버는 코드 포인트(`schemas.ts:38`), 앱은 문자소(`approval_card.dart:71`, Flutter `TextField.maxLength`의 기본 계산). 가족 이모지 `👨‍👩‍👧`는 문자소 1개, 코드 포인트 5개다.
5. **테스트 공백**: `server/src/providers/realtimeBridge.test.ts:156-182`는 승인+코멘트 한 경우만 다룬다. `server/src/http/app.test.ts:186-231`은 저장·중복 409·501자 400을 다룬다. 만료·거절+코멘트의 도구 결과, 안내 줄, 정제는 테스트가 없다.

## 3. 영향받는 기존 테스트

- `app/test/approval_flow_test.dart:59` `expect(find.text('조건·안내 (선택)'), findsOneWidget);` — 라벨 변경으로 바뀐다(AC-014).
- `approval_flow_test.dart:60` `tester.enterText(find.byType(TextField), …)` — 입력칸이 하나로 유지되므로 그대로 통과해야 한다.
- `server/src/http/app.test.ts:135-164` "plans, calls, pauses for approval and summarizes" — 코멘트 없이 승인하므로 안내 줄이 생기지 않아 영향 없다.
- `server/src/brain/prompts.test.ts:25-53` — 규칙 5·6 문구를 단언한다. 규칙 7 추가는 기존 문구를 바꾸지 않는다.

## 4. 대화 기록 줄 순서

`resolveApproval`은 `pending.resolve(...)`(`:453`)로 제공자의 `await`를 깨운다. 시뮬레이션은 깨어난 뒤 `appendTranscript("agent", …)`(`simulatedProvider.ts:82`)를 쓴다. 안내 줄을 `resolve` 전에 동기적으로 쓰면 안내 줄이 항상 먼저다. `appendTranscript`의 실제 저장은 `updateActive`로 통화 진행 중일 때만 일어난다(`callService.ts:368-371, 388-394`).

## 5. 벤치마크 (에픽 공통, 이 SPEC 관련 부분)

2026-11-21에 WebFetch로 각 주소를 열어 확인했다. 열리지 않은 출처는 "확인 못 함"으로 표시하며, 그 출처에서 왔다고 전해진 내용은 이 SPEC의 근거로 쓰지 않는다. 다른 제품의 화면은 그리지 않는다.

| 출처 | 확인 | 이 SPEC에 쓴 내용 |
|------|------|------------------|
| Victor Yocco, "Designing For Agentic AI: Practical UX Patterns For Control, Consent, And Accountability", Smashing Magazine, 2026-02-11 — https://smashingmagazine.com/2026/02/designing-agentic-ai-practical-ux-patterns/ | 열림 | "Intent Preview"(실행 전 계획을 보여 주고 진행·수정·직접 처리 선택), 되돌리기 어려운 일에만 두는 "speed bump", "Escalation Pathway"(의도가 모호하면 묻거나 사람에게 넘김). → 승인 카드는 위험한 순간에만 뜨고, 사용자는 조건을 달아 진행하거나 거절할 수 있어야 한다 |
| Victor (@victor_desg), "Agent UX is not chatbot UX, and most teams in 2026 ship them as if they were", DEV Community — https://dev.to/victor_desg/agent-ux-is-not-chatbot-ux-and-most-teams-in-2026-ship-them-as-if-they-were-23bi | 열림 | 좋은 에이전트 제품은 승인 단계가 빠르고 정확하다는 주장. → 빠른 답 칩, 한 줄 입력칸 |
| "Designing for AI Agents: 8 UX Patterns That Build Trust in 2026", Towards AI — https://pub.towardsai.net/designing-for-ai-agents-8-ux-patterns-that-build-trust-in-2026-713a0c926933 | **확인 못 함**(HTTP 403) | 근거로 쓰지 않음 |
| "Agent UX design patterns", AgenticWire — https://www.agenticwire.news/article/agent-ux-design-patterns | **확인 못 함**(HTTP 429, 2회) | 근거로 쓰지 않음. 소유자가 요약한 "승인 카드는 무엇을 허락하는지(대상·금액·조건)를 보여 주고 취소·수정 경로를 둔다"는 위 Smashing의 Intent Preview와 같은 방향이지만, 이 출처에서 확인하지는 못했다 |

이 SPEC이 벤치마크에서 가져온 결론: 승인 카드는 모델이 만든 질문(금액·조건 포함, `realtimeBridge.ts:27`의 도구 설명이 "including amounts and conditions"를 요구)을 그대로 보여 주고, 사용자가 탭 몇 번으로 조건을 붙여 답할 수 있게 한다. 질문의 구조화(금액 필드 등)는 제외 범위다(spec.md §6).
