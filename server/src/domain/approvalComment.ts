/** Replacement text for a masked sensitive digit run (SPEC-APPROVAL-001 OD-1). */
export const SENSITIVE_PLACEHOLDER = "[민감정보 삭제]";

/** A piece with this many digits or more is masked, with no upper bound (OD-4). */
const SENSITIVE_MIN_DIGITS = 13;

const CONTROL_CHARS = /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F]/g;
/** Digits joined by at most one space or one hyphen; global matching from the left yields maximal chains. */
const DIGIT_CHAIN = /\d(?:[ -]?\d)*/g;
/** A hyphenated domestic phone number, e.g. 010-1234-5678 or 02-123-4567. */
const PHONE_TOKEN = /^0\d{1,2}-\d{3,4}-\d{4}$/;

/**
 * Normalizes a user's approval comment before it is stored or sent to a provider
 * (SPEC-APPROVAL-001 REQ-002, REQ-003). Returns undefined when nothing is left.
 */
// @MX:NOTE: [AUTO] Single home of the approval-comment rule; app/lib/features/calls/domain/approval_comment.dart mirrors the digit rule for its warning only.
// @MX:SPEC: SPEC-APPROVAL-001
export function sanitizeApprovalComment(raw: string): string | undefined {
  const normalized = raw
    .replace(CONTROL_CHARS, "")
    .replace(/\t/g, " ")
    .replace(/\r\n?/g, "\n")
    .replace(/\n{3,}/g, "\n\n");
  const result = maskSensitiveDigits(normalized).trim();
  return result === "" ? undefined : result;
}

/**
 * REQ-003 three steps: take each maximal digit chain, keep hyphenated phone tokens,
 * and mask every remaining run of tokens that holds 13 or more digits.
 */
function maskSensitiveDigits(text: string): string {
  return text.replace(DIGIT_CHAIN, (chain) => {
    const out: string[] = [];
    let piece: string[] = [];
    const flush = () => {
      if (piece.length === 0) return;
      const joined = piece.join(" ");
      out.push(joined.replace(/\D/g, "").length >= SENSITIVE_MIN_DIGITS ? SENSITIVE_PLACEHOLDER : joined);
      piece = [];
    };
    for (const token of chain.split(" ")) {
      if (PHONE_TOKEN.test(token)) {
        flush();
        out.push(token);
      } else {
        piece.push(token);
      }
    }
    flush();
    return out.join(" ");
  });
}
