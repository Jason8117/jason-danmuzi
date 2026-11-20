import { randomBytes, timingSafeEqual } from "node:crypto";
import twilio from "twilio";
import type WebSocket from "ws";
import { maskPhoneNumber } from "../../domain/phone.js";
import type { CallProvider, CallSession } from "../types.js";
import { bridgeToRealtime, type RealtimeOptions } from "./realtimeBridge.js";

export interface TwilioOptions {
  accountSid: string;
  authToken: string;
  fromNumber: string;
  publicBaseUrl: string;
  realtime: RealtimeOptions;
}

interface Logger {
  info(obj: object, msg: string): void;
  warn(obj: object, msg: string): void;
}

interface ActiveCall {
  session: CallSession;
  streamToken: string;
  callSid?: string;
}

const FAILURE_MESSAGES: Record<string, string> = {
  busy: "상대방이 통화 중입니다.",
  "no-answer": "상대방이 전화를 받지 않았습니다.",
  failed: "전화 연결에 실패했습니다.",
  canceled: "전화가 취소되었습니다.",
};

function escapeXml(value: string): string {
  return value.replace(/[<>&'"]/g, (c) => `&#${c.charCodeAt(0)};`);
}

function safeEqual(a: string, b: string): boolean {
  const left = Buffer.from(a);
  const right = Buffer.from(b);
  return left.length === right.length && timingSafeEqual(left, right);
}

export class TwilioCallProvider implements CallProvider {
  readonly name = "twilio" as const;
  private readonly client: ReturnType<typeof twilio>;
  private readonly calls = new Map<string, ActiveCall>();

  constructor(
    private readonly options: TwilioOptions,
    private readonly log: Logger,
  ) {
    this.client = twilio(options.accountSid, options.authToken);
  }

  async start(session: CallSession): Promise<void> {
    const task = session.task();
    const streamToken = randomBytes(24).toString("hex");
    const active: ActiveCall = { session, streamToken };
    this.calls.set(task.id, active);
    session.signal.addEventListener("abort", () => this.calls.delete(task.id), { once: true });

    const base = this.options.publicBaseUrl.replace(/\/$/, "");
    const streamUrl = `${base.replace(/^http/, "ws")}/twilio/media`;
    // Twilio drops query strings on stream URLs, so identity travels as <Parameter>s.
    const twiml = `<Response><Connect><Stream url="${escapeXml(streamUrl)}"><Parameter name="taskId" value="${escapeXml(task.id)}"/><Parameter name="token" value="${streamToken}"/></Stream></Connect></Response>`;

    const call = await this.client.calls.create({
      to: task.phoneNumber,
      from: this.options.fromNumber,
      twiml,
      statusCallback: `${base}/twilio/status/${task.id}`,
      statusCallbackMethod: "POST",
      statusCallbackEvent: ["initiated", "ringing", "answered", "completed"],
      timeLimit: 15 * 60,
    });
    active.callSid = call.sid;
    this.log.info({ taskId: task.id, to: maskPhoneNumber(task.phoneNumber) }, "Outbound call created");
  }

  async hangup(taskId: string): Promise<void> {
    const active = this.calls.get(taskId);
    if (!active?.callSid) return;
    try {
      await this.client.calls(active.callSid).update({ status: "completed" });
    } catch (error) {
      this.log.warn({ taskId, err: (error as Error).message }, "Hangup request failed");
    }
  }

  isValidSignature(signature: string | undefined, path: string, params: Record<string, string>): boolean {
    if (!signature) return false;
    const url = `${this.options.publicBaseUrl.replace(/\/$/, "")}${path}`;
    return twilio.validateRequest(this.options.authToken, signature, url, params);
  }

  handleStatusCallback(taskId: string, params: Record<string, string>): void {
    const active = this.calls.get(taskId);
    if (!active) return;
    const status = params.CallStatus ?? "";

    if (status === "ringing") active.session.markRinging();
    else if (status === "in-progress") active.session.markConnected();
    else if (status === "completed") active.session.end();
    else if (status in FAILURE_MESSAGES) active.session.end({ error: FAILURE_MESSAGES[status] });
  }

  /** Waits for Twilio's "start" frame, authenticates it, then hands the socket to the realtime bridge. */
  attachMediaStream(socket: WebSocket): void {
    const timeout = setTimeout(() => socket.close(), 10_000);

    const onMessage = (raw: WebSocket.RawData) => {
      let event: { event?: string; start?: { streamSid?: string; customParameters?: Record<string, string> } };
      try {
        event = JSON.parse(raw.toString());
      } catch {
        return;
      }
      if (event.event !== "start") return;

      socket.off("message", onMessage);
      clearTimeout(timeout);

      const taskId = event.start?.customParameters?.taskId ?? "";
      const token = event.start?.customParameters?.token ?? "";
      const active = this.calls.get(taskId);
      const streamSid = event.start?.streamSid;
      if (!active || !streamSid || !safeEqual(token, active.streamToken)) {
        this.log.warn({ taskId }, "Rejected unauthenticated media stream");
        socket.close();
        return;
      }

      active.session.markConnected();
      bridgeToRealtime({
        twilio: socket,
        streamSid,
        session: active.session,
        options: this.options.realtime,
        hangup: () => this.hangup(taskId),
        log: this.log,
      });
    };

    socket.on("message", onMessage);
  }
}
