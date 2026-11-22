import { createHmac } from "node:crypto";
import type { FastifyInstance } from "fastify";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { HeuristicBrain } from "../brain/heuristicBrain.js";
import type { CallTask } from "../domain/types.js";
import { EventBus } from "../events/eventBus.js";
import { KatCallProvider } from "../providers/kat/katProvider.js";
import { SimulatedCallProvider } from "../providers/simulatedProvider.js";
import type { ProviderHttpRequest, ProviderRoutes } from "../providers/types.js";
import { CallService } from "../services/callService.js";
import { InMemoryTaskStore } from "../store/taskStore.js";
import { buildApp } from "./app.js";

const TOKEN = "test-token";
const auth = { authorization: `Bearer ${TOKEN}` };

async function waitFor(app: FastifyInstance, id: string, predicate: (t: CallTask) => boolean, timeoutMs = 5000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const task = (await app.inject({ method: "GET", url: `/v1/tasks/${id}`, headers: auth })).json<CallTask>();
    if (predicate(task)) return task;
    await new Promise((r) => setTimeout(r, 10));
  }
  throw new Error("Timed out waiting for task state");
}

describe("CallMate API", () => {
  let app: FastifyInstance;

  beforeEach(async () => {
    const bus = new EventBus();
    const calls = new CallService(new InMemoryTaskStore(), bus, new HeuristicBrain(), new SimulatedCallProvider(200), {
      maxConcurrentCalls: 1,
      maxCallsPerDay: 10,
      approvalTimeoutMs: 2000,
      maxCallDurationMs: 60_000,
    });
    app = await buildApp({
      config: { API_TOKEN: TOKEN, CORS_ORIGINS: undefined, provider: "simulated", llm: "heuristic" },
      calls,
      bus,
      logger: false,
    });
  });

  afterEach(() => app.close());

  const createTask = (goal = "금요일 저녁 7시 2명 예약해줘") =>
    app.inject({
      method: "POST",
      url: "/v1/tasks",
      headers: auth,
      payload: { targetName: "라 파스타", phoneNumber: "010-1234-5678", goal, requesterName: "김민수" },
    });

  it("rejects requests without the token", async () => {
    const res = await app.inject({ method: "GET", url: "/v1/tasks" });
    expect(res.statusCode).toBe(401);
  });

  it("validates phone numbers", async () => {
    const res = await app.inject({
      method: "POST",
      url: "/v1/tasks",
      headers: auth,
      payload: { targetName: "x", phoneNumber: "12", goal: "문의", requesterName: "김" },
    });
    expect(res.statusCode).toBe(400);
    expect(res.json().error).toBe("invalid_phone");
  });

  it("rejects emergency numbers with blocked_number", async () => {
    const res = await app.inject({
      method: "POST",
      url: "/v1/tasks",
      headers: auth,
      payload: { targetName: "x", phoneNumber: "119", goal: "문의", requesterName: "김" },
    });
    expect(res.statusCode).toBe(400);
    expect(res.json()).toEqual({ error: "blocked_number", message: "긴급·특수번호에는 전화할 수 없습니다." });
  });

  // SPEC-POLICY-001 audit F1: judged on the dialed digits, not on the +1 value they normalize to.
  it.each(["119 1234 5678", "+119 12345", "112-0000-0000"])(
    "rejects numbers whose dialed form starts with a blocked code: %s",
    async (phoneNumber) => {
      const res = await app.inject({
        method: "POST",
        url: "/v1/tasks",
        headers: auth,
        payload: { targetName: "x", phoneNumber, goal: "문의", requesterName: "김" },
      });
      expect(res.statusCode).toBe(400);
      expect(res.json()).toEqual({ error: "blocked_number", message: "긴급·특수번호에는 전화할 수 없습니다." });
    },
  );

  // SPEC-POLICY-001 owner decision: blocked callback numbers are dropped, the task is still created.
  it.each(["112-0000-0000", "119", "+82 112", "119 1234 5678"])(
    "drops a blocked callback number and still returns 201: %s",
    async (callbackNumber) => {
      const res = await app.inject({
        method: "POST",
        url: "/v1/tasks",
        headers: auth,
        payload: { targetName: "x", phoneNumber: "010-1234-5678", goal: "문의", requesterName: "김", callbackNumber },
      });
      expect(res.statusCode).toBe(201);
      expect(res.json<CallTask>().callbackNumber).toBeUndefined();
    },
  );

  it("still normalizes a normal callback number", async () => {
    const res = await app.inject({
      method: "POST",
      url: "/v1/tasks",
      headers: auth,
      payload: { targetName: "x", phoneNumber: "010-1234-5678", goal: "문의", requesterName: "김", callbackNumber: "010 9999 8888" },
    });
    expect(res.statusCode).toBe(201);
    expect(res.json<CallTask>().callbackNumber).toBe("+821099998888");
  });

  it("keeps invalid_request for schema violations", async () => {
    const res = await app.inject({
      method: "POST",
      url: "/v1/tasks",
      headers: auth,
      payload: { phoneNumber: "010-1234-5678", goal: "문의", requesterName: "김" },
    });
    expect(res.statusCode).toBe(400);
    expect(res.json().error).toBe("invalid_request");
  });

  it("plans, calls, pauses for approval and summarizes", async () => {
    const created = await createTask();
    expect(created.statusCode).toBe(201);
    const { id, phoneNumber } = created.json<CallTask>();
    expect(phoneNumber).toBe("+821012345678");

    const planned = await waitFor(app, id, (t) => t.status === "awaiting_approval");
    expect(planned.plan?.openingLine).toContain("AI 비서");
    expect(planned.plan?.approvalPoints.length).toBeGreaterThan(0);

    const started = await app.inject({ method: "POST", url: `/v1/tasks/${id}/approve-plan`, headers: auth, payload: {} });
    expect(started.statusCode).toBe(200);

    const waiting = await waitFor(app, id, (t) => t.approvals.some((a) => a.status === "pending"));
    expect(waiting.status).toBe("in_progress");
    const approval = waiting.approvals[0]!;

    const decided = await app.inject({
      method: "POST",
      url: `/v1/tasks/${id}/approvals/${approval.id}`,
      headers: auth,
      payload: { decision: "approve" },
    });
    expect(decided.json<CallTask>().approvals[0]?.status).toBe("approved");

    const done = await waitFor(app, id, (t) => t.status === "completed");
    expect(done.outcome?.result).toBe("unverified");
    expect(done.outcome?.source).toBe("heuristic");
    expect(done.transcript.some((t) => t.speaker === "callee")).toBe(true);
  });

  it("enforces the concurrent call limit", async () => {
    const first = (await createTask()).json<CallTask>();
    const second = (await createTask("영업시간 문의")).json<CallTask>();
    await waitFor(app, first.id, (t) => t.status === "awaiting_approval");
    await waitFor(app, second.id, (t) => t.status === "awaiting_approval");

    await app.inject({ method: "POST", url: `/v1/tasks/${first.id}/approve-plan`, headers: auth, payload: {} });
    const res = await app.inject({ method: "POST", url: `/v1/tasks/${second.id}/approve-plan`, headers: auth, payload: {} });
    expect(res.statusCode).toBe(429);
  });

  it("cancels a planned task and allows deleting it", async () => {
    const { id } = (await createTask()).json<CallTask>();
    await waitFor(app, id, (t) => t.status === "awaiting_approval");
    const canceled = await app.inject({ method: "POST", url: `/v1/tasks/${id}/cancel`, headers: auth });
    expect(canceled.json<CallTask>().status).toBe("canceled");
    const deleted = await app.inject({ method: "DELETE", url: `/v1/tasks/${id}`, headers: auth });
    expect(deleted.statusCode).toBe(204);
  });

  it("stores an optional approval comment and rejects duplicate decisions", async () => {
    const { id } = (await createTask()).json<CallTask>();
    await waitFor(app, id, (t) => t.status === "awaiting_approval");
    await app.inject({ method: "POST", url: `/v1/tasks/${id}/approve-plan`, headers: auth, payload: {} });

    const waiting = await waitFor(app, id, (t) => t.approvals.some((a) => a.status === "pending"));
    const approval = waiting.approvals[0]!;

    const decided = await app.inject({
      method: "POST",
      url: `/v1/tasks/${id}/approvals/${approval.id}`,
      headers: auth,
      payload: { decision: "approve", comment: "  1만 원까지만  " },
    });
    expect(decided.statusCode).toBe(200);
    const stored = decided.json<CallTask>().approvals[0];
    expect(stored?.status).toBe("approved");
    expect(stored?.userComment).toBe("1만 원까지만");

    const duplicate = await app.inject({
      method: "POST",
      url: `/v1/tasks/${id}/approvals/${approval.id}`,
      headers: auth,
      payload: { decision: "reject" },
    });
    expect(duplicate.statusCode).toBe(409);
    expect(duplicate.json().error).toBe("approval_closed");
  });

  it("rejects approval comments longer than 500 characters", async () => {
    const { id } = (await createTask()).json<CallTask>();
    await waitFor(app, id, (t) => t.status === "awaiting_approval");
    await app.inject({ method: "POST", url: `/v1/tasks/${id}/approve-plan`, headers: auth, payload: {} });
    const waiting = await waitFor(app, id, (t) => t.approvals.some((a) => a.status === "pending"));
    const approval = waiting.approvals[0]!;

    const tooLong = "가".repeat(501);
    const res = await app.inject({
      method: "POST",
      url: `/v1/tasks/${id}/approvals/${approval.id}`,
      headers: auth,
      payload: { decision: "approve", comment: tooLong },
    });
    expect(res.statusCode).toBe(400);
  });

  // SPEC-ARCH-001 AC-003 / REQ-003, REQ-021 (b)
  it("registers no provider routes in simulation mode", async () => {
    const status = await app.inject({ method: "POST", url: "/kat/status", payload: {} });
    const media = await app.inject({ method: "GET", url: "/kat/media" });
    expect(status.statusCode).toBe(404);
    expect(media.statusCode).toBe(404);
  });

  /** Creates a task, places the call and waits until the simulated callee's approval is pending. */
  const pendingApproval = async () => {
    const { id } = (await createTask()).json<CallTask>();
    await waitFor(app, id, (t) => t.status === "awaiting_approval");
    await app.inject({ method: "POST", url: `/v1/tasks/${id}/approve-plan`, headers: auth, payload: {} });
    const waiting = await waitFor(app, id, (t) => t.approvals.some((a) => a.status === "pending"));
    return { id, approvalId: waiting.approvals[0]!.id };
  };

  const decide = (id: string, approvalId: string, payload: Record<string, unknown>) =>
    app.inject({ method: "POST", url: `/v1/tasks/${id}/approvals/${approvalId}`, headers: auth, payload });

  // SPEC-APPROVAL-001 AC-004 (A) / REQ-003, REQ-005
  it("stores the masked approval comment", async () => {
    const { id, approvalId } = await pendingApproval();

    const res = await decide(id, approvalId, { decision: "approve", comment: "카드 1234 5678 9012 3456 말고 계좌이체" });

    expect(res.statusCode).toBe(200);
    const approval = res.json<CallTask>().approvals[0]!;
    expect(approval.status).toBe("approved");
    expect(approval.resolvedAt).toBeDefined();
    expect(approval.userComment).toBe("카드 [민감정보 삭제] 말고 계좌이체");
    expect(res.body).not.toContain("1234 5678 9012 3456");
    const stored = await app.inject({ method: "GET", url: `/v1/tasks/${id}`, headers: auth });
    expect(stored.body).not.toContain("1234 5678 9012 3456");
  });

  // SPEC-APPROVAL-001 AC-006 (6) / REQ-006
  it("records the guidance line once in a simulated call", async () => {
    const { id, approvalId } = await pendingApproval();

    await decide(id, approvalId, { decision: "approve", comment: "1만 원까지만" });

    const done = await waitFor(app, id, (t) => t.status === "completed");
    expect(done.transcript.filter((t) => t.text === "사용자 안내: 1만 원까지만")).toHaveLength(1);
  });

  // SPEC-APPROVAL-001 AC-001 / REQ-001: the 500 limit counts code points, before sanitization (protection test).
  const FAMILY = "👨‍👩‍👧"; // 1 grapheme, 5 code points
  it.each<[string, string | undefined, number, string | undefined]>([
    ["(1) no comment", undefined, 200, undefined],
    ["(2) blank comment", "   ", 200, undefined],
    ["(3) 500 syllables", "가".repeat(500), 200, "가".repeat(500)],
    ["(4) 501 syllables", "가".repeat(501), 400, undefined],
    ["(5) 100 family emoji = 500 code points", FAMILY.repeat(100), 200, FAMILY.repeat(100)],
    ["(6) 101 family emoji = 505 code points", FAMILY.repeat(101), 400, undefined],
  ])("counts approval comment length in code points: %s", async (_case, comment, statusCode, stored) => {
    const { id, approvalId } = await pendingApproval();

    const res = await decide(id, approvalId, comment === undefined ? { decision: "approve" } : { decision: "approve", comment });

    expect(res.statusCode).toBe(statusCode);
    if (statusCode === 400) {
      // The body also carries the schema message (app.ts error handler); the code is what clients branch on.
      expect(res.json()).toMatchObject({ error: "invalid_request" });
      return;
    }
    expect(res.json<CallTask>().approvals[0]!.userComment).toBe(stored);
  });
});

describe("/v1/stream (SPEC-ARCH-001 AC-019)", () => {
  let app: FastifyInstance;
  beforeEach(async () => {
    app = await buildApp({
      config: { API_TOKEN: TOKEN, CORS_ORIGINS: undefined, provider: "simulated", llm: "heuristic" },
      ...serviceDeps(),
      logger: false,
    });
    await app.ready();
  });
  afterEach(() => app.close());

  /** Opens the stream and records every message from the first one on. */
  async function connect(path: string, headers: Record<string, string> = {}) {
    const messages: Record<string, any>[] = [];
    const ws = await app.injectWS(path, { headers }, {
      onInit: (socket) => socket.on("message", (data) => messages.push(JSON.parse(data.toString()) as Record<string, any>)),
    });
    return { ws, messages };
  }

  const create = () =>
    app.inject({
      method: "POST",
      url: "/v1/tasks",
      headers: auth,
      payload: { targetName: "라 파스타", phoneNumber: "010-1234-5678", goal: "영업시간 문의", requesterName: "김민수" },
    });

  it("streams snapshots and task updates", async () => {
    const first = (await create()).json<CallTask>();

    // (a) header token: the first message is the snapshot
    const header = await connect("/v1/stream", auth);
    await vi.waitFor(() => expect(header.messages.length).toBeGreaterThan(0));
    expect(header.messages[0]!.type).toBe("snapshot");
    expect(header.messages[0]!.tasks.map((t: CallTask) => t.id)).toEqual([first.id]);

    // (b) a task created afterwards arrives as task.updated
    const second = (await create()).json<CallTask>();
    await vi.waitFor(() =>
      expect(header.messages.some((m) => m.type === "task.updated" && m.task.id === second.id)).toBe(true),
    );
    expect(new Set(header.messages.map((m) => m.type))).toEqual(new Set(["snapshot", "task.updated"]));
    header.ws.terminate();

    // (c) ?token= query: the same first message
    const query = await connect(`/v1/stream?token=${TOKEN}`);
    await vi.waitFor(() => expect(query.messages.length).toBeGreaterThan(0));
    expect(query.messages[0]!.type).toBe("snapshot");
    expect(query.messages[0]!.tasks.map((t: CallTask) => t.id).sort()).toEqual([first.id, second.id].sort());
    query.ws.terminate();
  });

  // (d)
  it("rejects stream connections without a token", async () => {
    await expect(app.injectWS("/v1/stream")).rejects.toThrow("Unexpected server response: 401");
    await expect(app.injectWS("/v1/stream?token=wrong")).rejects.toThrow("Unexpected server response: 401");
  });
});

const KAT_SECRET = "whsec_" + "ef".repeat(32);

function katForRoutes() {
  const fetchFn = (async () =>
    new Response(JSON.stringify({ result: { callId: "c-1" } }), { status: 200 })) as typeof fetch;
  return new KatCallProvider(
    {
      apiKey: "key",
      groupId: "g-1",
      fromNumber: "07012345678",
      webhookSecret: KAT_SECRET,
      publicBaseUrl: "https://example.test",
      apiBaseUrl: "https://kat.test/v1",
      realtime: { apiKey: "sk", model: "m", voice: "v" },
      fetch: fetchFn,
      maxCallDurationSec: 600,
    },
    { info: () => {}, warn: () => {} },
  );
}

function signedHeaders(rawBody: string) {
  const timestamp = String(Math.floor(Date.now() / 1000));
  const signature = "v1=" + createHmac("sha256", KAT_SECRET).update(`${timestamp}.`).update(rawBody).digest("hex");
  return { "content-type": "application/json", "x-webhook-timestamp": timestamp, "x-webhook-signature": signature };
}

function serviceDeps() {
  const bus = new EventBus();
  const calls = new CallService(new InMemoryTaskStore(), bus, new HeuristicBrain(), new SimulatedCallProvider(200), {
    maxConcurrentCalls: 1,
    maxCallsPerDay: 10,
    approvalTimeoutMs: 2000,
    maxCallDurationMs: 60_000,
  });
  return { bus, calls };
}

/** Builds the app the way container.ts wires a KAT deployment. */
function buildKatApp(kat: KatCallProvider) {
  return buildApp({
    config: { API_TOKEN: TOKEN, CORS_ORIGINS: undefined, provider: "kat", llm: "heuristic" },
    ...serviceDeps(),
    providerRoutes: kat.routes(),
    realCalls: true,
    logger: false,
  });
}

describe("provider routes (SPEC-ARCH-001)", () => {
  let app: FastifyInstance | undefined;
  afterEach(() => app?.close());

  // AC-004 / REQ-004, REQ-005 — protection test, written before the route contract existed.
  it("keeps the KAT webhook contract", async () => {
    app = await buildKatApp(katForRoutes());
    const rawBody = '{"data":{"type":"media_stream.call.ringing","callId":"c-unknown"}}';

    const unsigned = await app.inject({
      method: "POST",
      url: "/kat/status",
      headers: { "content-type": "application/json" },
      payload: rawBody,
    });
    expect(unsigned.statusCode).toBe(401);
    expect(unsigned.json()).toEqual({ error: "invalid_signature" });

    // Signed, and no API token: /v1/* auth does not apply to provider routes.
    const signed = await app.inject({ method: "POST", url: "/kat/status", headers: signedHeaders(rawBody), payload: rawBody });
    expect(signed.statusCode).toBe(204);
    expect(signed.body).toBe("");

    // The signature covers the exact raw bytes, query string or not.
    const withQuery = await app.inject({
      method: "POST",
      url: "/kat/status?x=1",
      headers: signedHeaders(rawBody),
      payload: rawBody,
    });
    expect(withQuery.statusCode).toBe(204);
  });

  // AC-009 / REQ-010 (OD-2 DEFAULT): a signed but malformed body is still accepted with 204 and ignored.
  it("answers signed but malformed status webhooks with 204", async () => {
    app = await buildKatApp(katForRoutes());
    for (const rawBody of ['{"data":{"type":123}}', '{"data":"x"}', "[]"]) {
      const res = await app.inject({ method: "POST", url: "/kat/status", headers: signedHeaders(rawBody), payload: rawBody });
      expect(res.statusCode).toBe(204);
    }
  });

  // AC-005 / REQ-006 — the protected values.
  it("serves /v1/config values for simulation and KAT deployments", async () => {
    const { bus, calls } = serviceDeps();
    app = await buildApp({
      config: { API_TOKEN: TOKEN, CORS_ORIGINS: undefined, provider: "simulated", llm: "heuristic" },
      calls,
      bus,
      logger: false,
    });
    expect((await app.inject({ method: "GET", url: "/v1/config", headers: auth })).json()).toEqual({
      provider: "simulated",
      brain: "heuristic",
      realCalls: false,
    });
    await app.close();

    app = await buildKatApp(katForRoutes());
    expect((await app.inject({ method: "GET", url: "/v1/config", headers: auth })).json()).toEqual({
      provider: "kat",
      brain: "heuristic",
      realCalls: true,
    });
  });

  // AC-005 / REQ-006 — realCalls comes from the wiring, not from comparing provider names.
  it("serves /v1/config from wiring-provided provider info", async () => {
    app = await buildApp({
      config: { API_TOKEN: TOKEN, CORS_ORIGINS: undefined, provider: "kat", llm: "heuristic" },
      ...serviceDeps(),
      realCalls: false,
      logger: false,
    });
    expect((await app.inject({ method: "GET", url: "/v1/config", headers: auth })).json()).toEqual({
      provider: "kat",
      brain: "heuristic",
      realCalls: false,
    });
  });

  // AC-002 / REQ-002, REQ-004, REQ-021 (a)
  it("registers provider-declared routes with raw bodies", async () => {
    const received: ProviderHttpRequest[] = [];
    const attached: string[] = [];
    const routes: ProviderRoutes = {
      http: [
        {
          method: "POST",
          path: "/fake/hook",
          rawBody: true,
          handle: (req) => {
            received.push(req);
            return { status: 202, body: { ok: true } };
          },
        },
        {
          method: "POST",
          path: "/fake/plain",
          rawBody: false,
          handle: async (req) => {
            received.push(req);
            return { status: 204 };
          },
        },
      ],
      sockets: [{ path: "/fake/ws", attach: (_socket, req) => attached.push(req.url ?? "") }],
    };
    app = await buildApp({
      config: { API_TOKEN: TOKEN, CORS_ORIGINS: undefined, provider: "simulated", llm: "heuristic" },
      ...serviceDeps(),
      providerRoutes: routes,
      logger: false,
    });
    const raw = '{"a": 1,  "b":2}';

    const hook = await app.inject({ method: "POST", url: "/fake/hook", headers: { "content-type": "application/json" }, payload: raw });
    expect(hook.statusCode).toBe(202);
    expect(hook.json()).toEqual({ ok: true });
    expect(received[0]?.rawBody).toBe(raw);
    expect(received[0]?.body).toEqual({ a: 1, b: 2 });
    expect(received[0]?.headers["content-type"]).toBe("application/json");

    await app.inject({ method: "POST", url: "/fake/hook?x=1", headers: { "content-type": "application/json" }, payload: raw });
    expect(received[1]?.rawBody).toBe(raw);

    const plain = await app.inject({ method: "POST", url: "/fake/plain", headers: { "content-type": "application/json" }, payload: raw });
    expect(plain.statusCode).toBe(204);
    expect(received[2]?.rawBody).toBeUndefined();
    expect(received[2]?.body).toEqual({ a: 1, b: 2 });

    await app.ready();
    const ws = await app.injectWS("/fake/ws?y=2");
    ws.terminate();
    expect(attached).toEqual(["/fake/ws?y=2"]);
  });

  // Edge case (acceptance.md): a provider route under /v1/ would bypass the API-token hook.
  it("refuses provider routes under /v1/", async () => {
    await expect(
      buildApp({
        config: { API_TOKEN: TOKEN, CORS_ORIGINS: undefined, provider: "simulated", llm: "heuristic" },
        ...serviceDeps(),
        providerRoutes: {
          http: [{ method: "POST", path: "/v1/hook", rawBody: false, handle: () => ({ status: 204 }) }],
          sockets: [],
        },
        logger: false,
      }),
    ).rejects.toThrow("/v1/");
  });
});

describe("autoStart (SPEC-INTAKE-001)", () => {
  let app: FastifyInstance;
  let store: InMemoryTaskStore;

  beforeEach(async () => {
    const bus = new EventBus();
    store = new InMemoryTaskStore();
    const calls = new CallService(store, bus, new HeuristicBrain(), new SimulatedCallProvider(200), {
      maxConcurrentCalls: 1,
      maxCallsPerDay: 10,
      approvalTimeoutMs: 2000,
      maxCallDurationMs: 60_000,
    });
    app = await buildApp({
      config: { API_TOKEN: TOKEN, CORS_ORIGINS: undefined, provider: "simulated", llm: "heuristic" },
      calls,
      bus,
      logger: false,
    });
  });

  afterEach(() => app.close());

  const body = { targetName: "라 파스타", phoneNumber: "010-1234-5678", goal: "영업시간 문의", requesterName: "김민수" };
  const post = (payload: object) => app.inject({ method: "POST", url: "/v1/tasks", headers: auth, payload });

  // AC-013 / REQ-013
  it("accepts an optional autoStart flag", async () => {
    const withFlag = await post({ ...body, autoStart: true });
    expect(withFlag.statusCode).toBe(201);
    expect(withFlag.json<CallTask>().autoStart).toBe(true);

    const without = await post({ ...body, goal: "가격 문의" });
    expect(without.statusCode).toBe(201);
    expect(Object.keys(without.json<CallTask>())).not.toContain("autoStart");

    const wrongType = await post({ ...body, autoStart: "yes" });
    expect(wrongType.statusCode).toBe(400);
    expect(wrongType.json().error).toBe("invalid_request");

    const before = store.list().length;
    const blocked = await post({ ...body, phoneNumber: "119", autoStart: true });
    expect(blocked.statusCode).toBe(400);
    expect(blocked.json().error).toBe("blocked_number");
    expect(store.list().length).toBe(before);
  });

  // AC-014 / REQ-014 (integration)
  it("auto-starts a simulated call without approve-plan", async () => {
    // The reservation scenario is the one whose simulated script asks for an approval.
    const { id } = (await post({ ...body, goal: "금요일 저녁 7시 2명 예약해줘", autoStart: true })).json<CallTask>();
    const waiting = await waitFor(app, id, (t) => t.approvals.some((a) => a.status === "pending"));
    expect(waiting.status).toBe("in_progress");
    expect(waiting.startedAt).toBeDefined();
    expect(waiting.plan?.openingLine).toContain("AI 비서");
  });
});

/** Counts intake interpretations so a test can prove none started. */
class CountingIntakeBrain extends HeuristicBrain {
  intakeCalls = 0;
  override async draftIntake(maskedText: string, language: "ko" | "en") {
    this.intakeCalls++;
    return super.draftIntake(maskedText, language);
  }
}

describe("POST /v1/intake (SPEC-INTAKE-001)", () => {
  let app: FastifyInstance;
  let calls: CallService;
  let brain: CountingIntakeBrain;

  beforeEach(async () => {
    const bus = new EventBus();
    brain = new CountingIntakeBrain();
    calls = new CallService(new InMemoryTaskStore(), bus, brain, new SimulatedCallProvider(200), {
      maxConcurrentCalls: 1,
      maxCallsPerDay: 10,
      approvalTimeoutMs: 2000,
      maxCallDurationMs: 60_000,
    });
    app = await buildApp({
      config: { API_TOKEN: TOKEN, CORS_ORIGINS: undefined, provider: "simulated", llm: "heuristic" },
      calls,
      bus,
      logger: false,
    });
  });

  afterEach(() => app.close());

  const intake = (payload: object, headers: Record<string, string> = auth) =>
    app.inject({ method: "POST", url: "/v1/intake", headers, payload });

  // AC-001 / REQ-001, REQ-012
  it.each([
    {
      name: "(1) a request with a name and a number",
      payload: { text: "라 파스타에 전화해서 02-123-4567로 금요일 7시 2명 예약" },
      status: 200,
      expect: {
        targetName: "라 파스타",
        phoneNumber: "+8221234567",
        phoneSource: "text",
        numberIssue: null,
        source: "heuristic",
        language: "ko",
        missing: [],
      },
    },
    {
      name: "(2) English, nothing to find",
      payload: { text: "금요일 7시 예약", language: "en" },
      status: 200,
      expect: { language: "en", missing: ["targetName", "phoneNumber"] },
    },
    { name: "(3) blank text", payload: { text: "   " }, status: 400, error: "invalid_request" },
    { name: "(4) 1001 characters", payload: { text: "가".repeat(1001) }, status: 400, error: "invalid_request" },
    { name: "(5) unsupported language", payload: { text: "예약", language: "fr" }, status: 400, error: "invalid_request" },
    {
      name: "(6) no token",
      payload: { text: "라 파스타에 전화해서 02-123-4567로 금요일 7시 2명 예약" },
      headers: {},
      status: 401,
      error: "unauthorized",
    },
  ])("drafts an intake without creating a task $name", async ({ payload, headers, status, expect: fields, error }) => {
    const res = await intake(payload, headers);
    expect(res.statusCode).toBe(status);
    const body = res.json();

    if (error) {
      expect(body.error).toBe(error);
    } else {
      expect(Object.keys(body).sort()).toEqual(["draft", "missing", "numberIssue", "phoneSource", "source"]);
      expect(Object.keys(body.draft).sort()).toEqual(["conditions", "context", "goal", "language", "phoneNumber", "targetName"]);
      const { language, targetName, phoneNumber, missing, ...top } = fields!;
      expect(body.draft.language).toBe(language);
      expect(body.missing).toEqual(missing);
      if (targetName !== undefined) expect(body.draft.targetName).toBe(targetName);
      if (phoneNumber !== undefined) expect(body.draft.phoneNumber).toBe(phoneNumber);
      expect(body).toMatchObject(top);
    }
    expect(calls.list()).toEqual([]);
  });

  // AC-002 / REQ-002
  it("refuses intake while shutting down", async () => {
    calls.beginShutdown();

    const refused = await intake({ text: "라 파스타에 전화해서 7시 예약" });
    expect(refused.statusCode).toBe(503);
    expect(refused.json()).toEqual({ error: "shutting_down", message: "서버가 종료 중입니다. 잠시 후 다시 시도해 주세요." });
    expect(brain.intakeCalls).toBe(0);

    const invalid = await intake({ text: "" });
    expect(invalid.statusCode).toBe(400);
    expect(invalid.json().error).toBe("invalid_request");
  });
});
