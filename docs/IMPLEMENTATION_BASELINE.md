# CallMate Implementation Baseline (Step 0)

> 작성: 2026-11-20  
> 근거: 실제 저장소 조사 + `01_REVIEW_AND_IMPLEMENTATION_PLAN.md` / `02_TARGET_ARCHITECTURE.md` / `03_CURSOR_IMPLEMENTATION_REQUEST.md`  
> **제품 기능 코드는 이 단계에서 변경하지 않음.**

---

## 1. 저장소 확인 결과

| 항목 | 실제 값 |
| --- | --- |
| 루트 | `app/`, `server/`, `docs/`, `README.md` |
| Git | `main...origin/main` (로컬 변경 다수: KAT 전환, PRODUCT_ROADMAP, 01/02/03 문서 등) |
| Node | 런타임 v23.7.0 / `engines.node: >=22` |
| Flutter | 3.50.1 · Dart 3.14.0 · `sdk: ^3.14.0` |
| 서버 스크립트 | `dev`, `start`, `build`, `typecheck`, `test` (vitest) |
| 앱 검증 | `flutter analyze`, `flutter test` |

### Baseline 테스트 (Step 0에서 실행)

| 명령 | 결과 |
| --- | --- |
| `cd server && npm test` | **31 passed** (3 files) |
| `cd server && npm run typecheck` | **통과** |
| `cd app && flutter test` | **12 passed** |
| `cd app && flutter analyze` | **No issues** |

실 KAT 발신은 Step 0에서 **실행하지 않음**.

---

## 2. 실제 코드 트리 (핵심)

```text
server/src/
  index.ts, config.ts, container.ts, logger.ts
  domain/     types.ts, stateMachine.ts, phone.ts, domain.test.ts
  services/   callService.ts
  providers/  types.ts, simulatedProvider.ts, realtimeBridge.ts
              kat/katProvider.ts, kat/webhook.ts, kat/*.test.ts
  http/       app.ts, schemas.ts, app.test.ts
  store/      taskStore.ts          # InMemory + JsonFile (atomic tmp+rename)
  brain/      openaiBrain, heuristicBrain, prompts, scenario
  events/     eventBus.ts

app/lib/
  main.dart, app.dart
  core/       config, network (api_client, live_channel), router, theme, widgets
  features/calls/
    domain/call_models.dart
    data/calls_repository.dart
    application/calls_controller.dart
    presentation/  home, new_call, call_detail, call_templates.dart,
                   approval_listener.dart, widgets/approval_card.dart, ...
```

**문서(`02`) 대비:** `approvalPolicy.ts`, `notifications/`, `templates/` feature 패키지는 **아직 없음**. Twilio 경로는 **이미 제거**되고 KAT + 공용 `realtimeBridge.ts`로 교체됨.

---

## 3. 승인 관련 실제 시그니처·경로

| 구성요소 | 위치 | 현재 계약 |
| --- | --- | --- |
| `ApprovalRequest` | `server/src/domain/types.ts` | `id, question, status(pending\|approved\|rejected\|expired), requestedAt, resolvedAt?, expiresAt` — **`userComment` 없음**, status에 `canceled` 없음 |
| `ApprovalDecisionBody` | `server/src/http/schemas.ts` | `{ decision: "approve" \| "reject" }` only |
| HTTP | `POST /v1/tasks/:id/approvals/:approvalId` | `respondToApproval(id, approvalId, decision === "approve")` |
| `CallSession.requestApproval` | `providers/types.ts` | `(question: string) => Promise<boolean>` |
| `CallService.requestApproval` | `callService.ts` | pending Map + timeout → `resolve(boolean)` |
| `respondToApproval` | `callService.ts` | pending 아니면 **409 `approval_closed`** (메시지 문자열) |
| Realtime tool | `realtimeBridge.ts` | `approved` + 고정 `instruction` 문자열, **comment 없음** |
| Simulated | `simulatedProvider.ts` | `await session.requestApproval(...)` → boolean |
| Flutter `ApprovalRequest` | `call_models.dart` | `resolvedAt`/`userComment` **미파싱** |
| Flutter decide | `calls_repository.dart` | `{ decision: approve\|reject }` only |
| UI | `approval_card.dart` | 예/아니오 버튼만, 텍스트 입력 없음 |
| 결과 이력 | `call_detail_screen.dart` `_ApprovalHistory` | 상태 아이콘·질문 표시 |

### 타임아웃·재시작

- 승인 타임아웃 → `expired`, Promise `false` (거절과 동일하게 AI에 전달).
- 통화 abort 시 pending 승인 `expired`.
- `recoverInterruptedTasks`: 활성 통화 복구 시 pending → expired (서비스 상단 로직 확인됨).
- TaskStore: 메모리 + debounce 300ms flush, **tmp 파일 + rename** 원자 저장. CAS/락은 없음(단일 프로세스 가정).

### WebSocket

- `/v1/stream?token=` 지원 (브라우저 제약). 로그에서 `token=***` 마스킹.
- Flutter `calls_controller`: **높은 `version`만 채택** (문서 ADR과 일치).

---

## 4. 현재 기능 vs 문서 목표

| 기능 | 상태 | 비고 |
| --- | --- | --- |
| 시뮬레이터 E2E 승인 | ✅ | `app.test.ts` + Flutter `approval_flow_test` |
| KAT 실통화 + Realtime | ✅ (환경 의존) | OpenAI 크레딧/쿼터 필요; 최근 무음 이슈는 billing |
| 승인 코멘트 | ✅ | Step **A1** 완료 (2026-11-20) |
| 최근 상대/템플릿 영속 | 부분 | `call_templates.dart`는 퀵스타트 UI 수준, A2와 범위 다름 |
| 푸시 | ❌ | A3 |
| 연락처/STT | ❌ | A4 |
| 계정/Postgres/커넥터 | ❌ | B0+ |
| AgentTask | ❌ | C1 |

### 문서 불일치·가정 목록

1. `PRODUCT_ROADMAP(1).md` 파일명은 실제 `PRODUCT_ROADMAP.md`.
2. `02`의 Twilio 다이어그램 잔재는 없음 — 코드는 **KAT only** (`provider: simulated \| kat`).
3. `02` 제안 경로 `approvalDecisionService.ts` 등은 미존재 — A1은 **기존 CallService 확장**이 최소 변경.
4. Flutter `ApprovalRequest`가 서버 `resolvedAt`을 무시 — A1에서 함께 정리 권장.
5. 홈 퀵 템플릿(`call_templates.dart`) ≠ A2 “저장된 최근 상대/사용자 템플릿”.
6. 공용 `API_TOKEN` + 다중 사용자 푸시 혼용 금지(01 문서) — A3 전 위험으로 유지.

---

## 5. 위험 목록 (Step 0)

| 위험 | 심각도 | 비고 |
| --- | --- | --- |
| OpenAI billing/429 | 높음 | 실통화 음성·계획 품질 직결 |
| Pending 승인이 프로세스 메모리 Promise | 중 | 재시작 시 expire; 다중 인스턴스 불가 |
| TaskStore 동시성 | 중 | 단일 노드 OK, 수평 확장 전 DB 필요 |
| WS `?token=` 로그 노출 | 중 | 마스킹됨, 장기적으로 헤더/단기 토큰 |
| 승인 코멘트 → prompt injection | A1에서 대응 | 사용자 코멘트를 정책보다 우선 금지 |
| 실발신 비용/한국 IP | 운영 | 테스트는 시뮬레이터 기본 |

---

## 6. Step A1 정확한 변경 계획 (구현 전 설계)

**범위:** 승인/거절 + optional `comment`만. 푸시·템플릿·DB 금지.

### 6.1 서버

1. `ApprovalDecisionBody`: `comment: z.string().trim().max(500).optional()` — 빈 문자열은 `undefined`로 정규화.  
2. `ApprovalRequest`: `userComment?: string` 추가 (기존 JSON 로드 호환).  
3. `CallSession.requestApproval` → `Promise<ApprovalDecision>`  
   `{ approved: boolean; comment?: string; reason?: 'user_approved'|'user_rejected'|'expired'|'canceled' }`  
4. `respondToApproval(..., { approve, comment? })`  
   - pending만 전이; 아니면 기존처럼 409 `approval_closed`  
   - 승인 시 `userComment`/`resolvedAt` 저장 후 Promise resolve  
5. `resolveApproval`이 comment를 pending resolver에 전달할 수 있게 pending 맵 확장.  
6. `realtimeBridge` / `simulatedProvider`: tool output에 `user_comment` + 범위 제한 `instruction`.  
7. 테스트: approve±comment, reject±comment, 500 초과 400, expired/duplicate 409, 시뮬레이터 comment 전달.

### 6.2 앱

1. `ApprovalRequest`: `userComment?`, `resolvedAt?` fromJson 하위 호환.  
2. `decide(..., { approve, comment? })` repository/controller.  
3. `ApprovalCard`: 멀티라인 입력, 글자 수, 로딩, 만료 시 제출 비활성.  
4. `_ApprovalHistory`: 코멘트 표시.  
5. `approval_flow_test` 확장.

### 6.3 정책

- 코멘트는 **선택**. 없어도 기존과 동일.  
- 코멘트가 민감정보/추가 약정을 요구해도 서버·프롬프트 금지를 덮어쓰지 않음.  
- 만료 = 거절(`approved: false`, `reason: 'expired'`).

### 6.4 예상 수정 파일

```text
server/src/domain/types.ts
server/src/providers/types.ts
server/src/services/callService.ts
server/src/http/schemas.ts
server/src/http/app.ts
server/src/http/app.test.ts
server/src/providers/realtimeBridge.ts
server/src/providers/simulatedProvider.ts
(+ 필요 시 brain이 approvals 요약에 userComment 포함)

app/lib/features/calls/domain/call_models.dart
app/lib/features/calls/data/calls_repository.dart
app/lib/features/calls/application/calls_controller.dart
app/lib/features/calls/presentation/widgets/approval_card.dart
app/lib/features/calls/presentation/call_detail_screen.dart
app/test/approval_flow_test.dart
```

---

## 7. 다음 단계

문서 `03`에 따라 **제품 코드 변경 없이 Step 0 완료**.  
사용자 지시 후 **Step A1(승인 코멘트)** 만 구현한다. 다른 Phase 선구현 금지.

---

## 8. Step 0 완료 보고 (요약)

1. **범위:** 조사·테스트·본 baseline 문서만. 기능 코드 미변경.  
2. **레포:** KAT 전환 반영됨. 승인 경로는 boolean 중심.  
3. **테스트:** server 31 / flutter 12 / analyze·typecheck 통과.  
4. **실발신:** 없음.  
5. **다음 제안:** Step A1 착수 승인 대기.

---

## 9. Step A1 완료 (승인 코멘트) — 2026-11-20

### 구현 요약

| 영역 | 변경 |
| --- | --- |
| API | `POST .../approvals/:id` body에 optional `comment` 추가. trim, 빈 문자열→미입력, Unicode code point 기준 500자 초과→400 |
| Domain | `ApprovalDecision`, `ApprovalRequest.userComment?` |
| CallService | `requestApproval` → `Promise<ApprovalDecision>`; `respondToApproval({ approve, comment? })`; pending 아니면 409 `approval_closed` |
| Realtime | tool output: `approved`, `reason`, `user_comment`, 정책 우선 `instruction` |
| Simulated | comment 있으면 system transcript에 사용자 안내 기록 |
| Flutter | ApprovalCard 멀티라인+카운트+로딩; 이력에 코멘트; decide API 하위 호환 |

### Backward compatibility

- comment 없는 `{ decision }` body는 기존과 동일.
- 구 스냅샷에 `userComment` 없어도 fromJson/저장 로드 안전.
- WS `version` 병합 로직 변경 없음.

### 테스트

| 명령 | 결과 |
| --- | --- |
| `cd server && npm test` | **33 passed** |
| `cd app && flutter test` | **12 passed** |
| 실 KAT 발신 | **미실행** |

### 잔여 / 다음

- Flutter `resolvedAt` 파싱은 아직 미추가(표시 필수 아님).
- 클라이언트 `maxLength`는 UTF-16, 서버는 code point — 이모지 경계에서 미세 차이 가능.
- **다음 제안:** Step A2 (최근 상대/템플릿) 또는 A3(푸시) — 사용자 지시 대기.
