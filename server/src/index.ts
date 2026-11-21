import { loadConfig } from "./config.js";
import { createContainer } from "./container.js";
import { buildApp } from "./http/app.js";
import { logger } from "./logger.js";
import { FINAL_STORE_FLUSH_FAILED, JsonFileTaskStore } from "./store/taskStore.js";

const config = loadConfig();
const store = await JsonFileTaskStore.open(config.DATA_FILE, { logger });
const { calls, bus, kat } = createContainer(config, store, logger);
// Before listen(): hangs up calls a previous process left behind (bounded to 10 s).
await calls.recoverInterruptedTasks();

const app = await buildApp({ config, calls, bus, kat });

if (!config.API_TOKEN) {
  logger.warn({}, "API_TOKEN is not set: the API is open to anyone who can reach it. Use only on a trusted network.");
}

await app.listen({ port: config.PORT, host: config.HOST });
logger.info(
  {
    provider: config.provider,
    brain: config.llm,
    port: config.PORT,
    // Host only — so we can catch stale tunnel URLs without logging secrets.
    publicBaseHost: config.PUBLIC_BASE_URL ? new URL(config.PUBLIC_BASE_URL).host : undefined,
  },
  "CallMate server ready",
);

for (const signal of ["SIGINT", "SIGTERM"] as const) {
  process.once(signal, async () => {
    await app.close();
    const result = await store.finalFlush();
    if (!result.ok) {
      const code = (result.error as NodeJS.ErrnoException | undefined)?.code;
      logger.error({ path: config.DATA_FILE, reason: result.reason, code }, FINAL_STORE_FLUSH_FAILED);
    }
    process.exit(result.ok ? 0 : 1);
  });
}
