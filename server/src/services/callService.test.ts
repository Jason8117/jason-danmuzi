import { afterEach, describe, expect, it, vi } from "vitest";
import type { CallBrain } from "../brain/types.js";
import type { CallTask, TaskStatus } from "../domain/types.js";
import { EventBus, type ServerEvent } from "../events/eventBus.js";
import type { Logger } from "../logger.js";
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
