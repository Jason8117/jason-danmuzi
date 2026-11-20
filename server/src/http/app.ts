import { Readable } from "node:stream";
import { timingSafeEqual } from "node:crypto";
import cors from "@fastify/cors";
import formbody from "@fastify/formbody";
import websocket from "@fastify/websocket";
import Fastify, { type FastifyInstance, type FastifyRequest } from "fastify";
import { ZodError } from "zod";
import type { AppConfig } from "../config.js";
import { isBlockedNumber, normalizePhoneNumber } from "../domain/phone.js";
import { InvalidTransitionError } from "../domain/stateMachine.js";
import type { EventBus } from "../events/eventBus.js";
import type { KatCallProvider } from "../providers/kat/katProvider.js";
import { type CallService, ServiceError } from "../services/callService.js";
import { ApprovalDecisionBody, ApprovalParams, ApprovePlanBody, CreateTaskBody, TaskParams } from "./schemas.js";

export interface AppDeps {
  config: Pick<AppConfig, "API_TOKEN" | "CORS_ORIGINS" | "provider" | "llm">;
  calls: CallService;
  bus: EventBus;
  kat?: KatCallProvider;
  logger?: boolean;
}

type RequestWithRawBody = FastifyRequest & { rawBody?: string };

function tokenMatches(expected: string, provided: string | undefined): boolean {
  if (!provided) return false;
  const a = Buffer.from(expected);
  const b = Buffer.from(provided);
  return a.length === b.length && timingSafeEqual(a, b);
}

function providedToken(request: FastifyRequest): string | undefined {
  const header = request.headers.authorization;
  if (header?.startsWith("Bearer ")) return header.slice(7);
  // Browsers cannot set headers on WebSocket handshakes, so the stream also accepts ?token=.
  const query = request.query as Record<string, string | undefined>;
  return request.url.startsWith("/v1/stream") ? query.token : undefined;
}

export async function buildApp(deps: AppDeps): Promise<FastifyInstance> {
  const { config, calls, bus, kat } = deps;
  const app = Fastify({
    logger:
      deps.logger === false
        ? false
        : {
            serializers: {
              // The stream URL can carry ?token=; keep it out of request logs.
              req: (req: { method: string; url: string }) => ({
                method: req.method,
                url: req.url.replace(/token=[^&]*/g, "token=***"),
              }),
            },
          },
    bodyLimit: 64 * 1024,
  });

  await app.register(formbody);
  await app.register(websocket, { options: { maxPayload: 1024 * 1024 } });
  if (config.CORS_ORIGINS) {
    await app.register(cors, {
      origin: config.CORS_ORIGINS.split(",").map((o) => o.trim()),
      methods: ["GET", "POST", "DELETE"],
    });
  }

  // KAT webhook signatures are computed over the exact raw body bytes.
  app.addHook("preParsing", async (request, _reply, payload) => {
    if (!request.url.startsWith("/kat/")) return payload;
    const chunks: Buffer[] = [];
    for await (const chunk of payload) {
      chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
    }
    const raw = Buffer.concat(chunks);
    (request as RequestWithRawBody).rawBody = raw.toString("utf8");
    return Readable.from(raw);
  });

  app.setErrorHandler((error, request, reply) => {
    if (error instanceof ZodError) {
      return reply.status(400).send({ error: "invalid_request", message: error.issues.map((i) => `${i.path.join(".")}: ${i.message}`).join("; ") });
    }
    if (error instanceof ServiceError) {
      return reply.status(error.statusCode).send({ error: error.code, message: error.message });
    }
    if (error instanceof InvalidTransitionError) {
      return reply.status(409).send({ error: "invalid_state", message: error.message });
    }
    const status = (error as { statusCode?: number }).statusCode;
    if (status && status < 500) {
      return reply.status(status).send({ error: "bad_request", message: (error as Error).message });
    }
    request.log.error(error);
    return reply.status(500).send({ error: "internal", message: "Unexpected server error" });
  });

  app.addHook("onRequest", async (request, reply) => {
    if (!request.url.startsWith("/v1/") || !config.API_TOKEN) return;
    if (!tokenMatches(config.API_TOKEN, providedToken(request))) {
      return reply.status(401).send({ error: "unauthorized", message: "Missing or invalid API token" });
    }
  });

  app.get("/health", async () => ({ ok: true }));

  app.get("/v1/config", async () => ({
    provider: config.provider,
    brain: config.llm,
    realCalls: config.provider === "kat",
  }));

  app.get("/v1/tasks", async () => ({ tasks: calls.list() }));

  app.get("/v1/tasks/:id", async (request) => calls.get(TaskParams.parse(request.params).id));

  app.post("/v1/tasks", async (request, reply) => {
    const body = CreateTaskBody.parse(request.body);
    const phoneNumber = normalizePhoneNumber(body.phoneNumber);
    if (!phoneNumber) throw new ServiceError(400, "invalid_phone", "전화번호 형식이 올바르지 않습니다.");
    if (isBlockedNumber(phoneNumber)) throw new ServiceError(400, "blocked_number", "긴급·특수번호에는 전화할 수 없습니다.");
    const callbackNumber = body.callbackNumber ? normalizePhoneNumber(body.callbackNumber) ?? undefined : undefined;
    const task = calls.create({ ...body, phoneNumber, callbackNumber });
    return reply.status(201).send(task);
  });

  app.post("/v1/tasks/:id/approve-plan", async (request) => {
    const { id } = TaskParams.parse(request.params);
    const { plan } = ApprovePlanBody.parse(request.body ?? {});
    return calls.approvePlan(id, plan);
  });

  app.post("/v1/tasks/:id/cancel", async (request) => calls.cancel(TaskParams.parse(request.params).id));

  app.post("/v1/tasks/:id/approvals/:approvalId", async (request) => {
    const { id, approvalId } = ApprovalParams.parse(request.params);
    const { decision, comment } = ApprovalDecisionBody.parse(request.body ?? {});
    return calls.respondToApproval(id, approvalId, {
      approve: decision === "approve",
      comment,
    });
  });

  app.delete("/v1/tasks/:id", async (request, reply) => {
    calls.delete(TaskParams.parse(request.params).id);
    return reply.status(204).send();
  });

  app.get("/v1/stream", { websocket: true }, (socket) => {
    const send = (payload: object) => {
      if (socket.readyState === socket.OPEN) socket.send(JSON.stringify(payload));
    };
    send({ type: "snapshot", tasks: calls.list() });
    const unsubscribe = bus.subscribe(send);
    const ping = setInterval(() => socket.ping(), 25_000);
    socket.on("close", () => {
      unsubscribe();
      clearInterval(ping);
    });
  });

  if (kat) {
    app.post("/kat/status", async (request, reply) => {
      const rawBody = (request as RequestWithRawBody).rawBody ?? "";
      if (!kat.isValidHttpWebhook(request.headers, rawBody)) {
        return reply.status(401).send({ error: "invalid_signature" });
      }
      kat.handleStatusWebhook(request.body as { data?: Record<string, unknown> });
      return reply.status(204).send();
    });

    app.get("/kat/media", { websocket: true }, (socket, request) => {
      kat.attachMediaStream(socket, request.raw);
    });
  }

  return app;
}
