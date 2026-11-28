import { readFileSync } from "node:fs";
import { afterEach, describe, expect, it, vi } from "vitest";
import { loadConfig } from "../config.js";
import { createContainer } from "../container.js";
import type { Logger } from "../logger.js";
import { InMemoryTaskStore } from "../store/taskStore.js";
import { createPlaceSearch } from "./placeSearch.js";
import { SimulatedPlaceSearch } from "./simulatedPlaceSearch.js";
import { PlaceSearchError, type PlaceQuery, type PlaceSearchProvider, type ProviderPlace } from "./types.js";

function place(overrides: Partial<ProviderPlace> = {}): ProviderPlace {
  return {
    providerPlaceId: "p-1",
    name: "라 파스타",
    category: "양식",
    address: "서울 강남구 테헤란로 12",
    distanceM: null,
    phone: "02-111-0000",
    ...overrides,
  };
}

/** A provider that records every query and answers with `answer`. */
function fakeProvider(answer: (query: PlaceQuery, signal: AbortSignal) => Promise<ProviderPlace[]>) {
  const queries: PlaceQuery[] = [];
  const provider: PlaceSearchProvider = {
    name: "kakao",
    search: (query, signal) => {
      queries.push(query);
      return answer(query, signal);
    },
  };
  return { provider, queries };
}

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("place search (SPEC-PLACE-001)", () => {
  // AC-003 / REQ-003
  it("every candidate number goes through checkTargetNumber", async () => {
    const phones = ["02-111-0000", "010 1234 5678", "", "119", "1588-0000", "12"];
    const { provider } = fakeProvider(async () =>
      phones.map((phone, i) => place({ providerPlaceId: `p-${i}`, phone: phone === "" ? null : phone })),
    );
    const result = await createPlaceSearch(provider).search({ query: "x" });
    expect(result.places.map((p) => p.phoneCheck)).toEqual(["ok", "ok", "missing", "blocked", "ok", "invalid"]);
    expect(result.places.map((p) => p.phoneNumber)).toEqual(["+8221110000", "+821012345678", null, null, "+15880000", null]);
    expect(result.places.map((p) => p.phone)).toEqual(["02-111-0000", "010 1234 5678", null, "119", "1588-0000", "12"]);
    expect(Object.keys(result.places[0]!).sort()).toEqual(
      ["address", "category", "distanceM", "id", "name", "phone", "phoneCheck", "phoneNumber"],
    );
    expect(result.places[0]!.id).toBe("p-0");
  });

  // AC-002 (query shape) / REQ-002
  it("fills the provider query with limit, radius and rounded coordinates", async () => {
    const { provider, queries } = fakeProvider(async () => []);
    const search = createPlaceSearch(provider);
    await search.search({ query: "  파스타  " });
    await search.search({ query: "파스타", near: { lat: 37.5, lng: 127.0 } });
    await search.search({ query: "파스타", near: { lat: 37.4979, lng: 127.0276 } });
    expect(queries[0]).toEqual({ keyword: "파스타", limit: 5, radiusM: 2000 });
    expect(queries[1]).toEqual({ keyword: "파스타", limit: 5, radiusM: 2000, near: { lat: 37.5, lng: 127.0 } });
    expect(queries[2]).toEqual({ keyword: "파스타", limit: 5, radiusM: 2000, near: { lat: 37.498, lng: 127.028 } });
  });

  // AC-005 (bare error part) / REQ-005
  it("search rejects only with a bare PlaceSearchError", async () => {
    const marker = "표식예외-e1e1";
    const failures: Array<() => Promise<ProviderPlace[]>> = [
      async () => {
        throw new PlaceSearchError("status", 401);
      },
      async () => {
        throw new PlaceSearchError("network");
      },
      async () => {
        throw new PlaceSearchError("format");
      },
      async () => {
        throw new PlaceSearchError("timeout");
      },
      async () => {
        throw Object.assign(new TypeError(marker), { input: `https://dapi.kakao.com/?query=${marker}`, code: "ERR_INVALID_URL" });
      },
      async () => {
        throw new Error(`plain ${marker}`);
      },
      // A provider answer that breaks normalization (not an array) must be wrapped too.
      async () => ({ length: 1, map: () => { throw new Error(marker); } }) as unknown as ProviderPlace[],
    ];
    for (const fail of failures) {
      const { provider } = fakeProvider(fail);
      const error = await createPlaceSearch(provider)
        .search({ query: marker })
        .then(
          () => undefined,
          (e: unknown) => e,
        );
      expect(error).toBeInstanceOf(PlaceSearchError);
      expect((error as Error).cause).toBeUndefined();
      expect((error as Error).message).not.toContain(marker);
      expect(JSON.stringify(error)).not.toContain(marker);
      expect(Object.keys(error as object).sort()).toEqual(expect.arrayContaining(["kind"]));
    }
  });

  it("keeps the provider status and kind but nothing else", async () => {
    const { provider } = fakeProvider(async () => {
      throw new PlaceSearchError("status", 403);
    });
    const error = (await createPlaceSearch(provider).search({ query: "x" }).catch((e: unknown) => e)) as PlaceSearchError;
    expect(error.kind).toBe("status");
    expect(error.status).toBe(403);

    const { provider: odd } = fakeProvider(async () => {
      throw new RangeError("boom");
    });
    const other = (await createPlaceSearch(odd).search({ query: "x" }).catch((e: unknown) => e)) as PlaceSearchError;
    expect(other.kind).toBe("unexpected");
    expect(other.status).toBeUndefined();
  });

  it("times out a provider that never answers", async () => {
    const { provider } = fakeProvider(() => new Promise<ProviderPlace[]>(() => {}));
    const started = Date.now();
    const error = (await createPlaceSearch(provider, { timeoutMs: 20 })
      .search({ query: "x" })
      .catch((e: unknown) => e)) as PlaceSearchError;
    expect(error).toBeInstanceOf(PlaceSearchError);
    expect(error.kind).toBe("timeout");
    expect(Date.now() - started).toBeLessThan(100);
  });

  it("passes an abort signal that fires on the time limit", async () => {
    let seen: AbortSignal | undefined;
    const { provider } = fakeProvider(
      (_query, signal) =>
        new Promise<ProviderPlace[]>((_resolve, reject) => {
          seen = signal;
          signal.addEventListener("abort", () => reject(new PlaceSearchError("timeout")));
        }),
    );
    await createPlaceSearch(provider, { timeoutMs: 10 }).search({ query: "x" }).catch(() => {});
    expect(seen?.aborted).toBe(true);
  });

  // AC-006 / REQ-006
  it("the simulated provider is deterministic and offline", async () => {
    const fetchSpy = vi.fn();
    vi.stubGlobal("fetch", fetchSpy);
    const search = createPlaceSearch(new SimulatedPlaceSearch());
    expect(search.source).toBe("simulated");

    const first = await search.search({ query: "파스타" });
    const second = await search.search({ query: "파스타" });
    const near = await search.search({ query: "파스타", near: { lat: 37.5, lng: 127.0 } });

    for (const result of [first, second, near]) {
      expect(result.source).toBe("simulated");
      expect(result.places).toHaveLength(5);
      expect(result.places.every((p) => p.name.startsWith("연습용"))).toBe(true);
      expect(new Set(result.places.map((p) => p.phoneCheck))).toEqual(new Set(["ok", "missing", "invalid"]));
    }
    expect(second).toEqual(first);
    expect(first.places.every((p) => p.distanceM === null)).toBe(true);

    const distances = near.places.map((p) => p.distanceM);
    expect(distances.every((d) => typeof d === "number")).toBe(true);
    expect([...distances].sort((a, b) => (a ?? 0) - (b ?? 0))).toEqual(distances);

    const other = await search.search({ query: "약국" });
    expect(other.places.map((p) => p.id)).not.toEqual(first.places.map((p) => p.id));
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  // AC-001 / REQ-001
  it("the container picks the place provider from the key and the call provider", () => {
    const quiet: Logger = { info: () => {}, warn: () => {}, error: () => {} };
    const kat = {
      KAT_API_KEY: "k",
      KAT_GROUP_ID: "g",
      KAT_FROM_NUMBER: "+827012345678",
      KAT_WEBHOOK_SECRET: "whsec_x",
      PUBLIC_BASE_URL: "https://example.test",
      OPENAI_API_KEY: "sk-test",
      API_TOKEN: "t",
    };
    const key = { KAKAO_REST_API_KEY: "kakao-test-key" };
    const assemble = (env: Record<string, string>) => {
      const config = loadConfig(env);
      return { config, container: createContainer(config, new InMemoryTaskStore(), quiet) };
    };

    const cases = [
      { env: { ...key, CALL_PROVIDER: "simulated" }, provider: "simulated", places: "kakao" },
      { env: { ...key, ...kat }, provider: "kat", places: "kakao" },
      { env: { CALL_PROVIDER: "simulated" }, provider: "simulated", places: "simulated" },
      // auto with KAT settings missing is assembled as simulated (config.ts), so it also gets practice places.
      { env: { CALL_PROVIDER: "auto", KAT_API_KEY: "k" }, provider: "simulated", places: "simulated" },
      { env: { ...kat }, provider: "kat", places: undefined },
    ] as const;
    for (const { env, provider, places } of cases) {
      const { config, container } = assemble(env);
      expect(config.provider).toBe(provider);
      expect(container.places?.source).toBe(places);
    }

    expect(loadConfig({}).KAKAO_REST_API_KEY).toBeUndefined();
    expect(loadConfig({ KAKAO_REST_API_KEY: "   " }).KAKAO_REST_API_KEY).toBeUndefined();
    expect(loadConfig({}).KAKAO_LOCAL_BASE_URL).toBe("https://dapi.kakao.com");

    // The startup log names the place search mode only, never the key.
    const index = readFileSync(new URL("../index.ts", import.meta.url), "utf8");
    expect(index).toContain("placeSearch:");
    expect(index).not.toContain("KAKAO_REST_API_KEY");
  });
});
