import { existsSync, readdirSync, readFileSync } from "node:fs";
import { sep } from "node:path";
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

  // AC-006 / REQ-007
  it("providers do not import brain", () => {
    const files = readdirSync(new URL("./providers/", import.meta.url), { recursive: true, encoding: "utf8" })
      .filter((file) => file.endsWith(".ts") && !file.endsWith(".test.ts"))
      .map((file) => `providers/${file.split(sep).join("/")}`);
    expect(files).toContain("providers/kat/katProvider.ts");

    const offending = files.flatMap((file) =>
      linesContaining(source(file), ['from "../brain/', 'from "../../brain/']).map((line) => `${file}:${line}`),
    );
    expect(offending).toEqual([]);
    // No re-export left behind for providers to reach through.
    expect(existsSync(new URL("./brain/scenario.ts", import.meta.url))).toBe(false);
  });
});

/** Non-test source files under places/, as paths relative to src/. */
function placesFiles(): string[] {
  return readdirSync(new URL("./places/", import.meta.url), { recursive: true, encoding: "utf8" })
    .filter((file) => file.endsWith(".ts") && !file.endsWith(".test.ts"))
    .map((file) => `places/${file.split(sep).join("/")}`);
}

/** Module specifiers a file imports or re-exports. */
function importedModules(text: string): string[] {
  return [...text.matchAll(/(?:^|\n)\s*(?:import|export)\b[^;]*?\bfrom\s+"([^"]+)"|(?:^|\n)\s*import\s+"([^"]+)"/g)].map(
    (match) => match[1] ?? match[2] ?? "",
  );
}

describe("place search boundaries (SPEC-PLACE-001)", () => {
  // AC-008 / REQ-008, REQ-004 (design.md D2 rules 1 and 2)
  it("places module stays stateless and out of store, brain and services", () => {
    const files = placesFiles();
    expect(files).toContain("places/kakaoLocalPlaceSearch.ts");
    expect(files).toContain("places/placeSearch.ts");

    const allowed = (specifier: string) =>
      specifier.startsWith("./") || specifier.startsWith("../domain/") || specifier === "../logger.js" || specifier === "zod";
    const badImports = files.flatMap((file) =>
      importedModules(source(file))
        .filter((specifier) => !allowed(specifier))
        .map((specifier) => `${file}: ${specifier}`),
    );
    expect(badImports).toEqual([]);

    const forbidden = files.flatMap((file) =>
      linesContaining(source(file), [
        'from "../store/',
        'from "../brain/',
        'from "../services/',
        '"node:fs',
        '"fs"',
        "new Map(",
        "new Set(",
        "WeakMap",
        "localStorage",
      ]).map((line) => `${file}:${line}`),
    );
    expect(forbidden).toEqual([]);

    // No module-level mutable state (a cache would need one).
    const moduleLets = files.flatMap((file) =>
      source(file)
        .split("\n")
        .map((line, index) => `${file}:${index + 1}: ${line}`)
        .filter((line) => /^[^:]+:\d+: (export )?(let|var) /.test(line)),
    );
    expect(moduleLets).toEqual([]);
  });

  // AC-008 / REQ-008 (design.md D2 rule 3)
  it("http layer does not know concrete place providers", () => {
    expect(
      linesContaining(source("http/app.ts"), ["kakaoLocal", "KakaoLocalPlaceSearch", "simulatedPlaceSearch", "SimulatedPlaceSearch", "dapi.kakao.com"]),
    ).toEqual([]);
  });

  // AC-008 / REQ-008 (design.md D2 rule 4)
  it("no any for place provider data", () => {
    const anyPattern = /Record<string, any>|:\s*any\b|as any\b/;
    const offending = placesFiles().flatMap((file) =>
      source(file)
        .split("\n")
        .map((line, index) => `${file}:${index + 1}: ${line.trim()}`)
        .filter((line) => anyPattern.test(line)),
    );
    expect(offending).toEqual([]);
  });
});
