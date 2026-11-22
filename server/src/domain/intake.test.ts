import { describe, expect, it } from "vitest";
import { findPhoneNumberInText, maskPhoneNumbers, normalizeName, PHONE_PLACEHOLDER } from "./intake.js";

describe("intake number rules (SPEC-INTAKE-001)", () => {
  // AC-004 / REQ-004, REQ-005 — design.md §2 vector table (18 rows)
  it.each([
    { text: "010-1234-5678로 전화해 줘", phoneNumber: "+821012345678", numberIssue: null },
    { text: "01012345678", phoneNumber: "+821012345678", numberIssue: null },
    { text: "라 파스타 02-123-4567", phoneNumber: "+8221234567", numberIssue: null },
    { text: "(02) 123-4567", phoneNumber: "+8221234567", numberIssue: null },
    { text: "031.123.4567", phoneNumber: "+82311234567", numberIssue: null },
    { text: "0507-1234-5678 예약", phoneNumber: "+8250712345678", numberIssue: null },
    { text: "+82 10 1234 5678", phoneNumber: "+821012345678", numberIssue: null },
    { text: "+82-2-123-4567", phoneNumber: "+8221234567", numberIssue: null },
    { text: "010 1234 5678 2명 예약", phoneNumber: "+821012345678", numberIssue: null },
    { text: "010-1234-5678 말고 02-123-4567", phoneNumber: "+821012345678", numberIssue: null },
    { text: "2024. 12. 25 예약", phoneNumber: null, numberIssue: null },
    { text: "1588-1234에 전화", phoneNumber: null, numberIssue: null },
    { text: "+1 415 555 0100", phoneNumber: null, numberIssue: null },
    { text: "119에 전화해 줘", phoneNumber: null, numberIssue: "blocked" },
    { text: "0119로 연락", phoneNumber: null, numberIssue: "blocked" },
    { text: "+82 112", phoneNumber: null, numberIssue: "blocked" },
    { text: "서울병원 112호실 면회 시간", phoneNumber: null, numberIssue: null },
    { text: "12345678901234", phoneNumber: null, numberIssue: null },
  ])("finds Korean phone numbers in free text: $text", ({ text, phoneNumber, numberIssue }) => {
    expect(findPhoneNumberInText(text)).toEqual({ phoneNumber, numberIssue });
  });

  // AC-007 (a) / REQ-007 — design.md §2 masking table (6 rows)
  it.each([
    { text: "라 파스타에 010-1234-5678로 전화해서 예약", masked: "라 파스타에 [전화번호]로 전화해서 예약" },
    { text: "1588-1234에 전화", masked: "[전화번호]에 전화" },
    { text: "+1 415 555 0100 번호로 연락", masked: "[전화번호] 번호로 연락" },
    { text: "2024. 12. 25 예약", masked: "2024. 12. 25 예약" },
    { text: "금요일 7시 2명", masked: "금요일 7시 2명" },
    { text: "119에 전화해 줘", masked: "119에 전화해 줘" },
  ])("masks number-shaped text before it reaches the LLM: $text", ({ text, masked }) => {
    expect(maskPhoneNumbers(text)).toBe(masked);
  });

  it("uses the [전화번호] placeholder", () => {
    expect(PHONE_PLACEHOLDER).toBe("[전화번호]");
  });

  // design.md §3.1 — the same vectors as the app (counterparties.dart)
  it.each([
    { name: "라 파스타", normalized: "라파스타" },
    { name: " La Pasta ", normalized: "lapasta" },
    { name: "미용실\tA", normalized: "미용실a" },
  ])("normalizes counterparty names: $name", ({ name, normalized }) => {
    expect(normalizeName(name)).toBe(normalized);
  });
});
