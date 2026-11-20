# 콜비 — 기술 스택과 개발 환경

콜비(구 CallMate)의 현재 기술 스택이다. 콜비라는 이름은 이 `.moai/project/` 문서에서만 쓴다. `README.md`, `docs/`, 패키지·식별자 이름(`callmate-server`, `CALLMATE_SERVER_URL` 등)은 여전히 CallMate / `callmate`이며, 이를 바꾸는 일은 아직 하지 않은 별도 작업이다.

## 기술 스택

### 서버 (`server/package.json`)

| 패키지 | 버전 | 용도 |
|---|---|---|
| Node.js | >=22 | 런타임 (TypeScript ESM) |
| fastify | ^5.12.8 | HTTP 서버 |
| @fastify/cors | ^11.4.3 | 브라우저(Flutter web) CORS |
| @fastify/formbody | ^9.0.2 | 폼 본문 파싱(KAT 웹훅) |
| @fastify/websocket | ^11.3.7 | `/v1/stream`, `/kat/media` |
| ws | ^8.23.0 | WebSocket 클라이언트(OpenAI Realtime) |
| zod | ^4.6.7 | 환경 변수·요청 검증 |
| typescript (dev) | ^7.0.2 | 타입 검사·빌드 |
| tsx (dev) | ^4.23.15 | 개발 모드 실행 |
| vitest (dev) | ^5.1.1 | 테스트 |
| @types/node (dev) | ^26.6.6 | Node.js 타입 정의 |
| @types/ws (dev) | ^8.18.2 | ws 타입 정의 |

### 앱 (`app/pubspec.yaml`, 버전 0.1.0+1)

| 패키지 | 버전 | 용도 |
|---|---|---|
| Dart SDK | ^3.14.0 | 언어 |
| flutter_riverpod | ^3.5.0 | 상태 관리 |
| go_router | ^18.1.4 | 라우팅 |
| http | ^1.6.0 | REST 통신 |
| web_socket_channel | ^3.0.3 | 실시간 스트림 |
| shared_preferences | ^2.5.6 | 서버 주소·토큰 저장 |
| intl | ^0.20.3 | 날짜·숫자 형식 |
| material_ui | ^1.1.0 | UI 컴포넌트 (`material`이 아님) |
| flutter_lints (dev) | ^6.0.0 | 린트 |

## 개발 환경 요구 사항

- Node.js 22 이상
- Dart ^3.14.0을 지원하는 Flutter SDK

## 명령어

아래 명령은 저장소에 정의된 것들이며, 이 문서를 작성하면서 실제로 실행하지는 않았다. 저장소 루트에 Makefile은 없다.

서버(`server/`):

| 명령 | 내용 |
|---|---|
| `npm run dev` | `tsx watch --env-file-if-exists=.env src/index.ts` |
| `npm run start` | `node --env-file-if-exists=.env dist/index.js` |
| `npm run build` | `tsc -p tsconfig.json` |
| `npm run typecheck` | `tsc -p tsconfig.json --noEmit` |
| `npm test` | `vitest run` |

앱(`app/`): `flutter analyze`, `flutter test`, `flutter run` (Flutter 표준 명령).

## 환경 변수 (`server/src/config.ts`)

| 이름 | 기본값 | 설명 |
|---|---|---|
| `PORT` | 8787 | 포트 |
| `HOST` | 127.0.0.1 | 바인드 주소 |
| `API_TOKEN` | 없음 | `/v1/*` Bearer 토큰. 실제 통화 모드에서는 필수 |
| `CORS_ORIGINS` | 없음 | 허용 오리진(쉼표 구분, Flutter web용) |
| `DATA_FILE` | `data/tasks.json` | 작업 저장 파일 |
| `CALL_PROVIDER` | `auto` | `auto` / `simulated` / `kat` |
| `PUBLIC_BASE_URL` | 없음 | KAT 웹훅·미디어용 공개 HTTPS 주소 |
| `OPENAI_API_KEY` | 없음 | 있으면 `OpenAiBrain` 사용, KAT 모드 필수 |
| `OPENAI_MODEL` | `gpt-4.1-mini` | 계획·요약 모델 |
| `OPENAI_REALTIME_MODEL` | `gpt-realtime` | 실시간 음성 모델 |
| `OPENAI_REALTIME_VOICE` | `marin` | 음성 |
| `KAT_API_KEY`, `KAT_GROUP_ID`, `KAT_FROM_NUMBER`, `KAT_WEBHOOK_SECRET` | 없음 | KAT Cloud 자격 정보 |
| `KAT_API_BASE_URL` | `https://studio-gateway.zerocall.kr` | KAT API 주소 |
| `MAX_CONCURRENT_CALLS` | 2 | 동시 통화 상한 |
| `MAX_CALLS_PER_DAY` | 30 | 일일 통화 상한 |
| `APPROVAL_TIMEOUT_SEC` | 90 | 통화 중 승인 응답 제한 시간 |
| `MAX_CALL_DURATION_SEC` | 600 | 통화당 최대 길이 |
| `SIMULATION_SPEED` | 1 | 시뮬레이션 진행 속도 배율 |

앱 빌드 정의: `CALLMATE_SERVER_URL`, `CALLMATE_API_TOKEN` (`--dart-define`, `app/lib/core/config/app_settings.dart`). `app_settings.dart`는 `prefs.getString(...) ?? <기본값>` 형태로 읽으므로 설정 화면에 저장한 값이 우선한다. 저장값이 없으면 `apiToken`은 `String.fromEnvironment('CALLMATE_API_TOKEN')`을, `serverUrl`은 `AppSettings.defaultServerUrl`을 쓴다.

## 외부 시스템

- **OpenAI**: 통화 계획·요약(Chat Completions, `OpenAiBrain`), 실시간 음성 대화(Realtime WebSocket, `providers/realtimeBridge.ts`).
- **KAT Cloud**: 070 번호 발신, 상태 웹훅(`/kat/status`), 미디어 스트림(`/kat/media`), 웹훅 서명 검증(`providers/kat/webhook.ts`). 한국 IP에서만 접근 가능하다. 이전의 Twilio 연동은 커밋 a7b5244에서 KAT Cloud로 교체되었다.

## 테스트와 CI 현황

테스트 파일(실행 결과는 확인하지 않았다):

- 서버: `src/domain/domain.test.ts`(상태 전이, 번호 처리, `heuristicBrain`에서 가져온 `isFiller`), `src/http/app.test.ts`(`buildApp`에 `CallService`, `SimulatedCallProvider`, `HeuristicBrain`, `InMemoryTaskStore`, `EventBus`를 조립한 통합 테스트), `src/providers/kat/katProvider.test.ts`(번호 변환, 웹훅 서명 검증)
- 앱: `test/approval_flow_test.dart`, `test/calls_controller_test.dart`, `test/unit_test.dart`, `test/support/fakes.dart`

직접 테스트가 없는 영역: `realtimeBridge.ts`, `openaiBrain.ts`, `KatCallProvider`의 통화 흐름, JSON 파일 저장소. 커버리지 수치는 미확인.

CI: `.github/workflows/label-sync.yml`만 있으며 빌드·테스트를 실행하는 CI는 없다.

## 코드로 확인된 제약

- 긴급·특수번호 112, 119, 113, 114, 117, 118, 122, 125, 182 발신 차단(`domain/phone.ts`)
- 승인 코멘트 최대 500자, 작업 `context` 최대 1000자, `callbackNumber` 최대 32자(`http/schemas.ts`)
- KAT 제공자 사용 시 `API_TOKEN` 필수, `CALL_PROVIDER=kat`이면 KAT·OpenAI 변수 6개 모두 필수(`config.ts`)
- 저장소는 단일 JSON 파일이며 데이터베이스가 없다
- 푸시 알림이 없어 앱이 연결된 동안에만 승인 요청을 받는다

## 알려진 문서 불일치

- `server/.env.example`에 `DATA_FILE`, `SIMULATION_SPEED`가 빠져 있다. 두 변수 모두 `config.ts`가 읽는다. `KAT_API_BASE_URL`은 예시 파일에 주석 처리(`#`)된 상태로 들어 있다.
- `README.md`의 기술 스택 줄은 "Flutter (iOS · Android)"로 web을 빠뜨렸지만, 같은 README가 `CORS_ORIGINS` 설정과 `flutter run -d chrome --web-port`를 이용한 web 실행 방법을 안내하며 `app/web/` 타깃도 존재한다.
- `docs/`의 8개 문서 중 현재 코드를 설명하는 것은 `ARCHITECTURE.md`, `IMPLEMENTATION_BASELINE.md`뿐이다. `01`~`05`와 `PRODUCT_ROADMAP.md`는 대부분 구현되지 않은 제안이다. 예외로 `01_REVIEW_AND_IMPLEMENTATION_PLAN.md`(「A1 | 승인 코멘트와 서버 정책」, 「Phase A1: 승인 코멘트」)와 `03_CURSOR_IMPLEMENTATION_REQUEST.md`(「Step A1 — 승인 코멘트」)가 정의한 Step A1은 구현되었다(`IMPLEMENTATION_BASELINE.md`에 "Step A1 완료 (2026-11-20)", `http/schemas.ts`의 `MAX_APPROVAL_COMMENT_CHARS`=500, 커밋 a7b5244).
- KAT + OpenAI Realtime 실제 통화 경로는 환경 의존적이며 실운영 검증 사실은 확인되지 않았다.

## 목표 기술 방향(미구현)

소유자가 허브 인증·라우팅에 쓰겠다고 밝힌 표준이다. 아래 다섯 가지 모두 `server/package.json`, `app/pubspec.yaml`, `server/src`, `app/lib`에 나오지 않는다(의존성·코드에 없음).

| 표준 | 설명 |
|---|---|
| A2A | 에이전트 간 통신 프로토콜(Agent2Agent) |
| MCP | Model Context Protocol. 모델과 외부 도구·데이터를 잇는 프로토콜 |
| OAuth | 권한 위임 표준(OAuth 2.0) |
| JWT | JSON Web Token. 서명된 토큰 형식 |
| Ory Hydra | OAuth 2.0 / OpenID Connect 서버 |

현재 인증은 서버 전체가 공유하는 Bearer 토큰(`API_TOKEN`) 하나뿐이며, 계정이나 테넌트 개념이 없다. 이 표준들을 어떻게 조합할지는 미확인이다.

---

Generated by /moai project on 2026-11-20; based on repository state at commit c95953f.
