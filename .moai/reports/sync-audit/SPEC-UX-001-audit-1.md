# Sync 감사 보고서 — SPEC-UX-001 (1차)

- 감사 대상: main HEAD `9bf5f82`(sync 커밋). 구현 커밋 `d63740d`(run 시작 `ba1ee17`), run 기록 커밋 `c2e732d`
- 평가 프로필: `.moai/config/evaluator-profiles/default.md` (Functionality 40%, Security 25%, Craft 20%, Consistency 15%; 필수 통과 차원: Functionality + Security)
- 집계: 차원 점수의 조화 평균(선례 `FIVE-SPECS-audit-1.md`와 같은 비가중 방식). 참고로 가중 조화 평균도 함께 적는다.
- 감사 방식: 읽기 전용. 아래 명령은 모두 이번 감사에서 이 트리에 직접 실행했다. 작성한 파일은 이 보고서 하나다.
- 상태: 완료

## 1. 판정 요약

| 차원 | 점수 | 판정 | 근거 요약 |
|------|------|------|-----------|
| Functionality (40%) | 90 | PASS | AC 15개 모두 실제 테스트에 연결, 전체 테스트 `+80` 통과, AC-001 grep 0줄, AC-014 보호 경로 diff 비어 있음. REQ-011 차이는 REQ 위반이 아님(§3.5) |
| Security (25%) | 95 | PASS | 추가된 줄에 비밀 값·자격 증명 없음, 의존성 변경 없음, 보호 경로(네트워크·데이터·라우터) 무변경 |
| Craft (20%) | 80 | UNVERIFIED (커버리지) | analyze = 기준선(info 1건, `fakes.dart:54:5`). 커버리지는 측정하지 않음. 테스트를 구현 뒤에 작성(기록상 RED 없음) |
| Consistency (15%) | 80 | PASS | spec.md 본문 무변경, §E.4 숫자 = 증거 파일, 문서 기호 = 실제 코드. 다만 후속 SPEC 선행 조건에 대한 §E.4 메모가 사실과 다름(C1, Medium) |
| **조화 평균** | **85.8** (가중 87.3) | | |
| **최종 판정** | | **PASS** | 필수 차원(Functionality, Security) 모두 통과 |

## 2. 기준 측정 (이번 감사, 이 트리)

```
$ cd app && flutter --suppress-analytics test
exit=0
00:07 +80: All tests passed!

$ cd app && flutter --suppress-analytics analyze
   info • Use the null-aware marker '?' rather than a null check via an 'if'. Try using '?' • test/support/fakes.dart:54:5 • use_null_aware_elements
1 issue found. (ran in 1.7s)
exit=1   (기준선 info 1건뿐)
```

서버 테스트는 다시 돌리지 않았다. 서버 파일이 바뀌지 않았음을 diff로 확인했고(§3.3), 서버 수치는 sync 증거 파일로만 대조했다(§6.2).

## 3. Functionality — 90, PASS

### 3.1 AC → 테스트 연결

`acceptance.md`의 AC 개수:

```
$ grep -oE 'AC-([A-Z0-9]+-)*[0-9]+' acceptance.md | sort -u | wc -l   → 15
$ grep -c "^## AC-" acceptance.md                                   → 15
```

progress.md §E.2 AC 표가 인용한 테스트 이름을 `grep -rlnF "<이름>" app/test`로 하나씩 찾았다. 15개 이름 모두 존재한다.

| AC | 테스트 이름 | 파일 |
|----|-------------|------|
| AC-001 | design tokens have the agreed values | theme_test.dart |
| AC-002 | status color pairs meet contrast in light and dark | theme_test.dart |
| AC-003 | text styles follow the type scale | theme_test.dart |
| AC-004 | cards share one component and tone | accessibility_test.dart |
| AC-005 | uses plain Korean status labels | unit_test.dart |
| AC-006 | respects reduce motion / scrolls without animation when motion is reduced | theme_test.dart / accessibility_test.dart |
| AC-007 | busy buttons show progress and success gives light haptics | accessibility_test.dart |
| AC-008 | empty states share one widget and wording | accessibility_test.dart |
| AC-009 | tap targets meet guidelines | accessibility_test.dart |
| AC-010 | text contrast meets guidelines | accessibility_test.dart |
| AC-011 | survives 2x text scale on a small phone | accessibility_test.dart |
| AC-012 | screen reader labels are present / announces the remaining time only at 30 and 10 seconds | accessibility_test.dart |
| AC-013 | screens follow the wireframe order | accessibility_test.dart |
| AC-014 | (명령 기반, §3.3) | — |
| AC-015 | (전체 테스트·analyze, §2) | — |

이 테스트들은 위 `flutter test` 실행에서 모두 통과했다(`+80`, 실패 0).

### 3.2 AC-001 grep

zsh 배열로 13개 대상 파일(plan.md §B 목록, `tokens.dart` 제외)을 넘겨 실행했다.

```
$ grep -nE "EdgeInsets\.(all|symmetric|only|fromLTRB)\([^)]*[0-9]|BorderRadius\.circular\([0-9]|Duration\(milliseconds: [0-9]" "${T[@]}"
ac001 exit=1          (출력 0줄)
$ grep -nA3 'EdgeInsets\.[a-zA-Z]*($' "${T[@]}"
multiline exit=1      (출력 0줄)
```

### 3.3 AC-014 보호 경로와 앞선 테스트

```
$ git diff --stat ba1ee17..d63740d -- server/ app/lib/features/calls/data/ app/lib/core/network/ app/lib/core/router/ app/lib/features/calls/application/
(출력 없음)

$ git diff --stat ba1ee17..d63740d -- app/test/{approval_flow,approval_card,intake_flow,plan_card,follow_up,trust_notice,outcome_card,calls_controller}_test.dart
(출력 없음 — 앞선 테스트 8개 무변경)

$ grep -rn "'계획 중'\|'연결 중'\|'정리 중'" app/test
(출력 없음)
```

`unit_test.dart`는 `+19`줄(AC-005 새 테스트)만 추가됐다(`git diff --stat ba1ee17..9bf5f82`).

### 3.4 변경 파일과 계획 대조

```
$ git diff --name-only ba1ee17..d63740d | wc -l   → 20
```

plan.md §B 목록(수정 13 + 신규 `tokens.dart` + `call_models.dart` = app/lib 15개, app/test 4개)에 spec.md를 더한 20개와 일치한다. 계획 밖 파일은 없다.

### 3.5 REQ-011 고정 영역 상한 — 기능 실패인가

- REQ-011 원문(spec.md:66): "**While** 글자 크기 배율이 2.0이면, … 화면 아래 고정 영역(승인 카드·행동 버튼)은 화면 높이의 절반을 넘으면 그 안에서 스크롤된다."
- AC-011 원문: 360×640, `TextScaler.linear(2.0)`에서 "(A)에서 아래 고정 영역의 높이는 화면 높이의 절반(320) 이하다".
- 구현(`call_detail_screen.dart:330,335`):
  ```dart
  final enlarged = MediaQuery.textScalerOf(context).scale(1) > 1;
  constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * (enlarged ? 1 / 2 : 2 / 3)),
  child: SingleChildScrollView(
  ```
- 테스트(`accessibility_test.dart:464-465`): `expect(tester.getSize(pinned).height, lessThanOrEqualTo(320));` — 2배 글자에서 승인·거절 두 경우 모두 확인하고 통과.

판단: **기능 실패가 아니다.** REQ-011은 상태 조건형([State-driven]) 요구로, 절반 상한은 글자 배율 2.0인 동안에만 걸린다. 구현은 배율이 1을 넘는 모든 경우(2.0 포함)에 절반을 적용하므로 REQ가 요구하는 범위를 빠짐없이 덮는다. 보통 글자 크기에서의 상한은 REQ도 AC도 정하지 않는다. 2/3라는 값과 어긋나는 것은 plan.md §B("화면 높이 절반 상한")라는 설계 메모이며, 그 차이는 근거(변경하지 않은 `approval_flow_test`가 800×600에서 절반 상한일 때 실패)와 함께 §E.2 Deviation 2와 §E.4에 기록되어 있다. 기록된 허용 편차로 본다. 다만 이것을 "REQ와 다른 값"이라고 적은 §E.4 표현은 정확하지 않다(C3, Low).

### 3.6 감점 이유

- AC-006은 "한 번의 pump" 대신 최대 3프레임 추가 정착을 허용하도록 테스트가 맞춰졌다(Deviation 3). 지연 배치 목록의 범위 재추정 때문이라는 설명은 타당하지만 AC 문구보다 느슨하다.
- AC-007의 heavy 진동은 "도착 시 1회 이상"으로 단언한다(기존 `ApprovalListener`와 중복 발생, Deviation 4). 기존 동작이라 이 SPEC의 결함은 아니다.
- TalkBack·VoiceOver·실제 진동은 확인하지 않았다(SPEC 자체가 자동 범위 밖으로 둠).

## 4. Security — 95, PASS

```
$ git diff ba1ee17..9bf5f82 | grep -E '^\+' | grep -inE 'api[_-]?key|secret|token\s*[:=]\s*["'"'"'][A-Za-z0-9]|password|bearer |sk-[A-Za-z0-9]{10}|AKIA|-----BEGIN|https?://[^ ]*@'
(출력 없음)

$ git diff ba1ee17..9bf5f82 | grep -E '^\+' | grep -oE 'https?://[^ )"'"'"']+' | sort -u
(출력 없음 — 새 URL 없음)

$ git diff ba1ee17..9bf5f82 -- app/pubspec.yaml app/pubspec.lock server/package.json server/package-lock.json
(출력 없음 — 의존성 변경 없음)
```

변경은 화면·테마·테스트에 한정되고, 네트워크·데이터·라우터·서버 경로는 바뀌지 않았다(§3.3). `.moai/state/verify/`는 git에 올라가 있지 않다(`git ls-files .moai/state/verify` 출력 없음). 5점 감점은 OWASP 항목별 점검을 따로 하지 않았기 때문이다(UI 전용 변경이라 해당 범위가 좁다).

## 5. Craft — 80, UNVERIFIED (커버리지)

- analyze는 기준선과 같다(§2: info 1건 `test/support/fakes.dart:54:5`). run 시작 기준선(§E.2)도 같은 위치 `54:5`다. `fakes.dart`가 이번에 23줄 바뀌었지만 새 경고는 없다.
- 커버리지: 이번 감사에서 `flutter test --coverage`를 실행하지 않았고, run·sync 기록에도 커버리지 수치가 없다. 85% 기준 충족 여부는 **UNVERIFIED**다. 필수 차원이 아니므로 판정을 바꾸지 않는다.
- 테스트 순서: §E.2가 "production code was written first and the new tests after it"라고 솔직히 적었다. TDD의 RED 증거가 없으므로 새 테스트가 구현 전에 실패했을지는 확인되지 않는다. 대신 새 테스트가 구현 결함 4건(넘침, 의미 노드 병합, 스크롤 끝 위치, 300px 고정 영역)을 실제로 잡았다는 기록이 있다.
- `dart format`을 10개 파일에 적용해 diff에 줄바꿈 변경이 섞였다(Deviation 5). 프로젝트 전체 포맷은 되돌렸다고 기록되어 있고, 변경 파일 목록이 계획과 일치하므로(§3.4) 계획 밖 파일로 번지지 않았음은 확인된다.

## 6. Consistency — 80, PASS

### 6.1 spec.md

```
$ git show 9bf5f82 -- .moai/specs/SPEC-UX-001/spec.md
-status: in-progress
+status: implemented
-updated: 2026-11-25
+updated: 2026-11-27
```

sync 커밋은 frontmatter `status`·`updated`만 바꿨다. 본문 변경 없음. 구현 커밋 `d63740d`도 `draft → in-progress`와 `updated`만 바꿨다.

### 6.2 §E.4 숫자 ↔ `.moai/state/verify/ux-sync/`

| §E.4 항목 | 증거 파일 내용 | 일치 |
|-----------|----------------|------|
| `00:08 +80: All tests passed!` | app-test.txt 마지막 줄 `00:08 +80: All tests passed!` | 예 |
| analyze 1 issue, fakes.dart:54:5 | analyze.txt `… test/support/fakes.dart:54:5 … 1 issue found. (ran in 1.6s)` | 예 |
| 14 files / 387 tests | server-test.txt `Test Files  14 passed (14)` / `Tests  387 passed (387)` | 예 |
| typecheck exit 0 | server-typecheck.txt 4줄(`> tsc -p tsconfig.json --noEmit`), 오류 문구 없음 | 예(파일에 종료 코드 자체는 없음 — 오류 출력 부재로만 확인) |

### 6.3 문서 ↔ 실제 기호

`git show 9bf5f82 -- structure.md codemaps/modules.md`의 추가 줄과 실제 선언을 대조했다.

| 문서 기재 | 실제 코드 | 일치 |
|-----------|-----------|------|
| `AppCard`, `SectionCard`, `BulletList`, `MessageView`, `PulsingDot`, `ResponsiveBody`, `runWithFeedback`, `describeError` | common.dart:8, 32, 103, 126, 164, 212, 258, 269 | 예 |
| `CardTone`(neutral·attention·positive·caution·critical), `ToneColors`, 상태 색 | app_theme.dart:66 `enum CardTone { neutral, attention, positive, caution, critical }`, :71 `class ToneColors`, :84 `extension StatusColors` | 예 |
| `AppSpace`(4~32) | tokens.dart:10-16 `4, 8, 12, 16, 20, 24, 32` | 예 |
| `AppRadius`(12·16·20·pill) | tokens.dart:21-24 `12, 16, 20, 999` | 예 |
| `AppMotion`(150·250·400 ms, `pulse` 1100 ms) | tokens.dart:29-34 | 예 |
| `kMinTapTarget`(48), `motionDuration`, `scrollToOffset`, `relativeLuminance`, `contrastRatio` | tokens.dart:38, 41, 45, 55, 61 | 예 |

### 6.4 §E.4 편차 목록 ↔ §E.2

§E.4 `deviations`는 §E.2 "Deviations for sync / plan-auditor" 1~6번(한 커밋, REQ-011 상한, AC-006 pump, AC-007 heavy 진동 중복, dart format 10개 파일, 기기 확인 보류)과 항목·순서가 같다.

### 6.5 감점 이유

C1~C4(§7) 참조.

## 7. 결함 목록

### C1 [Medium] [non-blocking] §E.4 후속 SPEC 선행 조건 메모가 사실과 다르다

- 위치: `.moai/specs/SPEC-UX-001/progress.md` §E.4 `downstream_note_spec_module_001`
- 메모 원문: "this repository's sync terminal status is `implemented` …, which satisfies that precondition"
- 대조한 원문:
  - `SPEC-MODULE-001/acceptance.md:31` "선행: SPEC-UX-001 `status: completed`"
  - `SPEC-MODULE-001/plan.md:164` "run 시작 전 SPEC-UX-001이 `completed`인지 확인한다(`grep '^status' …`)"
  - `SPEC-MODULE-001/spec.md:15` `depends_on: [SPEC-UX-001]`
  - `.claude/rules/moai/workflow/spec-workflow.md` § Depends_on Pre-flight Check: "fulfillment is defined as the dependency SPEC's `status: completed` — all other 7 status values … are considered unfulfilled"
- 의미: 현재 `status: implemented`이므로 SPEC-MODULE-001의 run 진입 사전 점검은 문자 그대로 실패한다. sync 기록이 다른 SPEC의 선행 조건을 "충족"이라고 단정한 것은 확인되지 않은 주장이다. 이 저장소의 다른 SPEC(STORE·LIFECYCLE·POLICY·OUTCOME·ARCH)도 `implemented`에 머문다는 점은 확인했으므로 관례 자체는 일관되지만, 판단 권한은 이 sync 기록이 아니라 사용자에게 있다.
- 필요한 조치: (가) UX-001을 `completed`로 올리거나, (나) SPEC-MODULE-001 선행 조건을 `implemented`로 고치거나(manager-spec), (다) MODULE-001 run 진입 때 `--ignore-deps`와 근거를 기록한다. 셋 중 하나를 사용자가 정해야 한다. 그때까지 §E.4 메모는 "충족"이 아니라 "판단 필요"로 읽어야 한다.

### C2 [Low] 종료 상태가 스키마 기준과 다르다

- `.claude/rules/moai/development/spec-frontmatter-schema.md`의 상태 전이 표는 sync 커밋이 `in-progress → implemented → completed`를 함께 싣는다고 정한다. 이번 sync는 `implemented`에서 멈췄다. 저장소 선례(다섯 SPEC 모두 `implemented`)와는 맞으므로 Low로 둔다. C1의 근본 원인이다.

### C3 [Low] REQ-011 편차의 표현이 부정확하다

- §E.4 `as_implemented_value_difference`가 "REQ body not edited, kept for owner review"로 적어 REQ와 다른 값처럼 읽힌다. 실제로는 REQ-011·AC-011을 충족하고(§3.5), 어긋나는 것은 plan.md §B 설계 메모다. 기능 판정에는 영향이 없다. 원하면 plan.md 메모를 "보통 크기 2/3"로 맞추는 정도면 된다.

### C4 [Low] `sync_commit_sha`가 실제 SHA가 아니다

- §E.4 `sync_commit_sha: "the docs(SPEC-UX-001) sync commit that adds this section (resolve via git log)"`. 커밋은 자기 SHA를 담을 수 없으므로 자리 표시는 정상이지만, 스키마가 말하는 후속 채움(`9bf5f82`)이 아직 없다. `era.go`는 필드 존재만 보므로 분류에는 지장이 없다.

### F1 [Low, 확신도 중간] 새 테스트가 구현 뒤에 작성됐다

- §E.2 RED/GREEN 기록이 스스로 밝힌 내용이다. TDD 모드인데 RED 증거가 없다. 새 테스트가 실제 결함을 잡은 기록이 있어 테스트가 비어 있지는 않다. 판정에는 영향 없음.

### F2 [Info] 선행 SPEC 상태

- UX-001이 의존하는 SPEC-FOLLOWUP-001(및 APPROVAL·INTAKE)은 아직 `status: in-progress`다(`grep -H '^status' .moai/specs/SPEC-*/spec.md`). run 단계에서 이미 진행된 일이라 이번 sync 판정 대상은 아니지만, 위 세 SPEC의 sync가 아직 남아 있다는 뜻이다.

## 8. 확인하지 못한 것 (Gaps)

- 커버리지 수치(측정하지 않음).
- 서버 테스트·typecheck는 다시 돌리지 않았다. 서버 무변경은 diff로 확인했고, 수치는 sync 증거 파일로만 대조했다. typecheck 증거 파일에는 종료 코드가 적혀 있지 않다.
- TalkBack·VoiceOver 읽기, 실제 진동, 실제 기기 글꼴에서의 줄바꿈.
- 비밀 값 검사는 정규식 기반이다. 전용 비밀 탐지 도구는 돌리지 않았다.

## 9. 잔여 위험

- `textContrastGuideline`은 위젯 색 추정치라 반투명 겹침 배경에서는 실제와 다를 수 있다(AC-002 직접 계산이 일부 보완).
- AC-006 스크롤 정착을 최대 3프레임까지 허용하므로, 목록 길이가 크게 달라지면 프레임 수가 더 필요할 수 있다.
- 보통 글자 크기에서 고정 영역이 화면의 2/3까지 커질 수 있어, 작은 화면에서는 대화 내용이 보이는 높이가 좁다.

## 10. 최종 판정

**PASS** — Functionality 90, Security 95, Craft 80(UNVERIFIED), Consistency 80, 조화 평균 85.8(가중 87.3). 필수 차원 두 개 모두 통과. 차단 결함은 없다. 다만 C1 때문에 SPEC-MODULE-001 run 진입 전에 종료 상태(`implemented`/`completed`) 처리를 사용자가 정해야 한다.
