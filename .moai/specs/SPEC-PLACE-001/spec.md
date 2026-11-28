---
id: SPEC-PLACE-001
title: "장소 찾기 — 카카오 로컬 검색, 장소 선택·상세, 계획 카드 채우기"
version: "0.2.1"
status: implemented
created: 2026-11-28
updated: 2026-11-28
author: jason
priority: High
phase: "v0.5.0 target"
module: "server/src/places, server/src/http, server/src/domain, server/src/brain, server/src/services, app/lib/features/places, app/lib/shell, packages/kolbi_core"
lifecycle: spec-anchored
tags: "places, kakao-local, place-search, location-permission, plan-card, no-storage, privacy, flutter, fastify"
tier: L
depends_on: [SPEC-ASSIST-001]
related_specs: [SPEC-INTAKE-001, SPEC-POLICY-001, SPEC-ASSIST-001, SPEC-SHELL-001, SPEC-HUB-001]
---

# SPEC-PLACE-001: 장소 찾기 — 카카오 로컬 검색, 장소 선택·상세, 계획 카드 채우기

## HISTORY

| 버전 | 날짜 | 작성 | 변경 |
|------|------|------|------|
| 0.1.0 | 2026-11-28 | jason (manager-spec) | 최초 작성(draft). 에픽 EPIC-KOLBI-APP의 다섯째 SPEC. 에픽 개요 §4.1 요약, 03 F-PLACE-01~03·F-REQ-07·F-CALL-01, 04 SCR-H02·H03·CMP-05·06·23, 06 DR-4, 설계서 §4.2·§4.3을 전체 문서로 씀. 카카오 로컬 키워드 검색의 요청·응답 필드는 공식 문서로 확인함(`research.md` R1) |
| 0.1.1 | 2026-11-28 | jason (manager-spec) | plan-audit 1차(FAIL 0.84, `.moai/reports/plan-audit/SPEC-PLACE-001-review-1.md`) 반영. 소유자 결정 2026-11-28: OD-2·OD-3·OD-6·OD-7을 권장 기본값대로 확정(감사 D1), OD-2·REQ-001의 판정 기준을 조립된 `config.provider`로 명시. 검색어 멈춤 낱말과 "해 줘" 예시(감사 D2). 15xx 대표번호 표시를 `formatPhone`에서 고침(감사 D3). 저장 금지 증명에 예상 못 한 예외·형식 오류 경로를 더하고 모든 예외를 원인 없이 감쌈(감사 D4). 시간 제한 주입(감사 D5), 위치 문구 좁힘과 좌표 반올림(감사 D6), 사람 이름 검색어 위험 기록(감사 D7), 카카오 콘솔 활성화 확인(감사 D8), REQ 문구 정리(감사 D9·D16), 마일스톤 순서(감사 D10), 파일 수(감사 D11), 시뮬레이션 거리 순서(감사 D12), `Cache-Control: no-store`(감사 D13), AC 필드 이름(감사 D14), 주석 범위(감사 D15). 요구사항·인수 기준 수(22 / 22)는 그대로 |
| 0.1.2 | 2026-11-28 | jason (manager-spec) | plan-audit 2차 PASS 0.91(`.moai/reports/plan-audit/SPEC-PLACE-001-review-2.md`) 뒤 정리. 소유자 Implementation Kickoff Approval(2026-11-28): OD-1·OD-4·OD-5·OD-8·OD-9·OD-10을 기본값대로 확정. 소유자 답변: 개발 서버는 실제 통화(KAT)에 쓰이므로 run은 그 서버를 건드리거나 다시 시작하지 않는다(D-11, §4). 감사 2차 N1(AC-005 (9)), N2(`cause` 단언 위치), N3(감사 결함 번호에 "감사" 접두), N4(sync 문서 항목) 반영. 요구사항·인수 기준 수(22 / 22)는 그대로 |
| 0.2.0 | 2026-11-28 | jason (manager-spec) | 소유자 화면 검토(2026-11-28) 뒤 개정. "근처 치과 내일 오전 예약해 줘"의 첫 검색어가 "치과 오전"으로 나옴(앱 규칙이 `오전`을 건너뛰지 않음). 소유자 결정 2026-11-28: "서버 AI가 검색어도 뽑기" — OD-7을 뒤집어 `/v1/intake` 응답에 `placeQuery`를 더함(REQ-023, REQ-024 신설, REQ-010·REQ-022 개정, `design.md` D6·D10). 날짜·시각은 부탁 문장(계획 카드 "부탁할 일")에 그대로 남고 검색어에서만 빠진다. 앱 대체 규칙에도 같은 시간 낱말을 더함. 기존 시험 변경 `app.test.ts`의 접수 응답 키 고정 줄 하나(AC-022 표). 소유자 결정: geolocator의 `BYPASS_PERMISSION_LOCATION_ALWAYS=1`을 iOS 배포 빌드에 적용(plan §B.4, 완료 정의). 요구사항·인수 기준 22 / 22 → 24 / 24 |
| 0.2.1 | 2026-11-28 | jason (manager-docs) | sync 단계 기록. 상태 in-progress → implemented(완료 표시는 sync 감사 통과 뒤). 0.2.0 M7 뒤 조율자 확인에서 나온 검색어 규칙 수정 셋(띄어 쓴 "3시 반", 사람 조사·인용 어미 "엄마한테 … 늦는다고", 동행 표현·관형형 동사 "가족과 함께 갈")을 기록함. `design.md` D6 공유 예시 표는 24줄이며 서버 `domain/placeQuery.test.ts`와 앱 `kolbi_core/test/places_test.dart`가 같은 표를 고정함. 대체 규칙의 알려진 한계(고정 낱말 목록이라 `앉을`·`쉴` 같은 다른 관형형 동사나 낯선 표현은 놓칠 수 있음, 검색칸 고치기와 [번호 직접 입력]이 빠져나갈 길, 실제 LLM의 `placeQuery` 품질은 아직 확인 안 함)는 `acceptance.md` 잔여 위험에 주석으로 더함. 요구사항·인수 기준 수(24 / 24)와 본문은 그대로 |

## 1. 배경과 목적

지금 앱에서 부탁에 번호가 없으면 계획 카드가 번호 칸 하나를 열고 사용자가 직접 번호를 적는다(`app/lib/features/calls/presentation/plan_card_screen.dart:166-172`). "강남역 근처 파스타집, 금요일 7시 2명 예약해 줘"처럼 장소 조건만 있는 부탁은 사용자가 번호를 따로 찾아 와야 한다. 서버에는 장소 검색이 없다(`server/src/http/app.ts:147-205`에 `/v1/places` 경로 없음).

기획(03 F-PLACE-01~03, 흐름 1)과 디자인 결정(06 DR-4, 04 §17.1)은 AI 비서(SCR-A01) 다음 화면으로 장소 선택(SCR-H02)을 열어 후보 몇 곳 가운데 하나를 고르게 하고, 고른 곳의 이름과 번호로 계획 카드(SCR-H04)를 채우도록 정했다. 번호를 주는 국내 장소 검색은 카카오 로컬뿐이며(01 §5.2), 카카오는 검색 결과를 실시간 호출로만 쓰고 저장(임시 저장 포함)하지 말라고 답했다(`research.md` R2).

이 SPEC은 서버에 `places` 모듈과 `POST /v1/places/search`를 더하고(설계서 §4.2·§4.3), 앱에 장소 선택·장소 상세 화면을 더한다. 검색 결과는 응답으로만 넘기고 서버의 저장소·캐시·로그에 남기지 않으며, 이를 테스트로 증명한다(에픽 D-8). 키가 없으면 시뮬레이션 제공자로 전 흐름이 돈다(설계서 OD-K3).

## 2. 범위

- 서버: `server/src/places/`(포트 `PlaceSearchProvider`, `SimulatedPlaceSearch`, `KakaoLocalPlaceSearch`, 응답 정규화와 번호 판정), 새 경로 `POST /v1/places/search`(더하기만, D-1), 환경 변수 `KAKAO_REST_API_KEY`(D-9), 조립(`container.ts`), 구조 규칙(`architecture.test.ts`).
- 서버 접수(0.2.0): `/v1/intake` 응답에 선택 필드 `placeQuery`(장소 검색어, 문자열 또는 `null`)를 더함 — LLM 프롬프트·스키마, LLM이 주지 않을 때의 결정적 규칙(`server/src/domain/placeQuery.ts`), 서비스 후처리(`design.md` D10).
- 공유 패키지 `kolbi_core`: 장소 모델과 JSON 해석, `PlacesRepository`, 검색어·"근처" 판단 순수 함수(접수의 `placeQuery`가 있으면 그것, 없으면 대체 규칙), `IntakeResult.placeQuery`, `PhoneSource.search`, `formatPhone`의 대표번호 표시.
- 앱: `features/places`(SCR-H02 장소 선택, CMP-05 후보 카드, SCR-H03·CMP-06 장소 상세 시트, CMP-23 위치 사전 안내, 위치 포트), 비서에서 장소 선택으로 가는 분기, 계획 카드 펼침 규칙 일부(04 D-4), "최근 통화한 곳" → "최근 장소"(04 §11.1 C2).
- 기기 권한 선언: iOS `NSLocationWhenInUseUsageDescription`, Android `ACCESS_COARSE_LOCATION`.
- 화면 설계: 04 §7.2·§7.3·§17.1·§17.8, 06 DR-4, 승인된 목업 https://claude.ai/artifact/Cp7JpXX81GSaEKh5SVUQ7U. 세부 규칙은 `design.md`, 근거는 `research.md`, 변경 파일은 `plan.md` §B.

### 2.1 제외 범위 (Out of Scope) — 기능

- 여러 곳 고르기와 차례로 묻기(F-CALL-06, Phase 2), 비교표(F-RES-05).
- 장소 상세의 [길찾기]와 지도 앱 딥링크(F-INTG-04, 에픽 §5), 앱 안 지도 그리기(03 §8.2).
- 온라인 예약 경로 안내(F-PLACE-06), 내 장소(F-PLACE-05), Google Places(F-PLACE-07), 카테고리 검색 API.
- 오늘의 "최근 장소"에서 장소 상세 시트 열기(04 §7.3 진입 H01). 이 SPEC에서 최근 장소 칩은 지금처럼 비서를 글로 입력 모드로 연다. 이름만 바꾼다.
- 결과·실패 화면의 [다른 곳 찾기](F-RES-07), 공유 시트 진입(Phase 2).
- 사용자별 검색 횟수 제한과 카카오 쿼터 증설 신청(03 §8.1). 위험으로만 기록한다(`plan.md` §D).
- 계획 카드의 주 버튼 문구 "비서에게 맡기기"·신뢰 줄 개정(04 §17.8 SCR-H04), 예상 소요 시간(F-NOTI-05).

### 2.2 제외 범위 (Out of Scope) — 서버와 데이터

- `/v1/intake`의 요청 변경과, 응답의 `placeQuery` 하나 밖의 변경(0.2.0 OD-7 개정). `nearby`(근처 여부)는 응답에 넣지 않고 앱이 정한다. `GET /v1/config` 응답 변경.
- `placeQuery`를 작업·저장소·로그에 남기는 일(REQ-024).
- 장소 ID나 검색 결과를 작업·별도 저장소에 기록하는 일(OD-3). 작업에는 지금처럼 사용자가 확정한 이름·번호만 남는다.
- 실제 카카오 API를 부르는 자동 테스트(D-6).

## 3. 요구사항 (EARS)

### 3.1 서버 — 장소 검색 모듈

- **REQ-001** [Ubiquitous] 서버는 장소 검색 포트 하나와 그 구현 둘(카카오 로컬, 시뮬레이션)을 가져야 하며(**shall**), 어느 것을 쓸지는 조립 한 곳에서만 정한다: `KAKAO_REST_API_KEY`가 있으면 카카오, 키가 없고 조립된 통화 제공자가 시뮬레이션(`config.provider === "simulated"`, 곧 `realCalls`가 false)이면 시뮬레이션, 키가 없고 조립된 통화 제공자가 실제 통화(`kat`)이면 장소 검색 없음(OD-2). 판정 기준은 `CALL_PROVIDER` 환경 변수 값이 아니라 `loadConfig`가 정한 `config.provider`다(`CALL_PROVIDER=auto`에서 KAT 설정이 모자라면 시뮬레이션으로 조립됨, `server/src/config.ts:56-57`). 이름과 위치는 `design.md` D2다.
- **REQ-002** [Event-driven] **When** 인증된 클라이언트가 `POST /v1/places/search`에 `{query, near?}`를 보내면, 서버는 요청을 검증하고(`query` 공백 제거 뒤 1~100자, `near.lat` −90~90, `near.lng` −180~180) 제공자를 한 번 불러 `{source, places}`를 돌려줘야 하며(**shall**), 후보는 최대 5곳이다. `near`가 있으면 반경 2,000m 안에서 거리순, 없으면 좌표 없이 정확도순으로 찾는다(OD-4). 응답 형식은 `design.md` D1이다. 토큰이 없거나 틀리면 지금의 `/v1/` 규칙대로 401이다.
- **REQ-003** [Ubiquitous] 서버는 후보마다 제공자가 준 전화번호를 `checkTargetNumber`(`server/src/domain/phone.ts:57`)로 판정해 `phoneCheck`(`ok` · `invalid` · `blocked` · `missing`)를 붙여야 하며(**shall**), `phoneNumber`(E.164)는 `ok`일 때만 채우고 나머지는 `null`이다. 번호 원문은 `phone`으로 함께 준다(표시용).
- **REQ-004** [Unwanted] 서버는 장소 검색의 요청(검색어·좌표)과 결과(이름·주소·번호·장소 ID·좌표·거리)를 작업 저장소·파일·메모리 캐시·이벤트 버스·로그 어디에도 남겨서는 안 되며(**shall not**), 같은 요청이 두 번 오면 제공자를 두 번 부른다. 응답에는 `Cache-Control: no-store`를 붙인다. 이 성질은 `design.md` D4의 증명 시험(예상 못 한 예외·형식 오류 경로 포함)과 구조 규칙으로 확인한다(에픽 D-8).
- **REQ-005** [Event-driven] **When** 카카오 제공자가 검색하면, 서버는 `GET {KAKAO_LOCAL_BASE_URL}/v2/local/search/keyword.json`을 `Authorization: KakaoAK {키}` 머리와 `query`, `size=5`, `page=1`(그리고 `near`가 있으면 소수 셋째 자리로 반올림한 `x`=경도, `y`=위도, `radius=2000`, `sort=distance`)로 부르고, 응답을 zod 스키마로 읽어 `design.md` D3 표대로 옮겨야 하며(**shall**), 5초(주입 가능한 `timeoutMs`) 안에 답이 없거나, 2xx가 아니거나, 형식이 맞지 않거나, 그 밖의 어떤 예외가 나도 502 `place_search_failed`로 답한다. 검색 경로에서 난 모든 예외는 원래 예외를 원인(`cause`)으로 달지 않고 메시지·속성을 옮기지 않은 새 `PlaceSearchError`로 감싸며, 로그에는 상태 코드와 원인 종류만 남긴다(응답 본문·검색어·좌표·원래 예외 메시지 없음).
- **REQ-006** [Ubiquitous] 시뮬레이션 제공자는 외부 호출 없이 검색어로 정해지는 후보 5곳을 돌려줘야 하며(**shall**), 이름은 "연습용"으로 시작하고, `phoneCheck`의 `ok`·`missing`·`invalid`를 모두 포함하며, `near`가 있을 때만 거리를 채운다. `near`가 있으면 거리 오름차순이다. 응답 `source`는 `simulated`다.
- **REQ-007** [Event-driven] **When** 장소 검색이 꺼진 조립(REQ-001의 세 번째 경우)에서 `POST /v1/places/search`가 오면, 서버는 제공자를 부르지 않고 503 `place_search_unavailable`로 답해야 한다(**shall**). 실제 통화 서버에서 연습용 번호에 실제로 거는 일을 막기 위함이다(OD-2).
- **REQ-008** [Ubiquitous] 장소 검색 모듈은 서버 소스 안에서 `domain`과 로거 타입(`logger.ts`의 `Logger`)만 가져와야 하며(**shall**)(외부 패키지는 `zod`) 저장소·두뇌·서비스 계층과 파일 시스템을 가져오지 않고, HTTP 계층은 구체 장소 제공자를 모른다. 카카오 키는 서버 환경 변수에만 있고 앱·응답·로그에 나오지 않는다(D-9). 이 규칙은 서버 구조 시험에 소스 글자 대조로 더한다(설계서 §4.2 표, `design.md` D2).

### 3.2 앱 — 장소 선택으로 가는 길

- **REQ-009** [Event-driven] **When** AI 비서가 부탁을 보내고 `/v1/intake` 결과의 `missing`에 `phoneNumber`가 있으며 번호 차단(앱 모델 `draft.numberBlocked`)이 아니면, 앱은 계획 카드 대신 장소 선택(SCR-H02)을 비서의 자식 경로 `/assistant/places`로 열어야 하며(**shall**), 그 밖의 경우(번호가 있음, 차단 번호, 옛 서버의 404 대체 초안)는 지금처럼 계획 카드를 연다(OD-6). 뒤로 가면 비서로 돌아오고 문장은 그대로다(04 §17.1).
- **REQ-010** [Ubiquitous] `kolbi_core`의 순수 함수는 첫 검색어와 "근처" 여부를 정해야 하며(**shall**), 검색어는 접수 결과의 `placeQuery`가 있고 공백이 아니면 그 값(30자 상한)이고, 없거나 비면(옛 서버 포함) 초안 이름 또는 문장의 대체 규칙으로 정한다. "근처" 여부는 늘 앱이 문장으로 정한다. 대체 규칙(시간 낱말 `오전`·`오후`·`아침`·`점심`·`저녁`·`밤`·`새벽`·`주말`·`평일`·`이따`·`지금`, 숫자+`일`·`월`·`시반` 등 포함)과 예시는 `design.md` D6이다(OD-7). 장소 선택 화면은 이 검색어를 고칠 수 있는 검색칸에 채워 보여 주고, 검색어가 비면 검색하지 않고 검색칸에 초점을 둔다.

### 3.3 앱 — 장소 선택과 상세

- **REQ-011** [State-driven] **While** 장소 선택 화면(SCR-H02)이 열려 있으면, 앱은 위에서 아래로 보낸 부탁 한 줄과 [고치기](비서로 돌아감) → 검색칸과 [다시 찾기] → 결과 문장("{검색어} {n}곳을 찾았어요") → 후보 카드 목록 → 출처 한 줄(`source`가 `kakao`면 "장소 정보는 카카오 로컬 검색 결과예요", `simulated`면 "연습용 장소예요. 실제 가게가 아니에요") → [번호 직접 입력]을 보여야 한다(**shall**). 후보 카드(CMP-05)는 이름·분류·거리(있을 때)·주소·번호 원문·추천 이유와 [상세]·[여기로 전화]를 가진다. 첫 번째 걸 수 있는 후보는 인디고 테두리와 채운 [여기로 전화]를, 나머지는 선 버튼을 쓴다. 추천 이유는 응답 값으로만 쓴다(거리가 있으면 첫 후보에 "가장 가까워요"). 문구 전체는 `design.md` D7이다.
- **REQ-012** [State-driven] **While** 검색이 진행 중이거나, 결과가 없거나, 실패했거나, 걸 수 있는 후보가 하나도 없으면, 앱은 각각 "{검색어}을(를) 찾는 중이에요"와 뼈대 카드 3개 / "조건에 맞는 곳을 찾지 못했어요" / "장소를 찾지 못했어요. 잠시 뒤 다시 시도해 주세요"와 [다시 시도](503이면 "지금은 장소 찾기를 쓸 수 없어요") / 후보 목록과 함께 "전화할 수 있는 곳이 없어요"를 보여야 하며(**shall**), 어느 상태에서도 [번호 직접 입력]은 남는다. 걸 수 있는 후보가 없어도 계획 카드로 저절로 넘어가지 않는다(OD-5).
- **REQ-013** [Unwanted] 앱은 `phoneCheck`가 `ok`가 아닌 후보를 고를 수 있게 해서는 안 되며(**shall not**), 그 후보의 [여기로 전화]와 상세의 [여기에 물어보기]를 비활성으로 두고 이유를 글자로 보인다: `missing` = "번호가 없어 전화할 수 없어요", `invalid`·`blocked` = "걸 수 없는 번호예요". 카드의 상태 글자는 "걸 수 있음" · "번호 없음" · "걸 수 없는 번호"다.
- **REQ-014** [Event-driven] **When** 사용자가 후보의 [상세]를 누르면, 앱은 장소 상세 시트(SCR-H03, CMP-06)를 열어 이름(열릴 때 초점)·분류·거리·주소·번호 원문·[번호 복사](번호가 있을 때)·[여기에 물어보기]를 보여야 하며(**shall**), 닫으면 [상세] 버튼으로 초점이 돌아간다(F-REQ-07).
- **REQ-015** [Event-driven] **When** 사용자가 걸 수 있는 후보의 [여기로 전화] 또는 상세의 [여기에 물어보기]를 누르면, 앱은 비서의 계획 카드(`/assistant/plan`)를 장소 선택 위에 열어야 하며(**shall**), 초안은 접수 초안 그대로에 `targetName` = 후보 이름, `phoneNumber` = 후보의 E.164, `phoneSource` = `search`("검색 결과")만 바꾼 것이다. 계획 카드는 번호를 지금처럼 `formatPhone`으로 보이되, 서버가 대표번호(15xx·16xx·18xx)를 `+1` 뒤 7자리 꼴로 판정한 값은 `1588-0000`처럼 보여야 하며(서버 판정과 만들기 요청의 E.164는 그대로, `design.md` D9), 뒤로 가면 장소 선택(후보 목록 그대로) → 비서 순이다. [번호 직접 입력]은 접수 초안 그대로 계획 카드를 연다(지금의 번호 칸).

### 3.4 앱 — "근처"와 위치 권한

- **REQ-016** [Event-driven] **When** "근처" 부탁으로 장소 선택이 열리고 위치 권한을 아직 묻지 않았으면, 앱은 OS 권한 창 전에 사전 안내(CMP-23: "근처 가게를 찾으려면 지금 위치가 필요해요. 가까운 가게를 찾는 데만 써요. 콜비는 위치를 저장하지 않아요." + [계속])를 보여야 하며(**shall**), [계속] 뒤 OS 창을 띄운다. 허용되면 대략 위치 한 번을 읽어 `near`로 검색한다. 거부되면 "동네 이름을 알려 주세요" 한 칸(F-REQ-06)을 보여 적은 동네를 검색어 앞에 붙여 `near` 없이 찾고, 다시 묻지 않음 상태면 설정에서 켜는 방법 한 줄과 [설정 열기]를 함께 둔다. 위치 읽기가 실패하거나 10초를 넘으면 거부와 같이 처리한다. 권한 시점은 OD-1이다.
- **REQ-017** [Unwanted] 앱은 기기 위치를 기기에 저장하거나, 콜비 서버의 장소 검색 요청(서버가 반올림해 카카오 검색에 넘김) 외의 곳으로 보내거나, "근처"가 아닌 부탁의 검색에 실어서는 안 된다(**shall not**). 위치 패키지(OD-8)는 장소 기능의 위치 포트 안에서만 가져오고(`design.md` D8), 위젯 시험은 가짜 위치만 쓴다. `kolbi_core`·`kolbi_ui`는 위치 패키지를 가져오지 않는다.
- **REQ-018** [Ubiquitous] 기기 권한 선언은 iOS `NSLocationWhenInUseUsageDescription`(사전 안내와 같은 뜻의 문구)과 Android `android.permission.ACCESS_COARSE_LOCATION`뿐이어야 하며(**shall**), `ACCESS_FINE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`, iOS의 "항상 허용" 키는 넣지 않는다.

### 3.5 앱 — 계획 카드와 오늘

- **REQ-019** [Ubiquitous] 계획 카드는 04 D-4의 일부를 따라야 하며(**shall**): 번호 출처가 검색이면 번호 옆에 "검색 결과"를 보이고, 기본값·프로필에서 온 통화 언어와 내 이름은 두 행 대신 한 줄("통화 언어 · 내 이름")로 접는다. 접힌 줄에서도 언어 글자를 누르면 지금처럼 한국어/English가 바뀌고 이름을 누르면 설정이 열린다(OD-10). 그 밖의 행과 [이대로 시작] 동작은 그대로다.
- **REQ-020** [Ubiquitous] 오늘 화면과 AI 비서 글로 입력 모드의 묶음 제목 "최근 통화한 곳"은 "최근 장소"로 바뀌어야 하며(**shall**), 칩의 내용·순서·누르면 하는 일은 그대로다(04 §11.1 C2, OD-9).

### 3.6 접근성·회귀

- **REQ-021** [Ubiquitous] 장소 선택 화면과 장소 상세 시트는 `androidTapTargetGuideline`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline`을 통과하고 360×640·글자 크기 2.0에서 넘침 없이 그려져야 하며(**shall**), 후보 카드는 하나의 읽기 단위로 "{이름}, {분류}, {거리}, {상태 글자}"를 읽고, 결과 문장은 검색이 끝날 때 정중한 수준으로 한 번 알린다.
- **REQ-022** [Unwanted] 이 SPEC은 기존 `/v1` 경로·요청·응답과 WebSocket 이벤트를 바꿔서는 안 되며(**shall not**, D-1) — 예외는 `/v1/intake` 응답에 `placeQuery` 키 하나를 더하는 것뿐이다(REQ-023, 0.2.0 OD-7) — 기존 테스트는 `acceptance.md` AC-022 표에 이름을 적은 블록 외에는 수정 없이 통과해야 한다(D-2).

### 3.7 서버 — 접수의 장소 검색어 (0.2.0)

- **REQ-023** [Event-driven] **When** `POST /v1/intake`가 답하면, 서버는 응답 최상위에 `placeQuery`(문자열 또는 `null`)를 넣어야 하며(**shall**), 그 값은 장소 이름이나 분류만이다(날짜·시각·인원·요청 동사·`근처`·`주변` 없음). LLM 두뇌는 접수 프롬프트·스키마로 `placeQuery`를 받고, 서비스가 번호 모양을 지우고 `근처`·`주변` 낱말을 빼고 30자로 자른다. LLM이 주지 않거나 비었거나 문자열이 아니면(휴리스틱 두뇌, LLM 실패 대체, 두뇌에 `draftIntake`가 없음 포함), 서비스는 결정적 규칙(`design.md` D6 문장 규칙과 같은 규칙과 같은 예시, 이름이 있으면 이름)으로 채운다. 그래도 비면 `null`이다. 규칙·계약은 `design.md` D10이다.
- **REQ-024** [Unwanted] 서버는 `placeQuery`를 접수 응답 밖으로 내보내서는 안 되며(**shall not**) — 작업 저장소·파일·이벤트 버스·로그에 남기지 않는다(에픽 D-8과 같은 규율). 접수 경로의 기존 로그(요청 URL, LLM 실패의 종류·상태)는 그대로이고 검색어를 싣지 않는다는 것을 시험으로 확인한다.

## 4. 비기능 제약

- 카카오 로컬 키워드 검색 사실(공식 문서로 확인, `research.md` R1): `GET https://dapi.kakao.com/v2/local/search/keyword.json`, `Authorization: KakaoAK ${REST_API_KEY}`, `size` 1~15(기본 15), `page` 1~45, `radius` 0~20,000m, `sort` `accuracy`(기본)·`distance`(`x`·`y` 필요), 응답 `documents[]`의 `id`, `place_name`, `category_name`, `phone`, `address_name`, `road_address_name`, `x`, `y`, `place_url`, `distance`(좌표를 줄 때만). 쿼터: 키워드 검색 일 100,000건, 전체 API 월 3,000,000건. 쿼터 초과·인증 실패의 응답 형식은 확인하지 못했으므로(R6) 어댑터는 상태 코드만으로 판단한다.
- 새 외부 의존 하나(앱): 위치 패키지 `geolocator`(pub.dev에서 확인: 14.1.2, MIT, `getCurrentPosition`·`checkPermission`·`requestPermission`, `LocationPermission.deniedForever`). SwiftPM 지원과 최소 iOS 버전은 M5(위치 마일스톤) 첫 작업에서 확인한다. 서버는 새 의존이 없다(전역 `fetch`와 `AbortController`).
- 시험은 가짜 제공자·가짜 `fetch`·가짜 위치만 쓴다(D-6). 사진 비교 테스트를 쓰지 않는다.
- 문구는 해요체, 04 §2.2 금지 문구를 쓰지 않는다.
- 서식은 이 SPEC이 만들거나 고친 파일에만 적용한다(D-5).
- 개발 서버는 실제 통화(KAT)에 쓰인다(소유자 답변 2026-11-28, D-11). run 단계는 그 서버를 멈추거나 다시 시작하거나 그 데이터·설정을 건드리지 않는다. 로컬 시험과 화면 확인은 따로 띄운 서버(`CALL_PROVIDER=simulated`와 필요한 값을 명령에 직접 준 환경)로만 하며, `server/.env`는 읽거나 불러오지 않는다(`--env-file` 쓰지 않음).

## 5. Open Decisions

| ID | 결정 사항 | 상태 | 결정 내용(또는 권장 기본값) |
|----|-----------|------|-------------|
| OD-1 | 위치 권한을 묻는 시점 | **DECIDED (소유자 결정 2026-11-28, 기본값)** | 처음 "근처" 부탁으로 장소 선택이 열릴 때 CMP-23 사전 안내 → [계속] → OS 창(03 F-PLACE-03, 04 §7.2). 앱 시작·온보딩에서는 묻지 않는다. 거부하면 동네 이름 한 칸 |
| OD-2 | 카카오 키가 없을 때 | **DECIDED (소유자 결정 2026-11-28)** | 조립된 통화 제공자(`config.provider`, 환경 변수 `CALL_PROVIDER` 값이 아님)가 시뮬레이션이면 시뮬레이션 장소 검색("연습용 장소" 표시, 설계서 OD-K3). 실제 통화(`kat`)인데 키가 없으면 장소 검색을 끄고 503 — 연습용 번호에 실제로 거는 일을 막는다 |
| OD-3 | 최근 장소 저장과 카카오 약관(03 OD-5, 에픽 D-8) | **DECIDED (소유자 결정 2026-11-28, 법무 해석은 계속 확인)** | 지금 그대로: 사용자가 확정해 만든 작업의 이름·번호만 사용자 작업 기록으로 남고, 검색 결과·장소 ID는 어디에도 기록하지 않는다(03 OD-5 ①). 카카오 데브톡 답변은 "임시 저장 불허", "장소 ID만 기록하고 나머지는 실시간 호출은 허용 가능"이다(R2, 공식 정책 문서 아님). 소유자·법무가 "작업 기록도 불가"로 정하면 OD-5 ②(업체명만 보관, 번호는 매번 다시 조회)를 별도 개정으로 한다 |
| OD-4 | 후보 수와 반경 | **DECIDED (소유자 결정 2026-11-28, 기본값)** | 5곳(F-PLACE-02의 3~5곳 상한), 1쪽만. "근처"면 반경 2,000m·거리순, 아니면 좌표를 보내지 않고 정확도순. 더 보기 없음 |
| OD-5 | 걸 수 있는 후보가 하나도 없을 때 | **DECIDED (소유자 결정 2026-11-28, 기본값)** | 후보는 모두 비활성 상태로 보여 주고(이유 글자 포함) "전화할 수 있는 곳이 없어요" + [다시 찾기]·[번호 직접 입력]. 계획 카드로 저절로 넘기지 않는다 |
| OD-6 | 장소 선택으로 가는 조건 | **DECIDED (소유자 결정 2026-11-28)** | 접수 결과 `missing`에 `phoneNumber`가 있고 차단이 아니면 이름이 정해져 있어도 장소 선택(이름으로 검색). 404 대체 초안·차단 번호·번호 있음은 계획 카드. 사람 이름("엄마", 연락처 이름)도 검색어로 카카오에 전송되며, 소유자가 이 위험을 받아들였다(`plan.md` §D). [번호 직접 입력]으로 넘어갈 수 있다. 이후 개정 후보: 사람 호칭에 걸리면 자동 검색 없이 검색칸만 연다 |
| OD-7 | 첫 검색어를 만드는 곳 | **DECIDED — 개정 (소유자 결정 2026-11-28, 화면 검토 뒤 "서버 AI가 검색어도 뽑기")** | 서버 접수가 `placeQuery`(장소 이름·분류만)를 응답에 더한다: LLM이 프롬프트·스키마로 뽑고, LLM이 없거나 주지 않으면 서비스가 결정적 규칙으로 채운다(시간 낱말 포함, 예시는 앱 규칙과 같음). `nearby`는 앱에 남긴다. 앱은 `placeQuery`가 있으면 그것을, 없으면(옛 서버) `kolbi_core` 대체 규칙(같은 시간 낱말 더함)을 쓴다. 기존 시험 변경: `server/src/http/app.test.ts:699`의 응답 키 고정 줄에 `placeQuery` 더함(AC-022 표). 이전 결정(0.1.x: `/v1/intake` 불변, 앱 규칙만)은 화면 검토에서 "치과 오전" 검색어가 나와 뒤집음 |
| OD-8 | 위치 패키지 | **DECIDED (소유자 결정 2026-11-28, 기본값 — 버전·SwiftPM은 M5 첫 작업에서 확인)** | `geolocator` 14.1.2(MIT), 대략 위치(`LocationAccuracy.low`)로 한 번만 읽음. 권한은 이 패키지의 API로 묻는다(`permission_handler`는 마이크용으로 비서 기능 안에 남김. 장소 기능에서 `permission_handler`를 쓰면 `app/test/architecture_test.dart:188-205`가 깨진다) |
| OD-9 | "최근 장소" 문구 범위 | **DECIDED (소유자 결정 2026-11-28, 기본값)** | 오늘과 비서 글로 입력 모드 둘 다 바꾼다(같은 묶음이 두 곳에 있음) |
| OD-10 | 계획 카드 펼침 규칙(D-4) 범위 | **DECIDED (소유자 결정 2026-11-28, 기본값)** | 번호 출처 "검색 결과"와, 언어·내 이름을 한 줄로 접기만. 각 글자를 누르는 동작은 지금과 같아 `plan_card_test.dart`를 고치지 않는다. 주 버튼 문구·신뢰 줄 개정은 범위 밖 |

## 6. 추적성

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
| REQ-017 | AC-017 |
| REQ-018 | AC-018 |
| REQ-019 | AC-019 |
| REQ-020 | AC-020 |
| REQ-021 | AC-021 |
| REQ-022 | AC-022 |
| REQ-023 | AC-023 |
| REQ-024 | AC-024 |
