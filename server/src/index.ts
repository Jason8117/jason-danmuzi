import { loadConfig } from "./config.js";
import { createContainer } from "./container.js";
import { buildApp } from "./http/app.js";
import { logger } from "./logger.js";
import { createShutdownHandler } from "./shutdown.js";
import { JsonFileTaskStore } from "./store/taskStore.js";

const config = loadConfig();
const store = await JsonFileTaskStore.open(config.DATA_FILE, { logger });
const { calls, bus, providerRoutes, realCalls, places } = createContainer(config, store, logger);
// Before listen(): hangs up calls a previous process left behind (bounded to 10 s).
await calls.recoverInterruptedTasks();

const app = await buildApp({ config, calls, bus, providerRoutes, realCalls, places });

if (!config.API_TOKEN) {
  logger.warn({}, "API_TOKEN is not set: the API is open to anyone who can reach it. Use only on a trusted network.");
}

await app.listen({ port: config.PORT, host: config.HOST });
logger.info(
  {
    provider: config.provider,
    brain: config.llm,
    port: config.PORT,
    // Which place search is wired, never the key (SPEC-PLACE-001 AC-001).
    placeSearch: places?.source ?? "off",
    // Host only — so we can catch stale tunnel URLs without logging secrets.
    publicBaseHost: config.PUBLIC_BASE_URL ? new URL(config.PUBLIC_BASE_URL).host : undefined,
  },
  "CallMate server ready",
);

// Live calls are hung up before app.close(), which also closes the media sockets; total budget 9 s.
const onSignal = createShutdownHandler({
  calls,
  app,
  store,
  logger,
  exit: (code) => process.exit(code),
  dataFile: config.DATA_FILE,
});
// `on`, not `once`: the second signal must reach the handler so it can exit 1 immediately.
for (const signal of ["SIGINT", "SIGTERM"] as const) {
  process.on(signal, () => onSignal(signal));
}
