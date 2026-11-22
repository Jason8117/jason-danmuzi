import type { CallOutcome, CallPlan, CallTask, CallTaskInput, IntakeContent, Language } from "../domain/types.js";

/** Pre-call planning and post-call summarization. The live conversation itself is the provider's job. */
export interface CallBrain {
  readonly name: "openai" | "heuristic";
  createPlan(input: CallTaskInput): Promise<CallPlan>;
  summarize(task: CallTask): Promise<CallOutcome>;
  /**
   * Interprets a one-line request whose number-shaped text is already masked (SPEC-INTAKE-001 REQ-008).
   * Optional so brains that predate intake keep compiling; the service then uses the deterministic rules.
   */
  draftIntake?(maskedText: string, language: Language): Promise<IntakeContent>;
}
