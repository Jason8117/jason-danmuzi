import { randomBytes, timingSafeEqual } from "node:crypto";
import type { IncomingMessage } from "node:http";
import type WebSocket from "ws";
import { maskPhoneNumber } from "../../domain/phone.js";
import type { CallProvider, CallSession } from "../types.js";
import { bridgeToRealtime, type RealtimeOptions } from "../realtimeBridge.js";
import { verifyKatHttpSignature, verifyKatStreamSignature } from "./webhook.js";

export interface KatOptions {
  apiKey: string;
  groupId: string;
  fromNumber: string;
  webhookSecret: string;
  publicBaseUrl: string;
  apiBaseUrl: string;
  realtime: RealtimeOptions;
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

/** KAT expects domestic Korean numbers (010… / 070…), not E.164. */
export function toKatPhoneNumber(e164OrLocal: string): string {
  const trimmed = e164OrLocal.trim();
  if (trimmed.startsWith("+82")) return `0${trimmed.slice(3)}`;
  return trimmed.replace(/[^\d]/g, "");
}

function paramString(value: unknown): string {
  if (typeof value === "string") return value;
  if (typeof value === "number" || typeof value === "boolean") return String(value);
  return "";
}

export class KatCallProvider implements CallProvider {
  readonly name = "kat" as const;
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
    const streamUrl = `${base.replace(/^http/, "ws")}/kat/media`;
    const from = toKatPhoneNumber(this.options.fromNumber);
    const to = toKatPhoneNumber(task.phoneNumber);

    const body = {
      from,
      to,
      streamUrl,
      statusCallbackUrl: `${base}/kat/status`,
      metadata: { taskId: task.id, token: streamToken },
      timeLimit: Math.max(10, Math.min(14_400, 15 * 60)),
      codec: "PCMU",
    };

    const response = await this.api("POST", `/group/${this.options.groupId}/media-stream/calls`, body, {
      "Idempotency-Key": task.id,
    });
    const callId = paramString(response.callId);
    if (!callId) {
      throw new Error("KAT Cloud did not return a callId");
    }
    active.callId = callId;
    this.byCallId.set(callId, task.id);
    this.log.info(
      {
        taskId: task.id,
        callId,
        to: maskPhoneNumber(task.phoneNumber),
        streamHost: new URL(streamUrl.replace(/^ws/, "http")).host,
        statusHost: new URL(`${base}/kat/status`).host,
      },
      "Outbound call created",
    );
  }

  async hangup(taskId: string): Promise<void> {
    const active = this.calls.get(taskId);
    if (!active?.callId) return;
    await this.terminateCall(active.callId, taskId);
  }

  private async terminateCall(callId: string, taskId: string): Promise<void> {
    if (!callId) return;
    try {
      await this.api("POST", `/group/${this.options.groupId}/media-stream/calls/${callId}/termination`);
    } catch (error) {
      this.log.warn({ taskId, err: (error as Error).message }, "Hangup request failed");
    }
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

  handleStatusWebhook(payload: {
    data?: {
      type?: string;
      callId?: string;
      status?: string;
      metadata?: Record<string, unknown>;
    };
  }): void {
    const data = payload.data ?? {};
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

  /** Waits for KAT's "start" frame, authenticates it, then bridges to Realtime. */
  attachMediaStream(socket: WebSocket, request: IncomingMessage): void {
    if (!this.isValidStreamUpgrade(request.headers)) {
      this.log.warn({}, "Rejected media stream with invalid signature");
      socket.close();
      return;
    }

    const headerCallId = headerValue(request.headers["x-kat-call-id"]);
    const headerStreamId = headerValue(request.headers["x-kat-stream-id"]);
    const timeout = setTimeout(() => socket.close(), 10_000);

    const onMessage = (raw: WebSocket.RawData) => {
      let event: {
        event?: string;
        streamSid?: string;
        start?: {
          streamSid?: string;
          streamId?: string;
          callId?: string;
          customParameters?: Record<string, unknown> | string;
        };
      };
      try {
        event = JSON.parse(raw.toString());
      } catch {
        return;
      }
      if (event.event !== "start") return;

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
        }
        return;
      }

      active.mediaBridged = true;
      active.session.markConnected();
      this.log.info({ taskId, callId: callId || undefined, streamSid }, "Media stream bridged to Realtime");
      // Capture callId so hangup still works after session.abort() clears the active map.
      const pstnCallId = active.callId || callId;
      bridgeToRealtime({
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
  ): Promise<Record<string, any>> {
    const url = `${this.options.apiBaseUrl.replace(/\/$/, "")}${path}`;
    const response = await fetch(url, {
      method,
      headers: {
        "x-api-key": this.options.apiKey,
        Accept: "application/json",
        ...(body !== undefined ? { "Content-Type": "application/json" } : {}),
        ...extraHeaders,
      },
      body: body !== undefined ? JSON.stringify(body) : undefined,
    });

    const text = await response.text();
    let json: Record<string, any> = {};
    if (text) {
      try {
        json = JSON.parse(text) as Record<string, any>;
      } catch {
        json = { raw: text };
      }
    }

    if (!response.ok) {
      const message = json.message ?? json.error ?? text.slice(0, 200) ?? response.statusText;
      throw new Error(`KAT Cloud ${method} ${path} failed (${response.status}): ${message}`);
    }

    // Some KAT endpoints wrap the payload as { code, message, result }.
    if (json && typeof json === "object" && "result" in json && json.result != null) {
      return json.result as Record<string, any>;
    }
    return json;
  }
}

function headerValue(value: string | string[] | undefined): string {
  if (Array.isArray(value)) return value[0] ?? "";
  return value ?? "";
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
