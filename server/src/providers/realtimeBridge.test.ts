import { EventEmitter } from "node:events";
import { afterEach, describe, expect, it, vi } from "vitest";
import WebSocket from "ws";
import type { ApprovalDecision, CallTask } from "../domain/types.js";
import { bridgeToRealtime } from "./realtimeBridge.js";
import type { CallSession } from "./types.js";

/** Just enough of a `ws` socket for the bridge: readyState, send, close and events. */
class FakeSocket extends EventEmitter {
  readyState: number = WebSocket.CONNECTING;
  readonly sent: Record<string, unknown>[] = [];
  readonly close = vi.fn(() => {
    this.readyState = WebSocket.CLOSED;
  });

  send(data: string) {
    this.sent.push(JSON.parse(data) as Record<string, unknown>);
  }

  open() {
    this.readyState = WebSocket.OPEN;
    this.emit("open");
  }

  receive(event: unknown) {
    this.emit("message", Buffer.from(typeof event === "string" ? event : JSON.stringify(event)));
  }

  /** What `ws` emits when the server answers the upgrade with a non-101 status. */
  reject(statusCode: number, body: string) {
    const res = Object.assign(new EventEmitter(), { statusCode });
    this.emit("unexpected-response", {}, res);
    res.emit("data", Buffer.from(body));
    res.emit("end");
  }
}

const INSTRUCTIONS = "INSTRUCTIONS-FROM-THE-SESSION-7f3a";

function setup(decision: ApprovalDecision = { approved: true, reason: "user_approved" }) {
  const controller = new AbortController();
  const task = { id: "t-1", language: "ko" } as CallTask;
  const session = {
    taskId: "t-1",
    task: () => task,
    agentInstructions: vi.fn(() => INSTRUCTIONS),
    signal: controller.signal,
    markRinging: vi.fn(),
    markConnected: vi.fn(),
    appendTranscript: vi.fn(),
    requestApproval: vi.fn(async () => decision),
    recordProviderCallId: vi.fn(),
    // Like CallService.endSession: ending a session aborts its signal.
    end: vi.fn(() => controller.abort()),
  } satisfies CallSession;

  const warns: { obj: object; msg: string }[] = [];
  const log = { info: () => {}, warn: (obj: object, msg: string) => warns.push({ obj, msg }) };
  const media = new FakeSocket();
  media.readyState = WebSocket.OPEN;
  const sockets: FakeSocket[] = [];
  const urls: string[] = [];
  const hangup = vi.fn(async () => {});

  bridgeToRealtime({
    media: media as unknown as WebSocket,
    streamSid: "s-1",
    session,
    options: { apiKey: "sk-test", model: "gpt-realtime", voice: "marin" },
    hangup,
    log,
    createSocket: (url) => {
      const socket = new FakeSocket();
      sockets.push(socket);
      urls.push(url);
      return socket as unknown as WebSocket;
    },
  });

  const ai = () => sockets[sockets.length - 1]!;
  return { session, media, sockets, urls, ai, hangup, warns };
}

/** Lets the bridge's async tool handling settle. */
const flush = () => new Promise((resolve) => setImmediate(resolve));

afterEach(() => {
  vi.useRealTimers();
});

describe("bridgeToRealtime (SPEC-ARCH-001 AC-015)", () => {
  // (a) + AC-007
  it("sends session-provided instructions, audio formats and tools when the AI socket opens", () => {
    const { ai, session, urls } = setup();
    expect(urls).toEqual(["wss://api.openai.com/v1/realtime?model=gpt-realtime"]);

    ai().open();

    const [update, create] = ai().sent as [Record<string, any>, Record<string, unknown>];
    expect(update.type).toBe("session.update");
    expect(update.session.instructions).toBe(INSTRUCTIONS);
    expect(session.agentInstructions).toHaveBeenCalledTimes(1);
    expect(update.session.audio.input.format).toEqual({ type: "audio/pcmu" });
    expect(update.session.audio.input.transcription).toEqual({ model: "gpt-4o-mini-transcribe", language: "ko" });
    expect(update.session.audio.output).toEqual({ format: { type: "audio/pcmu" }, voice: "marin" });
    expect(update.session.tools.map((tool: { name: string }) => tool.name)).toEqual(["request_user_approval", "end_call"]);
    expect(create).toEqual({ type: "response.create" });
  });

  // (b)
  it("forwards audio both ways", () => {
    const { ai, media } = setup();
    ai().open();
    ai().sent.length = 0;

    media.receive({ event: "media", streamSid: "s-1", media: { payload: "KAT-AUDIO" } });
    expect(ai().sent).toEqual([{ type: "input_audio_buffer.append", audio: "KAT-AUDIO" }]);

    ai().receive({ type: "response.output_audio.delta", delta: "AI-AUDIO-1" });
    ai().receive({ type: "response.audio.delta", delta: "AI-AUDIO-2" });
    expect(media.sent).toEqual([
      { event: "media", streamSid: "s-1", media: { payload: "AI-AUDIO-1" } },
      { event: "media", streamSid: "s-1", media: { payload: "AI-AUDIO-2" } },
    ]);
  });

  // (c)
  it("clears KAT playback when the callee starts speaking", () => {
    const { ai, media } = setup();
    ai().open();
    ai().receive({ type: "input_audio_buffer.speech_started" });
    expect(media.sent).toEqual([{ event: "clear", streamSid: "s-1" }]);
  });

  // (d)
  it("records callee and agent transcripts", () => {
    const { ai, session } = setup();
    ai().open();
    ai().receive({ type: "conversation.item.input_audio_transcription.completed", transcript: "네, 라 파스타입니다." });
    ai().receive({ type: "response.output_audio_transcript.done", transcript: "7시 예약 되나요?" });
    ai().receive({ type: "response.audio_transcript.done", transcript: "감사합니다." });
    expect(session.appendTranscript.mock.calls).toEqual([
      ["callee", "네, 라 파스타입니다."],
      ["agent", "7시 예약 되나요?"],
      ["agent", "감사합니다."],
    ]);
  });

  // (e)
  it("turns the approval tool into a user approval and returns the decision as tool output", async () => {
    const { ai, session } = setup({ approved: true, comment: "1만 원까지만", reason: "user_approved" });
    ai().open();
    ai().sent.length = 0;

    ai().receive({
      type: "response.function_call_arguments.done",
      name: "request_user_approval",
      call_id: "call-1",
      arguments: JSON.stringify({ question: "예약금 1만 원을 결제할까요?" }),
    });
    await flush();

    expect(session.requestApproval).toHaveBeenCalledWith("예약금 1만 원을 결제할까요?");
    const [item, create] = ai().sent as [Record<string, any>, Record<string, unknown>];
    expect(item.type).toBe("conversation.item.create");
    expect(item.item.type).toBe("function_call_output");
    expect(item.item.call_id).toBe("call-1");
    expect(JSON.parse(item.item.output as string)).toEqual({
      approved: true,
      reason: "user_approved",
      user_comment: "1만 원까지만",
      instruction: expect.stringContaining("approved with these conditions"),
    });
    expect(create).toEqual({ type: "response.create" });
  });

  // (f)
  it("hangs up 2,500 ms after the end_call tool", async () => {
    vi.useFakeTimers();
    const { ai, hangup } = setup();
    ai().open();
    ai().receive({ type: "response.function_call_arguments.done", name: "end_call", call_id: "call-2", arguments: '{"reason":"done"}' });

    await vi.advanceTimersByTimeAsync(2499);
    expect(hangup).not.toHaveBeenCalled();
    await vi.advanceTimersByTimeAsync(1);
    expect(hangup).toHaveBeenCalledTimes(1);
  });

  // (g)
  it("fails the session and hangs up on billing or auth errors", () => {
    const { ai, session, hangup } = setup();
    ai().open();
    ai().receive({ type: "error", error: { message: "You exceeded your current quota, check billing" } });

    const message = "음성 AI 오류로 통화를 종료합니다: You exceeded your current quota, check billing";
    expect(session.appendTranscript).toHaveBeenCalledWith("system", message);
    expect(session.end).toHaveBeenCalledWith({ error: message });
    expect(hangup).toHaveBeenCalledTimes(1);
  });

  // (h)
  it("reconnects once after a rejected handshake and fails on the second rejection", async () => {
    vi.useFakeTimers();
    const { sockets, session, hangup, warns } = setup();
    const body = "x".repeat(450);

    sockets[0]!.reject(401, body);
    expect(sockets).toHaveLength(1);
    await vi.advanceTimersByTimeAsync(250);
    expect(sockets).toHaveLength(2);
    expect(session.end).not.toHaveBeenCalled();

    sockets[1]!.reject(401, body);
    await vi.advanceTimersByTimeAsync(10_000);

    expect(sockets).toHaveLength(2);
    expect(session.end).toHaveBeenCalledWith({ error: "음성 AI 연결이 거절되었습니다 (401)." });
    expect(hangup).toHaveBeenCalledTimes(1);
    const rejected = warns.filter((w) => w.msg === "Realtime handshake rejected");
    expect(rejected.map((w) => w.obj)).toEqual([
      { taskId: "t-1", status: 401, body: "x".repeat(400), attempt: 1 },
      { taskId: "t-1", status: 401, body: "x".repeat(400), attempt: 2 },
    ]);
  });

  // (i)
  it("closes the AI socket on a KAT stop frame", () => {
    const { ai, media } = setup();
    ai().open();
    media.receive({ event: "stop", streamSid: "s-1" });
    expect(ai().close).toHaveBeenCalledTimes(1);
  });
});

describe("bridgeToRealtime input validation (SPEC-ARCH-001 AC-011)", () => {
  it("validates handled realtime events and ignores the rest", async () => {
    const { ai, media, session, warns } = setup();
    ai().open();
    ai().sent.length = 0;

    // (1) audio delta without delta: nothing reaches KAT
    ai().receive({ type: "response.output_audio.delta" });
    expect(media.sent).toEqual([]);
    expect(warns).toHaveLength(1);

    // (2) transcript that is not a string: nothing is recorded
    ai().receive({ type: "conversation.item.input_audio_transcription.completed", transcript: 123 });
    expect(session.appendTranscript).not.toHaveBeenCalled();
    expect(warns).toHaveLength(2);

    // (3) function call without a name: no tool handling
    ai().receive({ type: "response.function_call_arguments.done", call_id: "call-3", arguments: "{}" });
    await flush();
    expect(ai().sent).toEqual([]);
    expect(session.requestApproval).not.toHaveBeenCalled();
    expect(warns).toHaveLength(3);

    // Warnings name the event type only, never its content.
    expect(warns.map((w) => w.obj)).toEqual([
      { taskId: "t-1", type: "response.output_audio.delta" },
      { taskId: "t-1", type: "conversation.item.input_audio_transcription.completed" },
      { taskId: "t-1", type: "response.function_call_arguments.done" },
    ]);

    // (4) an event type the bridge does not handle stays silent
    ai().receive({ type: "session.created", session: { id: "sess-1" } });
    ai().receive("not json");
    expect(warns).toHaveLength(3);

    // (5) approval arguments without a question fall back to the default question
    ai().receive({ type: "response.function_call_arguments.done", name: "request_user_approval", call_id: "call-4", arguments: "{}" });
    await flush();
    expect(session.requestApproval).toHaveBeenCalledWith("진행해도 될까요?");
    expect(warns).toHaveLength(3);
  });

  it("ignores malformed KAT media frames without logging", () => {
    const { ai, media, warns } = setup();
    ai().open();
    ai().sent.length = 0;

    media.receive("not json");
    media.receive({ event: "media" });
    media.receive({ event: "media", media: { payload: 42 } });
    media.receive({ event: "media", media: { payload: "" } });

    expect(ai().sent).toEqual([]);
    expect(ai().close).not.toHaveBeenCalled();
    expect(warns).toEqual([]);
  });
});
