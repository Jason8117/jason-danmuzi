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
  /** Start the call as soon as the plan is ready (SPEC-INTAKE-001 REQ-013). */
  autoStart: z.boolean().optional(),
});

/** One-line request for POST /v1/intake; 1-1000 UTF-16 units after trimming, like CreateTaskBody.goal (REQ-001). */
export const IntakeBody = z.object({
  text: text(1000),
  language: z.enum(["ko", "en"]).default("ko"),
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

const MAX_APPROVAL_COMMENT_CHARS = 500;

export const ApprovalDecisionBody = z
  .object({
    decision: z.enum(["approve", "reject"]),
    /** Optional user guidance; empty/whitespace becomes undefined. */
    comment: z.string().optional(),
  })
  .superRefine((body, ctx) => {
    if (body.comment === undefined) return;
    const trimmed = body.comment.trim();
    if (!trimmed) return;
    if ([...trimmed].length > MAX_APPROVAL_COMMENT_CHARS) {
      ctx.addIssue({
        code: "custom",
        path: ["comment"],
        message: `comment must be at most ${MAX_APPROVAL_COMMENT_CHARS} characters`,
      });
    }
  })
  .transform((body) => {
    const trimmed = body.comment?.trim();
    return {
      decision: body.decision,
      comment: trimmed ? trimmed : undefined,
    };
  });

export const TaskParams = z.object({ id: z.uuid() });
export const ApprovalParams = z.object({ id: z.uuid(), approvalId: z.uuid() });
