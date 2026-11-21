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
