import * as realFs from "node:fs/promises";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import type { CallTask } from "../domain/types.js";
import { JsonFileTaskStore, STORE_WRITE_FAILED, STORE_WRITE_RECOVERED } from "./taskStore.js";

const RETRY = { retryInitialMs: 1000, retryMultiplier: 2, retryMaxMs: 30_000 };

const PHONE = "010-1234-5678";

function task(id: string, createdAt = "2026-11-21T00:00:00.000Z"): CallTask {
  return {
    id,
    version: 1,
    status: "planning",
    targetName: "Target",
    phoneNumber: PHONE,
    goal: "Ask opening hours",
    language: "ko",
    requesterName: "Requester",
    transcript: [],
    approvals: [],
    provider: "simulated",
    createdAt,
    updatedAt: createdAt,
  };
}

function errno(code: string): NodeJS.ErrnoException {
  return Object.assign(new Error(`${code}: injected`), { code });
}

type Step = "ok" | "fail" | "hang";

/** In-memory file system layer whose write outcome is decided per attempt (1-based). */
function makeFs(plan: (attempt: number) => Step = () => "ok", code = "EACCES") {
  let active = 0;
  const fs = {
    files: new Map<string, string>(),
    writes: 0,
    maxActive: 0,
    attemptTimes: [] as number[],
    plan,
    async readFile(path: string): Promise<string> {
      const value = fs.files.get(path);
      if (value === undefined) throw errno("ENOENT");
      return value;
    },
    async mkdir(): Promise<undefined> {
      return undefined;
    },
    async writeFile(path: string, data: string): Promise<void> {
      const attempt = ++fs.writes;
      fs.attemptTimes.push(Date.now());
      active++;
      fs.maxActive = Math.max(fs.maxActive, active);
      try {
        // Yield a few microtasks so unserialized writes would overlap.
        for (let i = 0; i < 5; i++) await Promise.resolve();
        const step = fs.plan(attempt);
        if (step === "hang") await new Promise(() => {});
        if (step === "fail") throw errno(code);
        fs.files.set(path, data);
      } finally {
        active--;
      }
    },
    async rename(from: string, to: string): Promise<void> {
      const value = fs.files.get(from);
      if (value === undefined) throw errno("ENOENT");
      fs.files.delete(from);
      fs.files.set(to, value);
    },
  };
  return fs;
}

function makeLogger() {
  return { info: vi.fn(), warn: vi.fn(), error: vi.fn() };
}

let dir: string;
let dataFile: string;
let unhandled: unknown[];
const onUnhandled = (reason: unknown) => unhandled.push(reason);

beforeEach(async () => {
  dir = await mkdtemp(join(tmpdir(), "taskstore-test-"));
  dataFile = join(dir, "tasks.json");
  unhandled = [];
  process.on("unhandledRejection", onUnhandled);
});

afterEach(async () => {
  vi.useRealTimers();
  // Let pending rejections surface before the listener is removed.
  await new Promise((resolve) => setTimeout(resolve, 20));
  process.off("unhandledRejection", onUnhandled);
  await rm(dir, { recursive: true, force: true });
});

describe("JsonFileTaskStore write-failure isolation", () => {
  it("background flush failure never becomes an unhandled rejection", async () => {
    vi.useFakeTimers();
    const fs = makeFs(() => "fail");
    const store = await JsonFileTaskStore.open(dataFile, { fs, logger: makeLogger() });

    store.save(task("a"));
    await vi.advanceTimersByTimeAsync(300);
    vi.useRealTimers();
    await new Promise((resolve) => setTimeout(resolve, 20));

    expect(fs.writes).toBe(1);
    expect(unhandled).toHaveLength(0);
  });

  it("a failed write does not poison later writes", async () => {
    vi.useFakeTimers();
    const fs = makeFs((attempt) => (attempt === 1 ? "fail" : "ok"));
    const store = await JsonFileTaskStore.open(dataFile, { fs, logger: makeLogger() });

    store.save(task("a"));
    await vi.advanceTimersByTimeAsync(300);
    expect(fs.writes).toBe(1);

    store.save(task("b", "2026-11-21T00:00:01.000Z"));
    await Promise.all([store.flush(), store.flush()]);

    expect(fs.writes).toBe(3);
    expect(JSON.parse(fs.files.get(dataFile) ?? "null")).toEqual(store.list());
    expect(fs.maxActive).toBe(1);
    expect(unhandled).toHaveLength(0);
  });

  it("reads and writes keep working in memory while persistence fails", async () => {
    vi.useFakeTimers();
    const fs = makeFs(() => "fail");
    const store = await JsonFileTaskStore.open(dataFile, { fs, logger: makeLogger() });

    expect(() => store.save(task("a"))).not.toThrow();
    await vi.advanceTimersByTimeAsync(300);
    store.save(task("b", "2026-11-21T00:00:01.000Z"));
    expect(store.get("a")?.id).toBe("a");
    expect(store.list().map((t) => t.id)).toEqual(["b", "a"]);
    expect(store.delete("a")).toBe(true);
    expect(store.get("a")).toBeUndefined();
    expect(store.list().map((t) => t.id)).toEqual(["b"]);
    await vi.advanceTimersByTimeAsync(5000);

    expect(fs.writes).toBeGreaterThan(0);
    expect(unhandled).toHaveLength(0);
  });
});

describe("JsonFileTaskStore retry and recovery", () => {
  it("logs each failed write once with path, code and count", async () => {
    vi.useFakeTimers();
    const fs = makeFs(() => "fail");
    const logger = makeLogger();
    const store = await JsonFileTaskStore.open(dataFile, { fs, logger, ...RETRY });

    store.save(task("a"));
    await vi.advanceTimersByTimeAsync(300);

    expect(STORE_WRITE_FAILED).toBe("Store write failed");
    expect(fs.writes).toBe(1);
    expect(logger.error).toHaveBeenCalledTimes(1);
    const [obj, msg] = logger.error.mock.calls[0] ?? [];
    expect(msg).toBe(STORE_WRITE_FAILED);
    expect(obj).toMatchObject({ path: dataFile, code: "EACCES", consecutiveFailures: 1 });
    expect(JSON.stringify(obj)).not.toContain(PHONE);
  });

  it("retries with capped exponential backoff", async () => {
    vi.useFakeTimers();
    const fs = makeFs(() => "fail");
    const store = await JsonFileTaskStore.open(dataFile, { fs, logger: makeLogger(), ...RETRY });

    store.save(task("a"));
    await vi.advanceTimersByTimeAsync(300);
    expect(fs.writes).toBe(1);

    const expected = [1000, 2000, 4000, 8000, 16_000, 30_000, 30_000];
    for (const [i, delay] of expected.entries()) {
      await vi.advanceTimersByTimeAsync(delay - 1);
      expect(fs.writes).toBe(i + 1);
      await vi.advanceTimersByTimeAsync(1);
      expect(fs.writes).toBe(i + 2);
    }
    const intervals = fs.attemptTimes.slice(1).map((t, i) => t - (fs.attemptTimes[i] ?? 0));
    expect(intervals).toEqual(expected);

    await vi.advanceTimersByTimeAsync(30_000);
    expect(fs.writes).toBe(expected.length + 2);
  });

  it("coalesces saves while a retry is pending", async () => {
    vi.useFakeTimers();
    const fs = makeFs(() => "fail");
    const store = await JsonFileTaskStore.open(dataFile, { fs, logger: makeLogger(), ...RETRY });

    store.save(task("a"));
    await vi.advanceTimersByTimeAsync(300);
    expect(fs.writes).toBe(1);

    for (let i = 0; i < 5; i++) store.save(task(`extra-${i}`));
    await vi.advanceTimersByTimeAsync(1000);

    expect(fs.writes).toBe(2);
  });

  it("the next successful write persists the full current state", async () => {
    vi.useFakeTimers();
    const fs = makeFs((attempt) => (attempt <= 2 ? "fail" : "ok"));
    const store = await JsonFileTaskStore.open(dataFile, { fs, logger: makeLogger(), ...RETRY });

    store.save(task("a"));
    await vi.advanceTimersByTimeAsync(300);
    store.save(task("b", "2026-11-21T00:00:01.000Z"));
    await vi.advanceTimersByTimeAsync(1000);
    expect(fs.writes).toBe(2);
    await vi.advanceTimersByTimeAsync(2000);

    expect(fs.writes).toBe(3);
    const written = JSON.parse(fs.files.get(dataFile) ?? "[]") as CallTask[];
    expect(written.map((t) => t.id).sort()).toEqual(["a", "b"]);
  });

  it("logs recovery once and resets the backoff", async () => {
    vi.useFakeTimers();
    const fs = makeFs((attempt) => (attempt <= 2 ? "fail" : "ok"));
    const logger = makeLogger();
    const store = await JsonFileTaskStore.open(dataFile, { fs, logger, ...RETRY });

    store.save(task("a"));
    await vi.advanceTimersByTimeAsync(300);
    store.save(task("b", "2026-11-21T00:00:01.000Z"));
    await vi.advanceTimersByTimeAsync(3000);
    expect(fs.writes).toBe(3);

    expect(STORE_WRITE_RECOVERED).toBe("Store write recovered");
    const recovered = () => logger.info.mock.calls.filter(([, msg]) => msg === STORE_WRITE_RECOVERED);
    expect(recovered()).toHaveLength(1);

    fs.plan = () => "fail";
    store.save(task("c", "2026-11-21T00:00:02.000Z"));
    await vi.advanceTimersByTimeAsync(300);
    expect(fs.writes).toBe(4);
    expect(logger.error.mock.calls.at(-1)?.[0]).toMatchObject({ consecutiveFailures: 1 });
    await vi.advanceTimersByTimeAsync(999);
    expect(fs.writes).toBe(4);
    await vi.advanceTimersByTimeAsync(1);
    expect(fs.writes).toBe(5);
    expect(recovered()).toHaveLength(1);
  });

  it("a failed write leaves the previous file intact", async () => {
    vi.useFakeTimers(); // real disk I/O; fake timers only keep the retry from outliving the test
    let failRename = false;
    const fs = {
      readFile: realFs.readFile,
      writeFile: realFs.writeFile,
      mkdir: realFs.mkdir,
      async rename(from: string, to: string) {
        if (failRename) throw errno("EACCES");
        await realFs.rename(from, to);
      },
    };
    const store = await JsonFileTaskStore.open(dataFile, { fs, logger: makeLogger(), ...RETRY });
    store.save(task("a"));
    await store.flush();
    const before = await readFile(dataFile, "utf8");

    failRename = true;
    store.save(task("b", "2026-11-21T00:00:01.000Z"));
    await expect(store.flush()).rejects.toMatchObject({ code: "EACCES" });

    const after = await readFile(dataFile, "utf8");
    expect(after).toBe(before);
    expect((JSON.parse(after) as CallTask[]).map((t) => t.id)).toEqual(["a"]);
  });
});
