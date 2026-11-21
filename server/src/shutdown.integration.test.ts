import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { HeuristicBrain } from "./brain/heuristicBrain.js";
import type { CallTask } from "./domain/types.js";
import { EventBus } from "./events/eventBus.js";
import { buildApp } from "./http/app.js";
import type { Logger } from "./logger.js";
import type { CallProvider } from "./providers/types.js";
import { CallService, SHUTDOWN_CALL_ERROR } from "./services/callService.js";
import { createShutdownHandler } from "./shutdown.js";
import { JsonFileTaskStore } from "./store/taskStore.js";

const quiet: Logger = { info: () => {}, warn: () => {}, error: () => {} };
const dirs: string[] = [];

afterEach(async () => {
  for (const dir of dirs.splice(0)) await rm(dir, { recursive: true, force: true });
});

// SPEC-LIFECYCLE-001 REQ-004 / REQ-006, audit finding F2: the step budget and the hang-up deadline
// used to be the same number, so the final flush could snapshot the call before it was marked failed.
describe("shutdown with a hang-up that never answers (real app, real JSON store)", () => {
  it("saves the shutdown-failed status to the data file", async () => {
    const dir = await mkdtemp(join(tmpdir(), "shutdown-integration-"));
    dirs.push(dir);
    const file = join(dir, "tasks.json");
    const store = await JsonFileTaskStore.open(file, { logger: quiet });
    const provider: CallProvider = {
      name: "kat",
      async start(session) {
        session.recordProviderCallId("c-1");
        session.markRinging();
      },
      hangup: () => new Promise<void>(() => {}),
      terminateByProviderCallId: () => new Promise<void>(() => {}),
    };
    const bus = new EventBus();
    const calls = new CallService(store, bus, new HeuristicBrain(), provider, {
      maxConcurrentCalls: 5,
      maxCallsPerDay: 100,
      approvalTimeoutMs: 60_000,
      maxCallDurationMs: 600_000,
      logger: quiet,
    });
    const task = calls.create({
      targetName: "x",
      phoneNumber: "010-1234-5678",
      goal: "영업시간 문의",
      language: "ko",
      requesterName: "김",
    });
    while (calls.get(task.id).status === "planning") await new Promise((r) => setTimeout(r, 5));
    await calls.approvePlan(task.id);
    expect(calls.get(task.id).status).toBe("ringing");

    const app = await buildApp({
      config: { API_TOKEN: undefined, CORS_ORIGINS: undefined, provider: "simulated", llm: "heuristic" },
      calls,
      bus,
      logger: false,
    });
    await app.listen({ port: 0, host: "127.0.0.1" });

    const exitCode = await new Promise<number>((resolve) => {
      const onSignal = createShutdownHandler({
        calls,
        app,
        store,
        logger: quiet,
        dataFile: file,
        exit: resolve,
        // Shorter than the 3 s default to keep the test fast; the step budget still equals the value
        // the shutdown module derives the hang-up deadline from, which is what used to race.
        budgets: { terminateCallsMs: 600 },
      });
      onSignal("SIGTERM");
    });

    expect(exitCode).toBe(0);
    expect(calls.get(task.id).status).toBe("failed");
    const onDisk = JSON.parse(await readFile(file, "utf8")) as CallTask[];
    expect(onDisk.find((t) => t.id === task.id)).toMatchObject({ status: "failed", error: SHUTDOWN_CALL_ERROR });
  }, 15_000);
});
