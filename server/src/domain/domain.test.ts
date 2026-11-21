import { describe, expect, it } from "vitest";
import { isFiller } from "../brain/heuristicBrain.js";
import { checkTargetNumber, isBlockedNumber, maskPhoneNumber, normalizePhoneNumber } from "./phone.js";
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

describe("checkTargetNumber (SPEC-POLICY-001)", () => {
  // AC-008: the block list fires for every notation, judged on the raw text with the leading "+" kept.
  it.each(["119", "112", "182", "(119)", "+82 119", "+82-182", "0082-112", "0119", "+82 112"])(
    "classifies Korean emergency and special codes as blocked in every notation: %s",
    (raw) => {
      expect(checkTargetNumber(raw)).toEqual({ kind: "blocked" });
    },
  );

  // AC-009: normal numbers keep their normalized value; malformed input stays invalid.
  it.each([
    ["010-1234-5678", "+821012345678"],
    ["02 123 4567", "+8221234567"],
    ["+1 (415) 555-0100", "+14155550100"],
    ["0082 10 1234 5678", "+821012345678"],
  ])("keeps normal numbers and the block list unchanged: %s is ok", (raw, e164) => {
    expect(checkTargetNumber(raw)).toEqual({ kind: "ok", e164 });
    expect(normalizePhoneNumber(raw)).toBe(e164);
  });

  it.each(["+1 911", "", "abc", "+12"])("keeps normal numbers and the block list unchanged: %s is invalid", (raw) => {
    expect(checkTargetNumber(raw)).toEqual({ kind: "invalid" });
  });

  it("keeps the block list unchanged", () => {
    for (const code of ["112", "119", "113", "114", "117", "118", "122", "125", "182"]) {
      expect(checkTargetNumber(code)).toEqual({ kind: "blocked" });
      expect(isBlockedNumber(`+82${code}`)).toBe(true);
    }
    for (const code of ["111", "115", "116", "120", "123", "124", "126", "181", "183"]) {
      expect(checkTargetNumber(code)).toEqual({ kind: "invalid" });
      expect(isBlockedNumber(`+82${code}`)).toBe(false);
    }
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
