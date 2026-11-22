import { checkTargetNumber } from "./phone.js";
import type { CallTask } from "./types.js";

/** Stands in for a number-shaped span before text leaves the server (SPEC-INTAKE-001 REQ-007 (a)). */
export const PHONE_PLACEHOLDER = "[전화번호]";

// @MX:NOTE: [AUTO] Korean candidate: "+82" or "0" (optionally "(0"), then 1-3, 3-4 and 4 digit groups with at most
// one separator between groups. No digit or "+" right before, no digit right after (design.md §2). Only this shape
// is ever proposed as a number; the international and 15xx shapes below are masked only (OD-4).
// @MX:SPEC: SPEC-INTAKE-001 REQ-004
const DOMESTIC = /(?<![\d+])(?:\+82[ .-]?|\(?0)(\d{1,3})\)?[ .-]?(\d{3,4})[ .-]?(\d{4})(?!\d)/g;
/** "+" then digits with spaces, hyphens, dots or parentheses, ending in a digit; kept only with 8+ digits. */
const INTERNATIONAL = /(?<!\d)\+\d[\d ().-]*\d/g;
/** 15xx / 16xx / 18xx representative numbers. */
const REPRESENTATIVE = /(?<!\d)1[5-8]\d{2}[ .-]?\d{4}(?!\d)/g;
/** A blocked short code standing on its own: "119에", "0119로", "+82 112". "112호실" is not one. */
const SHORT_CODE =
  /(?<![\d+])(?:\+82[ .-]?|0)?(?:112|119|113|114|117|118|122|125|182)(?=\s*(?:$|에게|에|으로|로|번|한테|전화))/;

const digitCount = (text: string) => text.replace(/\D/g, "").length;

/** Replaces every number-shaped span (the masking set of REQ-007 (a)) with `replacement`. */
function replaceNumberShapes(text: string, replacement: string): string {
  return text
    .replace(DOMESTIC, replacement)
    .replace(INTERNATIONAL, (match) => (digitCount(match) >= 8 ? replacement : match))
    .replace(REPRESENTATIVE, replacement);
}

/** The text the LLM may see: number-shaped spans become [전화번호]; dates, times and counts stay. */
export function maskPhoneNumbers(text: string): string {
  return replaceNumberShapes(text, PHONE_PLACEHOLDER);
}

export interface TextNumber {
  phoneNumber: string | null;
  numberIssue: "blocked" | null;
}

/**
 * The first Korean number candidate in text order that the number policy accepts. A candidate or a standalone
 * short code the policy blocks makes the answer "blocked" when no candidate is dialable (REQ-004, REQ-005).
 */
export function findPhoneNumberInText(text: string): TextNumber {
  let blocked = false;
  for (const match of text.matchAll(DOMESTIC)) {
    const check = checkTargetNumber(`0${match[1]}${match[2]}${match[3]}`);
    if (check.kind === "ok") return { phoneNumber: check.e164, numberIssue: null };
    if (check.kind === "blocked") blocked = true;
  }
  if (SHORT_CODE.test(text)) blocked = true;
  return { phoneNumber: null, numberIssue: blocked ? "blocked" : null };
}

/** Lower-cased with every whitespace removed; the app uses the same rule (design.md §3.1). No NFC. */
export function normalizeName(name: string): string {
  return name.toLowerCase().replace(/\s/g, "");
}

/**
 * Removes the placeholder and every number-shaped span, then tidies spaces. Applied to all LLM strings: the LLM never
 * received a number, so any number in its answer was invented (REQ-007 (c)).
 */
export function stripPhoneNumbers(text: string): string {
  return replaceNumberShapes(text.split(PHONE_PLACEHOLDER).join(""), "")
    .replace(/\s+/g, " ")
    .trim();
}

/** The history the intake may use: tasks whose callee answered (OD-2), newest first (OD-3). */
export function answeredHistory(tasks: readonly CallTask[]): CallTask[] {
  return tasks.filter((task) => task.connectedAt).sort((a, b) => b.createdAt.localeCompare(a.createdAt));
}

/**
 * The longest known counterparty name (2+ normalized characters) contained in the request, ties going to the more
 * recent call; returned with the spelling of its most recent call (REQ-011). `history` must be answeredHistory().
 */
export function findKnownName(history: readonly CallTask[], text: string): string | null {
  const haystack = normalizeName(text);
  let best: { key: string; name: string } | undefined;
  for (const task of history) {
    const key = normalizeName(task.targetName);
    if (key.length < 2 || !haystack.includes(key)) continue;
    if (!best || key.length > best.key.length) best = { key, name: task.targetName };
  }
  return best?.name ?? null;
}

/**
 * The number of the most recent answered call to the same (normalized) name, re-judged by the number policy. A stored
 * number that is no longer dialable yields null; an older call's number never stands in for it (REQ-006).
 */
export function findHistoryNumber(history: readonly CallTask[], targetName: string): string | null {
  const key = normalizeName(targetName);
  const latest = history.find((task) => normalizeName(task.targetName) === key);
  if (!latest) return null;
  const check = checkTargetNumber(latest.phoneNumber);
  return check.kind === "ok" ? check.e164 : null;
}
