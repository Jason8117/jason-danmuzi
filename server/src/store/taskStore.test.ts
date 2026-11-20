import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import type { CallTask } from "../domain/types.js";
import { JsonFileTaskStore } from "./taskStore.js";

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
