import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

/** Reads a source file relative to src/, so the rules check the code as written. */
const source = (path: string) => readFileSync(new URL(`./${path}`, import.meta.url), "utf8");

/** Lines of `text` that contain any of `needles`, as "line: text" for readable failures. */
function linesContaining(text: string, needles: string[]): string[] {
  return text
    .split("\n")
    .map((line, index) => `${index + 1}: ${line.trim()}`)
    .filter((line) => needles.some((needle) => line.includes(needle)));
}

describe("module boundaries (SPEC-ARCH-001)", () => {
  // AC-001 / REQ-001
  it("http layer does not know concrete providers", () => {
    const app = source("http/app.ts");
    expect(
      linesContaining(app, ["providers/kat", "KatCallProvider", "simulatedProvider", "realtimeBridge", '"/kat/"', '=== "kat"']),
    ).toEqual([]);
  });
});
