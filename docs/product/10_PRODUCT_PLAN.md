# 10. 제품 기획서 — 콜비(Kolbi) 상용 앱

- 작성일: 2026-11-26, 작성: jason (manager-spec)
- 문서 성격: 콜비 앱을 만들기 위한 제품 방향, 기능 목록, 출시 범위, 배포 채널(허브·SDK) 기획. 설계는 `11_ARCHITECTURE.md`, 구현 순서는 `12_IMPLEMENTATION_PLAN.md`, SPEC 묶음은 `.moai/specs/EPIC-KOLBI-APP/overview.md`.
- 입력 자료: `docs/planning/03_SERVICE_FEATURE_PLAN.md`(이하 "03"), `docs/planning/04_DESIGN_PLAN.md`(이하 "04"), `docs/planning/01_SERVICE_BENCHMARK.md`(이하 "01"), `docs/planning/02_UIUX_BENCHMARK.md`(이하 "02"), `docs/04_SDK_ADDON_PLATFORM_ARCHITECTURE.md`(이하 "SDK 제안"), `.moai/project/product.md`, 현재 코드(`app/lib`, `server/src`).
- UI 목업: `docs/mockups/`의 HTML 목업(별도 작성). 이 문서는 목업의 화면 ID(SCR-…)를 04와 같이 쓴다.
- 표기: **가정**은 근거 자료 없이 기획 판단으로 둔 값이다. 기능 ID(`F-…`)는 03의 번호를 그대로 쓴다.
- 개정 이력
  - 2026-11-26: 디자인 검토 반영. 근거는 `docs/planning/06_DESIGN_DECISIONS.md`(이하 "06"), 승인된 목업은 https://claude.ai/artifact/Cp7JpXX81GSaEKh5SVUQ7U(화면 ID는 06 §4). 앱 이름 콜비 확정(OD-12), 5칸 탭(SHELL-001 범위 변경), 새 기능 9개(§3.5), 음성 비서 SPEC 추가(SPEC-ASSIST-001, §4.2).

---

## 1. 제품 방향

### 1.1 한 줄 정의

콜비는 "한 줄로 맡기면 장소를 찾아 대신 전화하고, 중요한 순간에만 묻고, 결과를 일정·지도·공유로 이어 주는 한국어 개인 비서"다(03 §1). 전화는 첫 실행 수단이며, 같은 작업·승인 규칙 위에 웹 작업, 알림, 연동, 그리고 기업 인바운드 에이전트와의 에이전트 간(A2A) 연결을 차례로 더한다.

### 1.2 제품 원칙

| # | 원칙 | 이 계획에서의 뜻 |
|---|---|---|
| P-1 | 작업 하나, 실행 수단 여럿 | 사용자는 "작업"을 맡기고, 전화·웹·알림·연동·A2A는 작업 안의 실행 수단이다(03 §2.1). 앱 구조도 실행 수단이 아니라 작업 종류(`TaskKind`)로 확장한다 |
| P-2 | 맡기되 통제한다 | 돈·약정·확정·제출·로그인 직전에는 항상 멈추고, 만료는 거절이다(03 §2.4). 이 규칙은 실행 수단이 A2A로 바뀌어도 서버가 집행한다 |
| P-3 | 확인한 것만 확정처럼 보인다 | "확인 못 함"을 확정처럼 보이지 않게 한다(03 F-RES-01) |
| P-4 | 무인 자동화는 하지 않는다 | 출석은 마감 알림과 바로 열기까지만 한다. 사용자 계정으로 무인 로그인·클릭을 하지 않는다(03 F-ROUT-X1) |
| P-5 | 검색 결과를 쌓지 않는다 | 카카오 로컬 검색 결과는 응답으로만 넘기고 저장하지 않는다(03 §8.1, 01 §5.2) |
| P-6 | 비밀은 서버에만 있다 | KAT·OpenAI·허브 자격 증명과 파트너 비밀은 앱·SDK에 넣지 않는다(SDK 제안 §5) |
| P-7 | 한 번 만들어 여러 곳에 쓴다 | 화면과 도메인 로직을 패키지로 나누어 자체 앱, 임베디드 UI SDK, 헤드리스 SDK가 같은 코드를 쓴다 |
| P-8 | 깨지지 않게 넓힌다 | 기존 `/v1` API, WebSocket 전체 스냅샷과 `version` 병합, 기존 테스트를 모든 단계에서 유지한다 |

### 1.3 이 계획이 답하는 질문

1. 지금 있는 CallMate 프로토타입에서 무엇을 그대로 쓰고 무엇을 새로 만드는가(§3 기능 목록의 상태 열).
2. 이 저장소에서 이번에 무엇을 만들고 무엇을 뒤로 미루는가(§4 출시 범위).
3. 허브 플랫폼과 SDK는 제품에서 어떤 자리에 있는가(§5 배포 채널).
4. 구현을 막는 결정은 무엇이고, 결정 전까지 어떤 기본값으로 진행하는가(§6).

---

## 2. 대상 사용자

03 §3.1의 페르소나를 그대로 쓴다(모두 가정, 출시 전 인터뷰로 검증).

| ID | 사용자 | 콜비에 바라는 것 | 이 계획에서 먼저 닿는 기능 |
|---|---|---|---|
| PS-1 | 근무 중 통화가 어려운 회사원 | 한 줄로 맡기고 결과만 받기, 앱 밖에서 승인 | 한 줄 부탁, 장소 찾기, 작업함 "내 차례" |
| PS-2 | ARS·대기가 부담스러운 중장년 자영업자 | 협상은 맡기되 결정은 직접, 큰 글자 | 승인 카드, 큰 글자 2.0(보유) |
| PS-3 | 출석·쿠폰 마감을 놓치는 대학원생 | 마감 전 알림, 바로 열기 | 반복 알림(F-ROUT-01·02) |
| PS-4 | 일정이 흩어진 맞벌이 부모 | 병원 예약 변경, 메일 속 일정 정리 | 다시 걸기(보유), 캘린더 연동(후속) |

배포 채널이 늘면 대상이 둘 더 생긴다.

| ID | 대상 | 바라는 것 |
|---|---|---|
| PT-1 | 파트너 앱(가정: 생활·예약·금융 앱 운영사) | 자기 앱 안에서 "대신 전화" 기능을 화면째 또는 데이터만 가져다 쓰기 |
| PT-2 | 기업 인바운드 에이전트(허브 플랫폼 쪽, 소유자의 별도 프로젝트) | 콜비가 보내는 작업을 전화가 아닌 에이전트 간 채널로 받아 처리하기 |

---

## 3. 기능 목록

### 3.1 읽는 법

- 03 §4의 103개 기능을 한 표로 모았다. 기능 이름·우선순위·출시 단계는 03을 그대로 옮겼다.
- **앱 모듈**과 **서버 모듈**은 `11_ARCHITECTURE.md`의 모듈 이름이다. `kind:call`·`kind:web`은 작업 종류 확장 단위, `kolbi_ui(…)`는 SDK로도 내보내는 공용 UI다. "(후속)"은 이번 계획에서 모듈 자리만 정하고 만들지 않는 서버 모듈이다.
- **상태**: 구현됨 = 03에서 "보유"로 표시되고 현재 코드에 있음, 부분 = 03에서 "보유(…개선)"으로 표시되어 핵심은 있으나 개선 범위가 남음, 신규 = 아직 없음, 제외 = 제공하지 않기로 함.
- 상태 열은 03의 보유 표시를 따랐고, 다음 항목은 코드에서 직접 확인했다: F-CALL-02·F-TRUST-01 첫인사 AI 고지(`server/src/brain/prompts.ts:6`, `:39`), F-CALL-04 끊기(`server/src/http/app.ts:178`), F-TRUST-05 긴급·특수번호 차단(`server/src/domain/phone.ts:22`), F-PLACE-04 최근 장소(`app/lib/features/calls/domain/counterparties.dart:24`), F-INTG-01 일정 파일(`app/lib/features/calls/domain/follow_up.dart:45`), F-RES-03 공유(`app/lib/features/calls/presentation/widgets/follow_up_actions.dart:31`), F-TRUST-04 민감정보 검사(`app/lib/features/calls/domain/approval_comment.dart:68`). 나머지 보유 항목은 03의 표시를 근거로 삼았다.

### 3.2 전체 기능 표

| ID | 기능 | 우선순위 | 출시 단계 | 앱 모듈 | 서버 모듈 | 상태 |
|---|---|---|---|---|---|---|
| F-REQ-01 | 한 줄 부탁 입력 | P0 | 보유(Ph1 문구 개선) | home | intake | 부분 |
| F-REQ-02 | 받아쓰기 | P0 | Ph1 | assistant | intake | 신규 |
| F-REQ-03 | 예시 칩 | P0 | 보유(Ph1 문구 개선) | home | intake | 부분 |
| F-REQ-04 | 자주 하는 부탁 저장 | P1 | Ph2 | home | intake | 신규 |
| F-REQ-05 | 공유하기로 받기 | P1 | Ph2 | home | intake | 신규 |
| F-REQ-06 | 한 번에 한 질문 | P0 | 보유(Ph1 확장) | home | intake | 부분 |
| F-REQ-07 | 맥락 진입점 | P0 | Ph1 | home | intake | 신규 |
| F-REQ-08 | 대화 모드 음성 | P2 | Ph3 | home | intake | 신규 |
| F-REQ-09 | 사진으로 부탁 | P2 | Ph3 | home | intake | 신규 |
| F-PLACE-01 | 장소 키워드 검색 | P0 | Ph1 | places | places | 신규 |
| F-PLACE-02 | 후보 카드와 선택 | P0 | Ph1 | places | places | 신규 |
| F-PLACE-03 | 내 주변 검색 | P0 | Ph1 | places | places | 신규 |
| F-PLACE-04 | 최근 장소 | P0 | 보유 | places | places | 구현됨 |
| F-PLACE-05 | 내 장소 | P1 | Ph2 | places | places | 신규 |
| F-PLACE-06 | 온라인 예약 경로 안내 | P1 | Ph2 | places | places | 신규 |
| F-PLACE-07 | Google Places 보조 검색 | P2 | Ph3 | places | places | 신규 |
| F-CALL-01 | 계획 카드 | P0 | 보유(Ph1 개선) | task_detail · kind:call | calls · channels | 부분 |
| F-CALL-02 | 실제 발신과 AI 고지 첫인사 | P0 | 보유 | task_detail · kind:call | calls · channels | 구현됨 |
| F-CALL-03 | 진행 단계와 실시간 대화 기록 | P0 | 보유(Ph1 타임라인) | task_detail · kind:call | calls · channels | 부분 |
| F-CALL-04 | 통화 끊기 | P0 | 보유 | task_detail · kind:call | calls · channels | 구현됨 |
| F-CALL-05 | 다시 걸기·조건 바꿔 다시 | P0 | 보유 | task_detail · kind:call | calls · channels | 구현됨 |
| F-CALL-06 | 여러 곳 차례로 전화해 비교 | P1 | Ph2 | task_detail · kind:call | calls · channels | 신규 |
| F-CALL-07 | ARS 메뉴 탐색 | P1 | Ph2 | task_detail · kind:call | calls · channels | 신규 |
| F-CALL-08 | 정해진 시각에 걸기 | P1 | Ph2 | task_detail · kind:call | calls · channels | 신규 |
| F-CALL-09 | 수신 거부 목록과 재발신 제한 | P0 | Ph1 | task_detail · kind:call | calls · channels | 신규 |
| F-CALL-10 | AI 거절 대응 | P0 | Ph1 | task_detail · kind:call | calls · channels | 신규 |
| F-CALL-11 | 대기 대신 기다리기 | P2 | Ph3 | task_detail · kind:call | calls · channels | 신규 |
| F-CALL-12 | 통화 넘겨받기 | P2 | Ph3 | task_detail · kind:call | calls · channels | 신규 |
| F-WEB-01 | 웹 작업 실행기(기기 안, 지켜보는 실행) | P1 | Ph2 | kind:web | web(후속) | 신규 |
| F-WEB-02 | 허용 사이트 목록과 고위험 범주 차단 | P1 | Ph2 | kind:web | web(후속) | 신규 |
| F-WEB-03 | 행동 기록과 AI 조작 표시 | P1 | Ph2 | kind:web | web(후속) | 신규 |
| F-WEB-04 | 웹 양식 대신 작성 | P1 | Ph2 | kind:web | web(후속) | 신규 |
| F-WEB-05 | 증거 저장 | P1 | Ph2 | kind:web | web(후속) | 신규 |
| F-WEB-06 | 페이지 내용 지시 차단 | P1 | Ph2 | kind:web | web(후속) | 신규 |
| F-WEB-07 | 로그인 세션 관리 | P1 | Ph2 | kind:web | web(후속) | 신규 |
| F-WEB-08 | 서버 원격 브라우저(공개 페이지 조회) | P2 | Ph3 | kind:web | web(후속) | 신규 |
| F-ROUT-01 | 마감 알림과 바로 열기 | P0 | Ph1 | routines | routines | 신규 |
| F-ROUT-02 | 반복 일정 관리 | P0 | Ph1 | routines | routines | 신규 |
| F-ROUT-03 | 지켜보는 한 번 실행(출석) | P1 | Ph2 | routines | routines | 신규 |
| F-ROUT-04 | 반복 전화 | P1 | Ph2 | routines | routines | 신규 |
| F-ROUT-05 | 공식 API·제휴처 자동 처리 | P2 | Ph3 | routines | routines | 신규 |
| F-ROUT-X1 | 무인 자동 출석(서버가 사용자 계정으로 정기 로그인) | 제외 | — | routines | routines | 제외 |
| F-INTG-01 | 일정 파일 저장(.ics) | P0 | 보유 | results · integrations | integrations(후속) | 구현됨 |
| F-INTG-02 | 기기 캘린더에 추가 | P0 | Ph1 | results · integrations | integrations(후속) | 신규 |
| F-INTG-03 | Google Calendar 연결 | P1 | Ph2 | results · integrations | integrations(후속) | 신규 |
| F-INTG-04 | 지도 앱 길찾기 | P0 | Ph1 | results · integrations | integrations(후속) | 신규 |
| F-INTG-05 | 연락처에서 번호 고르기 | P0 | Ph1 | results · integrations | integrations(후속) | 신규 |
| F-INTG-06 | Gmail 읽기(일정·예약 메일) | P1 | Ph2 | results · integrations | integrations(후속) | 신규 |
| F-INTG-07 | 메일 초안 작성 | P2 | Ph3 | results · integrations | integrations(후속) | 신규 |
| F-INTG-08 | Outlook 메일·캘린더 | P2 | Ph3 | results · integrations | integrations(후속) | 신규 |
| F-INTG-09 | 일정 겹침 확인 | P1 | Ph2 | results · integrations | integrations(후속) | 신규 |
| F-NOTI-01 | 푸시 알림 기반 | P0 | Ph0 | shell(notifications) | notifications(후속) | 신규 |
| F-NOTI-02 | 내 차례 긴급 알림 | P0 | Ph1 | shell(notifications) | notifications(후속) | 신규 |
| F-NOTI-03 | 잠금 화면 진행 표시 | P0 | Ph1 | shell(notifications) | notifications(후속) | 신규 |
| F-NOTI-04 | 완료·실패·마감 알림 | P0 | Ph1 | shell(notifications) | notifications(후속) | 신규 |
| F-NOTI-05 | 예상 소요 시간 안내 | P0 | Ph1 | shell(notifications) | notifications(후속) | 신규 |
| F-NOTI-06 | 결과 이메일 받기 | P2 | Ph3 | shell(notifications) | notifications(후속) | 신규 |
| F-APPR-01 | 계획 확인 후 한 번에 시작 | P0 | 보유(Ph1 개선) | kolbi_ui(approval) · task_detail | calls(approvals) | 부분 |
| F-APPR-02 | 고정 승인 카드 | P0 | 보유 | kolbi_ui(approval) · task_detail | calls(approvals) | 구현됨 |
| F-APPR-03 | 빠른 답과 조건 코멘트 | P0 | 보유 | kolbi_ui(approval) · task_detail | calls(approvals) | 구현됨 |
| F-APPR-04 | 금액 상한 승인 | P0 | Ph1 | kolbi_ui(approval) · task_detail | calls(approvals) | 신규 |
| F-APPR-05 | 승인 제한 시간 재설계 | P0 | Ph1 | kolbi_ui(approval) · task_detail | calls(approvals) | 신규 |
| F-APPR-06 | 손 넘기기 화면 | P1 | Ph2 | kolbi_ui(approval) · task_detail | calls(approvals) | 신규 |
| F-APPR-07 | 지켜보기 모드 | P1 | Ph2 | kolbi_ui(approval) · task_detail | calls(approvals) | 신규 |
| F-APPR-08 | 알림에서 바로 답하기 | P1 | Ph2 | kolbi_ui(approval) · task_detail | calls(approvals) | 신규 |
| F-RES-01 | 결과 카드 | P0 | 보유 | results · kolbi_ui(result) | calls(outcome) | 구현됨 |
| F-RES-02 | 후속 행동 | P0 | 보유(Ph1 개선) | results · kolbi_ui(result) | calls(outcome) | 부분 |
| F-RES-03 | 공유 문구 | P0 | 보유 | results · kolbi_ui(result) | calls(outcome) | 구현됨 |
| F-RES-04 | 증거 첨부 | P1 | Ph2 | results · kolbi_ui(result) | calls(outcome) | 신규 |
| F-RES-05 | 비교표 | P1 | Ph2 | results · kolbi_ui(result) | calls(outcome) | 신규 |
| F-RES-06 | 확정 증거로 올리기 | P2 | Ph3 | results · kolbi_ui(result) | calls(outcome) | 신규 |
| F-RES-07 | 실패 뒤 다음 길 | P0 | Ph1 | results · kolbi_ui(result) | calls(outcome) | 신규 |
| F-INBOX-01 | 업무 탭 | P0 | Ph1 | inbox | store | 신규 |
| F-INBOX-02 | 내 차례 배지와 오늘 노출 | P0 | Ph1 | inbox | store | 신규 |
| F-INBOX-03 | 새 결과 표시 | P0 | Ph1 | history | store | 신규 |
| F-INBOX-04 | 삭제와 보관 기간 | P0 | Ph1 | history | store | 신규 |
| F-INBOX-05 | 기기 간 동기화 | P0 | Ph0 | inbox | store | 신규 |
| F-INBOX-06 | 검색·필터 | P1 | Ph2 | history | store | 신규 |
| F-MEM-01 | 기억 카드 | P1 | Ph2 | me | memory(후속) | 신규 |
| F-MEM-02 | 말로 기억시키기 | P1 | Ph2 | me | memory(후속) | 신규 |
| F-MEM-03 | 기억 사용 표시 | P1 | Ph2 | me | memory(후속) | 신규 |
| F-MEM-04 | 기억 일시정지·끄기·전체 삭제 | P1 | Ph2 | me | memory(후속) | 신규 |
| F-MEM-05 | 기본 프로필 | P0 | 보유(Ph1 서버 동기화) | me | memory(후속) | 부분 |
| F-ACCT-01 | 계정과 로그인 | P0 | Ph0 | me · onboarding | auth | 신규 |
| F-ACCT-02 | 사용자별 인증·데이터 분리 | P0 | Ph0 | me · onboarding | auth | 신규 |
| F-ACCT-03 | 사용량과 한도 표시 | P0 | Ph1 | me · onboarding | auth | 신규 |
| F-ACCT-04 | 구독·결제 | P1 | Ph2 | me · onboarding | auth | 신규 |
| F-ACCT-05 | 탈퇴와 데이터 삭제 | P0 | Ph0 | me · onboarding | auth | 신규 |
| F-ACCT-06 | 본인 확인(휴대폰 번호) | P0 | Ph0 | me · onboarding | auth | 신규 |
| F-TRUST-01 | 통화 첫인사 AI 고지 | P0 | 보유 | me · onboarding | policy | 구현됨 |
| F-TRUST-02 | 앱 내 AI 사전 고지 | P0 | Ph0 | me · onboarding | policy | 신규 |
| F-TRUST-03 | 녹음·전사 처리 고지와 보관 정책 | P0 | Ph0 | me · onboarding | policy | 신규 |
| F-TRUST-04 | 민감정보 입력 차단·마스킹 | P0 | 보유 | me · onboarding | policy | 구현됨 |
| F-TRUST-05 | 발신 차단과 남용 방지 | P0 | 보유(Ph1 확장) | me · onboarding | policy | 부분 |
| F-TRUST-06 | 안전하게 쓰는 법 | P1 | Ph1 | me · onboarding | policy | 신규 |
| F-TRUST-07 | 감사 기록 | P1 | Ph1 | me · onboarding | policy | 신규 |
| F-TRUST-08 | 신고·문의 창구 | P0 | Ph1 | me · onboarding | policy | 신규 |
| F-SET-01 | 자율성 단계 | P1 | Ph2 | me | — | 신규 |
| F-SET-02 | 알림 설정 | P0 | Ph1 | me | — | 신규 |
| F-SET-03 | 연결한 앱 관리 | P1 | Ph2 | me | — | 신규 |
| F-SET-04 | 언어 | P0 | 보유 | me | — | 구현됨 |
| F-SET-05 | 접근성 | P0 | 보유 | me | — | 구현됨 |
| F-SET-06 | 개발용 설정 숨김과 쉬운 오류 문구 | P0 | Ph0 | me | — | 신규 |

### 3.3 집계

| 상태 | 개수 | 비고 |
|---|---|---|
| 구현됨 | 13 | 그대로 쓰고 새 구조로 옮긴다 |
| 부분 | 9 | 이번 계획의 SHELL·PLACE에서 일부 개선(F-REQ-01·03·06, F-CALL-01·03) |
| 신규 | 89 | 이 가운데 이번 계획이 만드는 것은 §4.2. 2026-11-26 추가 9개(§3.5) 포함 |
| 제외 | 1 | F-ROUT-X1(무인 자동 출석) |
| 합계 | 112 | 03 §4.16과 같음(반영 전 103) |

### 3.5 디자인 검토로 더한 기능(2026-11-26)

03 §4.17의 기능이다. 앱 모듈은 11 §2.5 개정 배치를 따른다.

| ID | 기능 | 우선순위 | 출시 단계 | 앱 모듈 | 서버 모듈 | 상태 | 이번 계획 |
|---|---|---|---|---|---|---|---|
| F-ASST-01 | AI 비서 화면과 Orb 상태 | P0 | Ph1 | assistant · kolbi_ui(orb) | intake | 신규 | SPEC-ASSIST-001 |
| F-ASST-02 | 어디서든 비서 부르기 | P0 | Ph1 | shell | — | 신규 | SPEC-SHELL-001(버튼) · ASSIST-001(화면) |
| F-TASK-01 | 업무 실행 단계 화면 | P0 | Ph1 | task_detail · kolbi_core(단계 계산) · kolbi_ui(타임라인) | — | 신규 | SPEC-SHELL-001 |
| F-HIST-01 | 기록 탭 | P0 | Ph1 | history | store | 신규 | SPEC-SHELL-001 |
| F-HOME-01 | 오늘의 브리핑 | P1 | Ph2 | home · kolbi_ui(briefing) | (후속) | 신규 | 작업 기반 요약만 SHELL-001(04 DOD-12) |
| F-HOME-02 | 제안 업무 | P1 | Ph2 | home | memory(후속) | 신규 | 후속 |
| F-HOME-03 | 오늘의 일정 타임라인 | P1 | Ph2 | home | integrations(후속) | 신규 | 후속 |
| F-HOME-04 | 위젯 순서 바꾸기·숨기기 | P2 | Ph3 | home | — | 신규 | 후속 |
| F-SKILL-01 | 스킬 둘러보기 | P2 | Ph3 | me | platform(후속) | 신규 | 후속(자리만) |

### 3.4 03에 없고 이 계획이 더하는 플랫폼 기능

03의 기능은 사용자 기능이다. 배포 채널(§5)을 위해 다음 플랫폼 기능을 더한다. 번호는 `F-PLAT-`로 새로 둔다.

| ID | 기능 | 설명 | 우선순위 | 출시 단계 | 앱·패키지 | 서버 모듈 | 상태 |
|---|---|---|---|---|---|---|---|
| F-PLAT-01 | 모듈화된 앱 구조 | Dart 워크스페이스, `kolbi_core`(헤드리스)·`kolbi_ui`(공용 UI) 패키지, 의존 규칙 테스트 | P0 | 이번 계획 | workspace | — | 신규 |
| F-PLAT-02 | 작업 종류 등록부 | `TaskKind` 등록부. 종류마다 해석·상세·결과 화면·상태 문구를 꽂는다 | P0 | 이번 계획 | kolbi_core · kolbi_ui · shell | domain(`kind`) | 신규 |
| F-PLAT-03 | 실행 채널 추상화 | 작업을 전화(KAT) 또는 A2A로 실행. 전화가 기본, A2A는 허브 경로 확인 뒤 | P1 | 이번 계획(포트·가짜 허브) | — | channels | 신규 |
| F-PLAT-04 | 허브 연동 포트 | `HubClient`(경로 조회), `A2AChannel`, 콜비 Agent Card, 허브 인증 | P1 | 이번 계획(포트·계약 테스트) | — | hub · auth | 신규 |
| F-PLAT-05 | 인증 경계 | 앱 `AuthTokenProvider`, 서버 `Principal{tenantId, appId, userId, scopes}` | P0 | 이번 계획(정적 토큰 구현) | kolbi_core | auth | 신규 |
| F-PLAT-06 | 헤드리스 SDK | `KolbiClient` 공개 API, 타입 모델, 이벤트 스트림 | P1 | 이번 계획(sandbox) | kolbi_core | platform | 신규 |
| F-PLAT-07 | 임베디드 UI SDK | `KolbiTaskFlow`, `KolbiApprovalCard` 등과 테마 덮어쓰기 | P1 | 이번 계획(sandbox) | kolbi_ui | — | 신규 |
| F-PLAT-08 | 공개 플랫폼 API | `/platform/v1` 최소 범위, `GET /platform/v1/capabilities` | P1 | 이번 계획(기능 플래그 뒤) | — | platform | 신규 |
| F-PLAT-09 | 호스트 예제 앱 | `examples/host_app`, 비밀 없이 시뮬레이터로 동작 | P1 | 이번 계획 | examples | — | 신규 |
| F-PLAT-10 | 호스티드 애드온 | 콜비가 호스팅하는 위임 화면 + 일회용 실행 티켓 | P2 | 후속 | — | platform | 신규 |
| F-PLAT-11 | 네이티브 SDK | Swift·Kotlin 래퍼 | P2 | 후속(수요 확인 뒤) | — | — | 신규 |
| F-PLAT-12 | 파트너 콘솔 | 앱 등록, 콜백 허용 목록, 사용량 | P2 | 후속 | — | platform | 신규 |

---

## 4. 출시 범위

### 4.1 단계 정의

03 §11의 Phase 0~3을 그대로 쓴다. 이 저장소의 이번 계획은 단계와 겹쳐 놓인 "기반 작업"이다.

| 단계 | 목표(03 §11) | 이 저장소에서 이번에 만드는 것 | 뒤로 미루는 것 |
|---|---|---|---|
| Phase 0 상용 배포 선행 | 계정, 사용자별 인증·데이터 분리, 다중 인스턴스 저장소, 푸시 기반 | 인증 경계(`Principal`, `AuthTokenProvider`)만. 정적 토큰 하나를 principal 하나로 대응시킨다 | 계정·로그인(F-ACCT-01·06), 사용자별 저장소(F-ACCT-02, F-INBOX-05), 푸시(F-NOTI-01), 법률 고지(F-TRUST-02·03), 개발용 설정 숨김(F-SET-06) |
| Phase 1 완성된 전화 비서 | 한 줄 부탁 → 장소 → 계획 → 통화 → 앱 밖 승인 → 결과 | 5칸 탭과 업무·기록(F-INBOX-01·02, F-HIST-01), Midnight Indigo 토큰, 업무 실행 화면(F-TASK-01), AI 비서와 받아쓰기(F-ASST-01·02, F-REQ-02), 장소 찾기(F-PLACE-01·02·03), 계획 카드 다듬기 일부(F-CALL-01), 반복 알림(F-ROUT-01·02, 기기 로컬 알림) | 앱 밖 승인 알림(F-NOTI-02·03, 푸시 필요), 금액 상한(F-APPR-04), 기기 캘린더(F-INTG-02), 지도 딥링크(F-INTG-04), 연락처(F-INTG-05), 수신 거부(F-CALL-09), AI 거절 대응(F-CALL-10) |
| Phase 2 연결된 비서 | 웹 작업, 연동, 기억, 유료화 | 작업 종류 `web`·`integration_action`의 자리만 등록부에 예약 | 웹 작업 전체, OAuth 연동, 기억, 결제 |
| Phase 3 확장 | 음성·메일·고객센터·제휴 | 허브 A2A 포트와 계약 테스트, SDK(헤드리스·임베디드 UI) sandbox | 실제 허브 연결, 호스티드 애드온, 네이티브 SDK |

허브와 SDK는 03에서 Phase 3 검토 후보였지만(03 §11 Phase 3), 소유자가 이번 요청에서 확장 대상으로 명시했으므로 **구조(포트·패키지·계약)는 이번에 만들고, 외부 노출은 Phase 0 계정·사용자별 저장소가 끝난 뒤로 둔다**. 구조를 먼저 두어야 이후 기능이 허브·SDK 경로를 다시 뜯지 않는다.

### 4.2 이번 계획에서 만드는 범위

| 순서 | 묶음(SPEC) | 사용자에게 보이는 변화 | 실제로 연결되는 것 | 가짜·시뮬레이션으로 두는 것 |
|---|---|---|---|---|
| 1 | SPEC-MODULE-001 패키지 분리 | 없음(동작 불변) | — | — |
| 2 | SPEC-DESIGN-001 Midnight Indigo 디자인 시스템 | 색·Pretendard·상태 칩 범주·선 카드(글자와 배치는 그대로) | — | — |
| 3 | SPEC-SHELL-001 5칸 셸·작업 종류 등록부(Tier L) | 오늘·업무·기록·내 정보 탭과 가운데 비서 버튼, 업무 묶음과 배지, 업무 실행 단계 화면, 기록 목록, 오늘(작업 기반 브리핑) | 기존 `/v1` | — |
| 4 | SPEC-ASSIST-001 AI 비서와 받아쓰기 | AI 비서 화면(SCR-A01), Orb 상태, 받아쓰기, 통화 중 화면 몰입형 다크(SCR-T08) | 기기 음성 인식 또는 STT(06 Q-3) | 테스트는 가짜 음성 인식기 |
| 5 | SPEC-PLACE-001 장소 찾기 | 장소 선택(SCR-H02), 장소 상세(SCR-H03), 후보에서 계획 확인으로 | 카카오 로컬(키가 있을 때) | 시뮬레이션 장소 검색(기본) |
| 6 | SPEC-ROUTINE-001 반복 알림 | 반복 묶음, 마감 알림과 바로 열기 | 기기 로컬 알림 | 푸시(없음) |
| 7 | SPEC-HUB-001 허브·A2A 포트 | 계획 확인에 실행 경로 표시(허브 경로가 있을 때만) | — | 가짜 허브, 가짜 인바운드 에이전트 |
| 8 | SPEC-SDK-001 SDK 최소 범위 | 예제 호스트 앱에서 콜비 흐름, Theme Override | 시뮬레이터 | 파트너 BFF(가짜 토큰 발급기) |

### 4.3 이번 계획이 지키는 불변 조건

- `/v1` 경로·요청·응답, WebSocket 스냅샷 형식과 `version` 병합 규칙을 바꾸지 않는다. 새 필드는 더하기만 하고, 모르는 값은 예전처럼 읽는다.
- 앱 테스트 80개(2026-11-26 `flutter test` 실행 결과 "+80: All tests passed!")와 서버 테스트가 각 SPEC 끝에서 통과한다. 의도한 문구·배치 변경으로 고치는 테스트는 SPEC의 인수 기준에 이름을 적는다.
- 실제 발신은 지금처럼 환경 설정(`CALL_PROVIDER`, KAT 키)에 따른다. 새 기능의 테스트는 시뮬레이터와 가짜 구현만 쓴다.

---

## 5. 배포 채널과 제품 위치

### 5.1 다섯 가지 채널

| 채널 | 형태 | 누가 화면을 그리나 | 누가 로그인을 맡나 | 이 계획에서 |
|---|---|---|---|---|
| C-1 독립 앱 | 콜비 Flutter 앱(`app/`) | 콜비 | 콜비(지금은 개발용 토큰) | 5칸 탭으로 재구성(06 DR-2) |
| C-2 임베디드 UI SDK | Flutter 패키지 `kolbi_ui` | 콜비 위젯, 호스트 테마 | 호스트 앱 + 파트너 BFF가 짧은 수명 토큰 발급 | 최소 범위(`KolbiTaskFlow`, `KolbiApprovalCard`) sandbox |
| C-3 헤드리스 SDK | Dart 패키지 `kolbi_core` | 호스트가 직접 | 같음 | `KolbiClient` 공개 API sandbox |
| C-4 호스티드 애드온 | 콜비가 호스팅한 위임 화면 + 실행 티켓 | 콜비 웹 화면 | 같음 | 후속(F-PLAT-10) |
| C-5 A2A 에이전트 연결 | 허브를 거친 에이전트 간 채널 | 화면 없음(작업·메시지·산출물) | 허브 인가 서버(Ory Hydra, 소유자 진술) | 포트·Agent Card·가짜 허브·계약 테스트 |

### 5.2 허브와 A2A의 자리

- 콜비 서버는 허브 플랫폼의 **아웃바운드(발신) 에이전트**다(`.moai/project/product.md`). 사용자의 작업을 받아, 상대 기업에 인바운드 에이전트가 있으면 허브를 거쳐 A2A로 맡기고, 없으면 지금처럼 전화로 건다.
- 사용자에게 A2A는 "실행 경로" 하나로만 보인다. 계획 카드에 "AI 상담 창구로 연결" 또는 "전화로 연결"을 표시하고, 승인·만료·결과 규칙은 전화와 같다(P-2).
- 허브와 인바운드 에이전트는 이 저장소에 없다. 이번 계획은 콜비 쪽 포트, 콜비 Agent Card 초안, 가짜 허브, 계약 테스트를 만든다. 실제 연결은 허브가 준비된 뒤 별도 SPEC으로 한다.
- 열린 질문으로 남아 있던 "기업 연결을 전화로 할지, 에이전트 채널로 할지, 둘 다인지"(product.md)는 **둘 다, A2A 우선·전화 대체**를 기본값으로 둔다(OD-K4).

### 5.3 SDK·애드온의 자리

- 첫 소비자는 콜비 앱 자신이다. 앱의 화면과 로직이 `kolbi_core`·`kolbi_ui`를 쓰게 만들면, SDK는 따로 만드는 제품이 아니라 이미 쓰는 코드의 공개 표면이 된다.
- 외부 파트너가 실제 사용자에게 쓰려면 계정·tenant·사용자별 저장소가 먼저 있어야 한다(SDK 제안 §11 S4). 그 전까지 SDK는 sandbox(시뮬레이터, 가짜 토큰 발급기)에서만 동작한다.
- SDK 제안 문서의 패키지 이름(`callmate_dart`, `callmate_flutter`)은 이 계획에서 `kolbi_core`, `kolbi_ui`로 바꾼다. 이유는 `11_ARCHITECTURE.md` §2.2.

---

## 6. 구현을 막는 열린 결정

03 §14의 OD-1~14 가운데 이번 계획의 구현에 닿는 것과, 이 계획이 새로 여는 결정(`OD-K…`)이다. 소유자 결정 전까지 "이 계획의 기본값"으로 진행하며, 바꾸면 영향 열의 SPEC을 고친다.

| ID | 결정 사항 | 이 계획의 기본값 | 막는 것 | 영향 |
|---|---|---|---|---|
| OD-12 | 앱 이름 CallMate → 콜비 | **결정됨(2026-11-26): 콜비**(06 DR-1). 새 패키지는 `kolbi_*`. 화면 안 워드마크 `kolbi.`는 SPEC-SHELL-001에서 그린다. 앱 패키지(`callmate`)와 OS 표시 이름 변경은 별도 SPEC(OD-K1) | SPEC-MODULE-001 패키지 이름 | — |
| OD-5 | 최근 장소와 카카오 로컬 약관 해석 | 사용자가 통화한 상대는 작업 기록으로 보관(지금과 같음), 검색 결과 자체는 저장하지 않음 | SPEC-PLACE-001 | 불가 판정 시 업체명만 보관하고 번호는 다시 조회 |
| OD-2 | 출석 기능 범위 | 마감 알림과 바로 열기만(Phase 1) | SPEC-ROUTINE-001 | 변경 없음 |
| OD-6 | 승인 제한 시간 | 현재 90초 유지 | SPEC-HUB-001(A2A 입력 대기도 같은 값) | 값만 바뀜 |
| OD-9 | 로그인 수단 | 이번 계획에서 정하지 않음. 인증 경계만 만든다 | 없음(경계는 수단과 무관) | Phase 0 SPEC |
| OD-K1 | 앱 패키지 이름 변경 시점 | 이번 계획 밖의 별도 SPEC으로, 저위험 기계적 변경 | 없음 | SPEC-MODULE-001 이후 언제든 |
| OD-K2 | 탭 전환 때 홈에서 "지난 통화" 목록을 빼는가 | 뺀다. 끝난 작업은 **기록 탭**으로(06 DR-6, 2026-11-26 개정) | SPEC-SHELL-001 | 유지하면 홈 배치 기준만 바뀜 |
| OD-K3 | 장소 검색 제공자 키가 없을 때 | 시뮬레이션 장소 검색으로 동작하고 화면에 "연습용 장소" 표시 | SPEC-PLACE-001 | — |
| OD-K4 | 기업 연결 방식 | 허브에 인바운드 에이전트가 있으면 A2A 우선, 없거나 실패하면 전화로 대체. 대체 전에 사용자에게 한 번 묻는다 | SPEC-HUB-001 | "전화만"이면 A2A 경로를 꺼 둔 채 포트만 유지 |
| OD-K5 | 허브 인증 방식 | OAuth 2.1 client credentials + JWT 접근 토큰, 사용자 위임은 토큰 교환(RFC 8693). mTLS는 선택 | SPEC-HUB-001 | 허브 쪽 확정값으로 어댑터만 교체 |
| OD-K6 | SDK 최초 지원 플랫폼 | Flutter(헤드리스 Dart + Flutter UI). 네이티브는 수요 확인 뒤 | SPEC-SDK-001 | 파트너가 네이티브면 REST 계약 우선 |
| OD-K7 | 반복 작업 정의를 어디에 두는가 | 서버(`/v1/routines`)에 두고, 알림 예약은 기기 로컬 알림으로 | SPEC-ROUTINE-001 | 기기 저장으로 바꾸면 서버 모듈이 빠짐 |
| OD-K8 | 받아쓰기 방식 | 기기 음성 인식을 기본으로 하고, 인식 결과 글만 서버(`/v1/intake`)로 보낸다. 음성 자체는 서버로 보내지 않는다(06 Q-3) | SPEC-ASSIST-001 | STT API로 바꾸면 음성 전송 고지와 비용이 생김 |
| OD-K9 | 글꼴 | Pretendard 가변 글꼴 하나를 `kolbi_ui`에 넣는다(06 DR-8, 소유자 결정) | SPEC-SHELL-001 | — |
| OD-K10 | 다크 모드 | 기기 설정을 따르고, AI 비서·통화 중·온보딩 첫 장만 늘 다크(06 DR-9, 소유자 결정) | SPEC-SHELL-001, SPEC-ASSIST-001 | — |

---

## 7. 가정 목록

| ID | 가정 | 확인 방법 |
|---|---|---|
| A-1 | Flutter 3.50.1과 Dart 3.14가 pub 워크스페이스(`workspace:`, `resolution: workspace`)를 지원한다 | SPEC-MODULE-001 M1에서 `flutter pub get` 실행 결과로 확인 |
| A-2 | 허브는 A2A 공개 프로토콜의 Agent Card·작업·메시지·산출물·작업 상태 개념을 따른다 | 허브 프로젝트와 계약 문서 교환 |
| A-3 | 허브 인가 서버는 Ory Hydra이며 client credentials 흐름을 지원한다(소유자 진술) | 허브 쪽 설정 확인 |
| A-4 | 기기 로컬 알림 패키지로 일·주·월 반복 알림을 예약할 수 있다 | SPEC-ROUTINE-001 착수 시 패키지 문서 확인 |
| A-5 | 카카오 로컬 키워드 검색 응답에 전화번호가 있다(01 §5.2) | 개발 키로 실제 응답 확인(SPEC-PLACE-001) |
| A-6 | Pretendard 가변 글꼴을 넣어도 앱 용량 증가가 약 2MB 안팎이다 | SPEC-SHELL-001에서 빌드 크기 비교(06 Q-2) |
| A-7 | Flutter용 기기 음성 인식 패키지가 한국어 받아쓰기를 iOS·Android 모두 지원한다 | SPEC-ASSIST-001 착수 시 패키지 문서와 기기 시험 |
