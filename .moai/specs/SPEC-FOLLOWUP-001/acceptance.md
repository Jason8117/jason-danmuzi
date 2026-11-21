# SPEC-FOLLOWUP-001 인수 기준

## 공통 검증 명령

저장소 루트(작업 트리)에서:

```bash
npm --prefix server test -- src/brain/openaiBrain.test.ts src/brain/heuristicBrain.test.ts
npm --prefix server test
npm --prefix server run typecheck
```

앱(작업 디렉터리 `app/`):

```bash
flutter --suppress-analytics pub get
flutter --suppress-analytics test test/follow_up_test.dart test/trust_notice_test.dart test/unit_test.dart
flutter --suppress-analytics test
flutter --suppress-analytics analyze
```

기준선: run-phase 시작 시 manager-develop이 위 전체 명령 결과를 `progress.md` §E.2 첫 부분에 기록한다(이 SPEC 작성 중에는 실행하지 않음). SPEC-INTAKE-001이 끝난 상태에서 시작한다(`depends_on`).

규칙: 테스트 먼저(RED) → 구현(GREEN). 실제 OpenAI 호출 없음. 공유·클립보드는 주입한 가짜 서비스로 호출만 기록한다(실제 공유 시트를 띄우지 않음). 시계는 주입해 고정한다. 문구 기대값은 OD-3·OD-4 DEFAULT.

공통 고정값: 작업 `id "task-1"`, `targetName "라 파스타"`, `endedAt "2026-11-21T10:05:00Z"`(+09:00 기준 오후 7:05), 생성 시각(DTSTAMP용) `2026-11-21T10:06:00Z`. 공유 문구 함수에는 표시 시간대 오프셋을 인자로 넘기며(기본 +09:00), 테스트 결과는 실행 기기의 시간대(`TZ`)와 무관하다.

## 서버

### AC-001 — 결과 타입 (REQ-001)

- **Given** (1) `appointment` 키가 없는 LLM 응답 `{"result":"success","summary":"7시 예약 완료","keyFacts":["7시"],"followUps":[]}`, (2) `InMemoryTaskStore`에 `appointment` 있는 결과와 없는 결과를 가진 작업 두 개
- **When** (1) `OpenAiBrain.summarize`를 부르고, (2) 두 작업을 저장한 뒤 `get`으로 읽으면
- **Then** (1) 결과가 `{ ...응답, source: "llm" }`과 깊은 비교로 같고 `appointment` 키가 없다(SPEC-OUTCOME-001 AC-006 무수정 통과). (2) 두 작업의 `outcome`이 저장 전과 같다. `npm --prefix server run typecheck` 종료 코드 0
- 테스트: `openaiBrain.test.ts` — "keeps outcomes without an appointment valid"
- RED: (2)는 `CallOutcome` 타입에 `appointment`가 없어 타입 검사가 실패한다.

### AC-002 — 일정 남기기·빼기 (REQ-002)

- **Given** 작업 `endedAt "2026-11-21T10:05:00Z"`, 가짜 `fetch`가 `{"result": R, "summary":"예약 완료", "keyFacts":[], "followUps":[], "appointment": A}`를 돌려줌
- **When** `OpenAiBrain.summarize`를 부르면
- **Then** 다음 표와 같고, 모든 경우 `source "llm"`, `result`는 R 그대로, warn 로그 0건

| R | A | 결과의 `appointment` |
|---|---|------|
| `success` | `{"title":"라 파스타 저녁 예약","startsAt":"2026-11-27T19:00:00+09:00"}` | 그대로 |
| `partial` | `{"title":"","startsAt":"2026-11-27T19:00:00+09:00","endsAt":"2026-11-27T21:00:00+09:00"}` | `title "라 파스타 일정"`, 나머지 그대로 |
| `success` | `{"title":"가"×100, "startsAt":"2026-11-27T19:00:00+09:00"}` | `title`은 "가" 80개 |
| `failed` | 첫 행과 같은 A | 없음 |
| `success` | `{"title":"x","startsAt":"2026-11-27T19:00:00"}` (시간대 없음) | 없음 |
| `success` | `{"title":"x","startsAt":"내일 7시"}` | 없음 |
| `success` | `{"title":"x","startsAt":"2026-11-19T19:00:00+09:00"}` (기준 −24h 밖) | 없음 |
| `success` | `{"title":"x","startsAt":"2027-12-01T19:00:00+09:00"}` (+366일 밖) | 없음 |
| `success` | `{"title":"x","startsAt":"2026-11-27T19:00:00+09:00","endsAt":"2026-11-27T18:00:00+09:00"}` | 없음 |
| `success` | `{"title":"x","startsAt":"2026-11-27T19:00:00+09:00","endsAt":"2026-11-29T19:00:00+09:00"}` (24h 초과) | 없음 |
| `success` | `"내일"` (객체 아님) | 없음 |
| `success` | `null` 또는 키 없음 | 없음 |

- 테스트: `server/src/brain/openaiBrain.test.ts` — "keeps only a confirmed, well-formed appointment" (`it.each`)
- RED: 현재 `OutcomeSchema`는 `appointment`를 버리고, 형식 검사가 없다.

### AC-003 — 요약 요청의 기준 시각 (REQ-003)

- **Given** 요청 본문을 기록하는 가짜 `fetch`, AC-002의 작업
- **When** `OpenAiBrain.summarize`를 부르면
- **Then** 보낸 `messages[1].content`를 JSON으로 해석한 값에 `referenceTime: "2026-11-21T10:05:00.000Z"`(또는 같은 순간의 ISO 문자열)와 `timezone: "Asia/Seoul"`이 있고, `messages[0].content`(요약 시스템 프롬프트)에 `appointment`와 `null`이 들어 있다. LLM 응답 `{"result":"unverified",…}`는 지금처럼 `schema_mismatch` 대체로 간다(SPEC-OUTCOME-001 AC-008 무수정 통과)
- 테스트: `openaiBrain.test.ts` — "sends the reference time and asks for confirmed appointments only"

### AC-004 — 휴리스틱 결과에는 일정이 없다 (REQ-004)

- **Given** (1) `HeuristicBrain`, (2) 500을 돌려주는 가짜 `fetch`의 `OpenAiBrain`
- **When** 상대 발화가 있는 작업을 요약하면
- **Then** 두 결과 모두 `appointment` 키가 없다(`"appointment" in outcome === false`)
- 테스트: `heuristicBrain.test.ts` — "never attaches an appointment"; `openaiBrain.test.ts` — "the fallback outcome has no appointment"
- 참고: (1)은 보호 테스트.

## 앱

### AC-005 — 모델 파싱 (REQ-005)

- **Given** `taskJson(status: 'completed', outcome: …)`의 `appointment`가 (1) `{"title":"라 파스타 저녁 예약","startsAt":"2026-11-27T19:00:00+09:00"}`, (2) 없음, (3) `{"title":"x","startsAt":"내일"}`, (4) `"문자열"`, (5) `{"startsAt":"2026-11-27T19:00:00+09:00"}`(title 없음)
- **When** `CallTask.fromJson`
- **Then** (1) `title`과 `startsAt`(같은 순간)이 있고 `endsAt` null, (2)(3)(4) `appointment` null, (5) `appointment`는 있고 `title`은 빈 문자열(`.ics` 제목은 REQ-011의 기본값 `라 파스타 일정`). 모든 경우 예외 없음
- 테스트: `app/test/unit_test.dart` — "parses appointments defensively"

### AC-006 — 후속 행동 줄 (REQ-006, REQ-010)

- **Given** 다음 작업으로 연 결과 화면

| # | 상태 | 결과 | 기대 버튼 |
|---|------|------|-----------|
| 1 | completed | `success`, `source llm`, appointment 있음 | 다시 걸기, 요약 복사, 공유, 캘린더 파일 보내기 |
| 2 | completed | `partial`, `source llm`, appointment 있음 | 네 개 모두 |
| 3 | completed | `success`, `source llm`, appointment 없음 | 캘린더 없음 |
| 4 | completed | `unverified`, `source heuristic`, appointment 있음(서버 규칙을 어긴 가정) | 캘린더 없음 |
| 5 | completed | `success`, source 없음(예전 결과), appointment 있음 | 캘린더 없음 |
| 6 | failed | `failed`, `source llm`, appointment 있음 | 캘린더 없음, 복사·공유 있음 |
| 7 | failed | 결과 없음 | 다시 걸기만 |
| 8 | canceled | 결과 없음 | 다시 걸기만 |

- **Then** 표의 버튼만 보인다(`find.text`로 네 라벨 각각 확인)
- 테스트: `app/test/follow_up_test.dart`(새 파일) — "shows follow-up actions that match the outcome" (`for` 8건)
- RED: 지금은 "다시 걸기"만 있다.

### AC-007 — 다시 걸기 → 계획 카드 (REQ-007)

- **Given** 결과 화면(#1), 의뢰 해석 호출을 기록하는 가짜 저장소, 안내 확인 기록 있음
- **When** "다시 걸기"를 누르고, 계획 카드에서 [이대로 시작]을 누르면
- **Then** 계획 카드("이렇게 걸어 볼게요")에 `라 파스타`, `02-123-4567`, "지난번과 같은 번호", 작업의 목적이 보이고, 가짜 저장소의 의뢰 해석 호출 수는 0이다. [이대로 시작] 뒤 기록된 생성 요청의 `targetName`·`phoneNumber`·`goal`·`language`가 원래 작업과 같고 `autoStart: true`다. 기존 양식 화면("통화 계획 만들기")은 열리지 않는다
- 테스트: `follow_up_test.dart` — "call again opens a filled plan card"
- RED: 지금은 양식 화면이 열린다(`call_detail_screen.dart:248`).

### AC-008 — 복사와 공유 (REQ-008)

- **Given** 결과 화면(#1), 호출을 기록하는 가짜 후속 행동 서비스
- **When / Then**
  1. "요약 복사" → 서비스의 `copied`가 [AC-009 (1)의 문구] 한 건, 스낵바 "요약을 복사했어요"
  2. "공유" → `sharedTexts`가 같은 문구 한 건
  3. 서비스의 공유가 예외를 던지도록 설정 → `copied`에 같은 문구, 스낵바 "공유할 수 없어 복사했어요"
- 테스트: `follow_up_test.dart` — "copies and shares the summary"

### AC-009 — 공유 문구 (REQ-009)

- **Given** 문구 생성 함수, 위 공통 고정값, 표시 시간대 인자 `+09:00`(Asia/Seoul)을 명시해 넘김
- **When / Then**
  1. 결과 `success`, 요약 `금요일 7시 2명 예약을 확정했어요.`, 알아낸 내용 `["7시 2명", "예약금 없음"]`, 해야 할 일 `["10분 전 도착"]` → 정확히

     ```
     [목표 달성] 라 파스타 통화 결과
     2026년 11월 21일 오후 7:05

     금요일 7시 2명 예약을 확정했어요.

     알아낸 내용
     • 7시 2명
     • 예약금 없음

     해야 할 일
     • 10분 전 도착
     ```
  2. 결과 `unverified`, 요약 `자동 요약(검증되지 않음): 라 파스타과(와) 통화했습니다.`, 목록 비어 있음 → 정확히

     ```
     [결과 미확인] 라 파스타 통화 결과
     2026년 11월 21일 오후 7:05

     자동 요약(검증되지 않음): 라 파스타과(와) 통화했습니다.
     ※ 자동 요약이라 목표를 이뤘는지 확인하지 못했어요.
     ```
  3. 작업 번호 `+8221234567`, 요청자 `김민수`, 대화 기록 `네, 라 파스타입니다.`, 승인 코멘트 `1만 원까지만`이 있어도 (1)의 결과 문자열에 `02-123-4567`, `+8221234567`, `김민수`, `네, 라 파스타입니다.`, `1만 원까지만`이 없다
  4. (1)과 같은 입력에 표시 시간대 인자 `+00:00`을 넘기면 둘째 줄이 `2026년 11월 21일 오전 10:05`다. 인자를 생략하면 (1)과 같다(기본 +09:00)
  5. 시간대 결정성: 같은 테스트 파일을 `TZ=UTC`와 `TZ=Asia/Seoul`로 각각 실행해도(`TZ=UTC flutter --suppress-analytics test test/follow_up_test.dart`) 둘 다 통과한다 — run-phase가 두 실행 결과를 기록한다
- 테스트: `follow_up_test.dart` — "builds the share text" (1~4)
- 참고: 라벨은 기존 `OutcomeResult.label`(`call_models.dart:51-58`)을 쓴다.

### AC-010 — 캘린더 노출 조건 (REQ-010)

- 단위: 노출 판정 함수가 AC-006 표 8건에 대해 #1·#2만 참
- 테스트: `follow_up_test.dart` — "offers a calendar draft only for confirmed LLM outcomes"
- 참고: 위젯 수준은 AC-006이 덮는다.

### AC-011 — `.ics` 형식 (REQ-011)

- **Given** #1 작업(appointment `title "라 파스타 저녁 예약"`, `startsAt 2026-11-27T19:00:00+09:00`, 요약 `금요일 7시 2명 예약을 확정했어요.`), 고정 시계
- **When** `.ics`를 만들면
- **Then**
  1. 줄 목록(CRLF로 나눔, 마지막 빈 문자열 제외)이 정확히 `BEGIN:VCALENDAR`, `VERSION:2.0`, `PRODID:-//CallMate//Follow-up//KO`, `METHOD:PUBLISH`, `BEGIN:VEVENT`, `UID:task-1-appointment@callmate.local`, `DTSTAMP:20261121T100600Z`, `DTSTART:20261127T100000Z`, `DTEND:20261127T110000Z`, `SUMMARY:라 파스타 저녁 예약`, `DESCRIPTION:…`(접힌 줄 포함), `END:VEVENT`, `END:VCALENDAR` 순서다
  2. 모든 줄 끝이 `\r\n`이고 `\n`만 있는 줄 끝이 없다
  3. 접은 뒤 각 물리 줄의 UTF-8 길이가 75바이트 이하이고, 이어지는 줄은 공백 하나로 시작하며, 접힘을 풀면(`\r\n ` 제거) `DESCRIPTION:금요일 7시 2명 예약을 확정했어요.\n\nAI 비서가 통화에서 확인한 내용으로 만든 초안이에요. 저장하기 전에 확인해 주세요.`(여기서 `\n`은 두 글자 `\` `n`)과 같다. 접힌 지점에서 UTF-8 바이트가 잘리지 않는다(각 물리 줄을 UTF-8로 디코드해도 오류 없음)
  4. 제목 `A;B,C\D`인 일정 → `SUMMARY:A\;B\,C\\D`
  5. `endsAt 2026-11-27T21:30:00+09:00`인 일정 → `DTEND:20261127T123000Z`
  6. 결과 문자열에 `ATTENDEE`, `ORGANIZER`, `+82`, `02-`가 없다
- 테스트: `follow_up_test.dart` — "builds an RFC 5545 calendar draft" (1~6)

### AC-012 — 캘린더 공유 (REQ-012)

- **Given** 결과 화면(#1), 가짜 후속 행동 서비스
- **When** (1) "캘린더 파일 보내기"를 누르고, (2) 파일 공유가 예외를 던지게 한 뒤 다시 누르면
- **Then** (1) `sharedFiles`가 한 건이고 이름 `appointment.ics`, 형식 `text/calendar`, 내용이 AC-011의 결과와 같다. (2) 스낵바 "캘린더 초안을 열 수 없어요"
- 테스트: `follow_up_test.dart` — "shares the calendar draft as a file"

### AC-013 — 신뢰 안내 문구와 그 근거 (REQ-013)

- **Given** 신뢰 안내 문구 상수
- **When** 단위 테스트에서 문구 목록을 읽고, 서버 근거를 명령으로 확인하면
- **Then** 목록이 REQ-013의 여섯 문장과 순서·글자까지 같고, (1)(2)(5)는 "정해져 있어요"로 끝난다(지시 수준 표현). 그리고 다음 명령이 모두 기대 결과를 낸다(근거가 사라지면 문구가 거짓이 되므로 sync-phase에서도 다시 실행한다). (1)(2)(5)의 근거는 지시문이 있다는 것까지이며 모델이 지시를 따르는지는 검증하지 않는다(OD-3 수용 위험)

| 항목 | 명령 | 기대 |
|------|------|------|
| (1) | `grep -c "Always say you are an AI assistant in your first sentence" server/src/brain/prompts.ts` | `1` |
| (2) | `grep -c "call the request_user_approval tool" server/src/brain/prompts.ts` | `1` 이상 |
| (3) | `grep -c 'app.delete("/v1/tasks/:id"' server/src/http/app.ts` | `1` |
| (4) | `grep -ci "audio" server/src/domain/types.ts` 그리고 `grep -rln "writeFile\|createWriteStream\|appendFile" server/src \| grep -v "\.test\.ts"` | `0`, 그리고 `server/src/store/taskStore.ts` 한 줄 |
| (5) | `grep -c "Never give card numbers, passwords" server/src/brain/prompts.ts` | `1` |
| (6) | `grep -c 'api.openai.com/v1/chat/completions' server/src/brain/openaiBrain.ts`, `grep -c 'goal: input.goal' server/src/brain/openaiBrain.ts`, `grep -c 'userComment: a.userComment' server/src/brain/openaiBrain.ts`, `grep -c 'transcript: task.transcript' server/src/brain/openaiBrain.ts` | 각각 `1` 이상(계획 입력 `openaiBrain.ts:62-69`, 요약 입력 `:74-90`; 의뢰 해석 입력은 SPEC-INTAKE-001 REQ-008) |
| (6) 내 이름·알려줘도 되는 정보·회신 번호 | `grep -c 'requesterName: input.requesterName' server/src/brain/openaiBrain.ts`, `grep -c 'shareableInfo: input.context' server/src/brain/openaiBrain.ts`, `grep -c 'Callback number: ' server/src/brain/prompts.ts`, `grep -c 'agentInstructions: () => buildAgentInstructions' server/src/services/callService.ts`, `grep -c 'session.agentInstructions()' server/src/providers/realtimeBridge.ts` | 각각 `1` 이상(계획 요청 `openaiBrain.ts:65,68`; 통화 지시문 `prompts.ts:17,27` → `callService.ts:377` → `realtimeBridge.ts:77,164`에서 Realtime `session.update`로 전송) |

- 테스트: `app/test/trust_notice_test.dart`(새 파일) — "trust statements are exactly the agreed six"; 명령 표는 run-phase 증거로 `progress.md`에 원문 기록

### AC-014 — 첫 통화 전 한 번 (REQ-014)

- **Given** 기기 저장값에 안내 확인 기록이 없는 앱, 계획 카드(SPEC-INTAKE-001 AC-021의 초안), 생성 요청을 기록하는 가짜 저장소
- **When / Then**
  1. [이대로 시작] → 안내(여섯 문장, [확인했어요])가 보이고 생성 요청 0건
  2. 바깥을 눌러 닫음 → 계획 카드에 남고 생성 요청 0건
  3. 다시 [이대로 시작] → 안내가 다시 보임 → [확인했어요] → 생성 요청 1건, 상세 화면으로 이동
  4. 앱을 다시 띄워(같은 기기 저장값) 새 계획 카드에서 [이대로 시작] → 안내 없이 생성 요청 1건
  5. `awaiting_approval` 상세 화면의 "이대로 전화 걸기"도 확인 기록이 없으면 같은 안내를 먼저 보이고, [확인했어요] 뒤에 계획 승인 요청을 보낸다
- 테스트: `trust_notice_test.dart` — "asks for the trust notice once before the first call" (1~5)
- RED: 안내가 없다.

### AC-015 — 설정과 통화 중 한 줄 (REQ-015)

- **Given** (1) 설정 화면, (2) `in_progress` 작업의 상세 화면, (3) `completed` 작업의 상세 화면
- **When** 렌더링하면
- **Then** (1) "AI 비서와 기록" 제목과 여섯 문장이 보인다. (2) "AI 비서는 AI임을 밝히도록 정해져 있어요 · 대화는 글로 기록돼요"가 보인다. (3) 그 한 줄이 없다. (4) 기존 양식 화면(`/calls/new`)의 안내 문단에 "정해져 있어요"가 들어 있고, 예전 보장형 문구 "AI임을 밝혀요.", "꼭 먼저 물어봐요", "절대 말하지 않아요"가 없다
- 테스트: `trust_notice_test.dart` — "shows trust statements in settings and during calls"

### AC-016 — 호환·회귀·의존성 (REQ-016)

- 서버 `npm --prefix server test` 전체 통과(기존 테스트 무수정), typecheck 0.
- 앱 `flutter test` 전체 통과, `flutter analyze`가 run-phase 기준선보다 늘지 않음.
- 의도된 변경: SPEC-INTAKE-001이 만든 `app/test/plan_card_test.dart`와 `app/test/intake_flow_test.dart`의 기기 저장값 준비(`SharedPreferences.setMockInitialValues({...})`)에 안내 확인 기록 키 한 항목을 더한다. `git diff <run_start_sha> -- app/test/plan_card_test.dart app/test/intake_flow_test.dart`가 그 준비 줄의 변경만 보여 준다.
- 의존성: `git diff <run_start_sha> -- app/pubspec.yaml`의 `dependencies:` 추가 줄이 `share_plus` 하나이고(직접 의존성 기준), `server/package.json`은 바뀌지 않는다. M2 첫 단계의 `flutter pub add share_plus` 출력(해결된 버전, `pubspec.lock`에 새로 생긴 전이 패키지 목록)을 `progress.md`에 원문으로 기록한다. 해결이 실패하거나 SDK 제약과 맞지 않으면 blocker로 보고한다.

## 엣지 케이스

- 시간대가 다른 사용자: 앱은 `.ics`를 UTC로 쓰므로 캘린더 앱이 기기 시간대로 보여 준다. 공유 문구의 시각은 항상 Asia/Seoul(+09:00)로 표시된다(REQ-009, 받는 사람이 한국 시각 기준으로 읽도록).
- `endedAt`이 없는 결과(예전 데이터): 공유 문구 둘째 줄은 `updatedAt`을 쓴다.
- 결과 화면에서 작업이 삭제되면 후속 행동 줄도 사라진다(기존 "통화를 찾을 수 없어요" 화면).

## 잔여 위험

- LLM이 대화를 잘못 이해해 틀린 일정을 낼 수 있다. 초안 문구(REQ-011)와 캘린더 앱에서의 저장 전 확인으로 막으며, 자동 검증하지 않는다.
- `share_plus`의 파일 공유 동작은 플랫폼마다 다르다(웹은 브라우저의 공유 기능에 따름). run-phase에서 패키지 문서로 확인한다.
- Android·iOS 기본 캘린더가 공유 시트로 `.ics`를 받는지는 확인되지 않은 가설이다. 그래서 기본 라벨은 하는 일을 그대로 말하는 "캘린더 파일 보내기"이며(OD-6), 아래 완료 정의의 기기 수동 확인에서 받는 것이 확인될 때만 "캘린더에 추가"로 올린다.
- 기기에서 처음 거는 통화는 계획 카드 확인([이대로 시작])과 신뢰 안내 확인(REQ-014)을 둘 다 거친다. 소유자 결정 3("한 번 확인 후 시작")과 첫 통화에 한해 한 번 더 누르는 차이이며, 소유자에게 알릴 항목으로 sync-phase 문서에 남긴다.
- 신뢰 안내 문구는 법률 검토 전 기본값이다(OD-3).
- 공유 문구의 요약·알아낸 내용에 상대가 말한 번호(예: 예약 번호)가 들어 있으면 그대로 나간다. 공유는 사용자가 직접 고르는 행동이다.

## 완료 정의 (Definition of Done)

- AC-001 ~ AC-016 충족, RED/GREEN 원문과 AC-013 명령 표 결과를 `progress.md` §E.2에 기록.
- OD-1 ~ OD-6 DEFAULT 구현과 소유자 검토 대기를 sync-phase 문서에 기록. 새 의존성 `share_plus`를 `.moai/project/tech.md`에 반영할 항목으로 남김.
- **기기 수동 확인(사람이 판정, 자동 AC 아님)**: Android 기기 1대와 iOS 기기 1대에서 결과 화면의 캘린더 행동을 눌러 (a) 공유 시트에 기본 캘린더 앱이 보이는지, (b) 고르면 일정 초안이 열리는지 확인해 결과(기기·OS 버전·예/아니오)를 `progress.md`에 적는다. 라벨은 기본값 "캘린더 파일 보내기"로 구현한다(OD-6). 두 기기 모두 "예"일 때만 OD-6의 올리는 변경("캘린더에 추가")을 소유자에게 제안한다. run-phase에서 기기를 쓸 수 없으면 이 항목을 "확인 못 함"으로 적고 기본 라벨을 그대로 둔다(자동 인수 기준에는 영향 없음).
