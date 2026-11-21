# 에픽 EPIC-ASSISTANT-UX — 개인 비서다운 첫 묶음

작성: 2026-11-21, jason (manager-spec). 기준 커밋 `c664596`. 상태: 계획 단계(네 SPEC 모두 `draft`, 버전 0.2.0 — plan-audit iteration 1 반영, 재감사 대기).

## 1. 목표

앱을 정돈되고 친근하며 쉽게 쓰는 개인 비서로 만든다. 사용자는 최소한만 입력·선택하고, 에이전트가 할 수 있는 일은 스스로 한다. 돈·약정·잘못된 번호로 거는 실제 통화처럼 되돌리기 어려운 일은 승인 뒤에 둔다.

소유자가 이미 정한 사항(이 에픽 전체에 적용):

1. 범위는 "한 줄 부탁 + 승인 코멘트 + 통화 후 행동 카드". 푸시 알림, 연락처 선택, 음성 입력, 커넥터, 수신 대행, 장소 검색 API, 계정·동기화는 이 묶음에 없다(§6 백로그).
2. 번호는 사용자가 쓴 글과 저장된 통화 기록에서만 찾는다. 없으면 번호 칸 하나로 한 번만 묻는다.
3. 계획 카드가 나오면 [이대로 시작]을 한 번 누르고 통화가 시작된다. 통화 중 승인은 그대로이며, 승인 제한 시간 만료 = 거절이다.

## 2. 순서와 의존 관계

엄격한 직렬 순서. 각 SPEC은 혼자 구현·검증할 수 있고, 앞 SPEC이 `completed`가 된 뒤 시작한다(`depends_on`).

```
SPEC-APPROVAL-001 ──► SPEC-INTAKE-001 ──► SPEC-FOLLOWUP-001 ──► SPEC-UX-001
(승인 코멘트 보강)     (한 줄 부탁·계획 카드)  (통화 후 행동·신뢰 안내)   (디자인 시스템)
```

| 순서 | SPEC | Tier | `depends_on` | REQ | AC | 변경 파일(계획) | 권장 하네스 |
|------|------|------|--------------|-----|----|----------------|-------------|
| 1 | SPEC-APPROVAL-001 | M | (없음) | 16 | 15 | 15 | standard |
| 2 | SPEC-INTAKE-001 | L | SPEC-APPROVAL-001 | 24 | 24 | 26 | thorough |
| 3 | SPEC-FOLLOWUP-001 | M | SPEC-INTAKE-001 | 16 | 16 | 21 | standard |
| 4 | SPEC-UX-001 | M | SPEC-FOLLOWUP-001 | 14 | 15 | 19 | standard |
| | 합계 | | | 70 | 70 | | |

순서 이유:

- **APPROVAL 먼저**: 승인 코멘트 뼈대는 이미 있고(Step A1, `docs/IMPLEMENTATION_BASELINE.md` §9), 남은 빈틈(실통화 안내 기록, 민감정보 마스킹, 빠른 답)이 작고 위험한 순간(통화 중 결정)을 다룬다. 뒤 SPEC들이 `callService.ts`·`prompts.ts`·테스트 대역을 함께 고치므로 가장 작은 변경을 먼저 넣는다.
- **INTAKE 다음**: 새 홈·계획 카드·자동 시작이 이 에픽의 중심이며, FOLLOWUP의 "다시 걸기"가 계획 카드를 재사용한다.
- **FOLLOWUP 다음**: 계획 카드(재통화)와 [이대로 시작](첫 통화 전 신뢰 안내)에 기댄다.
- **UX 마지막**(SPEC-UX-001 OD-1 DEFAULT, 근거 `SPEC-UX-001/plan.md` §A.0): 계획 카드·빠른 답·후속 행동이 실제로 있는 상태에서 한 번에 다듬고, 접근성 검사를 완성된 네 화면 전체에 건다. 앞 세 SPEC은 새 색·간격을 만들지 않고 기존 테마와 공용 위젯만 쓰며, 테스트는 문구·`Key`·의미로만 요소를 찾는다. 그래서 UX 재디자인이 앞 SPEC 테스트를 깨뜨리지 않는다.

**`depends_on`에 v0.2.0 SPEC을 넣지 않은 이유**: SPEC-STORE·LIFECYCLE·POLICY·OUTCOME·ARCH-001은 현재 `status: implemented`(`completed` 아님)다. run-phase의 `depends_on` 사전 검사는 `completed`만 충족으로 보므로, 이들을 넣으면 코드가 이미 들어가 있는데도 막힌다. 그래서 `related_specs`로만 연결했다. 이들의 동작(번호 정책, 결과 `unverified`, 종료 순서, 저장소 전제, 계층 규칙)은 각 SPEC 본문에서 그대로 지킨다.

이 우회는 v0.2.0 SPEC의 생명주기 누락을 덮는다. `spec_audit`은 다섯 SPEC 모두를 `SyncStatusDrift`(동기화 기록 §E.4와 `sync_commit_sha`가 있는데 `status: implemented`)로 본다(plan-audit iteration 1 §0). 별도 정리 작업으로 각 SPEC에 `moai spec close <ID> --backfill-only`를 검토할 것을 권한다(이 에픽 범위 밖, 이 SPEC 작성자는 실행하지 않음). 그 뒤에는 이들을 `depends_on`에 넣어도 사전 검사를 통과한다.

## 3. SPEC 요약

| SPEC | 사용자에게 달라지는 것 | 서버 변경 | 앱 변경 |
|------|----------------------|----------|--------|
| APPROVAL-001 | 승인 카드에 빠른 답 칩 3개, 한 줄 입력칸, 민감정보 안내. 실통화 기록에도 "사용자 안내:" 줄 | 코멘트 정제·마스킹(도메인 함수), 서비스가 안내 줄 기록(시뮬레이션 중복 제거), 통화 지시문 규칙 7 | `approval_card.dart`, 코드 포인트 기준 글자 수 |
| INTAKE-001 | 홈 입력칸 하나 → 계획 카드 → [이대로 시작] 한 번. 최근 통화한 곳 제안. 번호 없으면 한 번만 묻기 | `POST /v1/intake`(작업을 만들지 않음), 번호 후보 규칙, 기록 조회, brain 의뢰 해석(LLM + 결정적 대체), `autoStart`·`autoStartBlocked` | 새 홈, 새 계획 카드 화면, 최근 상대 계산, 막힘 안내 |
| FOLLOWUP-001 | 결과 화면에 다시 걸기·요약 복사·공유·캘린더에 추가. 첫 통화 전 신뢰 안내, 설정·통화 중 고지 | 결과의 선택 필드 `appointment`(확정된 LLM 결과만) | 후속 행동, 공유 문구, `.ics`, 신뢰 안내, `share_plus` 1개 |
| UX-001 | 정돈된 색·글자·간격, 같은 모양의 카드, 쉬운 상태 문구, 큰 글자·움직임 줄이기 대응 | 없음 | 토큰·분위기·공용 카드, 네 화면 재정리, 접근성 테스트 |

## 4. 공통 결정 (네 SPEC 모두 지킴)

| # | 결정 | 근거·출처 |
|---|------|----------|
| D1 | 서버와 앱은 SPEC마다 같은 릴리스로 배포한다. 섞인 버전에서도 안전하게 동작하도록 각 SPEC에 호환 요구를 둔다 | SPEC-OUTCOME-001 OD-1과 같은 원칙. APPROVAL REQ-016, INTAKE REQ-022·024, FOLLOWUP REQ-016 |
| D2 | 번호 판정은 `checkTargetNumber`(`server/src/domain/phone.ts`) 하나. 의뢰 해석이 제안하는 번호, 기록에서 찾은 번호, 자동 시작 직전 번호 모두 이 함수를 지난다. 서버는 번호를 지어내지 않고 LLM에 번호를 보내지 않는다 | SPEC-POLICY-001 REQ-005·007, INTAKE REQ-004~007·014 |
| D3 | 자동 시작은 계획 승인과 같은 함수·같은 순서(503 → 404 → 409 → 400 → 429)를 쓴다. 기동 복구는 어떤 작업도 발신하지 않는다 | SPEC-LIFECYCLE-001 REQ-001 (d), INTAKE REQ-014·016 |
| D4 | 통화 중 위험한 결정은 항상 승인. 만료 = 거절. 코멘트는 정책(카드번호·비밀번호 금지, 승인 범위 초과 약정 금지)을 넘지 못한다 | APPROVAL REQ-007~009 |
| D5 | 검증되지 않은 결과(`unverified`, `source: heuristic`)는 확정처럼 보이지 않는다. 캘린더 초안을 내주지 않고, 공유 문구에 "결과 미확인"과 안내 줄이 들어간다 | SPEC-OUTCOME-001, FOLLOWUP REQ-004·009·010 |
| D6 | 로그에는 요청 글·전화번호·코멘트·대화 내용을 넣지 않는다. LLM 실패 로그는 `op`·`reason`·HTTP 상태만 | SPEC-OUTCOME-001 REQ-009, APPROVAL REQ-004, INTAKE REQ-003·009 |
| D7 | 새 오류 코드 없음. 자동 시작 막힘은 기존 `ServiceError` 코드를 `autoStartBlocked`에 담는다(예외: 서비스 밖 오류는 `auto_start_failed`, HTTP 오류 코드가 아니라 작업 필드 값) | INTAKE design.md §5 |
| D8 | 새 런타임 직접 의존성은 앱의 `share_plus` 하나(FOLLOWUP OD-1). 전이 의존성은 run 시작 때 `flutter pub add` 출력으로 기록. 서버 없음 | FOLLOWUP REQ-016 |
| D9 | 계층 규칙(`server/src/architecture.test.ts`)을 그대로 지킨다. 규칙은 `domain/`, LLM은 `brain/`, HTTP는 서비스 호출만 | ARCH-001, 각 SPEC §4 |
| D10 | 저장소는 단일 JSON 파일·단일 인스턴스 그대로. 새 저장소를 만들지 않는다. 최근 상대는 저장된 작업에서 계산한다 | `docs/OPERATIONS.md` "실행 전제", INTAKE §4 |
| D11 | 화면 문구는 한국어 해요체. 기능 SPEC은 기존 테마만 쓰고, 시각 스타일은 UX-001이 정한다. 위젯 테스트는 문구·`Key`·의미로 찾는다 | 각 SPEC §4 |
| D12 | 벤치마크 중 열리지 않은 출처(Towards AI 403, AgenticWire 429)와 다른 제품의 화면은 근거로 쓰지 않는다. Pickle 소개는 경쟁사(Carly)가 쓴 글이다 | 각 research.md 벤치마크 절 |

## 5. Open Decisions 목록 (모두 DEFAULT, 소유자 검토 대기)

| SPEC | ID | 결정 | DEFAULT |
|------|----|------|---------|
| APPROVAL | OD-1 | 민감 숫자열 처리 | 거절 대신 `[민감정보 삭제]`로 마스킹 |
| APPROVAL | OD-2 | 빠른 답 칩 | 3개: "금액이 더 나오면 거절해 주세요" / "다른 날짜·시간도 물어봐 주세요" / "조건을 자세히 듣고 다시 물어봐 주세요" |
| APPROVAL | OD-3 | 기록 안내 줄 접두어 | ko "사용자 안내:", en "User guidance:" |
| APPROVAL | OD-4 | 민감 숫자열 기준 | 13~19자리 숫자(공백·하이픈 하나씩 허용) |
| INTAKE | OD-1 | 자동 시작 위치 | 서버(`autoStart` 필드) |
| INTAKE | OD-2 | 기록 범위 | 상대가 받은 적 있는 작업(`connectedAt`)만 |
| INTAKE | OD-3 | 같은 이름 번호 여럿 | 가장 최근 작업 |
| INTAKE | OD-4 | 추출할 번호 형식 | `0`/`+82` 국내 형식만(대표번호·해외 제외) |
| INTAKE | OD-5 | 홈 제안 | 최근 통화 순 3개 |
| INTAKE | OD-6 | 화면 문구 | spec.md REQ-017~023 문구 |
| INTAKE | OD-7 | 자동 시작 통화의 첫 인사 | AI 고지가 든 템플릿 첫 인사로 고정 |
| FOLLOWUP | OD-1 | 새 의존성 | `share_plus` 추가 |
| FOLLOWUP | OD-2 | 일정 없을 때 캘린더 | 보여 주지 않음 |
| FOLLOWUP | OD-3 | 신뢰 안내 문구 | REQ-013의 여섯 문장(AI 행동은 "정해져 있어요" 지시 수준, OpenAI 글 전송 항목 포함, 법률 검토 전) |
| FOLLOWUP | OD-4 | 공유 문구 내용 | 라벨·상대·시각·요약·알아낸 내용·할 일만 |
| FOLLOWUP | OD-5 | 끝 시각 없는 일정 길이 | 60분 |
| FOLLOWUP | OD-6 | 캘린더 행동 라벨 | "캘린더에 추가", 기기 수동 확인에서 기본 캘린더가 받지 못하거나 확인 못 하면 "캘린더 파일 보내기" |
| UX | OD-1 | 이 SPEC의 순서 | 마지막 |
| UX | OD-2 | 씨앗 색 | `0xFF1F8A70` 유지 |
| UX | OD-3 | 상태 라벨 | 세 개만 변경(계획 세우는 중 / 전화 거는 중 / 결과 정리 중) |
| UX | OD-4 | 글꼴 | 시스템 기본 |

가장 먼저 볼 결정: INTAKE OD-1(서버 자동 시작 — 사용자가 통화 계획 본문을 보지 않고 시작하는 흐름의 핵심), APPROVAL OD-1(마스킹), FOLLOWUP OD-1(새 의존성).

## 6. 이 묶음의 제외 범위와 후속 백로그

아무것도 잃지 않도록 로드맵(`docs/PRODUCT_ROADMAP.md`) 항목을 다음 묶음 후보로 적는다. 순서는 제안이며 확정이 아니다.

| 후보 | 로드맵 | 이 묶음에서 빠진 이유 | 선행 조건·메모 |
|------|--------|----------------------|----------------|
| 푸시 알림(승인 요청·통화 종료·실패) | §4.1 P0, §6 Phase A-2 | FCM/APNs 계정 필요 | 공용 `API_TOKEN` 하나로는 기기별 수신자를 구분할 수 없음(`docs/IMPLEMENTATION_BASELINE.md` 위험 표) → 계정 또는 기기 등록이 먼저. 지금은 앱을 열어 둬야 승인 카드가 뜬다 |
| 연락처 선택 | §4.1 P0, §4.4 | 이 묶음은 글·기록에서만 번호를 찾음(소유자 결정 2) | 선택한 항목만 서버로, 전체 주소록 업로드 금지(§4.4). 계획 카드의 번호 칸 옆에 붙이면 됨 |
| 음성으로 부탁·코멘트 입력 | §4.1 P0, §4.3 P2 | 범위 밖 | 마이크 권한 목적 고지. 홈 입력칸·승인 칸에 붙임 |
| 장소·업체 검색(네이버·카카오 로컬) | §4.2 P1 | 외부 검색 금지(소유자 결정 2) | 검색 결과 번호도 `checkTargetNumber`를 지나야 함(D2) |
| 커넥터(Google Calendar, 메일 등) | §4.2 P1, §7.2 | OAuth·토큰 보관 필요 | FOLLOWUP의 `.ics` 초안을 커넥터 쓰기로 바꿀 수 있음. 쓰기는 항상 승인(§4.2 원칙) |
| 수신 대행 | §4.3 P2 | 범위 밖 | KAT 인바운드 스트림, AI 고지 필수 |
| 계정·기기 간 동기화 | §4.2 P1 | 범위 밖 | 푸시·커넥터의 선행 작업 |
| 대표번호(15xx 등) 자동 추출 | — | 현재 정규화가 `+1588…`로 바꿈(INTAKE research §4) | 번호 정규화 SPEC 먼저(`docs/OPERATIONS.md` 잔여 위험과 함께) |
| 자율성 단계 설정 | 벤치마크(Autonomy Dial) | 이 묶음은 "계획 카드 확인 → 시작" 고정 | 저위험 작업은 바로 걸기 등. 승인 원칙(§8) 유지 |
| 메모리(선호·회원번호) | §4.3 P2 | 범위 밖 | 사용자가 보고 지울 수 있어야 함. "최근 통화한 곳"이 가장 작은 형태 |
| ARS/DTMF, 예약 통화 | §4.2 P1 | 범위 밖 | 제공자 기능 확인 필요 |
| 앱 이름 변경(CallMate → 콜비) | `.moai/project/product.md` | 별도 작업으로 기록됨 | 코드·패키지·문서 일괄 |
| 승인 질문 구조화(금액·대상 필드) | §7.3 `ApprovalGate` | 범위 밖(APPROVAL §6) | 전화·웹·결제 공통 승인으로 일반화할 때 |

## 7. 위험 (에픽 수준)

| 위험 | 대응 |
|------|------|
| 사용자가 통화 계획 본문을 보지 않고 통화가 시작됨(소유자 결정 3) | 상대·번호·목적은 계획 카드에서 확인, 번호 출처 표시, 번호 정책 재검사, 통화 중 승인 유지, 신뢰 안내(INTAKE, FOLLOWUP) |
| 기록에서 잘못된 번호 제안(같은 이름의 다른 곳) | 연결된 작업만, 최신, "지난번 통화한 번호" 표시, 한 번 눌러 수정(INTAKE OD-2·3) |
| AI가 코멘트를 따르지 않음 | 지시문 규칙 + 대화 기록의 사용자 안내 줄로 사후 확인(APPROVAL). 모델 동작 자체는 자동 검증하지 않음 |
| 틀린 일정 초안 | 확정된 LLM 결과만, 범위 검사, 저장 전 확인 문구(FOLLOWUP) |
| SPEC 간 파일 겹침 | 직렬 `depends_on`, 각 plan.md §D.1 겹침 표 |
| Tier 경계 | FOLLOWUP(21개)·UX(19개)는 파일 수가 Tier M 안내치(5~15)를 넘음. 초과분 대부분이 테스트·잠금 파일·토큰 치환이고 REQ/AC 수는 Tier M 상한 안이라 M 유지(각 plan.md §B, plan-audit iteration 1 D23에서 수용). LOC 추정은 검증하지 않음 |
| 확인하지 못한 외부 사실 | Towards AI·AgenticWire 미확인, 경쟁 제품 화면 미확인, `share_plus` API 미확인, Fastify 기본 404 본문은 일반 지식 — 각 research.md에 표시 |

## 8. 문서 위치

- `.moai/specs/SPEC-APPROVAL-001/` — spec, plan, acceptance, research, progress
- `.moai/specs/SPEC-INTAKE-001/` — spec, plan, acceptance, design, research, progress
- `.moai/specs/SPEC-FOLLOWUP-001/` — spec, plan, acceptance, research, progress
- `.moai/specs/SPEC-UX-001/` — spec, plan, acceptance, design(와이어프레임), research, progress
