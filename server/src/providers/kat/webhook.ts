import { createHmac, timingSafeEqual } from "node:crypto";

const TOLERANCE_SECONDS = 5 * 60;

function safeEqualString(a: string, b: string): boolean {
  const left = Buffer.from(a);
  const right = Buffer.from(b);
  return left.length === right.length && timingSafeEqual(left, right);
}

/** HTTP webhook: HMAC-SHA256(secret, "{timestamp}.{rawBody}") → v1=hex */
export function verifyKatHttpSignature(params: {
  secret: string;
  timestamp: string | string[] | undefined;
  signature: string | string[] | undefined;
  rawBody: string | Buffer;
}): boolean {
  const timestamp = headerValue(params.timestamp);
  const signature = headerValue(params.signature);
  if (!timestamp || !signature) return false;

  const ts = Number(timestamp);
  const now = Math.floor(Date.now() / 1000);
  if (!Number.isInteger(ts) || Math.abs(now - ts) > TOLERANCE_SECONDS) return false;

  const body = typeof params.rawBody === "string" ? params.rawBody : params.rawBody.toString("utf8");
  const expected =
    "v1=" + createHmac("sha256", params.secret).update(`${timestamp}.`).update(body).digest("hex");
  return safeEqualString(expected, signature);
}

/** Media-stream WebSocket upgrade: HMAC-SHA256(secret, "{timestamp}.{callId}.{streamId}") → v1=hex */
export function verifyKatStreamSignature(params: {
  secret: string;
  timestamp: string | string[] | undefined;
  signature: string | string[] | undefined;
  callId: string | string[] | undefined;
  streamId: string | string[] | undefined;
}): boolean {
  const timestamp = headerValue(params.timestamp);
  const signature = headerValue(params.signature);
  const callId = headerValue(params.callId);
  const streamId = headerValue(params.streamId);
  if (!timestamp || !signature || !callId || !streamId) return false;

  const ts = Number(timestamp);
  const now = Math.floor(Date.now() / 1000);
  if (!Number.isInteger(ts) || Math.abs(now - ts) > TOLERANCE_SECONDS) return false;

  const expected =
    "v1=" + createHmac("sha256", params.secret).update(`${timestamp}.${callId}.${streamId}`).digest("hex");
  return safeEqualString(expected, signature);
}

function headerValue(value: string | string[] | undefined): string | undefined {
  if (Array.isArray(value)) return value[0];
  return value;
}
