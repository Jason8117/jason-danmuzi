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
  CALL_PROVIDER: z.enum(["auto", "simulated", "twilio"]).default("auto"),
  PUBLIC_BASE_URL: optional,
  OPENAI_API_KEY: optional,
  OPENAI_MODEL: z.string().default("gpt-4.1-mini"),
  OPENAI_REALTIME_MODEL: z.string().default("gpt-realtime"),
  OPENAI_REALTIME_VOICE: z.string().default("marin"),
  TWILIO_ACCOUNT_SID: optional,
  TWILIO_AUTH_TOKEN: optional,
  TWILIO_FROM_NUMBER: optional,
  MAX_CONCURRENT_CALLS: z.coerce.number().int().positive().default(2),
  MAX_CALLS_PER_DAY: z.coerce.number().int().positive().default(30),
  APPROVAL_TIMEOUT_SEC: z.coerce.number().int().positive().default(90),
  MAX_CALL_DURATION_SEC: z.coerce.number().int().positive().default(600),
  SIMULATION_SPEED: z.coerce.number().positive().default(1),
});

export type AppConfig = z.infer<typeof EnvSchema> & {
  provider: "simulated" | "twilio";
  llm: "openai" | "heuristic";
};

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  const parsed = EnvSchema.parse(env);
  const twilioReady = Boolean(
    parsed.TWILIO_ACCOUNT_SID &&
      parsed.TWILIO_AUTH_TOKEN &&
      parsed.TWILIO_FROM_NUMBER &&
      parsed.PUBLIC_BASE_URL &&
      parsed.OPENAI_API_KEY,
  );

  if (parsed.CALL_PROVIDER === "twilio" && !twilioReady) {
    throw new Error(
      "CALL_PROVIDER=twilio requires TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM_NUMBER, PUBLIC_BASE_URL and OPENAI_API_KEY",
    );
  }

  const provider =
    parsed.CALL_PROVIDER === "simulated" || !twilioReady ? "simulated" : "twilio";

  // Real calls cost money and reach real people, so the API must never be open.
  if (provider === "twilio" && !parsed.API_TOKEN) {
    throw new Error("API_TOKEN is required when real phone calls are enabled");
  }

  return {
    ...parsed,
    provider,
    llm: parsed.OPENAI_API_KEY ? "openai" : "heuristic",
  };
}
