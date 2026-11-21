import type { Logger } from "./logger.js";
import type { TerminateActiveCallsOptions } from "./services/callService.js";
import { FINAL_STORE_FLUSH_FAILED, type FinalFlushResult } from "./store/taskStore.js";

/**
 * Per-step budgets. Their sum (9 s) assumes the platform waits at least 10 s after SIGTERM
 * before killing the process (SPEC-LIFECYCLE-001 §4).
 */
export interface ShutdownBudgets {
  terminateCallsMs: number;
  appCloseMs: number;
  finalFlushMs: number;
}

export const DEFAULT_SHUTDOWN_BUDGETS: ShutdownBudgets = {
  terminateCallsMs: 3000,
  appCloseMs: 1000,
  finalFlushMs: 5000,
};

export interface ShutdownDeps {
  calls: {
    beginShutdown(): void;
    terminateActiveCalls(options: TerminateActiveCallsOptions): Promise<void>;
  };
  app: { close(): Promise<unknown> };
  store: { finalFlush(): Promise<FinalFlushResult> };
  logger: Logger;
  exit: (code: number) => void;
  /** Only used to say which file failed to save. */
  dataFile?: string;
  budgets?: Partial<ShutdownBudgets>;
}

/**
 * The hang-up deadline handed to terminateActiveCalls ends this long before the step budget, so the
 * calls are marked failed before the step moves on to app.close and the final flush. With equal
 * values the step timer fired first and the flush saved the pre-shutdown status (audit F2).
 */
export const TERMINATE_MARK_HEADROOM_MS = 250;

const TIMED_OUT = Symbol("timed out");

/** Resolves with the step's value, or TIMED_OUT once `ms` passes. A rejected step counts as finished. */
async function withinBudget<T>(step: () => Promise<T>, ms: number): Promise<T | typeof TIMED_OUT> {
  let timer: NodeJS.Timeout | undefined;
  const budget = new Promise<typeof TIMED_OUT>((resolve) => {
    timer = setTimeout(() => resolve(TIMED_OUT), ms);
  });
  try {
    return await Promise.race([Promise.resolve().then(step), budget]);
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Returns the SIGINT/SIGTERM handler. The first signal runs: block new work → hang up live
 * calls (before app.close(), which also closes the provider's media sockets) → close HTTP →
 * final store flush → exit 0/1. Every step races its own budget, so the whole sequence ends
 * within 9 s even when a dependency never answers. A second signal exits 1 immediately.
 */
// @MX:ANCHOR: [AUTO] Process shutdown contract: step order, 3 s + 1 s + 5 s budgets, exit code mapping.
// @MX:REASON: Live phone calls must be hung up before app.close(); index.ts and SPEC-LIFECYCLE-001 AC-002/AC-005/AC-015 depend on this order and timing.
// @MX:SPEC: SPEC-LIFECYCLE-001
export function createShutdownHandler(deps: ShutdownDeps): (signal: string) => void {
  const budgets = { ...DEFAULT_SHUTDOWN_BUDGETS, ...deps.budgets };
  const { logger } = deps;
  let signals = 0;
  let exited = false;

  const exit = (code: number) => {
    if (exited) return;
    exited = true;
    deps.exit(code);
  };

  const step = async <T>(name: string, run: () => Promise<T>, ms: number): Promise<T | typeof TIMED_OUT> => {
    try {
      const result = await withinBudget(run, ms);
      if (result === TIMED_OUT) logger.warn({ step: name, budgetMs: ms }, "Shutdown step exceeded its budget");
      return result;
    } catch (error) {
      logger.warn({ step: name, err: (error as Error).message }, "Shutdown step failed");
      return TIMED_OUT;
    }
  };

  const run = async (signal: string) => {
    logger.info({ signal }, "Shutting down");
    try {
      deps.calls.beginShutdown();
    } catch (error) {
      logger.warn({ step: "begin_shutdown", err: (error as Error).message }, "Shutdown step failed");
    }
    // The outer budget only guards a terminateActiveCalls that itself hangs; normally it returns at its
    // own, earlier deadline with every call already marked failed.
    const hangupDeadlineMs = Math.max(0, budgets.terminateCallsMs - TERMINATE_MARK_HEADROOM_MS);
    await step(
      "terminate_calls",
      () => deps.calls.terminateActiveCalls({ deadlineMs: hangupDeadlineMs }),
      budgets.terminateCallsMs,
    );
    if (exited) return;
    await step("app_close", () => deps.app.close(), budgets.appCloseMs);
    if (exited) return;

    let result: FinalFlushResult;
    try {
      const flushed = await withinBudget(() => deps.store.finalFlush(), budgets.finalFlushMs);
      result = flushed === TIMED_OUT ? { ok: false, reason: "timeout" } : flushed;
    } catch (error) {
      result = { ok: false, reason: "error", error };
    }
    if (exited) return;
    if (!result.ok) {
      const code = (result.error as NodeJS.ErrnoException | undefined)?.code;
      logger.error({ path: deps.dataFile, reason: result.reason, code }, FINAL_STORE_FLUSH_FAILED);
    }
    exit(result.ok ? 0 : 1);
  };

  return (signal: string) => {
    signals += 1;
    if (signals === 1) {
      void run(signal);
      return;
    }
    logger.warn({ signal }, "Second shutdown signal: exiting now");
    exit(1);
  };
}
