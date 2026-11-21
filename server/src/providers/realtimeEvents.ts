import { z } from "zod";

/**
 * OpenAI Realtime server events the bridge acts on. Only the fields the bridge reads are checked;
 * unknown fields pass, so additions on OpenAI's side do not break calls (SPEC-ARCH-001 REQ-012).
 */
const AudioDelta = z.object({
  type: z.enum(["response.output_audio.delta", "response.audio.delta"]),
  delta: z.string(),
});

const SpeechStarted = z.object({ type: z.literal("input_audio_buffer.speech_started") });

const CalleeTranscript = z.object({
  type: z.literal("conversation.item.input_audio_transcription.completed"),
  transcript: z.string().optional(),
});

const AgentTranscript = z.object({
  type: z.enum(["response.output_audio_transcript.done", "response.audio_transcript.done"]),
  transcript: z.string().optional(),
});

const FunctionCallDone = z.object({
  type: z.literal("response.function_call_arguments.done"),
  name: z.string(),
  call_id: z.string(),
  arguments: z.string().optional(),
});

const ErrorEvent = z.object({
  type: z.literal("error"),
  error: z.object({ message: z.string().optional() }).optional(),
});

const RealtimeEvent = z.union([AudioDelta, SpeechStarted, CalleeTranscript, AgentTranscript, FunctionCallDone, ErrorEvent]);
export type RealtimeEvent = z.infer<typeof RealtimeEvent>;

const HANDLED_TYPES: ReadonlySet<string> = new Set([
  ...AudioDelta.shape.type.options,
  SpeechStarted.shape.type.value,
  CalleeTranscript.shape.type.value,
  ...AgentTranscript.shape.type.options,
  FunctionCallDone.shape.type.value,
  ErrorEvent.shape.type.value,
]);

export type ParsedRealtimeEvent =
  | { kind: "event"; event: RealtimeEvent }
  /** A handled type whose fields did not validate: ignored and logged by type name only. */
  | { kind: "malformed"; type: string }
  /** Not JSON, no type, or a type the bridge does not handle: ignored silently. */
  | { kind: "ignored" };

export function parseRealtimeEvent(text: string): ParsedRealtimeEvent {
  let data: unknown;
  try {
    data = JSON.parse(text);
  } catch {
    return { kind: "ignored" };
  }
  const type = typeof data === "object" && data !== null && "type" in data ? data.type : undefined;
  if (typeof type !== "string" || !HANDLED_TYPES.has(type)) return { kind: "ignored" };
  const parsed = RealtimeEvent.safeParse(data);
  return parsed.success ? { kind: "event", event: parsed.data } : { kind: "malformed", type };
}

/** Arguments of the request_user_approval tool. */
export const ApprovalToolArgs = z.object({ question: z.string() });
