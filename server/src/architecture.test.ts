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

  // AC-006 / REQ-007, REQ-008 (bridge part; the full providers/** rule lands with the scenario move in M5)
  // AC-012 / REQ-013
  it("no any for external data", () => {
    const anyPattern = /Record<string, any>|:\s*any\b|as any\b/;
    for (const file of ["providers/kat/katProvider.ts", "providers/realtimeBridge.ts"]) {
      const offending = source(file)
        .split("\n")
        .map((line, index) => `${file}:${index + 1}: ${line.trim()}`)
        .filter((line) => anyPattern.test(line));
      expect(offending).toEqual([]);
    }
  });

  it("the realtime bridge does not import brain", () => {
    expect(linesContaining(source("providers/realtimeBridge.ts"), ['from "../brain/', 'from "../../brain/'])).toEqual([]);
  });
});
