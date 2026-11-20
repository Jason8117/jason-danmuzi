import { z } from "zod";

const text = (max: number) => z.string().trim().min(1).max(max);

export const CreateTaskBody = z.object({
  targetName: text(80),
  phoneNumber: text(32),
  goal: text(1000),
  context: z.string().trim().max(1000).optional(),
  language: z.enum(["ko", "en"]).default("ko"),
  requesterName: text(40),
  callbackNumber: z.string().trim().max(32).optional(),
});

export const ApprovePlanBody = z
  .object({
    plan: z
      .object({
        openingLine: text(500).optional(),
        questionsToAsk: z.array(text(300)).max(8).optional(),
      })
      .optional(),
  })
  .default({});

export const ApprovalDecisionBody = z.object({
  decision: z.enum(["approve", "reject"]),
});

export const TaskParams = z.object({ id: z.uuid() });
export const ApprovalParams = z.object({ id: z.uuid(), approvalId: z.uuid() });
