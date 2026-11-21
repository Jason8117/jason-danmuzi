import { z } from "zod";
import type { CallOutcome, CallPlan, CallTask, CallTaskInput } from "../domain/types.js";
import { HeuristicBrain } from "./heuristicBrain.js";
import { PLAN_SYSTEM_PROMPT, SUMMARY_SYSTEM_PROMPT } from "./prompts.js";
import type { CallBrain } from "./types.js";

const PlanSchema = z.object({
  openingLine: z.string().min(1),
  steps: z.array(z.string()).max(8),
  questionsToAsk: z.array(z.string()).max(8),
  approvalPoints: z.array(z.string()).max(5),
  fallback: z.string(),
});

const OutcomeSchema = z.object({
  result: z.enum(["success", "partial", "failed"]),
  summary: z.string(),
  keyFacts: z.array(z.string()),
  followUps: z.array(z.string()),
});

interface Logger {
  warn(obj: object, msg: string): void;
}

/** Why an LLM call fell back. Only these categories are logged, never error messages or response text (REQ-009). */
type FailureReason = "timeout" | "http_status" | "invalid_json" | "schema_mismatch" | "empty_content" | "network";

type Completion<T> = { ok: true; value: T } | { ok: false; reason: FailureReason; status?: number };

interface CallContext {
  op: "plan" | "summarize";
  taskId?: string;
}

function isTimeout(error: unknown): boolean {
  return typeof error === "object" && error !== null && "name" in error && error.name === "TimeoutError";
}

/**
 * LLM-backed brain. Any API or validation failure degrades to the heuristic brain instead of failing the task;
 * the fallback is logged by category and the heuristic outcome carries `source: "heuristic"`.
 */
export class OpenAiBrain implements CallBrain {
  readonly name = "openai" as const;
  private readonly fallback = new HeuristicBrain();

  constructor(
    private readonly apiKey: string,
    private readonly model: string,
    private readonly log: Logger,
  ) {}

  async createPlan(input: CallTaskInput): Promise<CallPlan> {
    const user = JSON.stringify({
      language: input.language,
      requesterName: input.requesterName,
      calleeName: input.targetName,
      goal: input.goal,
      shareableInfo: input.context ?? "",
    });
    const plan = await this.completeJson(PLAN_SYSTEM_PROMPT, user, PlanSchema, { op: "plan" });
    return plan ?? this.fallback.createPlan(input);
  }

  async summarize(task: CallTask): Promise<CallOutcome> {
    const user = JSON.stringify({
      language: task.language,
      goal: task.goal,
      approvals: task.approvals.map((a) => ({
        question: a.question,
        status: a.status,
        userComment: a.userComment,
      })),
      transcript: task.transcript.map((t) => `${t.speaker}: ${t.text}`),
    });
    const outcome = await this.completeJson(SUMMARY_SYSTEM_PROMPT, user, OutcomeSchema, {
      op: "summarize",
      taskId: task.id,
    });
    return outcome ? { ...outcome, source: "llm" } : this.fallback.summarize(task);
  }

  /** Returns the validated LLM answer, or undefined after logging why the caller must fall back. */
  private async completeJson<T>(system: string, user: string, schema: z.ZodType<T>, ctx: CallContext): Promise<T | undefined> {
    const completion = await this.request(system, user, schema);
    if (completion.ok) return completion.value;
    this.log.warn(
      {
        op: ctx.op,
        reason: completion.reason,
        ...(completion.status !== undefined && { status: completion.status }),
        ...(ctx.taskId !== undefined && { taskId: ctx.taskId }),
      },
      "LLM call failed, using heuristic fallback",
    );
    return undefined;
  }

  // @MX:WARN: [AUTO] Every failure path must map to a FailureReason without carrying the thrown error's message.
  // @MX:REASON: JSON.parse and zod messages can echo response or transcript text, which REQ-009 keeps out of logs.
  private async request<T>(system: string, user: string, schema: z.ZodType<T>): Promise<Completion<T>> {
    let res: Response;
    try {
      res = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: { Authorization: `Bearer ${this.apiKey}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          model: this.model,
          response_format: { type: "json_object" },
          messages: [
            { role: "system", content: system },
            { role: "user", content: user },
          ],
        }),
        signal: AbortSignal.timeout(30_000),
      });
    } catch (error) {
      return { ok: false, reason: isTimeout(error) ? "timeout" : "network" };
    }
    if (!res.ok) return { ok: false, reason: "http_status", status: res.status };

    // JSON `null` is a valid body too; it must reach empty_content instead of throwing (audit F4).
    let body: { choices?: { message?: { content?: string } }[] } | null;
    try {
      body = (await res.json()) as typeof body;
    } catch (error) {
      // The timeout signal also covers reading the body.
      return { ok: false, reason: isTimeout(error) ? "timeout" : "invalid_json" };
    }
    const content = body?.choices?.[0]?.message?.content;
    if (!content) return { ok: false, reason: "empty_content" };

    let parsed: unknown;
    try {
      parsed = JSON.parse(content);
    } catch {
      return { ok: false, reason: "invalid_json" };
    }
    const checked = schema.safeParse(parsed);
    return checked.success ? { ok: true, value: checked.data } : { ok: false, reason: "schema_mismatch" };
  }
}
