https://chatgpt.com/share/6b07b16f-440c-83ee-8c19-78bc4c6112b8

# **개인비서 App UI/UX 디자인 컨셉 제안**

우리 앱은 단순한 AI 챗봇이나 일정 관리 앱보다는 **사용자의 일상과 업무를 파악하고, 필요한 일을 먼저 제안하며, 실제 업무까지 수행하는 AI Personal Assistant**라는 방향으로 디자인하는 것이 좋겠습니다.

이전에 논의한 Add-on 및 SDK 기반의 서비스 확장성까지 고려하면, 개별 기능 중심의 화면보다 모듈형 컴포넌트를 기반으로 한 디자인 시스템을 구축하는 것을 추천합니다.

다만, 보내주신 Figma Community 페이지는 외부 접근이 제한되어 해당 페이지의 개별 디자인 파일을 직접 열람하지 못했습니다. 따라서 Figma에서 공개한 디자인 리소스와 별도로 확인 가능한 UI 레퍼런스를 기반으로 추천안을 구성하겠습니다.

## **1. 디자인 레퍼런스 추천**

다음 5가지 디자인에서 각각의 장점을 가져오는 방식이 가장 적합하다고 판단됩니다.

[Orb - AI Daily Assistant App by Alvian Teddy Cahya Putra 👨🏻‍🎨 for Kretya on Dribbble](https://images.openai.com/static-rsc-4/Piy-SvbxEBPtm8lasBefOjcbcPFxDJC1kcVfvlZeO7RQHwyvAAWpTASRwri9nxt89lpUKrqfWU4T_HFPzbbFBz5Bn8KM9JDAu3YIMyBI5JtQqqUIIhtxajsc68GxGCNTqZcV1yvYqiotjsd-b1fOH6R7j-L2Z5hq5f28nxR2Fls?purpose=inline)

**① Smart Personal Assistant**

일정, 리마인더, 음성 비서, 맞춤형 브리핑을 통합한 디자인입니다.

- 참고 요소: 메인 홈, 개인화 브리핑
- 우리 앱과 기능적 방향이 유사

[디자인 원본 보기](https://dribbble.com/shots/26339390-AI-Assistant-App-UI-Smart-Personal-Assistant-Mobile-Design?utm_source=chatgpt.com)

[Smart Planner UI – Your Schedule, Upgraded by AI by Sunmait - UX UI Team on Dribbble](https://images.openai.com/static-rsc-4/t_Kji22UaDW7SNOvc89lzLOpJdss_lEXcmDJm8m5CpOZie0S39AiTMuWXs_Oq-mdz2pzGprC_7eSt8db1B_TG1LERoHBMljt-cHsF3qt9rtUoAKkx1nE4gnnodK_oji5J6kXhRm2_DiLvG9DtBzswekzw8PeffvZspbOoAWwGm8?purpose=inline)

**② AI Personal Assistant & Daily Planner**

AI 비서와 개인 일정 관리를 결합한 디자인입니다.

- 참고 요소: 일정 카드, 할 일 관리
- 하루의 업무를 직관적으로 파악

[디자인 원본 보기](https://dribbble.com/shots/27823566-AI-Personal-Assistant-Daily-Planne-Mobile-App?utm_source=chatgpt.com)

[Agent Approve - AI Agent Observability & Control on Your Wrist](https://images.openai.com/static-rsc-4/xLN2356nzK7P3tpHAveqKRQwacGQkukdnoa0Qc5XMCDYMj0TkSCXSJwrDqbHCYfGmp25B8XIRNcp-kP98tvRPVuS1Lg29LjQKN6FKF7Y-g1JZpuoFHJ5Dj6mZQDOHbuAZ_DUQm0JF012kEjRKLDw4ESj1OquuEv7MHa1jFgxvZ8?purpose=inline)

**③ Apetic – Agent Team**

AI Agent가 업무를 수행하고 중요한 작업은 사용자의 승인을 받는 디자인 컨셉입니다.

- 참고 요소: Agent 실행 상태, 승인 UX
- Agentic AI의 특성을 표현하기에 적합

[디자인 원본 보기](https://dribbble.com/shots/27892961-Ask-Once-Approve-Later-Apetic-s-Agent-Team-on-iOS?utm_source=chatgpt.com)

[Nova AI – Smart Assistant Mobile App by Raymiq Mobile App on Dribbble](https://images.openai.com/static-rsc-4/9Ax17hxn8hCFlsLX0Q0R-82aX-2VxDDlySzV8MEAZmhGLy60ywnjsfph4pdqfysEqk9EEYKoBdSovPyvPzIdTfsA9zw0FnUDGfLZlZzGKwOhewFqIy9Kfj-8Ft6Epz1uV6icrNIl5Ih_LWPQ_Tdvb4tgRL3Tr_pck2-zI0Kgaxw?purpose=inline)

**④ Nova AI Assistant**

대화, 문서 관리, 업무 진행 상황을 하나의 공간으로 통합한 디자인입니다.

- 참고 요소: 통합 Workspace
- 향후 업무용 기능 및 Add-on 확장에 유리

[디자인 원본 보기](https://dribbble.com/shots/27482267-Nova-AI-Assistant-Mobile-App-UI?utm_source=chatgpt.com)

[Structured Daily Planner Turns 5! - Structured Daily Planner: Optimize Your Time Management](https://images.openai.com/static-rsc-4/KVsX83AJaJqiV8UsbVqvto_vafP1ALdX_U3a7trxNqDHHsJmgeJYj_XkMo4YF9KHv8xyFRWvbmTW_SaZku7oB7ELyi3mAXALmEUUfKJHbNreWN7B-aDJ6r-87W0PR0dULONbuRIni_hk-l3NDRcEY8DJwxDM-XCUKSSZlOPndgU?purpose=inline)

**⑤ Structured – Daily Planner**

시간의 흐름에 따라 하루 일정을 시각화하는 디자인입니다.

- 참고 요소: 타임라인, 정보 계층
- 일정과 업무의 통합 표현

[서비스 홈페이지](https://structured.app/?utm_source=chatgpt.com)

## **2. 우리 앱의 기본 디자인 컨셉**

# **Calm Intelligence**

차분하지만 능동적이고, 친근하지만 전문적인 AI 개인비서

[AI Assistant - Onboarding & Dashboard by MapleFrame on Dribbble](https://images.openai.com/static-rsc-4/RQh-no57hRXo-zCTiaJIUV-dI6r1UZrlp84y7sWy_hcRRXZYWoHWUUkDZVXNGc14x_TOASOtcfmCiFveXLGlNECRyLMY0rteGdLAumSDeP5_zy68HN9zTPxU0zRSquzv3B8PFtww6bpee5ZNBIHBT_1vOt14Bkl21lNmxJwBohQ?purpose=inline)

[Productivity Planner App – Goals, Calendar & Daily Routine UI by Fahim Faysal on Dribbble](https://images.openai.com/static-rsc-4/0ICV3EXCItJQHL_7fpRzXzljVAUT_zVuj5jTRBzTTi_08BhI3RuT7nwiz3Pc3G3Exmt8L_vlTVu3CPHzI8dxedU_z0f3LWso2HTVwyxL1evLcY194sL3yt59csz0H9DV9VmGH_xnJ_Vo6pfynZpPd8LWVus1dcPMgQlLMghEDHU?purpose=inline)

[AI Assistant – Multimodal Agent App by Fahim Faysal on Dribbble](https://images.openai.com/static-rsc-4/9se0XKzwHGNBVvBZsx0eMIKxrCKkt7jvx3Iu6J56LCCR4l8PtC33PbDVRbwMxSsoXwVzY99-kL4joOXlUO46AiRn1MZgM4HhaF6QJvxJZ9LD5uCFxACh_3hrTDn3gV__rdjX8dvbAj5l8Xet7sRMxODUht_jHHYVY9gqVc4q_g8?purpose=inline)

19

화려한 AI 그래픽보다는 매일 사용해도 피로감이 없고, 사용자가 중요한 정보에 집중할 수 있는 프리미엄 미니멀리즘을 추천합니다.

| 디자인 요소       | 추천 방향                       |
| ------------ | --------------------------- |
| Design Style | Premium Minimalism          |
| 브랜드 이미지      | 신뢰감, 지능적, 친근함               |
| Layout       | Modular Card & Bento Grid   |
| Interaction  | Voice + Chat + Action UI    |
| Home UX      | 개인화된 Today Dashboard        |
| Navigation   | 하단 탭 + 중앙 AI 버튼             |
| AI 시각화       | 부드러운 AI Orb, Waveform       |
| 모서리          | 16\~24px Rounded Corner     |
| 테마           | Warm Light Mode + Dark Mode |
| 애니메이션        | 부드럽고 절제된 Motion             |

특히 사용자가 앱을 실행했을 때 **무엇을 질문할지 고민하게 만드는 것이 아니라, 비서가 먼저 오늘의 중요한 일을 알려주는 구조**가 핵심입니다.

## **3. 추천 디자인 시스템 (Design System)**

### **Color Palette**

테크 기업에서 흔하게 사용하는 강렬한 보라색이나 네온 컬러보다, 장시간 사용하기 편안한 Sage Green 계열을 메인 브랜드 컬러로 추천합니다.

Primary

\#426B5B

Secondary

\#A8C5B5

Accent

\#DFEAE4

Background

\#F7F8F5

Surface

\#FFFFFF

Text

\#202924

Warning

\#D99A42

Error

\#C45B5B

### **Typography & Component**

TYPOGRAPHY

# **Your day, simplified.**

# **당신의 하루를 더 여유롭게.**

복잡한 일은 제가 처리할게요. 중요한 일에 집중하세요.

English · Inter / Korean · Pretendard

BUTTON COMPONENTS

비서에게 부탁하기

자세히 보기

STATUS COMPONENTS

대기 중

진행 중

승인 필요

완료

실패

| 항목             | 디자인 규격                 |
| -------------- | ---------------------- |
| 기본 폰트          | Pretendard / Inter     |
| Page Title     | 28px / Bold            |
| Section Title  | 20px / SemiBold        |
| Body           | 15\~16px / Regular     |
| Caption        | 12\~13px               |
| Icon           | Lucide Icons           |
| Spacing System | 4, 8, 12, 16, 24, 32px |
| Card Radius    | 20px                   |
| Button Radius  | 16px                   |
| 화면 좌우 여백       | 20px                   |
| 최소 터치 영역       | 48 × 48px              |

## **4. App Information Architecture**

기존 CallMate 로드맵의 전화 대행 기능을 유지하면서 향후 종합 개인비서 플랫폼으로 발전할 수 있는 구조입니다.

중앙 AI 버튼은 일반적인 탭 메뉴와 다르게 설계합니다. 어느 화면에서든 비서를 호출하여 음성이나 텍스트로 업무를 지시할 수 있도록 합니다.

## **5. 주요 화면 디자인 제안**

아래는 우리 앱에 적용할 수 있도록 구성한 초기 UI 와이어프레임입니다. 실제 데이터가 아닌 예시 시나리오를 적용했습니다.

홈AI 비서업무연결 앱

**9:41**

# **연결된 서비스**

비서에게 필요한 기능과 권한을 관리하세요.

Google Calendar

일정 조회 및 등록

연결됨

Gmail

메일 조회 및 작성

연결됨

Contacts

연락처 및 전화 대행

연결됨

Maps

장소 및 업체 검색

연결하기

Notion

문서 및 지식 관리

연결하기

개인정보 및 실행 권한

외부 서비스에 쓰기 작업을 하거나 결제할 때는 사용자 승인을 요청합니다.

TodayTasksAssistantMy

상단 탭과 하단 메뉴를 클릭하면 화면을 전환할 수 있습니다. 디자인 방향 검토용으로, 실제 업무 실행 기능은 연결되어 있지 않습니다.

### **5-1. Today – 개인화 홈**

[Productivity App Design designs, themes, templates and downloadable graphic elements on Dribbble](https://images.openai.com/static-rsc-4/1XkRms4b2yAiYRwDjyaflkOhUwYfmAnHhOjw0xyxeR9CaLe-ckGI3k7pQHY0wbZs4HpB1GlpKKJV_vuXLEExtipXEsg4JP2VAEB2bKzGr3ompz7qkO5G9DyWZ3ocOreChi7hoWOww6Mls0lX04IsUqMutDxKVP4xwDEs8JNPn-Q?purpose=inline)

[Second Memory App - Never Lose Ideas](https://images.openai.com/static-rsc-4/WSMGZ6I4Xs9NxMviN0UVtePL27NpmB9JRpM46Nvzpsf2X_GmGGq0YGoS6leTDbyNdTVNOHdsTGMH3wwEOGWQ_2dY-DojszfbjMc3GoXW6iHYy9zDxBjIY4KE5-LV0W0VGyFJVdQTQvRZzZo5DlqdeNQ9BYlslLGR5rjpiYqvbNY?purpose=inline)

[Task Schedule - Mobile App | Dribbble | Mobile app design inspiration, App interface design, Mobile ui design](https://images.openai.com/static-rsc-4/GJur4ao_F5yLegUsOmuB0WHVtq2xkmOPcMx65iY0SDyihN64lAx1OkG5BLo-4O_tY_79gCxPcbbfY6WGKjunhyJ6Ea8aK1VEPq_htLfxT3SGPYgamcdIqUFNzMXarYsSWcoW7Aj5dgb_-muyMOxRCzTX6DBZG4_73Ky-_H-Mzeo?purpose=inline)

18

앱에서 가장 중요한 화면입니다. 단순히 기능 목록을 나열하는 것이 아니라 사용자에게 필요한 정보를 우선순위에 따라 보여줍니다.

| 영역                | 주요 기능             |
| ----------------- | ----------------- |
| Daily Briefing    | 오늘의 일정, 중요 업무 요약  |
| Suggested Actions | AI가 선제적으로 제안하는 업무 |
| Quick Actions     | 전화 대행, 예약, 일정, 메일 |
| Approval Inbox    | 사용자 확인 및 승인 필요 업무 |
| Active Tasks      | 비서가 현재 처리 중인 업무   |
| Today's Timeline  | 오늘의 일정과 리마인더      |

각 영역은 Widget 형태로 구현하여 사용자가 순서를 변경하거나 숨길 수 있게 확장하는 것이 좋겠습니다.

### **5-2. AI Assistant – 음성 및 대화 화면**

[Ios App UI designs, themes, templates and downloadable graphic elements on Dribbble](https://images.openai.com/static-rsc-4/-HmiqhOO10TzOmBrd6EPJRrRZk5rSyCgv5Kyi6LgdvUT_EG6qcQb0YFOjzJ-rd9ZIetITWvP_tF-V4GVmG_owPzOBladHISmzZbKFZMPBS9zNW0IBxmizOS0WxsVq8i0mbXoaYUnhZtm0hqh7Iddlhqvj-WY1f0Q5onWrn2N3Fw?purpose=inline)

[Calm AI · Voice Interaction Concept by pooja joshi on Dribbble](https://images.openai.com/static-rsc-4/65XBdue0l0bOacCPgAC9b__sqYITuu3eS7o8PJaXrCYtyQwn4a9KxM-uk72qTL1GB_NL7WSk0HFrnc9zi5uHY6ZTHljhrkdVjLROAOP3tZUaWCqaOlXEauNs8pAbLUVOA75BLnvDa7ODrvF6NuNAbhIFIxjuE8a4dZr-pHvyckQ?purpose=inline)

[Me.Chat - AI Assistant by Rusdhy Jasmin on Dribbble](https://images.openai.com/static-rsc-4/AItYPHf_gH3rnNSaZt-VcSmDZc3Bfi57uPhJDtzw6Mlz-WhZoLwQYN69aBgnh-0RmwgxHHyIRsb-eQiMhXU1ExRZ1zf0iJvRNdCwZl4Fv4jVh7WMAOqGDXWo5QybrGPRLYTMUWV4eupaOjh5Eo5f3YYqCWqKNv7KNMG-CO1-e14?purpose=inline)

18

음성 기술이 우리 앱의 중요한 차별화 요소인 만큼 일반적인 채팅 중심의 AI 서비스보다 음성 접근성을 높이는 것을 추천합니다.

AI Orb는 단순한 장식이 아니라 실제 비서의 상태를 표현합니다.

대기

듣는 중

처리 중

응답 중

실시간 음성 대화, 텍스트 입력, 통화 진행 중 자막, 중단, 다시 말하기 등의 인터랙션을 공통 컴포넌트로 설계합니다.

### **5-3. Agent Task – 비서 업무 실행 화면**

이 화면은 ChatGPT 스타일의 일반 챗봇과 우리 앱을 차별화할 수 있는 핵심 화면입니다.

**저녁 식당 예약하기**

AI Assistant · 전화 대행

진행 중

업무 진행 상황

1. **사용자 요청 분석**

   오늘 저녁 7시, 2명 예약
2. **식당 연락처 확인**

   예약할 식당 및 전화번호 확인 완료
3. **전화 및 예약 가능 여부 확인**

   오후 7시 예약 가능
4. **사용자 최종 승인**

   사용자 응답 대기 중
5. 예약 확정
6. 캘린더 등록 제안 및 결과 보고

승인이 필요한 작업은 확인 없이 실행하지 않습니다.

이 구조는 내부 Agent Execution Engine과 연계할 수 있습니다. 실제 실행 단계, 통화 진행 상황, 실패 및 재시도 여부를 서버에서 전달받아 화면에 표시하는 방식입니다.

### **5-4. 통화 결과 화면**

기존 CallMate 기능의 완성도를 높이는 데 필요한 화면입니다.

## **부탁하신 업무를 완료했어요.**

전화 대행 · 통화 시간 2분 34초

**통화 요약**

병원에 전화하여 기존 진료 예약을 변경했습니다.

변경 전

~~11월 27일 오전 10시~~

변경 후

**11월 30일 오후 2시**



처리 결과

예약 변경 완료

**다음으로 할 수 있는 일**

일정에 추가

통화 기록 보기

요약 복사

결과 공유

### **5-5. Connected Apps – 서비스 확장 화면**

[Muse from Meta Revenue Estimate & Downloads | AppRank](https://images.openai.com/static-rsc-4/kbRwAYzGo71U_qbuUKwH2GGJCNaRPY_eJxI54Ig_DMYql4xjEJuNZX79rfOB6zmLnVdquHNSkN_VLzKVrImpBcnNbIpXRPQblyIXxkoGTthP9F-iz__RCLprVI-MZDmqJEb_UAvEjYGd3IbjQvkMzNAWI3PEmnfyhBab2D4rM5Y?purpose=inline)

[AI Automation SaaS App — Mobile Dashboard UI by Orbix Studio on Muzli](https://images.openai.com/static-rsc-4/iGv8_5xN8pqCxl8Iuafp6boT6nJTTIPMxSiiJnE9U0dzjWkgCE7_a-CU_yNSCB6aYUUxgsUBK49xkfm16SyBf0EQBVxVJhu3MUMPrNOoLNQ533PD6WR_fr1aG9AN3KfQ03crCi1OUZ0mGCPxeRlRsW56ZH1RtA1CiI3-z-rHbCA?purpose=inline)

[OpenMinis：讓手機 AI 開始動手做事，整理訊息、建立行程、記錄健康都能交給 Agent - 硬是要學](https://images.openai.com/static-rsc-4/BIPvGoCxb3a1AtbY6PQ6GrQnlVd-QLffRAaQ8jjAD0JpyiWTLUV6En8hP3UR8UHDiXZhXUmbdVl2JAH0hZv_2PJ-_N1lFAaLzrZs-q1imB8udINMvrR6TMwzvRwgBfgYGk19XUXfsyawTnZdmd5eTyRSOsAw-T2E4iSuJeQMRn0?purpose=inline)

16

장기적으로는 단순 설정 화면이 아니라 개인비서의 능력을 확장하는 Skills Store 형태로 발전시키는 것도 좋겠습니다.

| Category      | Skills                    |
| ------------- | ------------------------- |
| Communication | Phone, Email, Messaging   |
| Productivity  | Calendar, Tasks, Notion   |
| Lifestyle     | Restaurant, Hotel, Travel |
| Information   | Web Search, Maps, Weather |
| Enterprise    | 사내 시스템, 업무 API            |
| Custom Skills | 사용자 정의 도구, Add-on         |

초기에는 연결된 앱과 권한 관리에 집중하고, 향후 SDK 생태계가 확장되면 Skills Store를 추가하는 방식입니다.

## **6. SDK 및 Add-on을 고려한 UI 아키텍처**

이전 설계에서 정의한 `callmate_dart`와 `callmate_flutter` 구조를 UI 디자인에도 반영할 필요가 있습니다.

이렇게 설계하면 우리 개인비서 앱뿐 아니라 다른 앱에 제공하는 Embedded UI SDK에서도 동일한 컴포넌트를 사용할 수 있습니다.

예를 들어 병원 앱에는 전화 예약 비서만, 여행 앱에는 식당 및 호텔 예약 비서만, 기업 업무 앱에는 일정 및 업무 처리 비서만 탑재할 수 있습니다.

외부 앱의 브랜드 컬러와 폰트, 모서리 스타일 등을 적용할 수 있는 Theme Override도 지원하는 것이 좋겠습니다.

## **7. Figma 프로젝트 구성 추천**

Figma에서 처음부터 다음과 같이 파일을 구성하면 Cursor를 통한 Flutter 개발과 연결하기도 수월합니다.

&#x20;**CallMate — Design System**

00

Cover & Design Principles

01

Foundations & Design Tokens

02

Base Components

03

Agent UI Components

04

Today Dashboard

05

Voice & Conversation

06

Task Execution & Approval

07

Phone Call & Results

08

Connectors & Skills

09

Settings & Privacy

10

Embedded SDK UI

11

Interactive Prototype

12

Developer Handoff

### **Figma 기본 템플릿 추천**

| 템플릿                                                                                            | 활용 목적               |
| ---------------------------------------------------------------------------------------------- | ------------------- |
| [Figma Mobile UI Kit](https://www.figma.com/templates/mobile-ui-kit/?utm_source=chatgpt.com)   | 모바일 기본 컴포넌트         |
| [Material 3 Design Kit](https://m3.material.io/?utm_source=chatgpt.com)                        | Flutter 기본 UI 및 접근성 |
| [Apple Design Resources](https://developer.apple.com/design/resources/?utm_source=chatgpt.com) | iOS 네이티브 인터랙션       |
| [Untitled UI](https://www.untitledui.com/?utm_source=chatgpt.com)                              | 컴포넌트 및 디자인 시스템 참고   |
| [Mobbin](https://mobbin.com/?utm_source=chatgpt.com)                                           | 실제 서비스의 UX 패턴 분석    |

Figma에서도 Material 3, Simple Design System, Apple iOS UI Kit 등을 공식 UI 라이브러리로 제공합니다. 처음부터 모든 컴포넌트를 새롭게 그리기보다는 기본 UI Kit 위에 우리 앱 고유의 Agent 컴포넌트를 추가하는 편이 효율적입니다.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://www.figma.com\&sz=32)

Figma+1



## **8. 단계별 디자인 구현 우선순위**

| 단계      | 디자인 범위                           | 우선순위 |
| ------- | -------------------------------- | ---- |
| Phase 1 | 디자인 토큰 및 공통 컴포넌트                 | P0   |
| Phase 2 | 홈, 음성 부탁, 연락처 선택                 | P0   |
| Phase 3 | 전화 대행, 실시간 상태, 자막                | P0   |
| Phase 4 | 사용자 승인, 통화 요약, 후속 액션             | P0   |
| Phase 5 | Calendar, Mail, Maps Connector   | P1   |
| Phase 6 | 개인화 브리핑, 통합 일정 화면                | P1   |
| Phase 7 | Embedded UI SDK 및 Theme Override | 확장   |
| Phase 8 | Skills Store, 메모리, 상시 음성         | 확장   |

초기 디자인은 미래의 개인비서 플랫폼 전체 모습을 고려하되, 실제 개발은 기존 전화 대행 기능의 완성도를 높이는 것부터 시작하는 방향입니다.

## **9. 최종 추천 디자인 방향**

[AI Assistant - Onboarding & Dashboard by MapleFrame on Dribbble](https://images.openai.com/static-rsc-4/RQh-no57hRXo-zCTiaJIUV-dI6r1UZrlp84y7sWy_hcRRXZYWoHWUUkDZVXNGc14x_TOASOtcfmCiFveXLGlNECRyLMY0rteGdLAumSDeP5_zy68HN9zTPxU0zRSquzv3B8PFtww6bpee5ZNBIHBT_1vOt14Bkl21lNmxJwBohQ?purpose=inline)

[AI Assistant – Multimodal Agent App by Fahim Faysal on Dribbble](https://images.openai.com/static-rsc-4/9se0XKzwHGNBVvBZsx0eMIKxrCKkt7jvx3Iu6J56LCCR4l8PtC33PbDVRbwMxSsoXwVzY99-kL4joOXlUO46AiRn1MZgM4HhaF6QJvxJZ9LD5uCFxACh_3hrTDn3gV__rdjX8dvbAj5l8Xet7sRMxODUht_jHHYVY9gqVc4q_g8?purpose=inline)

[Productivity Task Management Mobile App by Abu Hossain on Dribbble](https://images.openai.com/static-rsc-4/6pLsuazSu83IZQfDuzx1Wazz7pjnrZAGucU7u2Hy-SvYRbKOka9O5nPGLg4Oj-b9DFEnICcRkmW8nEiK8xoX9145IfHXyTVsf1ioKH27rkxIrjhmrq8QmH14m3Gv2u2v3dfVF_AUY7n9Fsk6mksRtNByaSdfY8wwnLlHFTpwFvg?purpose=inline)

21

| 서비스        | 가져올 디자인 요소       |
| ---------- | ---------------- |
| Apple      | 정제된 디자인과 인터랙션    |
| Notion     | 모듈형 정보 구조        |
| ChatGPT    | 자연스러운 대화 및 음성 UX |
| Structured | 일정 타임라인          |
| Linear     | 간결한 업무 상태 표현     |
| Apetic     | Agent 실행 및 승인 UX |

우리 앱의 디자인 정체성은 다음 세 가지로 정의하는 것을 추천합니다.

**Proactive** — 사용자가 부탁하기 전에 필요한 일을 알려주는 비서

**Action-oriented** — 단순히 답변하는 것이 아니라 실제 업무를 수행하는 비서

**Trustworthy** — 무엇을 하고 있는지 보여주고 중요한 결정은 사용자에게 맡기는 비서

브랜드 슬로건 역시 이러한 방향과 맞추는 것이 좋겠습니다.

# **CallMate**

# **Less to do. More to live.**

복잡한 일은 비서에게, 소중한 시간은 당신에게.

CALM INTELLIGENCE · DESIGN CONCEPT 01

최종적으로 **Today Dashboard + Voice-first Assistant + Agent Task Management**를 세 가지 핵심 UX로 선정하고, 이를 중심으로 Figma 디자인 시스템을 구축하는 것을 추천합니다.

현재 제안한 Sage Green 컬러, Calm Intelligence 디자인 컨셉, 내비게이션 구성 및 브랜드 슬로건은 검토를 위한 신규 제안이며 확정된 디자인은 아닙니다. 또한 Figma Community 원본 파일의 직접 비교와 개별 템플릿의 라이선스 검증은 아직 이루어지지 않았으므로 실제 디자인 리소스 선정 시 추가 확인이 필요합니다.

Sage Green은 편안하고 친근하지만, AI 기반 개인비서라는 제품의 정체성을 표현하기에는 다소 웰니스 앱이나 생활 관리 앱처럼 보일 수 있습니다.

CallMate는 **프리미엄 테크놀로지, 지능적인 개인비서, 세련된 라이프스타일**을 동시에 표현할 수 있는 컬러가 더 적합하다고 생각합니다.

기존의 Calm Intelligence 컨셉을 유지하면서 다음 4가지 컬러 방향을 추천합니다.

## **1. 컬러 팔레트 비교**

[Syntra | AI Powered Assistant Mobile App UI Design by Opedia Studio on Dribbble](https://images.openai.com/static-rsc-4/xmIgLycfkllk559d2CqAYiBkDHk7RK9CyO2dJ4VCb_6CSi85l40q_ITqU2Pa_0EvfyGyD-DZ9qtOdP7DN-z0-7zGWCTmmHPHESPOcWTFhersGawibKsHNLOckEZqe_Ps7ylGZEeNok-mqN-S_tjUVMmglzr6EDDA0vH2vfAx7yw?purpose=inline)

## **1. Midnight Indigo**

Intelligent · Premium · Modern

딥 네이비와 인디고를 조합한 디자인. 지능적이고 전문적인 느낌을 주면서 AI 서비스의 정체성을 잘 표현합니다.

CallMate의 메인 디자인으로 가장 추천

[Productivity Mobile App: Daily Overview & Activity Tracking by Keitoto  on Dribbble](https://images.openai.com/static-rsc-4/ZZZwSVkx111nSC4A9fi2b-ZaN_b5tv_LDNj4mRJKg1YaQDAADQgmWGuEUy7Z_zOIJk_QlskWxqtrI-K-0pnrUnKBOMi_vYU81rU8YD6gVmgiBpEgHnQwwkUONbFuKOTwiYnAkCtuk6f5LbE7bhZlepZmrNgRG2xPc7OJW7hD31w?purpose=inline)

## **2. Graphite & Silver**

Minimal · Luxury · Timeless

Apple이나 Linear를 연상시키는 모노크롬 디자인. 색상을 최소화하여 콘텐츠와 타이포그래피 자체를 강조합니다.

[Ello AI Assistant - Mobile App & UX/UI Design — Dprofile](https://images.openai.com/static-rsc-4/FSI77Ro7C1C0i6jy4XTSoGrYeAfQoG5mBAIuvMwJutnaGHIrmCrlalgPhSgh_n-Swxjt72wI8DiI_wDmlxJJzDYYeD5Ak1Q5FSZky4eAoY8br0se5C0-rPKzMeXbCaQNREi5ld3qkW8iscSupe__ruA9LqRYV7UCUkO_a_wzHzM?purpose=inline)

## **3. Digital Lavender**

Creative · Soft · Futuristic

미래지향적인 AI의 느낌과 부드러운 감성을 결합한 컬러. 음성 비서의 Orb 및 애니메이션에 특히 잘 어울립니다.

[AI Assistant Native App :: Behance](https://images.openai.com/static-rsc-4/NitJGQDT8-1iayDrtpNoK82KYny2XyWgfArlgQUVW0gtMmf9BvU9MtIk6YUqrDat-tRgsTqJ0woHHEVXVXFXRRi9a61XM-llL4w8UXw-nxSaTiUjhGumWS-lBM9y-XffiDsJo7VJaoNus6ASnWRWH6JRHoTKRltmeifhaIFtwNY?purpose=inline)

## **4. Cobalt & Porcelain**

Confident · Clean · Dynamic

선명한 코발트 블루와 깨끗한 화이트의 조합. 신뢰감이 높고 개인 서비스에서 기업용 서비스까지 확장하기 좋습니다.

## **2. 컬러별 실제 UI 적용 비교**

동일한 화면 구조에 각 팔레트를 적용했습니다. 컬러와 Light/Dark Mode를 변경하면서 비교해 보세요.

Midnight Indigo

Light ModeDark Mode

**9:41**

## **callmate.**

THURSDAY, NOVEMBER 26

# **Good morning.**

Let's make today a little easier.

YOUR DAILY BRIEF

## **Your day, simplified.**

오늘 3개의 일정과 확인이 필요한 업무가 있어요.

View briefing

### **Quick actions**

전화

일정

메일

검색

### **Needs your attention**

1

저녁 식당 예약 승인

오후 7시 · 2명 예약 가능

### **In progress**

병원 예약 변경

Calling...

예약 가능한 날짜를 확인하고 있어요.

Ask me anything...

Today

Tasks

Assistant

Activity

You

### **Midnight Indigo**

Deep

\#171B2E

Primary

\#635BFF

Accent

\#A6ACFF

Tint

\#EEEDFC

Base

\#F7F8FC

&#x20;선택한 디자인 컬러 토큰 복사

## **3. 최종 추천 — Midnight Indigo**

[Syntra | AI Powered Assistant Mobile App UI Design by Opedia Studio on Dribbble](https://images.openai.com/static-rsc-4/xmIgLycfkllk559d2CqAYiBkDHk7RK9CyO2dJ4VCb_6CSi85l40q_ITqU2Pa_0EvfyGyD-DZ9qtOdP7DN-z0-7zGWCTmmHPHESPOcWTFhersGawibKsHNLOckEZqe_Ps7ylGZEeNok-mqN-S_tjUVMmglzr6EDDA0vH2vfAx7yw?purpose=inline)

[Orbit - Listen - AI Voice Assistant by Alex Bellingham on Dribbble](https://images.openai.com/static-rsc-4/JoQin8h3D1_KSMUC69iR3AMFKS8Hc3UC0COIHmZyh37gl3I9m7WFg1REwweHdN9rig4jVCXiaJTi2S2JMoX4JHuRb8mIb4nSDCEnLAE3VXk8Lr_bbSViaY-k7dV7s_ico8mNpv_OT_8GYZhxOVCNGc4E77ar3qEARxT1ekpr-2c?purpose=inline)

[Oday - AI Productivity Assistant | Tasks, Calendar & Goals](https://images.openai.com/static-rsc-4/5xr5sjczcDYH1-KF73d3bb03f0B2DAKr8NncDWdSX4orIgtYQk42YtiM4niFVi7YhFZ10mCIATP0AHlGP0Ivj0LEuN2rmWzscb9YQMa9f_YNxpDA1o0wOR0VGg-QcqRKTYoSD5omAimISFcOGmH4cXUn4AcdfuM3u8fkN7NyCQ8?purpose=inline)

12

기존 Calm Intelligence에서 한 단계 발전시킨 **Quiet Intelligence**라는 디자인 컨셉을 제안합니다.

AI의 지능을 화려하게 과시하기보다 정제된 인터페이스를 통해 자연스럽게 전달하는 디자인입니다.

디자인 레퍼런스의 조합으로는 다음과 같은 방향을 추천합니다.

[Private teams – Linear Docs](https://images.openai.com/static-rsc-4/cyf8wGo8Ia6cBep8xliXZX9fqFRs3mjG3Ot8MkJeBXKPpEo2-h4_G5H-nWaQ9mkamDSPKmMjJouh1dUuu-AmdBXTl4b74x79W4jvfDcR5fUMzW7dtROoQgpKxjr2rIj0JUSR8TrIwpFYqZL8IQLbzecCDg-S4D-wvqY9cgC-O6Q?purpose=inline)

**Linear**

정제된 컬러와 정보 계층

[What’s actually new in Siri in iOS 18.1? The Apple Intelligence upgrades explained – and what’s coming next | TechRadar](https://images.openai.com/static-rsc-4/Lrha3JJeR6PclN5vstZ6vJ7zW5jJiK0MZpvFoNOxkC8L4HLfxDK_BhgOf5Me5e7lTDMkj46-faxlp23dux4VKYyTGy56Mugx6gQvYtU9qPTCDNVsN73GA2mP1umbYYpLKuOPh5tCzgZ6cLdzL5B2HJsv1kLjHvfPU5Ak7PZEIAg?purpose=inline)

**Apple Intelligence**

감각적인 AI 시각화

[Getting started with script commands - Raycast Blog](https://images.openai.com/static-rsc-4/qfVdEVXJ3MfDLN0H4gv2kLTt7psuokqe83w4_dSEidQlPcqE4SP1Dmcp-6r3ROgEBJPs3ZxgeRNGy3LvAwhVtEexT7e0xi04OaSTCZFCbmgiq6vZcNFtyFVG083WOlmZPNc4f_yLYAQwld9Li1cMEvIcGht2G2oApitvMtxxWDw?purpose=inline)

**Raycast**

효율적인 명령 및 업무 실행 UX

[Stripe - Dashboard Redesign by Johny vino™ on Dribbble](https://images.openai.com/static-rsc-4/RX6NTut-NJp6b8NzsCmjW2ifq8BryqlJhR-4NeoJ0SXOGqj-jNToye6i-97rWZUvqRZeVDLJiQr0Rhps-7sC53vjnCDFQ_ky_90kGHIB90neMBHsV12ARVcUSxAz5sD0c0J5ihnfrROyotMwtMpH0TAhfCbrn-CoXOx3cuNOX4Q?purpose=inline)

**Stripe**

전문적이고 확장 가능한 디자인 시스템

## **4. 추천 Design Tokens**

## **Brand Colors**

Midnight

브랜드, 메인 브리핑, 다크 카드

\#171B2E

Electric Indigo

CTA, AI 호출, 활성화 상태

\#635BFF

Periwinkle

AI Orb, 강조, 보조 그래픽

\#A6ACFF

Soft Indigo

아이콘 배경, 선택 영역

\#EEEDFC

Cloud White

전체 앱 배경

\#F7F8FC

Pure White

카드 및 콘텐츠 영역

\#FFFFFF

## **Semantic Colors**

Success

업무 완료

\#16A34A

Warning

사용자 승인 필요

\#D97706

Error

실패 및 오류

\#DC2626

Information

안내 및 실행 상태

\#2563EB

### **컬러 사용 비율**

70%

20%

10%

Neutral · 70%Midnight · 20%Accent · 10%

인디고 컬러가 아무리 매력적이어도 화면 전체를 인디고로 채우지는 않는 것이 좋습니다. 대부분의 화면은 무채색에 가깝게 유지하고, AI와 직접 상호작용하거나 중요한 행동을 유도하는 부분에만 인디고를 사용해야 세련된 느낌이 살아납니다.

## **5. AI Assistant의 시그니처 디자인**

일반적인 원형 마이크 버튼보다는 브랜드를 대표할 수 있는 **Iridescent AI Orb**를 추천합니다.

Listening

듣고 있어요

Thinking

처리하고 있어요

Speaking

말하고 있어요

그라데이션은 전체 UI가 아니라 AI Orb, 음성 인터랙션, 온보딩 등 AI의 존재감을 표현하는 영역에 제한적으로 사용하는 것을 추천합니다.

## **6. 최종 브랜드 디자인 컨셉**

# **callmate.**

# **Your life. In good hands.**

당신의 일상을 이해하고, 당신을 대신하는 AI.

QUIET INTELLIGENCE — BRAND CONCEPT 02

| 디자인 항목                | 최종 추천                   |
| --------------------- | ----------------------- |
| Design Concept        | Quiet Intelligence      |
| Color System          | Midnight Indigo         |
| Design Style          | Premium Tech Minimalism |
| Font (English)        | Inter / Geist           |
| Font (Korean)         | Pretendard              |
| Icon                  | Lucide, 1.5\~2px Stroke |
| Card                  | 16\~20px Radius         |
| Border                | Thin, Subtle            |
| Shadow                | 거의 사용하지 않음              |
| AI Signature          | Iridescent Orb          |
| Motion                | Fluid & Subtle          |
| Default Theme         | Light Mode              |
| Voice Assistant Theme | Immersive Dark Mode     |
| Logo Style            | Lowercase Wordmark      |

특히 **일반적인 앱 화면은 밝고 정제된 화이트톤으로 구성하고, AI 비서를 호출하면 몰입감 있는 딥 네이비 화면으로 전환되는 Dual Experience**를 추천합니다.

이렇게 하면 일상적인 사용성은 유지하면서도 AI 비서와 상호작용할 때 차별화된 브랜드 경험을 제공할 수 있습니다. 위 팔레트와 로고는 신규 디자인 제안이며, 실제 구현 전에는 색상 대비 및 접근성 검증을 거쳐 확정하는 것이 좋겠습니다.