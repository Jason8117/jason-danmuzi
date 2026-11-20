# SPEC-ARCH-001 구현 계획

## A. 접근 방식

세부 설계는 `design.md`. 이 SPEC은 대부분 동작을 바꾸지 않는 구조 변경이므로, TDD를 다음처럼 적용한다.

1. **보호 테스트 먼저**: 옮기려는 경로의 현재 동작을 고정하는 테스트를 쓴다. 대상 코드가 아직 테스트할 수 없는 구조라면(예: 브리지가 `new WebSocket`을 직접 호출), 최소한의 주입 지점만 먼저 넣는다.
2. **새 동작은 RED**: 형식 오류 무시·로그, 라우트 계약 등록, 의존 규칙 검사처럼 지금 없는 동작은 실패하는 테스트로 시작한다.
3. **구조 변경 → 같은 테스트 통과**.

## B. 변경 파일

| 파일 | 변경 | 이유 |
|------|------|------|
| `server/src/providers/types.ts` | 수정 | 라우트 계약, `CallSession.agentInstructions`, `ProviderId` 사용 |
| `server/src/http/app.ts` | 수정 | 구체 제공자 제거, 선언된 라우트 등록, 원문 본문 캡처 범위, `realCalls` |
| `server/src/providers/kat/katProvider.ts` | 수정 | 라우트 선언, zod 해석, 브리지 주입 지점 |
| `server/src/providers/kat/schemas.ts` | 신규 | KAT 응답·웹훅·미디어 프레임 스키마 |
| `server/src/providers/realtimeBridge.ts` | 수정 | 지시문 주입, zod 해석, WebSocket 생성 주입 |
| `server/src/providers/realtimeEvents.ts` | 신규 | Realtime 이벤트·도구 인자 스키마 |
| `server/src/providers/simulatedProvider.ts` | 수정 | 시나리오 import 경로 |
| `server/src/brain/scenario.ts` → `server/src/domain/scenario.ts` | 이동 | 제공자 → brain 의존 제거 |
| `server/src/brain/heuristicBrain.ts` | 수정 | 시나리오 import 경로 |
| `server/src/services/callService.ts` | 수정 | 세션에 지시문 제공 |
| `server/src/domain/types.ts` | 수정 | `ProviderId` |
| `server/src/container.ts` | 수정 | 라우트·제공자 정보 전달 |
| `server/src/index.ts` | 수정 | `buildApp` 인자 변경 |
| `server/src/http/app.test.ts` | 수정 | `/v1/stream`, 제공자 라우트 등록 테스트 추가(기존 테스트 불변) |
| `server/src/providers/realtimeBridge.test.ts` | 신규 | 브리지 테스트 |
| `server/src/providers/kat/katProvider.test.ts` | 수정 | 웹훅·미디어 스트림·API 응답 해석 테스트 |
| `server/src/brain/openaiBrain.test.ts` | 수정 | 계획 경로 테스트(SPEC-OUTCOME-001이 생성) |
| `server/src/services/callService.test.ts` | 수정 | 세션 지시문 테스트(AC-007), 제공자 식별자 보호 테스트(AC-013). SPEC-LIFECYCLE-001이 생성, SPEC-POLICY-001이 확장한 파일 |
| `server/src/architecture.test.ts` | 신규 | import 규칙 검사(REQ-001, REQ-007, REQ-013) |
| `app/test/unit_test.dart` | 수정 | 모르는 제공자 값 파싱 |

합계: 신규 4(`kat/schemas.ts`, `realtimeEvents.ts`, `realtimeBridge.test.ts`, `architecture.test.ts`), 수정 15, 이동 1(`scenario.ts`) → 20개 파일. Tier L 기준(15개 초과)에 해당한다.

## C. 마일스톤 (우선순위 순, 하나씩 순서대로)

결정이 바뀔 가능성이 큰 것(라우트 계약, 세션 인터페이스)을 앞에, 기계적인 것(파일 이동, 타입 별칭)을 뒤에 둔다.

### M1 — 제공자 라우트 계약 (Priority High)

설계상 가장 되돌리기 어려운 결정이다(`design.md` §1).

보호 테스트(현재 동작 고정, `app.test.ts`에 KAT 모드 구성 추가):
- KAT 모드에서 서명 무효 `POST /kat/status` → 401 `invalid_signature`, 유효 서명 → 204(가짜 제공자 또는 테스트용 `KatCallProvider` + 비밀키).
- 시뮬레이션 모드에서 `POST /kat/status` → 404.

RED:
- 라우트를 선언한 가짜 제공자(예: `POST /fake/hook`, `rawBody: true`)로 `buildApp` → 라우트가 등록되고 핸들러가 원문 본문을 정확히 받는다. 현재 `AppDeps`에 그런 입력이 없어 실패.
- `architecture.test.ts`: `app.ts` 원문에 `providers/kat`, `KatCallProvider`, `"/kat/"`, `=== "kat"` 문자열 0건. 현재 실패.

### M2 — 세션 지시문 주입 (Priority High)

RED:
- `callService.test.ts`(또는 브리지 테스트): 세션의 지시문이 `buildAgentInstructions(task)`와 같다.
- `architecture.test.ts`: `providers/` 아래 파일에 `../brain/` 또는 `../../brain/` import 0건. 현재 `realtimeBridge.ts:2`, `simulatedProvider.ts:2` 때문에 실패.

### M3 — 브리지 주입 지점과 브리지 테스트 (Priority High)

1. WebSocket 생성 주입 지점만 추가(동작 불변).
2. 보호 테스트(`realtimeBridge.test.ts`, AC-015 (a)~(i)): 세션 설정 메시지(지시문, 음성 형식, 도구), 양방향 음성 전달, 발화 시작 시 `clear`, 전사 → 대화 기록, 승인 도구 왕복(`function_call_output` + `response.create`), `end_call` → 2.5 s 유예 뒤 `hangup`(가짜 타이머), 과금 오류 → 실패 + `hangup`, 첫 연결 거절 → 재연결 1회 → 두 번째 거절 → `failAndHangup`(WebSocket 생성 총 2회 — `REALTIME_CONNECT_RETRIES = 2`, 첫 시도가 `connectAttempt` 1), `stop` 프레임 → AI 소켓 닫기.
3. RED: 형식 오류 처리 대상 이벤트(예: `response.output_audio.delta`에 `delta` 없음) → 무시 + warn 1건. 현재는 `payload: undefined`인 미디어 프레임을 보낸다.
4. zod 적용 → 모두 통과.

### M4 — KAT 입력 검증과 테스트 (Priority High)

보호 테스트(`katProvider.test.ts`, 가짜 세션):
- `handleStatusWebhook`: `media_stream.call.ringing` → `markRinging`, `answered` → `markConnected`, 음성 미연결 상태의 `completed` → 미디어 실패 문구로 종료, 연결 뒤 `completed` → 정상 종료, `busy`/`no-answer`/`rejected`/`canceled`/`failed` → 각 문구, 모르는 작업 → 무시.
- `attachMediaStream`: 서명 무효 → 닫기, 정상 `start` → `markConnected` + 브리지 호출(주입으로 가로챔), 토큰 불일치 → 닫기 + 세션 종료 + 종료 요청, `start` 없음 → 10 s 뒤 닫기.
- API 응답: `{ callId }`, `{ result: { callId } }` 모두 처리, `callId` 없음 → 기존 오류 문구.

RED:
- 형식 오류 웹훅(`{ data: { type: 123 } }`, `{ data: "x" }`) → 무시 + warn 1건. 현재는 `type` 비교에서 그냥 지나가고 로그가 없다.
- 형식 오류 `start` 프레임(`start.customParameters`가 숫자) → 무시 + warn + 계속 대기. 단, SPEC-LIFECYCLE-001이 넣은 주인 없는 스트림 판정(헤더 통화 ID에 활성 세션 없음 → 종료)은 zod 해석보다 앞에 그대로 둔다(REQ-011 예외). LIFECYCLE의 AC-014 테스트를 보호 테스트로 먼저 다시 돌린다.
- `architecture.test.ts`: `katProvider.ts`, `realtimeBridge.ts`에 `any` 0건. 현재 4건, 2건.

### M5 — 시나리오 이동과 제공자 식별자 타입 (Priority Medium)

기계적 변경.
- `scenario.ts` 이동, import 경로 수정(M2의 의존 규칙 테스트가 통과로 바뀜).
- `ProviderId` 도입. RED는 AC-013의 grep이다: `grep -n 'provider: "simulated" | "kat"\|name: "simulated" | "kat"' src/domain/types.ts src/providers/types.ts`가 현재 2줄을 출력하고, GREEN에서 출력이 없어야 한다. `callService.test.ts`의 `"fake"` 제공자 테스트는 vitest가 타입을 지우고 `tsconfig.json`이 테스트 파일을 제외하므로 현재 코드에서도 통과한다. 실행 동작을 고정하는 보호 테스트일 뿐 RED 근거가 아니다.
- 앱: `provider: "telco_x"` JSON 파싱 → 예외 없음, `isSimulated == false`.

### M6 — 남은 테스트 공백과 연결 (Priority Medium)

- `/v1/stream`(`app.injectWS`): `snapshot`, 작업 생성 뒤 `task.updated`, 헤더 토큰, 쿼리 토큰, 토큰 없음 401.
- `openaiBrain.test.ts` 계획 경로: 정상 응답 통과, `steps` 9개·`approvalPoints` 6개 → 대체.
- `container.ts`, `index.ts` 연결, 전체 회귀.

## D. 위험 요소

| 위험 | 내용 | 대응 |
|------|------|------|
| 파일 겹침 | 아래 §D.1 행렬. 이 SPEC이 고치는 파일 가운데 최대 14개(`katProvider.ts`와 그 테스트를 따로 세고, LIFECYCLE이 `simulatedProvider.ts`를 실제로 고친 경우 포함)를 앞선 SPEC이 먼저 바꾼다. | 마지막에 구현한다(`depends_on`이 네 SPEC 모두). 시작 전에 각 파일의 최신 상태를 다시 읽고, 앞선 SPEC이 넣은 동작(종료 순서, 시간 제한, `fetch` 주입, 통화 ID 보고, 주인 없는 스트림 판정, 서비스 정책, 결과 출처·로그 형식)을 보호 테스트로 먼저 고정한다. |
| 동작 회귀 | 구조 변경 중 웹훅 서명 검증이나 원문 본문 캡처가 깨질 수 있다. | M1 보호 테스트로 401/204를 먼저 고정한다. 원문 본문은 바이트 단위 비교 테스트. |
| 테스트 파일 타입 미검사 | `tsconfig.json`이 `src/**/*.test.ts`를 제외해 테스트의 타입 오류가 드러나지 않는다(`ProviderId` 검증이 약해짐). | 타입 수준 검증은 프로덕션 코드 쪽에서 `npm run typecheck`로 한다(예: 시뮬레이션·KAT 제공자 이름 상수가 `ProviderId`에 대입 가능). 테스트 파일 타입 검사 추가는 이 SPEC 범위 밖(별도 작업으로 권고). |
| 스키마가 너무 엄격 | 실제 KAT·OpenAI가 보내는 필드 변형을 거부해 정상 통화가 끊길 수 있다. | 알려진 필드만 검사하고 나머지는 통과(`design.md` §4). 현재 코드가 허용하는 모든 위치·형태를 보호 테스트로 고정. 실제 서비스 응답으로는 검증할 수 없음 — 잔여 위험. |
| 원문 본문 캡처 범위 | 선언 경로 집합 매칭이 쿼리 문자열이 붙은 URL에서 빗나갈 수 있다. | 경로 비교는 쿼리 문자열을 뗀 값으로 한다. 테스트 추가. |
| `injectWS` 사용법 | 버전별 API 차이. | 11.3.7 타입 정의 확인 결과 `injectWS` 존재. 막히면 실제 포트로 `listen` 후 `ws` 클라이언트로 대체. |

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

이 SPEC만 쓰는 파일: `kat/schemas.ts`, `realtimeEvents.ts`, `realtimeBridge.ts`, `realtimeBridge.test.ts`, `architecture.test.ts`, `domain/scenario.ts`(이동).

## E. 하네스·복잡도 지표

| 지표 | 값 |
|------|-----|
| 도메인 수 | 4 (HTTP, 제공자, 서비스·도메인, 앱 모델 테스트) |
| 변경 파일 수 | 20 (신규 4, 수정 15, 이동 1) |
| REQ / AC | 22 / 20 (Tier L 상한 25 이내) |
| Tier | L (파일 수 기준) |
| 외부 연동 | KAT, OpenAI Realtime(모두 가짜로만 검증) |
| 동작 변경 | 없음(형식 오류 입력 무시·로그 추가만) |
| 권장 하네스 | thorough |
| 권장 실행 방식 | 순차(serial). 파일 간 의존이 많아 병렬 분할 이득이 작다. |

## F. 자체 검증

- 마일스톤별 보호 테스트 통과 원문, 새 동작의 RED/GREEN 원문을 `progress.md` §E.2에 기록.
- `architecture.test.ts`의 import·`any` 검사 통과.
- 서버 전체 테스트·타입 검사, 앱 `flutter analyze`·`flutter test` 통과.
