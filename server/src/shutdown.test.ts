import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import type { Logger } from "./logger.js";
import { createShutdownHandler } from "./shutdown.js";
import { FINAL_STORE_FLUSH_FAILED, type FinalFlushResult } from "./store/taskStore.js";

const never = <T>() => new Promise<T>(() => {});

interface HarnessOptions {
  terminate?: () => Promise<void>;
  close?: () => Promise<unknown>;
  finalFlush?: () => Promise<FinalFlushResult>;
}

/** Fake calls/app/store/exit that record the order in which the shutdown module drives them. */
function harness(options: HarnessOptions = {}) {
  const order: string[] = [];
  const at: Record<string, number> = {};
  const hangups: string[] = [];
  const exits: number[] = [];
  const logs: { level: string; obj: Record<string, unknown>; msg: string }[] = [];
  const mark = (name: string) => {
    order.push(name);
    at[name] = Date.now();
  };
  const logger: Logger = {
    info: (obj, msg) => logs.push({ level: "info", obj: obj as Record<string, unknown>, msg }),
    warn: (obj, msg) => logs.push({ level: "warn", obj: obj as Record<string, unknown>, msg }),
    error: (obj, msg) => logs.push({ level: "error", obj: obj as Record<string, unknown>, msg }),
  };
  const onSignal = createShutdownHandler({
    calls: {
      beginShutdown: () => mark("beginShutdown"),
      terminateActiveCalls: () => {
        mark("terminateActiveCalls");
        // Two active calls: the provider is asked to hang both up right away.
        hangups.push("call-a", "call-b");
        return options.terminate ? options.terminate() : Promise.resolve();
      },
    },
    app: {
      close: () => {
        mark("app.close");
        return options.close ? options.close() : Promise.resolve();
      },
    },
    store: {
      finalFlush: () => {
        mark("finalFlush");
        return options.finalFlush ? options.finalFlush() : Promise.resolve({ ok: true });
      },
    },
    logger,
    exit: (code) => {
      mark(`exit(${code})`);
      exits.push(code);
    },
    dataFile: "/tmp/tasks.json",
  });
  const errors = () => logs.filter((l) => l.level === "error" && l.msg === FINAL_STORE_FLUSH_FAILED);
  return { onSignal, order, at, hangups, exits, logs, errors };
}

let start = 0;

beforeEach(() => {
  vi.useFakeTimers();
  start = Date.now();
});

afterEach(() => {
  vi.useRealTimers();
});

describe("shutdown (AC-002)", () => {
  it("terminates calls before app.close and moves on when app.close hangs", async () => {
    const h = harness({ close: never });

    h.onSignal("SIGTERM");
    await vi.advanceTimersByTimeAsync(0);
    expect(h.hangups).toHaveLength(2);
    expect(h.order).toEqual(["beginShutdown", "terminateActiveCalls", "app.close"]);

    await vi.advanceTimersByTimeAsync(999);
    expect(h.order).not.toContain("finalFlush");

    await vi.advanceTimersByTimeAsync(1);
    expect(h.order).toEqual(["beginShutdown", "terminateActiveCalls", "app.close", "finalFlush", "exit(0)"]);
    expect(h.at.finalFlush! - h.at["app.close"]!).toBe(1000);
    expect(h.at.finalFlush! - start).toBe(1000);

    await vi.advanceTimersByTimeAsync(3000);
    expect(h.logs.filter((l) => l.level === "warn" && l.obj.step === "app_close")).toHaveLength(1);
    expect(h.exits).toEqual([0]);
  });
});

describe("shutdown (AC-005)", () => {
  it("runs the steps in order", async () => {
    const h = harness();

    h.onSignal("SIGINT");
    await vi.advanceTimersByTimeAsync(0);

    expect(h.order).toEqual(["beginShutdown", "terminateActiveCalls", "app.close", "finalFlush", "exit(0)"]);
  });

  it("finishes within 9 s + 500 ms when every step hangs", async () => {
    const h = harness({
      terminate: never,
      close: never,
      // Mimics the store's own 5 s deadline: reports a timeout after 5,000 ms.
      finalFlush: () => new Promise((resolve) => setTimeout(() => resolve({ ok: false, reason: "timeout" }), 5000)),
    });

    h.onSignal("SIGTERM");
    await vi.advanceTimersByTimeAsync(8999);
    expect(h.exits).toEqual([]);

    await vi.advanceTimersByTimeAsync(1);
    expect(h.exits).toEqual([1]);
    expect(h.at["exit(1)"]! - start).toBe(9000);
    expect(h.at["exit(1)"]! - start).toBeLessThanOrEqual(9500);

    await vi.advanceTimersByTimeAsync(10_000);
    expect(h.exits).toEqual([1]);
    expect(h.errors()).toHaveLength(1);
  });

  it.each([
    { name: "failure", result: { ok: false, reason: "error", error: Object.assign(new Error("EROFS"), { code: "EROFS" }) }, code: 1, errorLogs: 1 },
    { name: "success", result: { ok: true }, code: 0, errorLogs: 0 },
  ] as const)("maps the final flush result to the exit code ($name)", async ({ result, code, errorLogs }) => {
    const h = harness({ finalFlush: async () => result as FinalFlushResult });

    h.onSignal("SIGTERM");
    await vi.advanceTimersByTimeAsync(0);

    expect(h.exits).toEqual([code]);
    expect(h.errors()).toHaveLength(errorLogs);
  });

  it("a second signal exits immediately", async () => {
    const h = harness({ terminate: never });

    h.onSignal("SIGTERM");
    await vi.advanceTimersByTimeAsync(1000);
    expect(h.exits).toEqual([]);

    h.onSignal("SIGINT");
    expect(h.exits).toEqual([1]);
    expect(h.at["exit(1)"]! - start).toBe(1000);

    await vi.advanceTimersByTimeAsync(20_000);
    expect(h.exits).toEqual([1]);
    expect(h.order).not.toContain("finalFlush");
  });

  it("treats a hanging final flush as a failure and exits 1 within the budget", async () => {
    const h = harness({ finalFlush: never });

    h.onSignal("SIGTERM");
    await vi.advanceTimersByTimeAsync(4999);
    expect(h.exits).toEqual([]);

    await vi.advanceTimersByTimeAsync(1);
    expect(h.errors()).toHaveLength(1);
    expect(h.exits).toEqual([1]);
    expect(h.at["exit(1)"]! - start).toBe(5000);

    await vi.advanceTimersByTimeAsync(10_000);
    expect(h.errors()).toHaveLength(1);
    expect(h.exits).toEqual([1]);
  });

  it("treats a hanging final flush as a failure when every step hangs (9 s)", async () => {
    const h = harness({ terminate: never, close: never, finalFlush: never });

    h.onSignal("SIGTERM");
    await vi.advanceTimersByTimeAsync(8999);
    expect(h.exits).toEqual([]);

    await vi.advanceTimersByTimeAsync(1);
    expect(h.errors()).toHaveLength(1);
    expect(h.exits).toEqual([1]);
    expect(h.at["exit(1)"]! - start).toBe(9000);
  });
});
