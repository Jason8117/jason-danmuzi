# SPEC-INTAKE-001 설계

`spec.md`의 요구사항을 만족하는 구조 결정을 정리한다. 함수 이름과 시그니처는 인터페이스를 고정하기 위한 의사 구조이며 run-phase RED 테스트를 쓰면서 확정한다. 시각 디자인(색·간격·모양·움직임)은 SPEC-UX-001 `design.md`가 정한다. 여기의 화면 구성은 기능 배치만 다룬다.

## 1. API 계약 (REQ-001, REQ-002, REQ-012, REQ-013)

### `POST /v1/intake`

요청:

```json
{ "text": "라 파스타에 전화해서 금요일 7시 2명 예약해줘. 안 되면 8시도 괜찮아", "language": "ko" }
```

응답 200 (LLM 사용, 기록에서 번호를 찾은 경우):

```json
{
  "draft": {
    "targetName": "라 파스타",
    "phoneNumber": "+8221234567",
    "goal": "금요일 저녁 7시에 2명 예약",
    "conditions": ["7시가 안 되면 8시도 괜찮음"],
    "context": null,
    "language": "ko"
  },
  "missing": [],
  "phoneSource": "history",
  "numberIssue": null,
  "source": "llm"
}
```

응답 200 (LLM 없음, 번호 없음, 기록 없음):

```json
{
  "draft": { "targetName": null, "phoneNumber": null, "goal": "금요일 7시 2명 예약", "conditions": [], "context": null, "language": "ko" },
  "missing": ["targetName", "phoneNumber"],
  "phoneSource": null,
  "numberIssue": null,
  "source": "heuristic"
}
```

오류: 400 `invalid_request`(본문 스키마), 401 `unauthorized`(토큰), 503 `shutting_down`(종료 중). 새 오류 코드는 없다.

처리 순서(서비스):

1. 종료 중이면 503(REQ-002). HTTP가 본문을 먼저 검증하므로 잘못된 본문은 400이 앞선다(`POST /v1/tasks`와 같음).
2. 번호 후보 찾기(§2) → 글에서 번호 결정 또는 `numberIssue`.
3. 후보를 `[전화번호]`로 가린 글로 `brain.draftIntake(maskedText, language)` 호출(§4).
4. 이름 보정: brain 이름이 `null`이면 기록 이름 포함 검사(§3.3).
5. 번호가 없고 `numberIssue`도 없고 이름이 있으면 기록에서 번호 찾기(§3.2).
6. `missing` 계산, 응답.

### `POST /v1/tasks`의 `autoStart`

`CreateTaskBody`에 `autoStart: z.boolean().optional()`. zod 객체는 모르는 키를 버리므로, 예전 서버는 새 앱이 보낸 `autoStart`를 조용히 무시한다(REQ-024의 호환 근거). 작업 타입에 `autoStart?: boolean`, `autoStartBlocked?: { code: string; message: string }` 추가.

## 2. 번호 후보 규칙 (REQ-004, REQ-005, REQ-007)

새 파일 `server/src/domain/intake.ts`(순수 함수). 의사 규칙:

- 후보 모양: `(\+82[ .-]?|\(?0)` + 숫자 1~3개 + `\)?[ .-]?` + 숫자 3~4개 + `[ .-]?` + 숫자 4개. 후보 바로 앞 글자는 숫자나 `+`가 아니고, 바로 뒤 글자는 숫자가 아니다.
- 판정에 넘기는 값: `0` + (세 숫자 묶음을 이은 것). `+82` 표기도 같은 값으로 바꿔 판정한다. 판정은 `checkTargetNumber`(`domain/phone.ts:57-67`) 하나로만 한다.
- 차단 단축 번호: 앞에 숫자·`+`가 없고, 뒤에 (공백을 건너뛰고) 글 끝 또는 `에`, `로`, `으로`, `번`, `한테`, `에게`, `전화` 중 하나가 오는 `112|119|113|114|117|118|122|125|182`(앞에 `0`이나 `+82`가 붙은 표기 포함). `112호실`처럼 다른 말이 붙은 숫자는 단축 번호로 보지 않는다.
- 가리기: LLM에 보내는 글에서 후보 부분(원문 그대로의 범위)을 `[전화번호]`로 바꾼다. 차단 단축 번호는 개인 정보가 아니므로 가리지 않는다.

테스트 벡터(`server/src/domain/intake.test.ts`, AC-004·AC-005):

| 글 | `phoneNumber` | `numberIssue` |
|----|---------------|---------------|
| `010-1234-5678로 전화해 줘` | `+821012345678` | null |
| `01012345678` | `+821012345678` | null |
| `라 파스타 02-123-4567` | `+8221234567` | null |
| `(02) 123-4567` | `+8221234567` | null |
| `031.123.4567` | `+82311234567` | null |
| `0507-1234-5678 예약` | `+8250712345678` | null |
| `+82 10 1234 5678` | `+821012345678` | null |
| `+82-2-123-4567` | `+8221234567` | null |
| `010 1234 5678 2명 예약` | `+821012345678` | null |
| `010-1234-5678 말고 02-123-4567` | `+821012345678` (글 순서상 첫 후보) | null |
| `2024. 12. 25 예약` | null | null |
| `1588-1234에 전화` | null | null |
| `+1 415 555 0100` | null | null |
| `119에 전화해 줘` | null | `"blocked"` |
| `0119로 연락` | null | `"blocked"` |
| `+82 112` | null | `"blocked"` |
| `서울병원 112호실 면회 시간` | null | null |
| `12345678901234` | null | null |

## 3. 이름과 통화 기록 (REQ-006, REQ-010, REQ-011, REQ-018)

### 3.1 정규화

`normalizeName(s) = s.toLowerCase()` 후 모든 공백(`\s`) 제거. 서버(`domain/intake.ts`)와 앱(`lib/features/calls/domain/counterparties.dart`)이 같은 규칙과 같은 벡터를 쓴다: `"라 파스타" → "라파스타"`, `" La Pasta " → "lapasta"`, `"미용실\tA" → "미용실a"`. 유니코드 정규화(NFC)는 하지 않는다(Dart 표준 라이브러리에 없음, 잔여 위험).

### 3.2 기록에서 번호 찾기

- 기록 범위: `TaskStore.list()` 중 `connectedAt`이 있는 작업(OD-2). `list()`는 이미 `createdAt` 내림차순이다(`store/taskStore.ts` `InMemoryTaskStore.list`).
- 이름이 같은(정규화 비교) 첫 작업의 `phoneNumber`를 `checkTargetNumber`로 다시 판정(데이터 파일에서 온 값이므로, `approvePlan`이 재검사하는 이유와 같음 — SPEC-POLICY-001 REQ-007). `ok`가 아니면 다음 작업으로 넘어가지 않고 번호 없음으로 둔다(차단된 옛 번호를 다른 옛 번호로 대신하지 않음).

### 3.3 기록 이름 포함 검사

brain 이름이 `null`이면, 기록 범위 작업의 정규화 이름(2자 이상) 중 정규화한 원문 글에 포함된 가장 긴 것. 같은 길이면 더 최근 작업. 표시 이름은 그 정규화 이름을 가진 가장 최근 작업의 `targetName`.

### 3.4 결정적 이름 규칙(heuristic)

번호 자리표시를 지운 글에 대해 `^\s*(.{1,40}?)\s*(?:에|에게|한테|께)\s*(?:전화|연락)`의 첫 묶음을 앞뒤 공백 제거해 쓴다.

벡터(기록 없음 기준, AC-010):

| 글 | 이름 | 목적 |
|----|------|------|
| `라 파스타에 전화해서 금요일 7시 2명 예약해줘` | `라 파스타` | 글 그대로 |
| `동네 세탁소에게 연락해 영업시간 물어봐` | `동네 세탁소` | 글 그대로 |
| `엄마한테 전화해 줘` | `엄마` | 글 그대로 |
| `금요일 7시 예약` | null | 글 그대로 |
| `010-1234-5678에 전화해서 예약` | null | `에 전화해서 예약` |
| `라 파스타에   전화해서\n7시` | `라 파스타` | `라 파스타에 전화해서 7시` |

기록 벡터(AC-006, AC-011). 기록: ① `라 파스타`, `+8221234567`, 연결됨, 2026-11-01 ② `라파스타`, `+8221110000`, 연결됨, 2026-11-10 ③ `미용실 A`, `+82311234567`, 연결 안 됨, 2026-11-15.

| 글(결정적 해석) | 이름 | 번호 | `phoneSource` |
|----|------|------|------|
| `라 파스타에 전화해서 7시 예약` | `라 파스타` | `+8221110000` (②, 최신) | history |
| `라파스타 금요일 7시 2명 예약해줘` | `라파스타` (포함 검사, 표시는 ②) | `+8221110000` | history |
| `미용실 A에 예약` | null | null | null (③은 연결 안 됨) |
| `라 파스타에 전화해서 02-999-9999로` | `라 파스타` | `+82299999999` | text (글의 번호가 우선) |
| `라 파스타에 전화해 119로` | `라 파스타` | null | null, `numberIssue: "blocked"` |

## 4. brain 의뢰 해석 (REQ-008, REQ-009)

- `CallBrain`에 `draftIntake(maskedText: string, language: Language): Promise<IntakeContent>` 추가. `IntakeContent = { targetName: string | null; goal: string; conditions: string[]; context: string | null; source: "llm" | "heuristic" }`.
- `HeuristicBrain.draftIntake`: §3.4 규칙. `source: "heuristic"`.
- `OpenAiBrain.draftIntake`: 기존 `completeJson`(`openaiBrain.ts:93-107`)을 `op: "intake"`로 사용. 실패 시 `this.fallback.draftIntake(...)`. `CallContext.op` 타입에 `"intake"` 추가.
- LLM 응답 스키마(의사): `targetName: string.max(80).nullish → null`, `goal: string.min(1).max(1000)`, `conditions: array(string.min(1).max(200)).max(5).nullish → []`, `context: string.max(1000).nullish → null`. 번호 필드 없음. 검증 실패는 `schema_mismatch` 대체(SPEC-OUTCOME-001과 같은 분류).
- 서비스 후처리: 모든 문자열에서 `[전화번호]` 제거 후 공백 정리, 이름 포함 검사(정규화한 원문 글이 정규화 이름을 포함해야 함). 빈 문자열 이름은 `null`.
- 프롬프트(`brain/prompts.ts`의 새 상수, 영어): 한 줄 부탁을 통화 초안으로 바꾼다. `targetName`은 글에 적힌 그대로, 없으면 null. `goal`은 통화로 이룰 일(시간·한도 등 포함, `conditions`에 넣은 항목은 빼고). `conditions`는 사용자가 밝힌 제약·대안(0~5개). `context`는 사용자가 상대에게 알려도 된다고 밝힌 정보만. 이름·번호·날짜를 지어내지 말 것. `[전화번호]`는 지워진 번호 표시이므로 옮기지 말 것. 요청 언어로 쓸 것.

## 5. 자동 시작 순서 (REQ-013 ~ REQ-016)

```
app: POST /v1/tasks {…, autoStart: true}
  └─ CallService.create → persist(task{planning, autoStart:true}) → void plan(id)
       plan(): brain.createPlan → (status 아직 planning?) → task.plan, transition awaiting_approval
         └─ if task.autoStart: await autoStartCall(id)
              try   approvePlan(id)            // 503 → 404 → 409 → 400 → 429, 같은 함수
              catch ServiceError e → task.autoStartBlocked = {code: e.code, message: e.message}; persist
              catch 그 밖의 오류   → task.autoStartBlocked = {code: "auto_start_failed", message: "자동으로 통화를 시작하지 못했어요."}; persist
approvePlan 성공 경로(수동·자동 공통): delete task.autoStartBlocked 후 dialing
```

- `autoStartCall`은 어떤 오류도 `plan()`의 `catch`로 넘기지 않는다. 넘기면 `plan()`이 `awaiting_approval` → `failed` 전이를 시도해 `InvalidTransitionError`가 난다(`stateMachine.ts:5`에 그 전이가 없음).
- 계획 중 취소: `plan()`은 상태가 `planning`이 아니면 바로 끝난다(`callService.ts:312-313`). 자동 시작 분기는 그 뒤에 있으므로 실행되지 않는다.
- 재기동: `recoverInterruptedTasks`는 `awaiting_approval` 작업을 건너뛴다(`callService.ts:99`). 자동 시작은 `plan()` 안에서만 일어나므로 기동 시 불러온 작업은 자동 시작되지 않는다.
- 종료 중: 계획이 종료 중에 끝나면 503 → `autoStartBlocked: shutting_down`. 최종 flush가 이 상태를 저장한다.
- `provider.start` 실패는 막힘이 아니다. 기존처럼 `session.end({error})`로 `failed`가 된다(`callService.ts:261-265`).

## 6. 앱 화면 구성 (기능 배치)

### 홈 (REQ-017, REQ-018)

```
┌ CallMate                         ● ⚙ ┐
│ [무엇을 도와드릴까요?           ] [➤] │  ← 입력칸 하나 + 보내기
│ 직접 입력하기 >                         │  ← /calls/new
│ 최근 통화한 곳                          │
│  [라파스타 · 02-111-0000 · 2번]        │  ← 누르면 "라파스타에 "
│ 이런 부탁도 할 수 있어요                │
│  (식당 예약) (영업시간 문의) …          │  ← 누르면 템플릿 문장
│ (작업이 없으면) 귀찮은 전화, 대신 …     │  ← 기존 안내 유지
│ 진행 중 / 지난 통화 목록 (기존)         │
└─────────────────────────────────────────┘
```

### 계획 카드 (REQ-019 ~ REQ-021)

```
┌ ← 이렇게 걸어 볼게요                     ┐
│ [번호만 알려 주시면 바로 걸게요.   ]   │  ← 번호 없을 때만, 자동 초점
│ 전화할 곳     라 파스타            ✎   │
│ 전화번호      02-111-0000  지난번 통화한 번호 ✎ │
│ 부탁할 일     금요일 저녁 7시에 2명 예약 ✎ │
│ 조건          (8시도 괜찮음 ×) (+ 추가) │
│ 알려줘도 되는 정보 (있을 때)        ✎   │
│ 통화 언어     한국어 ⇄                  │
│ 내 이름       김민수 (설정)             │
│ (heuristic) AI 없이 간단히 정리했어요…  │
│ 직접 자세히 입력 >                       │
│ [            이대로 시작            ]   │
└─────────────────────────────────────────┘
```

- 경로: `/plan`, `GoRouterState.extra`로 초안 객체(`PlanDraft`)를 받는다. `extra`가 없으면 홈으로 돌아간다.
- `PlanDraft`(새 파일 `lib/features/calls/domain/intake_models.dart`): 초안 필드 + `phoneSource` + `numberIssue` + `source`. `fromJson`은 모르는 값에 예외를 내지 않는다(`phoneSource`·`source` 모르는 값 → null/heuristic).
- 목적 합치기: `conditions`가 있으면 `"$goal\n조건: ${conditions.join(' / ')}"`.

### 상세 화면 안내 (REQ-023)

`awaiting_approval` 분기(`call_detail_screen.dart:170-180`) 맨 위에 `autoStartBlocked`가 있으면 안내 카드 한 장.

## 7. 대안과 기각 이유

| 대안 | 기각 이유 |
|------|-----------|
| 앱이 계획 완료를 기다렸다가 `approve-plan`을 보냄(OD-1의 반대) | 앱이 닫히거나 백그라운드로 가면 사용자가 이미 [이대로 시작]을 눌렀는데 작업이 `awaiting_approval`에 멈춘다. 서버 방식은 같은 함수(`approvePlan`)를 쓰므로 검사 순서가 한 곳에 남는다. |
| `GET /v1/counterparties` 엔드포인트로 제안 목록 제공 | 앱은 이미 모든 작업을 메모리에 들고 있다(`calls_controller.dart`). API 면적만 늘어난다. 대신 서버·앱이 같은 정규화 규칙과 테스트 벡터를 쓴다(§3.1). |
| LLM이 번호도 뽑음 | "번호를 지어내지 않는다"를 구조로 보장할 수 없고, 번호가 외부 LLM으로 나간다. 결정적 규칙이 더 단순하다. |
| 의뢰 해석과 통화 계획(`createPlan`)을 한 번의 LLM 호출로 | 계획(첫 인사·순서·질문)은 에이전트의 내부 각본이고, 사용자가 확인할 것은 상대·번호·목적·조건이다. 기존 계획 경로와 그 테스트를 그대로 둔다. |
| 홈을 채팅 스레드로 | 벤치마크 결론(채팅은 묻기엔 좋고 실행엔 계획 카드 + 승인 한 번이 낫다, `research.md` §5). 범위 밖(spec.md §6). |

## 8. 되돌리기 쉬운 정도

- `autoStart`(OD-1): 중간. 필드는 선택이라 지워도 예전 동작으로 돌아가지만, 앱 흐름(한 번 누름)이 이 필드에 기댄다. plan-auditor·소유자 검토에서 먼저 볼 결정이다.
- 번호 후보 규칙(OD-4): 쉬움. 순수 함수와 벡터 표만 바꾸면 된다.
- 기록 범위·우선순위(OD-2, OD-3): 쉬움. 한 함수.
- 홈 배치: 쉬움(SPEC-UX-001이 다시 다듬음).
