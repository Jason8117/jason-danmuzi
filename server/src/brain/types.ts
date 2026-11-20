import type { CallOutcome, CallPlan, CallTask, CallTaskInput } from "../domain/types.js";

/** Pre-call planning and post-call summarization. The live conversation itself is the provider's job. */
export interface CallBrain {
  readonly name: "openai" | "heuristic";
  createPlan(input: CallTaskInput): Promise<CallPlan>;
  summarize(task: CallTask): Promise<CallOutcome>;
}
