---
id: SPEC-ASSIST-001
title: "AI 비서와 받아쓰기 — 몰입형 비서 화면, Orb 상태, 음성 부탁, 통화 중 화면"
version: "0.3.1"
status: completed
created: 2026-11-26
updated: 2026-11-28
author: jason
priority: High
phase: "v0.4.0 target"
module: "app/lib/features/assistant, app/lib/features/calls/presentation, app/lib/shell, packages/kolbi_ui, app/ios, app/android"
lifecycle: spec-anchored
tags: "assistant, voice, dictation, speech-recognition, orb, immersive-dark, live-call, transcript, permissions, accessibility, flutter"
tier: M
depends_on: [SPEC-SHELL-001, SPEC-DESIGN-001]
related_specs: [SPEC-INTAKE-001, SPEC-UX-001, SPEC-SHELL-001, SPEC-PLACE-001, SPEC-SDK-001]
---

# SPEC-ASSIST-001: AI 비서와 받아쓰기 — 몰입형 비서 화면, Orb 상태, 음성 부탁, 통화 중 화면

## HISTORY

| 버전 | 날짜 | 작성 | 변경 |
|------|------|------|------|
| 0.1.0 | 2026-11-26 | jason | 최초 작성 (draft). 에픽 EPIC-KOLBI-APP의 셋째 SPEC. 디자인 검토 반영 결정 06 DR-9·DR-10·DR-11과 에픽 개요 §4.0 요약을 전체 문서로 씀 |
| 0.2.0 | 2026-11-26 | jason | plan-audit 1차(FAIL 0.71, `.moai/reports/plan-audit/SPEC-ASSIST-001-review-1.md`) 반영. 글로 입력 모드를 지금의 입력 상자 전체를 옮긴 것으로 정의(D2·D3), 예시 칩은 채우기만(지금 동작), 개인정보 문구 범위 좁힘(D4), 권한 패키지 허용(D5), 기기 안 인식 실패 시 한 번 대체(D6), 배경 전환 기준(D7), 오류 경로(D9), 업무 실행 화면 대화 기록은 접지 않음(D10), 가짜 저장소 추가 변경 허용(D11), 길게 누르기 삭제(D8) |
| 0.3.0 | 2026-11-26 | jason | plan-audit 2차(FAIL 0.77, `.moai/reports/plan-audit/SPEC-ASSIST-001-review-2.md`) 반영. 비서에서 나가는 화면을 모두 `/assistant` 자식 경로로(N2, SHELL research R1-G3), 통화 중 화면은 셸 밖 경로이고 끝나면 닫기(N3, D11), 음성 인식을 쓸 수 없으면 글로 입력 모드로 시작(N4), 글로 입력 모드에서 숨기는 요소(N1), 승인 알림 처리(N3), AC-016 표 보완(D2, N5), 문서 정리(N6, N7), 권장 수정(D8~D10, D12) |
| 0.3.1 | 2026-11-28 | jason (manager-spec) | sync 단계 주석. 소유자 결정 2026-11-28 두 건을 기록함. (1) `acceptance.md` AC-016 표에 한 행을 더함: `font_overflow_test.dart:73`의 표식을 '직접 입력하기'에서 '전화 대신하기'로 바꿈(원인 REQ-010, 검사 의도 홈·360×640·2배 글자·실제 Pretendard는 그대로). 이에 따라 AC-015의 "수정 없이" 목록에서 `font_overflow_test.dart`는 이 한 행만 바뀐 채 통과하면 됨 (2) OD-2 Android 편차: speech_to_text 7.5.0이 Android에서 기기 안 인식을 쓸 수 없으면 알리지 않고 네트워크 인식기로 넘어가므로(`SpeechToTextPlugin.kt` 620-640), Android는 첫 받아쓰기 전에 안내를 한 번 미리 보이고 `androidSpeechServiceNoticeAcknowledged`(SharedPreferences)에 기록함. iOS는 계획대로 이벤트가 올 때 안내함. plan §B 밖에서 더한 파일 `app/lib/shell/request_intake.dart`와 `shell/navigation.dart`의 `/assistant/settings` 도우미는 `progress.md` §E.2 계획 갱신 표에 있음. 요구사항·인수 기준 수(16 / 16)는 그대로 |

## 1. 배경과 목적

지금 앱에서 부탁은 홈 화면의 입력칸 하나로만 받는다(`app/lib/features/calls/presentation/home_screen.dart:153` `_IntakeBox`, `:188` `Key('home-intake-field')`). 글을 보내면 `/v1/intake`로 초안을 받아 계획 카드를 연다(`home_screen.dart:61`). 음성 입력은 없고 음성 인식 패키지도 없다(`app/pubspec.yaml` dependencies). 통화 중 화면은 밝은 통화 상세 안에 대화 기록(`call_detail_screen.dart:186` `TranscriptView`)과 하단 고정 승인 카드(`:172`)를 함께 둔다.

디자인 검토(`docs/planning/06_DESIGN_DECISIONS.md`, 이하 "06")는 세 핵심 경험 가운데 하나로 "음성 우선 비서"를 정했다. 어느 화면에서든 가운데 비서 버튼으로 AI 비서를 열어 말이나 글로 부탁하고(06 DR-2·DR-11), 비서 화면과 통화 중 화면은 늘 다크로 그리며(06 DR-9), 비서의 상태를 Iridescent AI Orb로 보인다(06 DR-10). SPEC-SHELL-001은 가운데 버튼과 `/assistant` 경로, 밝은 임시 화면만 만들었다(SHELL-001 OD-6).

이 SPEC은 임시 화면을 실제 AI 비서 화면(SCR-A01)으로 바꾸고, 기기 음성 인식으로 받아쓰기(F-REQ-02)를 더하며, 오늘 화면의 입력칸을 비서 화면으로 옮긴다. 통화 중 화면(SCR-T08)을 몰입형 다크로 따로 만든다. 서버와 `/v1`은 바꾸지 않는다. 받아쓴 **글만** 지금처럼 `/v1/intake`로 보낸다.

## 2. 범위

- 앱과 `kolbi_ui`만. 서버와 `/v1`은 바꾸지 않는다.
- 대상 화면: SCR-A01 AI 비서(신규, `/assistant`), SCR-T08 통화 중(신규, `/calls/:id/live`), SCR-H01 오늘(입력칸 이동), SCR-T02 업무 실행(통화 보기 버튼).
- 컴포넌트: CMP-35 AI Orb의 상태 움직임(`kolbi_ui`), 몰입형 다크 테마(`kolbi_ui`), CMP-23 마이크 권한 사전 안내.
- 기기 권한 선언: iOS `Info.plist`(마이크, 음성 인식), Android `AndroidManifest.xml`(녹음, 음성 인식 서비스 `<queries>`).
- 화면 설계: `docs/planning/04_DESIGN_PLAN.md` §17.4(AI 비서), §17.6(통화 중), §17.1(흐름), 06 §3.3(다크 값)·§4.2(문구), 승인된 목업 https://claude.ai/artifact/Cp7JpXX81GSaEKh5SVUQ7U.
- 변경 파일 목록: `plan.md` §B.

## 3. 요구사항 (GEARS)

### 3.1 AI 비서 화면

- **REQ-001** [Ubiquitous] AI 비서 화면(SCR-A01, 셸 밖 최상위 경로 `/assistant`)은 몰입형 다크(SPEC-DESIGN-001의 어두운 색 체계, 기기 모드와 무관)로 보여야 하며(**shall**), 음성 모드에서는 위에서 아래로 제목 "AI 비서"와 닫기 버튼 → Orb 상태 칩 → AI Orb → "무엇을 도와드릴까요?" / "말씀해 주시면 제가 대신 처리할게요." → 받아쓰기 문장 자리 → "이렇게 부탁해 보세요"와 예시 칩 두 개(지금 홈 예시 템플릿의 앞 두 개) → 아래 조작 줄([글로 입력] · [말하기 끝] · [그만하기])을 둔다. 예시 칩을 누르면 글로 입력 모드로 바뀌고 입력칸이 그 템플릿 문장으로 채워진다(보내지 않음). SPEC-SHELL-001의 임시 화면은 이 화면으로 바뀐다.
- **REQ-002** [State-driven] **While** AI 비서 화면이 열려 있으면, Orb는 대기 · 듣는 중 · 처리 중 세 상태 가운데 하나를 보여야 하며(**shall**), 상태 칩 글자 "기다리고 있어요" · "듣고 있어요" · "처리하고 있어요"를 Orb와 함께 늘 보인다. 상태가 바뀌면 화면 읽기 프로그램에 한 번 정중한 수준(polite)으로 알린다. 기기의 움직임 줄이기가 켜져 있으면 Orb 움직임을 멈추고 칩만 바꾼다. Orb 자체는 의미 트리에서 장식으로 숨긴다.

### 3.2 받아쓰기

- **REQ-003** [Event-driven] **When** 사용자가 AI 비서 화면에서 말하기를 시작하면(마이크 권한이 이미 허용된 상태에서 화면을 연 직후 자동, 또는 Orb를 누름), 앱은 기기 음성 인식으로 한국어 받아쓰기를 시작해 듣는 중 상태로 바꾸고, 중간 결과를 받아쓰기 문장 자리에 실시간으로 보여야 하며(**shall**), [말하기 끝]을 누르거나 인식기가 말이 끝났다고 알리면 최종 문장을 지금의 부탁 접수 경로(`/v1/intake`, 실패 시 SPEC-INTAKE-001 REQ-022 대체 동작)로 보내고 처리 중 상태를 거쳐 계획 카드(`/assistant/plan`, REQ-009)를 연다. 음성 인식을 쓸 수 없으면(인식기·권한 플러그인이 없음 — 테스트 환경 포함 — 또는 한국어 인식 언어가 없음) 받아쓰기를 시작하지 않고 글로 입력 모드로 연다(REQ-008).
- **REQ-004** [Unwanted] 콜비 앱은 음성 데이터를 직접 다루거나 업로드하거나 기기에 저장해서는 안 되며(**shall not**), 콜비 서버로 가는 것은 사용자가 확인할 수 있는 최종 문장(글)뿐이다. 앱은 먼저 기기 안 인식으로 받아쓰기를 시도한다. 이 요구는 "음성이 기기를 떠나지 않는다"는 보장이 아니다: 기기 안 인식을 쓸 수 없어 OS 음성 인식(애플·구글)을 쓰는 경우 음성은 그 제공자가 처리하며, 이 경우의 고지는 OD-2를 따른다.
- **REQ-005** [Event-driven] **When** 사용자가 처음 말하기를 시작하면, 앱은 OS 권한 창을 띄우기 전에 목적 문장 사전 안내(CMP-23: "말로 부탁하면 제가 글로 받아 적어요. 콜비는 음성을 저장하지 않아요." + [계속])를 보여야 하며(**shall**), 사용자가 거부하면 글로 입력 모드로 바꾸고 "마이크 없이도 글로 부탁할 수 있어요"를 보인다. 다시 묻지 않음 상태로 거부되어 있으면 사전 안내 대신 설정에서 켜는 방법을 한 줄로 보이고 [설정 열기]를 둔다.
- **REQ-006** [Event-driven] **When** 인식 결과가 비었거나, 인식기가 오류를 내거나, 말이 없는 채 인식기가 끝나면, 앱은 "잘 못 들었어요. 다시 말하거나 글로 적어 주세요"를 보이고 대기 상태로 돌아가야 하며(**shall**), 빈 문장을 부탁으로 보내지 않는다. 예외로, 기기 안 인식을 쓸 수 없다는 오류(언어 팩 없음 등)이면 같은 말하기 안에서 **한 번만** 일반 인식으로 다시 시도하고(OD-2 고지를 보인 뒤), 그것도 실패하면 위 문구와 함께 글로 입력 모드로 바꾼다. 연달아 두 번 실패하면 다음 화면 열기부터는 자동으로 듣기 시작하지 않는다.
- **REQ-007** [Event-driven] **When** 사용자가 [그만하기]·닫기·시스템 뒤로 가기를 누르거나 앱이 배경으로 가면(생명주기 `paused`·`hidden`. OS 권한 창이 떠서 생기는 `inactive`는 배경으로 치지 않는다), 앱은 즉시 받아쓰기를 멈추고 중간 결과를 버려야 하며(**shall**), 화면이 닫힌 뒤에는 어떤 경우에도 마이크가 켜져 있지 않다. 닫으면 가운데 버튼을 누르기 전의 탭과 화면으로 돌아간다(SHELL-001 REQ-006).
- **REQ-008** [Event-driven] **When** 사용자가 [글로 입력]을 누르면(또는 `/assistant?mode=text`로 열리거나 음성 인식을 쓸 수 없으면), 앱은 받아쓰기를 멈추고 글로 입력 모드로 바꿔야 하며(**shall**), 이 모드에서는 음성 모드의 상태 칩·큰 Orb·"무엇을 도와드릴까요?" 제목과 부제·"이렇게 부탁해 보세요" 예시 칩·아래 조작 줄을 숨기고, 제목 "AI 비서"·작은 Orb(장식) 아래에 지금 홈의 입력 상자 전체를 그대로 보인다: 입력칸(힌트·키 유지)과 보내기(툴팁 "보내기"), [직접 입력하기](지금처럼 프로필이 없으면 설정, 있으면 직접 입력 화면), "최근 통화한 곳" 칩(작업 목록을 불러오는 중이거나 실패하면 이 묶음만 숨김), "이런 부탁도 할 수 있어요" 템플릿. 같은 글자가 화면에 두 번 나오지 않는다. 받아쓰던 중간 문장이 있으면 입력칸에 채운다.
- **REQ-009** [Ubiquitous] AI 비서에서 여는 화면은 모두 `/assistant`의 자식 경로로 비서 위에 쌓여야 하며(**shall**): 계획 카드 `/assistant/plan`, 설정 `/assistant/settings`, 직접 입력 `/assistant/new`(같은 화면 위젯을 씀). 셸 안 경로를 비서 위에 바로 쌓지 않는다(SPEC-SHELL-001 research R1-G의 go_router 오류). 뒤로 가면 비서로 돌아오고 입력 문장은 그대로다. 계획 카드에서 [이대로 시작]이 성공하면 SHELL-001의 `openTask`로 업무 탭 상세를 열어 비서와 그 위 화면을 모두 닫는다(R1-G3). 부탁을 보낼 때 프로필이 없으면 `/assistant/settings`를 열고, 접수가 404가 아닌 오류로 실패하면 지금처럼 오류 문구를 알림으로 보이고 화면과 입력 문장을 그대로 둔다.

### 3.3 진입과 오늘 화면

- **REQ-010** [Ubiquitous] 오늘 화면(SCR-H01)은 부탁 입력 상자(입력칸·보내기·직접 입력하기·예시 템플릿)를 더는 보이지 않아야 하며(**shall**)(SHELL-001 OD-6 해소), "최근 통화한 곳"은 오늘에 남기되 누르면 AI 비서를 글로 입력 모드로 열고 "{이름}에 "를 채운다. 바로가기 "전화 대신하기"·"정보 찾아보기"는 AI 비서를 연다. 작업이 하나도 없으면 첫 사용 빈 상태 대신 브리핑 카드에 "오늘은 맡긴 일이 없어요." / "가운데 버튼으로 부탁해 보세요."를 보인다(SHELL-001 OD-2 해소, 04 §17.2). 이 변경으로 바뀌는 기존 테스트는 `acceptance.md` AC-016에 이름을 적은 것뿐이다.

### 3.4 통화 중 화면

- **REQ-011** [State-driven] **While** 통화 작업이 진행 중(`dialing`·`ringing`·`inProgress`)이면, 셸 밖 최상위 경로 `/calls/:id/live`는 통화 중 화면(SCR-T08)을 몰입형 다크로 보여야 하며(**shall**), 위에서 아래로 뒤로 버튼과 [통화 끊기](지금의 끊기 확인 동작 그대로) → 응답 중 상태의 작은 Orb · "통화 중 · 경과 시간" · 상대 이름 · 부탁 요약 → 실시간 자막(지금 `TranscriptView`의 내용, 말풍선 위에 "콜비" / 상대 이름 표시, 새 줄이 오면 끝까지 따라감) → "실시간 자막 · 통화는 글로 기록돼요"를 둔다. 대기 승인이 오면 지금의 승인 카드를 밝은 아래 고정 영역에 보이고, 이 화면이 보이는 동안 같은 작업의 승인 알림(`ApprovalListener` 스낵바)은 띄우지 않는다. 다른 작업의 승인 알림 [답하기]와 AI 비서 위에서 받은 승인 알림 [답하기]는 SHELL-001의 `openTask`로 연다. 통화가 끝나면(`summarizing` 이후) 이 화면을 닫아(`pop`) 아래의 업무 실행 화면으로 돌아간다.
- **REQ-012** [State-driven] **While** 통화 작업이 진행 중이면, 업무 실행 화면(SCR-T02)은 머리에 [통화 보기](`/calls/:id/live`로 감)를 보여야 하며(**shall**), 대화 기록 묶음·자막 따라가기·하단 고정 승인 카드와 그 동작은 지금 그대로 둔다(접지 않음, OD-5). 같은 승인은 T02와 T08 어느 쪽에서 답해도 한 번만 보내진다(서버 판정, 기존 승인 카드 동작).

### 3.5 구조·접근성·회귀

- **REQ-013** [Ubiquitous] AI Orb(상태 대기 · 듣는 중 · 처리 중 · 응답 중)와 몰입형 다크 테마는 공용 UI 패키지(`kolbi_ui`)에 있어야 하며(**shall**), 상태 값만 받아 그리고 마이크·음성 인식을 모른다. 음성 인식·권한 패키지와 받아쓰기 포트는 앱의 비서 기능 안에만 있고, `kolbi_ui`·`kolbi_core`는 음성 인식 패키지를 가져오지 않는다(설계서 AD-9, 의존 규칙 테스트로 확인).
- **REQ-014** [Ubiquitous] AI 비서 화면과 통화 중 화면은 `androidTapTargetGuideline`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline`을 통과하고, 글자 크기 배율 2.0·360×640에서 넘침 오류 없이 그려져야 하며(**shall**), 아래 조작 줄의 세 버튼은 각각 읽기 문구("글로 입력하기", "말하기 끝내고 보내기", "그만하기")를 가진다. 받아쓰기 중간 문장은 실시간 영역으로 매번 읽지 않고, 최종 문장을 보낼 때 한 번 읽는다.
- **REQ-015** [Ubiquitous] 기존 통화 흐름은 동작이 같아야 하며(**shall**)(계획 카드 → [이대로 시작] → 업무 실행 → 고정 승인 카드(빠른 답·코멘트·만료) → 결과 → 후속 행동, 직접 입력, 신뢰 안내, 앱 어디서든 승인 알림), 부탁 접수는 시작 위치만 오늘에서 AI 비서(글로 입력 모드)로 바뀌고 입력 상자의 동작(채우기·보내기·직접 입력·프로필 없음·404 대체·그 밖의 오류)은 같다. 결과 카드의 [다시 걸기]·[조건 바꿔 다시]는 지금처럼 계획 카드로 간다.
- **REQ-016** [Unwanted] 이 SPEC은 `server/`와 `/v1`을 바꿔서는 안 되며, 기존 테스트는 `acceptance.md` AC-016에 이름을 적은 블록 외에는 수정 없이 통과해야 한다(**shall not** 그 밖의 변경).

## 4. 비기능 제약

- 새 외부 의존 두 개(앱에만): 음성 인식 패키지 `speech_to_text`(plan-audit 1차에서 pub.dev로 확인: 7.5.0, BSD-3-Clause, iOS·Android, `listen`의 `localeId`·`onDevice`·`partialResults`, `stop`·`cancel`, "원격 서비스를 쓸 수 있음" 경고)와 권한 상태 조회·요청·앱 설정 열기를 위한 권한 패키지(후보 `permission_handler`, M1에서 버전·라이선스 확인). `speech_to_text`는 권한을 허용/미허용으로만 알려 주고 설정 열기가 없어(plan-audit D5), 권한 패키지가 마이크·음성 인식 두 권한을 따로 다룬다. 로케일 표기(`ko_KR`/`ko-KR`)와 기기 안 한국어 지원 여부는 M1에서 `locales()` 결과와 실제 기기로 확인한다. 둘 다 받아쓰기 포트 뒤에 둔다.
- 기기 권한 선언: iOS `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`(문구는 REQ-005 사전 안내와 같은 뜻). Android `android.permission.RECORD_AUDIO`와, targetSdk 30 이상에서 필요한 `<queries>` 안의 `android.speech.RecognitionService` 항목(이미 있는 `<queries>` 요소에 더함). 블루투스 헤드셋 입력은 범위 밖이라 블루투스 권한은 넣지 않는다.
- 위젯 테스트는 가짜 인식기(`FakeSpeechRecognizer`)만 쓴다. 실제 마이크·인식기는 테스트에 쓰지 않는다(에픽 D-6).
- 다크 화면 글자 값은 06 §3.3 추천 값을 쓴다(모두 5.0:1 이상으로 계산됨).
- 사진 비교(golden) 테스트를 쓰지 않는다.
- 문구는 해요체, 04 §2.2 금지 문구를 쓰지 않는다. 06 §4.2 문구표를 따른다.
- 서식은 이 SPEC이 만들거나 고친 파일에만 적용한다.

## 5. Open Decisions

| ID | 결정 사항 | 상태 | 결정 내용 |
|----|-----------|------|-----------|
| OD-1 | 받아쓰기 방식 | **DECIDED (2026-11-26, 10 OD-K8)** | 기기 음성 인식, 서버로는 글만 |
| OD-2 | 기기 안 인식을 쓸 수 없는 기기에서 | **DEFAULT (iOS) · Android 편차 결정 (소유자 결정 2026-11-28)** | 받아쓰기는 허용하되, 일반 인식으로 넘어가기 직전에 "이 기기에서는 애플(또는 구글)의 음성 인식 서비스가 말을 글로 바꿔요. 콜비는 음성을 저장하지 않아요."를 한 번 보이고 [계속]/[글로 입력]을 고르게 한다. 제공자 이름은 플랫폼으로 정한다(iOS 애플, Android 구글). 음성이 국외 제공자에게 처리될 수 있어 법률 검토(03 NFR-LAW) 항목에 추가. **Android 편차(소유자 결정 2026-11-28)**: speech_to_text 7.5.0은 Android에서 기기 안 인식을 쓸 수 없으면 실패하지 않고 기본(네트워크) 인식기를 조용히 쓴다(`SpeechToTextPlugin.kt` 620-640). 그래서 "넘어가기 직전" 안내가 Android에서는 뜰 수 없다. Android는 첫 받아쓰기 전에 "Android에서는 구글 음성 인식 서비스가 말을 글로 바꿀 수 있어요. 콜비는 음성을 저장하지 않아요."를 한 번 보이고(권한을 아직 묻지 않았으면 목적 안내 안에, 이미 있으면 [글로 입력]/[계속] 카드로), 본 여부를 SharedPreferences `androidSpeechServiceNoticeAcknowledged`에 저장한다. iOS는 위 기본값대로 이벤트가 올 때 안내한다 |
| OD-3 | 화면을 열면 바로 듣기 시작할지 | **DEFAULT (pending owner review)** | 마이크 권한이 이미 허용되어 있으면 바로 듣는다. 처음이면 사전 안내부터(REQ-005). 이 때문에 04 DOD-11의 "길게 누르면 바로 듣기"는 짧게 누르기와 차이가 없어 만들지 않는다(plan-audit D8) |
| OD-4 | 비서의 음성 응답(소리로 말하기) | **DEFAULT (pending owner review)** | 이 SPEC 범위 밖. "응답 중" 상태는 Orb 컴포넌트에만 두고 통화 중 화면에서 쓴다 |
| OD-5 | 업무 실행 화면의 대화 기록 | **DEFAULT (pending owner review)** | 접지 않고 지금 그대로 둔다(REQ-012). 접으면 기존 자막 따라가기 테스트(`accessibility_test.dart:189-232`)가 깨지고, 통화 중 화면이 따로 생겨 접을 이유가 작다(plan-audit D10). 목업(T02에 대화 없음)과의 차이는 이후 화면 정리 SPEC에서 다룬다 |

## 6. 제외 범위 (Out of Scope)

### 6.1 Out of Scope — 기능

- 대화 모드 음성(끼어들기·보류, F-REQ-08), 비서의 소리 응답(TTS), 사진으로 부탁(F-REQ-09), 블루투스 헤드셋 입력, 가운데 버튼 길게 누르기(OD-3).
- 결과 카드의 [조건 바꿔 다시]를 AI 비서로 보내는 일(04 §17.4 진입 목록). 이 SPEC에서는 지금처럼 계획 카드로 간다.
- 장소 선택 화면(SPEC-PLACE-001). 이 SPEC에서 장소가 정해지지 않은 부탁은 지금처럼 계획 카드의 번호 칸으로 간다.
- 받아쓰기 기록 저장, 자주 하는 부탁(F-REQ-04), 오늘의 브리핑 문장 생성(F-HOME-01).
- 잠금 화면 진행 표시·푸시 알림.

### 6.2 Out of Scope — 서버와 데이터

- `server/` 변경, 음성 업로드 경로, STT API 연동.

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
