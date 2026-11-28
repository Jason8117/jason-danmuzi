import { z } from "zod";

const optional = z
  .string()
  .optional()
  .transform((v) => (v && v.trim() ? v.trim() : undefined));

const EnvSchema = z.object({
  PORT: z.coerce.number().int().positive().default(8787),
  HOST: z.string().default("127.0.0.1"),
  API_TOKEN: optional,
  /** Comma-separated origins allowed to call the API from a browser (Flutter web). Mobile apps need none. */
  CORS_ORIGINS: optional,
  DATA_FILE: z.string().default("data/tasks.json"),
  CALL_PROVIDER: z.enum(["auto", "simulated", "kat"]).default("auto"),
  PUBLIC_BASE_URL: optional,
  OPENAI_API_KEY: optional,
  OPENAI_MODEL: z.string().default("gpt-4.1-mini"),
  OPENAI_REALTIME_MODEL: z.string().default("gpt-realtime"),
  OPENAI_REALTIME_VOICE: z.string().default("marin"),
  KAT_API_KEY: optional,
  KAT_GROUP_ID: optional,
  KAT_FROM_NUMBER: optional,
  /** From GET /webhook/secret (whsec_…). Used to verify status webhooks and media-stream upgrades. */
  KAT_WEBHOOK_SECRET: optional,
  KAT_API_BASE_URL: z.string().default("https://studio-gateway.zerocall.kr"),
  MAX_CONCURRENT_CALLS: z.coerce.number().int().positive().default(2),
  MAX_CALLS_PER_DAY: z.coerce.number().int().positive().default(30),
  APPROVAL_TIMEOUT_SEC: z.coerce.number().int().positive().default(90),
  MAX_CALL_DURATION_SEC: z.coerce.number().int().positive().default(600),
  SIMULATION_SPEED: z.coerce.number().positive().default(1),
  /** Kakao Local REST API key for place search (SPEC-PLACE-001). Server-side only; never sent to the app or logged. */
  KAKAO_REST_API_KEY: optional,
  KAKAO_LOCAL_BASE_URL: z.string().default("https://dapi.kakao.com"),
});

export type AppConfig = z.infer<typeof EnvSchema> & {
  provider: "simulated" | "kat";
  llm: "openai" | "heuristic";
};

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  const parsed = EnvSchema.parse(env);
  const katReady = Boolean(
    parsed.KAT_API_KEY &&
      parsed.KAT_GROUP_ID &&
      parsed.KAT_FROM_NUMBER &&
      parsed.KAT_WEBHOOK_SECRET &&
      parsed.PUBLIC_BASE_URL &&
      parsed.OPENAI_API_KEY,
  );

  if (parsed.CALL_PROVIDER === "kat" && !katReady) {
    throw new Error(
      "CALL_PROVIDER=kat requires KAT_API_KEY, KAT_GROUP_ID, KAT_FROM_NUMBER, KAT_WEBHOOK_SECRET, PUBLIC_BASE_URL and OPENAI_API_KEY",
    );
  }

  const provider =
    parsed.CALL_PROVIDER === "simulated" || !katReady ? "simulated" : "kat";

  // Real calls cost money and reach real people, so the API must never be open.
  if (provider === "kat" && !parsed.API_TOKEN) {
    throw new Error("API_TOKEN is required when real phone calls are enabled");
  }

  return {
    ...parsed,
    provider,
    llm: parsed.OPENAI_API_KEY ? "openai" : "heuristic",
  };
}
