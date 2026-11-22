import { describe, expect, it } from "vitest";
import { SENSITIVE_PLACEHOLDER, sanitizeApprovalComment } from "./approvalComment.js";

// SPEC-APPROVAL-001 AC-002 / REQ-002
describe("sanitizeApprovalComment control characters (SPEC-APPROVAL-001 AC-002)", () => {
  it.each([
    ["a\u0000b", "ab"],
    ["a\tb", "a b"],
    ["a\r\nb\rc", "a\nb\nc"],
    ["a\n\n\n\nb", "a\n\nb"],
    ["\u0085x", "x"],
    ["\u0007   ", undefined],
    ["  1만 원까지만  ", "1만 원까지만"],
  ])("sanitizes control characters and line breaks: %j", (input, expected) => {
    expect(sanitizeApprovalComment(input)).toBe(expected);
  });
});

/**
 * AC-003 vector table (16 rows). The app warning uses the same rows
 * (`app/test/unit_test.dart`, "detects sensitive digit runs like the server"); keep both tables identical.
 * `null` means the input comes back unchanged.
 */
const SENSITIVE_DIGIT_VECTORS: [input: string, masked: string | null][] = [
  ["카드 1234-5678-9012-3456로 결제", "카드 [민감정보 삭제]로 결제"],
  ["주민번호 900101-1234567", "주민번호 [민감정보 삭제]"],
  ["1234 5678 9012 345 입니다", "[민감정보 삭제] 입니다"],
  ["4111111111111111", "[민감정보 삭제]"],
  ["010-1234-5678로 연락 주세요", null],
  ["주문 2024-1234-5678", null],
  ["12345678901234567890", "[민감정보 삭제]"],
  ["1234--5678-9012-3456", null],
  ["카드 1111 2222 3333 4444, 다른 카드 5555-6666-7777-8888", "카드 [민감정보 삭제], 다른 카드 [민감정보 삭제]"],
  ["010-1234-5678 010-9876-5432", null],
  ["1234 5678 9012 3456 7890", "[민감정보 삭제]"],
  ["카드 1234-5678-9012-3456 0101", "카드 [민감정보 삭제]"],
  ["카드 1234 5678 9012 3456 1225 123", "카드 [민감정보 삭제]"],
  ["주민번호 900101-1234567 010-1234-5678", "주민번호 [민감정보 삭제] 010-1234-5678"],
  ["010-1234-5678 1234 5678 9012 3456", "010-1234-5678 [민감정보 삭제]"],
  ["01012345678 01098765432", "[민감정보 삭제]"],
];

// SPEC-APPROVAL-001 AC-003 / REQ-003
describe("sanitizeApprovalComment sensitive digits (SPEC-APPROVAL-001 AC-003)", () => {
  it("uses the shared placeholder text", () => {
    expect(SENSITIVE_PLACEHOLDER).toBe("[민감정보 삭제]");
    expect(SENSITIVE_DIGIT_VECTORS).toHaveLength(16);
  });

  it.each(SENSITIVE_DIGIT_VECTORS)("masks card- and ID-shaped digit runs: %s", (input, masked) => {
    expect(sanitizeApprovalComment(input)).toBe(masked ?? input);
  });
});
