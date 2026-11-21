# SPEC-FOLLOWUP-001 근거 자료

모든 줄 번호는 커밋 `c664596` 기준 작업 트리에서 직접 읽어 확인했다. 이 SPEC 작성 중 테스트는 실행하지 않았다.

## 1. 지금의 결과 화면

| 위치 | 내용 |
|------|------|
| `app/lib/features/calls/presentation/call_detail_screen.dart:202-213` | 끝난 상태: `OutcomeCard`, 승인 이력, 목적 카드, 대화 기록 |
| `call_detail_screen.dart:245-253` | 끝난 상태의 행동은 "다시 걸기" 하나 → `context.push('/calls/new', extra: task)`(`:248`) |
| `app/lib/features/calls/presentation/new_call_screen.dart:14-31` | `redial`로 양식 미리 채움 |
| `app/lib/features/calls/presentation/widgets/outcome_card.dart:6-7` | `unverified` 안내 문구 상수(SPEC-OUTCOME-001 OD-2) |
| `outcome_card.dart:28-34` | 결과별 아이콘·색 |
| `app/lib/features/calls/domain/call_models.dart:51-58` | `OutcomeResult` 라벨: 목표 달성 / 일부 달성 / 달성 못 함 / 결과 미확인 |
| `call_models.dart:64` | `OutcomeSource { llm, heuristic, unknown }` |
| `call_models.dart:156-164` | `CallOutcome.fromJson`(모르는 `result` → `failed`, 모르는 `source` → `unknown`) |

## 2. 서버 결과 생성

| 위치 | 내용 |
|------|------|
| `server/src/domain/types.ts:54-67` | `OutcomeResult`(네 값), `OutcomeSource`, `CallOutcome` |
| `server/src/brain/openaiBrain.ts:22-27` | `OutcomeSchema`: `result` 엄격(세 값), 목록은 null/생략 허용 |
| `openaiBrain.ts:72-90` | `summarize`: 요청 본문 `{language, goal, approvals, transcript}` — 기준 시각 없음 |
| `server/src/brain/prompts.ts:59-62` | `SUMMARY_SYSTEM_PROMPT` |
| `server/src/brain/heuristicBrain.ts:32-73` | 휴리스틱 요약(일정 필드 없음) |
| `server/src/services/callService.ts:470-473, 486-488` | `endedAt` 기록 뒤 요약 |

## 3. 앱 의존성

`app/pubspec.yaml`의 `dependencies`: `flutter`, `flutter_riverpod`, `go_router`, `http`, `intl`, `material_ui`, `shared_preferences`, `web_socket_channel`. `app/pubspec.lock`에 `share_plus`, `url_launcher`, `path_provider`(본 패키지)는 없다(`path_provider_linux`·`_windows`·`_platform_interface`만 `shared_preferences`의 간접 의존으로 있음). `app/lib`에 `Clipboard` 사용처는 없다. 클립보드는 Flutter SDK(`flutter/services.dart`)에 있어 새 의존성이 필요 없다. 공유 시트와 파일 넘기기는 플랫폼 플러그인이 필요하다 → OD-1.

`share_plus`의 현재 버전, `XFile.fromData`류 메모리 파일 공유 지원, 웹 동작은 이 SPEC 작성 중 확인하지 않았다(run-phase에서 패키지 문서로 확인, 잔여 위험).

## 4. 신뢰 안내 문구의 근거 (REQ-013)

| 문장 | 근거(코드) |
|------|-----------|
| (1) AI라고 먼저 밝힘 | `server/src/brain/prompts.ts:38` "Always say you are an AI assistant in your first sentence." 첫 인사 템플릿도 AI 비서라고 밝힘(`prompts.ts:3-7`) |
| (2) 중요한 결정은 먼저 물어봄 | `prompts.ts:39-42` 규칙 2(결제·가입·약정 전 `request_user_approval`) |
| (3) 대화가 글로 서버에 저장, 끝난 통화는 지울 수 있음 | `CallTask.transcript`(`domain/types.ts:91`), 저장소 `store/taskStore.ts`, 삭제 `http/app.ts:182-185`, 끝난·계획 대기 작업만 삭제(`callService.ts:300-307`), 앱 삭제 버튼(`call_detail_screen.dart:119-120`) |
| (4) 음성은 서버에 저장하지 않음, 실통화 음성은 KAT·OpenAI를 거침 | `domain/types.ts`에 audio 필드 없음(`grep -ci audio` → 0), 서버에서 파일을 쓰는 곳은 `store/taskStore.ts`뿐(`grep -rln "writeFile\|createWriteStream\|appendFile" server/src`, 테스트 제외). 브리지는 음성 조각을 그대로 넘기기만 함(`providers/realtimeBridge.ts:191-193, 289-290`) |
| (5) 카드번호·비밀번호를 말하지 않음 | `prompts.ts:43-44` 규칙 3 |

KAT Cloud나 OpenAI가 자기 쪽에서 음성을 보관하는지는 이 저장소로 알 수 없다. 그래서 (4)는 "이 앱의 서버"로 범위를 한정한다.

지금 신뢰 안내는 양식 화면의 한 문단뿐이다(`new_call_screen.dart:162-182`, "AI 비서는 통화 시작 때 AI임을 밝혀요 …"). SPEC-INTAKE-001 뒤 기본 흐름은 양식을 거치지 않는다.

## 5. 기존 테스트 영향

- 앱에 "다시 걸기"나 "이대로 전화 걸기"를 누르는 기존 테스트는 없다(`grep -rn "다시 걸기\|redial\|이대로 전화 걸기" app/test` → 없음).
- SPEC-INTAKE-001이 만드는 `plan_card_test.dart`, `intake_flow_test.dart`는 [이대로 시작]을 누른다. 안내 시트가 생기면 준비 값에 확인 기록이 필요하다(AC-016).
- `server/src/brain/openaiBrain.test.ts`의 SPEC-OUTCOME-001 테스트(AC-005~AC-008)는 `appointment`가 없는 응답을 쓰므로 그대로 통과해야 한다.

## 6. 벤치마크

2026-11-21 WebFetch로 확인. 다른 제품 화면은 확인하지 못했으며 그리지 않는다.

| 출처 | 확인 | 이 SPEC에 쓴 내용 |
|------|------|------------------|
| 전자신문, "LG유플러스, AI 비서 '익시오' 강화…스마트 통화 관리 기능 탑재", 2025-10-19 — https://m.etnews.com/20251019000044 | 열림 | 통화 내용 요약("AI 스마트 요약", 여섯 가지 형식), 지난 통화 내용 검색, 통화에 나온 장소의 지도 정보, 온디바이스 모델로 "업무 제안" 개선 예정. 통화 후 할 일 제안의 구체 내용은 기사에 없음. **익시오 앱 화면은 확인하지 못했다.** → 통화 뒤 결과를 다음 행동으로 잇는다는 방향만 참고 |
| 뉴시스, "LGU+ AI 익시오, 통화중 궁금증 '말로 물어보면 대답'…상대에도 공유(종합)", 2025-11-13 — https://www.newsis.com/view/NISX20251113_0003401467 | 열림 | 통화 중 AI 검색, 개인정보 조치(호출어 전 음성은 기기에만, 동의 시 비식별 업로드), 통화 중 언급된 일정·장소 예약을 앞으로 하겠다는 계획. **화면 미확인.** → 무엇이 기기 밖으로 나가는지 밝히는 신뢰 안내(REQ-013 (4)) |
| Victor Yocco, Smashing Magazine, 2026-02-11 — https://smashingmagazine.com/2026/02/designing-agentic-ai-practical-ux-patterns/ | 열림 | "Action Audit & Undo"(행동 기록과 되돌리기, 시간 한도 명시), 오류 시 인정·수정 내용·사람 지원 경로. → 캘린더는 직접 쓰지 않고 초안을 넘겨 사용자가 저장(되돌릴 것이 없게) |
| Pickle 소개 — Carly 블로그(경쟁사 작성), https://www.usecarly.com/blog/pickle-ai/ | 열림 | 캘린더·연락처 연결(커넥터)을 언급. **Pickle 화면 미확인.** → 커넥터는 이 SPEC 제외, 공유 시트로 대신 |
| Towards AI "8 UX Patterns…", AgenticWire "Agent UX design patterns" | **확인 못 함**(403 / 429) | 근거로 쓰지 않음 |
