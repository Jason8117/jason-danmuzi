import * as realFs from "node:fs/promises";
import { chmod, mkdtemp, readdir, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import type { CallTask } from "../domain/types.js";
import {
  FINAL_STORE_FLUSH_FAILED,
  JsonFileTaskStore,
  STORE_WRITE_FAILED,
  STORE_WRITE_RECOVERED,
} from "./taskStore.js";

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

describe("JsonFileTaskStore final flush", () => {
  it("final flush cancels pending debounce and retry timers", async () => {
    vi.useFakeTimers();

    // Pending debounce timer.
    const debounced = makeFs();
    const first = await JsonFileTaskStore.open(dataFile, { fs: debounced, logger: makeLogger(), ...RETRY });
    first.save(task("a"));
    expect(vi.getTimerCount()).toBe(1);
    await expect(first.finalFlush()).resolves.toEqual({ ok: true });
    expect(vi.getTimerCount()).toBe(0);
    expect(debounced.writes).toBe(1);

    // Pending retry timer.
    const retried = makeFs((attempt) => (attempt === 1 ? "fail" : "ok"));
    const second = await JsonFileTaskStore.open(dataFile, { fs: retried, logger: makeLogger(), ...RETRY });
    second.save(task("b"));
    await vi.advanceTimersByTimeAsync(300);
    expect(retried.writes).toBe(1);
    expect(vi.getTimerCount()).toBe(1);
    await expect(second.finalFlush()).resolves.toEqual({ ok: true });
    expect(vi.getTimerCount()).toBe(0);
    expect(retried.writes).toBe(2);
    await vi.advanceTimersByTimeAsync(60_000);
    expect(retried.writes).toBe(2);
  });

  it("final flush reports success or failure and never hangs", async () => {
    expect(FINAL_STORE_FLUSH_FAILED).toBe("Final store flush failed");
    vi.useFakeTimers();

    const failing = await JsonFileTaskStore.open(dataFile, { fs: makeFs(() => "fail"), logger: makeLogger() });
    failing.save(task("a"));
    await expect(failing.finalFlush()).resolves.toMatchObject({ ok: false, reason: "error" });

    const hanging = await JsonFileTaskStore.open(dataFile, {
      fs: makeFs(() => "hang"),
      logger: makeLogger(),
      finalFlushTimeoutMs: 100,
    });
    hanging.save(task("a"));
    let settled: unknown;
    const pending = hanging.finalFlush().then((result) => (settled = result));
    await vi.advanceTimersByTimeAsync(99);
    expect(settled).toBeUndefined();
    await vi.advanceTimersByTimeAsync(1);
    await pending;
    expect(settled).toMatchObject({ ok: false, reason: "timeout" });

    const healthy = await JsonFileTaskStore.open(dataFile, { fs: makeFs(), logger: makeLogger() });
    healthy.save(task("a"));
    await expect(healthy.finalFlush()).resolves.toEqual({ ok: true });
    expect(unhandled).toHaveLength(0);
  });
});

describe("JsonFileTaskStore startup and real file system", () => {
  it("keeps current startup behavior: corrupt or unreadable files fail, legacy entries load", async () => {
    // (1) Corrupt JSON: open rejects and leaves the directory untouched.
    await writeFile(dataFile, "{not json", "utf8");
    const listingBefore = await readdir(dir);
    await expect(JsonFileTaskStore.open(dataFile, { logger: makeLogger() })).rejects.toThrow(SyntaxError);
    expect(await readdir(dir)).toEqual(listingBefore);
    expect(await readFile(dataFile, "utf8")).toBe("{not json");

    // (2) Read error other than ENOENT: open rejects and writes nothing.
    const unreadable = makeFs();
    unreadable.readFile = async () => {
      throw errno("EACCES");
    };
    await expect(JsonFileTaskStore.open(dataFile, { fs: unreadable, logger: makeLogger() })).rejects.toMatchObject({
      code: "EACCES",
    });
    expect(unreadable.writes).toBe(0);
    expect(await readdir(dir)).toEqual(listingBefore);

    // (3) Legacy entries without `version` load as version 0.
    const { version: _omitted, ...legacy } = task("legacy");
    await writeFile(dataFile, JSON.stringify([legacy]), "utf8");
    const loaded = await JsonFileTaskStore.open(dataFile, { logger: makeLogger() });
    expect(loaded.get("legacy")).toMatchObject({ id: "legacy", version: 0 });

    // (4) Missing file opens an empty store.
    const missing = await JsonFileTaskStore.open(join(dir, "absent.json"), { logger: makeLogger() });
    expect(missing.list()).toEqual([]);
  });

  const canChmod = process.platform !== "win32" && process.getuid?.() !== 0;
  (canChmod ? it : it.skip)("survives a read-only data directory (regression)", async () => {
    const store = await JsonFileTaskStore.open(dataFile, {
      logger: makeLogger(),
      debounceMs: 10,
      retryInitialMs: 100,
      retryMultiplier: 1,
      retryMaxMs: 100,
    });
    await chmod(dir, 0o555);
    try {
      store.save(task("a"));
      await new Promise((resolve) => setTimeout(resolve, 400));
      expect(unhandled).toHaveLength(0);
    } finally {
      await chmod(dir, 0o755);
    }

    const deadline = Date.now() + 2000;
    let written: CallTask[] = [];
    while (Date.now() < deadline) {
      written = JSON.parse(await readFile(dataFile, "utf8").catch(() => "[]")) as CallTask[];
      if (written.length > 0) break;
      await new Promise((resolve) => setTimeout(resolve, 20));
    }
    expect(written.map((t) => t.id)).toEqual(["a"]);
    await expect(store.finalFlush()).resolves.toEqual({ ok: true });
    expect(unhandled).toHaveLength(0);
  });
});
