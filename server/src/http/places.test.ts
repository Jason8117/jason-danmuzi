import { mkdtemp, readdir, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { Writable } from "node:stream";
import type { FastifyInstance } from "fastify";
import { afterEach, describe, expect, it, vi } from "vitest";
import { HeuristicBrain } from "../brain/heuristicBrain.js";
import type { CallTask } from "../domain/types.js";
import { EventBus } from "../events/eventBus.js";
import type { Logger } from "../logger.js";
import { KakaoLocalPlaceSearch } from "../places/kakaoLocalPlaceSearch.js";
import { createPlaceSearch, type PlaceSearch } from "../places/placeSearch.js";
import { SimulatedPlaceSearch } from "../places/simulatedPlaceSearch.js";
import type { PlaceQuery, PlaceSearchProvider } from "../places/types.js";
import { SimulatedCallProvider } from "../providers/simulatedProvider.js";
import { CallService } from "../services/callService.js";
import { InMemoryTaskStore, JsonFileTaskStore, type TaskStore } from "../store/taskStore.js";
import { type AppDeps, buildApp } from "./app.js";

const TOKEN = "test-token";
const auth = { authorization: `Bearer ${TOKEN}` };

const apps: FastifyInstance[] = [];
const dirs: string[] = [];

afterEach(async () => {
  vi.restoreAllMocks();
  await Promise.all(apps.splice(0).map((app) => app.close()));
  await Promise.all(dirs.splice(0).map((dir) => rm(dir, { recursive: true, force: true })));
});

async function makeApp(
  places: PlaceSearch | undefined,
  options: { store?: TaskStore; bus?: EventBus; logger?: AppDeps["logger"] } = {},
) {
  const bus = options.bus ?? new EventBus();
  const calls = new CallService(options.store ?? new InMemoryTaskStore(), bus, new HeuristicBrain(), new SimulatedCallProvider(200), {
    maxConcurrentCalls: 1,
    maxCallsPerDay: 10,
    approvalTimeoutMs: 2000,
    maxCallDurationMs: 60_000,
  });
  const app = await buildApp({
    config: { API_TOKEN: TOKEN, CORS_ORIGINS: undefined, provider: "simulated", llm: "heuristic" },
    calls,
    bus,
    places,
    logger: options.logger ?? false,
  });
  apps.push(app);
  return app;
}

const search = (app: FastifyInstance, payload: unknown, headers: Record<string, string> = auth) =>
  app.inject({ method: "POST", url: "/v1/places/search", headers, payload: payload as object });

describe("POST /v1/places/search (SPEC-PLACE-001)", () => {
  // AC-002 / REQ-002
  it("POST /v1/places/search validates and answers in the documented shape", async () => {
    const app = await makeApp(createPlaceSearch(new SimulatedPlaceSearch()));

    const noToken = await search(app, { query: "파스타" }, {});
    expect(noToken.statusCode).toBe(401);
    expect(noToken.json().error).toBe("unauthorized");

    const longQuery = "가".repeat(101);
    for (const payload of [{ query: "   " }, { query: longQuery }, { query: "파스타", near: { lat: 91, lng: 0 } }]) {
      const res = await search(app, payload);
      expect(res.statusCode).toBe(400);
      expect(res.json().error).toBe("invalid_request");
      expect(res.json().message).not.toContain(longQuery.slice(0, 10));
      expect(res.json().message).not.toContain("91");
    }

    const plain = await search(app, { query: "파스타" });
    expect(plain.statusCode).toBe(200);
    expect(plain.headers["cache-control"]).toBe("no-store");
    const body = plain.json<{ source: string; places: Array<Record<string, unknown>> }>();
    expect(Object.keys(body).sort()).toEqual(["places", "source"]);
    expect(body.source).toBe("simulated");
    expect(body.places).toHaveLength(5);
    for (const place of body.places) {
      expect(Object.keys(place).sort()).toEqual(["address", "category", "distanceM", "id", "name", "phone", "phoneCheck", "phoneNumber"]);
      expect(place.distanceM).toBeNull();
    }

    const near = await search(app, { query: "파스타", near: { lat: 37.5, lng: 127.0 } });
    expect(near.statusCode).toBe(200);
    const distances = near.json<{ places: Array<{ distanceM: number }> }>().places.map((p) => p.distanceM);
    expect(distances.every((d) => typeof d === "number")).toBe(true);
    expect([...distances].sort((a, b) => a - b)).toEqual(distances);
  });

  it("hands the provider the documented query", async () => {
    const queries: PlaceQuery[] = [];
    const provider: PlaceSearchProvider = {
      name: "kakao",
      search: async (query) => {
        queries.push(query);
        return [];
      },
    };
    const app = await makeApp(createPlaceSearch(provider));
    await search(app, { query: "파스타" });
    await search(app, { query: "파스타", near: { lat: 37.5, lng: 127.0 } });
    await search(app, { query: "파스타", near: { lat: 37.4979, lng: 127.0276 }, extra: "dropped" });
    expect(queries).toEqual([
      { keyword: "파스타", limit: 5, radiusM: 2000 },
      { keyword: "파스타", limit: 5, radiusM: 2000, near: { lat: 37.5, lng: 127.0 } },
      { keyword: "파스타", limit: 5, radiusM: 2000, near: { lat: 37.498, lng: 127.028 } },
    ]);
  });

  // AC-004 / REQ-004 (design.md D4, epic D-8)
  it("place search results never reach storage, cache, events or logs", async () => {
    // Setup: a real JSON store in a temp directory that already holds one task.
    const dir = await mkdtemp(join(tmpdir(), "place-proof-"));
    dirs.push(dir);
    const dataFile = join(dir, "tasks.json");
    const existing: CallTask = {
      id: "6f1c1a52-1d7e-4c40-9e7f-5b0b0c9a1a01",
      version: 1,
      targetName: "기존 가게",
      phoneNumber: "+821012345678",
      goal: "영업시간 문의",
      language: "ko",
      requesterName: "김민수",
      status: "completed",
      transcript: [],
      approvals: [],
      provider: "simulated",
      createdAt: "2026-11-01T00:00:00.000Z",
      updatedAt: "2026-11-01T00:00:00.000Z",
    };
    await writeFile(dataFile, JSON.stringify([existing], null, 2));
    const quiet: Logger = { info: () => {}, warn: () => {}, error: () => {} };
    const store = await JsonFileTaskStore.open(dataFile, { logger: quiet });
    const fileBefore = await readFile(dataFile);
    const dirBefore = (await readdir(dir)).sort();

    // Every output channel is captured: Fastify's log stream, the adapter logger, console and stdout.
    const captured: string[] = [];
    const stream = new Writable({
      write(chunk, _encoding, done) {
        captured.push(String(chunk));
        done();
      },
    });
    const adapterLogger: Logger = {
      info: (obj, msg) => captured.push(JSON.stringify(["info", obj, msg])),
      warn: (obj, msg) => captured.push(JSON.stringify(["warn", obj, msg])),
      error: (obj, msg) => captured.push(JSON.stringify(["error", obj, msg])),
    };
    const record = (...args: unknown[]) => {
      captured.push(args.map((a) => (typeof a === "string" ? a : JSON.stringify(a))).join(" "));
    };
    vi.spyOn(console, "log").mockImplementation(record);
    vi.spyOn(console, "error").mockImplementation(record);
    vi.spyOn(console, "warn").mockImplementation(record);
    vi.spyOn(console, "info").mockImplementation(record);
    const realWrite = process.stdout.write.bind(process.stdout);
    vi.spyOn(process.stdout, "write").mockImplementation(((chunk: string | Uint8Array, ...rest: unknown[]) => {
      captured.push(String(chunk));
      return realWrite(chunk, ...(rest as []));
    }) as typeof process.stdout.write);

    const bus = new EventBus();
    let events = 0;
    bus.subscribe(() => {
      events += 1;
    });

    // Fake Kakao: records every call; the answer for each call is chosen by the step below.
    const markerDocument = {
      id: "PID-9c1e",
      place_name: "표식장소-7f3a",
      category_name: "음식점 > 양식",
      phone: "02-555-0142",
      address_name: "표식동 1",
      road_address_name: "표식로 77",
      x: "127.0276",
      y: "37.4979",
      place_url: "http://place.map.kakao.com/PID-9c1e",
      distance: "350",
    };
    const steps: Array<() => Promise<Response>> = [
      async () => new Response(JSON.stringify({ documents: [markerDocument] }), { status: 200 }),
      async () => new Response(JSON.stringify({ documents: [markerDocument] }), { status: 200 }),
      async () => new Response("표식오류본문-d00d", { status: 500 }),
      async () => {
        throw Object.assign(new TypeError("표식예외-e1e1"), {
          input: "https://dapi.kakao.com/v2/local/search/keyword.json?query=표식검색어-41b2",
          code: "ERR_INVALID_URL",
        });
      },
      async () => new Response(JSON.stringify({ documents: [{ place_name: "표식형식-f0f0", id: 7 }] }), { status: 200 }),
    ];
    const fetchCalls: Array<{ url: string; authorization: string | null }> = [];
    const fetch = (async (input: string | URL | Request, init?: RequestInit) => {
      fetchCalls.push({ url: String(input), authorization: new Headers(init?.headers).get("authorization") });
      return steps[fetchCalls.length - 1]!();
    }) as typeof globalThis.fetch;

    const places = createPlaceSearch(new KakaoLocalPlaceSearch({ apiKey: "test-kakao-key", fetch, logger: adapterLogger }));
    const app = await makeApp(places, { store, bus, logger: { stream } });

    const payload = { query: "표식검색어-41b2", near: { lat: 37.4979, lng: 127.0276 } };
    const responses = [];
    for (let i = 0; i < steps.length; i += 1) responses.push(await search(app, payload));
    await app.close();
    apps.splice(apps.indexOf(app), 1);
    // Give a debounced store write (300 ms) the chance to happen if anything had scheduled one.
    await new Promise((resolve) => setTimeout(resolve, 400));
    vi.restoreAllMocks();

    // Check 1: the first two answers reach the client.
    for (const res of responses.slice(0, 2)) {
      expect(res.statusCode).toBe(200);
      expect(res.body).toContain("표식장소-7f3a");
      expect(res.body).toContain("02-555-0142");
      expect(res.body).toContain("표식로 77");
    }

    // Check 2: no cache — the provider is called every time, with the documented request.
    expect(fetchCalls).toHaveLength(5);
    const firstUrl = new URL(fetchCalls[0]!.url);
    expect(fetchCalls[0]!.url.startsWith("https://dapi.kakao.com/v2/local/search/keyword.json")).toBe(true);
    expect(firstUrl.searchParams.get("x")).toBe("127.028");
    expect(firstUrl.searchParams.get("y")).toBe("37.498");
    expect(fetchCalls[0]!.authorization).toBe("KakaoAK test-kakao-key");
    for (const res of responses) expect(res.headers["cache-control"]).toBe("no-store");

    // Check 3: provider failures, unexpected errors and malformed answers are all a bare 502.
    for (const res of responses.slice(2)) {
      expect(res.statusCode).toBe(502);
      expect(res.json()).toEqual({ error: "place_search_failed", message: "Place search failed" });
    }

    // Check 4: no marker in any captured output or failure body.
    const everything = [...captured, ...responses.slice(2).map((res) => res.body)].join("\n");
    expect(captured.length).toBeGreaterThan(0);
    const markers = [
      "표식장소-7f3a",
      "02-555-0142",
      "+8225550142",
      "표식로 77",
      "PID-9c1e",
      "표식검색어-41b2",
      "37.4979",
      "127.0276",
      "37.498",
      "127.028",
      "표식오류본문-d00d",
      "표식예외-e1e1",
      "ERR_INVALID_URL",
      "표식형식-f0f0",
      "test-kakao-key",
    ];
    expect(markers.filter((marker) => everything.includes(marker))).toEqual([]);

    // Check 5: the store file and its directory are untouched; the store holds only the prepared task.
    expect(await readFile(dataFile)).toEqual(fileBefore);
    expect((await readdir(dir)).sort()).toEqual(dirBefore);
    expect(store.list().map((task) => task.id)).toEqual([existing.id]);

    // Check 6: nothing was published on the event bus.
    expect(events).toBe(0);
  });

  // AC-007 / REQ-007
  it("without a place provider the route answers 503", async () => {
    const off = await makeApp(undefined);
    const res = await search(off, { query: "파스타" });
    expect(res.statusCode).toBe(503);
    expect(res.headers["cache-control"]).toBe("no-store");
    expect(res.json()).toEqual({ error: "place_search_unavailable", message: "Place search is not available" });
    expect((await search(off, { query: "파스타" }, {})).statusCode).toBe(401);

    const on = await makeApp(createPlaceSearch(new SimulatedPlaceSearch()));
    for (const app of [off, on]) {
      expect((await app.inject({ method: "GET", url: "/v1/tasks", headers: auth })).json()).toEqual({ tasks: [] });
      expect((await app.inject({ method: "GET", url: "/v1/config", headers: auth })).json()).toEqual({
        provider: "simulated",
        brain: "heuristic",
        realCalls: false,
      });
    }
    const intake = (app: FastifyInstance) =>
      app.inject({ method: "POST", url: "/v1/intake", headers: auth, payload: { text: "라 파스타에 전화해서 금요일 예약해줘" } });
    expect((await intake(off)).json()).toEqual((await intake(on)).json());
  });
});
