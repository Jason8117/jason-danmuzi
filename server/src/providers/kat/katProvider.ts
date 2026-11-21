import { randomBytes, timingSafeEqual } from "node:crypto";
import type { IncomingMessage } from "node:http";
import type WebSocket from "ws";
import { maskPhoneNumber, toDomesticDialString } from "../../domain/phone.js";
import type { ProviderId } from "../../domain/types.js";
import type { CallProvider, CallSession, ProviderRoutes } from "../types.js";
import { type BridgeParams, bridgeToRealtime, type RealtimeOptions } from "../realtimeBridge.js";
import { ApiErrorBody, CreateCallResponse, parseJson, StartFrame, StatusWebhook } from "./schemas.js";
import { verifyKatHttpSignature, verifyKatStreamSignature } from "./webhook.js";

export const KAT_PROVIDER_ID = "kat" satisfies ProviderId;

/** Routes KAT calls back on; also sent to KAT as statusCallbackUrl / streamUrl when a call is created. */
const STATUS_PATH = "/kat/status";
const MEDIA_PATH = "/kat/media";

export interface KatOptions {
  apiKey: string;
  groupId: string;
  fromNumber: string;
  webhookSecret: string;
  publicBaseUrl: string;
  apiBaseUrl: string;
  realtime: RealtimeOptions;
  /** Injectable for tests; defaults to the global fetch. */
  fetch?: typeof fetch;
  /** Per-request deadline for every KAT API call. Default 10 s. */
  requestTimeoutMs?: number;
  /** Server-side call duration limit (MAX_CALL_DURATION_SEC); KAT's own timeLimit is derived from it. */
  maxCallDurationSec: number;
  /** Injectable for tests; defaults to the OpenAI Realtime bridge. */
  bridge?: (params: BridgeParams) => void;
}

export const DEFAULT_KAT_REQUEST_TIMEOUT_MS = 10_000;
/** KAT's timeLimit runs this much longer than the server's own duration timer, so the server ends the call first. */
const TIME_LIMIT_MARGIN_SEC = 30;
const TIME_LIMIT_MIN_SEC = 10;
const TIME_LIMIT_MAX_SEC = 14_400;
const KAT_TIMEOUT_START_ERROR = "KAT Cloud가 응답하지 않아 전화를 걸지 못했습니다.";

/** Thrown when a KAT request exceeds its deadline, so callers can tell "no answer" from "error answer". */
export class KatTimeoutError extends Error {
  constructor(method: string, path: string, timeoutMs: number) {
    super(`KAT Cloud ${method} ${path} did not respond within ${timeoutMs} ms`);
    this.name = "KatTimeoutError";
  }
}

/** Safety net if the server disappears mid-call: KAT ends the call on its own after this many seconds. */
// @MX:NOTE: [AUTO] clamp(MAX_CALL_DURATION_SEC + 30, 10, 14_400); the floor is unreachable from config (min 31) and only guards injected values.
// @MX:SPEC: SPEC-LIFECYCLE-001
export function katTimeLimitSec(maxCallDurationSec: number): number {
  return Math.max(TIME_LIMIT_MIN_SEC, Math.min(TIME_LIMIT_MAX_SEC, maxCallDurationSec + TIME_LIMIT_MARGIN_SEC));
}

interface Logger {
  info(obj: object, msg: string): void;
  warn(obj: object, msg: string): void;
}

interface ActiveCall {
  session: CallSession;
  streamToken: string;
  callId?: string;
  /** True once KAT media WebSocket was accepted and bridged to Realtime. */
  mediaBridged: boolean;
}

const FAILURE_MESSAGES: Record<string, string> = {
  busy: "상대방이 통화 중입니다.",
  "no-answer": "상대방이 전화를 받지 않았습니다.",
  rejected: "상대방이 전화를 거절했습니다.",
  canceled: "전화가 취소되었습니다.",
  failed: "전화 연결에 실패했습니다.",
};

function safeEqual(a: string, b: string): boolean {
  const left = Buffer.from(a);
  const right = Buffer.from(b);
  return left.length === right.length && timingSafeEqual(left, right);
}

/**
 * KAT expects domestic Korean numbers (010… / 070…), not E.164. The transformation lives in the domain
 * so the number policy judges exactly the string KAT receives (SPEC-POLICY-001 audit F1).
 */
export const toKatPhoneNumber = toDomesticDialString;

function paramString(value: unknown): string {
  if (typeof value === "string") return value;
  if (typeof value === "number" || typeof value === "boolean") return String(value);
  return "";
}

export class KatCallProvider implements CallProvider {
  readonly name: ProviderId = KAT_PROVIDER_ID;
  private readonly calls = new Map<string, ActiveCall>();
  private readonly byCallId = new Map<string, string>();

  constructor(
    private readonly options: KatOptions,
    private readonly log: Logger,
  ) {}

  async start(session: CallSession): Promise<void> {
    const task = session.task();
    const streamToken = randomBytes(24).toString("hex");
    const active: ActiveCall = { session, streamToken, mediaBridged: false };
    this.calls.set(task.id, active);
    session.signal.addEventListener(
      "abort",
      () => {
        this.calls.delete(task.id);
        if (active.callId) this.byCallId.delete(active.callId);
      },
      { once: true },
    );

    const base = this.options.publicBaseUrl.replace(/\/$/, "");
    const streamUrl = `${base.replace(/^http/, "ws")}${MEDIA_PATH}`;
    const from = toKatPhoneNumber(this.options.fromNumber);
    const to = toKatPhoneNumber(task.phoneNumber);

    const body = {
      from,
      to,
      streamUrl,
      statusCallbackUrl: `${base}${STATUS_PATH}`,
      metadata: { taskId: task.id, token: streamToken },
      timeLimit: katTimeLimitSec(this.options.maxCallDurationSec),
      codec: "PCMU",
    };

    let response: unknown;
    try {
      response = await this.api("POST", `/group/${this.options.groupId}/media-stream/calls`, body, {
        "Idempotency-Key": task.id,
      });
    } catch (error) {
      if (error instanceof KatTimeoutError) {
        this.log.warn({ taskId: task.id, err: error.message }, "KAT call creation timed out");
        throw new Error(KAT_TIMEOUT_START_ERROR);
      }
      throw error;
    }
    const created = CreateCallResponse.safeParse(response);
    if (!created.success) {
      throw new Error("KAT Cloud did not return a callId");
    }
    const { callId } = created.data;
    active.callId = callId;
    this.byCallId.set(callId, task.id);
    session.recordProviderCallId(callId);
    this.log.info(
      {
        taskId: task.id,
        callId,
        to: maskPhoneNumber(task.phoneNumber),
        streamHost: new URL(streamUrl.replace(/^ws/, "http")).host,
        statusHost: new URL(`${base}${STATUS_PATH}`).host,
      },
      "Outbound call created",
    );
  }

  async hangup(taskId: string): Promise<void> {
    const active = this.calls.get(taskId);
    if (!active?.callId) return;
    await this.terminateCall(active.callId, taskId);
  }

  /** Used by restart recovery: no in-memory call exists, only the callId saved on the task. Never throws. */
  async terminateByProviderCallId(providerCallId: string): Promise<void> {
    await this.terminateCall(providerCallId);
  }

  private async terminateCall(callId: string, taskId?: string): Promise<void> {
    if (!callId) return;
    try {
      await this.api("POST", `/group/${this.options.groupId}/media-stream/calls/${callId}/termination`);
    } catch (error) {
      this.log.warn({ taskId, callId, err: (error as Error).message }, "Hangup request failed");
    }
  }

  /** KAT's status webhook (signed over the raw body) and its media stream WebSocket. */
  routes(): ProviderRoutes {
    return {
      http: [
        {
          method: "POST",
          path: STATUS_PATH,
          rawBody: true,
          handle: (request) => {
            if (!this.isValidHttpWebhook(request.headers, request.rawBody ?? "")) {
              return { status: 401, body: { error: "invalid_signature" } };
            }
            this.handleStatusWebhook(request.body);
            return { status: 204 };
          },
        },
      ],
      sockets: [{ path: MEDIA_PATH, attach: (socket, request) => this.attachMediaStream(socket, request) }],
    };
  }

  isValidHttpWebhook(headers: IncomingMessage["headers"], rawBody: string | Buffer): boolean {
    return verifyKatHttpSignature({
      secret: this.options.webhookSecret,
      timestamp: headers["x-webhook-timestamp"],
      signature: headers["x-webhook-signature"],
      rawBody,
    });
  }

  isValidStreamUpgrade(headers: IncomingMessage["headers"]): boolean {
    return verifyKatStreamSignature({
      secret: this.options.webhookSecret,
      timestamp: headers["x-webhook-timestamp"],
      signature: headers["x-webhook-signature"],
      callId: headers["x-kat-call-id"],
      streamId: headers["x-kat-stream-id"],
    });
  }

  /** Accepts any signed body; one that does not match the webhook schema is ignored (the route still answers 204). */
  handleStatusWebhook(payload: unknown): void {
    const parsed = StatusWebhook.safeParse(payload);
    if (!parsed.success) {
      // Only the event type and call id, and only when they are readable strings; never the body itself.
      this.log.warn(readableWebhookIds(payload), "Ignored malformed KAT status webhook");
      return;
    }
    const data = parsed.data.data ?? {};
    const taskId =
      paramString(data.metadata?.taskId) ||
      (data.callId ? this.byCallId.get(data.callId) : undefined) ||
      "";
    const active = taskId ? this.calls.get(taskId) : undefined;
    if (!active) return;

    const type = data.type ?? "";
    const status = data.status ?? "";
    this.log.info(
      { taskId, callId: data.callId, type, status, mediaBridged: active.mediaBridged },
      "KAT call status",
    );

    if (type === "media_stream.call.ringing") {
      active.session.markRinging();
      return;
    }
    if (type === "media_stream.call.answered" || status === "in-progress") {
      active.session.markConnected();
      return;
    }
    if (type === "media_stream.call.completed" || type === "media_stream.call.failed") {
      // Answered but never bridged audio → not a successful hang-up; usually tunnel/WSS failure.
      if (!active.mediaBridged) {
        active.session.end({
          error:
            "상대가 전화를 받았지만 음성 스트림이 연결되지 않아 통화가 종료되었습니다. PUBLIC_BASE_URL(터널)과 WSS(/kat/media)를 확인해 주세요.",
        });
        return;
      }
      if (status === "completed") {
        active.session.end();
        return;
      }
      if (status in FAILURE_MESSAGES) {
        active.session.end({ error: FAILURE_MESSAGES[status] });
        return;
      }
      active.session.end({
        error: status === "failed" ? FAILURE_MESSAGES.failed : "전화가 비정상 종료되었습니다.",
      });
    }
  }

  /**
   * Waits for KAT's "start" frame, authenticates it, then bridges to Realtime.
   * A signed stream with no active session is a real phone call nobody owns (e.g. the call
   * was created after our request timed out): it is hung up, not just disconnected.
   */
  // @MX:WARN: [AUTO] Hangs up real calls whose media stream has no active session; only signed upgrades may trigger it.
  // @MX:REASON: An unsigned peer must never be able to end arbitrary calls (SPEC-LIFECYCLE-001 REQ-016 (d)); single-instance assumption (§4).
  // @MX:SPEC: SPEC-LIFECYCLE-001
  attachMediaStream(socket: WebSocket, request: IncomingMessage): void {
    if (!this.isValidStreamUpgrade(request.headers)) {
      this.log.warn({}, "Rejected media stream with invalid signature");
      socket.close();
      return;
    }

    const headerCallId = headerValue(request.headers["x-kat-call-id"]);
    const headerStreamId = headerValue(request.headers["x-kat-stream-id"]);
    const hasActiveSession = (callId: string) => {
      const taskId = this.byCallId.get(callId);
      return Boolean(taskId && this.calls.has(taskId));
    };
    const hangUpOrphan = (callId: string, when: string) => {
      socket.off("message", onMessage);
      clearTimeout(timeout);
      this.log.warn({ callId, when }, "Hanging up a signed media stream with no active session");
      socket.close();
      void this.terminateCall(callId);
    };

    const timeout = setTimeout(() => {
      // Decide at the deadline, not at upgrade time: the call-creation response may still be in flight.
      if (headerCallId && !hasActiveSession(headerCallId)) {
        hangUpOrphan(headerCallId, "no_frame_timeout");
        return;
      }
      socket.close();
    }, 10_000);

    let headerChecked = false;
    const onMessage = (raw: WebSocket.RawData) => {
      // With a header call id, ownership is decided on the first frame, before the frame is parsed.
      if (headerCallId && !headerChecked) {
        headerChecked = true;
        if (!hasActiveSession(headerCallId)) {
          hangUpOrphan(headerCallId, "first_frame");
          return;
        }
      }

      // Non-JSON frames and frames other than "start" are ignored silently while waiting.
      const data = parseJson(raw.toString());
      if (!isRecord(data) || data.event !== "start") return;
      const parsed = StartFrame.safeParse(data);
      if (!parsed.success) {
        // Keep waiting for a well-formed start frame; the 10 s deadline still applies.
        this.log.warn({ callId: headerCallId || undefined }, "Ignored malformed media start frame");
        return;
      }
      const event = parsed.data;

      socket.off("message", onMessage);
      clearTimeout(timeout);

      const params = normalizeCustomParameters(event.start?.customParameters);
      const taskIdFromMeta = paramString(params.taskId);
      const token = paramString(params.token);
      const callId = headerCallId || paramString(event.start?.callId);
      const taskId = (callId ? this.byCallId.get(callId) : undefined) || taskIdFromMeta;
      const active = taskId ? this.calls.get(taskId) : undefined;
      const streamSid =
        event.streamSid ||
        event.start?.streamSid ||
        event.start?.streamId ||
        headerStreamId ||
        "";

      // Upgrade signature already proves the peer is KAT. Prefer callId mapping;
      // fall back to metadata token when callId is unavailable.
      const tokenOk = !token || (active ? safeEqual(token, active.streamToken) : false);
      const authorized = Boolean(active && streamSid && (callId ? this.byCallId.get(callId) === taskId : tokenOk));
      if (!authorized || !active) {
        this.log.warn(
          {
            taskId,
            callId: callId || undefined,
            hasActive: Boolean(active),
            hasStreamSid: Boolean(streamSid),
            hasToken: Boolean(token),
          },
          "Rejected unauthenticated media stream",
        );
        socket.close();
        if (active) {
          const pstnCallId = active.callId || callId;
          active.session.end({ error: "미디어 스트림 인증에 실패해 통화를 종료했습니다." });
          void this.terminateCall(pstnCallId, taskId);
        } else if (callId) {
          // No session owns this signed call (start-frame call id): hang it up too.
          void this.terminateCall(callId, taskId || undefined);
        }
        return;
      }

      active.mediaBridged = true;
      active.session.markConnected();
      this.log.info({ taskId, callId: callId || undefined, streamSid }, "Media stream bridged to Realtime");
      // Capture callId so hangup still works after session.abort() clears the active map.
      const pstnCallId = active.callId || callId;
      (this.options.bridge ?? bridgeToRealtime)({
        media: socket,
        streamSid,
        session: active.session,
        options: this.options.realtime,
        hangup: () => this.terminateCall(pstnCallId, taskId),
        log: this.log,
      });
    };

    socket.on("message", onMessage);
  }

  private async api(
    method: string,
    path: string,
    body?: unknown,
    extraHeaders?: Record<string, string>,
  ): Promise<unknown> {
    const url = `${this.options.apiBaseUrl.replace(/\/$/, "")}${path}`;
    const timeoutMs = this.options.requestTimeoutMs ?? DEFAULT_KAT_REQUEST_TIMEOUT_MS;
    // AbortController + setTimeout instead of AbortSignal.timeout(), so tests can drive the timer.
    const controller = new AbortController();
    let timedOut = false;
    const timer = setTimeout(() => {
      timedOut = true;
      controller.abort();
    }, timeoutMs);

    let response: Response;
    let text: string;
    try {
      response = await (this.options.fetch ?? fetch)(url, {
        method,
        headers: {
          "x-api-key": this.options.apiKey,
          Accept: "application/json",
          ...(body !== undefined ? { "Content-Type": "application/json" } : {}),
          ...extraHeaders,
        },
        body: body !== undefined ? JSON.stringify(body) : undefined,
        signal: controller.signal,
      });
      text = await response.text();
    } catch (error) {
      if (timedOut) throw new KatTimeoutError(method, path, timeoutMs);
      throw error;
    } finally {
      clearTimeout(timer);
    }
    let json: unknown = {};
    if (text) {
      try {
        json = JSON.parse(text);
      } catch {
        json = { raw: text };
      }
    }

    if (!response.ok) {
      // Any body shape (array, string, null) falls back to the raw text instead of throwing.
      const fields = ApiErrorBody.safeParse(json);
      const message = fields.data?.message ?? fields.data?.error ?? text.slice(0, 200) ?? response.statusText;
      throw new Error(`KAT Cloud ${method} ${path} failed (${response.status}): ${message}`);
    }

    // Some KAT endpoints wrap the payload as { code, message, result }.
    if (json && typeof json === "object" && "result" in json && json.result != null) {
      return json.result;
    }
    return json;
  }
}

function headerValue(value: string | string[] | undefined): string {
  if (Array.isArray(value)) return value[0] ?? "";
  return value ?? "";
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/** Event type and call id from a webhook body that failed validation, only where they are strings. */
function readableWebhookIds(payload: unknown): { type?: string; callId?: string } {
  const data = isRecord(payload) ? payload.data : undefined;
  if (!isRecord(data)) return {};
  return {
    ...(typeof data.type === "string" && { type: data.type }),
    ...(typeof data.callId === "string" && { callId: data.callId }),
  };
}

function normalizeCustomParameters(
  value: Record<string, unknown> | string | undefined,
): Record<string, unknown> {
  if (!value) return {};
  if (typeof value === "string") {
    try {
      const parsed = JSON.parse(value) as unknown;
      return parsed && typeof parsed === "object" && !Array.isArray(parsed)
        ? (parsed as Record<string, unknown>)
        : {};
    } catch {
      return {};
    }
  }
  return value;
}
