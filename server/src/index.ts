import { loadConfig } from "./config.js";
import { createContainer } from "./container.js";
import { buildApp } from "./http/app.js";
import { logger } from "./logger.js";
import { JsonFileTaskStore } from "./store/taskStore.js";

const config = loadConfig();
const store = await JsonFileTaskStore.open(config.DATA_FILE);
const { calls, bus, kat } = createContainer(config, store, logger);
calls.recoverInterruptedTasks();

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
    await store.flush();
    process.exit(0);
  });
}
