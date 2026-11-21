import { afterEach, describe, expect, it, vi } from "vitest";
import type { CallBrain } from "../brain/types.js";
import type { CallTask, TaskStatus } from "../domain/types.js";
import { EventBus, type ServerEvent } from "../events/eventBus.js";
import type { Logger } from "../logger.js";
import { KatCallProvider } from "../providers/kat/katProvider.js";
import type { CallProvider, CallSession } from "../providers/types.js";
import { InMemoryTaskStore } from "../store/taskStore.js";
import { CallService, type CallServiceOptions } from "./callService.js";

const PLAN = {
  openingLine: "안녕하세요",
  steps: ["용건 전달"],
  questionsToAsk: ["영업시간이 어떻게 되나요?"],
  approvalPoints: [],
  fallback: "정중히 마무리",
};

function makeTask(overrides: Partial<CallTask> = {}): CallTask {
  const timestamp = new Date().toISOString();
  return {
    id: "t-1",
    version: 1,
    status: "awaiting_approval",
    targetName: "가게",
    phoneNumber: "+821012345678",
    goal: "영업시간 문의",
    language: "ko",
    requesterName: "김",
    plan: PLAN,
    transcript: [],
    approvals: [],
    provider: "simulated",
    createdAt: timestamp,
    updatedAt: timestamp,
    ...overrides,
  };
}

interface LogEntry {
  level: "info" | "warn" | "error";
  obj: object;
  msg: string;
}

function recordingLogger() {
  const entries: LogEntry[] = [];
  const logger: Logger = {
    info: (obj, msg) => entries.push({ level: "info", obj, msg }),
    warn: (obj, msg) => entries.push({ level: "warn", obj, msg }),
    error: (obj, msg) => entries.push({ level: "error", obj, msg }),
  };
  return { logger, entries, warns: () => entries.filter((e) => e.level === "warn") };
}

/** A provider whose start() hands back the session, so tests can drive the call. */
class FakeProvider implements CallProvider {
  readonly sessions = new Map<string, CallSession>();
  readonly hangups: string[] = [];
  readonly terminated: string[] = [];
  hangupImpl: (taskId: string) => Promise<void> = async () => {};
  startImpl: (session: CallSession) => Promise<void> = async () => {};
  terminateImpl?: (providerCallId: string) => Promise<void>;

  constructor(readonly name: "simulated" | "kat" = "simulated") {}

  async start(session: CallSession): Promise<void> {
    this.sessions.set(session.taskId, session);
    await this.startImpl(session);
  }

  hangup(taskId: string): Promise<void> {
    this.hangups.push(taskId);
    return this.hangupImpl(taskId);
  }
}

/** Same as FakeProvider, plus the optional call-id based termination (a KAT-like provider). */
class FakeCallIdProvider extends FakeProvider {
  terminateByProviderCallId(providerCallId: string): Promise<void> {
    this.terminated.push(providerCallId);
    return this.terminateImpl ? this.terminateImpl(providerCallId) : Promise.resolve();
  }
}

function recordingBrain(): CallBrain & { summaries: number } {
  return {
    name: "heuristic",
    summaries: 0,
    async createPlan() {
      return PLAN;
    },
    async summarize() {
      this.summaries++;
      return { result: "success", summary: "요약", keyFacts: [], followUps: [] };
    },
  };
}

function setup(
  options: {
    provider?: CallProvider;
    tasks?: CallTask[];
    service?: Partial<CallServiceOptions>;
  } = {},
) {
  const store = new InMemoryTaskStore();
  for (const task of options.tasks ?? []) store.save(task);
  const bus = new EventBus();
  const events: ServerEvent[] = [];
  bus.subscribe((event) => events.push(structuredClone(event)));
  const brain = recordingBrain();
  const provider = options.provider ?? new FakeProvider();
  const log = recordingLogger();
  const calls = new CallService(store, bus, brain, provider, {
    maxConcurrentCalls: 5,
    maxCallsPerDay: 50,
    approvalTimeoutMs: 60_000,
    maxCallDurationMs: 600_000,
    logger: log.logger,
    ...options.service,
  });
  return { store, bus, events, brain, provider, calls, log };
}

/** Places an approved call and moves it to the given live status through the session API. */
async function startCall(calls: CallService, provider: FakeProvider, id: string, status: TaskStatus = "in_progress") {
  await calls.approvePlan(id);
  const session = provider.sessions.get(id)!;
  if (status === "ringing" || status === "in_progress") session.markRinging();
  if (status === "in_progress") session.markConnected();
  return session;
}

afterEach(() => {
  vi.useRealTimers();
});

describe("CallService provider call id (AC-006)", () => {
  it("stores the provider call id on the task", async () => {
    const provider = new FakeProvider("kat");
    provider.startImpl = async (session) => session.recordProviderCallId("c-1");
    const { calls, events } = setup({ provider, tasks: [makeTask({ provider: "kat" })] });

    await calls.approvePlan("t-1");

    expect(calls.get("t-1").providerCallId).toBe("c-1");
    expect(events.some((e) => e.type === "task.updated" && e.task.providerCallId === "c-1")).toBe(true);
  });
});

const SHUTTING_DOWN = {
  statusCode: 503,
  code: "shutting_down",
  message: "서버가 종료 중입니다. 잠시 후 다시 시도해 주세요.",
};

const INPUT = {
  targetName: "가게",
  phoneNumber: "+821012345678",
  goal: "영업시간 문의",
  language: "ko" as const,
  requesterName: "김",
};

describe("CallService shutdown flag (AC-001)", () => {
  it("rejects new work and new approvals while shutting down", async () => {
    const provider = new FakeProvider();
    const { calls, store } = setup({
      provider,
      tasks: [makeTask({ id: "live" }), makeTask({ id: "waiting" })],
    });
    const session = await startCall(calls, provider, "live");
    expect(calls.get("live").status).toBe("in_progress");

    calls.beginShutdown();

    // (a) create
    let createError: unknown;
    try {
      calls.create(INPUT);
    } catch (error) {
      createError = error;
    }
    expect(createError).toMatchObject(SHUTTING_DOWN);
    expect(store.list()).toHaveLength(2);

    // (b) approvePlan
    await expect(calls.approvePlan("waiting")).rejects.toMatchObject(SHUTTING_DOWN);
    expect(calls.get("waiting").status).toBe("awaiting_approval");

    // (c) a new mid-call approval is declined at once and not recorded
    await expect(session.requestApproval("예약금 1만 원을 결제할까요?")).resolves.toEqual({
      approved: false,
      reason: "canceled",
    });
    expect(calls.get("live").approvals).toHaveLength(0);
  });

  it("approvePlan checks shutting_down before state and limits", async () => {
    const provider = new FakeProvider();
    const { calls } = setup({
      provider,
      tasks: [makeTask({ id: "live" }), makeTask({ id: "waiting" })],
      service: { maxConcurrentCalls: 1 },
    });
    await startCall(calls, provider, "live");

    // Before shutdown the same calls fail with 409, 429 and 404.
    await expect(calls.approvePlan("live")).rejects.toMatchObject({ statusCode: 409 });
    await expect(calls.approvePlan("waiting")).rejects.toMatchObject({ statusCode: 429, code: "too_many_active_calls" });
    await expect(calls.approvePlan("missing")).rejects.toMatchObject({ statusCode: 404 });

    calls.beginShutdown();

    await expect(calls.approvePlan("live")).rejects.toMatchObject(SHUTTING_DOWN);
    await expect(calls.approvePlan("waiting")).rejects.toMatchObject(SHUTTING_DOWN);
    await expect(calls.approvePlan("missing")).rejects.toMatchObject(SHUTTING_DOWN);
  });
});

describe("CallService terminateActiveCalls (AC-003, AC-004)", () => {
  it("the termination step is bounded to its deadline", async () => {
    vi.useFakeTimers();
    const provider = new FakeProvider();
    provider.hangupImpl = () => new Promise<void>(() => {});
    const { calls, log } = setup({ provider, tasks: [makeTask({ id: "t-1" })] });
    await startCall(calls, provider, "t-1");
    calls.beginShutdown();

    let returned = false;
    void calls.terminateActiveCalls({ deadlineMs: 3000 }).then(() => {
      returned = true;
    });
    await vi.advanceTimersByTimeAsync(2999);
    expect(returned).toBe(false);
    expect(provider.hangups).toEqual(["t-1"]);

    await vi.advanceTimersByTimeAsync(1);
    expect(returned).toBe(true);
    expect(log.warns().filter((w) => JSON.stringify(w.obj).includes("t-1"))).toHaveLength(1);
  });

  it.each([
    { name: "hangup completes", hangup: () => Promise.resolve() },
    { name: "hangup hangs past the 3 s deadline", hangup: () => new Promise<void>(() => {}) },
  ])("a call ended by shutdown is closed as failed without a summary ($name)", async ({ hangup }) => {
    vi.useFakeTimers();
    const provider = new FakeProvider();
    provider.hangupImpl = hangup;
    const { calls, brain, events } = setup({ provider, tasks: [makeTask({ id: "t-1" })] });
    const session = await startCall(calls, provider, "t-1");
    session.appendTranscript("callee", "네, 가게입니다.");
    session.appendTranscript("agent", "영업시간 문의드립니다.");
    const decision = session.requestApproval("예약금 1만 원을 결제할까요?");
    expect(calls.get("t-1").approvals[0]?.status).toBe("pending");
    calls.beginShutdown();
    events.length = 0;

    const done = calls.terminateActiveCalls({ deadlineMs: 3000 });
    await vi.advanceTimersByTimeAsync(3000);
    await done;

    const task = calls.get("t-1");
    expect(task.status).toBe("failed");
    expect(task.error).toBe("서버가 종료되어 통화를 끊었습니다.");
    expect(task.transcript).toHaveLength(2);
    expect(task.approvals[0]?.status).toBe("expired");
    expect(task.outcome).toBeUndefined();
    expect(brain.summaries).toBe(0);
    expect(events.some((e) => e.type === "task.updated" && e.task.status === "failed")).toBe(true);
    await expect(decision).resolves.toMatchObject({ approved: false });

    // Nothing summarizes the call later either.
    await vi.advanceTimersByTimeAsync(60_000);
    expect(brain.summaries).toBe(0);
    expect(calls.get("t-1").status).toBe("failed");
  });
});

describe("CallService restart recovery (AC-007, AC-008)", () => {
  it.each([
    { name: "a: termination succeeds", terminate: () => Promise.resolve(), warns: 0, waitMs: 0 },
    { name: "b: termination is rejected", terminate: () => Promise.reject(new Error("KAT 500")), warns: 1, waitMs: 0 },
    { name: "c: termination never finishes", terminate: () => new Promise<void>(() => {}), warns: 1, waitMs: 10_000 },
  ])("recovery terminates a still-running provider call ($name)", async ({ terminate, warns, waitMs }) => {
    vi.useFakeTimers();
    const provider = new FakeCallIdProvider("kat");
    const { calls, store, log } = setup({
      provider,
      tasks: [makeTask({ id: "live", status: "in_progress", provider: "kat", providerCallId: "c-2" })],
    });
    const statusAtTerminate: string[] = [];
    provider.terminateImpl = (callId) => {
      statusAtTerminate.push(`${callId}:${store.get("live")!.status}`);
      return terminate();
    };

    let returned = false;
    const recovery = calls.recoverInterruptedTasks().then(() => {
      returned = true;
    });
    await vi.advanceTimersByTimeAsync(0);
    if (waitMs > 0) {
      await vi.advanceTimersByTimeAsync(waitMs - 1);
      expect(returned).toBe(false);
      await vi.advanceTimersByTimeAsync(1);
    }
    await recovery;

    expect(returned).toBe(true);
    expect(provider.terminated).toEqual(["c-2"]);
    expect(statusAtTerminate).toEqual(["c-2:in_progress"]);
    expect(calls.get("live").status).toBe("failed");
    expect(log.warns()).toHaveLength(warns);
  });

  it("recovery without a call id or with a different provider only marks the task failed", async () => {
    // (a) no providerCallId (saved before the field existed), (c) summarizing/planning, (d) awaiting_approval
    const kat = new FakeCallIdProvider("kat");
    const first = setup({
      provider: kat,
      tasks: [
        makeTask({ id: "no-id", status: "in_progress", provider: "kat" }),
        makeTask({ id: "summarizing", status: "summarizing", provider: "kat" }),
        makeTask({ id: "planning", status: "planning", provider: "kat" }),
        makeTask({ id: "waiting", status: "awaiting_approval", provider: "kat" }),
      ],
    });
    await first.calls.recoverInterruptedTasks();

    expect(kat.terminated).toEqual([]);
    expect(first.calls.get("no-id").status).toBe("failed");
    expect(first.calls.get("summarizing").status).toBe("failed");
    expect(first.calls.get("planning").status).toBe("failed");
    expect(first.calls.get("waiting").status).toBe("awaiting_approval");
    expect(first.log.warns()).toHaveLength(1);
    expect(first.log.warns()[0]!.obj).toMatchObject({ taskId: "no-id", reason: "no_provider_call_id" });

    // (b) the task was placed through KAT, but the server now runs the simulated provider
    const simulated = new FakeCallIdProvider("simulated");
    const second = setup({
      provider: simulated,
      tasks: [makeTask({ id: "other", status: "in_progress", provider: "kat", providerCallId: "c-3" })],
    });
    await second.calls.recoverInterruptedTasks();

    expect(simulated.terminated).toEqual([]);
    expect(second.calls.get("other").status).toBe("failed");
    expect(second.log.warns()).toHaveLength(1);
    expect(second.log.warns()[0]!.obj).toMatchObject({ taskId: "other", reason: "provider_mismatch" });
  });
});

describe("CallService with a hung KAT call creation (AC-011)", () => {
  it(
    "a hung provider start fails the task promptly and frees the slot",
    { timeout: 2000 },
    async () => {
      // KAT never answers; the request only ends when its abort signal fires.
      const fetchFn = ((_url: string | URL | Request, init: RequestInit = {}) =>
        new Promise<Response>((_, reject) => {
          init.signal?.addEventListener("abort", () => reject(new DOMException("aborted", "AbortError")), {
            once: true,
          });
        })) as typeof fetch;
      const kat = new KatCallProvider(
        {
          apiKey: "key",
          groupId: "g-1",
          fromNumber: "07012345678",
          webhookSecret: "secret",
          publicBaseUrl: "https://example.test",
          apiBaseUrl: "https://kat.test/v1",
          realtime: { apiKey: "sk", model: "m", voice: "v" },
          fetch: fetchFn,
          requestTimeoutMs: 50,
          maxCallDurationSec: 600,
        } as ConstructorParameters<typeof KatCallProvider>[0],
        { info: () => {}, warn: () => {} },
      );
      const { calls } = setup({
        provider: kat,
        tasks: [makeTask({ id: "A", provider: "kat" }), makeTask({ id: "B", provider: "kat" })],
        service: { maxConcurrentCalls: 1 },
      });

      const startedAt = Date.now();
      await calls.approvePlan("A");
      expect(Date.now() - startedAt).toBeLessThan(550);

      await vi.waitFor(() => expect(calls.get("A").status).toBe("failed"), { timeout: 500, interval: 5 });
      expect(Date.now() - startedAt).toBeLessThan(550);
      expect(calls.get("A").error).toContain("KAT Cloud가 응답하지 않아");

      await expect(calls.approvePlan("B")).resolves.toMatchObject({ id: "B" });
    },
  );
});

const INVALID_PHONE = { statusCode: 400, code: "invalid_phone", message: "전화번호 형식이 올바르지 않습니다." };
const BLOCKED_NUMBER = { statusCode: 400, code: "blocked_number", message: "긴급·특수번호에는 전화할 수 없습니다." };

/** Runs a synchronous call and returns what it threw (or undefined). */
function thrownBy(fn: () => unknown): unknown {
  try {
    fn();
  } catch (error) {
    return error;
  }
  return undefined;
}

describe("CallService number policy at creation (SPEC-POLICY-001 AC-001..AC-004)", () => {
  it("create normalizes the target number", () => {
    const { calls, store } = setup();
    const task = calls.create({ ...INPUT, phoneNumber: "010-1234-5678" });
    expect(task.phoneNumber).toBe("+821012345678");
    expect(store.get(task.id)?.phoneNumber).toBe("+821012345678");
  });

  it("create rejects an invalid number without side effects", async () => {
    const { calls, events, brain } = setup();
    const createPlan = vi.spyOn(brain, "createPlan");
    expect(thrownBy(() => calls.create({ ...INPUT, phoneNumber: "12" }))).toMatchObject(INVALID_PHONE);
    await new Promise((r) => setTimeout(r, 0));
    expect(calls.list()).toEqual([]);
    expect(events).toHaveLength(0);
    expect(createPlan).not.toHaveBeenCalled();
  });

  it.each(["119", "+82 112"])("create blocks emergency and special numbers: %s", async (phoneNumber) => {
    const { calls, events, brain } = setup();
    const createPlan = vi.spyOn(brain, "createPlan");
    expect(thrownBy(() => calls.create({ ...INPUT, phoneNumber }))).toMatchObject(BLOCKED_NUMBER);
    await new Promise((r) => setTimeout(r, 0));
    expect(calls.list()).toEqual([]);
    expect(events).toHaveLength(0);
    expect(createPlan).not.toHaveBeenCalled();
  });

  it.each([
    ["010 9999 8888", "+821099998888"],
    ["abc", undefined],
    ["", undefined],
    [undefined, undefined],
  ])("create normalizes or drops the callback number: %s", (callbackNumber, expected) => {
    const { calls, store } = setup();
    const input = callbackNumber === undefined ? { ...INPUT } : { ...INPUT, callbackNumber };
    const task = calls.create(input);
    expect(task.callbackNumber).toBe(expected);
    expect(store.get(task.id)?.callbackNumber).toBe(expected);
  });
});

describe("CallService number policy before dialing (SPEC-POLICY-001 AC-010)", () => {
  it("approvePlan re-checks the number right before dialing", async () => {
    const provider = new FakeProvider();
    const start = vi.spyOn(provider, "start");
    // Stored directly, as if loaded from the data file without going through create().
    const { calls } = setup({
      provider,
      tasks: [
        makeTask({ id: "blocked", phoneNumber: "+82119" }),
        makeTask({ id: "invalid", phoneNumber: "12" }),
        makeTask({ id: "normal", phoneNumber: "+821012345678" }),
      ],
    });

    await expect(calls.approvePlan("blocked")).rejects.toMatchObject(BLOCKED_NUMBER);
    await expect(calls.approvePlan("invalid")).rejects.toMatchObject(INVALID_PHONE);
    for (const id of ["blocked", "invalid"]) {
      expect(calls.get(id).status).toBe("awaiting_approval");
      expect(calls.get(id).startedAt).toBeUndefined();
    }
    expect(start).not.toHaveBeenCalled();

    await calls.approvePlan("normal");
    expect(calls.get("normal").status).toBe("dialing");
    expect(start).toHaveBeenCalledTimes(1);
  });

  it("approvePlan checks in the order shutting_down, state, number, limits", async () => {
    // (i) shutting down wins over a blocked number; a missing id is 503 too.
    const shutdown = setup({ tasks: [makeTask({ id: "blocked", phoneNumber: "+82119" })] });
    shutdown.calls.beginShutdown();
    await expect(shutdown.calls.approvePlan("blocked")).rejects.toMatchObject(SHUTTING_DOWN);
    await expect(shutdown.calls.approvePlan("missing")).rejects.toMatchObject(SHUTTING_DOWN);

    // (ii) state wins over a blocked number; (iii) a blocked number wins over a full call limit.
    const provider = new FakeProvider();
    const start = vi.spyOn(provider, "start");
    const { calls } = setup({
      provider,
      tasks: [
        makeTask({ id: "live", status: "in_progress", phoneNumber: "+82119" }),
        makeTask({ id: "blocked", phoneNumber: "+82119" }),
      ],
      service: { maxConcurrentCalls: 1 },
    });
    await expect(calls.approvePlan("missing")).rejects.toMatchObject({ statusCode: 404, code: "not_found" });
    await expect(calls.approvePlan("live")).rejects.toMatchObject({ statusCode: 409, code: "invalid_state" });
    await expect(calls.approvePlan("blocked")).rejects.toMatchObject(BLOCKED_NUMBER);
    expect(calls.get("blocked").status).toBe("awaiting_approval");
    expect(start).not.toHaveBeenCalled();
  });
});
