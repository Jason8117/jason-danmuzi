# 에픽 EPIC-KOLBI-APP — 콜비 앱의 모듈화와 확장 기반

작성: 2026-11-26, jason (manager-spec). 상태: 계획 단계(SPEC-MODULE-001 `implemented`(2026-11-27), DESIGN-001·SHELL-001·ASSIST-001 `draft`, 나머지 네 SPEC은 요약만 있음). plan-audit 1차(2026-11-26): MODULE 0.77·SHELL 0.70·ASSIST 0.71 모두 FAIL → 반영 후 2차 대기, DESIGN-001은 SHELL에서 나뉘어 새로 씀.

개정: 2026-11-26 디자인 검토 반영(`docs/planning/06_DESIGN_DECISIONS.md`). 3탭 → 5칸 셸, Midnight Indigo 토큰, SPEC-ASSIST-001 추가(SPEC 6개 → 7개), 공통 결정 D-13~D-15.

관련 문서:

- 제품 기획서: `docs/product/10_PRODUCT_PLAN.md`
- 설계서: `docs/product/11_ARCHITECTURE.md`
- 구현 계획: `docs/product/12_IMPLEMENTATION_PLAN.md`
- 입력 기획: `docs/planning/03_SERVICE_FEATURE_PLAN.md`(기능 ID `F-…`, 작업 모델 §7), `docs/planning/04_DESIGN_PLAN.md`(화면 `SCR-…`, 컴포넌트 `CMP-…`)
- UI 목업: https://claude.ai/artifact/Cp7JpXX81GSaEKh5SVUQ7U (2026-11-26 소유자 승인, 화면 ID 대응은 06 §4)
- 디자인 결정: `docs/planning/06_DESIGN_DECISIONS.md`(05 검토의 반영 기록. 03·04와 다르면 06이 앞선다)
- 앞선 에픽: `.moai/specs/EPIC-ASSISTANT-UX/overview.md`(SPEC-UX-001의 토큰·공용 카드·접근성 규칙을 이 에픽이 그대로 이어받음)

## 1. 목표

CallMate 프로토타입을 상용 앱 "콜비"로 키우기 위한 구조를 만든다. 이번 에픽이 끝나면:

1. 앱 코드가 헤드리스 패키지(`kolbi_core`), UI 패키지(`kolbi_ui`), 앱 셸(`app/`)로 나뉘고, 이 경계가 테스트로 지켜진다.
2. 앱이 5칸 탭(오늘 / 업무 / 가운데 비서 / 기록 / 내 정보)과 Midnight Indigo 디자인 시스템으로 바뀌고, 작업 종류(`TaskKind`)를 셸 수정 없이 더할 수 있다. 업무 하나의 진행을 6단계로 보인다.
3. Phase 1의 중심 흐름에 AI 비서(음성·글 부탁), 장소 찾기, 반복 알림이 더해진다.
4. 서버가 허브(A2A)와 SDK로 넓힐 포트·인증 경계·공개 API 최소 범위를 갖추되, 외부 노출은 Phase 0 계정·사용자별 저장소 이후로 미룬다.

## 2. SPEC 목록과 순서

```
SPEC-MODULE-001 ──► SPEC-DESIGN-001 ──► SPEC-SHELL-001 ──► SPEC-ASSIST-001 ──► SPEC-PLACE-001 ──► SPEC-ROUTINE-001
(패키지 분리)        (토큰·글꼴·칩)        (5칸 셸·업무·        (AI 비서·받아쓰기)    (장소 찾기)          (반복 알림)
                                           기록·단계, Tier L)                          │
                                              │                                        ▼
                                              └───────────────────────────────► SPEC-HUB-001 ──► SPEC-SDK-001
```

| 차수 | SPEC | 상태 | 우선순위 | `depends_on` | 문서 | Tier(예상) |
|---|---|---|---|---|---|---|
| 1 | SPEC-MODULE-001 워크스페이스와 패키지 분리 | implemented(0.2.2, 2026-11-27) | High | SPEC-UX-001(sync 완료) | spec·plan·acceptance·progress | M |
| 2 | SPEC-DESIGN-001 Midnight Indigo 디자인 시스템(토큰·Pretendard·상태 칩 범주·선 카드) | draft(0.1.0) | High | SPEC-MODULE-001 | spec·plan·acceptance·progress | M |
| 3 | SPEC-SHELL-001 5칸 셸·작업 종류 등록부·업무 실행 단계 | draft(0.3.0) | High | SPEC-MODULE-001, SPEC-DESIGN-001 | spec·plan·acceptance·design·research·progress | L |
| 4 | SPEC-ASSIST-001 AI 비서와 받아쓰기 | draft(0.2.0) | High | SPEC-SHELL-001, SPEC-DESIGN-001 | spec·plan·acceptance·progress | M |
| 5 | SPEC-PLACE-001 장소 찾기 | 요약(§4.1) | High | SPEC-ASSIST-001 | 이 문서 | M |
| 6 | SPEC-ROUTINE-001 반복 알림과 바로 열기 | 요약(§4.2) | Medium | SPEC-SHELL-001(실행은 PLACE-001 다음) | 이 문서 | M |
| 7 | SPEC-HUB-001 허브·A2A 포트와 인증 경계 | 요약(§4.3) | Medium | SPEC-PLACE-001 | 이 문서 | L |
| 8 | SPEC-SDK-001 SDK 최소 범위 | 요약(§4.4) | Medium | SPEC-HUB-001 | 이 문서 | L |

순서 이유는 `docs/product/12_IMPLEMENTATION_PLAN.md` §1.1. 5~8차 SPEC은 앞 SPEC이 끝난 뒤 이 문서의 요약을 바탕으로 전체 문서를 쓴다.

04의 SPEC 후보 이름과의 대응: 04 §11의 SPEC-UX-002(3탭 IA·작업 문구, 2026-11-26에 5칸 셸로 개정)는 SPEC-SHELL-001이 맡고, SPEC-PLACE-001은 04의 이름을 그대로 쓴다.

## 3. 공통 결정

이 에픽의 모든 SPEC에 적용한다.

| ID | 결정 | 근거 |
|---|---|---|
| D-1 | `/v1` 경로·요청·응답, WebSocket 전체 스냅샷과 `version` 병합 규칙을 바꾸지 않는다. 새 필드·경로·이벤트는 더하기만 하고, 모르는 값은 예전처럼 읽거나 무시한다 | 03 §7.5 호환 행, SDK 제안 §11 |
| D-2 | 각 SPEC 끝에서 기존 테스트가 통과한다. 의도한 변경으로 고치는 테스트는 그 SPEC의 인수 기준에 이름으로 적고, 그 밖의 테스트 파일은 고치지 않는다. 기준선: 2026-11-26 `cd app && flutter --suppress-analytics test` → `+80: All tests passed!` | SPEC-UX-001 REQ-014 방식 |
| D-3 | 새 패키지 이름은 `kolbi_*`. 앱 패키지(`callmate`)와 화면 제목 변경은 이 에픽 밖의 별도 SPEC | 03 OD-12, 설계서 §2.2 |
| D-4 | 의존 방향 `kolbi_core ◄ kolbi_ui ◄ app`. `kolbi_core`는 Flutter를 가져오지 않는다. 기능 모듈끼리 가져오지 않고 경로 이름으로만 이동한다. 검사는 import 줄을 글자로 대조하는 테스트로 한다 | 설계서 §2.4 |
| D-5 | 서식 도구는 고친 파일에만 돌린다. 저장소 전체 `dart format`은 쓰지 않는다 | 프로젝트 규칙(앱 전체가 서식 기준을 맞추고 있지 않음) |
| D-6 | 새 기능의 테스트는 시뮬레이터와 가짜 구현만 쓴다. 실제 발신·실제 외부 API·실제 허브는 테스트에 쓰지 않는다 | 기존 SPEC 관례, SDK 제안 §10 |
| D-7 | 돈·약정·확정·추가 개인 정보 제공 직전 승인, 만료 = 거절 규칙은 실행 수단(전화·A2A)과 무관하게 서버가 집행한다 | 03 §2.4, EPIC-ASSISTANT-UX D4 |
| D-8 | 카카오 로컬 검색 결과는 저장·캐시·로그하지 않는다 | 03 §8.1, OD-5 |
| D-9 | 자격 증명(KAT, OpenAI, 허브, 파트너 비밀)은 서버 환경 변수에만 둔다. 앱·SDK·예제에 넣지 않는다 | SDK 제안 §5 |
| D-10 | 사용자별 데이터 분리 전에는 `/platform/v1`과 허브 경로를 기본 꺼짐 플래그 뒤에 두고 sandbox에서만 연다 | 설계서 §8 S-1 |
| D-11 | 1·2차 SPEC은 `server/`를 바꾸지 않는다. 3차부터 서버를 바꾸는 SPEC은 개발 서버가 실제 통화를 하고 있지 않은지 소유자와 맞춘 뒤 run을 시작한다 | 현재 개발 서버(`tsx watch`)가 실제 통화에 쓰이고 있음 |
| D-12 | 화면 ID·컴포넌트 ID는 04를 따른다(04 §17과 06 §4의 새 ID 포함). 공용 카드·접근성 검사 방식은 SPEC-UX-001을 따르고, 토큰 **값**은 06 §3(Midnight Indigo)을 따른다 | 04 §5·§17, 06, SPEC-UX-001 |
| D-13 | 상태 색의 뜻은 SPEC-UX-001 규칙 그대로, 값만 바꾼다: 진행 중 = 인디고, 승인 필요 = Warning, 완료 = Success, 실패 = Error, 대기·확인 못 함 = 무채색. 상태는 늘 아이콘 + 글자 + 색 | 06 DR-7, 04 DP-6 |
| D-14 | Agent 컴포넌트(Orb, 단계 타임라인, 상태 칩, 승인 카드, 브리핑 카드)는 `kolbi_ui`에 두어 앱과 SDK가 같이 쓴다. 음성 인식 패키지는 앱 의존으로만 | 06 DR-13, 설계서 AD-9 |
| D-15 | 업무 실행 단계와 업무·기록 묶음은 `kolbi_core` 순수 함수로 계산하고 `/v1`은 바꾸지 않는다 | 설계서 §3.5·§3.6, AD-8 |

## 4. SPEC 요약(전체 문서가 없는 것과 ASSIST)

### 4.0 SPEC-ASSIST-001 — AI 비서와 받아쓰기 (High, `depends_on: SPEC-SHELL-001`, 2026-11-26 추가)

어느 화면에서든 가운데 비서 버튼으로 AI 비서(SCR-A01)를 열어 말이나 글로 부탁하게 한다(03 F-ASST-01·02, F-REQ-01·02·03·06, 04 §17.4, 06 DR-11). `kolbi_ui`의 `KolbiOrb`에 상태 4종(대기·듣는 중·처리 중·응답 중)의 움직임을 더하고 움직임 줄이기에서는 멈춘다. 상태는 늘 글자 칩으로도 보인다. 받아쓰기는 기기 음성 인식을 쓰고 인식된 글만 기존 `/v1/intake`로 보낸다(음성은 서버로 보내지 않음, 10 OD-K8). 마이크 권한은 처음 말하기 전에 목적 문장과 함께 묻고(CMP-23), 거부하면 글로 입력으로 이어 간다. 인식 결과로 대상·번호가 정해지면 계획 확인으로, 장소가 필요하면 장소 선택(SPEC-PLACE-001 전까지는 기존 번호 입력)으로 간다. 통화 중 화면(SCR-T08)을 몰입형 다크로 만들고 기존 대화 기록·승인 카드·끊기를 옮긴다(04 §17.6). 음성 인식 패키지는 착수 시 선정한다(10 가정 A-7). 대화형 음성 모드(F-REQ-08)와 Orb가 말하는 음성 응답(TTS)은 범위 밖이다.

### 4.1 SPEC-PLACE-001 — 장소 찾기 (High, `depends_on: SPEC-ASSIST-001`)

장소 조건이 있는 한 줄 부탁이나 "근처" 부탁에서 후보 장소를 찾아 고르게 하고, 고른 장소로 계획 카드를 채운다(03 F-PLACE-01·02·03, 04 SCR-H02·H03, CMP-05·06, 흐름 1). 서버에 `places` 모듈을 더한다: `PlaceSearchProvider` 포트, 키 없이 동작하는 시뮬레이션 제공자(기본), 카카오 로컬 키워드 검색 어댑터(키가 있을 때), 새 내부 경로 `POST /v1/places/search`. 핵심 요구: 검색 결과는 응답으로만 넘기고 서버에 저장·캐시·로그하지 않는다(D-8, 테스트로 증명). 후보의 번호는 `checkTargetNumber`를 지나 "걸 수 있음 / 번호 없음 / 걸 수 없는 번호"로 표시하고, 번호 없는 후보는 고를 수 없다. 위치 권한은 처음 "근처"를 쓸 때 목적 문장과 함께 요청한다(CMP-23). 장소 상세 시트에서 [여기에 물어보기]로 계획 카드를 연다(F-REQ-07). 홈의 "최근 통화한 곳"을 "최근 장소"로 바꾸고(04 §11.1 C2), 계획 카드는 확인할 칸만 펼친다(04 D-4, F-CALL-01 일부). 장소 선택은 홈 안 카드가 아니라 AI 비서 다음 화면으로 연다(04 §17.1·§17.8, 06 DR-4). 카카오 API의 요청·응답 필드는 착수 시 공식 문서로 확인한다. 약관 해석(OD-5)이 "불가"로 나오면 최근 장소는 업체명만 보관하고 번호는 매번 다시 조회한다.

### 4.2 SPEC-ROUTINE-001 — 반복 알림과 바로 열기 (Medium, `depends_on: SPEC-SHELL-001`, PLACE-001 다음 실행)

출석·이벤트·쿠폰 마감 같은 반복 알림을 만들고, 정한 시각에 기기 로컬 알림을 보내며, 알림을 누르면 대상 앱(딥링크)이나 사이트를 바로 연다(03 F-ROUT-01·02, 04 SCR-H06·T07, CMP-24·25, 흐름 3). 처리는 사용자가 직접 하며 무인 실행 경로를 만들지 않는다(F-ROUT-X1 제외, OD-2). 서버에 `routines` 모듈과 `/v1/routines`(목록·만들기·고치기·일시정지·지우기), 실시간 `routine.updated` 이벤트를 더한다(옛 앱은 무시). 다음 실행 시각 계산(매일·매주 요일·매월 날짜, 아시아/서울)은 `kolbi_core`의 순수 함수로 둔다. 작업 종류 `reminder`를 등록부에 등록하고, 작업함 "반복" 묶음을 채운다. 일시정지·삭제는 예약된 알림을 취소해야 하고, 알림 문구에 금액·번호·대화 내용이 없어야 한다(04 §13.3 잠금 화면 문구 검사 방식). 푸시 기반(F-NOTI-01)과 서버 스케줄러가 회차 작업을 만드는 반복 전화(F-ROUT-04)는 범위 밖이다. 로컬 알림 패키지는 착수 시 선정한다(가정 A-4).

### 4.3 SPEC-HUB-001 — 허브·A2A 포트와 인증 경계 (Medium, `depends_on: SPEC-PLACE-001`)

콜비 서버를 허브 플랫폼의 아웃바운드 에이전트로 연결할 수 있게 포트와 경계를 만든다(설계서 §4.5, §5, §6.2). 서버 `auth` 모듈: `Authenticator` 포트와 `Principal{tenantId, appId, userId, scopes}`, 지금 동작을 그대로 옮긴 `StaticTokenAuthenticator`(401 조건 불변). `channels` 모듈: `TaskChannel` 포트, 기존 `CallProvider` 경로를 감싸는 `PhoneChannel`(기존 `callService.test.ts`가 수정 없이 통과), 계획 단계에서 경로를 정하는 `ChannelRouter`. `hub` 모듈: `HubClient.lookupRoute`, `A2AConnection`, `A2AChannel`, A2A 작업 상태 ↔ 콜비 상태 대응표, 콜비 Agent Card 생성, 허브 토큰 포트(client credentials, 사용자 위임 토큰)와 허브 콜백 JWT 검증 함수, `FakeHub`·가짜 인바운드 에이전트, 같은 모음을 나중에 실제 허브에 돌릴 계약 테스트. 핵심 요구: `HUB_ENABLED`(기본 꺼짐)에서는 경로 조회조차 하지 않고 기존 동작과 같다. 경로가 A2A면 계획 카드에 실행 경로를 보이고 [이대로 시작] 승인 대상에 포함한다. 상대가 사용자 판단을 요구하면(input-required) 기존 승인 카드와 만료 = 거절 규칙을 탄다(D-7). A2A가 거절·실패하면 사용자에게 한 번 묻고 전화로 다시 계획한다(OD-K4). 상대 메시지는 데이터로만 다룬다. A2A 세부 필드와 Hydra의 토큰 교환 지원 여부는 허브와 확인할 항목으로 남기고(검증 필요), 실제 허브 클라이언트는 만들지 않는다.

### 4.4 SPEC-SDK-001 — SDK 최소 범위 (Medium, `depends_on: SPEC-HUB-001`)

자체 앱이 이미 쓰는 패키지를 헤드리스·임베디드 SDK의 공개 표면으로 다듬는다(설계서 §6.1, §7). `kolbi_core`: `KolbiClient`(intake, 작업 만들기·조회·계획 승인·취소·승인 응답, `watchTask`, `capabilities`), `AuthTokenProvider`와 `StaticTokenProvider`(앱이 쓰며 요청 헤더는 지금과 같아야 함), 봉인된 이벤트 타입, `KolbiException`, 앱과 공유하는 버전 병합 함수. 서버 `platform` 모듈: `/platform/v1` 최소 경로(capabilities, sandbox sdk-sessions, intake, tasks, approve-plan, cancel, approvals, event-tickets, events), `PLATFORM_API_ENABLED` 기본 꺼짐, `server/specs/openapi.platform.v1.yaml`과 응답 대조 계약 테스트, 다른 principal의 자원은 404. `kolbi_ui`: 승인 카드를 콜백을 받는 `KolbiApprovalCard`로 추출하고 앱도 같은 위젯을 쓴다(기존 승인 카드·접근성 테스트가 수정 없이 통과), `KolbiTaskFlow`, `ThemeExtension` 기반 Theme Override(색·글꼴·모서리, Orb 스타일)와 대비 경고(설계서 §7.2, 06 DR-13). `examples/host_app`: 비밀 없이 시뮬레이터와 가짜 BFF로 흐름을 열고 결과를 받는 최소 앱과 위젯 테스트. 패키지별 `CHANGELOG.md`와 semver 0.x 정책. 외부 파트너 노출, 웹훅, 호스티드 애드온, 네이티브 SDK는 범위 밖이다.

## 5. 에픽 밖(후속)

Phase 0 상용 기반(계정·로그인, 사용자별 저장소·다중 인스턴스, 서버 상태 이름 전환, 푸시, 법률 고지, 개발용 설정 숨김), Phase 1 나머지(앱 밖 승인 알림·잠금 화면, 금액 상한, 기기 캘린더, 지도 딥링크, 연락처), 허브 실연결, Phase 2 이후 기능, 앱 패키지 이름 변경. 목록과 막고 있는 결정은 `docs/product/12_IMPLEMENTATION_PLAN.md` §2.7.
