import { createHmac } from "node:crypto";
import { EventEmitter } from "node:events";
import type { IncomingMessage } from "node:http";
import { afterEach, describe, expect, it, vi } from "vitest";
import type WebSocket from "ws";
import type { CallTask } from "../../domain/types.js";
import type { CallSession } from "../types.js";
import { KatCallProvider, type KatOptions, toKatPhoneNumber } from "./katProvider.js";
import { verifyKatHttpSignature, verifyKatStreamSignature } from "./webhook.js";

const SECRET = "whsec_" + "cd".repeat(32);

interface FetchCall {
  url: string;
  init: RequestInit;
  body: Record<string, unknown> | undefined;
}

/** Records every request; `respond` decides the reply (return a Response, or a never-settling promise). */
function fakeFetch(respond: (call: FetchCall) => Promise<Response> | Response) {
  const calls: FetchCall[] = [];
  const fn = (async (input: string | URL | Request, init: RequestInit = {}) => {
    const call: FetchCall = {
      url: String(input),
      init,
      body: typeof init.body === "string" ? (JSON.parse(init.body) as Record<string, unknown>) : undefined,
    };
    calls.push(call);
    return respond(call);
  }) as typeof fetch;
  return { fn, calls };
}

const json = (payload: unknown, status = 200) =>
  new Response(JSON.stringify(payload), { status, headers: { "content-type": "application/json" } });

/** Never answers on its own; rejects with AbortError once the request's signal aborts. */
const hangUntilAborted = (call: FetchCall) =>
  new Promise<Response>((_, reject) => {
    const signal = call.init.signal;
    if (!signal) return; // no signal: hangs forever
    signal.addEventListener("abort", () => reject(new DOMException("The operation was aborted.", "AbortError")), {
      once: true,
    });
  });

function recordingLog() {
  const warns: { obj: object; msg: string }[] = [];
  return {
    warns,
    log: { info: () => {}, warn: (obj: object, msg: string) => warns.push({ obj, msg }) },
  };
}

function katOptions(fetchFn: typeof fetch, overrides: Partial<KatOptions> = {}): KatOptions {
  return {
    apiKey: "key",
    groupId: "g-1",
    fromNumber: "07012345678",
    webhookSecret: SECRET,
    publicBaseUrl: "https://example.test",
    apiBaseUrl: "https://kat.test/v1",
    realtime: { apiKey: "sk", model: "m", voice: "v" },
    fetch: fetchFn,
    maxCallDurationSec: 600,
    ...overrides,
  } as KatOptions;
}

function fakeSession(taskId = "t-1") {
  const controller = new AbortController();
  const task = {
    id: taskId,
    phoneNumber: "+821012345678",
    status: "dialing",
  } as CallTask;
  const recorded: string[] = [];
  const session = {
    taskId,
    task: () => task,
    signal: controller.signal,
    markRinging: vi.fn(),
    markConnected: vi.fn(),
    appendTranscript: vi.fn(),
    requestApproval: vi.fn(),
    end: vi.fn(),
    recordProviderCallId: (id: string) => recorded.push(id),
  } as unknown as CallSession;
  return { session, recorded, controller };
}

afterEach(() => {
  vi.useRealTimers();
});

describe("KatCallProvider call id (AC-006)", () => {
  it("reports the KAT callId to the session", async () => {
    const { fn } = fakeFetch(() => json({ code: 0, result: { callId: "c-1" } }));
    const kat = new KatCallProvider(katOptions(fn), recordingLog().log);
    const { session, recorded } = fakeSession();

    await kat.start(session);

    expect(recorded).toEqual(["c-1"]);
  });
});

describe("toKatPhoneNumber", () => {
  it("converts E.164 Korea numbers to domestic form", () => {
    expect(toKatPhoneNumber("+821090932936")).toBe("01090932936");
    expect(toKatPhoneNumber("+827012345678")).toBe("07012345678");
  });

  it("strips punctuation from local numbers", () => {
    expect(toKatPhoneNumber("010-9093-2936")).toBe("01090932936");
  });
});

describe("KAT webhook signatures", () => {
  const secret = "whsec_" + "ab".repeat(32);

  it("accepts a valid HTTP webhook signature", () => {
    const timestamp = String(Math.floor(Date.now() / 1000));
    const rawBody = '{"eventType":"MEDIA_STREAM"}';
    const signature =
      "v1=" + createHmac("sha256", secret).update(`${timestamp}.`).update(rawBody).digest("hex");
    expect(
      verifyKatHttpSignature({ secret, timestamp, signature, rawBody }),
    ).toBe(true);
  });

  it("rejects a tampered HTTP body", () => {
    const timestamp = String(Math.floor(Date.now() / 1000));
    const signature =
      "v1=" + createHmac("sha256", secret).update(`${timestamp}.`).update("good").digest("hex");
    expect(
      verifyKatHttpSignature({ secret, timestamp, signature, rawBody: "bad" }),
    ).toBe(false);
  });

  it("accepts a valid media-stream upgrade signature", () => {
    const timestamp = String(Math.floor(Date.now() / 1000));
    const callId = "call-1";
    const streamId = "MZ" + "a".repeat(32);
    const signature =
      "v1=" + createHmac("sha256", secret).update(`${timestamp}.${callId}.${streamId}`).digest("hex");
    expect(
      verifyKatStreamSignature({ secret, timestamp, signature, callId, streamId }),
    ).toBe(true);
  });
});

describe("KatCallProvider request timeout (AC-010 ~ AC-012)", () => {
  it(
    "every KAT request carries an abort signal and times out",
    { timeout: 2000 },
    async () => {
      // Call creation: KAT never answers.
      const create = fakeFetch(hangUntilAborted);
      const katA = new KatCallProvider(katOptions(create.fn, { requestTimeoutMs: 50 }), recordingLog().log);
      let startedAt = Date.now();
      await expect(katA.start(fakeSession("t-a").session)).rejects.toThrow();
      expect(Date.now() - startedAt).toBeLessThan(550);
      expect(create.calls).toHaveLength(1);
      expect(create.calls[0]!.init.signal).toBeInstanceOf(AbortSignal);
      expect(create.calls[0]!.init.signal!.aborted).toBe(true);

      // Call termination: creation answers, the termination request never does.
      const terminate = fakeFetch((call) =>
        call.url.endsWith("/termination") ? hangUntilAborted(call) : json({ result: { callId: "c-1" } }),
      );
      const katB = new KatCallProvider(katOptions(terminate.fn, { requestTimeoutMs: 50 }), recordingLog().log);
      await katB.start(fakeSession("t-b").session);
      startedAt = Date.now();
      await katB.hangup("t-b");
      expect(Date.now() - startedAt).toBeLessThan(550);
      const termination = terminate.calls.find((c) => c.url.endsWith("/media-stream/calls/c-1/termination"));
      expect(termination?.init.signal).toBeInstanceOf(AbortSignal);
      expect(termination?.init.signal?.aborted).toBe(true);
      expect(terminate.calls.every((c) => c.init.signal instanceof AbortSignal)).toBe(true);
    },
  );

  it(
    "maps a KAT timeout to a readable Korean error",
    { timeout: 2000 },
    async () => {
      const { fn } = fakeFetch(hangUntilAborted);
      const kat = new KatCallProvider(katOptions(fn, { requestTimeoutMs: 50 }), recordingLog().log);
      await expect(kat.start(fakeSession().session)).rejects.toThrow("KAT Cloud가 응답하지 않아 전화를 걸지 못했습니다.");
    },
  );

  it.each([
    { name: "timeout", respond: hangUntilAborted },
    { name: "HTTP 500", respond: () => json({ message: "boom" }, 500) },
  ])(
    "hangup never throws on timeout or error ($name)",
    { timeout: 2000 },
    async ({ respond }) => {
      const { fn } = fakeFetch((call) =>
        call.url.endsWith("/termination") ? respond(call) : json({ result: { callId: "c-1" } }),
      );
      const { log, warns } = recordingLog();
      const kat = new KatCallProvider(katOptions(fn, { requestTimeoutMs: 50 }), log);
      await kat.start(fakeSession().session);

      await expect(kat.hangup("t-1")).resolves.toBeUndefined();
      expect(warns).toHaveLength(1);
    },
  );
});

describe("KatCallProvider terminate by call id (AC-007 support)", () => {
  it("terminates a call it has no session for, without throwing on failure", async () => {
    const { fn, calls } = fakeFetch(() => json({ message: "gone" }, 404));
    const { log, warns } = recordingLog();
    const kat = new KatCallProvider(katOptions(fn), log);

    await expect(kat.terminateByProviderCallId("c-2")).resolves.toBeUndefined();

    expect(calls.map((c) => c.url)).toEqual(["https://kat.test/v1/group/g-1/media-stream/calls/c-2/termination"]);
    expect(warns).toHaveLength(1);
  });
});

describe("KatCallProvider orphan media streams (AC-014)", () => {
  class FakeSocket extends EventEmitter {
    readonly close = vi.fn();
  }

  function upgradeRequest(options: { callId?: string; valid?: boolean } = {}) {
    const timestamp = String(Math.floor(Date.now() / 1000));
    const streamId = "MZ" + "b".repeat(32);
    const callId = options.callId ?? "";
    const signature =
      "v1=" +
      createHmac("sha256", options.valid === false ? "wrong-secret" : SECRET)
        .update(`${timestamp}.${callId}.${streamId}`)
        .digest("hex");
    const headers: Record<string, string> = {
      "x-webhook-timestamp": timestamp,
      "x-webhook-signature": signature,
      "x-kat-stream-id": streamId,
    };
    if (options.callId) headers["x-kat-call-id"] = options.callId;
    return { headers } as unknown as IncomingMessage;
  }

  function provider() {
    const fetch = fakeFetch(() => json({ result: { callId: "c-1" } }));
    const kat = new KatCallProvider(katOptions(fetch.fn), recordingLog().log);
    const terminations = () => fetch.calls.filter((c) => c.url.endsWith("/termination")).map((c) => c.url);
    return { kat, fetch, terminations };
  }

  const TERMINATE = (callId: string) => `https://kat.test/v1/group/g-1/media-stream/calls/${callId}/termination`;

  it("terminates signed media streams that have no active session (a: header call id, non-JSON first frame)", async () => {
    vi.useFakeTimers();
    const { kat, terminations } = provider();
    const socket = new FakeSocket();

    kat.attachMediaStream(socket as unknown as WebSocket, upgradeRequest({ callId: "c-9" }));
    socket.emit("message", Buffer.from("this is not json"));
    await vi.advanceTimersByTimeAsync(0);

    expect(terminations()).toEqual([TERMINATE("c-9")]);
    expect(socket.close).toHaveBeenCalled();

    await vi.advanceTimersByTimeAsync(10_000);
    expect(terminations()).toHaveLength(1);
  });

  it("terminates signed media streams that have no active session (b: header call id, no frame for 10 s)", async () => {
    vi.useFakeTimers();
    const { kat, terminations } = provider();
    const socket = new FakeSocket();

    kat.attachMediaStream(socket as unknown as WebSocket, upgradeRequest({ callId: "c-9" }));
    await vi.advanceTimersByTimeAsync(9999);
    expect(terminations()).toEqual([]);
    expect(socket.close).not.toHaveBeenCalled();

    await vi.advanceTimersByTimeAsync(1);
    expect(terminations()).toEqual([TERMINATE("c-9")]);
    expect(socket.close).toHaveBeenCalled();
  });

  it("terminates signed media streams that have no active session (c: no header call id, start frame call id)", async () => {
    vi.useFakeTimers();
    const { kat, terminations } = provider();
    // The real upgrade verifier requires x-kat-call-id, so a signed upgrade without it cannot be built;
    // stub the (separately tested) signature check to reach the start-frame path.
    vi.spyOn(kat, "isValidStreamUpgrade").mockReturnValue(true);
    const socket = new FakeSocket();

    kat.attachMediaStream(socket as unknown as WebSocket, upgradeRequest());
    socket.emit(
      "message",
      Buffer.from(JSON.stringify({ event: "start", start: { streamSid: "s-1", callId: "c-8" } })),
    );
    await vi.advanceTimersByTimeAsync(0);

    expect(terminations()).toEqual([TERMINATE("c-8")]);
    expect(socket.close).toHaveBeenCalled();
  });

  it("terminates signed media streams that have no active session (d: invalid signature)", async () => {
    vi.useFakeTimers();
    const { kat, terminations } = provider();
    const socket = new FakeSocket();

    kat.attachMediaStream(socket as unknown as WebSocket, upgradeRequest({ callId: "c-9", valid: false }));
    socket.emit("message", Buffer.from("this is not json"));
    await vi.advanceTimersByTimeAsync(10_000);

    expect(terminations()).toEqual([]);
    expect(socket.close).toHaveBeenCalled();
  });

  it("keeps a stream whose header call id belongs to an active session", async () => {
    vi.useFakeTimers();
    const { kat, terminations } = provider();
    await kat.start(fakeSession("t-1").session); // registers callId c-1
    const socket = new FakeSocket();

    kat.attachMediaStream(socket as unknown as WebSocket, upgradeRequest({ callId: "c-1" }));
    socket.emit("message", Buffer.from("this is not json"));
    await vi.advanceTimersByTimeAsync(0);

    expect(terminations()).toEqual([]);
    expect(socket.close).not.toHaveBeenCalled();
  });
});

describe("KatCallProvider timeLimit (AC-013)", () => {
  const timeLimitFor = async (maxCallDurationSec: number) => {
    const { fn, calls } = fakeFetch(() => json({ result: { callId: "c-1" } }));
    const kat = new KatCallProvider(katOptions(fn, { maxCallDurationSec }), recordingLog().log);
    await kat.start(fakeSession().session);
    return calls[0]!.body?.timeLimit;
  };

  it.each([
    [600, 630],
    [5, 35],
    [1, 31],
    [20_000, 14_400],
  ])("derives timeLimit from MAX_CALL_DURATION_SEC (%i s -> %i)", async (seconds, expected) => {
    expect(await timeLimitFor(seconds)).toBe(expected);
  });

  it("clamps an injected duration below the floor to 10", async () => {
    expect(await timeLimitFor(-25)).toBe(10);
  });
});

// ---------------------------------------------------------------------------
// SPEC-ARCH-001: status webhooks, media streams and API responses
// ---------------------------------------------------------------------------

class MediaSocket extends EventEmitter {
  readonly close = vi.fn();
}

function signedUpgrade(options: { callId?: string; valid?: boolean } = {}) {
  const timestamp = String(Math.floor(Date.now() / 1000));
  const streamId = "MZ" + "c".repeat(32);
  const callId = options.callId ?? "";
  const signature =
    "v1=" +
    createHmac("sha256", options.valid === false ? "wrong-secret" : SECRET)
      .update(`${timestamp}.${callId}.${streamId}`)
      .digest("hex");
  const headers: Record<string, string> = {
    "x-webhook-timestamp": timestamp,
    "x-webhook-signature": signature,
    "x-kat-stream-id": streamId,
  };
  if (options.callId) headers["x-kat-call-id"] = options.callId;
  return { headers } as unknown as IncomingMessage;
}

const frame = (payload: unknown) => Buffer.from(typeof payload === "string" ? payload : JSON.stringify(payload));
const flush = () => new Promise((resolve) => setImmediate(resolve));

/** A KAT provider with one active call (task t-1, KAT callId c-1) and the Realtime bridge intercepted. */
async function activeCall() {
  const fetch = fakeFetch(() => json({ result: { callId: "c-1" } }));
  const bridge = vi.fn();
  const { log, warns } = recordingLog();
  const kat = new KatCallProvider(katOptions(fetch.fn, { bridge }), log);
  const { session } = fakeSession("t-1");
  await kat.start(session);
  const terminations = () => fetch.calls.filter((c) => c.url.endsWith("/termination")).map((c) => c.url);
  /** Session methods a webhook or media frame could have triggered. */
  const sessionCalls = () =>
    [session.markRinging, session.markConnected, session.end, session.appendTranscript].reduce(
      (count, fn) => count + vi.mocked(fn).mock.calls.length,
      0,
    );
  return { kat, session, bridge, warns, terminations, sessionCalls };
}

/** Bridges the active call's media stream, as a real answered call would. */
function bridgeMedia(kat: KatCallProvider) {
  const socket = new MediaSocket();
  kat.attachMediaStream(socket as unknown as WebSocket, signedUpgrade({ callId: "c-1" }));
  socket.emit("message", frame({ event: "start", start: { streamSid: "s-1" } }));
  return socket;
}

const MEDIA_FAILURE =
  "상대가 전화를 받았지만 음성 스트림이 연결되지 않아 통화가 종료되었습니다. PUBLIC_BASE_URL(터널)과 WSS(/kat/media)를 확인해 주세요.";

describe("KatCallProvider status webhooks (SPEC-ARCH-001 AC-016)", () => {
  it("(a) ringing marks the call ringing", async () => {
    const { kat, session } = await activeCall();
    kat.handleStatusWebhook({ data: { type: "media_stream.call.ringing", callId: "c-1" } });
    expect(session.markRinging).toHaveBeenCalledTimes(1);
  });

  it("(b) answered or in-progress marks the call connected", async () => {
    const first = await activeCall();
    first.kat.handleStatusWebhook({ data: { type: "media_stream.call.answered", callId: "c-1" } });
    expect(first.session.markConnected).toHaveBeenCalledTimes(1);

    const second = await activeCall();
    second.kat.handleStatusWebhook({ data: { status: "in-progress", metadata: { taskId: "t-1" } } });
    expect(second.session.markConnected).toHaveBeenCalledTimes(1);
  });

  it("(c) completed before any audio was bridged ends with the media failure message", async () => {
    const { kat, session } = await activeCall();
    kat.handleStatusWebhook({ data: { type: "media_stream.call.completed", callId: "c-1", status: "completed" } });
    expect(session.end).toHaveBeenCalledWith({ error: MEDIA_FAILURE });
  });

  it("(d) completed after audio was bridged ends without an error", async () => {
    const { kat, session } = await activeCall();
    bridgeMedia(kat);
    kat.handleStatusWebhook({ data: { type: "media_stream.call.completed", callId: "c-1", status: "completed" } });
    expect(session.end).toHaveBeenCalledTimes(1);
    expect(session.end).toHaveBeenCalledWith();
  });

  it.each([
    ["busy", "상대방이 통화 중입니다."],
    ["no-answer", "상대방이 전화를 받지 않았습니다."],
    ["rejected", "상대방이 전화를 거절했습니다."],
    ["canceled", "전화가 취소되었습니다."],
    ["failed", "전화 연결에 실패했습니다."],
  ])("(e) failure status %s ends with its message", async (status, message) => {
    const { kat, session } = await activeCall();
    bridgeMedia(kat);
    kat.handleStatusWebhook({ data: { type: "media_stream.call.failed", callId: "c-1", status } });
    expect(session.end).toHaveBeenCalledWith({ error: message });
  });

  it("(f) a webhook for an unknown task touches no session", async () => {
    const { kat, sessionCalls } = await activeCall();
    kat.handleStatusWebhook({
      data: { type: "media_stream.call.ringing", callId: "c-unknown", metadata: { taskId: "t-unknown" } },
    });
    expect(sessionCalls()).toBe(0);
  });
});

describe("KatCallProvider media streams (SPEC-ARCH-001 AC-017)", () => {
  it("(a) an invalid upgrade signature closes the socket without bridging", async () => {
    const { kat, bridge } = await activeCall();
    const socket = new MediaSocket();
    kat.attachMediaStream(socket as unknown as WebSocket, signedUpgrade({ callId: "c-1", valid: false }));
    socket.emit("message", frame({ event: "start", start: { streamSid: "s-1" } }));
    expect(socket.close).toHaveBeenCalled();
    expect(bridge).not.toHaveBeenCalled();
  });

  it("(b) a valid start frame marks the call connected and bridges it once", async () => {
    const { kat, session, bridge } = await activeCall();
    const socket = bridgeMedia(kat);
    expect(session.markConnected).toHaveBeenCalledTimes(1);
    expect(bridge).toHaveBeenCalledTimes(1);
    expect(bridge.mock.calls[0]![0]).toMatchObject({ media: socket, streamSid: "s-1", session });
    expect(socket.close).not.toHaveBeenCalled();
  });

  it("(c) a token mismatch without a call id closes, ends the session and terminates the call", async () => {
    const { kat, session, bridge, terminations } = await activeCall();
    // A signed upgrade without x-kat-call-id cannot be built (see AC-014 (c)); stub the separately tested check.
    vi.spyOn(kat, "isValidStreamUpgrade").mockReturnValue(true);
    const socket = new MediaSocket();
    kat.attachMediaStream(socket as unknown as WebSocket, signedUpgrade());
    socket.emit(
      "message",
      frame({ event: "start", start: { streamSid: "s-1", customParameters: { taskId: "t-1", token: "wrong" } } }),
    );
    await flush();
    expect(socket.close).toHaveBeenCalled();
    expect(session.end).toHaveBeenCalledWith({ error: "미디어 스트림 인증에 실패해 통화를 종료했습니다." });
    expect(terminations()).toEqual(["https://kat.test/v1/group/g-1/media-stream/calls/c-1/termination"]);
    expect(bridge).not.toHaveBeenCalled();
  });

  it("(d) with an active session, no start frame for 10 s closes the socket", async () => {
    vi.useFakeTimers();
    const { kat, terminations } = await activeCall();
    const socket = new MediaSocket();
    kat.attachMediaStream(socket as unknown as WebSocket, signedUpgrade({ callId: "c-1" }));
    await vi.advanceTimersByTimeAsync(9999);
    expect(socket.close).not.toHaveBeenCalled();
    await vi.advanceTimersByTimeAsync(1);
    expect(socket.close).toHaveBeenCalled();
    expect(terminations()).toEqual([]);
  });
});

describe("KatCallProvider API responses (SPEC-ARCH-001 AC-008)", () => {
  const CREATE = "KAT Cloud POST /group/g-1/media-stream/calls";
  const text = (body: string, status = 200) => new Response(body, { status });

  it.each([
    { name: "(1) top-level callId", reply: () => json({ callId: "c-1" }), callId: "c-1" },
    { name: "(2) callId inside result", reply: () => json({ code: 0, result: { callId: "c-2" } }), callId: "c-2" },
    { name: "(3) result without callId", reply: () => json({ result: {} }), error: "KAT Cloud did not return a callId" },
    { name: "(4) 200 with a non-JSON body", reply: () => text("not json"), error: "KAT Cloud did not return a callId" },
    { name: "(5) 500 with a message", reply: () => json({ message: "boom" }, 500), error: `${CREATE} failed (500): boom` },
    { name: "(6) 500 with an array body", reply: () => json([1, 2], 500), error: `${CREATE} failed (500): [1,2]` },
    { name: "(7) 500 with a null body", reply: () => text("null", 500), error: `${CREATE} failed (500): null` },
    { name: "(8) 200 with a null body", reply: () => text("null"), error: "KAT Cloud did not return a callId" },
  ])("parses KAT API responses safely $name", async ({ reply, callId, error }) => {
    const { fn } = fakeFetch(reply);
    const kat = new KatCallProvider(katOptions(fn), recordingLog().log);
    const { session, recorded } = fakeSession();

    if (callId) {
      await kat.start(session);
      expect(recorded).toEqual([callId]);
    } else {
      await expect(kat.start(session)).rejects.toThrow(new Error(error));
    }
  });
});

describe("KatCallProvider input validation (SPEC-ARCH-001 AC-009, AC-010)", () => {
  it("ignores malformed status webhooks", async () => {
    const { kat, warns, sessionCalls } = await activeCall();
    const payloads: unknown[] = [{ data: { type: 123 } }, { data: "x" }, [], { data: { type: 123, metadata: { taskId: "t-1" } } }];

    for (const payload of payloads) {
      kat.handleStatusWebhook(payload as Parameters<KatCallProvider["handleStatusWebhook"]>[0]);
    }

    expect(sessionCalls()).toBe(0);
    expect(warns.map((w) => w.msg)).toEqual(Array(4).fill("Ignored malformed KAT status webhook"));
    // Nothing from the body reaches the log.
    expect(warns.map((w) => w.obj)).toEqual([{}, {}, {}, {}]);
  });

  it("ignores malformed media frames and keeps waiting for start", async () => {
    const { kat, session, bridge, warns } = await activeCall();
    const socket = new MediaSocket();
    kat.attachMediaStream(socket as unknown as WebSocket, signedUpgrade({ callId: "c-1" }));

    socket.emit("message", frame({ event: "start", start: { streamSid: "s-1", customParameters: 5 } }));
    expect(session.markConnected).not.toHaveBeenCalled();
    expect(warns.map((w) => w.msg)).toEqual(["Ignored malformed media start frame"]);

    socket.emit("message", frame("not json"));
    socket.emit("message", frame({ event: "media", streamSid: "s-1" }));
    expect(warns).toHaveLength(1);

    socket.emit("message", frame({ event: "start", start: { streamSid: "s-1" } }));
    expect(session.markConnected).toHaveBeenCalledTimes(1);
    expect(bridge).toHaveBeenCalledTimes(1);
    expect(socket.close).not.toHaveBeenCalled();
  });

  it("still terminates a signed stream with no active session before looking at a malformed start frame", async () => {
    const { kat, bridge, terminations, warns } = await activeCall();
    const socket = new MediaSocket();
    kat.attachMediaStream(socket as unknown as WebSocket, signedUpgrade({ callId: "c-9" }));

    socket.emit("message", frame({ event: "start", start: { streamSid: "s-1", customParameters: 5 } }));
    await flush();

    expect(terminations()).toEqual(["https://kat.test/v1/group/g-1/media-stream/calls/c-9/termination"]);
    expect(socket.close).toHaveBeenCalled();
    expect(bridge).not.toHaveBeenCalled();
    expect(warns.map((w) => w.msg)).toEqual(["Hanging up a signed media stream with no active session"]);
  });
});
