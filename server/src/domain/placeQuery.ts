import { PHONE_PLACEHOLDER, stripPhoneNumbers } from "./intake.js";

// SPEC-PLACE-001 design.md D6: the place search term from a one-line request. The same rules and the same example
// table back the app's fallback (packages/kolbi_core/lib/src/places/place_intent.dart); change both together.

const NEAR_WORDS = ["근처", "주변"];
const TIME_WORDS = [
  "오늘", "내일", "모레", "이번", "다음", "오전", "오후", "아침", "점심", "저녁", "밤", "새벽",
  "주말", "평일", "이따", "이따가", "지금", "주", "이번주", "다음주",
];
const WHEN_PARTICLES = ["에서", "에게", "에는", "에", "엔", "은", "는", "까지", "부터", "쯤"];
const REQUEST_PREFIXES = ["예약", "문의", "확인", "물어봐", "알아봐", "전화", "찾아", "부탁"];
const REQUEST_WORDS = ["해", "해줘", "해주세요", "중에", "있는", "몇"];
const REQUEST_SUFFIXES = ["까지", "하는지", "있는지", "줘", "주세요"];
const PLACE_PARTICLES = ["에서", "에게", "에"];
const TRAILING_PARTICLES = ["의", "을", "를"];
const MAX_CODE_POINTS = 30;
/** "7시", "3시반에", "24일", "12월", "2명". */
const COUNT_WORD = /^\d+(시|분|명|일|월|주)/;
/** An hour ("3시") that a spaced "반" ("3시 반에") belongs to. */
const HOUR_WORD = /^\d+시$/;

const stripSuffix = (word: string, suffixes: readonly string[]): string => {
  const suffix = suffixes.find((s) => word.length > s.length && word.endsWith(s));
  return suffix ? word.slice(0, -suffix.length) : word;
};

const isNear = (word: string) => NEAR_WORDS.some((near) => word.startsWith(near));

/** A date, time or head count, with or without one trailing particle. */
function isWhen(word: string): boolean {
  const base = stripSuffix(word, WHEN_PARTICLES);
  return TIME_WORDS.includes(word) || TIME_WORDS.includes(base) || COUNT_WORD.test(word) || stripSuffix(word, PLACE_PARTICLES).endsWith("요일");
}

/** A time word at `i`, including a spaced half hour ("3시 반에", "10시 반쯤") right after an hour. */
const isWhenAt = (list: readonly string[], i: number) =>
  isWhen(list[i]!) || (i > 0 && HOUR_WORD.test(list[i - 1]!) && stripSuffix(list[i]!, WHEN_PARTICLES) === "반");

const isRequest = (word: string) =>
  REQUEST_PREFIXES.some((p) => word.startsWith(p)) || REQUEST_WORDS.includes(word) || REQUEST_SUFFIXES.some((s) => word.endsWith(s));

const words = (text: string) => text.trim().split(/\s+/).filter((w) => w !== "");

const cap = (text: string) => Array.from(text).slice(0, MAX_CODE_POINTS).join("");

function fromSentence(text: string): string {
  const comma = text.indexOf(",");
  const head = comma === -1 ? text : text.slice(0, comma);
  const kept: string[] = [];
  const list = words(head);
  for (const [i, word] of list.entries()) {
    if (word.includes(PHONE_PLACEHOLDER)) continue;
    if (isNear(word) || word.startsWith("가까운") || word === "내" || word === "여기" || isWhenAt(list, i)) continue;
    if (isRequest(word)) break;
    const stripped = stripSuffix(word, PLACE_PARTICLES);
    kept.push(stripped);
    if (stripped !== word) break;
  }
  return kept.map((w) => stripSuffix(w, TRAILING_PARTICLES)).join(" ");
}

/** A brain-provided term without numbers or "근처"/"주변" words, spaces tidied, at most 30 code points; "" if none. */
export function cleanPlaceQuery(value: string | undefined): string {
  if (value === undefined) return "";
  const cleaned = words(stripPhoneNumbers(value)).filter((w) => !isNear(w));
  return cap(cleaned.join(" "));
}

/**
 * The deterministic place search term: the name when there is one, otherwise the sentence rule. Null when empty.
 * `text` is the number-masked request; `targetName` is the name the service settled on.
 */
export function placeQueryFor(text: string, targetName: string | null): string | null {
  const name = targetName?.trim();
  const query = cap(name ? words(name).filter((w) => !isNear(w)).join(" ") : fromSentence(text));
  return query === "" ? null : query;
}
