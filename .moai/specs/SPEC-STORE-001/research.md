# SPEC-STORE-001 근거 자료

모든 줄 번호는 커밋 `f4d531e` 기준 작업 트리에서 직접 읽어 확인했다.

## 1. 쓰기 체인 오염

`server/src/store/taskStore.ts:69-80`

- `:72` 스냅숏은 `flush()` 호출 시점에 만든다.
- `:73-78` `this.writing = this.writing.then(async () => { mkdir; writeFile(tmp); rename(tmp, path) })`
- `:79` `await this.writing`

`then`에 거부 처리가 없으므로 한 번 거부된 `this.writing`은 계속 거부 상태다. 다음 `flush()`의 `this.writing.then(...)`은 콜백을 실행하지 않고 같은 거부를 그대로 넘긴다. 즉 첫 실패 뒤로는 쓰기를 다시 시도조차 하지 않는다(REQ-002의 근거).

## 2. 미처리 거부로 인한 프로세스 종료

`server/src/store/taskStore.ts:82-85`

- `:84` `this.timer = setTimeout(() => void this.flush(), 300);`

`void`는 Promise를 버릴 뿐 거부를 처리하지 않는다. Node(이 세션 23.7.0)의 기본 `--unhandled-rejections=throw` 동작으로 프로세스가 종료된다.

**재현(오케스트레이터가 이 세션에서 관찰)**: `DATA_FILE`을 한 디렉터리에 두고 서버를 띄운 뒤 그 디렉터리를 `chmod 555`로 바꾸고 `POST /v1/tasks`를 호출했다. 응답은 201이었고, 약 300 ms 뒤 프로세스가 `Error: EACCES: permission denied, open '.../tasks.json.tmp'` 로그와 함께 종료되었다. 이후 `/health`는 응답이 없었다. 이 SPEC 작성자(manager-spec)는 이 재현을 다시 실행하지 않았다. 위 내용은 오케스트레이터가 전달한 관찰 결과다.

## 3. 저장 호출 빈도

`server/src/services/callService.ts:342-347` `persist()`가 모든 상태 변화(대화 한 줄 추가 포함, `:224-230`)마다 `store.save()`를 부른다. 통화 중에는 저장 요청이 잦으므로, 실패 시 저장마다 재시도를 따로 만들면 쓰기가 폭주한다. 시도를 합치는 REQ-005의 근거다.

## 4. 기동 시 파일 읽기

`server/src/store/taskStore.ts:47-56`

- `:50` `readFile(path, "utf8")`
- `:51` `JSON.parse(raw) as CallTask[]`를 그대로 순회하며 `version ?? 0` 보정
- `:52-54` `ENOENT`가 아니면 다시 던짐

구문 오류(`SyntaxError`)는 `code`가 없으므로 다시 던져져 기동이 실패한다. 최상위가 객체이면 `for…of`에서 반복 불가 오류가 난다. 항목에 `id`가 없으면 `undefined` 키로 적재된다. 어느 경우에도 백업은 없다.

## 5. 기동·종료 경로

`server/src/index.ts`

- `:8` `const store = await JsonFileTaskStore.open(config.DATA_FILE);` — 로거를 넘기지 않는다.
- `:30-36` SIGINT/SIGTERM 시 `app.close()` → `store.flush()` → `process.exit(0)`. `flush()`가 거부되면 처리되지 않은 거부가 되고, 끝나지 않으면 종료가 멈춘다.

로거: `server/src/logger.ts:1-16` — `info/warn/error(obj, msg)` JSON 한 줄 출력. 저장소에서 같은 인터페이스를 쓴다.

## 6. 기존 테스트와 영향

- `server/src/http/app.test.ts:29` `new InMemoryTaskStore()` 사용. `JsonFileTaskStore`, `TaskStore.flush`를 쓰는 테스트는 없다(`find src -name "*.test.ts"`에 `JsonFileTaskStore`를 import하는 파일 없음 — 이 세션에서 grep으로 확인).
- `server/tsconfig.json`의 `"exclude": ["src/**/*.test.ts"]` — `npm run typecheck`는 테스트 파일을 검사하지 않는다. 테스트 파일의 타입 오류는 vitest(타입 제거 후 실행)에서도 잡히지 않는다.
- 기준선: `npm test` 3개 파일 / 33개 테스트, `npm run typecheck` exit 0 (오케스트레이터 측정, 이 SPEC 작성 중 재실행하지 않음).

## 7. 관련 SPEC과의 접점

- SPEC-LIFECYCLE-001은 종료 처리를 "새 작업 차단 → 통화 종료(3 s) → `app.close()`(1 s) → 최종 저장(5 s) → 종료" 순서와 전체 마감 9 s로 다시 짠다. 이 SPEC은 그 마지막 단계(최종 저장 5 s, 결과 보고, 실패 문구, 종료 코드)를 먼저 확정한다.
- 손상 파일 격리는 소유자 결정(OD-1, 2026-11-21)으로 하지 않는다. 따라서 손상·읽기 불가 파일이 있으면 기동이 실패하고, SPEC-LIFECYCLE-001의 재기동 복구도 그 파일 안의 작업에 대해 실행되지 않는다(두 SPEC에 잔여 위험으로 기록).

## 8. 프로세스 단위 재현에서의 종료 코드 (plan-auditor 관찰)

plan-audit iteration 1 보고서 §4 C5: 현재 코드로 AC-013 절차를 실행하면 `POST=201`, `/health` 응답 없음(`000`), `exit=1`, 로그에 `EACCES`. 크래시도 종료 코드 1이므로 종료 코드만으로는 RED와 GREEN을 가를 수 없다. AC-013은 `/health` 200, 종료 코드 1, 고정 실패 문구 1건을 함께 본다.

`tsx`는 자식 프로세스의 신호와 종료 코드를 전달한다(같은 보고서 §4 C4). 그래서 `tsx src/index.ts`로 띄운 프로세스의 종료 코드로 판정할 수 있다.
