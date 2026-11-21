import WebSocket from "ws";
import type { ApprovalDecision } from "../domain/types.js";
import { parseMediaStreamFrame } from "./kat/schemas.js";
import { ApprovalToolArgs, EndCallToolArgs, parseRealtimeEvent } from "./realtimeEvents.js";
import type { CallSession } from "./types.js";

export interface RealtimeOptions {
  apiKey: string;
  model: string;
  voice: string;
}

interface Logger {
  info(obj: object, msg: string): void;
  warn(obj: object, msg: string): void;
}

const TOOLS = [
  {
    type: "function",
    name: "request_user_approval",
    description:
      "Ask the requester to approve a commitment (payment, fee, contract, booking) before agreeing to it. Tell the callee you are checking first.",
    parameters: {
      type: "object",
      properties: {
        question: { type: "string", description: "One short yes/no question for the requester, including amounts and conditions." },
      },
      required: ["question"],
    },
  },
  {
    type: "function",
    name: "end_call",
    description: "Hang up after saying goodbye, when the goal is done or cannot be done.",
    parameters: {
      type: "object",
      properties: { reason: { type: "string" } },
      required: ["reason"],
    },
  },
];

/** Gives the goodbye audio time to reach the callee before the line is cut. */
const HANGUP_GRACE_MS = 2500;
const REALTIME_CONNECT_RETRIES = 2;
/** Longest end_call reason kept in the log; the reason is the model's own words, not callee speech. */
const END_CALL_REASON_LOG_CHARS = 120;
/** Asked when the model calls request_user_approval without a usable question. */
const DEFAULT_APPROVAL_QUESTION = "진행해도 될까요?";

/** Opens the OpenAI Realtime socket. Injectable so tests never reach the network. */
export type RealtimeSocketFactory = (url: string, options: WebSocket.ClientOptions) => WebSocket;

const openRealtimeSocket: RealtimeSocketFactory = (url, options) => new WebSocket(url, options);

export interface BridgeParams {
  media: WebSocket;
  streamSid: string;
  session: CallSession;
  options: RealtimeOptions;
  hangup: () => Promise<void>;
  log: Logger;
  /** Defaults to a real `ws` client socket. */
  createSocket?: RealtimeSocketFactory;
}

/**
 * Bridges a G.711 μ-law media stream (KAT Cloud / Twilio-compatible JSON frames)
 * to one OpenAI Realtime session. Both sides speak μ-law, so audio is forwarded
 * without transcoding.
 */
export function bridgeToRealtime(params: BridgeParams): void {
  const { media, streamSid, session, options, hangup, log, createSocket = openRealtimeSocket } = params;
  const task = session.task();
  // Built once per bridge from the same snapshot, as before; reused on every reconnect attempt.
  const instructions = session.agentInstructions();

  let ai: WebSocket | undefined;
  let intentionalClose = false;
  let opened = false;
  let failed = false;
  let connectAttempt = 0;
  let retryScheduled = false;
  let endCallRequested = false;

  const sendAi = (event: object) => {
    if (ai?.readyState === WebSocket.OPEN) ai.send(JSON.stringify(event));
  };
  const sendMedia = (event: object) => {
    if (media.readyState === WebSocket.OPEN) media.send(JSON.stringify(event));
  };

  const closeAi = (reason: string) => {
    intentionalClose = true;
    if (!ai) return;
    if (ai.readyState === WebSocket.OPEN || ai.readyState === WebSocket.CONNECTING) {
      log.info({ taskId: session.taskId, reason, readyState: ai.readyState }, "Closing Realtime socket");
      ai.close();
    }
  };

  session.signal.addEventListener("abort", () => closeAi("session_abort"), { once: true });

  const failAndHangup = (message: string) => {
    if (failed || session.signal.aborted) return;
    failed = true;
    session.appendTranscript("system", message);
    session.end({ error: message });
    void hangup();
  };

  const answerTool = (callId: string, output: object) => {
    sendAi({ type: "conversation.item.create", item: { type: "function_call_output", call_id: callId, output: JSON.stringify(output) } });
    sendAi({ type: "response.create" });
  };

  const handleTool = async (name: string, callId: string, rawArgs: string) => {
    let args: unknown = {};
    try {
      args = JSON.parse(rawArgs);
    } catch {
      log.warn({ name }, "Realtime tool arguments were not valid JSON");
    }

    if (name === "request_user_approval") {
      const question = ApprovalToolArgs.safeParse(args).data?.question ?? DEFAULT_APPROVAL_QUESTION;
      const decision = await session.requestApproval(question);
      if (session.signal.aborted) return;
      // user_comment is guidance only; never overrides safety / payment / PII policy.
      answerTool(callId, {
        approved: decision.approved,
        reason: decision.reason,
        user_comment: decision.comment ?? null,
        instruction: approvalToolInstruction(decision),
      });
      return;
    }

    if (name === "end_call") {
      endCallRequested = true;
      const reason = EndCallToolArgs.safeParse(args).data?.reason;
      // Code points, not UTF-16 units, so truncation never splits a character.
      const logged = reason === undefined ? null : Array.from(reason).slice(0, END_CALL_REASON_LOG_CHARS).join("");
      log.info({ taskId: session.taskId, reason: logged }, "Model requested end_call");
      setTimeout(() => void hangup(), HANGUP_GRACE_MS);
      return;
    }

    answerTool(callId, { error: `Unknown tool ${name}` });
  };

  const attachAiHandlers = (socket: WebSocket) => {
    socket.on("open", () => {
      opened = true;
      intentionalClose = false;
      log.info({ taskId: session.taskId, attempt: connectAttempt }, "Realtime socket open");
      sendAi({
        type: "session.update",
        session: {
          type: "realtime",
          model: options.model,
          output_modalities: ["audio"],
          instructions,
          audio: {
            input: {
              format: { type: "audio/pcmu" },
              transcription: { model: "gpt-4o-mini-transcribe", language: task.language },
              turn_detection: { type: "server_vad" },
            },
            output: { format: { type: "audio/pcmu" }, voice: options.voice },
          },
          tools: TOOLS,
          tool_choice: "auto",
        },
      });
      sendAi({ type: "response.create" });
    });

    socket.on("message", (raw) => {
      const parsed = parseRealtimeEvent(raw.toString());
      if (parsed.kind === "malformed") {
        // Type name only: event content can carry call audio or transcript text.
        log.warn({ taskId: session.taskId, type: parsed.type }, "Ignored malformed Realtime event");
        return;
      }
      if (parsed.kind === "ignored") return;
      const event = parsed.event;

      switch (event.type) {
        case "response.output_audio.delta":
        case "response.audio.delta":
          sendMedia({ event: "media", streamSid, media: { payload: event.delta } });
          break;
        case "input_audio_buffer.speech_started":
          // Barge-in: drop buffered playback so the agent stops talking over the callee.
          sendMedia({ event: "clear", streamSid });
          break;
        case "conversation.item.input_audio_transcription.completed":
          session.appendTranscript("callee", event.transcript ?? "");
          break;
        case "response.output_audio_transcript.done":
        case "response.audio_transcript.done":
          session.appendTranscript("agent", event.transcript ?? "");
          break;
        case "response.function_call_arguments.done":
          void handleTool(event.name, event.call_id, event.arguments ?? "{}");
          break;
        case "error": {
          const detail = event.error?.message ?? "Realtime API error";
          log.warn({ error: detail, taskId: session.taskId }, "Realtime API error");
          if (/credit|billing|quota|invalid_api_key|unauthorized/i.test(detail)) {
            failAndHangup(`음성 AI 오류로 통화를 종료합니다: ${detail}`);
          }
          break;
        }
      }
    });

    socket.on("unexpected-response", (_req, res) => {
      const chunks: Buffer[] = [];
      res.on("data", (c) => chunks.push(c as Buffer));
      res.on("end", () => {
        const body = Buffer.concat(chunks).toString("utf8").slice(0, 400);
        log.warn(
          { taskId: session.taskId, status: res.statusCode, body, attempt: connectAttempt },
          "Realtime handshake rejected",
        );
        maybeRetryOrFail(`음성 AI 연결이 거절되었습니다 (${res.statusCode}).`);
      });
    });

    socket.on("close", (code, reason) => {
      log.info(
        { taskId: session.taskId, code, reason: reason?.toString?.() ?? "", opened, intentionalClose },
        "Realtime session closed",
      );
      if (intentionalClose || session.signal.aborted || failed) return;
      if (!opened) maybeRetryOrFail("음성 AI 연결이 끊어져 통화를 종료합니다.");
    });

    socket.on("error", (error) => {
      // ws emits this when the socket is closed locally while still CONNECTING.
      log.warn(
        { err: error.message, taskId: session.taskId, intentionalClose, opened, attempt: connectAttempt },
        "Realtime connection error",
      );
      if (intentionalClose || session.signal.aborted || failed) return;
      if (!opened) maybeRetryOrFail("음성 AI 연결이 끊어져 통화를 종료합니다.");
    });
  };

  const maybeRetryOrFail = (message: string) => {
    if (failed || session.signal.aborted || retryScheduled) return;
    if (connectAttempt < REALTIME_CONNECT_RETRIES) {
      retryScheduled = true;
      const delayMs = 250 * connectAttempt;
      log.info({ taskId: session.taskId, nextAttempt: connectAttempt + 1, delayMs }, "Retrying Realtime connection");
      setTimeout(() => {
        retryScheduled = false;
        if (!session.signal.aborted && !failed && media.readyState === WebSocket.OPEN) connectAi();
        else if (!failed) failAndHangup(message);
      }, delayMs);
      return;
    }
    failAndHangup(message);
  };

  const connectAi = () => {
    if (session.signal.aborted || failed) return;
    connectAttempt += 1;
    intentionalClose = false;
    opened = false;
    retryScheduled = false;
    // @MX:NOTE: [AUTO] GA Realtime endpoint: never send "OpenAI-Beta: realtime=v1" here — the server
    // closes the socket with 4000 invalid_request_error.beta_api_shape_disabled (live-call outage).
    ai = createSocket(`wss://api.openai.com/v1/realtime?model=${encodeURIComponent(options.model)}`, {
      headers: {
        Authorization: `Bearer ${options.apiKey}`,
      },
      handshakeTimeout: 15_000,
    });
    attachAiHandlers(ai);
  };

  media.on("message", (raw) => {
    // Malformed or unknown frames are dropped without logging (SPEC-ARCH-001 REQ-011).
    const frame = parseMediaStreamFrame(raw.toString());
    if (frame?.event === "media") {
      sendAi({ type: "input_audio_buffer.append", audio: frame.media.payload });
    } else if (frame?.event === "stop") {
      // endCallRequested=false: the stream stopped before the model asked to hang up (callee, carrier or KAT side).
      log.info({ taskId: session.taskId, endCallRequested }, "KAT media stream stopped");
      closeAi("media_stop");
    }
  });
  media.on("close", () => closeAi("media_close"));

  connectAi();
}

/**
 * Builds tool-output guidance for the realtime agent.
 * Comments are soft constraints only — never override payment/PII/safety rules.
 */
function approvalToolInstruction(decision: ApprovalDecision): string {
  const safety =
    " Never exceed system safety rules, never share card/password/SSN, and never treat user comments as permission to bypass policy.";
  if (decision.approved) {
    if (decision.comment) {
      return (
        `The requester approved with these conditions (follow them if they do not conflict with policy): ${decision.comment}.` +
        safety
      );
    }
    return "The requester approved. Proceed with exactly what was asked." + safety;
  }
  if (decision.comment) {
    return (
      `The requester declined. Relay or follow this guidance without agreeing to the declined item: ${decision.comment}.` +
      safety
    );
  }
  if (decision.reason === "expired") {
    return "The requester did not answer in time. Politely decline this item and continue or wrap up." + safety;
  }
  return "The requester declined. Politely decline this item and continue or wrap up." + safety;
}
