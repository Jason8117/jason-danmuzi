# Cursor 개발 구현 요청서 — CallMate

> **사용 방법:** 저장소 루트에 본 파일과 `01_REVIEW_AND_IMPLEMENTATION_PLAN.md`, `02_TARGET_ARCHITECTURE.md`, 기존 `PRODUCT_ROADMAP.md`, `ARCHITECTURE.md`를 함께 둔다. Cursor Agent에 아래 **Master Prompt**를 복사하고, 완료 후 별도 단계 지시문을 순서대로 전달한다.  
> **주의:** 현재 분석에는 실제 애플리케이션 소스가 포함되지 않았다. Cursor는 문서만으로 구현 상태를 단정하지 말고 반드시 git 저장소를 직접 확인해야 한다.

## 1. Master Prompt — 최초 1회 붙여넣기

```text
당신은 CallMate 프로젝트의 시니어 풀스택 엔지니어이자 테스트 담당자입니다.

[제품 및 기반]
- CallMate는 Flutter(iOS/Android) + Riverpod 앱과 Fastify/TypeScript 서버입니다.
- KAT Cloud + OpenAI Realtime 실제 전화, CallProvider 시뮬레이터, CallBrain, 통화 중 승인, WebSocket 전체 Task 스냅샷 + version이 기존 아키텍처의 핵심입니다.
- 프로젝트 루트의 PRODUCT_ROADMAP.md, ARCHITECTURE.md, 01_REVIEW_AND_IMPLEMENTATION_PLAN.md, 02_TARGET_ARCHITECTURE.md, 03_CURSOR_IMPLEMENTATION_REQUEST.md를 읽으세요.
- 문서에 없는 세부사항은 가정하지 말고 실제 소스/테스트/lockfile로 검증하세요. 문서와 코드가 다르면 실제 코드 우선, 차이를 명시하세요.

[작업 방식 — 필수]
1) 우선 repo 구조, git status, 주요 타입과 메서드, 테스트/빌드/실행 스크립트를 조사하세요.
2) 현재 동작/구현 여부/누락사항을 표로 보고하고 단계별 변경 파일, 위험, 검증계획을 제시하세요.
3) 내가 지정한 ONE STEP만 구현합니다. 다른 Phase의 기능을 선제 구현하지 마세요.
4) 기존 API, Flutter DTO, WebSocket 스냅샷, 단조 증가 version, 시뮬레이터, KAT 실통화 동작을 파괴하지 마세요.
5) DB/프레임워크 교체 또는 대규모 리팩터링을 먼저 제안하지 마세요. 필요한 경우 별도 승인 요청으로 분리합니다.
6) 새/수정된 기능에 백엔드 테스트, Flutter 테스트 또는 명확한 수동 검증 절차를 포함하세요.
7) 실전화 발신, 유료 외부 API 호출, 실제 데이터 삭제, 프로덕션 배포, OAuth 계정 연결, 결제/약정은 사용자 명시 승인 없이 실행하지 마세요. 기본은 시뮬레이터/모의 응답입니다.
8) 비밀키/전화번호/토큰/개인정보를 채팅·로그·커밋에 출력하지 마세요. .env는 수정·커밋하지 않고 .env.example만 업데이트하세요.
9) 실제 프로젝트 패키지에 존재하는 명령만 실행하세요. 없으면 필요한 의존성/스크립트를 설명하세요.
10) 각 작업이 끝나면 아래 완료 보고 템플릿으로 보고하세요. 사용자 검토 후 다음 단계로 이동합니다.

[필수 최종 출력]
- 저장소 확인 결과 및 문서 대비 차이
- 구현한 파일별 변경 요약 및 핵심 설계 선택
- API/type 변경과 backward compatibility 평가
- 실행한 테스트/빌드 명령, 성공/실패 결과 (실행하지 못한 검증은 명확히 표시)
- 보안 및 회귀 체크 결과
- 남은 위험/환경 의존성/추가 의사결정
- git diff 요약 및 다음 1단계 제안

먼저 **Step 0: 코드베이스 조사 및 안전한 구현 계획**만 진행하세요. Step 0에서는 제품 기능 코드를 변경하지 마세요. 결과를 받은 후 다음 지시를 기다리세요.
```

## 2. Step 0 — 코드베이스 감사 / 검증 기준선

```text
Step 0만 수행하세요. 요구사항:
- Flutter 및 Fastify/TypeScript의 실제 파일 트리, 엔트리, 의존성, lint/test/build 명령 파악.
- 기존 ApprovalRequest, CallSession.requestApproval, CallService.respondToApproval, RealtimeBridge tool-result 경로, HTTP approval route, ApprovalCard, Flutter DTO/Repository를 모두 찾아 실제 코드 위치와 시그니처 보고.
- TaskStore 원자 저장, pending 승인 메모리 Promise, timeout, cancel/restart 처리, WS version 병합을 점검.
- 시뮬레이터 시나리오로 생성→계획 승인→통화→승인/거절→요약 흐름을 테스트. 실KAT 통화는 하지 마세요.
- 현재 기능/미구현/의심 위험 목록과 Step A1의 정확한 변경 계획을 작성.
- 문서에 가정이 있거나 파일명 불일치면 목록화. 제품 코드 수정 없이 docs/IMPLEMENTATION_BASELINE.md에 결과 기록 (docs 디렉터리 없으면 생성 가능).

Acceptance: 기존 테스트/빌드 수행 결과, 코드 경로 및 A1 수정 대상이 확인되어야 함.
```

## 3. Step A1 — 승인 코멘트 (첫 구현 작업)

```text
이제 Step A1: '승인/거절 + 선택적 코멘트'만 구현하세요.

필수 요구사항:
1. 기존 POST /v1/tasks/:id/approvals/:approvalId는 유지. body decision='approve'|'reject'는 동일하고 optional comment:string만 추가.
2. comment는 trim, 최대 500자(Unicode 단위는 프로젝트 기존 규칙에 맞게 문서화), 비문자 입력 400. 빈 문자열은 미입력으로 처리. 승인/거절 둘 다 코멘트 허용.
3. ApprovalRequest(기존 필드 유지)에 userComment와 결정 시각 등 필요한 상태를 추가하고 TaskStore 스냅샷/기록에 반영. 이전 저장 데이터도 안전하게 로드.
4. CallSession.requestApproval 반환이 boolean이라면 {approved,comment?,reason?}로 점진 변경하고 simulatedProvider, katProvider, realtimeBridge 및 타입 호출부를 모두 업데이트. 실제 시그니처에 따라 최소 범위 변경.
5. Realtime tool output에 approved, user_comment, instruction을 포함하고, 승인 코멘트는 별도 사용자 지시로 전달. 시스템 정책/민감정보 금지/금전·계약 승인 범위를 덮어쓰지 못하게 하세요. 승인됐어도 조건이 바뀌면 재승인을 요청해야 합니다.
6. 승인 상태는 pending일 때만 확정, timeout 기본 거절. 중복 제출/만료/취소된 승인은 409 approval_closed. 동시에 처리되더라도 resolve/외부 실행 한 번만. 작업 id와 approval id가 실제 연결되었는지 검증.
7. Flutter ApprovalCard에 다중줄 optional 입력, 길이 카운트, 승인/거절 버튼, 로딩/만료/서버오류 UI 추가. 결과 기록에 코멘트 표시. 기존 버튼을 코멘트 없이 사용해도 종전과 같은 흐름.
8. http DTO와 Flutter fromJson 파서 수정 및 하위 호환성 유지. WebSocket task.version 기준 병합 변경 금지.
9. 실 KAT 전화를 걸지 않고 시뮬레이터 및 unit/widget/integration 테스트로 검증.

테스트 매트릭스:
- approve+empty, approve+comment, reject+empty, reject+comment
- 500자 경계/초과, 비문자/comment만 payload, Unicode 입력
- expired while typing, 2개 중복 승인, 취소/종료와 승인 race, 재연결 후 상태
- API 409와 400, 구 저장 데이터 로딩
- Realtime tool output 및 시뮬레이터에서 comment 전달 확인
- 민감정보/결제 조건이 추가되어도 서버 정책을 우회하지 않음

완료 조건:
- 회귀 테스트 통과, 기존 승인 API body가 그대로 동작, 실제 발신 없음.
- 변경 파일/테스트 실행 결과/잔여 위험 보고 후 대기.
```

## 4. Step A2 — 최근 상대·재사용 템플릿

```text
Step A2만 구현하세요. 이전 단계 merge/상태를 검증 후 진행하세요.
- 최근 통화 상대와 사용자가 저장한 템플릿을 Flutter feature 단위로 구현.
- 처음에는 비민감 데이터 최소 저장. 카드번호/비밀번호/인증번호/승인 결정 재사용 금지.
- 템플릿 선택 시 새 CallTask 생성, 이전 통화의 계획 승인 상태를 복제하지 말 것.
- 저장/수정/삭제/빈 목록/저장 실패/중복 번호 등 UX.
- 서버 API 추가가 꼭 필요하지 않다면 기존 API를 재사용하고 그 이유를 보고.
- 위젯 및 모델/저장소 테스트, 사용자 데이터 유출 없는 검증.
완료 후 보고하고 대기.
```

## 5. Step A3 — 푸시 알림

```text
Step A3만 구현하세요. 실사용자 계정/디바이스 식별 방식이 아직 없다면 먼저 위험을 표시하고, 안전한 단일 사용자 PoC 구성 범위로 제한하세요.
- 승인 요청, 통화 완료, 실패 알림: FCM/APNs adapter 및 등록/해제/갱신 흐름.
- 서버 이벤트 버스 이벤트와 알림 처리 분리. 반복/실패 전송으로 승인 상태를 바꾸지 않음.
- 승인 push 탭→앱 이동→서버 최신 task GET→pending이면 승인 카드 노출. 푸시 내용만 믿고 승인 금지.
- 타임아웃 시 알림이 뒤늦게 도착해도 승인 불가.
- 알림 본문 전화번호/개인정보 최소화, 민감정보 기록 금지.
- 알림 권한 거부, 백그라운드, 포그라운드, 토큰 갱신, 중복/지연/미수신 테스트.
- Firebase 설정/배포 인증서 등 외부 콘솔 작업은 필요 절차만 기록하고 임의 수행하지 마세요.
완료 후 보고하고 대기.
```

## 6. Step A4 — 연락처/음성 입력

```text
Step A4만 구현하세요.
- 연락처 권한 및 OS 연락처 선택 UI: 선택한 번호만 call form으로 가져오기, 전체 주소록 서버 전송 금지.
- 음성 STT로 goal/context 초안 작성하되 수정/취소 UI 제공, 통화 중 Realtime 음성과 분리.
- iOS/Android 권한 거부, 미지원 기기, STT 오류, 번호 정규화 오류를 처리.
- 패키지는 현재 Flutter 버전 호환성과 유지보수 상태를 조사해 선정하고 근거 기록.
- 테스트 및 개인정보 고지 변경 내용 포함.
완료 후 보고하고 대기.
```

## 7. Step A5 — 후속 액션 / 신뢰 UX

```text
Step A5만 구현하세요.
- 완료/부분 완료/실패 결과 카드에서 재통화, 복사, 공유, 캘린더 일정 초안을 지원.
- 외부 서비스 직접 쓰기는 하지 않고 OS 캘린더 작성 화면/공유 UI에 내용을 채운 후 사용자가 최종 확정.
- 재통화는 새 task/새 계획 검토.
- AI 대리 통화 안내, 자막 정보 보관, 권한 관련 설명, 승인 기록 표시 점검.
- 자막/결과의 PII가 공유 시 과다 노출되지 않도록 사용자 확인.
완료 후 보고하고 대기.
```

## 8. Step B0 — 계정·Postgres (별도 승인 후)

```text
Phase B0 설계를 먼저 제출하고 승인받은 뒤 구현하세요.
- OIDC 인증 및 userId owner scoping, 기존 API_TOKEN 마이그레이션/호환 정책.
- TaskStore 인터페이스를 보존한 Postgres 구현, schema migration/backfill/rollback.
- 모든 REST/WS/task/approval에 소유권 검증. 두 계정 사이 데이터 접근 불가 테스트 필수.
- 토큰/시크릿 암호화·로그 마스킹, 계정 삭제/데이터 삭제 정책.
- Zero-downtime 여부, 운영 전환/백업/장애 시 복구 절차 작성.
- 기존 JSON 데이터 이관 전 백업과 사용자 확인. 실제 이관은 명시 승인 후.
완료 후 보고하고 대기.
```

## 9. Step B1 — 커넥터 + Calendar (B0 이후)

```text
Step B1만 구현하세요.
- 공통 ConnectorAdapter/registry, capability(read/write), OAuth state/PKCE, 토큰 암호화·갱신·해제.
- 1차 Google Calendar: 읽기/일정 초안, 쓰기 전 별도 ApprovalGate 및 대상/시각/내용이 고정된 승인 확인.
- 승인 없이 외부 write 실행 불가. 실패/retry 중복 일정 생성 방지.
- 계정별 접근제어, 권한 회수/만료/403 에러, mock connector 통합 테스트.
- 프로덕션 OAuth 연결/실제 일정 생성은 명시 승인 필요.
완료 후 보고하고 대기.
```

## 10. Step B2 및 Phase C — 먼저 설계 리뷰

```text
제품 로드맵의 예약 통화/ARS/국내 업체 검색/AgentTask/채팅/음성/OCR/수신 기능은 즉시 구현하지 마세요.
다음 내용을 먼저 RFC로 제출하세요:
- 기능별 실제 KAT/커넥터 API 지원 확인 및 제약
- AgentTask와 기존 CallTask 공존/마이그레이션 설계
- 작업 재시도, 중복 방지, approval boundary, cancel/compensation
- 저장소/권한/개인정보 처리 영향, 비기능 테스트, 비용과 단계별 롤백
- 수신 대행은 통신사 계약/번호 귀속/법적 고지 확인 항목
리뷰 승인된 하나의 기능만 별도 PR/단계로 구현하세요.
```

## 11. 매 단계 완료 보고 템플릿

```markdown
# CallMate Step [ID] 완료 보고
## 1. 구현 범위 및 제외 범위
## 2. 확인한 실제 레포 구조/문서 불일치
## 3. 파일별 변경 목록
## 4. API/도메인/상태머신 변경 및 호환성
## 5. 테스트 실행 결과 (명령 / pass / fail / 미실행 이유)
## 6. 보안, 개인정보, 외부 부작용 점검
## 7. 실제 발신 여부 (기본값: 실행 안 함)
## 8. 남은 위험/수동 작업/환경 설정
## 9. git diff 요약과 롤백 방법
## 10. 다음 Step 제안 (자동 착수 금지)
```

## 12. Pull Request 체크리스트

- [ ] 요구사항 외 변경 최소화
- [ ] 모듈 의존 방향 유지
- [ ] API backward compatibility
- [ ] snapshot/version ordering 유지
- [ ] simulator regression 통과
- [ ] 승인 timeout/reject/duplicate 안전
- [ ] 개인정보/토큰 로그 점검
- [ ] 테스트 증거 및 미검증 사항 표기
- [ ] 신규 환경변수 `.env.example` 기록
- [ ] 실제 KAT 발신/운영 배포/결제 없음 (명시 승인 시 예외)
- [ ] 기존 아키텍처 및 CHANGELOG 업데이트
