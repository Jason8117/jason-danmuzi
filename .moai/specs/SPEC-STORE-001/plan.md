# SPEC-STORE-001 구현 계획

## A. 접근 방식

`JsonFileTaskStore`가 쓰기 실패를 스스로 흡수하도록 바꾼다. 핵심은 세 가지다.

1. **체인 분리**: 쓰기 직렬화는 유지하되, 각 시도의 결과를 체인에 넘기기 전에 내부에서 처리한다. 다음 시도는 이전 시도의 성공 여부와 상관없이 실행된다.
2. **늦은 스냅숏**: 스냅숏은 예약 시점이 아니라 실제 쓰기 직전에 만든다. 재시도가 성공하면 그 시점의 전체 상태가 기록된다.
3. **두 종류의 저장 진입점**: 백그라운드 저장(디바운스·재시도)은 절대 거부되지 않는 경로로, 종료 시 최종 저장은 마감 시간과 성공 여부를 돌려주는 경로로 나눈다. 인터페이스의 `flush(): Promise<void>`는 유지하고, 종료 경로가 쓸 결과 보고 메서드를 추가한다(예: `finalFlush(): Promise<{ ok: boolean; reason? }>`). 정확한 이름은 RED 테스트를 쓰면서 확정한다.

테스트 가능성을 위해 `JsonFileTaskStore.open(path, options)`에 선택 인자를 둔다: 파일 시스템 계층(`readFile/writeFile/rename/mkdir`), 로거, 재시도 설정, 최종 저장 마감. 기본값은 현재 동작과 같다.

### 기본값 (테스트에서 덮어씀)

| 항목 | 기본값 | 근거 |
|------|--------|------|
| 디바운스 | 300 ms | 현재 값 유지 (`taskStore.ts:84`) |
| 첫 재시도 지연 | 1 s | 일시적 오류에 빠르게 대응 |
| 배수 / 상한 | ×2 / 30 s | 장기 장애 때 로그 폭주와 디스크 부하 방지 |
| 최종 저장 마감 | 5 s | SPEC-LIFECYCLE-001의 전체 종료 마감 9 s = 통화 종료 3 s + HTTP 종료 1 s + 최종 저장 5 s 중 마지막 단계 |

재시도 횟수에는 상한을 두지 않는다. 메모리에 아직 저장되지 않은 변경이 있는 한 상한 지연 간격으로 계속 시도한다. 시도 횟수에 상한을 두면 변경이 조용히 영원히 유실되기 때문이다. "제한된 백오프"는 지연 간격의 상한을 뜻한다.

### 고정 로그 메시지

| 메시지 | 수준 | 시점 |
|--------|------|------|
| `Store write failed` | error | 백그라운드 쓰기 실패마다 1건 |
| `Store write recovered` | info | 실패 뒤 첫 성공 1건 |
| `Final store flush failed` | error | 최종 저장 실패 시 정확히 1건(`index.ts`가 남김) |

세 문자열은 `taskStore.ts`에 상수로 정의하고 테스트가 같은 상수를 가져다 쓴다.

### 기동 동작

손상 파일 격리는 하지 않는다(OD-1 RESOLVED). `open()`의 읽기·해석 경로는 바꾸지 않고, 현재 동작(손상·읽기 불가 시 거부, 파일 불변)을 보호 테스트로 고정한다.

## B. 변경 파일

| 파일 | 변경 | 이유 |
|------|------|------|
| `server/src/store/taskStore.ts` | 수정 | 체인 분리, 재시도, 최종 저장 결과 보고, 고정 로그 메시지, 주입 가능한 의존성 |
| `server/src/index.ts` | 수정 | 저장소에 로거 전달, 종료 시 최종 저장 결과에 따라 실패 문구와 종료 코드 결정 (REQ-012) |
| `server/src/store/taskStore.test.ts` | 신규 | 결함 주입 테스트, 재현 회귀 테스트, 기동 동작 보호 테스트 |

`InMemoryTaskStore`와 `TaskStore` 인터페이스의 기존 메서드 시그니처는 그대로 둔다. `app.test.ts`가 `InMemoryTaskStore`를 쓰므로 바뀌면 안 된다.

## C. 마일스톤 (우선순위 순, 하나씩 순서대로)

### M1 — 쓰기 실패 격리 (Priority High)

RED 테스트 (`server/src/store/taskStore.test.ts`):
- 첫 쓰기가 실패하는 주입 계층에서 `save()` 후 디바운스가 지나도 처리되지 않은 거부가 없다(AC-001).
- 첫 쓰기 실패, 두 번째 쓰기 성공으로 주입하면 두 번째 시도가 성공한다(AC-003).
- 쓰기 실패 중에도 `get/list/save/delete`가 정상 동작한다(AC-004, 보호).

### M2 — 재시도와 복구 (Priority High)

M1이 끝난 뒤 시작한다.

RED 테스트:
- 실패 시 `Store write failed` error 로그(경로, 코드, 횟수) — AC-005.
- 가짜 타이머로 지연 1 → 2 → 4 → 8 → 16 → 30 → 30 s — AC-006.
- 재시도 대기 중 여러 번 `save()`해도 쓰기는 한 번 — AC-007.
- 실패 사이에 추가된 작업까지 포함한 전체 상태가 성공한 쓰기에 담김 — AC-008.
- `Store write recovered` info 로그 1건, 지연 초기화 — AC-009.
- 실패한 쓰기 뒤에도 기존 `tasks.json` 내용이 그대로 — AC-010.

### M3 — 최종 저장과 종료 코드 (Priority High)

RED 테스트:
- 최종 저장은 대기 중인 타이머를 모두 취소한다 — AC-011.
- 실패하면 실패 결과를 돌려주며 거부로 터지지 않고, 끝나지 않는 쓰기에서도 마감 시간에 시간 초과 실패를 돌려준다 — AC-012.
- `index.ts` 종료 처리(실패 문구 1건 + 종료 코드 1)는 acceptance의 프로세스 단위 절차로 확인 — AC-013.

### M4 — 기동 동작 보호와 재현 회귀 테스트 (Priority Medium)

- 손상 JSON·읽기 오류 → `open()` 거부, 파일 불변. `version` 없는 항목 → 0. 파일 없음 → 빈 저장소 — AC-014(현재 코드에서 통과하는 보호 테스트).
- 이 세션에서 재현한 시나리오(디렉터리 `chmod 555` 후 저장)를 실제 파일 시스템으로 재현 — AC-002. root로 실행 중이거나 Windows이면 건너뛴다.
- 전체 테스트와 타입 검사 — AC-015.

## D. 위험 요소

| 위험 | 내용 | 대응 |
|------|------|------|
| 파일 겹침 | 아래 §D.1 행렬 참조. 이 SPEC은 `server/src/index.ts`만 다른 SPEC과 공유한다. | 이 SPEC을 가장 먼저 구현한다. `index.ts`의 종료 처리는 "최종 저장 결과 → 실패 문구 → 종료 코드"만 바꾼다. SPEC-LIFECYCLE-001이 이 부분을 종료 모듈로 옮길 때 메시지 상수와 종료 코드 규칙을 그대로 유지한다. |
| root 권한 테스트 | CI가 root로 돌면 `chmod 555`가 쓰기를 막지 못해 재현 테스트가 거짓 통과한다. | root·Windows에서는 건너뛰고, 핵심 검증은 주입 계층 테스트가 맡는다. |
| 가짜 타이머와 Promise | 가짜 타이머만 진행하면 비동기 쓰기의 후속 처리가 안 돌 수 있다. | `vi.advanceTimersByTimeAsync`를 쓴다. |
| 손상·읽기 불가 파일 | 기동이 실패하므로 그 안의 진행 중 작업은 복구도, 실통화 종료도 되지 않는다(SPEC-LIFECYCLE-001 복구가 실행되지 않음). | OD-1 RESOLVED에 따라 받아들인 잔여 위험. spec.md §6과 SPEC-LIFECYCLE-001에 같은 내용을 기록. |
| 다중 인스턴스 | 두 프로세스가 같은 `DATA_FILE`을 쓰면 서로 덮어쓴다. | 단일 인스턴스 가정을 spec.md §4에 명시. |

### D.1 다섯 SPEC 파일 겹침 행렬 (plan-audit iteration 1 §3.1 기준)

| 파일 | STORE | LIFECYCLE | POLICY | OUTCOME | ARCH |
|------|:-----:|:---------:|:------:|:-------:|:----:|
| server/src/index.ts | O | O | | | O |
| server/src/services/callService.ts | | O | O | | O |
| server/src/services/callService.test.ts | | 신규 | O | | O |
| server/src/domain/types.ts | | O | | O | O |
| server/src/providers/types.ts | | O | | | O |
| server/src/providers/kat/katProvider.ts (+test) | | O | | | O |
| server/src/providers/simulatedProvider.ts | | 확인 | | | O |
| server/src/container.ts | | O | | | O |
| server/src/http/app.ts | | | O | | O |
| server/src/http/app.test.ts | | | O | O | O |
| server/src/brain/heuristicBrain.ts | | | | O | O |
| server/src/brain/openaiBrain.ts | | | | O | |
| server/src/brain/openaiBrain.test.ts | | | | 신규 | O |
| app/test/unit_test.dart | | O | | O | O |

한 SPEC만 쓰는 파일(겹침 없음): STORE `taskStore.ts`·`taskStore.test.ts`, LIFECYCLE `shutdown.ts`·`shutdown.test.ts`, POLICY `phone.ts`·`domain.test.ts`, OUTCOME 앱 모델·카드·`heuristicBrain.test.ts`·`outcome_card_test.dart`, ARCH 새 스키마·테스트 파일.

## E. 하네스·복잡도 지표

| 지표 | 값 |
|------|-----|
| 도메인 수 | 1 (server 저장소) |
| 변경 파일 수 | 3 (신규 1, 수정 2) |
| REQ / AC | 14 / 15 (Tier M 상한 16 이내) |
| 외부 연동 | 없음 (파일 시스템만) |
| 권장 하네스 | standard |

## F. 자체 검증 (run-phase 완료 조건)

- `server/src/store/taskStore.test.ts`의 새 테스트가 처음에는 실패(RED)하고 구현 뒤 통과(GREEN)했음을 `progress.md` §E.2에 원문으로 기록.
- `npm test` 전체 통과, 기준선 33개 테스트 유지 + 새 테스트 추가.
- `npm run typecheck` exit 0. (참고: `tsconfig.json`은 `src/**/*.test.ts`를 제외하므로 테스트 파일의 타입 오류는 이 명령으로 잡히지 않는다.)

## G. sync-phase 문서 항목

- 운영 안내: 데이터 파일이 손상되었거나 읽을 수 없으면 서버가 기동하지 않으며, 그 안의 진행 중 작업과 실통화는 서버가 정리할 수 없다(OD-1 RESOLVED 잔여 위험).
- 운영 안내: 한 `DATA_FILE`은 한 서버 프로세스만 쓴다.
- 로그 메시지 세 가지(`Store write failed`, `Store write recovered`, `Final store flush failed`)와 종료 코드 규칙.
