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
