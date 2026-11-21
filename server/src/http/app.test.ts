import type { FastifyInstance } from "fastify";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { HeuristicBrain } from "../brain/heuristicBrain.js";
import type { CallTask } from "../domain/types.js";
import { EventBus } from "../events/eventBus.js";
import { SimulatedCallProvider } from "../providers/simulatedProvider.js";
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
});
