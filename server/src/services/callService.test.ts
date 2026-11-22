import { afterEach, describe, expect, it, vi } from "vitest";
import { buildAgentInstructions } from "../brain/prompts.js";
import { openingLine } from "../brain/prompts.js";
import { HeuristicBrain } from "../brain/heuristicBrain.js";
import { OpenAiBrain } from "../brain/openaiBrain.js";
import type { CallBrain } from "../brain/types.js";
import type { CallTask, ProviderId, TaskStatus } from "../domain/types.js";
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

  constructor(readonly name: ProviderId = "simulated") {}

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

describe("CallService session instructions (SPEC-ARCH-001 AC-007)", () => {
  it("session exposes the agent instructions for its task", async () => {
    const provider = new FakeProvider();
    const { calls } = setup({
      provider,
      tasks: [makeTask({ context: "2명, 창가 자리 선호", callbackNumber: "+821099998888" })],
    });

    await calls.approvePlan("t-1");
    const session = provider.sessions.get("t-1")!;

    expect(session.agentInstructions()).toBe(buildAgentInstructions(calls.get("t-1")));
    expect(session.agentInstructions()).toContain("2명, 창가 자리 선호");
  });
});

describe("CallService provider ids (SPEC-ARCH-001 AC-013)", () => {
  it("accepts any provider id", () => {
    const { calls } = setup({
      provider: new FakeProvider("fake"),
      tasks: [makeTask({ id: "old-sim", provider: "simulated" }), makeTask({ id: "old-kat", provider: "kat" })],
    });

    expect(calls.create(INPUT).provider).toBe("fake");
    expect(calls.get("old-sim").provider).toBe("simulated");
    expect(calls.get("old-kat").provider).toBe("kat");
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

  // Owner decision: a callback number the number policy blocks is dropped, never stored and never an error.
  it.each(["112-0000-0000", "119", "+82 112", "119 1234 5678"])(
    "create drops a blocked callback number and still creates the task: %s",
    (callbackNumber) => {
      const { calls, store } = setup();
      const task = calls.create({ ...INPUT, callbackNumber });
      expect(task.callbackNumber).toBeUndefined();
      expect(store.get(task.id)?.callbackNumber).toBeUndefined();
      expect(calls.list()).toHaveLength(1);
    },
  );
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

describe("CallService number policy on the dialed form (SPEC-POLICY-001 audit F1)", () => {
  it.each(["119 1234 5678", "+119 12345", "112-0000-0000"])(
    "create blocks a number whose dialed form starts with a blocked code: %s",
    async (phoneNumber) => {
      const { calls, events, brain } = setup();
      const createPlan = vi.spyOn(brain, "createPlan");
      expect(thrownBy(() => calls.create({ ...INPUT, phoneNumber }))).toMatchObject(BLOCKED_NUMBER);
      await new Promise((r) => setTimeout(r, 0));
      expect(calls.list()).toEqual([]);
      expect(events).toHaveLength(0);
      expect(createPlan).not.toHaveBeenCalled();
    },
  );

  it.each(["+11912345678", "+11912345", "+11200000000"])(
    "approvePlan blocks a stored number whose dialed form starts with a blocked code: %s",
    async (phoneNumber) => {
      const provider = new FakeProvider();
      const start = vi.spyOn(provider, "start");
      const { calls } = setup({ provider, tasks: [makeTask({ id: "stored", phoneNumber })] });
      await expect(calls.approvePlan("stored")).rejects.toMatchObject(BLOCKED_NUMBER);
      expect(calls.get("stored").status).toBe("awaiting_approval");
      expect(calls.get("stored").startedAt).toBeUndefined();
      expect(start).not.toHaveBeenCalled();
    },
  );
});

/**
 * Starts a live call for `task` and plays the provider side of a mid-call approval: it asks,
 * records the decision it gets back, then speaks once (SPEC-APPROVAL-001 AC-004..AC-006).
 */
async function askApproval(task: CallTask = makeTask()) {
  const provider = new FakeProvider();
  const ctx = setup({ provider, tasks: [task] });
  const session = await startCall(ctx.calls, provider, task.id);
  const settled = session.requestApproval("예약금 1만 원을 결제할까요?").then((decision) => {
    session.appendTranscript("agent", "확인했습니다");
    return decision;
  });
  const approvalId = ctx.calls.get(task.id).approvals[0]!.id;
  return { ...ctx, session, settled, approvalId };
}

const systemLines = (task: CallTask) => task.transcript.filter((t) => t.speaker === "system").map((t) => t.text);

describe("CallService approval comments (SPEC-APPROVAL-001 AC-004, AC-005)", () => {
  const CARD_COMMENT = "카드 1234 5678 9012 3456 말고 계좌이체";

  it.each([
    [true, "user_approved"],
    [false, "user_rejected"],
  ] as const)("resolves the approval with the sanitized comment (approve: %s)", async (approve, reason) => {
    const { calls, settled, approvalId } = await askApproval();

    calls.respondToApproval("t-1", approvalId, { approve, comment: CARD_COMMENT });

    expect(await settled).toEqual({ approved: approve, comment: "카드 [민감정보 삭제] 말고 계좌이체", reason });
    const approval = calls.get("t-1").approvals[0]!;
    expect(approval.status).toBe(approve ? "approved" : "rejected");
    expect(approval.userComment).toBe("카드 [민감정보 삭제] 말고 계좌이체");
    expect(JSON.stringify(calls.get("t-1"))).not.toContain("1234 5678 9012 3456");
  });

  it("never logs approval comments", async () => {
    const { calls, session, settled, approvalId, log } = await askApproval();

    calls.respondToApproval("t-1", approvalId, { approve: true, comment: "비밀안내문구-XYZ 1234 5678 9012 3456" });
    await settled;
    session.end();
    await vi.waitFor(() => expect(calls.get("t-1").status).toBe("completed"));

    const logged = JSON.stringify(log.entries);
    expect(logged).not.toContain("비밀안내문구-XYZ");
    expect(logged).not.toContain("1234 5678 9012 3456");
    expect(logged).not.toContain("[민감정보 삭제]");
  });
});

describe("CallService guidance line (SPEC-APPROVAL-001 AC-006)", () => {
  it("appends one guidance line per commented decision, before the provider's next line", async () => {
    const { calls, settled, approvalId } = await askApproval();

    calls.respondToApproval("t-1", approvalId, { approve: true, comment: "1만 원까지만" });
    await settled;

    const texts = calls.get("t-1").transcript.map((t) => t.text);
    expect(systemLines(calls.get("t-1"))).toEqual(["사용자 안내: 1만 원까지만"]);
    expect(texts.indexOf("사용자 안내: 1만 원까지만")).toBeLessThan(texts.indexOf("확인했습니다"));
  });

  it("uses the English prefix for an English task", async () => {
    const { calls, settled, approvalId } = await askApproval(makeTask({ language: "en" }));

    calls.respondToApproval("t-1", approvalId, { approve: true, comment: "up to 10,000 won" });
    await settled;

    expect(systemLines(calls.get("t-1"))).toEqual(["User guidance: up to 10,000 won"]);
  });

  it("writes no guidance line when the approval expires", async () => {
    vi.useFakeTimers();
    const { calls, settled } = await askApproval();

    await vi.advanceTimersByTimeAsync(60_000);
    const decision = await settled;

    expect(decision.approved).toBe(false);
    expect(decision.reason).toBe("expired");
    expect(decision.comment).toBeUndefined();
    const approval = calls.get("t-1").approvals[0]!;
    expect(approval.status).toBe("expired");
    expect(approval.userComment).toBeUndefined();
    expect(systemLines(calls.get("t-1"))).toEqual([]);
  });

  it("keeps the stored comment and transcript when a closed approval is answered again", async () => {
    const { calls, settled, approvalId } = await askApproval();
    calls.respondToApproval("t-1", approvalId, { approve: true, comment: "1만 원까지만" });
    await settled;

    expect(thrownBy(() => calls.respondToApproval("t-1", approvalId, { approve: false, comment: "취소" }))).toMatchObject({
      statusCode: 409,
      code: "approval_closed",
    });
    expect(calls.get("t-1").approvals[0]!.userComment).toBe("1만 원까지만");
    expect(systemLines(calls.get("t-1"))).toEqual(["사용자 안내: 1만 원까지만"]);
  });

  it.each([undefined, "\u0007  "])("writes no guidance line when no comment is left (comment: %j)", async (comment) => {
    const { calls, settled, approvalId } = await askApproval();

    calls.respondToApproval("t-1", approvalId, { approve: true, comment });

    expect(await settled).toEqual({ approved: true, comment: undefined, reason: "user_approved" });
    expect(calls.get("t-1").approvals[0]!.userComment).toBeUndefined();
    expect(systemLines(calls.get("t-1"))).toEqual([]);
  });
});

// ---------------------------------------------------------------------------------------------
// SPEC-INTAKE-001
// ---------------------------------------------------------------------------------------------

function planBrain(createPlan: CallBrain["createPlan"]): CallBrain {
  return {
    name: "heuristic",
    createPlan,
    async summarize() {
      return { result: "success", summary: "요약", keyFacts: [], followUps: [] };
    },
  };
}

/** Like setup(), but the brain, store and provider can be swapped, and every provider start is recorded. */
function intakeSetup(
  options: {
    brain?: CallBrain;
    store?: InMemoryTaskStore;
    provider?: FakeProvider;
    tasks?: CallTask[];
    service?: Partial<CallServiceOptions>;
  } = {},
) {
  const store = options.store ?? new InMemoryTaskStore();
  for (const task of options.tasks ?? []) store.save(task);
  const bus = new EventBus();
  const events: ServerEvent[] = [];
  bus.subscribe((event) => events.push(structuredClone(event)));
  const provider = options.provider ?? new FakeProvider();
  const starts: string[] = [];
  provider.startImpl = async (session) => {
    starts.push(session.taskId);
  };
  const log = recordingLogger();
  const calls = new CallService(store, bus, options.brain ?? recordingBrain(), provider, {
    maxConcurrentCalls: 5,
    maxCallsPerDay: 50,
    approvalTimeoutMs: 60_000,
    maxCallDurationMs: 600_000,
    logger: log.logger,
    ...options.service,
  });
  return { store, events, provider, starts, calls, log };
}

/** A brain whose plan only resolves once release() is called. */
function gatedBrain() {
  let release!: () => void;
  const gate = new Promise<void>((resolve) => (release = resolve));
  const brain = planBrain(async () => {
    await gate;
    return PLAN;
  });
  return { brain, release };
}

/** Throws from list() once armed: assertWithinLimits calls list(), so the auto start hits it. */
class FailingListStore extends InMemoryTaskStore {
  failList = false;
  override list(): CallTask[] {
    if (this.failList) throw new Error("boom");
    return super.list();
  }
}

const LIVE = ["dialing", "ringing", "in_progress"];

describe("CallService auto start (SPEC-INTAKE-001 AC-014)", () => {
  it("starts the call once planning finishes when autoStart is set", async () => {
    const { calls, starts } = intakeSetup();

    const auto = calls.create(INPUT, { autoStart: true });
    const manual = calls.create({ ...INPUT, goal: "가격 문의" });

    await vi.waitFor(() => expect(starts).toContain(auto.id));
    await vi.waitFor(() => expect(calls.get(manual.id).status).toBe("awaiting_approval"));
    expect(LIVE).toContain(calls.get(auto.id).status);
    expect(starts.filter((id) => id === auto.id)).toHaveLength(1);
    expect(calls.get(auto.id).startedAt).toBeDefined();
    expect(starts).not.toContain(manual.id);
  });

  it("auto-started calls open with the template AI disclosure", async () => {
    const brain = planBrain(async () => ({ ...PLAN, openingLine: "안녕하세요, 김민수입니다." }));
    const { calls, starts } = intakeSetup({ brain });
    const input = { ...INPUT, requesterName: "김민수" };

    const auto = calls.create(input, { autoStart: true });
    await vi.waitFor(() => expect(starts).toContain(auto.id));
    expect(calls.get(auto.id).plan?.openingLine).toBe(openingLine(input));
    expect(calls.get(auto.id).plan?.openingLine).toContain("AI 비서");

    const manual = calls.create(input);
    await vi.waitFor(() => expect(calls.get(manual.id).status).toBe("awaiting_approval"));
    await calls.approvePlan(manual.id);
    expect(calls.get(manual.id).plan?.openingLine).toBe("안녕하세요, 김민수입니다.");
  });
});

describe("CallService blocked auto start (SPEC-INTAKE-001 AC-015)", () => {
  it("records why an auto start was blocked: concurrent limit, cleared by a manual approval", async () => {
    const { calls, provider, starts, events } = intakeSetup({
      tasks: [makeTask({ id: "t-1" })],
      service: { maxConcurrentCalls: 1 },
    });
    const live = await startCall(calls, provider, "t-1");

    const auto = calls.create(INPUT, { autoStart: true });
    await vi.waitFor(() => expect(calls.get(auto.id).autoStartBlocked).toBeDefined());

    expect(calls.get(auto.id).status).toBe("awaiting_approval");
    expect(calls.get(auto.id).autoStartBlocked).toEqual({
      code: "too_many_active_calls",
      message: "Too many calls are in progress",
    });
    expect(starts).not.toContain(auto.id);
    expect(
      events.some(
        (e) => e.type === "task.updated" && e.task.id === auto.id && e.task.autoStartBlocked?.code === "too_many_active_calls",
      ),
    ).toBe(true);

    live.end();
    await vi.waitFor(() => expect(LIVE).not.toContain(calls.get("t-1").status));
    await calls.approvePlan(auto.id);
    expect(calls.get(auto.id).status).toBe("dialing");
    expect(Object.keys(calls.get(auto.id))).not.toContain("autoStartBlocked");
  });

  it("records daily_limit when the day's calls are used up", async () => {
    const { calls, starts } = intakeSetup({
      tasks: [makeTask({ id: "done", status: "completed", startedAt: new Date().toISOString() })],
      service: { maxCallsPerDay: 1 },
    });

    const auto = calls.create(INPUT, { autoStart: true });
    await vi.waitFor(() => expect(calls.get(auto.id).autoStartBlocked?.code).toBe("daily_limit"));
    expect(calls.get(auto.id).status).toBe("awaiting_approval");
    expect(starts).toEqual([]);
  });

  it("records shutting_down when shutdown began during planning", async () => {
    const { brain, release } = gatedBrain();
    const { calls, starts } = intakeSetup({ brain });

    const auto = calls.create(INPUT, { autoStart: true });
    calls.beginShutdown();
    release();

    await vi.waitFor(() => expect(calls.get(auto.id).autoStartBlocked?.code).toBe("shutting_down"));
    expect(calls.get(auto.id).status).toBe("awaiting_approval");
    expect(starts).toEqual([]);
  });

  it("records auto_start_failed for an unexpected error without failing the task", async () => {
    const store = new FailingListStore();
    const brain = planBrain(async () => {
      store.failList = true;
      return PLAN;
    });
    const rejections: unknown[] = [];
    const onRejection = (reason: unknown) => rejections.push(reason);
    process.on("unhandledRejection", onRejection);
    try {
      const { calls, starts, log } = intakeSetup({ brain, store });

      const auto = calls.create(INPUT, { autoStart: true });
      await vi.waitFor(() => expect(calls.get(auto.id).autoStartBlocked).toBeDefined());

      expect(calls.get(auto.id).autoStartBlocked).toEqual({
        code: "auto_start_failed",
        message: "자동으로 통화를 시작하지 못했어요.",
      });
      expect(calls.get(auto.id).status).toBe("awaiting_approval");
      expect(starts).toEqual([]);
      await new Promise((resolve) => setTimeout(resolve, 20));
      expect(rejections).toEqual([]);
      expect(JSON.stringify(log.entries)).not.toContain("InvalidTransition");
    } finally {
      process.off("unhandledRejection", onRejection);
    }
  });
});

describe("CallService auto start scope (SPEC-INTAKE-001 AC-016)", () => {
  it("never auto-starts outside the planning completion", async () => {
    // (1) canceled while planning
    const gated = gatedBrain();
    const slow = intakeSetup({ brain: gated.brain });
    const canceled = slow.calls.create(INPUT, { autoStart: true });
    await slow.calls.cancel(canceled.id);
    gated.release();
    await new Promise((resolve) => setTimeout(resolve, 10));
    expect(slow.calls.get(canceled.id).status).toBe("canceled");
    expect(slow.starts).toEqual([]);

    // (2) planning fails
    const failing = intakeSetup({
      brain: planBrain(async () => {
        throw new Error("plan failed");
      }),
    });
    const failed = failing.calls.create(INPUT, { autoStart: true });
    await vi.waitFor(() => expect(failing.calls.get(failed.id).status).toBe("failed"));
    expect(failing.starts).toEqual([]);
    expect(failing.calls.get(failed.id).autoStartBlocked).toBeUndefined();

    // (3) a stored auto-start task found at startup
    const provider = new FakeCallIdProvider();
    const restarted = intakeSetup({ provider, tasks: [makeTask({ id: "loaded", autoStart: true })] });
    await restarted.calls.recoverInterruptedTasks();
    expect(restarted.calls.get("loaded").status).toBe("awaiting_approval");
    expect(restarted.starts).toEqual([]);
    expect(provider.terminated).toEqual([]);
  });
});

/** A finished call to `targetName` (design.md §3.4 history vectors). */
function historyTask(id: string, targetName: string, phoneNumber: string, day: string, connected = true): CallTask {
  const at = `2026-11-${day}T10:00:00.000Z`;
  return makeTask({
    id,
    targetName,
    phoneNumber,
    status: "completed",
    createdAt: at,
    updatedAt: at,
    startedAt: at,
    ...(connected && { connectedAt: at }),
  });
}

const HISTORY_1 = () => historyTask("h1", "라 파스타", "+8221234567", "01");
const HISTORY_2 = () => historyTask("h2", "라파스타", "+8221110000", "10");
const HISTORY_3 = () => historyTask("h3", "미용실 A", "+82311234567", "15", false);

/** An OpenAiBrain whose fake fetch records each request body and answers with `content`. */
function llmBrain(content: object, log = recordingLogger()) {
  const bodies: string[] = [];
  vi.stubGlobal(
    "fetch",
    vi.fn(async (_url: unknown, init?: RequestInit) => {
      bodies.push(String(init?.body));
      return new Response(JSON.stringify({ choices: [{ message: { content: JSON.stringify(content) } }] }), { status: 200 });
    }),
  );
  return { brain: new OpenAiBrain("sk-test", "gpt-test", log.logger), bodies };
}

describe("CallService intake (SPEC-INTAKE-001)", () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  // AC-003 / REQ-003
  it("intake has no side effects and logs no request text", async () => {
    const log = recordingLogger();
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => new Response("upstream", { status: 500 })),
    );
    const brain = new OpenAiBrain("sk-test", "gpt-test", log.logger);
    const store = new InMemoryTaskStore();
    store.save(makeTask({ id: "kept", version: 3 }));
    const bus = new EventBus();
    const events: ServerEvent[] = [];
    bus.subscribe((event) => events.push(event));
    const provider = new FakeProvider();
    const calls = new CallService(store, bus, brain, provider, {
      maxConcurrentCalls: 5,
      maxCallsPerDay: 50,
      approvalTimeoutMs: 60_000,
      maxCallDurationMs: 600_000,
      logger: log.logger,
    });

    await calls.draftIntake("라 파스타에 전화해서 010-1234-5678 예약 비밀문구-Q", "ko");

    expect(store.list().map((t) => [t.id, t.version])).toEqual([["kept", 3]]);
    expect(events).toEqual([]);
    expect(provider.sessions.size).toBe(0);
    expect(provider.hangups).toEqual([]);
    expect(log.warns()).toHaveLength(1);
    const logged = JSON.stringify(log.entries);
    for (const secret of ["010-1234-5678", "+821012345678", "비밀문구-Q", "라 파스타"]) expect(logged).not.toContain(secret);
  });

  // AC-005 / REQ-005
  it.each(["라 파스타에 전화해 119로", "119에 전화해 줘"])("never proposes a blocked number, even from history: %s", async (text) => {
    const { calls } = intakeSetup({ brain: new HeuristicBrain(), tasks: [HISTORY_1(), HISTORY_2()] });

    const result = await calls.draftIntake(text, "ko");

    expect(result.draft.phoneNumber).toBeNull();
    expect(result.numberIssue).toBe("blocked");
    expect(result.phoneSource).toBeNull();
  });

  // AC-006 / REQ-006 — design.md §3.4 history table
  it.each([
    { text: "라 파스타에 전화해서 7시 예약", targetName: "라 파스타", phoneNumber: "+8221110000", phoneSource: "history", numberIssue: null },
    { text: "라파스타 금요일 7시 2명 예약해줘", targetName: "라파스타", phoneNumber: "+8221110000", phoneSource: "history", numberIssue: null },
    { text: "미용실 A에 예약", targetName: null, phoneNumber: null, phoneSource: null, numberIssue: null },
    // design.md §3.4 lists "+82299999999" here, but that is the E.164 form of 02-9999-9999. REQ-004 judges the text's
    // number with checkTargetNumber, which gives "+8229999999" for 02-999-9999; producing the table value would mean
    // inventing a digit (REQ-007). The row's point, the text number winning over history, is unchanged.
    { text: "라 파스타에 전화해서 02-999-9999로", targetName: "라 파스타", phoneNumber: "+8229999999", phoneSource: "text", numberIssue: null },
    { text: "라 파스타에 전화해 119로", targetName: "라 파스타", phoneNumber: null, phoneSource: null, numberIssue: "blocked" },
  ])("finds the number of a counterparty who answered before: $text", async ({ text, ...expected }) => {
    const { calls } = intakeSetup({ brain: new HeuristicBrain(), tasks: [HISTORY_1(), HISTORY_2(), HISTORY_3()] });

    const result = await calls.draftIntake(text, "ko");

    expect({
      targetName: result.draft.targetName,
      phoneNumber: result.draft.phoneNumber,
      phoneSource: result.phoneSource,
      numberIssue: result.numberIssue,
    }).toEqual(expected);
  });

  it("finds the number of a counterparty who answered before: a stored number now blocked is not replaced", async () => {
    const blocked = { ...HISTORY_2(), phoneNumber: "119" };
    const { calls } = intakeSetup({ brain: new HeuristicBrain(), tasks: [HISTORY_1(), blocked] });

    const result = await calls.draftIntake("라 파스타에 전화해서 7시 예약", "ko");

    expect(result.draft.phoneNumber).toBeNull();
    expect(result.phoneSource).toBeNull();
  });

  // AC-007 (a) / REQ-007
  it("masks numbers before calling the LLM", async () => {
    const { brain, bodies } = llmBrain({ targetName: "라 파스타", goal: "010-9999-8888로 예약", conditions: [], context: "번호 02-555-5555" });
    const { calls } = intakeSetup({ brain });

    await calls.draftIntake("라 파스타에 010-1234-5678로 전화해서 예약", "ko");

    expect(bodies).toHaveLength(1);
    expect(bodies[0]).not.toContain("010-1234-5678");
    expect(bodies[0]).not.toContain("01012345678");
    expect(bodies[0]).toContain("[전화번호]");
  });

  // AC-007 (b)-(e) / REQ-007
  it("uses only numbers from the text or history", async () => {
    const invented = ["010-9999-8888", "01099998888", "+821099998888", "02-555-5555", "+82255555555"];
    const first = llmBrain({ targetName: "라 파스타", goal: "010-9999-8888로 예약", conditions: [], context: "번호 02-555-5555" });
    const withNumber = await intakeSetup({ brain: first.brain }).calls.draftIntake("라 파스타에 010-1234-5678로 전화해서 예약", "ko");

    // (b) the number from the text, (c) invented numbers removed and spaces tidied
    expect(withNumber.draft.phoneNumber).toBe("+821012345678");
    expect(withNumber.phoneSource).toBe("text");
    for (const number of invented) expect(JSON.stringify(withNumber)).not.toContain(number);
    expect(withNumber.draft.goal).toBe("로 예약");
    expect(withNumber.draft.context).toBe("번호");

    // (d) same LLM answer, no number in the text
    const noNumber = await intakeSetup({ brain: first.brain }).calls.draftIntake("라 파스타에 전화해서 예약", "ko");
    expect(noNumber.draft.phoneNumber).toBeNull();
    expect(noNumber.missing).toContain("phoneNumber");
    for (const number of invented) expect(JSON.stringify(noNumber)).not.toContain(number);

    // (e) other number shapes in every string field; the name check runs after the removal
    vi.unstubAllGlobals();
    const second = llmBrain({
      targetName: "1588-9999 고객센터",
      goal: "+1 202 555 0199로 문의",
      conditions: ["02 777 7777도 가능"],
      context: null,
    });
    const shapes = await intakeSetup({ brain: second.brain }).calls.draftIntake("고객센터에 전화해서 문의", "ko");
    for (const number of ["1588-9999", "+1 202 555 0199", "02 777 7777"]) expect(JSON.stringify(shapes)).not.toContain(number);
    expect(shapes.draft.targetName).toBe("고객센터");
    expect(shapes.draft.goal).toBe("로 문의");
    expect(shapes.draft.conditions).toEqual(["도 가능"]);
  });

  // AC-008 / REQ-008 (service post-processing)
  it.each([
    {
      name: "(1) full draft",
      content: { targetName: "라 파스타", goal: "금요일 7시 2명 예약", conditions: ["8시도 괜찮음"], context: null },
      text: "라 파스타에 전화해서 금요일 7시 2명 예약해줘. 안 되면 8시도 괜찮아",
      expected: { targetName: "라 파스타", goal: "금요일 7시 2명 예약", conditions: ["8시도 괜찮음"] },
    },
    {
      name: "(2) a name the request never mentioned",
      content: { targetName: "강남 맛집", goal: "예약", conditions: [], context: null },
      text: "라 파스타에 전화해서 금요일 7시 2명 예약해줘. 안 되면 8시도 괜찮아",
      expected: { targetName: null },
    },
    {
      name: "(3) placeholder removed",
      content: { targetName: null, goal: "[전화번호]로 예약 문의", conditions: null },
      text: "02-123-4567로 예약 문의",
      expected: { goal: "로 예약 문의", conditions: [], phoneNumber: "+8221234567" },
    },
  ])("post-processes LLM intake content in the service $name", async ({ content, text, expected }) => {
    const { brain } = llmBrain(content);
    const { calls } = intakeSetup({ brain });

    const result = await calls.draftIntake(text, "ko");

    expect(result.source).toBe("llm");
    expect(result.draft).toMatchObject(expected);
    if (expected.targetName === null) expect(result.missing).toContain("targetName");
  });

  // AC-011 / REQ-011
  it("matches the longest known counterparty name", async () => {
    const tasks = [HISTORY_1(), HISTORY_2(), historyTask("h4", "파스타", "+82311119999", "12"), historyTask("h5", "A", "+82311118888", "13")];
    const { calls } = intakeSetup({ brain: new HeuristicBrain(), tasks });

    expect((await calls.draftIntake("라파스타 금요일 예약", "ko")).draft.targetName).toBe("라파스타");
    expect((await calls.draftIntake("파스타 집 영업시간", "ko")).draft.targetName).toBe("파스타");
    expect((await calls.draftIntake("A 매장 예약", "ko")).draft.targetName).toBeNull();
  });

  // AC-012 / REQ-012
  it("lists missing fields in a fixed order", async () => {
    const { calls } = intakeSetup({ brain: new HeuristicBrain() });

    const numberOnly = await calls.draftIntake("010-1234-5678", "ko");
    expect(numberOnly.draft.goal).toBe("");
    expect(numberOnly.missing).toEqual(["targetName", "goal"]);
    expect(numberOnly.draft.phoneNumber).toBe("+821012345678");

    const plain = await calls.draftIntake("금요일 7시 예약", "ko");
    expect(plain.missing).toEqual(["targetName", "phoneNumber"]);

    const mom = await calls.draftIntake("엄마한테 전화해 줘", "ko");
    expect(mom.missing).toEqual(["phoneNumber"]);

    for (const result of [numberOnly, plain, mom]) expect(result.draft.language).toBe("ko");

    const english = await calls.draftIntake("금요일 7시 예약", "en");
    expect(english.draft.language).toBe("en");
    expect({ ...english, draft: { ...english.draft, language: "ko" } }).toEqual(plain);
  });
});
