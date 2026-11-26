# 02. UI/UX 벤치마크 — 개인 비서 에이전트 앱

작성일: 2026-11-25 · 범위: 상호작용·시각 설계(기능 조사는 별도 문서) · 대상: CallMate(가칭 "콜비") 상용 출시 재설계

> 이 문서는 다른 제품의 화면이나 브랜딩을 옮기지 않는다. 공개 문서에서 확인한 **패턴과 원칙**만 정리한다. ASCII 그림은 모두 일반 패턴을 보여 주기 위한 것이다. 각 주장 옆에는 직접 열어 본 출처 URL을 붙였고, 열지 못했거나 검색 요약으로만 본 내용은 "미확인"으로 표시했다. "공식 가이드"(Apple HIG, Material, PAIR, HAX), "제품 공식 도움말·발표", "언론·리뷰"를 구분해 적는다.

---

## 1. 요약 — 핵심 UX 원칙 10개

1. **입력은 하나, 확인은 구조화.** 진입은 자유 문장 한 칸(음성 포함)으로 받고, 실행 전에는 대상·일시·조건을 칸으로 나눈 계획 카드로 되돌려 보여 준다. Google AI Mode는 부탁을 받은 뒤 짧은 추가 질문을 하고, 사용자가 확인한 정보만 업체에 전달한다(https://support.google.com/websearch/answer/17104441?hl=en). Chrome·Gemini 에이전트도 "계획 검토"를 먼저 둔다(https://support.google.com/chrome/answer/16821166?hl=en, https://support.google.com/gemini/answer/16940971?hl=en).
2. **되돌릴 수 없는 일 직전에만 멈춘다.** 결제·제출·발송처럼 결과가 남는 행동 앞에서 명시적 확인을 받는다. Apple HIG는 대리 구매 같은 일을 "허락 없이 자동화하지 말라"고 하고(https://developer.apple.com/design/human-interface-guidelines/generative-ai), OpenAI·Google 에이전트도 같은 지점에서 멈춘다(https://openai.com/index/introducing-chatgpt-agent/). 그 밖의 단계는 묻지 않고 진행해 부담을 줄인다.
3. **민감한 입력은 사용자가 직접 한다(손 넘기기).** 로그인·결제 정보·CAPTCHA는 에이전트가 사용자에게 조작을 넘기고, 그동안은 화면을 기록하지 않는다(https://openai.com/index/introducing-operator/, https://help.openai.com/en/articles/11752874-chatgpt-agent). 전화 대행에서는 "통화 중 승인"이 이 역할을 한다.
4. **오래 걸리는 일은 앱 밖에서 보이게.** 진행 상태는 잠금 화면·상태 표시줄의 실시간 진행 표시(iOS Live Activities, Android Live Updates)와 꼭 필요한 알림으로 전달한다. 둘 다 "시작과 끝이 분명한, 사용자가 시작한 일"에 쓰라고 한다(https://developer.apple.com/design/human-interface-guidelines/live-activities, https://developer.android.com/design/ui/mobile/guides/home-screen/live-updates).
5. **진행은 단계 이름으로, 알림은 상태가 바뀔 때만.** "처리 중…" 대신 구체적인 단계 문구를 쓰고(Apple HIG 생성형 AI), 작은 변화에는 알리지 않는다("기사 도착은 알리고 도착 예정 시각 변화는 알리지 말라", Android Live Updates).
6. **결과는 "확정된 것 / 확인 못 한 것 / 다음 할 일"로 나눈다.** AI 결과에 오류가 있을 수 있음을 밝히고, 실패하면 원인과 다음 단계를 일상어로 알린다(Apple HIG 생성형 AI, PAIR "Errors + Graceful Failure" https://pair.withgoogle.com/chapter/errors-failing/).
7. **작업함(기록)이 비서의 두 번째 홈이다.** 끝난 일·기다리는 일·반복 일을 한곳에서 보고 멈추거나 지울 수 있어야 한다. ChatGPT는 예약 작업을 한 목록에서 편집·일시정지·삭제하게 하고(https://help.openai.com/en/articles/10291617-tasks-in-chatgpt), Google AI Mode는 결과가 준비된 대화에 파란 점을 찍는다.
8. **신뢰는 "보정"하는 것이다.** 무조건 믿게 하지 말고, 할 수 있는 일과 없는 일, 얼마나 잘하는지를 알린다(PAIR https://pair.withgoogle.com/chapter/explainability-trust/, HAX G1·G2 https://www.microsoft.com/en-us/research/blog/guidelines-for-human-ai-interaction-design/).
9. **기억과 연결은 사용자가 보고 고치고 끌 수 있어야 한다.** Claude는 기억을 주제 단위로 보여 주고, 일시정지·끄기·임시 대화를 나눠 제공한다(https://support.claude.com/en/articles/11817273-use-claude-s-chat-search-and-memory-to-build-on-previous-context). 권한은 기능을 처음 쓸 때 목적 문장과 함께 요청한다(Apple HIG Privacy).
10. **한국어 화면은 쉬운 말, 한 화면 한 메시지, 익숙한 구조.** 토스의 제품 원칙(One Thing, Easy to Answer, Explain Why)과 라이팅 원칙(Easy to speak, Weed cutting, Suggest over force)이 좋은 기준이다(https://toss.im/tossfeed/article/tossproductprinciples, https://toss.tech/article/8-writing-principles-of-toss). 카카오톡 친구탭 개편과 원상 복귀는 익숙한 주 화면을 바꾸는 일의 위험을 보여 준다(https://mobile.newsis.com/view/NISX20251216_0003442706).

---

## 2. 조사 범위와 방법

| 항목 | 내용 |
|---|---|
| 조사일 | 2026-11-25 |
| 대상 | AI 비서(ChatGPT, Gemini, Claude, Perplexity Comet, Microsoft Copilot, Alexa+), 과업·예약 서비스(Google 검색 AI Mode·Google Pay, 네이버지도, 카카오톡, 토스, 배달의민족 등), 공식 가이드(Apple HIG, Android·Material 3, Google PAIR, Microsoft HAX) |
| 방법 | 웹 검색으로 후보를 찾은 뒤 원문 페이지를 직접 열어 확인했다. 원문에서 확인한 내용만 근거로 썼다. 검색 결과 요약으로만 본 내용, 차단된 페이지는 9장 "미확인 항목"에 모았다 |
| 근거 등급 | **[공식 가이드]** 플랫폼 설계 지침 · **[제품 공식]** 해당 회사의 도움말·발표 · **[언론]** 기사·리뷰 |
| 한계 | 앱을 직접 설치해 화면을 관찰하지 않았다. 따라서 버튼 위치, 색, 애니메이션 같은 세부 화면 묘사는 하지 않았다. 각 제품의 기능은 지역·요금제·시기에 따라 다르다. 예를 들어 OpenAI 도움말은 2026-11 현재 "ChatGPT agent는 더 이상 제공되지 않으며 ChatGPT Work를 쓰라"고 적고 있다(https://help.openai.com/en/articles/11752874-chatgpt-agent). 그래서 이 문서는 특정 기능의 현재 제공 여부보다 패턴을 기준으로 정리한다 |
| 현재 앱 자료 | `app/lib/features/calls/presentation/*.dart`, `.moai/specs/SPEC-UX-001/design.md`, `.moai/specs/EPIC-ASSISTANT-UX/overview.md`, `docs/PRODUCT_ROADMAP.md` |

---

## 3. 서비스별 UI/UX 분석

표의 열은 **진입 · 의도 확인 · 진행 표시 · 승인·위임 · 결과 · 기록 · 신뢰**이다. 출처에 없는 칸은 "—"(확인 안 됨)으로 둔다.

### 3.1 OpenAI — ChatGPT agent / Operator / 예약 작업 [제품 공식]

| 관점 | 확인한 내용 |
|---|---|
| 진입 | 도구 메뉴에서 agent 모드를 고르거나 입력창에 `/agent`를 친 뒤 할 일을 문장으로 설명한다(https://help.openai.com/en/articles/11752874-chatgpt-agent). Operator는 반복하는 부탁을 홈에 저장해 두고 바로 부를 수 있게 했다(https://openai.com/index/introducing-operator/) |
| 의도 확인 | 필요할 때 멈춰서 되묻거나 확인을 구한다("pause for clarification or confirmation when needed", 도움말) |
| 진행 표시 | 작업하는 동안 화면에 진행 내레이션이 나와 무엇을 하는지 보여 준다. 사용자는 아무 때나 끼어들어 지시를 고치거나, 일시정지하고 진행 요약을 요청하거나, 중단하고 부분 결과를 받을 수 있다(https://openai.com/index/introducing-chatgpt-agent/) |
| 승인·위임 | 결과가 남는 행동(구매 등) 전에 명시적으로 허락을 구한다. 이메일 발송 같은 중요한 작업은 사용자가 지켜봐야 진행된다("Watch Mode"). 로그인이 필요하면 멈추고 "브라우저 넘겨받기"를 권한다. 사용자가 조작하는 동안에는 스크린숏을 찍지 않는다(도움말, Operator 발표) |
| 결과 | 휴대폰 앱이 있으면 작업이 끝났을 때 알림을 보낸다(ChatGPT agent 발표) |
| 기록 | 끝난 작업을 매일·매주·매월 반복하도록 설정할 수 있다. 예약 작업은 "Scheduled" 목록에서 보고 편집·일시정지·삭제한다. 알림은 설정에서 푸시·이메일 중 고른다(https://help.openai.com/en/articles/10291617-tasks-in-chatgpt) |
| 신뢰 | 도움말에 프롬프트 주입 위험과 예시를 구체적으로 적고, 필요한 앱만 켜기, 민감한 로그인 피하기 같은 행동 지침을 함께 준다 |

**시사점.** "진행 내레이션 + 언제든 끼어들기 + 끝나면 알림 + 반복 작업 목록"의 묶음은 오래 걸리는 위임 작업의 기본형이다. 손 넘기기 동안 기록을 멈추는 규칙은 우리 웹 작업에도 그대로 필요하다.

### 3.2 Google — 검색 AI Mode "Check for me", Gemini 에이전트, Chrome 자동 탐색, Google Pay [제품 공식]

| 관점 | 확인한 내용 |
|---|---|
| 진입 | AI Mode에 "금요일 6명, 채식 메뉴 있는 곳 예약"처럼 자연어로 부탁하고 "Check for me"를 고른다(https://support.google.com/websearch/answer/17104441?hl=en) |
| 의도 확인 | 짧은 추가 질문으로 부탁을 구체화한다. 전화를 걸 경우 **사용자가 공유하고 확인한 정보만** 업체에 전달한다. 요청 내용을 검토하고 이메일 알림을 받을지 고른다(같은 출처). Chrome 자동 탐색과 Android Gemini는 실행 계획을 검토하게 한다(https://support.google.com/chrome/answer/16821166?hl=en, https://support.google.com/gemini/answer/16940971?hl=en) |
| 진행 표시 | 웹 결과는 몇 분, 전화 결과는 최대 30분 걸린다고 **미리 알린다**(AI Mode). Android Gemini는 채팅과 Live Update 알림에서 "진행 보기"로 실시간 진행을 보고, 거기서 바로 "작업 중지"를 누를 수 있다(Gemini 도움말) |
| 승인·위임 | 비밀번호·결제 정보 입력, 거래 마무리, 로그인, 계정 생성은 Gemini가 멈추고 "직접 조작"을 요청한다. 일부 기기는 10분 안에 넘겨받지 않으면 작업을 멈춘다. Chrome은 사용자가 해야 할 단계가 생기면 브라우저 위쪽에 알림을 띄우고, "작업 넘겨받기"와 "중지"를 제공한다(Gemini·Chrome 도움말) |
| 결과 | 결과가 준비되면 AI Mode 기록의 해당 대화에 파란 점이 찍히고, 선택한 경우 이메일도 온다(AI Mode). Google Pay 대리 결제는 주문 진행 상황을 이메일과 알림으로 보내고, 실패하면 알린다(https://support.google.com/googlepay/answer/16421147?hl=en) |
| 기록 | AI Mode 기록이 작업함 역할을 한다(파란 점 = 새 결과) |
| 신뢰 | "AI 응답에 실수가 있을 수 있어요" 같은 안내를 둔다(AI Mode). Gemini 도움말은 잘못된 버튼 누르기, 허락 없는 주문, "끝났다"고 잘못 보고하기 같은 오작동 예시를 **사용자에게 직접** 적어 둔다. Google Pay 대리 결제는 **확인한 총액과 같거나 낮을 때만** 결제하고, 값이 오르면 결제하지 않는다 |

**시사점.** 우리 서비스와 가장 닮은 사례다. ① 추가 질문 → ② 확인한 정보만 전달 → ③ 예상 소요 시간 안내 → ④ 결과 준비 표시(점·이메일)의 흐름은 콜비의 전화 대행 흐름에 거의 그대로 옮길 수 있다. "확인한 금액 이하일 때만 진행" 같은 **범위가 정해진 승인**은 통화 중 예약금 승인에 바로 쓸 수 있다.

### 3.3 Google Gemini Live (음성) [제품 공식]

- 말하는 도중에 끼어들어 내용을 더하거나 주제를 바꿀 수 있다. "보류(Hold)"로 잠시 멈췄다가 이어 가고, 음성 대화와 글 대화를 같은 대화 안에서 오간다. 카메라·화면 공유를 켜고 끄는 버튼을 따로 둔다(https://support.google.com/gemini/answer/15274899?hl=en).
- **시사점.** 음성 입력은 "녹음 버튼"이 아니라 **대화 모드**로 다루고, 글로 언제든 돌아올 수 있어야 한다. 마이크가 켜져 있는지는 항상 보여 준다.

### 3.4 Anthropic Claude — 기억·임시 대화 [제품 공식]

- 기억은 대화가 끝난 뒤 요약하는 방식이 아니라 대화 중에 **개별 주제 단위**로 저장된다. 사용자가 "기억해 줘"라고 직접 저장시킬 수도 있다. 지난 대화를 찾아 쓰면 현재 대화에 도구 호출로 드러난다. 기억은 "일시정지"(기존 기억은 두고 쓰지도 새로 만들지도 않음)와 끄기로 나뉜다. 유령 아이콘으로 여는 임시 대화는 기록과 기억에 남지 않는다(https://support.claude.com/en/articles/11817273-use-claude-s-chat-search-and-memory-to-build-on-previous-context).
- **시사점.** "회원번호, 선호 좌석, 자주 가는 미용실" 같은 비서 기억은 **주제 단위 카드**로 보여 주고, 지금 작업에 기억을 썼다는 사실을 작업 기록에 드러낸다(HAX G11 "왜 그렇게 했는지 알 수 있게").

### 3.5 Perplexity Comet (에이전트 브라우저) [연구 색인]

- MIT AI Agent Index는 Comet을 이렇게 기술한다. 에이전트가 일하는 동안 **브라우저 전체에 색조**를 입혀 작업 중임을 알리고, 옆 패널에 **행동 기록(action trace)**과 지시 입력창을 둔다(https://aiagentindex.mit.edu/2025/comet).
- 로그인·구매 같은 위험 단계에서 멈추도록 고쳤다는 2025-11 보도는 원문을 열지 못했다(미확인).
- **시사점.** "지금 AI가 조작 중"이라는 **화면 전체 상태 표시**는 웹 작업 화면에 필요하다. 사용자가 누르는 화면과 AI가 누르는 화면이 섞이면 안 된다.

### 3.6 Microsoft Copilot Actions [언론]

- 2025-04 발표. 예약·티켓 구매 같은 웹 작업을 Copilot 화면 안에서 끝내도록 설계했으며, 사이트에 직접 가지 않아도 되게 하는 것이 목표다. 기사는 돈이 드는 예약을 AI에 맡기는 데 사용자가 익숙해지려면 시간이 걸릴 것이라고 지적한다(https://www.windowscentral.com/microsoft/copilot-actions-announcement-2025).
- 현재 이름과 제공 상태("Copilot Tasks" 등)는 확인하지 못했다(미확인).

### 3.7 Amazon Alexa+ [제품 공식]

- OpenTable·Vagaro로 예약하고, 에이전트 기능으로 웹을 "보이지 않는 곳에서(behind the scenes)" 탐색해 일을 처리한다고 소개한다. 가족의 식성(채식·글루텐 제외) 같은 사실을 말로 기억시켜 추천에 쓴다. Echo 기기뿐 아니라 Alexa 앱과 Alexa.com에서도 쓴다(https://www.aboutamazon.com/news/devices/new-alexa-generative-artificial-intelligence).
- **시사점.** 음성 우선 비서도 결국 **화면(앱·웹)으로 결과와 기록을 확인하는 경로**를 둔다. "말로 기억시키기"는 설정 화면보다 진입 장벽이 낮다. 다만 저장 직후 "이렇게 기억했어요"라고 되읽어 주는 확인이 필요하다(Apple HIG ML: 명시적 피드백은 즉시 반영하고 유지할 것).

### 3.8 네이버지도 — 플레이스 에이전트 [언론, 회사 발표 인용]

- 2026-09-17 공개. 지도 앱 **검색창을 누르면 오른쪽에 나타나는 에이전트 버튼**, ‘음식점’ 검색 결과 사이의 **추천 질문**, 결과가 없을 때 나오는 **"AI 에이전트에게 물어보세요" 버튼**으로 들어간다. 구어체 문장과 한 문장 안의 여러 조건을 이해하는 것을 강점으로 내세운다. 네이버 예약을 쓰는 곳은 **날짜·시간·인원을 한 문장에 담아 예약 신청**까지 한다. 답변에는 장소 정보, 방문자 리뷰, 예약 가능 여부를 근거로 한 추천 이유가 붙고, **AI 안내 문구가 항상 표시**된다. 만 14세 이상 로그인 사용자 대상이다(https://byline.network/2026/09/17_naver_2/, https://ditoday.com/?p=153172).
- 2025-11 DAN25에서는 지도를 "발견, 예약, 이동, 리뷰"를 잇는 흐름으로 개편한다고 밝혔다. "예약, 알림, 변경, 관리"까지 하나로 잇는다는 설명이 있다(https://byline.network/2025/11/6-291/).
- **시사점.** ① 에이전트는 **기존 검색 흐름 안에 진입점을 여러 개** 심는다(검색창 옆, 결과 사이, 결과 없음 화면). ② 한국 사용자에게 "한 문장 예약"은 이미 익숙한 기대가 되었다. ③ 추천에는 **근거(리뷰·영업시간·예약 가능 여부)**를 붙인다. 콜비는 장소 검색을 직접 만들기보다 이 기대 수준에 맞추는 것이 중요하다.

### 3.9 카카오톡 — ChatGPT for Kakao, 카카오 툴즈, 탭 개편 [언론]

- 2025-10-28 시작. **채팅 탭 상단의 ChatGPT 버튼**으로 바로 쓰고, 답변을 채팅방에 공유하거나 대화 중에 바로 질문할 수 있다. 가입이나 로그인 없이도 써 볼 수 있다. **카카오 툴즈**가 카카오맵, 카카오톡 예약하기, 선물하기, 멜론을 부탁에 맞게 자동으로 연결한다(https://www.newsis.com/view/NISX20251028_0003379420).
- 2025-09 개편안: 채팅방 폴더와 ‘안읽음’ 폴더를 도입하고, 온디바이스 AI ‘카나나’가 일정·예약·구매를 추천·제안하며, 보이스톡 통화 녹음을 요약한다(https://www.mt.co.kr/tech/2025/09/23/2025092310345858683).
- 친구탭을 피드형으로 바꾼 개편은 반발을 샀고, 2025-12-16 업데이트(25.11.0)에서 **친구 목록을 기본 화면으로 되돌리고 피드는 ‘소식’ 선택지로** 옮겼다(https://mobile.newsis.com/view/NISX20251216_0003442706).
- **시사점.** ① 한국에서는 **대화 화면 안에서 서비스가 이어지는 방식**(채팅 → 예약하기·지도)이 익숙하다. ② **사용자가 매일 쓰는 기본 화면의 성격을 바꾸면 큰 반발**이 생긴다. 콜비가 출시 뒤 내비게이션을 바꿀 때는 기본값은 유지하고 새 화면을 선택지로 더해야 한다.

### 3.10 토스 — 제품 원칙과 라이팅 원칙 [제품 공식]

- **10가지 제품 원칙**(2025-09-17): Casual Concept(전문 용어 대신 일상어), Simple Policy(정책이 단순해야 화면도 단순하다), Value First(행동을 요구하기 전에 가치를 먼저 알린다), Clear Action(읽지 않아도 다음 행동이 보인다), Context Based(전체 여정을 설계한다), Easy to Answer(모든 질문에 3초 안에 답할 수 있게 하고, 어려우면 추천하고, 기억 못 하면 대신 찾아 준다. "어려운 질문 하나보다 쉬운 질문 셋, 질문이 없으면 가장 좋다"), Explain Why(왜 해야 하는지 설명한다), One Thing(한 화면에 핵심 메시지 하나), No More Loading(기다림을 없앤다), Minimum Features(https://toss.im/tossfeed/article/tossproductprinciples).
- 단순함의 정의: "알아야 할 것이나 배워야 할 것이 없고 본능적으로 이해할 수 있는 상태"(https://toss.im/tossfeed/article/importance-simplicity).
- **8가지 라이팅 원칙**(2022-11-15): Predictable hint(다음 화면을 예상할 수 있는 문장), Weed cutting(의미 없는 단어 제거), Remove empty sentences(허전해 보인다는 이유로 넣은 문장 제거), Focus on key message, Easy to speak(소리 내어 읽어도 어색하지 않게, 한자어·문어체·긴 호흡을 피한다), Suggest over force(강요나 공포 조성 금지), Universal words(유행어·은어 지양), Find hidden emotion(감정에 공감). 핵심 가치는 Clear·Concise·Casual·Respect·Emotional이다(https://toss.tech/article/8-writing-principles-of-toss).
- 40여 개 서비스가 "한 사람이 말하는 것 같은" 보이스톤을 유지하도록 라이팅 규칙을 디자인 시스템(TDS) 컴포넌트에 심었다(https://toss.im/tossfeed/article/uxwriter-interview).
- **시사점.** Easy to Answer는 계획 카드 설계 원칙으로 그대로 쓸 수 있다. "번호를 기억 못 하면 대신 찾아 주고, 질문은 최소로." Easy to speak는 **AI가 상대에게 말하는 문장**에도 적용된다(전화 대행에서는 화면 문구와 통화 음성이 같은 브랜드 목소리다).

### 3.11 배달의민족 — 탭 통합 [언론]

- 2025-01 발표. ‘음식배달’과 ‘가게배달’로 두 번 노출되던 같은 가게를 하나로 합치고, 배달 방식은 가게 상세 화면에서 고르게 했다. 이전 구조는 고객 혼선을 낳았다고 설명한다(https://news.mtn.co.kr/news-detail/2025013111355899370).
- **시사점.** 회사 내부의 처리 방식(배달 방식, 우리 경우에는 **전화 / 웹 / 커넥터**)으로 화면을 나누지 말고, 사용자의 목적(가게, 우리 경우에는 **장소·할 일**)으로 묶어야 한다. 콜비의 화면은 "전화 작업", "웹 작업"을 탭으로 나누지 말고 **하나의 작업**으로 보여 주고, 실행 수단은 작업 안의 단계로 드러내는 편이 낫다.

### 3.12 Uber·라이드셰어 진행 표시 [공식 가이드의 예시, 제품 사례는 미확인]

- Apple HIG는 Live Activity의 대표 예로 배달 도착 남은 시간과 라이드셰어를 든다. 기사를 찾는 동안에는 작게 보이다가 픽업 예정 시각이 나오면 커지는 식으로 **내용에 맞춰 높이를 바꾸라**고 한다(https://developer.apple.com/design/human-interface-guidelines/live-activities).
- Uber의 Live Activity 공학 블로그(uber.com)는 자동 접근이 막혀 열지 못했다(미확인).
- **시사점.** 전화 대행 작업은 "번호 확인 → 거는 중 → 통화 중 → 승인 대기 → 결과 정리"로 **단계가 분명하고 대개 몇 분이면 끝난다**. Live Activity·Live Update에 아주 잘 맞는 유형이다.

### 3.13 조사하지 못한 서비스

Airbnb, OpenTable, Resy, Google Maps 장소 카드, 카카오맵, 당근은 원문을 열어 화면 패턴을 확인하지 못했다. 근거로 쓰지 않았다(9장).

---

## 4. 공식 가이드라인 정리 (우리에게 해당하는 항목만)

### 4.1 Apple Human Interface Guidelines

| 가이드 | 우리에게 해당하는 항목 | 출처 |
|---|---|---|
| Generative AI | AI를 쓰는 곳을 분명히 밝히고, AI를 사람으로 착각하게 하지 않는다 · 사용자가 결정권을 갖고 되돌리거나 다시 시도할 수 있게 한다 · **되돌릴 수 없거나 문제가 될 수 있는 일은 결과를 고려해 허락을 받는다**(대리 구매 예시) · 생성 중에는 "처리 중…" 대신 구체적이고 안심되는 문구를 보여 준다 · 잘못되면 무슨 일이 있었는지 쉬운 말로 설명하고 다음 단계를 준다 · AI 없이 쓸 수 있는 대안을 둔다 · 할 수 있는 일과 없는 일을 미리 알린다 · 개인 정보를 쓰기 전에 허락을 받고, 서버로 보내는지 알린다 | https://developer.apple.com/design/human-interface-guidelines/generative-ai |
| Machine Learning | 실수의 결과가 얼마나 무거운지 파악하고, 그에 맞는 바로잡기 수단을 준다 · 사용자를 대신해 행동할 때는 특히 바로잡기가 쉬워야 한다 · 먼저 제안하는(proactive) 기능은 실수에 특히 조심한다(통제감을 잃게 만든다) · 결과가 나쁠 때는 이유를 설명한다 · 가능성이 높은 선택지를 먼저 보여 주되 너무 많이 주지 않는다 · 신뢰도는 사람이 이해하는 개념으로 바꿔 보여 준다 · 명시적 피드백은 즉시 반영하고 유지한다 | https://developer.apple.com/design/human-interface-guidelines/machine-learning |
| Live Activities | 시작과 끝이 분명하고 8시간을 넘지 않는 일에 쓴다 · 한눈에 필요한 정보(진행, 도착 예정 시각)에 집중한다 · 동작은 단순하게, 가능하면 하나만 둔다 · 같은 내용을 푸시 알림으로 중복해 보내지 않는다 · 잠금 화면에 보이므로 **민감한 정보는 빼고 무난한 요약**으로 보여 준다 · 앱 안에서 쉽게 끌 수 있게 한다 · 일이 끝나면 바로 종료한다 | https://developer.apple.com/design/human-interface-guidelines/live-activities |
| Managing notifications | 알림 전에 허락을 받는다 · 긴급도를 정확하게 표시해 신뢰를 쌓는다 · Time Sensitive는 지금 또는 1시간 안에 일어나는 일에만 쓰고 마케팅에는 쓰지 않는다 · 앱 안에 알림 설정 화면을 둔다 | https://developer.apple.com/design/human-interface-guidelines/managing-notifications |
| Privacy | 실제로 필요한 데이터만, 가능한 한 구체적으로 요청한다 · 기능을 실제로 쓸 때 요청하고, 실행 직후 요청은 피한다 · 사전 안내 화면에는 버튼 하나("계속" 등)만 둔다 · 목적 문장은 짧고 완결된 구체적 문장으로 쓴다 · 가능한 곳은 기기에서 처리한다 | https://developer.apple.com/design/human-interface-guidelines/privacy |
| Tab bars | 탭은 이동용이고 행동용이 아니다 · 쓸 수 없는 탭도 숨기지 말고 이유를 설명한다 · 배지는 중요한 정보에만 쓴다 · "더보기" 탭을 피한다 · 짧은 한 단어 라벨을 붙인다 | https://developer.apple.com/design/human-interface-guidelines/tab-bars |

### 4.2 Android / Material 3

| 가이드 | 우리에게 해당하는 항목 | 출처 |
|---|---|---|
| Live update notifications | 사용자가 시작한, 끝이 있고 추적할 수 있는 일에 쓴다 · 끝나는 시점이 불분명하면 쓰지 않는다 · 여러 앱의 정보를 묶지 않는다 · 사소한 변화에는 알리지 않는다 · 단계형이면 단계마다 이름을 붙이고, 막대형이면 채움이 남은 시간과 맞아야 한다 · 상태 표시줄 칩과 펼친 카드의 시간 형식을 맞춘다 · 사용자가 일시적으로 내리거나 일반 알림으로 낮출 수 있다 | https://developer.android.com/design/ui/mobile/guides/home-screen/live-updates |
| Layout and navigation patterns | 내비게이션 바는 같은 계층의 목적지 3~5개를 담는다 · 탭과 하단 앱 바는 보조 내비게이션이다 · 가장 중요한 행동은 FAB로 크게 보여 줄 수 있다 | https://developer.android.com/design/ui/mobile/guides/layout-and-content/layout-and-nav-patterns |
| Material 3 Expressive 연구 | 46건의 연구와 1만 8천 명 이상의 참가자를 바탕으로 했다 · 핵심 버튼(예: 보내기)을 크게 하고 키보드 바로 위에 두며 보조 색을 쓴 디자인에서 참가자가 버튼을 최대 4배 빨리 찾았다 · 45세 이상 사용자도 젊은 사용자만큼 빨리 핵심 요소를 찾았다 · 큰 버튼과 대비가 높은 묶음이 움직임·시각 능력이 다양한 사용자에게 도움이 되었다 · 진행 표시를 기다림이 짧게 느껴지는 쪽으로 평가했다 | https://design.google/library/expressive-material-design-google-research |

m3.material.io의 개별 컴포넌트 페이지는 열어 보지 않았다(미확인).

### 4.3 Google PAIR People + AI Guidebook

| 장 | 우리에게 해당하는 항목 | 출처 |
|---|---|---|
| Mental Models | 처음 쓸 때 할 수 있는 일, 할 수 없는 일, 앞으로 바뀔 수 있는 점, 더 좋게 만드는 법을 알린다 · **단계적으로 온보딩**한다 · 사람처럼 대화하는 제품에는 기대가 지나치게 높아지기 쉬우므로, 알고리즘이라는 성격과 한계를 알려 의도치 않은 기만을 피한다 | https://pair.withgoogle.com/chapter/mental-models/ |
| Explainability + Trust | 사용자가 신뢰를 **보정**하게 돕는다(언제 믿고 언제 스스로 판단할지) · 신뢰는 제품 경험 전체에 걸쳐 쌓인다 · 신뢰도를 보여 줄지, 언제 어떻게 보여 줄지가 판단에 큰 영향을 준다 | https://pair.withgoogle.com/chapter/explainability-trust/ |
| Feedback + Control | 알맞은 수준의 통제권이 있을 때 사용자는 시스템을 더 믿는다 · 통제와 자동화의 균형을 맞춘다 · 피드백을 받았다고 알리는 데서 그치지 말고, 다음에 무엇이 달라지는지 알린다 | https://pair.withgoogle.com/chapter/feedback-controls/ |
| Errors + Graceful Failure | 무엇이 오류인지는 사용자의 기대가 정한다 · 오류의 원인을 찾는다 · **실패 뒤에 나아갈 길을 준다** | https://pair.withgoogle.com/chapter/errors-failing/ |

### 4.4 Microsoft HAX — 인간-AI 상호작용 지침 18개

출처: https://www.microsoft.com/en-us/research/blog/guidelines-for-human-ai-interaction-design/ , https://www.microsoft.com/en-us/haxtoolkit/library/

| 시점 | 지침 | 콜비 적용 |
|---|---|---|
| 처음 | G1 할 수 있는 일을 분명히 · G2 얼마나 잘하는지 분명히 | 홈 빈 상태와 온보딩에 "할 수 있는 일·못 하는 일"을 쓴다. 결과 카드의 "확인 못 함" 상태로 실패할 수 있음을 드러낸다 |
| 사용 중 | G3 맥락에 맞춰 개입 시점을 정하기 · G4 지금 할 일에 관련된 정보 · G5 사회적 규범에 맞추기 · G6 사회적 편향 줄이기 | 승인 요청은 Time Sensitive 알림으로 보낸다. 상대방에게 AI임을 먼저 밝히고 한국어 존댓말 통화 예절을 지킨다 |
| 틀렸을 때 | G7 쉽게 부르기 · G8 쉽게 무시하기 · G9 쉽게 바로잡기 · G10 애매하면 범위를 좁히기 · G11 왜 그렇게 했는지 알 수 있게 | 계획 카드의 칸 단위 수정, 결과 카드의 "다시 걸기·조건 바꿔 다시", 번호 출처 표시("지난번 통화한 번호"), 애매하면 한 가지만 묻기 |
| 시간이 지나며 | G12 최근 상호작용 기억 · G13 행동에서 배우기 · G14 조심스럽게 바꾸기 · G15 세밀한 피드백 · G16 행동의 결과를 알리기 · G17 전체 통제 · G18 변경 사항 알리기 | 최근 장소, 기억 카드, 자율성 설정(전체 통제), 새 기능 안내 |

---

## 5. 패턴 라이브러리

각 패턴은 **이름 · 언제 쓰는가 · 장점 / 단점 · 대표 사례(출처) · 콜비 적용 메모** 순서로 적는다.

### 5.1 진입

**P1. 단일 부탁 입력(Single Composer)**
- 언제: 할 수 있는 일이 넓고, 사용자가 원하는 결과를 문장으로 말할 수 있을 때.
- 장점: 학습할 것이 없다(토스 단순함). 음성과 잘 맞는다. / 단점: 무엇을 부탁할 수 있는지 알기 어렵다(빈 입력칸 문제).
- 사례: AI Mode 자연어 부탁(3.2), ChatGPT agent 입력창(3.1), 네이버 한 문장 예약(3.8).
- 메모: 현재 홈의 입력칸을 유지한다. 그 아래에 **예시 칩**과 **최근 장소**를 두어 빈 입력칸 문제를 줄인다(이미 구현됨). 마이크 버튼을 입력칸 안에 둔다.

**P2. 맥락 진입점(Contextual Entry)**
- 언제: 사용자가 이미 다른 화면(장소, 일정, 메일)에서 일의 대상을 보고 있을 때.
- 장점: 대상이 정해져 있어 확인할 칸이 준다. / 단점: 진입점이 흩어진다.
- 사례: 네이버지도 검색창 옆 버튼, 결과 사이 추천 질문, "결과 없음" 화면 버튼(3.8). 카카오톡 채팅 탭 상단 버튼(3.9).
- 메모: 결과 카드("다시 걸기"), 장소 상세("여기에 전화로 물어보기"), 공유 시트(다른 앱의 장소 링크를 콜비로 보내기)에 진입점을 둔다. **"결과 없음"·"실패" 화면도 진입점**이다.

**P3. 저장한 부탁(Saved Prompt / 템플릿)**
- 언제: 같은 일을 반복할 때.
- 사례: Operator가 홈에 부탁을 저장하는 기능(3.1), ChatGPT 반복 설정(3.1).
- 메모: 현재 "이런 부탁도 할 수 있어요" 칩은 일반 예시다. 사용자가 끝낸 작업에서 **"자주 하는 부탁으로 저장"**을 추가한다.

**P4. 기능 격자(Action Grid)** — 비권장
- 장점: 할 수 있는 일이 한눈에 보인다. / 단점: 실행 수단별로 화면이 나뉘어 배민의 중복 탭 문제(3.11)와 같은 혼선이 생긴다. 기능이 늘수록 복잡해진다(토스 Minimum Features).
- 메모: 홈 첫 화면에는 쓰지 않는다. 온보딩이나 "무엇을 할 수 있나요?" 도움말 화면에서만 쓴다.

### 5.2 의도 확인

**P5. 구조화된 계획 카드(Editable Slots)**
- 언제: 자유 문장을 실행하기 전에.
- 장점: 오해를 실행 전에 잡는다(HAX G9·G10). 수정이 칸 단위라 빠르다. / 단점: 칸이 많으면 부담된다.
- 사례: Chrome·Gemini의 계획 검토(3.2), AI Mode의 요청 검토(3.2).
- 메모: 현재 계획 카드(전화할 곳, 번호, 부탁할 일, 조건, 알려줘도 되는 정보, 통화 언어, 내 이름)는 이 패턴을 잘 따른다. 다만 토스 Easy to Answer에 따라 **기본값이 확실한 칸(통화 언어, 내 이름)은 접어서 요약 한 줄**로 둔다. 확인이 필요한 칸만 펼친다.

**P6. 최소 추가 질문(One Question at a Time)**
- 언제: 꼭 필요한 정보가 빠졌을 때.
- 사례: AI Mode의 짧은 추가 질문(3.2). 토스 "어려운 질문 하나보다 쉬운 질문 셋, 없으면 가장 좋다".
- 메모: 지금의 "번호가 없을 때만 번호 칸 하나"가 이 패턴이다. 웹 작업으로 넓힐 때도 **한 번에 한 질문**을 지킨다.

**P7. 전달 범위 미리 보기(What will be shared)**
- 언제: 상대(업체·웹사이트)에게 사용자 정보를 넘길 때.
- 사례: AI Mode "공유하고 확인한 정보만 업체에 전달"(3.2).
- 메모: 계획 카드의 "알려줘도 되는 정보" 칸을 **"상대에게 알려 줄 정보"**로 이름을 바꾸고, 기억에서 가져온 항목에는 출처 표시를 붙인다.

**P8. 예상 소요 시간 안내(Time Expectation)**
- 언제: 결과가 몇 분 넘게 걸릴 때.
- 사례: AI Mode "웹 결과는 몇 분, 전화 결과는 최대 30분"(3.2).
- 메모: [이대로 시작] 버튼 위에 "보통 3~5분 걸려요. 끝나면 알려 드릴게요"를 적는다. 시간 값은 실측으로 정한다.

### 5.3 진행 표시

**P9. 단계형 타임라인(Step Timeline)**
- 언제: 단계가 분명한 일.
- 장점: 지금 어디쯤인지 알 수 있다. / 단점: 단계가 자주 바뀌면 혼란스럽다.
- 사례: Android Live Updates "단계형이면 단계마다 이름을"(4.2), Apple "구체적인 진행 문구"(4.1).
- 메모: 통화 상세 상단에 `준비 → 거는 중 → 통화 중 → 결과 정리` 4단계를 둔다. 웹 작업도 같은 틀(`준비 → 사이트 여는 중 → 입력 중 → 확인 대기 → 완료`)을 쓴다.

**P10. 진행 내레이션 + 행동 기록(Narration & Trace)**
- 언제: AI가 사용자 대신 화면을 조작하거나 대화할 때.
- 사례: ChatGPT agent의 화면 내레이션(3.1), Comet의 옆 패널 행동 기록(3.5).
- 메모: 전화는 이미 **실시간 대화 기록**이 이 역할을 한다. 웹 작업은 "페이지 열었어요 → 날짜 골랐어요 → 출석 버튼 눌렀어요"처럼 **한 줄씩 쌓이는 기록**과 스크린숏 썸네일로 보여 준다.

**P11. 앱 밖 실시간 상태(Live Activity / Live Update)**
- 언제: 사용자가 앱을 떠나도 몇 분 안에 끝나는 일.
- 사례: Apple HIG Live Activities, Android Live Updates(4.1, 4.2), Gemini의 Live Update 알림 "진행 보기 / 작업 중지"(3.2).
- 메모: **콜비에 가장 효과가 큰 신규 패턴이다.** 잠금 화면에는 "라 파스타에 전화 중 · 1:24"처럼 무난한 요약만 보여 준다(민감한 내용은 빼라는 HIG). 동작은 "열기" 하나 또는 "끊기" 하나로 둔다. 통화가 끝나면 바로 종료한다.

**P12. 화면 상태 색조(Agent-at-work Tint)**
- 언제: AI가 조작하는 화면과 사용자가 조작하는 화면을 구분해야 할 때.
- 사례: Comet의 브라우저 색조(3.5).
- 메모: 웹 작업 화면에서 AI가 조작하는 동안에는 테두리와 상단 띠를 표시한다. 사용자에게 넘긴 뒤에는 띠를 거둔다.

### 5.4 승인·위임

**P13. 고정 승인 카드(Pinned Approval)**
- 언제: 진행 중인 일에서 사용자 결정이 필요할 때.
- 사례: 결과가 남는 행동 전 명시적 확인(3.1, 3.2, Apple HIG).
- 메모: 현재 승인 카드(가장 큰 글자 = 질문, 빠른 답 칩, 조건 덧붙이기, 만료 = 거절)는 업계 기준보다 앞서 있다. 유지한다.

**P14. 범위가 정해진 승인(Bounded Approval)**
- 언제: 금액·조건이 바뀔 수 있는 결정.
- 사례: Google Pay 대리 결제, 확인한 총액과 같거나 낮을 때만 결제(3.2).
- 메모: 승인 카드에 "**1만 원까지 허락**" 같은 상한 선택지를 칩으로 둔다. 상한을 넘으면 다시 묻는다. 계획 카드의 "조건"과 같은 데이터로 묶는다.

**P15. 손 넘기기(Takeover / Hand-off)**
- 언제: 로그인, 결제 정보, CAPTCHA, 본인 인증.
- 사례: Operator·ChatGPT 넘겨받기와 그동안 기록 중지(3.1), Gemini "직접 조작"과 10분 시간 제한(3.2), Chrome "작업 넘겨받기"(3.2).
- 메모: 웹 작업에 꼭 필요하다. 화면 구성: ① "여기서부터는 직접 해 주세요" 안내와 이유(토스 Explain Why), ② 사용자가 조작하는 동안 **기록하지 않는다는 표시**, ③ "다 했어요, 이어서 해 주세요" 주 버튼, ④ 남은 시간. 한국 서비스의 본인 인증(PASS, 간편 인증)은 거의 다 이 패턴으로 처리해야 한다(설계 가정, 검증 필요).

**P16. 지켜보기 모드(Watch Mode)**
- 언제: 메일 발송, 금융처럼 민감한 사이트.
- 사례: ChatGPT agent·Operator의 Watch Mode(3.1).
- 메모: 메일 커넥터로 **보내기**를 할 때는 초안을 보여 주고 사용자가 보내기를 누르게 한다. 앱을 떠나면 작업을 멈춘다.

**P17. 자율성 단계(Autonomy Dial)**
- 언제: 사용자마다 맡기고 싶은 정도가 다를 때.
- 사례: HAX G17 "전체 통제". PAIR "통제와 자동화의 균형". 지출 한도 안에서 Gemini가 스스로 진행하게 한다는 보도는 원문을 열지 못했다(미확인).
- 메모: 출시 때는 단계를 두 개만 둔다. "**매번 계획 보고 시작**"(기본)과 "**저위험 확인 전화는 바로 걸기**"(영업시간·재고 문의 등). 돈·약정은 어느 단계에서도 승인을 받는다(EPIC D4 유지).

### 5.5 결과와 후속 행동

**P18. 3단 결과 카드(Done / Unverified / Next)**
- 언제: 작업이 끝났을 때.
- 사례: Apple HIG "오류 가능성 안내 · 실패 시 쉬운 말과 다음 단계", PAIR "실패 뒤 나아갈 길"(4.1, 4.3).
- 메모: 현재 결과 카드(목표 달성/일부/실패/미확인, 알아낸 내용, 해야 할 일, 후속 행동)를 유지한다. 웹 작업 결과에는 **증거**(확인 화면 스크린숏, 예약 번호)를 붙인다.

**P19. 연결된 후속 행동(Connected Follow-up)**
- 언제: 결과가 다른 앱의 일로 이어질 때(일정, 지도, 공유).
- 사례: 카카오 툴즈가 카카오맵·예약하기로 자동 연결(3.9), 네이버 "예약·알림·변경·관리"를 하나로(3.8).
- 메모: "캘린더 파일 보내기"는 커넥터 연결 뒤 "**캘린더에 추가**"(쓰기 전 확인)로 바꾼다. "길 찾기"는 지도 앱으로 넘긴다. 후속 행동은 **최대 4개**만 두고, 가장 가능성이 높은 것을 주 버튼으로 둔다(Apple HIG ML "가능성 높은 것 먼저, 너무 많지 않게").

### 5.6 기록·작업함

**P20. 상태별 작업함(Task Inbox)**
- 언제: 작업이 여러 개 쌓이고, 일부는 사용자 차례일 때.
- 사례: ChatGPT "Scheduled" 목록(3.1), AI Mode 기록의 파란 점(3.2), 카카오톡 ‘안읽음’ 폴더(3.9).
- 메모: 작업함 맨 위에 **"내 차례"(승인·손 넘기기 대기)** 묶음을 두고, 이어서 진행 중, 끝남(새 결과 점 표시), 반복 순으로 둔다. 탭 배지는 "내 차례"에만 쓴다(Apple HIG Tab bars "배지는 중요한 정보에만").

### 5.7 신뢰·투명성

**P21. 상시 AI 고지와 할 수 있는 일 안내**
- 사례: 네이버 플레이스 에이전트 답변에 AI 안내 문구를 항상 표시(3.8), AI Mode "AI 응답에 실수가 있을 수 있어요"(3.2), Apple HIG "AI를 쓰는 곳을 분명히".
- 메모: 현재 통화 중 신뢰 줄("AI 비서는 AI임을 밝히도록 정해져 있어요 · 대화는 글로 기록돼요")을 유지한다.

**P22. 오작동 예시를 숨기지 않기**
- 사례: Gemini 도움말이 잘못된 버튼 누르기, 허락 없는 주문 같은 위험을 사용자에게 직접 설명(3.2). ChatGPT 도움말의 프롬프트 주입 예시(3.1).
- 메모: 설정의 "안전하게 쓰는 법" 화면에 **AI가 실수할 수 있는 예 3가지와 그때 할 일**을 쓴다.

### 5.8 기억·연결·권한

**P23. 주제 단위 기억 카드**
- 사례: Claude의 주제 단위 기억, 일시정지, 임시 대화(3.4). Alexa+의 말로 기억시키기(3.7).
- 메모: "내 정보" 화면에 기억을 `나에 대해`, `자주 가는 곳`, `회원번호·예약 정보`, `말투·선호`로 나눠 카드로 보여 준다. 각 카드는 수정·삭제할 수 있다. 작업에 기억을 썼다면 작업 기록에 "기억해 둔 회원번호를 썼어요"를 남긴다.

**P24. 필요할 때 요청하는 권한(Just-in-time Permission)**
- 사례: Apple HIG Privacy(4.1), ChatGPT의 알림 권한 흐름(3.1).
- 메모: 첫 실행 때 권한을 한꺼번에 묻지 않는다. 알림 권한은 **첫 작업을 시작할 때** "통화 중에 확인할 일이 생기면 알려 드릴게요"라는 사전 안내(버튼 하나)와 함께 요청한다. 캘린더 권한은 첫 "캘린더에 추가" 때, 연락처는 계획 카드의 번호 칸에서 요청한다.

### 5.9 음성

**P25. 대화 모드 음성(Live Voice)**
- 사례: Gemini Live의 끼어들기, 보류, 음성과 글 오가기(3.3).
- 메모: 1단계는 입력칸의 받아쓰기로 충분하다. 2단계에서 "말로 부탁하기" 대화 모드를 더하되, 결과는 언제나 **같은 계획 카드**로 모은다.

### 5.10 빈 상태·접근성

**P26. 할 일을 알려 주는 빈 상태**
- 사례: 네이버 "결과 없음 → AI에게 물어보세요"(3.8), HAX G1.
- 메모: 홈 빈 상태는 "할 수 있는 일 3가지 예시 + 입력칸"으로 둔다(현재 문구 유지 가능). 작업함 빈 상태는 "아직 맡긴 일이 없어요"와 예시 칩 하나로 둔다.

**P27. 큰 핵심 버튼과 높은 대비**
- 사례: M3 Expressive 연구, 핵심 버튼을 크게 하면 찾는 속도가 빨라지고 45세 이상의 차이가 사라짐(4.2).
- 메모: 계획 카드 [이대로 시작], 승인 카드 [승인]/[거절], 손 넘기기 [이어서 해 주세요]는 화면 아래 고정, 높이 52 이상(현재 토큰 유지)으로 둔다. 전화 대행의 핵심 사용자층에 중장년이 포함될 가능성이 높으므로 글자 크기 2.0 대응을 유지한다(SPEC-UX-001 REQ-011).

---

## 6. 한국 사용자 UX 관례

| 관례 | 근거 | 콜비 적용 |
|---|---|---|
| **해요체와 쉬운 말** | 토스는 모든 화면 문구를 한 사람이 말하는 듯한 보이스톤으로 맞춘다. Easy to speak 원칙은 소리 내어 읽어도 어색하지 않게, 한자어·문어체·긴 호흡을 피하라고 한다(https://toss.tech/article/8-writing-principles-of-toss, https://toss.im/tossfeed/article/uxwriter-interview) | 화면 문구는 해요체(EPIC D11 유지). "승인"·"거절" 같은 버튼 라벨은 짧아서 그대로 둔다. 설명 문장은 "~돼요/~할게요"로 쓴다. **통화 음성과 화면 문구의 말투를 맞춘다** |
| **한 화면 한 메시지, 쉬운 질문** | 토스 One Thing, Easy to Answer(https://toss.im/tossfeed/article/tossproductprinciples) | SPEC-UX-001 원칙 1 "한 화면에 한 가지 결정"과 같다. 유지한다 |
| **강요하지 않는 문구** | 토스 Suggest over force | 승인 카드의 남은 시간은 압박하지 않는 말투로 쓴다("상대방이 기다리고 있어요"는 적절하다). 이탈 막기 문구("지금 나가면 손해예요")는 쓰지 않는다 |
| **정보 밀도** | 국내 대형 앱은 홈에 여러 묶음(최근, 추천, 진행 중)을 함께 보여 준다. 다만 배민은 중복 노출을 혼선으로 보고 줄였다(https://news.mtn.co.kr/news-detail/2025013111355899370) | 홈에는 입력칸, 내 차례·진행 중 작업(있을 때만), 최근 장소 3개, 예시 칩까지만 둔다. 지난 작업 전체는 작업함으로 옮긴다 |
| **하단 탭 3~5개, 익숙한 기본 화면 유지** | Android 내비게이션 바 3~5개(4.2), Apple "더보기 탭 피하기"(4.1), 카카오톡 친구탭 원상 복귀(https://mobile.newsis.com/view/NISX20251216_0003442706) | 출시 때 탭은 3개로 시작하고, 이후 늘리더라도 기본 화면(부탁 입력)은 바꾸지 않는다 |
| **대화 안에서 서비스가 이어짐** | 카카오톡 ChatGPT의 카카오 툴즈(https://www.newsis.com/view/NISX20251028_0003379420) | 결과를 카카오톡으로 공유하는 기능을 1순위 후속 행동으로 둔다(현재 "공유" 유지). 공유 문구는 받는 사람이 앱 없이도 읽을 수 있게 쓴다 |
| **한 문장 예약 기대** | 네이버 플레이스 에이전트의 날짜·시간·인원 한 문장 예약(https://byline.network/2026/09/17_naver_2/) | 홈 입력칸 예시를 "금요일 7시 2명, 라 파스타 예약해 줘"처럼 한 문장 형태로 둔다 |
| **AI 안내 상시 표시** | 네이버 답변의 AI 안내 문구 상시 표기(같은 출처) | 결과 카드·공유 문구에 "AI 비서가 통화해 정리했어요"를 넣는다 |
| **본인 인증·간편 결제** | (설계 가정) 국내 웹 작업은 본인 인증과 간편 결제 화면을 거치는 경우가 많다. 이 문서에서는 확인하지 않았다 | 손 넘기기 패턴(P15)을 기본 경로로 설계한다 |

---

## 7. 현재 CallMate UI 진단

근거: `app/lib/features/calls/presentation/home_screen.dart`, `plan_card_screen.dart`, `call_detail_screen.dart`, `widgets/approval_card.dart`, `widgets/follow_up_actions.dart`, `trust_notice.dart`, `.moai/specs/SPEC-UX-001/design.md`

### 7.1 유지할 것

| 항목 | 현재 | 근거 |
|---|---|---|
| 단일 입력 홈("무엇을 도와드릴까요?") + 최근 장소 + 예시 칩 | `home_screen.dart`, design.md §7.1 | P1, 토스 단순함 |
| 계획 카드의 칸 단위 수정, 번호 출처 표시("지난번 통화한 번호") | `plan_card_screen.dart`, design.md §7.2 | P5, HAX G9·G11 |
| 번호가 없을 때만 한 번 묻기 | design.md §7.2 | P6, 토스 Easy to Answer |
| 승인 카드: 질문이 가장 큰 글자, 빠른 답 칩, 조건 덧붙이기, 민감 정보 안내, 만료 = 거절 | `approval_card.dart`, design.md §7.3 | P13, Apple HIG "중요한 행동 전 허락" |
| 결과 카드의 4가지 상태와 "확인 못 함"을 확정처럼 보이지 않게 하는 규칙 | design.md §7.4, EPIC D5 | P18, PAIR 신뢰 보정 |
| "통화 중 결정한 것" 기록과 "사용자 안내" 줄 | `call_detail_screen.dart` | HAX G11, P10 |
| 분위기 색(주의 색은 승인 카드에만, 위험 색은 실패·끊기에만), 움직임 줄이기 대응, 화면 읽기 알림(30초·10초) | design.md §3, §6, §7.3 | Apple HIG "긴급도를 정확히", 접근성 |
| 해요체·생활어 상태 문구("전화 거는 중") | design.md §1 | 6장 |

### 7.2 바꿀 것

| # | 문제 | 근거 | 제안 |
|---|---|---|---|
| C1 | **앱을 열어 둬야 승인 카드가 뜬다**(푸시 없음, EPIC §6) | Apple HIG 알림·Live Activities, Android Live Updates, Gemini의 Live Update "진행 보기" | 승인 요청은 Time Sensitive 알림으로 보낸다. 통화 진행은 Live Activity·Live Update로 보여 준다. 승인 제한 시간(현재 수십 초)은 알림을 보고 앱을 여는 시간을 고려해 다시 정한다 |
| C2 | 화면 이름과 문구가 "통화"에 묶여 있다(앱 제목 "CallMate", "최근 통화한 곳", "통화를 찾을 수 없어요") | 배민 탭 통합(3.11), 목적 중심 구성 | 상위 개념을 **"작업"**으로 바꾼다. 통화는 작업의 한 단계로 둔다. "최근 통화한 곳"은 "최근 장소"로 바꾼다 |
| C3 | 홈에 진행 중·지난 작업 목록까지 모두 있다 | 토스 One Thing, Apple 탭 바 | 홈에는 **내 차례·진행 중 작업만** 남기고, 지난 작업은 작업함 탭으로 옮긴다 |
| C4 | 계획 카드의 칸 7개가 모두 같은 무게로 보인다(통화 언어, 내 이름 포함) | 토스 Easy to Answer, Apple HIG ML "선택지를 너무 많이 주지 말 것" | 확인이 필요한 칸(대상, 번호, 부탁, 조건)만 펼친다. 나머지는 "한국어로, 김민수 이름으로 걸어요 ›" 한 줄로 접는다 |
| C5 | 첫 통화 때 계획 카드 [이대로 시작]과 신뢰 안내 [확인했어요]를 두 번 누른다(EPIC §7 위험) | Apple HIG Privacy "사전 안내는 버튼 하나", PAIR "단계적 온보딩" | 신뢰 안내를 **온보딩 3장 중 1장**으로 옮기거나, 계획 카드 아래 접힌 안내 한 줄로 합친다. 첫 통화 확인은 한 번으로 줄인다 |
| C6 | 진행 단계가 문구로만 바뀐다(계획 세우는 중 / 전화 거는 중 / 결과 정리 중) | Android "단계형이면 단계마다 이름", Apple "구체적 진행 문구" | 통화 상세 상단에 단계형 타임라인(P9)을 두고, 같은 단계 이름을 Live Activity에도 쓴다 |
| C7 | 후속 행동이 "캘린더 파일 보내기"처럼 기술 용어다 | 토스 Casual Concept | 커넥터 전에는 "일정 파일 저장"으로, 커넥터 뒤에는 "캘린더에 추가"로 바꾼다. 가장 가능성 높은 행동 하나를 주 버튼으로 둔다 |
| C8 | 설정에 서버 주소 같은 개발용 항목이 있다(오류 문구 "설정에서 서버 주소를 확인해 주세요") | Apple HIG "할 수 없는 일은 이유를 설명", 상용 출시 | 상용 빌드에서는 서버 설정을 숨기고, 오류는 "잠시 연결이 안 돼요. 다시 시도해 주세요"로 바꾼다 |
| C9 | 기억이 "최근 통화한 곳"뿐이고 보거나 지우는 화면이 없다 | Claude 기억 관리(3.4), HAX G12·G17 | "내 정보" 탭에 기억 카드(P23)를 둔다 |
| C10 | 음성 입력이 없다 | Gemini Live(3.3) | 1단계로 입력칸에 받아쓰기 버튼을 넣는다 |
| C11 | 웹 작업·손 넘기기 화면이 없다 | Operator·Gemini·Chrome(3.1, 3.2) | 8.3의 "손 넘기기" 화면을 새로 둔다 |
| C12 | 씨앗 색 하나에서 만든 기본 테마다(시각 정체성이 약함) | M3 Expressive "핵심 행동을 크기·색·모양으로 돋보이게" | 브랜드 색은 유지하되, **주 버튼과 승인 카드에만** 강조 모양·색을 쓴다(SPEC-UX-001 원칙 3과 같은 방향) |

---

## 8. 우리 서비스 UI/UX 방향 제안

### 8.1 설계 원칙 (콜비용 6개)

1. **한 칸으로 부탁하고, 한 장으로 확인한다.** 입력은 자유롭게 받고, 확인은 계획 카드 한 장으로 한다.
2. **돈·약정·발송·로그인에서만 멈춘다.** 그 밖의 단계는 묻지 않고 진행하되 기록은 남긴다.
3. **내 차례는 앱 밖에서도 보인다.** 승인과 손 넘기기는 알림과 실시간 상태로 알린다.
4. **결과는 확인된 것과 아닌 것을 나눈다.** 확인 못 한 결과는 절대 확정처럼 보이지 않는다.
5. **사용자가 보고 지울 수 있는 것만 기억한다.**
6. **쉬운 말, 같은 목소리.** 화면 문구와 AI의 통화 말투가 같은 사람처럼 들리게 한다.

### 8.2 내비게이션 구조 후보

| 후보 | 구조 | 장점 | 단점 | 맞는 경우 |
|---|---|---|---|---|
| **A. 부탁 홈 + 작업함 (3탭)** | `홈`(입력, 내 차례, 진행 중, 최근 장소) · `작업함`(내 차례 / 진행 중 / 끝남 / 반복) · `내 정보`(기억, 연결한 앱, 알림, 안전, 설정) | 현재 구조를 거의 그대로 확장한다. 작업 상태가 분명하다. 탭 3개는 플랫폼 권장 범위의 최소다 | 대화형 비서다운 느낌은 약하다 | 출시 첫 버전, 전화 대행이 주력일 때 |
| **B. 대화 홈 (2탭 + 작업 카드)** | `비서`(하나의 대화 흐름 안에 계획 카드·진행 카드·결과 카드가 쌓임) · `내 정보` + 상단에 작업함 버튼 | 질문, 장소 찾기, 후속 부탁이 자연스럽게 이어진다. 카카오톡식 사용 습관에 맞는다 | 진행 중인 작업이 대화에 묻힌다. 기록 찾기가 어렵다. 구현 범위가 크다 | 정보 질문·장소 탐색 비중이 커질 때 |
| **C. 4탭 확장형** | `홈` · `장소`(저장한 곳, 찾기) · `작업함` · `내 정보` | 장소 탐색이 앞에 나온다 | 장소 검색 품질이 네이버·카카오에 못 미치면 빈 탭이 된다. 탭이 늘어난다 | 장소 데이터·검색 제휴가 확보된 뒤 |

**권고: A로 출시하고, 홈 입력 결과를 B처럼 "카드가 쌓이는 대화형"으로 보여 주는 혼합형.** 사용자가 매일 보는 기본 화면(부탁 입력)은 처음부터 고정한다(카카오톡 교훈). 장소 탭(C)은 검색 제휴가 생긴 뒤 선택지로 추가한다.

```
[후보 A 혼합형: 일반 패턴 스케치]
┌──────────────────────────────────────┐
│ 콜비                                  │
│ ┌──────────────────────────────────┐ │
│ │ 무엇을 맡길까요?            🎤  ➤ │ │  단일 입력 + 받아쓰기
│ └──────────────────────────────────┘ │
│ (금요일 7시 2명 예약) (영업시간 문의) │  예시 칩
│                                      │
│ 내 차례 1                            │  있을 때만, 주의 색
│ ┌ 예약금 1만 원, 진행할까요? 0:40 ─┐ │
│ 진행 중                              │
│ ┌ ○ 미용실 · 통화 중 ●──○──○ ──────┐ │  단계 표시
│ 최근 장소  라 파스타 · 치과 · 미용실 │
├──────────────────────────────────────┤
│   홈          작업함(1)      내 정보  │  배지는 '내 차례'에만
└──────────────────────────────────────┘
```

### 8.3 핵심 화면 후보

| # | 화면 | 핵심 내용 | 관련 패턴 |
|---|---|---|---|
| S1 | **홈** | 입력칸(받아쓰기), 예시 칩, 내 차례·진행 중 작업(있을 때만), 최근 장소 | P1, P3, P20 |
| S2 | **계획 카드** | 확인할 칸만 펼침, 기본값은 한 줄 요약, "상대에게 알려 줄 정보", 예상 소요 시간, [이대로 시작] | P5~P8 |
| S3 | **작업 상세(진행 중)** | 단계 타임라인, 실시간 대화 기록 또는 웹 행동 기록, 하단 고정 승인 카드, [끊기]/[중지] | P9, P10, P13, P14 |
| S4 | **손 넘기기** | "여기서부터는 직접 해 주세요"와 이유, 기록 중지 표시, [다 했어요, 이어서 해 주세요], 남은 시간 | P15, P16 |
| S5 | **결과 카드** | 상태(달성/일부/실패/확인 못 함), 확인된 내용, 증거(대화 발췌·예약 번호·스크린숏), 다음 할 일, 주 후속 행동 1개 + 보조 3개 | P18, P19 |
| S6 | **작업함** | 내 차례 / 진행 중 / 끝남(새 결과 점) / 반복. 길게 눌러 반복·삭제 | P20, P3 |
| S7 | **잠금 화면 실시간 상태·알림** | 단계 이름과 경과 시간, 민감 정보 제외, 승인 요청은 Time Sensitive, 끝나면 바로 종료 | P11 |
| S8 | **내 정보** | 기억 카드(주제별 수정·삭제·일시정지), 연결한 앱(권한 범위·해제), 자율성 2단계, 알림 설정, "안전하게 쓰는 법" | P17, P22, P23, P24 |
| S9 | **온보딩(3장)** | ① 할 수 있는 일·못 하는 일 ② AI가 상대에게 AI임을 밝히고 중요한 결정은 묻는다는 약속 ③ 이름 입력. 권한은 여기서 묻지 않는다 | PAIR 단계적 온보딩, HAX G1·G2, Apple Privacy |

```
[S4 손 넘기기: 일반 패턴 스케치]
┌──────────────────────────────────────┐
│ ● 여기서부터는 직접 해 주세요   9:41 │  남은 시간
│ 본인 인증은 직접 하셔야 해요.        │  이유(Explain Why)
│ 지금 화면은 기록하지 않아요.         │  기록 중지 표시
│ ┌──────────────────────────────────┐ │
│ │       (웹 페이지 영역)            │ │  AI 조작 표시 띠 없음
│ └──────────────────────────────────┘ │
│ [ 그만두기 ]   [ 다 했어요, 이어서 ] │  주 버튼 하나
└──────────────────────────────────────┘
```

### 8.4 우선순위 제안

1. **승인 알림 + 실시간 상태(C1, S7).** 전화 대행의 핵심 순간을 앱 밖으로 꺼낸다. 효과가 가장 크다.
2. **"작업" 중심 이름과 3탭 구조(C2, C3, S1, S6).** 웹 작업·커넥터를 더하기 전에 틀을 먼저 바꾼다.
3. **계획 카드 다이어트와 첫 실행 확인 한 번으로 줄이기(C4, C5).**
4. **손 넘기기 화면(S4).** 웹 작업(출석 체크 등)의 선행 조건이다.
5. **기억·연결 관리(S8)와 받아쓰기(C10).**

---

## 9. 미확인 항목

| 항목 | 상태 | 비고 |
|---|---|---|
| Uber Live Activity 공학 블로그(uber.com/blog/live-activity-on-ios) | 자동 접근 차단으로 열지 못함 | 검색 요약에는 별도 타깃·네트워크 제한 내용이 있었으나 근거로 쓰지 않음 |
| Uber·Uber Eats Live Activity 출시 시점(MacRumors 등) | 검색 요약만 봄 | — |
| Perplexity Comet의 2025-11 투명성·위험 단계 정지 업데이트 | 검색 요약만 봄 | MIT AI Agent Index 내용만 사용 |
| Gemini 에이전트의 지출 한도 안 자동 진행(AP2 관련 보도) | 검색 요약만 봄 | — |
| ChatGPT Work의 화면 구성 | 확인 안 함 | OpenAI 도움말에 "ChatGPT agent는 더 이상 제공되지 않음"이라는 문장만 확인 |
| Microsoft Copilot Actions의 현재 이름·상태, 확인 화면 세부 | 확인 안 함 | Windows Central 2025-04 기사만 사용 |
| Alexa+ 2025-12 제휴 확대(Expedia, Yelp 등) | 검색 요약만 봄 | — |
| Apple Intelligence·Siri 관련 HIG(App Intents 등) | 확인 안 함 | 생성형 AI·ML 페이지만 사용 |
| Material 3 컴포넌트 페이지(m3.material.io) | 열지 않음 | Android 개발자 디자인 가이드와 design.google 연구 글만 사용 |
| Airbnb, OpenTable, Resy, Google Maps 장소 카드, 카카오맵, 당근의 화면 패턴 | 확인 안 함 | 근거로 쓰지 않음 |
| 카나나 정식 출시 여부, 카카오톡 탭 구조의 2026년 상태 | 확인 안 함 | 2025-09~12 기사만 사용 |
| 배민 2025-09 이후 앱 개편 테스트 결과 | 검색 요약만 봄 | 2025-01 탭 통합 기사만 사용 |
| 한국 웹 작업의 본인 인증·간편 결제 흐름 | 조사하지 않음 | 6장의 "설계 가정" |
| 각 제품의 실제 화면(버튼 위치, 색, 애니메이션) | 관찰하지 않음 | 앱을 설치해 보지 않았음 |

---

## 10. 출처 목록

모두 2026-11-25에 직접 열어 확인했다.

**공식 가이드**
1. Apple HIG — Generative AI: https://developer.apple.com/design/human-interface-guidelines/generative-ai
2. Apple HIG — Machine learning: https://developer.apple.com/design/human-interface-guidelines/machine-learning
3. Apple HIG — Live Activities: https://developer.apple.com/design/human-interface-guidelines/live-activities
4. Apple HIG — Managing notifications: https://developer.apple.com/design/human-interface-guidelines/managing-notifications
5. Apple HIG — Privacy: https://developer.apple.com/design/human-interface-guidelines/privacy
6. Apple HIG — Tab bars: https://developer.apple.com/design/human-interface-guidelines/tab-bars
7. Android Developers — Live update notifications: https://developer.android.com/design/ui/mobile/guides/home-screen/live-updates
8. Android Developers — Layouts and navigation patterns: https://developer.android.com/design/ui/mobile/guides/layout-and-content/layout-and-nav-patterns
9. Google Design — Expressive Material Design research: https://design.google/library/expressive-material-design-google-research
10. Google PAIR — Mental Models: https://pair.withgoogle.com/chapter/mental-models/
11. Google PAIR — Explainability + Trust: https://pair.withgoogle.com/chapter/explainability-trust/
12. Google PAIR — Feedback + Control: https://pair.withgoogle.com/chapter/feedback-controls/
13. Google PAIR — Errors + Graceful Failure: https://pair.withgoogle.com/chapter/errors-failing/
14. Microsoft Research — Guidelines for human-AI interaction design: https://www.microsoft.com/en-us/research/blog/guidelines-for-human-ai-interaction-design/
15. Microsoft HAX Toolkit — Design Library: https://www.microsoft.com/en-us/haxtoolkit/library/

**제품 공식 도움말·발표**
16. OpenAI Help — ChatGPT agent: https://help.openai.com/en/articles/11752874-chatgpt-agent
17. OpenAI — Introducing ChatGPT agent: https://openai.com/index/introducing-chatgpt-agent/
18. OpenAI — Introducing Operator: https://openai.com/index/introducing-operator/
19. OpenAI Help — Scheduled tasks in ChatGPT: https://help.openai.com/en/articles/10291617-tasks-in-chatgpt
20. Google Search Help — Use AI Mode to check local availability and pricing: https://support.google.com/websearch/answer/17104441?hl=en
21. Google Chrome Help — Gemini in Chrome auto browse: https://support.google.com/chrome/answer/16821166?hl=en
22. Gemini Help — Multi-step tasks in Android apps: https://support.google.com/gemini/answer/16940971?hl=en
23. Gemini Help — Talk naturally with Gemini Live: https://support.google.com/gemini/answer/15274899?hl=en
24. Google Pay Help — Agentic checkout: https://support.google.com/googlepay/answer/16421147?hl=en
25. Claude Help — Chat search and memory: https://support.claude.com/en/articles/11817273-use-claude-s-chat-search-and-memory-to-build-on-previous-context
26. Amazon — Introducing Alexa+: https://www.aboutamazon.com/news/devices/new-alexa-generative-artificial-intelligence
27. 토스 — What makes a good product?(제품 원칙): https://toss.im/tossfeed/article/tossproductprinciples
28. 토스 — 토스는 왜 단순함에 집착할까?: https://toss.im/tossfeed/article/importance-simplicity
29. 토스 — UX Writing 인터뷰: https://toss.im/tossfeed/article/uxwriter-interview
30. 토스 테크 — 토스의 8가지 라이팅 원칙들: https://toss.tech/article/8-writing-principles-of-toss

**연구 색인·언론**
31. MIT AI Agent Index — Comet: https://aiagentindex.mit.edu/2025/comet
32. Windows Central — Copilot Actions(2025-04-04): https://www.windowscentral.com/microsoft/copilot-actions-announcement-2025
33. 바이라인네트워크 — 네이버지도 플레이스 에이전트(2026-09-17): https://byline.network/2026/09/17_naver_2/
34. 디지털인사이트 — 네이버지도 플레이스 에이전트(2026-09-18): https://ditoday.com/?p=153172
35. 바이라인네트워크 — DAN25 네이버 지도(2025-11-06): https://byline.network/2025/11/6-291/
36. 뉴시스 — 카카오톡 챗GPT 탑재(2025-10-28): https://www.newsis.com/view/NISX20251028_0003379420
37. 머니투데이 — 카카오톡 개편(2025-09-23): https://www.mt.co.kr/tech/2025/09/23/2025092310345858683
38. 뉴시스 — 카카오톡 친구탭 복귀(2025-12-16): https://mobile.newsis.com/view/NISX20251216_0003442706
39. MTN — 배민 음식·가게배달 탭 일원화(2025-01-31): https://news.mtn.co.kr/news-detail/2025013111355899370
