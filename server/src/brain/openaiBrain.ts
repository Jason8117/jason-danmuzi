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

/** LLM-backed brain. Any API or validation failure degrades to the heuristic brain instead of failing the task. */
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
    return this.completeJson(PLAN_SYSTEM_PROMPT, user, PlanSchema, () => this.fallback.createPlan(input));
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
    return this.completeJson<CallOutcome>(SUMMARY_SYSTEM_PROMPT, user, OutcomeSchema, () => this.fallback.summarize(task));
  }

  private async completeJson<T>(
    system: string,
    user: string,
    schema: z.ZodType<T>,
    fallback: () => Promise<T>,
  ): Promise<T> {
    try {
      const res = await fetch("https://api.openai.com/v1/chat/completions", {
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
      if (!res.ok) throw new Error(`OpenAI responded ${res.status}`);
      const body = (await res.json()) as { choices?: { message?: { content?: string } }[] };
      const content = body.choices?.[0]?.message?.content;
      if (!content) throw new Error("OpenAI returned no content");
      return schema.parse(JSON.parse(content));
    } catch (error) {
      this.log.warn({ err: (error as Error).message }, "LLM call failed, using heuristic fallback");
      return fallback();
    }
  }
}
