---
id: SPEC-FOLLOWUP-001
title: "통화가 끝난 뒤 한 번에 — 다시 걸기·복사·공유·캘린더 초안과 신뢰 안내"
version: "0.3.0"
status: implemented
created: 2026-11-21
updated: 2026-11-27
author: jason
priority: Medium
phase: "v0.3.0 target"
module: "server/src/brain, server/src/domain, app/lib/features/calls, app/lib/features/settings"
lifecycle: spec-anchored
tags: "follow-up, share, calendar, ics, trust, ai-disclosure, outcome, flutter, tdd, assistant-ux"
tier: M
depends_on: [SPEC-INTAKE-001]
related_specs: [SPEC-OUTCOME-001, SPEC-APPROVAL-001]
---

# SPEC-FOLLOWUP-001: 통화가 끝난 뒤 한 번에 — 다시 걸기·복사·공유·캘린더 초안과 신뢰 안내

## HISTORY

| 버전 | 날짜 | 작성 | 변경 |
|------|------|------|------|
| 0.1.0 | 2026-11-21 | jason (manager-spec) | 최초 작성 (draft). 에픽 EPIC-ASSISTANT-UX의 세 번째 SPEC |
| 0.2.0 | 2026-11-21 | jason (manager-spec) | plan-audit iteration 1 반영: D13 공유 문구의 표시 시간대를 인자로(기본 Asia/Seoul +09:00), D14 신뢰 문구 (1)(2)(5)와 통화 중 한 줄을 지시 수준 문장으로 바꾸고 OpenAI 글 전송 항목 (6) 추가(다섯 → 여섯), D15 파일 수 21개로 정정, D16 캘린더 공유 라벨 OD-6과 기기 수동 확인, D17 "직접 의존성"과 해결 버전 기록. REQ/AC 번호·개수 불변 |
| 0.3.0 | 2026-11-21 | jason (manager-spec) | plan-audit iteration 2 반영: A4 신뢰 문구 (6)에 내 이름·알려줘도 되는 정보·회신 번호 전송 추가와 근거 행, A5 캘린더 라벨 기본값을 "캘린더 파일 보내기"로 뒤집고 기기 확인 뒤 "캘린더에 추가"로 올림, A6 양식 화면의 보장형 안내 문단을 지시 수준 문구로(`new_call_screen.dart` 계획 파일 추가, 합계 22개), A7 줄 번호 정정, A8 첫 통화 두 번 확인을 잔여 위험에. REQ/AC 번호·개수 불변 |

## 1. 배경과 목적

통화가 끝나면 결과 화면은 요약(`OutcomeCard`)과 "다시 걸기" 버튼 하나를 보여 준다(`app/lib/features/calls/presentation/call_detail_screen.dart:202-213, 245-253`). 예약이 잡혔어도 일정을 옮기려면 사용자가 직접 캘린더 앱을 열어 입력해야 하고, 결과를 가족에게 알리려면 화면을 옮겨 적어야 한다. 로드맵 §1.2는 "후속 행동: 요약만 보여 줌 — 일이 앱 밖에서 끊김", §4.1은 P0 "통화 후 액션(캘린더 초안, 메모 복사, 재통화, 공유)"과 "신뢰 UI(AI 고지, 녹음·자막 안내)"를 든다. 근거: `research.md`.

신뢰 안내도 흩어져 있다. 양식 화면 아래 한 문단(`new_call_screen.dart:162-182`)뿐이며, SPEC-INTAKE-001 뒤에는 기본 흐름이 그 양식을 거치지 않는다. 통화 중 화면과 설정에는 AI 고지나 무엇이 기록되는지에 대한 설명이 없다.

목적은 통화가 끝난 화면에서 결과에 맞는 다음 행동을 한 번의 탭으로 하게 하고(다시 걸기, 요약 복사, 공유, 캘린더 초안), 사용자가 첫 통화 전과 통화 중에 AI가 무엇을 밝히고 무엇이 기록되는지 알게 하는 것이다. 검증되지 않은 결과(SPEC-OUTCOME-001의 `unverified`)는 확정된 일정처럼 캘린더 초안을 내주지 않는다. OAuth 커넥터 없이, 기기의 공유 기능으로만 캘린더 앱에 넘긴다.

## 2. 범위

- 서버: 결과(`CallOutcome`)에 선택 필드 `appointment`를 더하고, LLM 요약이 확인된 일정만 구조화하게 한다. 휴리스틱 결과에는 붙지 않는다.
- 앱: 결과 화면의 후속 행동, 공유 문구와 `.ics` 생성(순수 함수), 재통화를 SPEC-INTAKE-001의 계획 카드로 연결, 신뢰 안내(첫 통화 전 1회, 설정, 통화 중 한 줄).
- 새 의존성: 앱에 `share_plus` 하나(OD-1 DEFAULT). 서버는 없음.
- 시각 디자인은 SPEC-UX-001이 정한다. 배포는 서버·앱 같은 릴리스(에픽 공통 결정).

## 3. 요구사항 (GEARS)

### 3.1 확인된 일정 (서버)

- **REQ-001** [Ubiquitous] `CallOutcome`은 선택 필드 `appointment?: { title: string; startsAt: string; endsAt?: string }`를 가질 수 있어야 하며(**shall**), `startsAt`·`endsAt`은 시간대(`Z` 또는 `±hh:mm`)를 명시한 ISO 8601 일시다. 이 필드가 없는 저장된 결과는 지금처럼 유효하다.
- **REQ-002** [Event-driven] **When** LLM 요약이 성공하고 응답에 `appointment`가 있으면, 서버는 다음을 모두 만족할 때만 그것을 결과에 남겨야 한다(**shall**): (a) `result`가 `success` 또는 `partial`, (b) `startsAt`이 시간대를 명시한 ISO 일시로 해석됨, (c) 기준 시각(작업의 `endedAt`, 없으면 요약 시각)으로부터 `startsAt`이 −24시간 ~ +366일 안, (d) `endsAt`이 없거나 `startsAt` 뒤이고 24시간 이내, (e) `title`은 앞뒤 공백을 지우고 80자(코드 포인트)로 자르며, 비면 `"<targetName> 일정"`. 하나라도 어기면 `appointment`만 빼고 나머지 결과(`result`, `source: "llm"`, 요약 등)는 그대로 둔다. 형식이 어긋난 `appointment`가 결과 전체의 대체(휴리스틱 전환)를 일으키지 않으며, 이 일로 로그를 남기지 않는다.
- **REQ-003** [Ubiquitous] 요약 요청은 기준 시각(ISO)과 시간대 `Asia/Seoul`을 함께 보내야 하고(**shall**), 요약 프롬프트는 대화 기록에서 날짜와 시각이 구체적으로 확정된 약속(예약·방문·회신 일정)이 있을 때만 `appointment`를 채우고 아니면 `null`로 두라고 지시한다. LLM 응답의 `result` 허용 값(`success`/`partial`/`failed`)은 바뀌지 않는다(SPEC-OUTCOME-001 REQ-010).
- **REQ-004** [Unwanted] `HeuristicBrain`이 만든 결과(`source: "heuristic"`, LLM 실패 대체 포함)에는 `appointment`가 있어서는 안 된다(**shall not**).

### 3.2 결과 화면의 후속 행동 (앱)

- **REQ-005** [Ubiquitous] 앱의 `CallOutcome.fromJson`은 `appointment`를 해석해야 하며(**shall**), 없거나 `startsAt`을 해석할 수 없거나 형태가 어긋나면 `null`로 두고 예외를 내지 않는다.
- **REQ-006** [State-driven] **While** 작업이 끝난 상태이면, 결과 화면은 후속 행동 줄을 보여 줘야 한다(**shall**): 항상 "다시 걸기", 결과(`outcome`)가 있으면 "요약 복사"와 "공유", REQ-010 조건을 만족하면 "캘린더 파일 보내기". 취소된 작업이나 결과가 없는 실패 작업에는 "다시 걸기"만 있다.
- **REQ-007** [Event-driven] **When** 사용자가 "다시 걸기"를 누르면, 앱은 그 작업의 상대 이름·번호·목적·알려줄 정보·언어로 채운 계획 카드(SPEC-INTAKE-001 REQ-019)를 열어야 하며(**shall**), 번호 출처는 "지난번과 같은 번호"로 보이고 의뢰 해석 API와 LLM은 부르지 않는다. 계획 카드의 [이대로 시작]은 SPEC-INTAKE-001 REQ-021과 같이 동작한다.
- **REQ-008** [Event-driven] **When** 사용자가 "요약 복사"를 누르면 앱은 REQ-009의 문구를 클립보드에 넣고 "요약을 복사했어요"를 알려야 하며(**shall**), "공유"를 누르면 같은 문구로 기기의 공유 시트를 연다. 공유를 쓸 수 없거나 실패하면 문구를 클립보드에 넣고 "공유할 수 없어 복사했어요"를 알린다.
- **REQ-009** [Ubiquitous] 공유 문구는 다음 순서로 만들어져야 한다(**shall**): 첫 줄 `[<결과 라벨>] <상대 이름> 통화 결과`, 둘째 줄 통화 끝난 시각(`y년 M월 d일 a h:mm`, 한국어), 빈 줄, 요약, (있으면) 빈 줄 + `알아낸 내용` + `• ` 항목들, (있으면) 빈 줄 + `해야 할 일` + `• ` 항목들. 결과가 `unverified`이면 요약 바로 다음 줄에 `※ 자동 요약이라 목표를 이뤘는지 확인하지 못했어요.`를 넣는다. 문구에는 전화번호, 대화 기록, 승인 코멘트, 요청자 이름을 넣지 않는다. 시각은 문구 생성 함수가 인자로 받은 표시 시간대(UTC 오프셋)로 바꿔 쓰며, 앱은 Asia/Seoul(+09:00, 일광 절약 시간 없음)을 넘긴다. 기기 시간대에 따라 결과가 달라지지 않는다.

### 3.3 캘린더 초안 (앱)

- **REQ-010** [State-driven] **While** 결과의 `source`가 `llm`이고 `result`가 `success` 또는 `partial`이며 `appointment`가 있으면 결과 화면은 "캘린더 파일 보내기"를 보여 주고(**shall**), 그 밖에는(`unverified`, `failed`, `source`가 `heuristic`·`unknown`, `appointment` 없음) 보여 주지 않는다(OD-2 DEFAULT).
- **REQ-011** [Ubiquitous] 캘린더 초안은 RFC 5545 `.ics` 문서여야 한다(**shall**): `VCALENDAR`(VERSION 2.0, PRODID, METHOD PUBLISH) 안에 `VEVENT` 하나, CRLF 줄 끝, 75옥텟을 넘는 줄은 접기(UTF-8 문자를 쪼개지 않음), TEXT 값의 `\`·`;`·`,`·줄바꿈 이스케이프. `UID`는 `<작업 ID>-appointment@callmate.local`, `DTSTAMP`는 생성 시각(UTC), `DTSTART`·`DTEND`는 UTC 기본 형식(`yyyyMMddTHHmmssZ`), `DTEND`는 `endsAt`이 없으면 `startsAt` + 60분(OD-5), `SUMMARY`는 `appointment.title`(비어 있으면 `<상대 이름> 일정`), `DESCRIPTION`은 요약 + 빈 줄 + `AI 비서가 통화에서 확인한 내용으로 만든 초안이에요. 저장하기 전에 확인해 주세요.`. 참석자·주최자·전화번호는 넣지 않는다.
- **REQ-012** [Event-driven] **When** 사용자가 "캘린더 파일 보내기"를 누르면, 앱은 `.ics`를 `appointment.ics`(`text/calendar`) 파일로 공유 시트에 넘겨야 하며(**shall**), 실패하면 "캘린더 초안을 열 수 없어요"를 알린다.

### 3.4 신뢰 안내 (앱)

- **REQ-013** [Ubiquitous] 신뢰 안내 문구는 다음 여섯 항목이어야 하며(**shall**)(OD-3 DEFAULT), 각 항목은 현재 코드로 사실이어야 한다(근거 `research.md` §4). AI의 행동에 관한 항목((1)(2)(5))은 결과를 보장하는 말이 아니라 AI에게 준 지시를 밝히는 말로 쓴다 — 근거가 지시문 문자열이고 모델 행동은 자동으로 검증하지 않기 때문이다: (1) "AI 비서는 통화를 시작할 때 AI라고 먼저 밝히도록 정해져 있어요." (2) "결제·약정처럼 중요한 결정은 통화 중에 먼저 물어보도록 정해져 있어요." (3) "대화 내용은 글로 기록되어 서버에 저장돼요. 끝난 통화는 상세 화면에서 지울 수 있어요." (4) "통화 음성은 이 앱의 서버에 저장하지 않아요. 실제 통화에서는 음성이 통신 서비스(KAT)와 OpenAI를 거쳐 처리돼요." (5) "카드번호·비밀번호 같은 정보는 상대에게 말하지 않도록 정해져 있어요." (6) "서버에 OpenAI가 연결되어 있으면, 부탁 정리·통화 계획·결과 요약을 위해 부탁 내용, 내 이름, 상대에게 알려도 된다고 한 정보, 승인 코멘트, 대화 글이 OpenAI로 전송돼요. 실제 통화에서는 회신 번호도 통화 지시문에 담겨 OpenAI로 전송돼요."
- **REQ-014** [Event-driven] **When** 사용자가 처음으로 통화를 시작하려 할 때(계획 카드의 [이대로 시작] 또는 상세 화면의 "이대로 전화 걸기") 안내를 확인한 기록이 없으면, 앱은 REQ-013의 안내를 한 번 보여 주고 [확인했어요]를 누른 뒤에만 그 요청을 보내야 한다(**shall**). 확인 기록은 기기에 저장되어 다시 보이지 않는다. 안내를 닫으면(뒤로·바깥 누름) 요청을 보내지 않고 화면에 남는다.
- **REQ-015** [Ubiquitous] 설정 화면에는 "AI 비서와 기록" 묶음으로 REQ-013의 여섯 항목이 항상 보여야 하고(**shall**), 통화 상세 화면은 통화가 진행 중(`dialing`/`ringing`/`inProgress`)인 동안 "AI 비서는 AI임을 밝히도록 정해져 있어요 · 대화는 글로 기록돼요" 한 줄을 보여 준다. 기존 양식 화면의 안내 문단(`new_call_screen.dart:175-176`, "…AI임을 밝혀요 … 꼭 먼저 물어봐요 … 절대 말하지 않아요")도 REQ-013 (1)(2)(5)와 같은 지시 수준 문장(같은 문구 상수)으로 바꾼다.

### 3.5 호환과 회귀

- **REQ-016** [Ubiquitous] 기존 서버·앱 테스트는 수정 없이 통과해야 하며(**shall**), 예외는 acceptance.md AC-016에 이름을 적은 의도된 변경(SPEC-INTAKE-001이 만든, 통화 시작 버튼을 누르는 위젯 테스트의 기기 저장값 준비에 안내 확인 기록 한 항목 추가)뿐이다. 새 런타임 직접 의존성은 앱의 `share_plus` 하나뿐이다(서버 없음). `share_plus`가 끌어오는 전이 의존성은 run-phase 첫 단계에서 `flutter pub add share_plus` 결과(해결된 버전, 추가된 전이 패키지)로 기록하고, 그 단계에서 현재 Dart `^3.14.0`·Flutter와 맞는지 확인한다. `appointment`를 모르는 예전 앱은 이 필드를 무시하고, `appointment`가 없는 예전 결과는 새 앱에서 캘린더 행동 없이 보인다.

## 4. 비기능 제약

- 서버 테스트는 가짜 `fetch`만 쓴다(실제 OpenAI 호출 없음). 기준 시각 검사는 가짜 시계나 고정 `endedAt`으로 검증한다.
- 앱의 공유·클립보드 호출은 주입 가능한 한 곳(예: Riverpod 공급자 하나)으로 모아, 위젯 테스트가 기기 기능 없이 호출을 기록하게 한다. `.ics`·공유 문구 생성은 시계를 주입받는 순수 함수다.
- 로그 제약: SPEC-OUTCOME-001 REQ-009를 바꾸지 않는다. `appointment` 검사 실패는 새 로그 분류를 만들지 않는다(REQ-002).
- 공유 문구·캘린더 초안은 기기 밖으로 나가는 데이터이므로 전화번호·대화 기록·코멘트·요청자 이름을 넣지 않는다(REQ-009, REQ-011).
- 앱 문구는 한국어 해요체. 위젯 테스트는 문구·`Key`·의미로 찾는다.

## 5. Open Decisions

| ID | 결정 사항 | 상태 | 결정 내용 |
|----|-----------|------|-----------|
| OD-1 | 공유 시트용 새 의존성 | **DEFAULT (pending owner review)** | `share_plus` 하나를 추가한다. 현재 `pubspec.yaml`에는 공유·URL 실행 패키지가 없고(`research.md` §3), 클립보드만으로는 캘린더 앱에 넘길 수 없다. 버전과 파일 공유 API(`XFile.fromData` 등)는 run-phase에서 패키지 문서로 확인한다. 거부하면 "공유"와 "캘린더 파일 보내기"를 빼고 복사(공유 문구, `.ics` 본문)만 남긴다. |
| OD-2 | 일정이 없을 때의 캘린더 행동 | **DEFAULT (pending owner review)** | 보여 주지 않는다. 사용자가 날짜를 고르게 하면 입력이 늘고, 확인되지 않은 일정을 만들 위험이 있다. |
| OD-3 | 신뢰 안내 문구 | **DEFAULT (pending owner review)** | REQ-013의 여섯 문장. 법률 검토 전 문구다(로드맵 §8 "출시 법률"). 수용 위험: (1)(2)(5)는 모델에게 준 지시이며 모델이 늘 따른다는 보장이 아니다(문장도 "정해져 있어요"로 그 점을 밝힌다). 바꾸려면 문구 상수와 AC-013 기대 문자열만 고친다. 단 바뀐 문구도 코드로 사실이어야 한다. |
| OD-4 | 공유 문구에 넣을 정보 | **DEFAULT (pending owner review)** | 결과 라벨·상대 이름·시각·요약·알아낸 내용·해야 할 일만. 번호·기록·코멘트·요청자 이름 제외. |
| OD-5 | 끝 시각이 없을 때 일정 길이 | **DEFAULT (pending owner review)** | 60분. |
| OD-6 | 캘린더 행동의 라벨 | **DEFAULT (pending owner review)** | 기본 라벨은 "캘린더 파일 보내기"다(run-phase에서는 기기 확인을 할 수 없으므로 하는 일을 그대로 말하는 라벨을 기본으로 둔다). 나중에 기기 수동 확인(사람이 판정, acceptance.md 완료 정의)에서 Android·iOS 기본 캘린더가 공유 시트로 `.ics` 파일을 받아 일정 초안을 여는 것이 확인되면 "캘린더에 추가"로 바꿀 수 있다(올리는 변경). 기본 캘린더가 `text/calendar` 공유를 받는지는 확인하지 못한 가설이다(plan-audit D16). 라벨을 바꾸면 REQ-006·REQ-010·REQ-012와 AC-006·AC-012의 문자열만 고친다. |

## 6. 제외 범위 (Out of Scope)

### Out of Scope — 커넥터와 계정

- Google Calendar 등 OAuth 커넥터, 캘린더에 직접 쓰기, 일정 수정·삭제 동기화는 다루지 않는다. 사용자가 공유 시트에서 고른 앱이 초안을 저장한다.
- 계정·기기 간 동기화, 문자(SMS) 보내기, 메모 앱 연동은 다루지 않는다.

### Out of Scope — 알림과 제안

- 통화 종료·실패 푸시 알림, 일정 전 알림, "할 일 제안"(로드맵 §3.2 익시오식 업무 제안)은 다루지 않는다.

### Out of Scope — 결과 품질과 법률

- LLM이 낸 `appointment`의 정확도 검증은 하지 않는다. 초안 문구와 사용자의 저장 전 확인으로 대신한다.
- 약관·개인정보 처리방침 화면, 녹음 고지의 법률 검토는 다루지 않는다(OD-3 문구는 법률 검토 전 기본값).

### Out of Scope — 시각 디자인

- 결과 화면·안내 시트의 색·간격·움직임은 SPEC-UX-001이 정한다.

## 7. 추적성

| 요구사항 | 인수 기준 |
|----------|-----------|
| REQ-001 | AC-001 |
| REQ-002 | AC-002 |
| REQ-003 | AC-003 |
| REQ-004 | AC-004 |
| REQ-005 | AC-005 |
| REQ-006 | AC-006 |
| REQ-007 | AC-007 |
| REQ-008 | AC-008 |
| REQ-009 | AC-009 |
| REQ-010 | AC-010 |
| REQ-011 | AC-011 |
| REQ-012 | AC-012 |
| REQ-013 | AC-013 |
| REQ-014 | AC-014 |
| REQ-015 | AC-015 |
| REQ-016 | AC-016 |
