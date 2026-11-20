# CallMate

AI가 대신 전화를 걸어 주는 개인 비서 앱입니다. 식당 예약, 영업시간 문의, 요금 할인 요청, 취소·환불처럼 전화로만 되는 일을 맡기면, AI가 통화 계획을 세우고 통화합니다. 결제나 약정처럼 중요한 결정은 통화 중에 사용자에게 먼저 묻고, 통화가 끝나면 결과를 정리해 줍니다.

- **앱**: Flutter (iOS · Android), `app/`
- **서버**: Node.js + TypeScript (Fastify), `server/`
- **실제 통화**: KAT Cloud(발신·070) + OpenAI Realtime(음성 AI)
- **키가 없을 때**: 통화 시뮬레이터로 전체 흐름을 그대로 체험 가능

설계 문서는 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), 제품 고도화·개인 비서 로드맵은 [docs/PRODUCT_ROADMAP.md](docs/PRODUCT_ROADMAP.md)에 있습니다.

## 사용 흐름

1. **전화 맡기기**: 어디에, 몇 번으로, 무엇을 할지 입력합니다(자주 하는 부탁 템플릿 제공).
2. **계획 확인**: AI가 만든 첫 인사, 통화 순서, 물어볼 것, 승인이 필요한 경우를 확인하고 "이대로 전화 걸기"를 누릅니다.
3. **실시간 통화**: 대화가 자막으로 보입니다. 언제든 "통화 끊기"를 누를 수 있습니다.
4. **통화 중 승인**: 예약금이나 수수료가 나오면 AI가 상대방을 잠시 기다리게 하고 앱에 승인을 요청합니다. 제한 시간 안에 답이 없으면 진행하지 않습니다.
5. **결과**: 목표 달성 여부, 요약, 알아낸 내용, 해야 할 일을 보여 줍니다.

## 빠르게 실행하기 (시뮬레이션 모드)

필요한 것: Node.js 22+, Flutter 3.50+ (Xcode 또는 Android Studio)

### 1. 서버

```bash
cd server
npm install
npm run dev            # http://127.0.0.1:8787, 키가 없으면 시뮬레이션 모드
```

### 2. 앱

```bash
cd app
flutter pub get
flutter run            # iOS 시뮬레이터 또는 Android 에뮬레이터 선택
```

- iOS 시뮬레이터는 `http://127.0.0.1:8787`, Android 에뮬레이터는 `http://10.0.2.2:8787`로 자동 연결됩니다.
- **실제 휴대폰**에서 테스트하려면 서버를 `HOST=0.0.0.0 npm run dev`로 실행하고, 앱 설정에서 서버 주소를 `http://<컴퓨터 IP>:8787`로 바꾸세요.
- 빌드할 때 서버 주소를 고정하려면 `--dart-define=CALLMATE_SERVER_URL=https://...`를 쓰세요.
- 웹에서 확인하려면 서버를 `CORS_ORIGINS=http://localhost:<포트>`로 실행한 뒤 `flutter run -d chrome --web-port <포트>`를 실행하세요.

## 실제 전화 걸기 (KAT Cloud)

1. [KAT Cloud](https://katcloud.kr/)에 가입해 070 번호와 API 키를 받습니다.
2. `GET /group`으로 `groupId`를, `GET /webhook/secret`으로 `whsec_…` 서명을 확인합니다.
3. `server/.env.example`을 `server/.env`로 복사하고 아래 값을 채웁니다.
4. 서버가 한국에서 도달 가능한 `PUBLIC_BASE_URL`(https, 예: Cloudflare Tunnel)을 켭니다. KAT API는 **한국 IP**에서만 호출됩니다.

| 변수 | 설명 |
| --- | --- |
| `API_TOKEN` | 앱이 서버에 접근할 때 쓰는 토큰(실제 통화 모드에서는 필수). 앱 설정에 같은 값을 입력 |
| `OPENAI_API_KEY` | 통화 계획·요약과 음성 AI에 사용 |
| `KAT_API_KEY` | KAT Cloud 콘솔 API 키 (`x-api-key`) |
| `KAT_GROUP_ID` | `GET /group`으로 확인한 그룹 ID |
| `KAT_FROM_NUMBER` | 발신에 쓸 070 번호 (그룹 번호) |
| `KAT_WEBHOOK_SECRET` | `GET /webhook/secret` 값 (`whsec_…`) |
| `PUBLIC_BASE_URL` | KAT가 서버에 접근할 공개 https 주소 |

`OPENAI_API_KEY`만 넣으면, 통화는 시뮬레이션이지만 계획과 요약은 LLM이 만듭니다.

## 테스트

```bash
cd server && npm test && npm run typecheck
cd app && flutter analyze && flutter test
```

## 폴더 구조

```text
server/src
  brain/        통화 계획·요약 (OpenAI / 규칙 기반), 음성 AI 지시문
  providers/    통화 공급자 (시뮬레이터, KAT Cloud + OpenAI Realtime)
  services/     CallService: 상태 머신, 통화 중 승인, 한도
  http/         REST · WebSocket API
app/lib
  core/         설정, 네트워크, 라우터, 테마, 공통 위젯
  features/
    calls/      domain · data · application · presentation
    settings/
docs/           설계 문서
```
