import { Readable } from "node:stream";
import { timingSafeEqual } from "node:crypto";
import cors from "@fastify/cors";
import formbody from "@fastify/formbody";
import websocket from "@fastify/websocket";
import Fastify, { type FastifyInstance, type FastifyRequest } from "fastify";
import { ZodError } from "zod";
import type { AppConfig } from "../config.js";
import { InvalidTransitionError } from "../domain/stateMachine.js";
import type { EventBus } from "../events/eventBus.js";
import type { ProviderRoutes } from "../providers/types.js";
import { type CallService, ServiceError } from "../services/callService.js";
import { ApprovalDecisionBody, ApprovalParams, ApprovePlanBody, CreateTaskBody, TaskParams } from "./schemas.js";

export interface AppDeps {
  config: Pick<AppConfig, "API_TOKEN" | "CORS_ORIGINS" | "provider" | "llm">;
  calls: CallService;
  bus: EventBus;
  /** Routes the active provider declares; registered exactly as declared. */
  providerRoutes?: ProviderRoutes;
  /** Whether the active provider dials real phones. Decided by the wiring (container.ts); default false. */
  realCalls?: boolean;
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

/** Path without the query string, so "/hook?x=1" matches a route declared as "/hook". */
function pathOf(url: string): string {
  const query = url.indexOf("?");
  return query === -1 ? url : url.slice(0, query);
}

// @MX:ANCHOR: [AUTO] The only place provider-declared routes become HTTP routes; every provider's webhooks pass through here.
// @MX:REASON: Providers must stay framework-neutral (SPEC-ARCH-001 REQ-001/002); raw-body capture and the /v1/ auth boundary are enforced here.
// @MX:SPEC: SPEC-ARCH-001
function registerProviderRoutes(app: FastifyInstance, routes: ProviderRoutes): void {
  for (const route of [...routes.http, ...routes.sockets]) {
    if (route.path.startsWith("/v1/")) {
      throw new Error(`Provider route ${route.path} must not live under /v1/ (the token-protected API)`);
    }
  }

  // Signatures are computed over the exact raw body bytes, so declared routes get them captured.
  const rawBodyPaths = new Set(routes.http.filter((route) => route.rawBody).map((route) => route.path));
  if (rawBodyPaths.size > 0) {
    app.addHook("preParsing", async (request, _reply, payload) => {
      if (!rawBodyPaths.has(pathOf(request.url))) return payload;
      const chunks: Buffer[] = [];
      for await (const chunk of payload) {
        chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
      }
      const raw = Buffer.concat(chunks);
      (request as RequestWithRawBody).rawBody = raw.toString("utf8");
      return Readable.from(raw);
    });
  }

  for (const route of routes.http) {
    app.route({
      method: route.method,
      url: route.path,
      handler: async (request, reply) => {
        const response = await route.handle({
          headers: request.headers,
          rawBody: route.rawBody ? ((request as RequestWithRawBody).rawBody ?? "") : undefined,
          body: request.body,
        });
        reply.status(response.status);
        return response.body === undefined ? reply.send() : reply.send(response.body);
      },
    });
  }

  for (const route of routes.sockets) {
    app.get(route.path, { websocket: true }, (socket, request) => route.attach(socket, request.raw));
  }
}

export async function buildApp(deps: AppDeps): Promise<FastifyInstance> {
  const { config, calls, bus, providerRoutes } = deps;
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
    realCalls: deps.realCalls ?? false,
  }));

  app.get("/v1/tasks", async () => ({ tasks: calls.list() }));

  app.get("/v1/tasks/:id", async (request) => calls.get(TaskParams.parse(request.params).id));

  app.post("/v1/tasks", async (request, reply) => {
    // Number normalization and the emergency-number block live in CallService (SPEC-POLICY-001 REQ-008).
    const task = calls.create(CreateTaskBody.parse(request.body));
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

  if (providerRoutes) registerProviderRoutes(app, providerRoutes);

  return app;
}
