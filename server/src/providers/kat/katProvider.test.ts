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
