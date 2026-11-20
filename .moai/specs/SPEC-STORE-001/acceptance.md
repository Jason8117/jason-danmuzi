# SPEC-STORE-001 인수 기준

## 공통 검증 명령

서버 명령은 모두 아래 PATH 설정을 앞에 붙여 실행한다.

```bash
export PATH=/opt/homebrew/Cellar/node/23.7.0/bin:$PATH
npm --prefix /Users/jason/Documents/Jason-Danmuzi/Jason-Danmuzi/server test -- src/store/taskStore.test.ts   # 이 SPEC의 테스트만
npm --prefix /Users/jason/Documents/Jason-Danmuzi/Jason-Danmuzi/server test                                   # 전체
npm --prefix /Users/jason/Documents/Jason-Danmuzi/Jason-Danmuzi/server run typecheck
```

기준선(오케스트레이터 측정, plan-auditor 재측정): `npm run typecheck` exit 0, `npm test` 3개 파일 / 33개 테스트 통과(vitest 5.1.1).

TDD 규칙: 아래 각 기준의 테스트는 구현보다 먼저 작성하고, 현재 코드에서 실패하는 것을 확인한 뒤 구현한다. "RED"는 현재 코드에서 관찰되어야 하는 실패, "GREEN"은 구현 뒤 기대 결과다. "보호"라고 표시한 기준은 현재 코드에서도 통과해야 하는 동작 고정 테스트다.

## 인수 기준

### AC-001 — 백그라운드 저장 실패가 프로세스를 죽이지 않는다 (REQ-001)

- **Given** 쓰기를 항상 `EACCES`로 실패시키는 파일 시스템 계층을 주입한 저장소
- **When** `save(task)`를 호출하고 디바운스 시간을 지나도록 타이머를 진행하면
- **Then** 처리되지 않은 Promise 거부가 0건이다
- 테스트: `server/src/store/taskStore.test.ts` — "background flush failure never becomes an unhandled rejection"
- RED: 현재 코드에서는 `void this.flush()`의 거부가 처리되지 않아 감시자가 1건을 기록하거나 vitest가 미처리 오류로 실패를 보고한다.

### AC-002 — 재현 시나리오 회귀 테스트 (REQ-001)

- **Given** 임시 디렉터리 안의 `tasks.json`으로 연 실제 저장소, 그리고 그 디렉터리의 권한을 `0o555`로 바꾼 상태
- **When** `save(task)` 후 디바운스 시간을 지나도록 기다리면
- **Then** 처리되지 않은 거부가 없고, 권한을 되돌린 뒤 다음 재시도에서 파일에 작업이 기록된다
- 테스트: "survives a read-only data directory (regression)". `process.getuid?.() === 0`이거나 `win32`이면 `it.skip`.
- RED: 현재 코드에서는 미처리 거부 발생.

### AC-003 — 실패한 쓰기가 다음 쓰기를 오염시키지 않는다 (REQ-002)

- **Given** 첫 번째 쓰기는 실패하고 두 번째부터 성공하는 주입 계층(동시 호출 수 최대값을 기록)
- **When** 첫 저장이 실패한 뒤 다음 저장을 시도하면
- **Then** 두 번째 시도는 성공하고 파일 내용이 메모리 상태와 같으며, 기록된 동시 쓰기 최대값이 1이다
- 테스트: "a failed write does not poison later writes"
- RED: 현재 코드에서는 `this.writing`이 거부 상태로 남아 두 번째 `flush()`도 같은 오류로 거부된다.

### AC-004 — 실패 중에도 메모리 연산은 정상 (REQ-003, 보호)

- **Given** 쓰기가 계속 실패하는 저장소
- **When** `save/get/list/delete`를 차례로 호출하면
- **Then** 모두 즉시 기대한 값을 돌려주고 예외가 없다
- 테스트: "reads and writes keep working in memory while persistence fails"

### AC-005 — 쓰기 실패 기록 (REQ-004)

- **Given** 계속 실패하는 주입 계층(`EACCES`)과 호출을 기록하는 가짜 로거
- **When** `save()` 후 첫 시도가 실패하면
- **Then** error 로그가 정확히 1건이고, 메시지가 `"Store write failed"`이며, 객체에 경로, `code: "EACCES"`, 연속 실패 횟수 `1`이 있고, 작업 내용(전화번호 문자열)이 없다
- 테스트: "logs each failed write once with path, code and count"
- RED: 현재 코드는 로그를 남기지 않는다.

### AC-006 — 상한 있는 지수 백오프 (REQ-005)

- **Given** 가짜 타이머, 계속 실패하는 주입 계층, 재시도 설정(초기 1 s, ×2, 상한 30 s)
- **When** `save()` 후 타이머를 단계적으로 진행하면
- **Then** 시도 간격이 1, 2, 4, 8, 16, 30, 30 s로 이어지고 시도가 멈추지 않는다
- 테스트: "retries with capped exponential backoff"
- RED: 현재 코드에는 재시도가 없다.

### AC-007 — 재시도 대기 중 시도 합치기 (REQ-006)

- **Given** AC-006의 상태에서 재시도가 예약된 저장소
- **When** 다음 재시도 전에 `save()`를 5번 더 호출하고 그 재시도 시점까지 진행하면
- **Then** 그 구간의 쓰기 시도는 정확히 1회다
- 테스트: "coalesces saves while a retry is pending"

### AC-008 — 복구된 쓰기는 현재 상태 전체를 기록 (REQ-007)

- **Given** 두 번 실패 후 성공하는 주입 계층
- **When** 작업 A 저장 → 실패 → 작업 B 저장 → 실패 → 재시도 성공
- **Then** 기록된 JSON에 A와 B가 모두 있다
- 테스트: "the next successful write persists the full current state"
- RED: 현재 코드에서는 체인 오염 때문에 성공하는 쓰기가 일어나지 않는다.

### AC-009 — 복구 기록과 지연 초기화 (REQ-008)

- **Given** AC-008의 시나리오와 가짜 로거
- **When** 재시도가 성공한 뒤 다시 한 번 실패를 주입하면
- **Then** `"Store write recovered"` info 로그가 정확히 1건이고, 새 실패의 첫 재시도 지연이 1 s다
- 테스트: "logs recovery once and resets the backoff"

### AC-010 — 실패해도 기존 파일은 보존 (REQ-009)

- **Given** 작업 A가 저장된 임시 디렉터리의 `tasks.json`, 그리고 rename만 실패시키는 주입 계층
- **When** 작업 B를 저장하려다 실패하면
- **Then** `tasks.json`은 A만 담은 직전 내용 그대로다
- 테스트: "a failed write leaves the previous file intact" (보호 성격이지만 주입 계층이 필요하므로 M2에서 작성)

### AC-011 — 최종 저장은 대기 타이머를 취소 (REQ-010)

- **Given** 디바운스 타이머 1개가 걸린 저장소, 그리고 재시도 타이머 1개가 걸린 저장소(각각 가짜 타이머)
- **When** 최종 저장을 호출하고 끝난 뒤 `vi.getTimerCount()`를 보면
- **Then** 두 경우 모두 0이고, 쓰기는 최종 저장의 1회뿐이다
- 테스트: "final flush cancels pending debounce and retry timers"
- RED: 최종 저장 메서드가 없다.

### AC-012 — 최종 저장은 결과를 알리고 멈추지 않는다 (REQ-011)

- **Given** (1) 실패하는 주입 계층, (2) 끝나지 않는 쓰기를 흉내 내는 주입 계층과 마감 100 ms 주입(가짜 타이머)
- **When** 최종 저장을 호출하면
- **Then** (1)은 거부 없이 실패 결과를, (2)는 100 ms 진행 뒤 거부 없이 시간 초과 실패 결과를 돌려준다. 성공하는 계층에서는 성공 결과를 돌려준다
- 테스트: "final flush reports success or failure and never hangs"
- RED: 현재 `flush()`는 실패 시 거부되고, 끝나지 않는 쓰기에서는 영원히 기다린다.

### AC-013 — 프로세스 단위 확인: 생존 + 실패 문구 1건 + 종료 코드 1 (REQ-001, REQ-012)

수동 검증. 아래 절차를 그대로 실행한다.

```bash
export PATH=/opt/homebrew/Cellar/node/23.7.0/bin:$PATH
D=$(mktemp -d); cd /Users/jason/Documents/Jason-Danmuzi/Jason-Danmuzi/server
DATA_FILE=$D/tasks.json PORT=18787 ./node_modules/.bin/tsx src/index.ts > $D/log.txt 2>&1 &   # 시뮬레이션 모드(키 없음)
PID=$!; sleep 2; chmod 555 $D
curl -s -o /dev/null -w 'POST=%{http_code}\n' -X POST localhost:18787/v1/tasks -H 'content-type: application/json' \
  -d '{"targetName":"x","phoneNumber":"010-1234-5678","goal":"영업시간 문의","requesterName":"김"}'
sleep 1; curl -s -o /dev/null -w 'health=%{http_code}\n' localhost:18787/health
kill -TERM $PID; wait $PID; echo "exit=$?"
echo "final_fail_count=$(grep -c '"msg":"Final store flush failed"' $D/log.txt)"
chmod 755 $D
```

- GREEN은 세 조건을 **모두** 만족할 때만이다: `health=200` **그리고** `exit=1` **그리고** `final_fail_count=1`.
- RED(현재 코드, plan-auditor가 관찰): `health=000`(응답 없음), `exit=1`(크래시도 1), `final_fail_count=0`. 종료 코드만으로는 RED와 GREEN을 가를 수 없으므로 세 조건을 함께 본다.
- 참고: SPEC-LIFECYCLE-001 구현 뒤에도 같은 절차가 같은 결과를 내야 한다(활성 통화가 없으므로 종료 단계는 저장 단계만 의미가 있다).

### AC-014 — 기동 동작 유지 (REQ-013, REQ-014, 보호)

- **Given** 임시 디렉터리에 (1) `{not json` 내용의 `tasks.json`, (2) 읽기에서 `EACCES`를 던지는 주입 계층, (3) `version`이 없는 정상 작업 배열 파일, (4) 파일 없음
- **When** `JsonFileTaskStore.open()`을 호출하면
- **Then** (1)(2)는 거부되고 디렉터리의 파일 목록과 `tasks.json` 내용이 호출 전과 같다(새 파일 없음). (3)은 작업이 `version: 0`으로 적재된다. (4)는 빈 저장소로 열린다
- 테스트: "keeps current startup behavior: corrupt or unreadable files fail, legacy entries load"
- 이 기준은 현재 코드에서 통과해야 한다. 구현 중 기동 경로가 바뀌지 않았음을 지키는 테스트다.

### AC-015 — 회귀 없음

- `npm test` 전체 통과: 기준선 33개 테스트 모두 통과 + 이 SPEC의 새 테스트 추가.
- `npm run typecheck` exit 0.
- `server/src/http/app.test.ts`는 수정 없이 통과한다(`InMemoryTaskStore` 의미 불변).

## 엣지 케이스

- 디바운스 대기 중에 최종 저장이 호출되는 경우: AC-011에 포함.
- 재시도 중 `delete()`만 일어난 경우: 삭제가 반영된 상태가 다음 성공 쓰기에 기록된다(AC-008 변형으로 추가 가능).

## 잔여 위험

- 손상되었거나 읽을 수 없는 데이터 파일이 있으면 기동이 실패하고, 그 안의 진행 중 작업은 복구되지 않으며 그 작업의 실통화도 서버가 끊을 수 없다(OD-1 RESOLVED, SPEC-LIFECYCLE-001 잔여 위험과 같음).
- 최종 저장 5 s는 실제 배포 환경의 종료 유예(가정 10 s)에 맞춘 값이다. 배포 환경이 정해지면 다시 본다.

## 완료 정의 (Definition of Done)

- AC-001 ~ AC-015 충족. AC-013은 절차 출력(`POST=`, `health=`, `exit=`, `final_fail_count=` 네 줄)을 `progress.md` §E.2에 원문 그대로 기록.
- 새 로그 메시지에 전화번호·대화 내용이 없음(AC-005의 단언과 코드 리뷰).
