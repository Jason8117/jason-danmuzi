import { z } from "zod";

/**
 * Shapes of what KAT Cloud sends us. Only known fields are checked and unknown fields pass,
 * so KAT can add fields without breaking calls (SPEC-ARCH-001 REQ-009 ~ REQ-011, design.md §4).
 */

/** Parses JSON without throwing; undefined when the text is not JSON. */
export function parseJson(text: string): unknown {
  try {
    return JSON.parse(text) as unknown;
  } catch {
    return undefined;
  }
}

/** A call id may arrive as a string or a number; both are kept as a string. */
const CallIdValue = z.union([z.string(), z.number()]).transform(String);

/** Call creation result (already unwrapped from `{ code, message, result }` when wrapped). */
export const CreateCallResponse = z.object({ callId: CallIdValue.pipe(z.string().min(1)) });

/**
 * Error body fields worth showing. A field of the wrong type is dropped on its own (so a string `message`
 * survives an object `error`); a body that is not an object at all falls back to the raw text.
 */
export const ApiErrorBody = z.object({
  message: z.string().optional().catch(undefined),
  error: z.string().optional().catch(undefined),
});

export const StatusWebhook = z.object({
  data: z
    .object({
      type: z.string().optional(),
      callId: z.string().optional(),
      status: z.string().optional(),
      metadata: z.record(z.string(), z.unknown()).optional(),
    })
    .optional(),
});
export type StatusWebhook = z.infer<typeof StatusWebhook>;

/** customParameters arrive either as an object or as a JSON string of one. */
export const StartFrame = z.object({
  event: z.literal("start"),
  streamSid: z.string().optional(),
  start: z
    .object({
      streamSid: z.string().optional(),
      streamId: z.string().optional(),
      callId: CallIdValue.optional(),
      customParameters: z.union([z.record(z.string(), z.unknown()), z.string()]).optional(),
    })
    .optional(),
});
export type StartFrame = z.infer<typeof StartFrame>;

/** Media-stream frames after `start`: audio from the callee, and the end of the stream. */
const MediaFrame = z.object({ event: z.literal("media"), media: z.object({ payload: z.string().min(1) }) });
const StopFrame = z.object({ event: z.literal("stop") });
const MediaStreamFrame = z.union([MediaFrame, StopFrame]);
export type MediaStreamFrame = z.infer<typeof MediaStreamFrame>;

/** Undefined for anything that is not a well-formed media or stop frame (ignored without logging). */
export function parseMediaStreamFrame(text: string): MediaStreamFrame | undefined {
  const parsed = MediaStreamFrame.safeParse(parseJson(text));
  return parsed.success ? parsed.data : undefined;
}
