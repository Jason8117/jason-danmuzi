import { describe, expect, it, vi } from "vitest";
import type { Logger } from "../logger.js";
import { KakaoLocalPlaceSearch } from "./kakaoLocalPlaceSearch.js";
import { createPlaceSearch } from "./placeSearch.js";
import { PlaceSearchError, type PlaceQuery } from "./types.js";

const KEY = "test-kakao-key";

function capturingLogger() {
  const lines: unknown[] = [];
  const logger: Logger = {
    info: (obj, msg) => lines.push(["info", obj, msg]),
    warn: (obj, msg) => lines.push(["warn", obj, msg]),
    error: (obj, msg) => lines.push(["error", obj, msg]),
  };
  return { logger, lines };
}

interface FetchCall {
  url: string;
  headers: Record<string, string>;
  signal: AbortSignal | null | undefined;
}

function fakeFetch(answer: (init: RequestInit | undefined) => Promise<Response>) {
  const calls: FetchCall[] = [];
  const fetch = vi.fn(async (input: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: String(input), headers: Object.fromEntries(new Headers(init?.headers).entries()), signal: init?.signal });
    return answer(init);
  }) as unknown as typeof globalThis.fetch;
  return { fetch, calls };
}

const json = (body: unknown, status = 200) =>
  Promise.resolve(new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } }));

const doc = (overrides: Record<string, unknown> = {}) => ({
  id: "26338954",
  place_name: "라 파스타",
  category_name: "음식점 > 양식",
  category_group_code: "FD6",
  category_group_name: "음식점",
  phone: "02-111-0000",
  address_name: "서울 강남구 역삼동 1",
  road_address_name: "서울 강남구 테헤란로 12",
  x: "127.0276",
  y: "37.4979",
  place_url: "http://place.map.kakao.com/26338954",
  distance: "350",
  ...overrides,
});

const query: PlaceQuery = { keyword: "강남역 파스타집", limit: 5, radiusM: 2000 };
const signal = () => new AbortController().signal;

async function failure(promise: Promise<unknown>): Promise<PlaceSearchError> {
  const error = await promise.then(
    () => undefined,
    (e: unknown) => e,
  );
  expect(error).toBeInstanceOf(PlaceSearchError);
  return error as PlaceSearchError;
}

describe("kakao keyword search request, mapping and failures", () => {
  it("(1) sends the documented request without coordinates", async () => {
    const { fetch, calls } = fakeFetch(() => json({ documents: [doc()] }));
    const { logger } = capturingLogger();
    const places = await new KakaoLocalPlaceSearch({ apiKey: KEY, fetch, logger }).search(query, signal());

    const url = new URL(calls[0]!.url);
    expect(`${url.origin}${url.pathname}`).toBe("https://dapi.kakao.com/v2/local/search/keyword.json");
    expect(Object.fromEntries(url.searchParams)).toEqual({ query: "강남역 파스타집", size: "5", page: "1" });
    expect(calls[0]!.headers.authorization).toBe(`KakaoAK ${KEY}`);
    expect(places).toEqual([
      {
        providerPlaceId: "26338954",
        name: "라 파스타",
        category: "양식",
        address: "서울 강남구 테헤란로 12",
        distanceM: 350,
        phone: "02-111-0000",
      },
    ]);
  });

  it("(2) adds rounded coordinates, radius and distance order, and passes the signal through", async () => {
    const { fetch, calls } = fakeFetch(() => json({ documents: [] }));
    const { logger } = capturingLogger();
    const controller = new AbortController();
    await new KakaoLocalPlaceSearch({ apiKey: KEY, fetch, logger }).search(
      { ...query, near: { lat: 37.498, lng: 127.028 } },
      controller.signal,
    );
    const params = Object.fromEntries(new URL(calls[0]!.url).searchParams);
    expect(params).toEqual({
      query: "강남역 파스타집",
      size: "5",
      page: "1",
      x: "127.028",
      y: "37.498",
      radius: "2000",
      sort: "distance",
    });
    expect(calls[0]!.signal).toBe(controller.signal);
  });

  it("(3)(4) maps empty fields to null and drops nameless documents", async () => {
    const { fetch } = fakeFetch(() =>
      json({
        documents: [
          doc({ category_name: "음식점 > 양식 > 이탈리안", road_address_name: "", address_name: "서울 강남구 역삼동 1", phone: "", distance: "" }),
          doc({ id: "blank", place_name: "   " }),
          doc({ id: "bare", category_name: "", road_address_name: "", address_name: "" }),
        ],
      }),
    );
    const { logger } = capturingLogger();
    const places = await new KakaoLocalPlaceSearch({ apiKey: KEY, fetch, logger }).search(query, signal());
    expect(places.map((p) => p.providerPlaceId)).toEqual(["26338954", "bare"]);
    expect(places[0]).toMatchObject({ category: "이탈리안", address: "서울 강남구 역삼동 1", phone: null, distanceM: null });
    expect(places[1]).toMatchObject({ category: null, address: null });
  });

  it("(5)-(9) fails with a kind and logs only status and kind", async () => {
    const marker = "표식오류본문-d00d";
    const cases: Array<{ answer: (init: RequestInit | undefined) => Promise<Response>; kind: string; status?: number }> = [
      { answer: () => Promise.resolve(new Response(marker, { status: 401 })), kind: "status", status: 401 },
      { answer: () => Promise.reject(new Error(`socket ${marker}`)), kind: "network" },
      { answer: () => json({ documents: "x", note: marker }), kind: "format" },
      { answer: () => Promise.resolve(new Response(`not json ${marker}`, { status: 200 })), kind: "format" },
      { answer: () => Promise.reject(new TypeError(`표식예외-e1e1 ${marker}`)), kind: "network" },
    ];
    for (const { answer, kind, status } of cases) {
      const { fetch } = fakeFetch(answer);
      const { logger, lines } = capturingLogger();
      const error = await failure(new KakaoLocalPlaceSearch({ apiKey: KEY, fetch, logger }).search(query, signal()));
      expect(error.kind).toBe(kind);
      expect(error.status).toBe(status);
      expect(error.cause).toBeUndefined();
      expect(error.message).not.toContain(marker);
      expect(lines).toEqual([["warn", { provider: "kakao", kind, status }, "Place search failed"]]);
      const logged = JSON.stringify(lines);
      expect(logged).not.toContain(marker);
      expect(logged).not.toContain("강남역");
      expect(logged).not.toContain(KEY);
    }
  });

  it("(8) an aborted request is a timeout", async () => {
    const { fetch } = fakeFetch(
      (init) =>
        new Promise<Response>((_resolve, reject) => {
          init?.signal?.addEventListener("abort", () => reject(init.signal?.reason));
        }),
    );
    const { logger, lines } = capturingLogger();
    const controller = new AbortController();
    const pending = new KakaoLocalPlaceSearch({ apiKey: KEY, fetch, logger }).search(query, controller.signal);
    controller.abort();
    const error = await failure(pending);
    expect(error.kind).toBe("timeout");
    expect(lines).toEqual([["warn", { provider: "kakao", kind: "timeout", status: undefined }, "Place search failed"]]);
  });

  it("(10) the place search time limit stops a request that never ends", async () => {
    const { fetch } = fakeFetch(() => new Promise<Response>(() => {}));
    const { logger } = capturingLogger();
    const started = Date.now();
    const error = await failure(
      createPlaceSearch(new KakaoLocalPlaceSearch({ apiKey: KEY, fetch, logger }), { timeoutMs: 20 }).search({ query: "x" }),
    );
    expect(error.kind).toBe("timeout");
    expect(error.cause).toBeUndefined();
    expect(Date.now() - started).toBeLessThan(100);
  });

  it("uses the configured base URL", async () => {
    const { fetch, calls } = fakeFetch(() => json({ documents: [] }));
    const { logger } = capturingLogger();
    await new KakaoLocalPlaceSearch({ apiKey: KEY, baseUrl: "http://127.0.0.1:9/", fetch, logger }).search(query, signal());
    expect(calls[0]!.url.startsWith("http://127.0.0.1:9/v2/local/search/keyword.json?")).toBe(true);
  });
});
