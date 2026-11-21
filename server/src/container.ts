import { HeuristicBrain } from "./brain/heuristicBrain.js";
import { OpenAiBrain } from "./brain/openaiBrain.js";
import type { CallBrain } from "./brain/types.js";
import type { AppConfig } from "./config.js";
import { EventBus } from "./events/eventBus.js";
import type { Logger } from "./logger.js";
import { KatCallProvider } from "./providers/kat/katProvider.js";
import { SimulatedCallProvider } from "./providers/simulatedProvider.js";
import type { CallProvider, ProviderRoutes } from "./providers/types.js";
import { CallService } from "./services/callService.js";
import type { TaskStore } from "./store/taskStore.js";

export interface Container {
  calls: CallService;
  bus: EventBus;
  /** Routes the active provider declares (none for the simulated provider). */
  providerRoutes?: ProviderRoutes;
  /** True when the active provider dials real phones. */
  realCalls: boolean;
}

/** Wires concrete implementations from configuration. The only place that knows which ones exist. */
export function createContainer(config: AppConfig, store: TaskStore, log: Logger): Container {
  const bus = new EventBus();

  const brain: CallBrain =
    config.llm === "openai" && config.OPENAI_API_KEY
      ? new OpenAiBrain(config.OPENAI_API_KEY, config.OPENAI_MODEL, log)
      : new HeuristicBrain();

  let provider: CallProvider;
  let realCalls: boolean;
  if (config.provider === "kat") {
    provider = new KatCallProvider(
      {
        apiKey: config.KAT_API_KEY!,
        groupId: config.KAT_GROUP_ID!,
        fromNumber: config.KAT_FROM_NUMBER!,
        webhookSecret: config.KAT_WEBHOOK_SECRET!,
        publicBaseUrl: config.PUBLIC_BASE_URL!,
        apiBaseUrl: config.KAT_API_BASE_URL,
        maxCallDurationSec: config.MAX_CALL_DURATION_SEC,
        realtime: {
          apiKey: config.OPENAI_API_KEY!,
          model: config.OPENAI_REALTIME_MODEL,
          voice: config.OPENAI_REALTIME_VOICE,
        },
      },
      log,
    );
    realCalls = true;
  } else {
    provider = new SimulatedCallProvider(config.SIMULATION_SPEED);
    realCalls = false;
  }

  const calls = new CallService(store, bus, brain, provider, {
    maxConcurrentCalls: config.MAX_CONCURRENT_CALLS,
    maxCallsPerDay: config.MAX_CALLS_PER_DAY,
    approvalTimeoutMs: config.APPROVAL_TIMEOUT_SEC * 1000,
    maxCallDurationMs: config.MAX_CALL_DURATION_SEC * 1000,
  });

  return { calls, bus, providerRoutes: provider.routes?.(), realCalls };
}
