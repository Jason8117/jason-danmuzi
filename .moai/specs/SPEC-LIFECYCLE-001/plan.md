# SPEC-LIFECYCLE-001 구현 계획

## A. 접근 방식

### 데이터 모델 (가장 먼저 확정할 결정)

- `server/src/domain/types.ts`의 `CallTask`에 선택 필드 `providerCallId?: string` 추가.
- 저장소는 필드를 그대로 직렬화한다. 기존 파일에는 필드가 없을 뿐이므로 마이그레이션이 필요 없다.
- 앱 `app/lib/features/calls/domain/call_models.dart`의 `CallTask.fromJson`은 모르는 키를 읽지 않으므로 코드 변경이 필요 없다. 이를 `app/test/unit_test.dart`의 테스트로 고정한다.

### 제공자 인터페이스 (`server/src/providers/types.ts`)

최소 변경 두 가지:

1. `CallSession`에 외부 통화 ID를 알리는 메서드 추가(예: `recordProviderCallId(id: string): void`). KAT 제공자는 통화 생성 응답에서 `callId`를 받은 직후 호출한다.
2. `CallProvider`에 "작업 맥락 없이 외부 통화 ID로 종료"하는 선택 메서드 추가(예: `terminateByProviderCallId?(id: string): Promise<void>`). 시뮬레이션 제공자는 구현하지 않는다.

이름은 RED 테스트를 쓰면서 확정한다. SPEC-ARCH-001이 같은 파일에 라우트 계약을 추가하므로, 이 SPEC에서는 위 두 항목만 넣는다.

### 종료 순서 (전체 9 s)

종료 처리를 테스트할 수 있도록 `index.ts`의 신호 처리 본문을 새 모듈 `server/src/shutdown.ts`로 옮긴다. 이 모듈은 `calls`, `app`(`close()`만 필요), `store`(SPEC-STORE-001의 최종 저장 메서드), 로거, `exit` 함수, 단계 예산을 주입받는다.

| 단계 | 동작 | 예산 | 근거 |
|------|------|------|------|
| 0 | `calls.beginShutdown()` — 종료 중 플래그. `create`/`approvePlan`은 503 `shutting_down`, 새 중간 승인은 `canceled` | 즉시 | 단계 1 도중 새 통화가 생기지 않게 |
| 1 | `calls.terminateActiveCalls({ deadlineMs: 3000 })` — 활성 통화마다 `provider.hangup(taskId)`를 병렬로 요청하고 마감과 경쟁. 끝나면(또는 마감) 각 작업 세션 정리 → 대기 승인 `expired` → `failed` + 종료 문구 → `persist`. 요약 없음 | 3 s | 반드시 `app.close()` 전에: `app.close()`의 `preClose`가 KAT 미디어 소켓을 닫기 때문(research.md §1). KAT 종료 API는 짧은 제어 요청 |
| 2 | `app.close()`를 1 s 마감과 경쟁 | 1 s | 진행 중 HTTP 요청을 오래 기다리지 않음 |
| 3 | `store.finalFlush()` (SPEC-STORE-001 REQ-011, 자체 마감 5 s) | 5 s | 저장 실패를 알리고 멈추지 않음 |
| 끝 | 최종 저장 성공 → `exit(0)`, 실패 → `Final store flush failed` error 1건 + `exit(1)` | — | SPEC-STORE-001 REQ-012 |

합계 9 s. 플랫폼 종료 유예를 최소 10 s로 가정(spec.md §4)하고 1 s를 남긴다. 단계 1의 KAT 요청별 시간 제한(10 s)보다 단계 예산(3 s)이 짧으므로, 종료 중에는 단계 예산이 먼저 끊는다. 그래도 단계 1의 작업 `failed` 기록은 반드시 일어난다.

`shutdown.ts`는 단계 1~3을 각각 자기 예산과 경쟁시킨다(`Promise.race`와 주입 타이머). 따라서 주입된 의존성이 마감을 지키지 않아도 전체가 9 s를 넘지 않는다(AC-005 (b)). 단계 3(최종 저장)이 5 s 예산 안에 끝나지 않으면(예: STORE의 자체 마감이 버그로 동작하지 않는 경우) 실패로 간주해 `Final store flush failed` 1건 + `exit(1)`(AC-005 (e)). `CallService.terminateActiveCalls`도 자체 마감을 받아 마감 시점에 작업을 `failed`로 기록한다(AC-003, AC-004).

두 번째 신호: 모듈이 신호 횟수를 세고, 두 번째에는 즉시 `exit(1)`.

SPEC-STORE-001이 `index.ts`에 둔 "최종 저장 결과 → 실패 문구 → 종료 코드" 처리는 이 모듈로 옮기되 메시지 상수와 종료 코드 규칙은 그대로 쓴다.

### 재기동 복구

- `recoverInterruptedTasks`를 비동기로 바꾸고 `index.ts`에서 `listen` 전에 기다린다. 종료 요청은 병렬로 보내고 전체 10 s로 제한한다.
- 대상 판정: `dialing`/`ringing`/`in_progress`만 종료 요청. `planning`/`summarizing`은 통화가 없거나 이미 끝났으므로 지금처럼 `failed`만. `awaiting_approval`은 그대로(현행).
- 제공자 불일치와 필드 부재를 각각 warn 로그로 남긴다.

### KAT 시간 제한

- `KatOptions`에 `fetch`(기본 전역 `fetch`)와 `requestTimeoutMs`(기본 10,000)를 추가한다. `api()`는 `AbortController` + `setTimeout(requestTimeoutMs)`로 요청마다 중단 신호를 만든다(`AbortSignal.timeout`은 가짜 타이머로 제어되지 않을 수 있어 쓰지 않는다).
- 시간 초과를 일반 오류와 구분해 한국어 문구("KAT Cloud가 응답하지 않아 전화를 걸지 못했습니다.")로 바꾼다. `approvePlan`의 `"전화 연결에 실패했습니다: …"` 접두어와 이어지게 쓴다.

| 항목 | 값 | 근거 |
|------|-----|------|
| KAT API 요청 시간 제한 | 10 s | 통화 생성·종료는 짧은 제어 요청. 계획 승인 버튼을 누른 뒤 기다릴 수 있는 수준 |
| 기동 시 복구 종료 마감 | 10 s | 기동 지연 상한 |
| `timeLimit` 여유 | 30 s | 서버 타이머(기본 600 s)가 먼저 동작하도록. 여유 30 s 전체가 유지되는 것은 `MAX_CALL_DURATION_SEC` ≤ 14,370일 때다. 14,371 이상이면 여유가 30 s보다 줄어들고, 14,401 이상이면 KAT 상한 14,400 s가 서버 타이머보다 먼저 끊는다(OD-3 잔여 위험, KAT 기준 시점 미확인) |

### timeLimit (OD-3 DEFAULT)

`KatOptions`에 `maxCallDurationSec`를 추가하고 `container.ts`에서 `config.MAX_CALL_DURATION_SEC`를 넘긴다. `timeLimit = clamp(maxCallDurationSec + 30, 10, 14_400)`. 기본 설정에서 900 → 630. 추가 고정 상한은 두지 않는다. 소유자가 상한을 택하면 이 식에 `min(…, 900)`을 넣고 AC-013 기대값만 고친다.

계산 예: 600 → 630, 5 → 35, 1 → 31, 20,000 → 14,400. `config.ts:30`이 1 이상의 정수만 허용하므로 설정으로는 하한 10에 닿지 않는다(최소 31). 하한은 생성자에 직접 주입한 값(예: `maxCallDurationSec: -25` → 10)에 대한 방어 코드로 두고 별도 단위 테스트로 검증한다(AC-013 (b)).

### `approvePlan` 검사 순서

503 `shutting_down`(이 SPEC) → 404 `not_found`(현행 `this.get(id)`) → 409 `invalid_state`(현행) → 400 번호 재검사(SPEC-POLICY-001) → 429 한도(현행). 이 SPEC은 맨 앞에 503을 넣고 404·409·429의 상대 순서는 그대로 둔다. 400 단계는 SPEC-POLICY-001이 409와 429 사이에 넣는다.

### 주인 없는 미디어 스트림

`attachMediaStream`의 순서를 바꾼다.

1. 업그레이드 서명 무효 → 소켓 닫기(현행). 종료 요청 없음.
2. 헤더 통화 ID가 있으면: 첫 `message` 이벤트에서 프레임을 해석하기 전에 `byCallId`로 활성 세션을 찾는다. 없으면 `terminateCall(headerCallId)` + 소켓 닫기. 10 s 시간 초과 처리기도 같은 판정을 한다.
3. 헤더 통화 ID가 없으면: 유효한 `start` 프레임의 통화 ID로 같은 판정(현행 경로에 종료 추가).

업그레이드 시점에 바로 판정하지 않고 첫 프레임 시점까지 미루는 이유: KAT가 통화 생성 응답보다 먼저 미디어 스트림을 열면 그 순간에는 `byCallId`가 아직 비어 있을 수 있다. 첫 프레임까지 미루면 생성 응답 처리 시간을 조금 더 번다. 이 경쟁에서 헤더 통화 ID가 아직 등록되지 않았다면 지금 코드도 인증 실패로 처리해 통화를 끊으므로(`katProvider.ts:255-273`) 새로 생기는 위험은 없다. SPEC-ARCH-001 REQ-011은 이 판정이 프레임 검증보다 먼저 일어난다는 예외를 따른다.

## B. 변경 파일

| 파일 | 변경 | 이유 |
|------|------|------|
| `server/src/domain/types.ts` | 수정 | `CallTask.providerCallId?` |
| `server/src/providers/types.ts` | 수정 | `CallSession` 통화 ID 보고, `CallProvider` 통화 ID 기반 종료(선택) |
| `server/src/services/callService.ts` | 수정 | 통화 ID 저장, 종료 중 플래그, 활성 통화 일괄 종료, 비동기 복구 |
| `server/src/providers/kat/katProvider.ts` | 수정 | 시간 제한, `fetch` 주입, `timeLimit`, 통화 ID 보고, 통화 ID 기반 종료, 주인 없는 스트림 평가 순서 |
| `server/src/providers/simulatedProvider.ts` | 확인 | 선택 메서드라 변경 불필요할 가능성이 높음. 타입 오류가 나면 최소 수정 |
| `server/src/container.ts` | 수정 | `maxCallDurationSec` 전달 |
| `server/src/shutdown.ts` | 신규 | 종료 단계·예산·두 번째 신호·종료 코드 |
| `server/src/index.ts` | 수정 | 신호 처리를 `shutdown.ts`에 위임, 복구 대기 |
| `server/src/shutdown.test.ts` | 신규 | 가짜 `calls`/`app`/`store`/`exit` + 가짜 타이머로 순서·예산 검증 |
| `server/src/services/callService.test.ts` | 신규 | 종료 중 플래그, 일괄 종료, 복구, 통화 ID 저장 |
| `server/src/providers/kat/katProvider.test.ts` | 수정 | 시간 제한, `timeLimit`, 통화 ID 보고, 주인 없는 스트림 |
| `app/test/unit_test.dart` | 수정 | `providerCallId` 유무와 상관없는 파싱 고정 |

합계 12개(신규 3, 수정 8, 확인 1).

## C. 마일스톤 (우선순위 순, 하나씩 순서대로)

결정이 바뀔 가능성이 큰 데이터 모델·인터페이스·종료 순서를 먼저 두고, 기계적인 연결 작업을 뒤에 둔다.

### M1 — 데이터 모델과 통화 ID 저장 (Priority High)

RED: AC-006(서비스·KAT), AC-009(앱 보호).

### M2 — 종료 순서와 예산 (Priority High)

RED: AC-001(종료 중 플래그), AC-002(`app.close()` 전 종료 요청, `app.close()`가 끝나지 않아도 진행), AC-003(단계 1 마감), AC-004(작업 최종 상태), AC-005(전체 순서, 9 s + 500 ms, 종료 코드, 두 번째 신호).

### M3 — KAT 시간 제한과 timeLimit (Priority High)

RED: AC-010(모든 요청에 중단 신호), AC-011(생성 시간 초과 → 빠른 실패, 한도 해제), AC-012(종료 요청 실패가 예외가 되지 않음), AC-013(`timeLimit`).

### M4 — 재기동 복구 (Priority High)

RED: AC-007(종료 요청 후 `failed`, 실패·시간 초과에도 `failed`, 10 s 제한), AC-008(필드 없음, 제공자 불일치).

### M5 — 주인 없는 미디어 스트림 (Priority Medium)

RED: AC-014 (a)~(d).

### M6 — 연결과 회귀 확인 (Priority Low)

`container.ts`, `index.ts` 연결, AC-015(프로세스 단위 절차), AC-016(전체 회귀).

## D. 위험 요소

| 위험 | 내용 | 대응 |
|------|------|------|
| 파일 겹침 | 아래 §D.1 행렬. 특히 `index.ts`(STORE, ARCH), `callService.ts`(POLICY, ARCH), `callService.test.ts`(POLICY·ARCH가 확장), `katProvider.ts`와 그 테스트(ARCH), `simulatedProvider.ts`(ARCH가 수정) | SPEC-STORE-001 완료 뒤 시작한다(`depends_on`). ARCH가 `katProvider.ts`의 `any`를 zod로 바꾸므로, 이 SPEC에서는 `api()`의 반환 타입을 건드리지 않는다. |
| 통화 중 배포 | 모든 SIGTERM이 진행 중 실통화를 즉시 끊는다(OD-1 RESOLVED, drain 없음). | 운영 안내를 sync-phase 문서에 넣는다(§G). |
| 단일 인스턴스 가정 | 같은 `DATA_FILE`의 두 인스턴스에서는 복구·주인 없는 스트림 처리가 정상 통화를 끊는다. | spec.md §4에 가정 명시, §G 운영 안내. |
| 시간 초과 뒤 실제 통화 생성 | 요청은 KAT에 도달했지만 응답만 늦은 경우 실통화가 생긴다. | REQ-016으로 미디어 스트림 시점에 끊는다. 상대가 받지 않으면 KAT `timeLimit`이 마지막 안전장치. |
| 통화 생성 중 종료 | `start`가 응답을 기다리는 중에 종료되면 통화 ID가 없어 끊을 수 없다. | 단계 1의 warn 로그에 "통화 ID 미확보"를 남긴다. 미디어 스트림이 열리면 서버는 이미 내려가는 중이라 REQ-016도 돕지 못할 수 있다. 잔여 위험. |
| 가짜 타이머와 `AbortSignal.timeout` | 가짜 타이머가 제어하지 못할 수 있다. | `AbortController` + `setTimeout`으로 구현. KAT 시간 제한 테스트는 실제 짧은 시간을 쓴다(AC-010 예외). |
| 손상·읽기 불가 데이터 파일 | 기동이 실패하므로 복구가 실행되지 않고 그 안의 실통화를 끊을 수 없다(SPEC-STORE-001 OD-1 RESOLVED). | 잔여 위험으로 기록. |
| `timeLimit` 변경 | 기본 900 → 630. 설정이 커지면 안전 상한도 커진다(OD-3 DEFAULT). | 소유자 검토 대상으로 표시. |

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

이 SPEC만 쓰는 파일: `server/src/shutdown.ts`, `server/src/shutdown.test.ts`.

## E. 하네스·복잡도 지표

| 지표 | 값 |
|------|-----|
| 도메인 수 | 2 (server 서비스·제공자·종료, app 모델 테스트) |
| 변경 파일 수 | 12 (신규 3, 수정 8, 확인 1) |
| REQ / AC | 16 / 16 (Tier M 상한 이내) |
| 외부 연동 | KAT Cloud(가짜 `fetch`로만 검증) |
| 위험 성격 | 실제 사람에게 걸리는 통화, 비용 |
| 권장 하네스 | thorough |

## F. 자체 검증 (run-phase 완료 조건)

- run 진입 시 HEAD를 `progress.md` §E.2 첫 줄에 `run_start_sha`로 기록.
- 마일스톤별 RED 출력(실패 원문)과 GREEN 출력을 `progress.md` §E.2에 기록.
- `npm test` 전체 통과(기준선 33개 + SPEC-STORE-001 추가분 + 이 SPEC 추가분), `npm run typecheck` exit 0.
- `flutter analyze` 결과가 기준선(info 1건, `test/support/fakes.dart:53`)보다 늘지 않음, `flutter test` 기준선 12개 + 새 테스트 통과.

## G. sync-phase 문서 항목

- **운영 안내**: 활성 통화가 없을 때만 배포·재시작한다. SIGTERM/SIGINT는 진행 중 실통화를 즉시 끊고 해당 작업을 `failed`로 기록한다(OD-1 RESOLVED, drain 없음).
- **운영 안내**: 한 `DATA_FILE`은 한 서버 프로세스만 쓴다. blue/green처럼 두 인스턴스가 같은 파일을 쓰면 새 인스턴스가 기존 통화를 끊는다.
- **운영 안내**: 플랫폼 종료 유예는 10 s 이상이어야 한다(서버 종료 마감 9 s).
- 기본 설정에서 KAT `timeLimit`이 900에서 630으로 바뀐다. 설정을 키우면 KAT 쪽 안전 상한도 함께 커진다(OD-3 DEFAULT). `MAX_CALL_DURATION_SEC`를 14,371 이상으로 두면 여유가 30 s보다 줄어들고, 14,401 이상으로 두면 KAT 상한 14,400 s가 서버 타이머보다 먼저 통화를 끊는다(KAT `timeLimit` 기준 시점은 미확인).
- 종료 중 응답 `503 shutting_down`.
