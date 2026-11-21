const E164 = /^\+[1-9]\d{7,14}$/;

/**
 * Normalizes user-typed numbers to E.164. Numbers without a country code are
 * treated as Korean (leading 0 replaced by +82), which matches the target market.
 */
export function normalizePhoneNumber(raw: string): string | null {
  const trimmed = raw.trim();
  const digits = trimmed.replace(/[^\d]/g, "");
  if (!digits) return null;

  let candidate: string;
  if (trimmed.startsWith("+")) candidate = `+${digits}`;
  else if (digits.startsWith("00")) candidate = `+${digits.slice(2)}`;
  else if (digits.startsWith("0")) candidate = `+82${digits.slice(1)}`;
  else candidate = `+${digits}`;

  return E164.test(candidate) ? candidate : null;
}

/** Emergency and special-service numbers must never be dialed by an automated agent. */
const BLOCKED_KR_SHORT_CODES = ["112", "119", "113", "114", "117", "118", "122", "125", "182"];

/**
 * The digit string actually sent to the carrier: domestic Korean form (010… / 070…) for +82,
 * otherwise the bare digits. Shared by the number policy and the KAT provider so both see one number.
 */
// @MX:NOTE: [AUTO] Non-+82 numbers lose their "+" here, so "+1 19…" is dialed as a domestic "119…" string (SPEC-POLICY-001 audit F1).
// @MX:SPEC: SPEC-POLICY-001
export function toDomesticDialString(e164OrLocal: string): string {
  const trimmed = e164OrLocal.trim();
  if (trimmed.startsWith("+82")) return `0${trimmed.slice(3)}`;
  return trimmed.replace(/[^\d]/g, "");
}

/**
 * Judged on the dialed form. A domestic number (leading 0) is blocked only when its national part is
 * exactly a short code, so 011-9xx… and 02-112… stay dialable. A digit string without a leading 0 is
 * blocked when it starts with a short code, because the carrier would read it as that code.
 */
export function isBlockedNumber(e164: string): boolean {
  const dialed = toDomesticDialString(e164);
  if (dialed.startsWith("0")) return BLOCKED_KR_SHORT_CODES.includes(dialed.slice(1));
  return BLOCKED_KR_SHORT_CODES.some((code) => dialed.startsWith(code));
}

export type TargetNumberCheck = { kind: "ok"; e164: string } | { kind: "invalid" } | { kind: "blocked" };

/**
 * The single rule deciding whether an automated agent may dial a number (SPEC-POLICY-001 REQ-005).
 * The block list is checked on the raw text first, because normalizePhoneNumber rejects short codes
 * as malformed and would otherwise hide them behind "invalid".
 */
// @MX:ANCHOR: [AUTO] Safety gate for every outbound call: CallService.create and CallService.approvePlan both rely on it; create also uses it to drop blocked callback numbers.
// @MX:REASON: Emergency/special numbers must never be auto-dialed; a weaker rule here silently weakens every entry point.
// @MX:SPEC: SPEC-POLICY-001
export function checkTargetNumber(raw: string): TargetNumberCheck {
  // Drop spaces, hyphens, parentheses and dots, but keep a leading "+" so "+82 112" is still seen as +82.
  const compact = raw.trim().replace(/[\s\-().]/g, "");
  const national = koreanNationalPart(compact);
  if (national !== null && BLOCKED_KR_SHORT_CODES.includes(national)) return { kind: "blocked" };

  const e164 = normalizePhoneNumber(raw);
  if (!e164) return { kind: "invalid" };
  if (isBlockedNumber(e164)) return { kind: "blocked" };
  return { kind: "ok", e164 };
}

/** The Korean national part of a compacted number, or null when it carries another country code. */
function koreanNationalPart(compact: string): string | null {
  if (compact.startsWith("+82")) return compact.slice(3);
  if (compact.startsWith("+")) return null;
  if (compact.startsWith("0082")) return compact.slice(4);
  if (compact.startsWith("0")) return compact.slice(1);
  return compact;
}

export function maskPhoneNumber(e164: string): string {
  if (e164.length <= 7) return e164;
  return `${e164.slice(0, 3)}${"•".repeat(e164.length - 7)}${e164.slice(-4)}`;
}
