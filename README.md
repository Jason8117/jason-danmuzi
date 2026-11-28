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

## 화면 구성

앱 아래에는 다섯 칸 탭 바가 있습니다. 왼쪽부터 **오늘**(날짜·인사, 오늘의 브리핑, 바로가기, 최근 장소, 확인이 필요한 일과 진행 중인 일), **업무**(승인 요청·진행 중·반복 묶음과 개수, 탭에는 승인 대기 수 배지), 가운데 **비서 버튼**, **기록**(끝난 일을 날짜별로 묶고 결과 칩을 표시), **내 정보**(프로필, 비서·권한과 안전·앱 항목, 설정 연결)입니다. 작업을 열면 업무 탭으로 옮겨 가 상세 화면 맨 위에 6단계 진행 상황(요청 이해 → 연락처 확인 → 가능 여부 확인 → 내 승인 → 확정 → 결과 보고)이 보입니다. 부탁은 가운데 버튼이 여는 **AI 비서** 화면에서 합니다. 통화 중에는 상세 화면의 [통화 보기]로 실시간 자막, 통화 끊기, 승인 카드가 있는 어두운 통화 화면을 열 수 있으며, 통화가 끝나면 상세 화면으로 돌아옵니다.

## 말로 부탁하기

AI 비서 화면은 늘 어두운 화면이며, 가운데 Orb와 상태 글자(기다리고 있어요 · 듣고 있어요 · 처리하고 있어요)로 비서의 상태를 보여 줍니다. 권한이 있으면 화면을 열자마자 듣기 시작합니다(처음이면 목적 안내와 권한 요청 뒤). 음성 인식이 말을 글로 받아 적고, 말이 끝나거나 [말하기 끝]을 누르면 그 문장으로 통화 계획 카드를 엽니다. 번호 없이 장소만 말하면 먼저 장소 선택을 열고, 고른 곳으로 계획 카드를 채웁니다(「장소 찾기」). 기다리는 중에는 Orb를 눌러 다시 들을 수 있습니다. [글로 입력]을 누르면 예전 오늘 화면의 부탁 입력 상자(입력칸, 직접 입력하기, 최근 장소, 예시)로 바뀝니다. 잘 알아듣지 못하면 다시 말하거나 글로 적도록 안내하고, 빈 문장은 보내지 않습니다.

- **권한**: 처음 말하기 전에 목적을 먼저 알린 뒤 마이크와 음성 인식 권한을 묻습니다. 거부해도 글로 부탁할 수 있고, 다시 묻지 않음으로 거부했다면 [설정 열기]로 안내합니다.
- **음성은 콜비 서버로 보내지 않습니다**: 앱은 음성을 저장하거나 업로드하지 않고, 받아 적은 최종 문장만 기존 `/v1/intake`로 보냅니다. 먼저 기기 안 인식을 쓰고, 기기 안 인식을 쓸 수 없으면 애플·구글의 음성 인식 서비스가 음성을 처리할 수 있어 그 전에 안내합니다. Android에서는 첫 받아쓰기 전에 이 안내를 한 번 보여 줍니다.
- **권한 문구**: iOS `Info.plist`의 `NSMicrophoneUsageDescription`·`NSSpeechRecognitionUsageDescription`, Android `AndroidManifest.xml`의 `RECORD_AUDIO`.
- 웹과 iOS·Android 밖의 플랫폼에서는 받아쓰기를 쓰지 않고 글로 입력 모드로 시작합니다. 기기에 한국어 인식 언어가 없을 때도 같습니다.

## 장소 찾기

"강남역 근처 파스타집, 금요일 7시 2명 예약해 줘"처럼 번호 없이 장소만 말하면, AI 비서가 계획 카드 대신 **장소 선택** 화면을 엽니다. 서버가 부탁에서 뽑은 검색어(예: "강남역 파스타집")가 검색칸에 채워져 있고 고칠 수 있습니다. 후보는 최대 5곳이며 카드마다 이름·분류·거리·주소와 "걸 수 있음 / 번호 없음 / 걸 수 없는 번호"가 보입니다. 번호가 없거나 걸 수 없는 번호(긴급·특수번호 등)인 곳은 고를 수 없습니다. [상세]를 누르면 장소 상세 시트에서 [번호 복사]·[여기에 물어보기]를 쓸 수 있습니다. [여기로 전화]나 [여기에 물어보기]로 고른 곳의 이름과 번호가 계획 카드에 채워지고, 번호 옆에 "검색 결과"가 표시됩니다. 원하는 곳이 없으면 언제든 [번호 직접 입력]으로 넘어갈 수 있습니다.

- **검색 결과는 남기지 않습니다**: 서버는 카카오 로컬 검색 결과를 앱에 그대로 넘기고 저장·캐시·로그하지 않습니다(`Cache-Control: no-store`). 남는 것은 사용자가 확정해 만든 작업의 이름·번호뿐입니다. 사람 이름("엄마" 등)이 들어간 부탁도 그 이름이 검색어로 카카오에 전송될 수 있습니다.
- **위치 권한**: "근처" 부탁을 처음 할 때만 "근처 가게를 찾으려면 지금 위치가 필요해요. 가까운 가게를 찾는 데만 써요. 콜비는 위치를 저장하지 않아요." 안내를 먼저 보인 뒤 OS 권한 창을 띄웁니다. 대략 위치를 한 번만 읽어 그 검색에만 쓰며, 앱과 서버가 모두 좌표를 약 100m 단위(소수 셋째 자리)로 반올림한 뒤에만 넘깁니다. 거부하면 "동네 이름을 알려 주세요" 칸에 적은 동네로 찾습니다. 권한 문구는 iOS `Info.plist`의 `NSLocationWhenInUseUsageDescription`, Android `AndroidManifest.xml`의 `ACCESS_COARSE_LOCATION`입니다("항상" 위치와 정밀 위치는 묻지 않습니다).
- **카카오 키**: 실제 장소를 찾으려면 서버 `server/.env`에 `KAKAO_REST_API_KEY`(카카오 개발자 콘솔의 REST API 키)를 넣고, 콘솔에서 그 앱의 카카오맵(로컬) API 사용 설정을 켜세요. 키는 서버에만 두고 앱 빌드에는 넣지 않습니다. 키가 없으면 시뮬레이션 서버는 "연습용 장소"를 보여 주고, 실제 통화 서버는 장소 찾기를 끕니다(연습용 번호에 실제로 걸지 않도록).
- **대표번호 표시**: 1588·1644·1800 같은 대표번호는 앱 어디서나 `1588-0000` 모양으로 보입니다.

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
| `KAKAO_REST_API_KEY` | (선택) 카카오 로컬 장소 검색 키. 실제 통화 모드에서 이 키가 없으면 장소 찾기가 꺼집니다 |

`OPENAI_API_KEY`만 넣으면, 통화는 시뮬레이션이지만 계획과 요약은 LLM이 만듭니다.

배포 전에 [운영·배포 메모](docs/OPERATIONS.md)를 확인하세요(단일 인스턴스 전제, 통화 중 배포 금지, 종료 유예 시간 10초 이상, 서버·앱 동시 배포).

## iOS 배포 빌드

위치 패키지(geolocator)는 빌드할 때 환경 변수 `BYPASS_PERMISSION_LOCATION_ALWAYS=1`을 주지 않으면 앱에 "항상" 위치 요청 코드(`requestAlwaysAuthorization`)를 남기고, App Store 제출 때 ITMS-90683 경고가 날 수 있습니다. 이 값은 Xcode 빌드 설정으로는 적용되지 않고, 이전 빌드 결과가 남아 있으면 다시 컴파일되지 않습니다. 그래서 배포 빌드는 늘 깨끗한 상태에서 환경 변수와 함께 만듭니다.

```bash
cd app && flutter clean && BYPASS_PERMISSION_LOCATION_ALWAYS=1 flutter build ipa
```

만든 뒤 바이너리에 요청 코드가 없는지 확인합니다. 결과가 `0`이어야 합니다.

```bash
strings -a build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Runner | grep -c requestAlwaysAuthorization
```

Xcode에서 Archive할 때도 같은 환경 변수로 Xcode를 띄우고 패키지 캐시를 지운 뒤 만듭니다. 빌드 스크립트·CI 자동화는 아직 없습니다.

## 테스트

앱과 공용 패키지는 저장소 루트의 Dart pub 워크스페이스 하나로 묶여 있습니다. 잠금 파일은 루트 `pubspec.lock` 하나이므로, 처음에는 루트에서 의존성을 받습니다.

```bash
flutter pub get                                   # 저장소 루트에서, 워크스페이스 전체
dart test                                         # 루트: 워크스페이스 구성 검사(test/workspace_test.dart)
cd app && flutter analyze && flutter test         # 앱
cd packages/kolbi_core && dart test               # 헤드리스 패키지(순수 Dart)
cd packages/kolbi_ui && flutter test              # 공용 UI 패키지
cd server && npm test && npm run typecheck        # 서버(워크스페이스와 무관)
```

## 폴더 구조

```text
server/src
  brain/        통화 계획·요약 (OpenAI / 규칙 기반), 음성 AI 지시문
  providers/    통화 공급자 (시뮬레이터, KAT Cloud + OpenAI Realtime)
  services/     CallService: 상태 머신, 통화 중 승인, 한도
  http/         REST · WebSocket API
  places/       장소 검색 (카카오 로컬 어댑터, 연습용 후보), 결과를 남기지 않음
pubspec.yaml    워크스페이스 루트(app, packages/kolbi_core, packages/kolbi_ui)
pubspec.lock    워크스페이스 전체의 잠금 파일
test/           워크스페이스 구성 검사
packages/
  kolbi_core/   순수 Dart: 모델, 형식 함수, 서버 접근(ApiClient, CallsRepository, PlacesRepository), 실시간 채널, 첫 검색어 규칙
  kolbi_ui/     Flutter: 디자인 토큰, 테마, 공용 위젯, 입력 포매터
app/lib
  shell/        라우터, 다섯 칸 탭 바, 탭 사이 이동 함수, 작업 종류 등록, 공유 작업 목록, 부탁 접수
  core/         설정, 시계, 공통 위젯 (라우터·네트워크·테마·포매터 옛 경로는 다시 내보냄)
  features/
    assistant/  AI 비서 화면, 받아쓰기 포트와 기기 음성 인식 어댑터(speech/)
    places/     장소 선택·상세 화면, 위치 포트와 어댑터(location/)
    calls/      domain · data · application · presentation (오늘 화면, 통화 중 화면 포함)
    inbox/      업무 탭
    history/    기록 탭
    me/         내 정보 탭
    settings/
docs/           설계 문서
```

앱 코드는 `package:kolbi_core/kolbi_core.dart`와 `package:kolbi_ui/kolbi_ui.dart` 배럴만 가져옵니다. 패키지 사이 의존 규칙은 각 패키지의 `test/dependency_rules_test.dart`와 `app/test/architecture_test.dart`가 검사합니다.
