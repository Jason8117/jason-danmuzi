# Cursor 구현 요청서 — CallMate SDK / Add-on 플랫폼

> 읽을 문서: `SOURCE_ARCHITECTURE.md`, `SOURCE_PRODUCT_ROADMAP.md`, `01_REVIEW_AND_IMPLEMENTATION_PLAN.md`, `02_TARGET_ARCHITECTURE.md`, `03_CURSOR_IMPLEMENTATION_REQUEST.md`, **`04_SDK_ADDON_PLATFORM_ARCHITECTURE.md`**. 실제 소스코드는 전달되지 않았으므로 반드시 저장소와 먼저 비교. 이 문서는 **기존 CallMate 개발 계획에 더하는 트랙**이며 기존 Step 0/A1~A5를 무효화하지 않는다.

## Master Prompt — Cursor에 처음 복사

```text
당신은 CallMate 프로젝트의 플랫폼/SDK 아키텍트와 시니어 개발자입니다.
목표는 현재 Flutter 앱+Fastify/TypeScript 서버에서 작동하는 AI 통화 대행을 외부 앱에서 Embedded SDK, Hosted Add-on, Headless API로 사용할 수 있는 재사용 플랫폼으로 확장하는 것입니다.

프로젝트 루트의 01~05 설계/구현 문서와 SOURCE_*.md를 읽고 실제 코드, 테스트, lockfile과 차이를 검증하세요.
중요한 비파괴 조건: 기존 CallService, CallProvider(Simulated/KAT), CallBrain, RealtimeBridge, REST /v1/tasks, WebSocket full snapshot/version, 승인 제한시간, 시뮬레이터, 실발신 안전 규칙을 유지하세요.

기술 전략:
- 기존 Fastify server에 platform 모듈을 별도로 추가하는 modular monolith 유지.
- 내부 API를 SDK에 직접 노출하지 않고 /platform/v1 계약과 DTO facade를 설계.
- 최초 SDK는 UI 없는 Dart package(callmate_dart) → Flutter UI package(callmate_flutter) → sample host app 순서. 호스트 앱이 자체 화면을 구현할 수 있어야 함.
- 모바일 앱에 파트너 client secret/KAT/OpenAI 키를 절대 넣지 말고, 외부 파트너 운영용 multi-tenant Auth/RBAC/ownership/Postgres가 갖춰지기 전에는 sandbox-only.
- ApprovalGate는 서버 권한 판정자, UI/SDK는 사용자 의사 입력/상태 반영만 담당.
- 타입·버전·오류·승인·이벤트 계약을 OpenAPI/contract tests로 관리.

작업 방식: 내가 지정한 SDK Step **하나만** 수행. 먼저 기존 기능과 충돌을 조사하고 파일별 변경 계획·수용 기준을 작성. 키 없이 Mock/Simulated provider로 테스트. 실발신/실계정/실결제/프로덕션 반영 금지. 완료 시 변경 파일 목록, API/types, 테스트 결과, 미검증 사항, 보안/하위호환성, 다음 단계 권고를 보고.

첫 요청: SDK Step S0(저장소 및 연동 경계 분석)만 하세요. 구현 코드는 수정하지 마세요.
```

## S0 — 저장소 감사 (코드 수정 금지)

```text
SDK Step S0만 수행하세요.
1. `CallService`/`TaskStore`/`ApprovalRequest`/provider/RealtimeBridge의 실제 타입/경로 분석.
2. 서버 라우트와 인증/WS 연결 계약, Flutter repository/controller/screens 의존 그래프 추출.
3. UI 종속 로직 vs 순수 도메인 로직 표시, 추출 가능한 widget/typed SDK API 후보 표시.
4. 현재 사용 가능한 실행/test/build 명령과 시뮬레이터 자동화 결과 기록. 실제 통화 금지.
5. 공개 API와 내부 API를 분리하기 위한 최소 adapter/facade, 호환성 위험, 다중 사용자 보안 차단 조건을 `docs/SDK_PLATFORM_BASELINE.md`에 문서화.
6. S1의 API 스펙 설계를 제시하고 대기.
```

## S1 — 계약 우선 (공개 API 스펙 + facade)

```text
SDK Step S1만 수행. 실제 repo와 S0 결과를 기준으로 하세요.
- specs/openapi.platform.v1.yaml에 SDK session(안전한 mock-only), call tasks, approval, cancel, task snapshot, errors, capabilities, events를 문서화.
- 기존 `/v1/tasks` 내부 API는 변경/삭제하지 말고 platform DTO mapper/facade layer 분리.
- `tenantId`, `appId`, `userId`, scope, `version`, `requestId`, `Idempotency-Key` 의미를 명확히 정의. 외부 공개 모드 비활성(feature flag).
- SDK에서 신뢰하면 안 되는 client-supplied tenant/subject 필드를 사용해 owner 권한을 구현하지 말 것.
- 보안 구현이 없는 경로는 전부 테스트 모드 및 localhost/mock에서만 접근 가능하도록 강제하고 운영 배포 노출 금지.
- schema validation, API contract tests, 기존 regression tests와 결과를 보고.
```

## S2 — Headless Dart SDK (sandbox)

```text
SDK Step S2만 수행.
- `packages/callmate_dart` 작성: typed models, CallMateClient, create/get/approvePlan/respondToApproval/cancel, status subscription, error mapping, authTokenProvider 주입, idempotency support.
- Dart package는 Flutter UI에 의존하지 않아야 함; API URL/credentials 하드코딩 금지.
- stream disconnect/reconnect 시 GET task 후 단조 증가 version만 수용.
- mock HTTP/WS 기반 unit tests, API schema mismatch tests, approval timeout/409, retry/backoff tests.
- `packages/callmate_sdk_example`에 파트너 앱 연동 샘플. sandbox only.
- API secret 사용 없음. 실제 KAT 호출 없음.
```

## S3 — Flutter Embedded UI SDK

```text
SDK Step S3만 수행.
- `packages/callmate_flutter` 작성: CallMateCallFlow 및 필요한 CallRequestForm/CallPlanReview/CallProgressView/ApprovalCard/OutcomeView.
- host injectable client, theme/localization, onExit/onComplete/onError, host navigation, keyboard/accessibility 지원.
- 비즈니스 승인 정책은 서버에 남기고 위젯은 결정을 전송한 뒤 응답으로 확정.
- 기존 CallMate Flutter 앱에서 가장 안전한 화면 1개만 이식하여 패키지 소비를 검증, 전체 재작성 금지.
- example host app에서 네트워크 장애/앱 재시작/재연결/타임아웃/호스트 UI 재마운트 테스트.
- 기존 앱의 UI와 behavior regression 테스트.
```

## S4 — Multi-tenant Identity + Persistence (외부 공개 전 필수)

```text
SDK Step S4는 설계 결과를 먼저 제출하고 사용자 승인 후 구현하세요.
- tenant/app/end-user 모델, 파트너 BFF 전용 credential, 짧은 수명 sdkAccessToken, scopes/audience, per-resource ownership 검증.
- Postgres migration + 백업/롤백 계획, transactional approval, idempotency keys, outbox model; 실제 데이터 이관은 별도 승인 후.
- tenant/user/app별 rate limits, concurrency/cost budgets, feature entitlements.
- 혼합 tenant 테스트: task/approval/transcript/websocket/webhook 모두 교차 접근 거부, token replay/expiry 검증.
- 기존 개인용 모드는 외부 tenant 등록 없이도 회귀 가능해야 함.
- 보안이 불완전하면 production exposure=off 유지.
```

## S5 — 공개 API / Events / Webhooks / Dev Sandbox

```text
SDK Step S5만 수행. S4가 승인되고 완료된 상태가 선행조건.
- 실제 인증된 /platform/v1 라우트와 API schema 검증, versioned errors, capabilities, owner policy.
- event stream tickets (short lived, replay guarded), eventId and resourceVersion.
- BFF 전용 webhook subscription, payload signing/timestamps, SSRF-safe URL validation, idempotent outbox delivery, retries + DLQ.
- sandbox mode with SimulatedCallProvider, usage/event audit, docs/examples.
- event out of order and duplicate delivery, approval expiry before push/webhook, hostile URLs/security tests.
- 외부 실사용 공개는 보안/법률/파트너 계약 검토 후 명시 승인까지 차단.
```

## S6 — Hosted Add-on / Developer Portal

```text
SDK Step S6만 수행.
- BFF-created one-time launch ticket, short expiry, return state/nonce, allowed callback URL/redirect, replay prevention.
- Hosted UI는 taskId/reference만 반환하고 상세 transcript/token/PII는 redirect URL로 보내지 말 것.
- Partner app registration, environment separation, scope controls, webhook secret rotate, diagnostics, sandbox usage.
- 가격/과금 로직은 제품 정책 결정 전 구현하지 말고 usage event 설계까지만.
- CSP, deep-link hijack, redirect abuse, session fixation, cross-tenant replay tests.
```

## S7 — 네이티브 Wrapper / 기능 확장 (별도 결정)

```text
SDK Step S7의 범위와 필요성을 우선 보고. 첫 파트너 언어/수요가 확인된 후 Swift Package / Android Kotlin / React Native wrapper 중 필요한 것만 구현. 이 단계는 기존 플랫폼 API와 approval policy를 변경하지 않고 wrapper/contract만 추가.
```

## 공통 Done 정의

- 단일 Step만 코드 변경, 기존 앱 및 시뮬레이터 테스트 통과.
- 공개 API/OpenAPI 와 SDK 모델이 상호 호환, breaking change 문서화.
- 승인 만료·중복·재시도·취소 상태 모두 서버 authoritative.
- tenant/app/user 권한 재확인, secrets/PII 로그·URL 유출 없음.
- 실제 수행하지 않은 test/deploy는 수행했다고 주장하지 않음.
- `git diff --stat` 및 수정·추가 파일, 실행 결과, 차기 단계 1개만 보고.
