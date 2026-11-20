import { createHmac } from "node:crypto";
import { describe, expect, it } from "vitest";
import { toKatPhoneNumber } from "./katProvider.js";
import { verifyKatHttpSignature, verifyKatStreamSignature } from "./webhook.js";

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
