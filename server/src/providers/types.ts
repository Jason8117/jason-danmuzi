import type { IncomingHttpHeaders, IncomingMessage } from "node:http";
import type WebSocket from "ws";
import type { ApprovalDecision, CallTask, Speaker } from "../domain/types.js";

/** What a provider route handler sees of an HTTP request. Framework-neutral on purpose. */
export interface ProviderHttpRequest {
  headers: IncomingHttpHeaders;
  /** The exact request body bytes as UTF-8; set only on routes declared with `rawBody: true`. */
  rawBody?: string;
  /** The parsed request body. */
  body: unknown;
}

export interface ProviderHttpResponse {
  status: number;
  /** JSON body; omitted for empty responses (e.g. 204). */
  body?: object;
}

export interface ProviderHttpRoute {
  method: "POST" | "GET";
  /** Absolute path. Must not start with /v1/ (that prefix is the token-protected user API). */
  path: string;
  /** Capture the raw body, e.g. for signature checks over the exact bytes. */
  rawBody: boolean;
  handle(request: ProviderHttpRequest): ProviderHttpResponse | Promise<ProviderHttpResponse>;
}

export interface ProviderSocketRoute {
  path: string;
  attach(socket: WebSocket, request: IncomingMessage): void;
}

/** Webhook and WebSocket routes a provider needs; the HTTP layer registers them as declared. */
export interface ProviderRoutes {
  http: ProviderHttpRoute[];
  sockets: ProviderSocketRoute[];
}

export interface EndOptions {
  /** Set when the call could not be completed (no answer, busy, provider error). */
  error?: string;
}

/**
 * What a provider can do to a running call. The provider owns audio and
 * dialing; CallService owns state, persistence, approvals and summaries.
 */
export interface CallSession {
  readonly taskId: string;
  /** Latest task snapshot. */
  task(): CallTask;
  /** The live agent's instructions for this task, built by the service layer from the current task. */
  agentInstructions(): string;
  /** Aborted when the user hangs up or the call ends for any reason. */
  readonly signal: AbortSignal;
  markRinging(): void;
  markConnected(): void;
  appendTranscript(speaker: Speaker, text: string): void;
  /**
   * Pauses for the user's decision. Resolves with approved=false on rejection,
   * timeout, or hang-up. Optional comment is user guidance for the agent.
   */
  requestApproval(question: string): Promise<ApprovalDecision>;
  /** Reports the provider's external call id as soon as it is known, so it survives a restart. */
  recordProviderCallId(providerCallId: string): void;
  end(options?: EndOptions): void;
}

export interface CallProvider {
  readonly name: "simulated" | "kat";
  /** Starts dialing. Resolves once the call is initiated, not when it ends. */
  start(session: CallSession): Promise<void>;
  /** Hangs up an active call. Must be safe to call more than once. */
  hangup(taskId: string): Promise<void>;
  /**
   * Hangs up a call by its external id without any in-memory session (e.g. after a restart).
   * Optional: providers that never report a call id (simulated) do not implement it.
   */
  terminateByProviderCallId?(providerCallId: string): Promise<void>;
  /** Routes this provider needs (webhooks, media streams). Optional: the simulated provider has none. */
  routes?(): ProviderRoutes;
}
