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

export function isBlockedNumber(e164: string): boolean {
  if (!e164.startsWith("+82")) return false;
  const national = e164.slice(3);
  return BLOCKED_KR_SHORT_CODES.includes(national);
}

export function maskPhoneNumber(e164: string): string {
  if (e164.length <= 7) return e164;
  return `${e164.slice(0, 3)}${"•".repeat(e164.length - 7)}${e164.slice(-4)}`;
}
