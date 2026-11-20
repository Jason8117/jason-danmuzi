# SPEC-LIFECYCLE-001 근거 자료

모든 줄 번호는 커밋 `f4d531e` 기준 작업 트리에서 직접 읽어 확인했다.

## 1. 종료 처리

`server/src/index.ts:30-36`

```
process.once(signal, async () => { await app.close(); await store.flush(); process.exit(0); });
```

`calls`(CallService)나 제공자를 전혀 호출하지 않는다. `server/src/index.ts:9`에서 `createContainer`가 `kat`을 돌려주지만 종료 시 쓰이지 않는다. `app.close()`에는 마감 시간이 없다.

`app.close()`가 WebSocket에 하는 일(manager-spec이 이 세션에서 직접 읽음): `server/node_modules/@fastify/websocket/index.js:243` `fastify.addHook('preClose', preClose)`, `:245-254` `defaultPreClose`가 `server.clients`의 모든 클라이언트에 `client.close()`를 부른다. 즉 KAT 미디어 소켓도 `app.close()` 때 닫힌다. 브리지는 `server/src/providers/realtimeBridge.ts:274` `media.on("close", () => closeAi("media_close"))`로 AI 소켓만 닫고 세션을 끝내거나 KAT 통화를 끊지 않는다. 그래서 통화 종료 요청은 `app.close()`보다 먼저 해야 한다(REQ-002). plan-audit iteration 1 보고서 §4 C6도 같은 내용을 확인했다.

## 2. 재기동 복구

`server/src/services/callService.ts:69-79`

- 종결 상태와 `awaiting_approval`을 제외한 모든 작업을 `failed`로 바꾸고 오류 문구 "서버가 재시작되어 작업이 중단되었습니다."를 넣는다.
- 대기 승인을 `expired`로 바꾼다.
- 제공자를 호출하지 않는다.

`server/src/index.ts:10` — 동기 호출 `calls.recoverInterruptedTasks();` 뒤 바로 `buildApp`, `listen`.

## 3. KAT 통화 ID 보관 위치

`server/src/providers/kat/katProvider.ts`

- `:24-30` `ActiveCall { session, streamToken, callId?, mediaBridged }`
- `:61-62` `private readonly calls = new Map<string, ActiveCall>(); private readonly byCallId = new Map<string, string>();`
- `:98-106` 통화 생성 응답에서 `callId`를 읽어 두 맵에만 넣는다. 작업(`CallTask`)에는 저장하지 않는다.
- `:74-81` 세션 중단 시 맵에서 지운다.
- `:119-123` `hangup`은 `this.calls.get(taskId)?.callId`가 있어야만 종료를 요청한다.

`server/src/domain/types.ts:73-89` `CallTask`에 외부 통화 ID 필드가 없다. 따라서 재기동 뒤에는 통화 ID를 알 방법이 없다.

## 4. KAT API 시간 제한 부재

`server/src/providers/kat/katProvider.ts:295-333` `api()`

- `:302-311` `fetch(url, { method, headers, body })` — `signal` 없음.
- 비교: `server/src/brain/openaiBrain.ts:80` `signal: AbortSignal.timeout(30_000)`.

영향 경로: `server/src/services/callService.ts:110-128` `approvePlan`

- `:115` `assertWithinLimits()` 통과 후 `:119` `dialing`으로 전이, `:121` 세션 열기.
- `:123` `await this.provider.start(session)` — KAT가 응답하지 않으면 여기서 멈춘다. HTTP 요청도 함께 멈춘다.
- `:185-195` 동시 통화 한도는 `isActiveCall`(`dialing` 포함) 작업 수로 계산하므로 멈춘 작업이 자리를 차지한다.
- `:197-202` 세션을 열 때 `maxCallDurationMs` 타이머가 시작되어, 그 시간이 지나야 `hangup` + `endSession`이 일어난다.
- `server/src/config.ts:30` `MAX_CALL_DURATION_SEC` 기본 600.

## 5. timeLimit 고정값

`server/src/providers/kat/katProvider.ts:94` `timeLimit: Math.max(10, Math.min(14_400, 15 * 60))` → 항상 900.
`server/src/container.ts:31-46` `KatCallProvider` 생성 시 통화 시간 설정을 넘기지 않는다. `:52-57`에서 `CallService`에는 `maxCallDurationMs`를 넘긴다.

## 6. 종료 마감 값의 근거와 한계

전체 종료 마감은 9 s다: 통화 종료 3 s + `app.close()` 1 s + 최종 저장 5 s(SPEC-STORE-001 REQ-011) = 9 s. 플랫폼이 SIGTERM 뒤 최소 10 s를 기다린다고 가정하고 1 s를 남겼다. 10 s는 흔한 기본값 중 가장 짧은 쪽(컨테이너 런타임의 `stop` 기본값)에 맞춘 가정이다. 더 긴 기본값을 쓰는 관리자(systemd, 쿠버네티스)에서는 여유가 더 커진다. 이 프로젝트의 실제 배포 환경은 문서에서 확인되지 않았으므로, 배포 환경이 정해지면 값을 다시 본다.

KAT 요청별 시간 제한(10 s)은 단계 1 예산(3 s)보다 길다. 종료 중에는 단계 예산이 먼저 끝내고, 끝나지 않은 종료 요청은 버린 채 작업을 `failed`로 기록한다.

## 7. 주인 없는 미디어 스트림

`server/src/providers/kat/katProvider.ts:207-293` `attachMediaStream`

- `:209-213` 서명 무효 → 소켓 닫기.
- `:243-245` 통화 ID 또는 메타데이터 `taskId`로 활성 세션을 찾는다.
- `:217` `setTimeout(() => socket.close(), 10_000)` — `start` 프레임이 오지 않으면 소켓만 닫는다. 통화는 끊지 않는다.
- `:255-256` 헤더 통화 ID가 있으면 `byCallId.get(callId) === taskId`일 때만 인증된다. 통화 생성 응답 처리 전에 스트림이 오면(`byCallId`가 비어 있음) 지금도 인증 실패로 처리된다.
- `:257-274` 인증 실패 시 소켓을 닫고, **활성 세션이 있을 때만** `terminateCall`을 호출한다. 시간 초과로 세션이 이미 정리된 뒤 KAT가 실제로 통화를 만들어 미디어 스트림이 들어오면, 소켓만 닫히고 전화는 끊기지 않는다.
- `:125-132` `terminateCall`은 실패를 warn 로그로 삼킨다. 시간 제한이 없어 끝나지 않을 수 있다.

## 8. 제공자 인터페이스

`server/src/providers/types.ts:12-35`

- `CallSession`: `taskId`, `task()`, `signal`, `markRinging`, `markConnected`, `appendTranscript`, `requestApproval`, `end`. 외부 통화 ID를 알리는 수단이 없다.
- `CallProvider`: `name`, `start(session)`, `hangup(taskId)`. 작업 맥락 없이 끊는 수단이 없다. `hangup`은 여러 번 호출해도 안전해야 한다는 계약이 주석에 있다(`:33`).

`server/src/providers/simulatedProvider.ts:43-45` `hangup`은 아무것도 하지 않는다(세션 중단 신호로 각본이 멈춤).

## 9. 앱 모델의 하위 호환

`app/lib/features/calls/domain/call_models.dart:182-207` `CallTask.fromJson`은 정해진 키만 읽는다. 모르는 키(`providerCallId`)는 무시된다. `:202` `isSimulated: json['provider'] == 'simulated'`.

`app/test/unit_test.dart:20-43` `CallTask.fromJson` 테스트 그룹, `app/test/support/fakes.dart:8-43` `taskJson()` 생성기. 새 테스트는 이 생성기에 키를 하나 더한 JSON으로 작성할 수 있다.

## 10. 기존 테스트 현황

- `server/src/providers/kat/katProvider.test.ts`는 `toKatPhoneNumber`와 서명 검증만 다룬다(import 목록: `toKatPhoneNumber`, `verifyKatHttpSignature`, `verifyKatStreamSignature`).
- `recoverInterruptedTasks`, 종료 처리, KAT `api()`를 다루는 테스트는 없다(`find src -name "*.test.ts"` 결과에서 확인).
- 이 환경에서는 실제 KAT·OpenAI 호출을 할 수 없다. 모든 검증은 주입 `fetch`와 가짜 제공자로 한다.
