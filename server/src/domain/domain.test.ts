import { describe, expect, it } from "vitest";
import { isFiller } from "../brain/heuristicBrain.js";
import { isBlockedNumber, maskPhoneNumber, normalizePhoneNumber } from "./phone.js";
import { assertTransition, canTransition } from "./stateMachine.js";

describe("normalizePhoneNumber", () => {
  it.each([
    ["010-1234-5678", "+821012345678"],
    ["02 123 4567", "+8221234567"],
    ["+1 (415) 555-0100", "+14155550100"],
    ["0082 10 1234 5678", "+821012345678"],
  ])("normalizes %s", (raw, expected) => {
    expect(normalizePhoneNumber(raw)).toBe(expected);
  });

  it.each(["", "abc", "112", "+12"])("rejects %s", (raw) => {
    expect(normalizePhoneNumber(raw)).toBeNull();
  });

  it("blocks Korean emergency short codes", () => {
    expect(isBlockedNumber("+82119")).toBe(true);
    expect(isBlockedNumber("+821012345678")).toBe(false);
  });

  it("masks all but the last four digits", () => {
    expect(maskPhoneNumber("+821012345678")).toBe("+82••••••5678");
  });
});

describe("isFiller", () => {
  it.each(["네, 말씀하세요.", "네, 알겠습니다.", "네, 감사합니다.", "Sure, go ahead.", "Thank you, bye."])("treats %s as filler", (line) => {
    expect(isFiller(line)).toBe(true);
  });

  it.each(["네, 그 시간에 자리 있습니다.", "1인당 1만 원 예약금이 있습니다.", "Yes, we have a table."])("keeps %s", (line) => {
    expect(isFiller(line)).toBe(false);
  });
});

describe("task state machine", () => {
  it("allows the happy path", () => {
    expect(canTransition("planning", "awaiting_approval")).toBe(true);
    expect(canTransition("awaiting_approval", "dialing")).toBe(true);
    expect(canTransition("in_progress", "summarizing")).toBe(true);
    expect(canTransition("summarizing", "completed")).toBe(true);
  });

  it("never leaves a terminal state", () => {
    expect(() => assertTransition("completed", "dialing")).toThrow();
    expect(() => assertTransition("canceled", "planning")).toThrow();
  });

  it("requires plan approval before dialing", () => {
    expect(canTransition("planning", "dialing")).toBe(false);
  });
});
