import WebSocket from "ws";
import { buildAgentInstructions } from "../../brain/prompts.js";
import type { CallSession } from "../types.js";

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

/**
 * Connects one Twilio Media Stream (8 kHz μ-law) to one OpenAI Realtime
 * session. Both sides speak μ-law, so audio is forwarded without transcoding.
 */
export function bridgeToRealtime(params: {
  twilio: WebSocket;
  streamSid: string;
  session: CallSession;
  options: RealtimeOptions;
  hangup: () => Promise<void>;
  log: Logger;
}): void {
  const { twilio, streamSid, session, options, hangup, log } = params;
  const task = session.task();

  const ai = new WebSocket(`wss://api.openai.com/v1/realtime?model=${encodeURIComponent(options.model)}`, {
    headers: { Authorization: `Bearer ${options.apiKey}` },
  });

  const sendAi = (event: object) => {
    if (ai.readyState === WebSocket.OPEN) ai.send(JSON.stringify(event));
  };
  const sendTwilio = (event: object) => {
    if (twilio.readyState === WebSocket.OPEN) twilio.send(JSON.stringify(event));
  };
  const close = () => {
    if (ai.readyState === WebSocket.OPEN || ai.readyState === WebSocket.CONNECTING) ai.close();
  };
  session.signal.addEventListener("abort", close, { once: true });

  ai.on("open", () => {
    sendAi({
      type: "session.update",
      session: {
        type: "realtime",
        model: options.model,
        output_modalities: ["audio"],
        instructions: buildAgentInstructions(task),
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

  const answerTool = (callId: string, output: object) => {
    sendAi({ type: "conversation.item.create", item: { type: "function_call_output", call_id: callId, output: JSON.stringify(output) } });
    sendAi({ type: "response.create" });
  };

  const handleTool = async (name: string, callId: string, rawArgs: string) => {
    let args: Record<string, unknown> = {};
    try {
      args = JSON.parse(rawArgs) as Record<string, unknown>;
    } catch {
      log.warn({ name }, "Realtime tool arguments were not valid JSON");
    }

    if (name === "request_user_approval") {
      const question = typeof args.question === "string" ? args.question : "진행해도 될까요?";
      const approved = await session.requestApproval(question);
      if (session.signal.aborted) return;
      answerTool(callId, {
        approved,
        instruction: approved
          ? "The requester approved. Proceed with exactly what was asked."
          : "The requester declined or did not answer. Politely decline this item and continue or wrap up.",
      });
      return;
    }

    if (name === "end_call") {
      setTimeout(() => void hangup(), HANGUP_GRACE_MS);
      return;
    }

    answerTool(callId, { error: `Unknown tool ${name}` });
  };

  ai.on("message", (raw) => {
    let event: Record<string, any>;
    try {
      event = JSON.parse(raw.toString());
    } catch {
      return;
    }

    switch (event.type) {
      case "response.output_audio.delta":
      case "response.audio.delta":
        sendTwilio({ event: "media", streamSid, media: { payload: event.delta } });
        break;
      case "input_audio_buffer.speech_started":
        // Barge-in: drop audio Twilio has buffered so the agent stops talking over the callee.
        sendTwilio({ event: "clear", streamSid });
        break;
      case "conversation.item.input_audio_transcription.completed":
        session.appendTranscript("callee", String(event.transcript ?? ""));
        break;
      case "response.output_audio_transcript.done":
      case "response.audio_transcript.done":
        session.appendTranscript("agent", String(event.transcript ?? ""));
        break;
      case "response.function_call_arguments.done":
        void handleTool(String(event.name), String(event.call_id), String(event.arguments ?? "{}"));
        break;
      case "error":
        log.warn({ error: event.error?.message, taskId: session.taskId }, "Realtime API error");
        break;
    }
  });

  ai.on("close", () => log.info({ taskId: session.taskId }, "Realtime session closed"));
  ai.on("error", (error) => {
    log.warn({ err: error.message, taskId: session.taskId }, "Realtime connection failed");
    session.appendTranscript("system", "음성 AI 연결이 끊어져 통화를 종료합니다.");
    void hangup();
  });

  twilio.on("message", (raw) => {
    let event: Record<string, any>;
    try {
      event = JSON.parse(raw.toString());
    } catch {
      return;
    }
    if (event.event === "media" && event.media?.payload) {
      sendAi({ type: "input_audio_buffer.append", audio: event.media.payload });
    } else if (event.event === "stop") {
      close();
    }
  });
  twilio.on("close", close);
}
